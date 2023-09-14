/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 * This example standalone application for the RPi Camera FMC will configure all of the connected
 * cameras that it finds connected, and then displays the video outputs on the DisplayPort monitor.
 * To display all four video streams on the single display, it uses the Video Processor Subsystem IP
 * to downsize the 1080p videos coming from the cameras to 720x480 resolution and then combines them
 * with the Video Mixer to produce a 1080p resolution video containing all four video streams.
 * The camera streams are organized on the screen as shown below:
 *
 * +------------------------------------------+
 * |              1920x1080px                 |
 * |  +----------------+  +----------------+  |
 * |  |                |  |                |  |
 * |  |     CAM0       |  |     CAM1       |  |
 * |  |   720x480px    |  |   720x480px    |  |
 * |  +----------------+  +----------------+  |
 * |                                          |
 * |  +----------------+  +----------------+  |
 * |  |                |  |                |  |
 * |  |     CAM2       |  |     CAM3       |  |
 * |  |   720x480px    |  |   720x480px    |  |
 * |  +----------------+  +----------------+  |
 * |                                          |
 * +------------------------------------------+
 *
 * Camera-to-DDR video pipe (x4):
 * ------------------------------
 *  RPi cam -> MIPI CSI SS -> Demosaic -> Gamma LUT -> VProc SS -> Frame Buffer Write -> DDR
 *
 *  The video pipe runs at 2 pixels per clock.
 *
 * DDR-to-DP video pipe:
 * ---------------------
 *                                    +-------------+
 *    Video Test Pattern Generator -> |             |
 * DDR -> Frame Buffer Read (CAM0) -> |             |
 * DDR -> Frame Buffer Read (CAM1) -> | Video Mixer |-> AXIS Remapper -> AXIS to Video Out -> DP live
 * DDR -> Frame Buffer Read (CAM2) -> |   (2ppc)    |   (2ppc to 1ppc)
 * DDR -> Frame Buffer Read (CAM3) -> |             |
 *                                    +-------------+
 *
 * Input and output of the video mixer runs at 2 pixels per clock. The AXIS Remapper converts
 * the 2ppc to 1ppc before it gets converted to video signals for the ZynqMP's DP live interface.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "xscugic.h"
#include "xgpio.h"
#include "xgpiops.h"
#include "xvtc.h"
#include "xavbuf.h"
#include "xv_frmbufrd_l2.h"
#include "xv_frmbufwr_l2.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xvprocss_vdma.h"
#include "xv_mix_l2.h"
#include "xv_axi4s_remap.h"
#include "xv_tpg.h"
#include "xvidc.h"
#include "xdpdma_video_example.h"
#include "board.h"
#include "pipe.h"
#include "config.h"

// Frame buffer Rd/Wr buffer addresses (using physical memory)
#define CAM0_FRMBUF_BUFR_ADDR 0x10000000
#define CAM1_FRMBUF_BUFR_ADDR 0x20000000
#define CAM2_FRMBUF_BUFR_ADDR 0x30000000
#define CAM3_FRMBUF_BUFR_ADDR 0x40000000

// Common IP
XScuGic Intc;
XVtc VtcInst;
XGpio RsvdGpio;
XV_Mix_l2  VMix;
XGpioPs EmioGpio;
XV_tpg Tpg;
XV_axi4s_remap Remap;

// Video pipes 0 and 1
VideoPipe Cam0,Cam1;

// Provide the device IDs for the elements of each video pipe
VideoPipeDevIds CamDevIds0 = {
		XPAR_MIPI_0_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_0_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_0_V_FRMBUF_WR_DEVICE_ID,
		XPAR_MIPI_0_V_FRMBUF_RD_DEVICE_ID,
		CAM0_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_0_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_0_V_GAMMA_LUT_DEVICE_ID,
		XPAR_XVPROCSS_0_DEVICE_ID,
		XPAR_FABRIC_MIPI_0_AXI_IIC_0_IIC2INTC_IRPT_INTR,
		XPAR_FABRIC_MIPI_0_V_FRMBUF_WR_INTERRUPT_INTR,
		XPAR_FABRIC_MIPI_0_V_FRMBUF_RD_INTERRUPT_INTR
};
VideoPipeDevIds CamDevIds1 = {
		XPAR_MIPI_1_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_1_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_1_V_FRMBUF_WR_DEVICE_ID,
		XPAR_MIPI_1_V_FRMBUF_RD_DEVICE_ID,
		CAM1_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_1_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_1_V_GAMMA_LUT_DEVICE_ID,
		XPAR_XVPROCSS_1_DEVICE_ID,
		XPAR_FABRIC_MIPI_1_AXI_IIC_0_IIC2INTC_IRPT_INTR,
		XPAR_FABRIC_MIPI_1_V_FRMBUF_WR_INTERRUPT_INTR,
		XPAR_FABRIC_MIPI_1_V_FRMBUF_RD_INTERRUPT_INTR
};

#ifdef XPAR_MIPI_2_AXI_IIC_0_DEVICE_ID
#define NUM_CAMS 4
// Video pipes 2 and 3
VideoPipe Cam2,Cam3;

VideoPipeDevIds CamDevIds2 = {
		XPAR_MIPI_2_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_2_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_2_V_FRMBUF_WR_DEVICE_ID,
		XPAR_MIPI_2_V_FRMBUF_RD_DEVICE_ID,
		CAM2_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_2_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_2_V_GAMMA_LUT_DEVICE_ID,
		XPAR_XVPROCSS_2_DEVICE_ID,
		XPAR_FABRIC_MIPI_2_AXI_IIC_0_IIC2INTC_IRPT_INTR,
		XPAR_FABRIC_MIPI_2_V_FRMBUF_WR_INTERRUPT_INTR,
		XPAR_FABRIC_MIPI_2_V_FRMBUF_RD_INTERRUPT_INTR
};
VideoPipeDevIds CamDevIds3 = {
		XPAR_MIPI_3_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_3_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_3_V_FRMBUF_WR_DEVICE_ID,
		XPAR_MIPI_3_V_FRMBUF_RD_DEVICE_ID,
		CAM3_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_3_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_3_V_GAMMA_LUT_DEVICE_ID,
		XPAR_XVPROCSS_3_DEVICE_ID,
		XPAR_FABRIC_MIPI_3_AXI_IIC_0_IIC2INTC_IRPT_INTR,
		XPAR_FABRIC_MIPI_3_V_FRMBUF_WR_INTERRUPT_INTR,
		XPAR_FABRIC_MIPI_3_V_FRMBUF_RD_INTERRUPT_INTR
};
#else
#define NUM_CAMS 2
#endif

/*
 * The table below determines how the four camera video streams are organized
 * on a single 1080p video stream
 */
static const XVidC_VideoWindow MixLayerConfig[4] =
{// X   Y     W    H
  {160, 40,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 1
  {1040, 40,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 2
  {160, 560,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 3
  {1040, 560,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}  //Layer 4
};

VideoPipe *ActiveCams[NUM_CAMS];
uint8_t ActiveCamIndex[NUM_CAMS];
uint8_t NumActiveCams;

// Common target device IDs
#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define VTC_DEVICE_ID		XPAR_VTC_0_DEVICE_ID
#define RSVD_GPIO_DEVICE_ID XPAR_RSVD_GPIO_DEVICE_ID

// Interrupt controller defines
//#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define IIC_INTR_ID			XPAR_FABRIC_IIC_0_VEC_ID
#define INTC_HANDLER		XScuGic_InterruptHandler

// Reserved GPIO

#define CAM0_TST_OE_MASK    (0x0001<<0) // LA04_P
#define CAM1_TST_OE_MASK    (0x0001<<1) // LA04_N
#define CAM1_CLK_P_TST_MASK (0x0001<<2) // LA07_P
#define CAM1_CLK_N_TST_MASK (0x0001<<3) // LA07_N
#define CAM_IO0_DIR_MASK    (0x0001<<4) // LA13_P
#define CAM_IO1_DIR_MASK    (0x0001<<5) // LA13_N
#define CAM_IO0_OE_N_MASK   (0x0001<<6) // LA27_P
#define CAM_IO1_OE_N_MASK   (0x0001<<7) // LA27_N
#define CAM3_CLK_P_TST_MASK (0x0001<<8) // LA29_P
#define CAM3_CLK_N_TST_MASK (0x0001<<9) // LA29_N

// Reserved GPIO default direction mask (1=input, 0=output)
#define RSVD_GPIO_DEF_DIR_MASK 0 // All outputs
// Reserved GPIO default value mask
#define RSVD_GPIO_DEF_VAL_MASK (CAM_IO0_DIR_MASK|CAM_IO1_DIR_MASK)

// EMIO GPIO mapping
#define EMIO_GPIO_VMIX_RST_N          (78+0)
#define EMIO_GPIO_VTPG_RST_N          (78+1)
#define EMIO_GPIO_CAM0_DEMOSAIC_RST_N (78+8)  // CAM0 Demosaic IP reset
#define EMIO_GPIO_CAM0_VPROC_RST_N    (78+9)  // CAM0 Vproc IP reset
#define EMIO_GPIO_CAM0_GAMMA_RST_N    (78+10) // CAM0 Gamma LUT IP reset
#define EMIO_GPIO_CAM0_FRMBUFRD_RST_N (78+11) // CAM0 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM0_FRMBUFWR_RST_N (78+12) // CAM0 Frame Buffer Write IP reset
#define EMIO_GPIO_CAM1_DEMOSAIC_RST_N (78+16) // CAM1 Demosaic IP reset
#define EMIO_GPIO_CAM1_VPROC_RST_N    (78+17) // CAM1 Vproc IP reset
#define EMIO_GPIO_CAM1_GAMMA_RST_N    (78+18) // CAM1 Gamma LUT IP reset
#define EMIO_GPIO_CAM1_FRMBUFRD_RST_N (78+19) // CAM1 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM1_FRMBUFWR_RST_N (78+20) // CAM1 Frame Buffer Write IP reset
#define EMIO_GPIO_CAM2_DEMOSAIC_RST_N (78+24) // CAM2 Demosaic IP reset
#define EMIO_GPIO_CAM2_VPROC_RST_N    (78+25) // CAM2 Vproc IP reset
#define EMIO_GPIO_CAM2_GAMMA_RST_N    (78+26) // CAM2 Gamma LUT IP reset
#define EMIO_GPIO_CAM2_FRMBUFRD_RST_N (78+27) // CAM2 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM2_FRMBUFWR_RST_N (78+28) // CAM2 Frame Buffer Write IP reset
#define EMIO_GPIO_CAM3_DEMOSAIC_RST_N (78+32) // CAM3 Demosaic IP reset
#define EMIO_GPIO_CAM3_VPROC_RST_N    (78+33) // CAM3 Vproc IP reset
#define EMIO_GPIO_CAM3_GAMMA_RST_N    (78+34) // CAM3 Gamma LUT IP reset
#define EMIO_GPIO_CAM3_FRMBUFRD_RST_N (78+35) // CAM3 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM3_FRMBUFWR_RST_N (78+36) // CAM3 Frame Buffer Write IP reset

// EMIO GPIO masks (bank 3 in ZynqMP)
#define EMIO_GPIO_VMIX_RST_N_MASK          (0x1 << 0)
#define EMIO_GPIO_VTPG_RST_N_MASK          (0x1 << 1)
#define EMIO_GPIO_CAM0_DEMOSAIC_RST_N_MASK (0x1 << 8)  // CAM0 Demosaic IP reset
#define EMIO_GPIO_CAM0_VPROC_RST_N_MASK    (0x1 << 9)  // CAM0 Vproc IP reset
#define EMIO_GPIO_CAM0_GAMMA_RST_N_MASK    (0x1 << 10) // CAM0 Gamma LUT IP reset
#define EMIO_GPIO_CAM0_FRMBUFRD_RST_N_MASK (0x1 << 11) // CAM0 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM0_FRMBUFWR_RST_N_MASK (0x1 << 12) // CAM0 Frame Buffer Write IP reset
#define EMIO_GPIO_CAM1_DEMOSAIC_RST_N_MASK (0x1 << 16) // CAM1 Demosaic IP reset
#define EMIO_GPIO_CAM1_VPROC_RST_N_MASK    (0x1 << 17) // CAM1 Vproc IP reset
#define EMIO_GPIO_CAM1_GAMMA_RST_N_MASK    (0x1 << 18) // CAM1 Gamma LUT IP reset
#define EMIO_GPIO_CAM1_FRMBUFRD_RST_N_MASK (0x1 << 19) // CAM1 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM1_FRMBUFWR_RST_N_MASK (0x1 << 20) // CAM1 Frame Buffer Write IP reset
#define EMIO_GPIO_CAM2_DEMOSAIC_RST_N_MASK (0x1 << 24) // CAM2 Demosaic IP reset
#define EMIO_GPIO_CAM2_VPROC_RST_N_MASK    (0x1 << 25) // CAM2 Vproc IP reset
#define EMIO_GPIO_CAM2_GAMMA_RST_N_MASK    (0x1 << 26) // CAM2 Gamma LUT IP reset
#define EMIO_GPIO_CAM2_FRMBUFRD_RST_N_MASK (0x1 << 27) // CAM2 Frame Buffer Read IP reset
#define EMIO_GPIO_CAM2_FRMBUFWR_RST_N_MASK (0x1 << 28) // CAM2 Frame Buffer Write IP reset
// EMIO GPIO masks (bank 4 in ZynqMP)
#define EMIO_GPIO_B4_CAM3_DEMOSAIC_RST_N_MASK (0x1 << 0) // CAM3 Demosaic IP reset
#define EMIO_GPIO_B4_CAM3_VPROC_RST_N_MASK    (0x1 << 1) // CAM3 Vproc IP reset
#define EMIO_GPIO_B4_CAM3_GAMMA_RST_N_MASK    (0x1 << 2) // CAM3 Gamma LUT IP reset
#define EMIO_GPIO_B4_CAM3_FRMBUFRD_RST_N_MASK (0x1 << 3) // CAM3 Frame Buffer Read IP reset
#define EMIO_GPIO_B4_CAM3_FRMBUFWR_RST_N_MASK (0x1 << 4) // CAM3 Frame Buffer Write IP reset
// EMIO GPIO masks combined
#define EMIO_GPIO_B3_CAM0_RST_N               (0x1F << 8)
#define EMIO_GPIO_B3_CAM1_RST_N               (0x1F << 16)
#define EMIO_GPIO_B3_CAM2_RST_N               (0x1F << 24)
#define EMIO_GPIO_B4_CAM3_RST_N               (0x1F << 0)
#define EMIO_GPIO_B3_ALL_RST_N                (0x3 | EMIO_GPIO_B3_CAM0_RST_N | EMIO_GPIO_B3_CAM1_RST_N | EMIO_GPIO_B3_CAM2_RST_N)
#define EMIO_GPIO_B4_ALL_RST_N                EMIO_GPIO_B4_CAM3_RST_N

int main()
{
	XScuGic_Config *IntcConfig;
	XVtc_Config *VtcConfig;
	XVtc_Timing VtcTiming = {0};
	Run_Config RunCfg;
	XVidC_VideoTiming const *TimingPtr;
	XGpioPs_Config *ConfigPtr;
	XV_tpg_Config *TpgConfig;
	XV_axi4s_remap_Config *RemapCfg;

	int Status;

    xil_printf("---------------------------------------\n\r");
    xil_printf(" 4x RPi camera to Display Port example\n\r");
    xil_printf("---------------------------------------\n\r");

    /*
     * Initialize the EMIO GPIO driver
     */
    ConfigPtr = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_DEVICE_ID);
	Status = XGpioPs_CfgInitialize(&EmioGpio, ConfigPtr,ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: EmioGpio Initialization Failed\r\n");
		return XST_FAILURE;
	}
	// Enable and release all reset outputs in bank 3
	XGpioPs_SetDirection(&EmioGpio, 3, EMIO_GPIO_B3_ALL_RST_N);
	XGpioPs_Write(&EmioGpio, 3, EMIO_GPIO_B3_ALL_RST_N);
	XGpioPs_SetOutputEnable(&EmioGpio, 3, EMIO_GPIO_B3_ALL_RST_N);
	// Enable and release all reset outputs in bank 4
	XGpioPs_SetDirection(&EmioGpio, 4, EMIO_GPIO_B4_ALL_RST_N);
	XGpioPs_Write(&EmioGpio, 4, EMIO_GPIO_B4_ALL_RST_N);
	XGpioPs_SetOutputEnable(&EmioGpio, 4, EMIO_GPIO_B4_ALL_RST_N);

	/*
	 * Initialize the Reserved GPIO driver
	 */
	Status = XGpio_Initialize(&RsvdGpio, RSVD_GPIO_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: RsvdGpio Initialization Failed\r\n");
		return XST_FAILURE;
	}

	// Set Rsvd GPIO default directions (1=input, 0=output) and values
	XGpio_SetDataDirection(&RsvdGpio, 1, RSVD_GPIO_DEF_DIR_MASK);
	XGpio_DiscreteWrite(&RsvdGpio, 1, RSVD_GPIO_DEF_VAL_MASK);

	/*
	 * Initialize the interrupt controller
	 * The init functions of the I2C driver and DPDMA driver will each setup and
	 * enable their respective interrupts later.
	 */
	IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
	if (NULL == IntcConfig) {
		return XST_FAILURE;
	}
	Status = XScuGic_CfgInitialize(&Intc, IntcConfig, IntcConfig->CpuBaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	// Initialize exceptions
	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
			(Xil_ExceptionHandler)XScuGic_DeviceInterruptHandler,
			INTC_DEVICE_ID);
	// Enable exceptions for interrupts
	Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
	Xil_ExceptionEnable();

	/*
	 * Initialize Video pipe for each camera
	 */
	NumActiveCams = 0;
	pipe_init(&Cam0, &CamDevIds0, &Intc);
	if(Cam0.IsConnected) {
		ActiveCams[NumActiveCams] = &Cam0;
		ActiveCamIndex[NumActiveCams] = 0;
		NumActiveCams++;
	}
	pipe_init(&Cam1, &CamDevIds1, &Intc);
	if(Cam1.IsConnected) {
		ActiveCams[NumActiveCams] = &Cam1;
		ActiveCamIndex[NumActiveCams] = 1;
		NumActiveCams++;
	}
#ifdef XPAR_MIPI_2_AXI_IIC_0_DEVICE_ID
	pipe_init(&Cam2, &CamDevIds2, &Intc);
	if(Cam2.IsConnected) {
		ActiveCams[NumActiveCams] = &Cam2;
		ActiveCamIndex[NumActiveCams] = 2;
		NumActiveCams++;
	}
	pipe_init(&Cam3, &CamDevIds3, &Intc);
	if(Cam3.IsConnected) {
		ActiveCams[NumActiveCams] = &Cam3;
		ActiveCamIndex[NumActiveCams] = 3;
		NumActiveCams++;
	}
#endif

	if(NumActiveCams == 0) {
		xil_printf("ERROR: No video pipes were activated.\n\r");
		return 0;
	}

	xil_printf("Detected %d connected cameras\n\r",NumActiveCams);

	/*
	 * Initialize the Video Test Pattern Generator
	 */
	TpgConfig = XV_tpg_LookupConfig(XPAR_V_TPG_DEVICE_ID);
	if(TpgConfig == NULL) {
		xil_printf("ERROR: Video TPG device not found\r\n");
		return XST_FAILURE;
	}
	Status = XV_tpg_CfgInitialize(&Tpg, TpgConfig, TpgConfig->BaseAddress);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR:  Video TPG Initialization failed %d\r\n", Status);
		return XST_FAILURE;
	}
	XV_tpg_Set_height(&Tpg, VMODE_HEIGHT);
	XV_tpg_Set_width(&Tpg, VMODE_WIDTH);
	XV_tpg_Set_colorFormat(&Tpg, 0);
	XV_tpg_Set_bckgndId(&Tpg, XTPG_BKGND_SOLID_BLACK);
	XV_tpg_Set_ovrlayId(&Tpg, 0);
	XV_tpg_EnableAutoRestart(&Tpg);
	XV_tpg_Start(&Tpg);

	/*
	 * Initialize and configure the Video Mixer
	 */
	XVidC_VideoStream Stream;
	XVidC_ColorFormat Cfmt;
	Status  = XVMix_Initialize(&VMix, XPAR_V_MIX_DEVICE_ID);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Video Mixer device not initialized\r\n");
		return(XST_FAILURE);
	}

	// Video stream properties of the mixer's master input and output
	Stream.VmId = XVidC_GetVideoModeId(VMODE_WIDTH,VMODE_HEIGHT,VMODE_FRAMERATE,FALSE);
	XVMix_GetLayerColorFormat(&VMix, XVMIX_LAYER_MASTER, &Cfmt);
	Stream.PixPerClk = VMix.Mix.Config.PixPerClk;
	Stream.ColorFormatId = Cfmt;
	Stream.ColorDepth = VMix.Mix.Config.MaxDataWidth;
	TimingPtr = XVidC_GetTimingInfo(Stream.VmId);
	Stream.Timing = *TimingPtr;
	Stream.FrameRate = XVidC_GetFrameRate(Stream.VmId);

	XVMix_LayerDisable(&VMix, XVMIX_LAYER_MASTER);
	XVMix_LayerDisable(&VMix, XVMIX_LAYER_ALL);
	XVMix_SetVidStream(&VMix, &Stream);

	// Background color used when a streaming layer is disabled
	XVMix_SetBackgndColor(&VMix, XVMIX_BKGND_GREEN, Stream.ColorDepth);

	XVidC_VideoWindow Win;
	u32 Stride;
	for(u8 layerIndex = 0; layerIndex < NUM_CAMS; layerIndex++) {
		Win = MixLayerConfig[layerIndex];
		XVMix_GetLayerColorFormat(&VMix, layerIndex+1, &Cfmt);
		Stride = ((Cfmt == XVIDC_CSF_YCRCB_422) ? 2: 4); //BytesPerPixel
		Stride *= Win.Width;
		Status = XVMix_SetLayerWindow(&VMix, layerIndex+1, &Win, Stride);
		if(Status != XST_SUCCESS) {
			xil_printf("ERROR: Failed to set window for Video Mixer layer %d\r\n",layerIndex+1);
		}
	}

	XVMix_LayerEnable(&VMix, XVMIX_LAYER_MASTER);
	XVMix_InterruptDisable(&VMix);
	XVMix_Start(&VMix);

	/*
	 * Initialize Remapper (for converting 2ppc to 1ppc)
	 */
    RemapCfg = XV_axi4s_remap_LookupConfig(XPAR_V_AXI4S_REMAP_DEVICE_ID);
    if(RemapCfg == NULL) {
        xil_printf("ERROR: AXI4S_REMAP device not found\r\n");
        return(XST_FAILURE);
    }
    Status = XV_axi4s_remap_CfgInitialize(&Remap, RemapCfg, RemapCfg->BaseAddress);
    if(Status != XST_SUCCESS) {
        xil_printf("ERROR: AXI4S_REMAP Initialization failed %d\r\n", Status);
        return(XST_FAILURE);
    }
    XV_axi4s_remap_Set_width(&Remap, TimingPtr->HActive);
    XV_axi4s_remap_Set_height(&Remap, TimingPtr->VActive);
    XV_axi4s_remap_Set_ColorFormat(&Remap, 0);
    XV_axi4s_remap_Set_inPixClk(&Remap, Remap.Config.PixPerClkIn);
    XV_axi4s_remap_Set_outPixClk(&Remap, Remap.Config.PixPerClkOut);
    XV_axi4s_remap_Set_inHDMI420(&Remap, 0);
    XV_axi4s_remap_Set_outHDMI420(&Remap, 0);
    XV_axi4s_remap_Set_inPixDrop(&Remap, 0);
    XV_axi4s_remap_Set_outPixRepeat(&Remap, 0);
    XV_axi4s_remap_WriteReg(RemapCfg->BaseAddress, XV_AXI4S_REMAP_CTRL_ADDR_AP_CTRL, 0x81);

	/*
	 * Initialize VTC
	 */
	VtcConfig = XVtc_LookupConfig(VTC_DEVICE_ID);
    XVtc_CfgInitialize(&VtcInst, VtcConfig, VtcConfig->BaseAddress);
    VtcTiming.HActiveVideo  = TimingPtr->HActive/Remap.Config.PixPerClkOut;
    VtcTiming.HFrontPorch   = TimingPtr->HFrontPorch/Remap.Config.PixPerClkOut;
    VtcTiming.HSyncWidth    = TimingPtr->HSyncWidth/Remap.Config.PixPerClkOut;
    VtcTiming.HBackPorch    = TimingPtr->HBackPorch/Remap.Config.PixPerClkOut;
    VtcTiming.HSyncPolarity = TimingPtr->HSyncPolarity;
    VtcTiming.VActiveVideo  = TimingPtr->VActive;
    VtcTiming.V0FrontPorch  = TimingPtr->F0PVFrontPorch;
    VtcTiming.V0SyncWidth   = TimingPtr->F0PVSyncWidth;
    VtcTiming.V0BackPorch   = TimingPtr->F0PVBackPorch;
    VtcTiming.VSyncPolarity = TimingPtr->VSyncPolarity;
    XVtc_SetGeneratorTiming(&VtcInst, &VtcTiming);
    XVtc_Enable(&VtcInst);
    XVtc_EnableGenerator(&VtcInst);
    XVtc_RegUpdateEnable(&VtcInst);

	/*
	 * Run the DisplayPort video example
	 */
	Xil_DCacheDisable();
	Xil_ICacheDisable();

	Status = DpdmaVideoExample(&RunCfg,&Intc,Stream.VmId);
	if (Status != XST_SUCCESS) {
			xil_printf("ERROR: DPDMA Video Example Test Failed\r\n");
			return XST_FAILURE;
	}

	/*
	 * Start the connected cameras and enable corresponding mixer layers
	 */
	for(int i = 0; i < NumActiveCams; i++) {
		pipe_start_camera(ActiveCams[i]);
		XVMix_LayerEnable(&VMix, ActiveCamIndex[i]+1);
	}

	while(1){
	}

    return 0;
}

