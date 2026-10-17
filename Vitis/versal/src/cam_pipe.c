/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * Camera video pipe of the Versal design (one per camera port, Vivado/src/bd/bd_versal.tcl):
 *
 *   sensor -> MIPI CSI-2 RX SS -> ISPPipeline_accel -> v_proc_ss (scaler, CSC) -> v_frmbuf_wr -> DDR
 *     RAW10 1920x1080           (demosaic, AWB,       RGB 1920x1080 ->           YUYV 960x540
 *                                gamma) -> RGB         YUV 4:2:2 960x540
 *
 * Every pipe has its own AXI IIC (sensor) and AXI GPIO (bit 0 = camera power enable / reset).
 * The frame buffer writer cycles through three buffers; the main loop polls its "done" flag and
 * hands the last complete frame to the mixer layer, so the display never shows a frame that is
 * still being written.
 */

#include "cam_pipe.h"
#include "config.h"
#include "resets.h"
#include "display.h"
#include "i2c.h"
#include "xv_hscaler_l2.h"
#include "xv_vscaler_l2.h"
#include "xv_frmbufwr_l2.h"
#include "xvidc.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "sleep.h"

#define GPIO_CAM_IO0_MASK   0x01   /* camera power enable */

/* ISPPipeline_accel registers (HLS driver xisppipeline_accel_hw.h) */
#define ISP_REG_AP_CTRL         0x000
#define ISP_REG_WIDTH           0x010
#define ISP_REG_HEIGHT          0x018
#define ISP_REG_MODE_REG        0x020
#define ISP_REG_RGAIN           0x030
#define ISP_REG_BGAIN           0x038
#define ISP_REG_PAWB            0x054
#define ISP_GAMMA_BLUE      0x800   /* one 256-entry table per plane: B, G, R */
#define ISP_GAMMA_GREEN     0x900
#define ISP_GAMMA_RED       0xA00
#define ISP_START_AUTO      0x81    /* ap_start + auto_restart */

/* MIPI CSI-2 RX controller registers (PG232) */
#define CSI_CORE_STATUS     0x10
#define CSI_ISR             0x24

/*
 * Gamma curve of the Linux ISP driver's default (red/green/blue gamma control = 20 with the
 * Opsero gamma-plane fix): out = floor(255 * (in / 255) ^ (1 / 2.1)).
 */
static const u8 isp_gamma[256] = {
	  0,  18,  25,  30,  35,  39,  42,  46,  49,  51,  54,  57,  59,  61,  64,  66,
	 68,  70,  72,  74,  75,  77,  79,  81,  82,  84,  85,  87,  89,  90,  92,  93,
	 94,  96,  97,  99, 100, 101, 103, 104, 105, 106, 108, 109, 110, 111, 112, 113,
	115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 127, 128, 129, 130, 131,
	132, 133, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 145,
	146, 147, 148, 149, 150, 151, 151, 152, 153, 154, 155, 156, 156, 157, 158, 159,
	160, 160, 161, 162, 163, 164, 164, 165, 166, 167, 167, 168, 169, 170, 170, 171,
	172, 173, 173, 174, 175, 175, 176, 177, 178, 178, 179, 180, 180, 181, 182, 182,
	183, 184, 185, 185, 186, 187, 187, 188, 189, 189, 190, 191, 191, 192, 192, 193,
	194, 194, 195, 196, 196, 197, 198, 198, 199, 199, 200, 201, 201, 202, 203, 203,
	204, 204, 205, 206, 206, 207, 207, 208, 209, 209, 210, 210, 211, 211, 212, 213,
	213, 214, 214, 215, 216, 216, 217, 217, 218, 218, 219, 219, 220, 221, 221, 222,
	222, 223, 223, 224, 224, 225, 226, 226, 227, 227, 228, 228, 229, 229, 230, 230,
	231, 231, 232, 233, 233, 234, 234, 235, 235, 236, 236, 237, 237, 238, 238, 239,
	239, 240, 240, 241, 241, 242, 242, 243, 243, 244, 244, 245, 245, 246, 246, 247,
	247, 248, 248, 249, 249, 250, 250, 251, 251, 252, 252, 253, 253, 254, 254, 255
};

/* Camera ports of this design, from xparameters.h (the XSA). Quadrant = camera port index. */
#define CAM_ENTRY(n) { n, XPAR_MIPI_##n##_AXI_IIC_0_BASEADDR, XPAR_MIPI_##n##_AXI_GPIO_0_BASEADDR, \
	XPAR_MIPI_##n##_MIPI_CSI2_RX_SUBSYST_0_BASEADDR, XPAR_MIPI_##n##_ISPPIPELINE_BASEADDR, \
	XPAR_MIPI_##n##_V_PROC_VSC_BASEADDR, XPAR_MIPI_##n##_V_PROC_HSC_BASEADDR, \
	XPAR_MIPI_##n##_V_PROC_RESET_SEL_AXIS_BASEADDR, XPAR_MIPI_##n##_V_FRMBUF_WR_BASEADDR }

static const CamPorts cam_ports[] = {
#ifdef XPAR_MIPI_0_AXI_IIC_0_BASEADDR
	CAM_ENTRY(0),
#endif
#ifdef XPAR_MIPI_1_AXI_IIC_0_BASEADDR
	CAM_ENTRY(1),
#endif
#ifdef XPAR_MIPI_2_AXI_IIC_0_BASEADDR
	CAM_ENTRY(2),
#endif
#ifdef XPAR_MIPI_3_AXI_IIC_0_BASEADDR
	CAM_ENTRY(3),
#endif
};
#define NUM_PORTS (sizeof(cam_ports) / sizeof(cam_ports[0]))

static CamPipe Pipes[NUM_PORTS];

unsigned cam_num_ports(void) { return NUM_PORTS; }
CamPipe *cam_pipe(unsigned i) { return (i < NUM_PORTS) ? &Pipes[i] : NULL; }

static const char *sensor_name(u8 model)
{
	switch (model) {
	case RPI_CAM_TYPE_IMX219: return "Raspberry Pi Camera v2 (IMX219)";
	case RPI_CAM_TYPE_OV5640: return "Digilent Pcam 5C (OV5640)";
	default:                  return "unknown";
	}
}

static void isp_start(UINTPTR base)
{
	Xil_Out32(base + ISP_REG_WIDTH, CAM_WIDTH);
	Xil_Out32(base + ISP_REG_HEIGHT, CAM_HEIGHT);
	Xil_Out32(base + ISP_REG_RGAIN, ISP_RGAIN);
	Xil_Out32(base + ISP_REG_BGAIN, ISP_BGAIN);
	Xil_Out32(base + ISP_REG_MODE_REG, ISP_MODE_REG);
	Xil_Out32(base + ISP_REG_PAWB, ISP_PAWB);
	for (unsigned w = 0; w < 64; w++) {
		u32 v = isp_gamma[4 * w] | (isp_gamma[4 * w + 1] << 8) |
			(isp_gamma[4 * w + 2] << 16) | ((u32)isp_gamma[4 * w + 3] << 24);
		Xil_Out32(base + ISP_GAMMA_BLUE + 4 * w, v);
		Xil_Out32(base + ISP_GAMMA_GREEN + 4 * w, v);
		Xil_Out32(base + ISP_GAMMA_RED + 4 * w, v);
	}
	Xil_Out32(base + ISP_REG_AP_CTRL, ISP_START_AUTO);
}

/*
 * Video Processing Subsystem (scaler-only topology: V scaler -> H scaler, CSC in the H scaler),
 * programmed through its sub-core drivers. The XVprocSs driver itself is not used: in the 2025.2
 * SDT flow its sub-core repository is declared "subcoreRepo[]" (one element), so a second
 * v_proc_ss instance overwrites memory past it (seen on the bench: the second camera's H scaler
 * coefficients were garbage and its picture black).
 */
#define VPROC_RST_IP_AXIS   0x2     /* reset_sel_axis GPIO: release the scalers */
#define VPROC_RST_VIDEO_IN  0x1     /* ... then accept the input stream */

static int vproc_start(CamPipe *p)
{
	XV_vscaler_Config *vcfg = XV_vscaler_LookupConfig(p->ports->vsc);
	XV_hscaler_Config *hcfg = XV_hscaler_LookupConfig(p->ports->hsc);
	if (vcfg == NULL || hcfg == NULL ||
	    XV_vscaler_CfgInitialize(&p->Vsc.Vsc, vcfg, vcfg->BaseAddress) != XST_SUCCESS ||
	    XV_hscaler_CfgInitialize(&p->Hsc.Hsc, hcfg, hcfg->BaseAddress) != XST_SUCCESS ||
	    XGpio_Initialize(&p->VprocRst, p->ports->vproc_rst) != XST_SUCCESS) {
		xil_printf("v_proc init failed\r\n");
		return XST_FAILURE;
	}
	XGpio_SetDataDirection(&p->VprocRst, 1, 0);
	XGpio_DiscreteWrite(&p->VprocRst, 1, 0);
	usleep(100);
	XGpio_DiscreteWrite(&p->VprocRst, 1, VPROC_RST_IP_AXIS);
	usleep(1000);

	/* 1920x1080 RGB -> V scaler -> 1920x540 RGB -> H scaler (+CSC) -> 960x540 YUV 4:2:2 */
	if (XV_VScalerSetup(&p->Vsc, CAM_WIDTH, CAM_HEIGHT, QUAD_HEIGHT, XVIDC_CSF_RGB) != XST_SUCCESS ||
	    XV_HScalerSetup(&p->Hsc, QUAD_HEIGHT, CAM_WIDTH, QUAD_WIDTH, XVIDC_CSF_RGB,
			    XVIDC_CSF_YCRCB_422) != XST_SUCCESS) {
		xil_printf("v_proc configuration failed\r\n");
		return XST_FAILURE;
	}
	XV_HScalerStart(&p->Hsc);
	XV_VScalerStart(&p->Vsc);
	XGpio_DiscreteWrite(&p->VprocRst, 1, VPROC_RST_IP_AXIS | VPROC_RST_VIDEO_IN);
	return XST_SUCCESS;
}

static int frmbuf_start(CamPipe *p)
{
	XV_FrmbufWr_l2 *fb = &p->Frmbuf;
	if (XVFrmbufWr_Initialize(fb, p->ports->frmbuf) != XST_SUCCESS) {
		xil_printf("v_frmbuf_wr init failed\r\n");
		return XST_FAILURE;
	}
	XVidC_VideoStream s = {0};
	s.VmId           = XVIDC_VM_CUSTOM;
	s.Timing.HActive = QUAD_WIDTH;
	s.Timing.VActive = QUAD_HEIGHT;
	s.ColorFormatId  = XVIDC_CSF_YCRCB_422;
	s.ColorDepth     = XVIDC_BPC_8;
	s.PixPerClk      = (XVidC_PixelsPerClock)fb->FrmbufWr.Config.PixPerClk;
	s.FrameRate      = XVIDC_FR_30HZ;
	if (XVFrmbufWr_SetMemFormat(fb, QUAD_STRIDE, XVIDC_CSF_MEM_YUYV8, &s) != XST_SUCCESS) {
		xil_printf("v_frmbuf_wr format failed\r\n");
		return XST_FAILURE;
	}
	/* Frame k writes the address set two "done"s earlier (see cam_poll) */
	p->seq = 0;
	if (XVFrmbufWr_SetBufferAddr(fb, p->buf[0]) != XST_SUCCESS)
		return XST_FAILURE;
	XV_frmbufwr_InterruptGlobalDisable(&fb->FrmbufWr);
	XV_frmbufwr_InterruptEnable(&fb->FrmbufWr, XVFRMBUFWR_IRQ_DONE_MASK); /* status only, polled */
	XV_frmbufwr_InterruptClear(&fb->FrmbufWr, XVFRMBUFWR_IRQ_DONE_MASK);
	XV_frmbufwr_EnableAutoRestart(&fb->FrmbufWr);
	XV_frmbufwr_Start(&fb->FrmbufWr);
	return XST_SUCCESS;
}

/* Fill a YUYV buffer with black (Y=0x10, U=V=0x80) */
static void buf_clear(UINTPTR buf)
{
	u32 *w = (u32 *)buf;
	for (unsigned i = 0; i < QUAD_FRAME_BYTES / 4; i++)
		w[i] = 0x80108010;
	Xil_DCacheFlushRange(buf, QUAD_FRAME_BYTES);
}

/* Power up the camera port and look for a sensor. Returns XST_SUCCESS if one is found. */
int cam_detect(unsigned i)
{
	CamPipe *p = &Pipes[i];
	p->ports = &cam_ports[i];
	p->port = p->ports->port;
	p->active = 0;

	if (XGpio_Initialize(&p->Gpio, p->ports->gpio) != XST_SUCCESS)
		return XST_FAILURE;
	XGpio_SetDataDirection(&p->Gpio, 1, 0);
	XGpio_DiscreteWrite(&p->Gpio, 1, GPIO_CAM_IO0_MASK);   /* camera enabled */
	usleep(10000);

	if (IicAxiInit(NULL, p->ports->iic, &p->iic_id) != XST_SUCCESS)
		return XST_FAILURE;
	if (rpi_cam_init(&p->Camera, p->iic_id, &p->Gpio, GPIO_CAM_IO0_MASK) != XST_SUCCESS)
		return XST_FAILURE;
	p->sensor = sensor_name(p->Camera.sensor.model);
	return XST_SUCCESS;
}

/* Bring up the pipe of a detected camera on mixer layer <layer>, then start the sensor */
int cam_start(unsigned i, unsigned layer)
{
	CamPipe *p = &Pipes[i];
	p->layer = layer;
	for (unsigned b = 0; b < FRMBUF_NUM; b++) {
		p->buf[b] = FRMBUF_BASE + p->port * FRMBUF_CAM_SPAN + b * QUAD_FRAME_BYTES;
		buf_clear(p->buf[b]);
	}

	/* downstream first: frame buffer, scaler, ISP; then the sensor */
	reset_release(RST_BIT_FRMBUF(p->port));
	if (frmbuf_start(p) != XST_SUCCESS)
		return XST_FAILURE;
	reset_release(RST_BIT_VPROC(p->port));
	if (vproc_start(p) != XST_SUCCESS)
		return XST_FAILURE;
	reset_release(RST_BIT_ISP(p->port));
	isp_start(p->ports->isp);

	if (display_layer_setup(layer, p->port, p->buf[0]) != XST_SUCCESS)
		return XST_FAILURE;

	if (rpi_cam_config(&p->Camera) != XST_SUCCESS) {
		xil_printf("sensor configuration failed\r\n");
		return XST_FAILURE;
	}

	Xil_Out32(p->ports->csi + CSI_ISR, 0xFFFFFFFF);   /* clear the start-up events */
	display_layer_enable(layer);
	p->active = 1;
	return XST_SUCCESS;
}

/*
 * Called from the main loop. With auto-restart, frame k+1 starts (and latches the buffer
 * address register) right when frame k is done, before we see the done flag. So the address
 * written at done k is used by frame k+2, and the frame completed at done k is the one whose
 * address was written at done k-2. Three buffers rotate: at done k the register gets buffer
 * k%3, frame k+1 is writing (k-1)%3 and the complete frame (k-2)%3 goes to the mixer.
 */
void cam_poll(CamPipe *p)
{
	XV_frmbufwr *fb = &p->Frmbuf.FrmbufWr;
	if (!p->active || !(XV_frmbufwr_InterruptGetStatus(fb) & XVFRMBUFWR_IRQ_DONE_MASK))
		return;
	XV_frmbufwr_InterruptClear(fb, XVFRMBUFWR_IRQ_DONE_MASK);
	p->seq++;
	p->frames++;
	XVFrmbufWr_SetBufferAddr(&p->Frmbuf, p->buf[p->seq % FRMBUF_NUM]);
	if (p->seq >= 2)
		display_layer_buffer(p->layer, p->buf[(p->seq - 2) % FRMBUF_NUM]);
}

u32 cam_csi_isr(CamPipe *p, int clear)
{
	u32 isr = Xil_In32(p->ports->csi + CSI_ISR);
	if (clear)
		Xil_Out32(p->ports->csi + CSI_ISR, isr);
	return isr;
}

u32 cam_csi_packets(CamPipe *p)
{
	return Xil_In32(p->ports->csi + CSI_CORE_STATUS) >> 16;
}
