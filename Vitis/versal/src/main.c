/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * Baremetal example for the RPi Camera FMC (OP068) on the Versal boards (VCK190, VEK280).
 * Runs on the Cortex-A72 (standalone). It is the Versal counterpart of the AUBoard application
 * (microblaze/src): it finds the cameras that are connected, starts their video pipes and shows
 * all of them on the board's HDMI TX connector (DVI, 1080p60), each camera in its own quadrant:
 *
 * +-----------------------------------+
 * |            1920x1080              |
 * |  +-------------+-------------+    |
 * |  |    CAM0     |    CAM1     |    |
 * |  |   960x540   |   960x540   |    |
 * |  +-------------+-------------+    |
 * |  |    CAM2     |    CAM3     |    |
 * |  |   960x540   |   960x540   |    |
 * |  +-------------+-------------+    |
 * +-----------------------------------+
 *
 * Only the camera ports that exist in the target's design are used (vck190_fmcp1: CAM0, CAM2;
 * vck190_fmcp2: CAM1, CAM2, CAM3; vek280: CAM0, CAM1, CAM3); an unused quadrant shows the
 * mixer's blue background.
 *
 * Camera-to-DDR pipe (one per camera):
 *   sensor -> MIPI CSI-2 RX SS -> ISP pipeline -> Video Processing SS -> Frame Buffer Write -> DDR
 * DDR-to-display pipe:
 *   DDR -> Video Mixer (one memory layer per camera) -> AXI4-S to Video Out (VTC 1080p60)
 *       -> DVI encoder + transceivers -> retimer/redriver -> HDMI connector
 *
 * Bring-up order: FMC VADJ (VCK190) -> IP resets (PMC GPIO) -> DVI output (clock generator,
 * retimer, transceivers) -> mixer + VTC -> cameras.
 *
 * UART commands (115200 8N1): 's' print status, 'p' toggle the DVI colour-bar test pattern.
 */

#include "xparameters.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xil_assert.h"
#include "xiltimer.h"
#include "xuartpsv_hw.h"
#include "sleep.h"
#include "board.h"
#include "config.h"
#include "vadj.h"
#include "resets.h"
#include "dvi.h"
#include "display.h"
#include "cam_pipe.h"

static void assert_callback(const char8 *file, s32 line)
{
	xil_printf("ASSERT: %s line %d\r\n", file, line);
}

static void print_status(XTime t_frames, XTime now)
{
	u32 ms = (u32)((now - t_frames) * 1000 / COUNTS_PER_SECOND);
	for (unsigned i = 0; i < cam_num_ports(); i++) {
		CamPipe *p = cam_pipe(i);
		if (!p->active)
			continue;
		u32 fps10 = ms ? (p->frames * 10000 + ms / 2) / ms : 0;
		u32 isr = cam_csi_isr(p, 1);
		/* ISR bit 31 = frame received, bit 17 = lanes in stop state, bit 18 = stream line
		 * buffer full at stream start/stop: all benign; anything else is a CSI-2 error */
		xil_printf("  CAM%d: %d.%d fps, CSI-2 ISR 0x%08x (%s), packets 0x%04x\r\n", p->port,
			   fps10 / 10, fps10 % 10, isr, (isr & ~0x80060000) ? "ERRORS" : "no errors",
			   cam_csi_packets(p));
		p->frames = 0;
	}
	dvi_print_status();
}

int main(void)
{
	int status;
	unsigned num_active = 0;

	Xil_AssertSetCallback(assert_callback);
	xil_printf("\r\n\r\n");
	xil_printf("################################################\r\n");
	xil_printf("#    Raspberry Pi Camera to DVI/HDMI Example   #\r\n");
	xil_printf("#    For the Opsero RPi Camera FMC (OP068)     #\r\n");
	xil_printf("################################################\r\n");
	xil_printf("Board: %s, Vitis %s, %d camera port(s) in the design\r\n\r\n",
		   BOARD_NAME, VITIS_VERSION, cam_num_ports());

	/* 1. FMC VADJ must be up before anything on the FMC is accessed */
	if (vadj_init() != XST_SUCCESS)
		xil_printf("ERROR: FMC VADJ could not be set, the cameras will not respond\r\n");

	/* 2. IP resets (all asserted) */
	if (resets_init() != XST_SUCCESS) {
		xil_printf("ERROR: PMC GPIO (IP resets) init failed\r\n");
		return XST_FAILURE;
	}

	/* 3. DVI output: pixel clock, retimer/redriver, transceivers */
	status = dvi_init();
	if (status != XST_SUCCESS)
		xil_printf("ERROR: DVI output not up (continuing)\r\n");

	/* 4. Mixer (background) + VTC: the monitor shows a blue screen from here on */
	if (display_init() != XST_SUCCESS) {
		xil_printf("ERROR: display pipeline init failed\r\n");
		return XST_FAILURE;
	}
	xil_printf("Display: 1080p60, mixer with %d layers\r\n\r\n", display_num_layers());

	/* 5. Cameras */
	xil_printf("Detecting cameras:\r\n");
	for (unsigned i = 0; i < cam_num_ports(); i++) {
		status = cam_detect(i);
		CamPipe *p = cam_pipe(i);
		xil_printf("  - CAM%d: %s\r\n", p->port, status == XST_SUCCESS ? p->sensor : "not connected");
		if (status == XST_SUCCESS && p->Camera.sensor.model == RPI_CAM_TYPE_OV5640)
			xil_printf("    (the ISP's Bayer pattern is RGGB: OV5640 colours will be wrong)\r\n");
	}
	xil_printf("\r\nStarting cameras:\r\n");
	for (unsigned i = 0; i < cam_num_ports(); i++) {
		CamPipe *p = cam_pipe(i);
		if (p->sensor == NULL)
			continue;
		status = cam_start(i, num_active + 1);
		xil_printf("  - CAM%d: %s (mixer layer %d, quadrant %d)\r\n", p->port,
			   status == XST_SUCCESS ? "SUCCESS" : "FAILED", num_active + 1, p->port);
		if (status == XST_SUCCESS)
			num_active++;
	}
	if (num_active == 0)
		xil_printf("\r\nNo cameras running: the display shows the background only.\r\n");
	xil_printf("\r\nRunning. Commands: 's' = status, 'p' = DVI test pattern on/off\r\n");

	/* Main loop: frame buffer rotation, periodic status */
	XTime t0, now, t_frames, t_next;
	XTime_GetTime(&t0);
	t_frames = t0;
	t_next = t0 + (XTime)5 * COUNTS_PER_SECOND;   /* first status after 5 s, then every 60 s */
	int pattern = 0;
	for (;;) {
		for (unsigned i = 0; i < cam_num_ports(); i++)
			cam_poll(cam_pipe(i));

		XTime_GetTime(&now);
		int show = 0;
		if (now >= t_next) {
			show = 1;
			t_next = now + (XTime)60 * COUNTS_PER_SECOND;
		}
		if (XUartPsv_IsReceiveData(STDIN_BASEADDRESS)) {
			char c = XUartPsv_RecvByte(STDIN_BASEADDRESS);
			if (c == 's')
				show = 1;
			else if (c == 'p') {
				pattern = !pattern;
				dvi_pattern(pattern);
				xil_printf("DVI test pattern %s\r\n", pattern ? "on" : "off");
			}
		}
		if (show) {
			xil_printf("Status after %d s:\r\n", (u32)((now - t0) / COUNTS_PER_SECOND));
			print_status(t_frames, now);
			t_frames = now;
		}
	}
	return 0;
}
