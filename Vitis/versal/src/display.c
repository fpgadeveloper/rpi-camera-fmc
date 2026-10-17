/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * Display pipeline: Video Mixer (reads the camera frame buffers from DDR, RGB output) and the
 * Video Timing Controller (1080p60 generator, pixel clock = DVI 148.5 MHz) that times the
 * AXI4-Stream to Video Out bridge in front of the DVI encoder.
 *
 * The mixer's streaming master layer has no source in this design (tied off), so it stays
 * disabled and the mixer shows its background colour wherever no camera layer is enabled.
 */

#include "display.h"
#include "config.h"
#include "resets.h"
#include "xv_mix_l2.h"
#include "xvtc.h"
#include "xvidc.h"
#include "xil_printf.h"
#include "sleep.h"

static XV_Mix_l2 VMix;
static XVtc Vtc;

static int vtc_start(void)
{
	XVtc_Config *cfg = XVtc_LookupConfig(XPAR_DISPLAY_PIPELINE_V_TC_0_BASEADDR);
	if (cfg == NULL || XVtc_CfgInitialize(&Vtc, cfg, cfg->BaseAddress) != XST_SUCCESS) {
		xil_printf("Display: VTC init failed\r\n");
		return XST_FAILURE;
	}
	XVtc_Timing timing = {0};
	XVtc_ConvVideoMode2Timing(&Vtc, XVTC_VMODE_1080P, &timing);
	timing.Interlaced = 0;

	/* All generator values come from the registers we program */
	XVtc_SourceSelect src = {0};
	src.VChromaSrc = 1; src.VActiveSrc = 1; src.VBackPorchSrc = 1; src.VSyncSrc = 1;
	src.VFrontPorchSrc = 1; src.VTotalSrc = 1; src.HActiveSrc = 1; src.HBackPorchSrc = 1;
	src.HSyncSrc = 1; src.HFrontPorchSrc = 1; src.HTotalSrc = 1;
	src.FieldIdPolSrc = 1; src.ActiveChromaPolSrc = 1; src.ActiveVideoPolSrc = 1;
	src.HSyncPolSrc = 1; src.VSyncPolSrc = 1; src.HBlankPolSrc = 1; src.VBlankPolSrc = 1;

	/* 1080p60: positive syncs, active-high blank/active */
	XVtc_Polarity pol = {0};
	pol.ActiveChromaPol = 1; pol.ActiveVideoPol = 1; pol.FieldIdPol = 1;
	pol.VBlankPol = 1; pol.VSyncPol = 1; pol.HBlankPol = 1; pol.HSyncPol = 1;

	XVtc_DisableGenerator(&Vtc);
	XVtc_SetSource(&Vtc, &src);
	XVtc_SetGeneratorTiming(&Vtc, &timing);
	XVtc_SetPolarity(&Vtc, &pol);
	XVtc_RegUpdateEnable(&Vtc);
	XVtc_EnableGenerator(&Vtc);
	return XST_SUCCESS;
}

int display_init(void)
{
	reset_release(RST_BIT_VMIX);
	if (XVMix_Initialize(&VMix, XPAR_DISPLAY_PIPELINE_V_MIX_0_BASEADDR) != XST_SUCCESS) {
		xil_printf("Display: video mixer init failed\r\n");
		return XST_FAILURE;
	}

	XVidC_VideoStream stream = {0};
	stream.VmId          = XVIDC_VM_1920x1080_60_P;
	stream.Timing        = *XVidC_GetTimingInfo(stream.VmId);
	stream.FrameRate     = XVIDC_FR_60HZ;
	stream.ColorFormatId = XVIDC_CSF_RGB;
	stream.ColorDepth    = (XVidC_ColorDepth)VMix.Mix.Config.MaxDataWidth;
	stream.PixPerClk     = (XVidC_PixelsPerClock)VMix.Mix.Config.PixPerClk;
	XVMix_SetVidStream(&VMix, &stream);

	XVMix_LayerDisable(&VMix, XVMIX_LAYER_ALL);
	XVMix_LayerDisable(&VMix, XVMIX_LAYER_MASTER);
	XVMix_SetBackgndColor(&VMix, XVMIX_BKGND_BLUE, stream.ColorDepth);
	XVMix_InterruptDisable(&VMix);
	XVMix_Start(&VMix);

	return vtc_start();
}

/* Memory layer <layer> (1..) shows a camera in quadrant <quad> (0..3) */
int display_layer_setup(unsigned layer, unsigned quad, UINTPTR buf)
{
	XVidC_VideoWindow win;
	win.StartX = (quad & 1) ? QUAD_WIDTH : 0;
	win.StartY = (quad & 2) ? QUAD_HEIGHT : 0;
	win.Width  = QUAD_WIDTH;
	win.Height = QUAD_HEIGHT;

	XVidC_ColorFormat cfmt;
	XVMix_GetLayerColorFormat(&VMix, layer, &cfmt);
	if (cfmt != XVIDC_CSF_MEM_YUYV8)
		xil_printf("Display: mixer layer %d is not YUYV (format %d)\r\n", layer, cfmt);
	if (XVMix_SetLayerWindow(&VMix, layer, &win, QUAD_STRIDE) != XST_SUCCESS) {
		xil_printf("Display: mixer layer %d window failed\r\n", layer);
		return XST_FAILURE;
	}
	if (XVMix_SetLayerBufferAddr(&VMix, layer, buf) != XST_SUCCESS) {
		xil_printf("Display: mixer layer %d buffer address failed\r\n", layer);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

void display_layer_enable(unsigned layer)
{
	XVMix_LayerEnable(&VMix, layer);
}

void display_layer_buffer(unsigned layer, UINTPTR buf)
{
	XVMix_SetLayerBufferAddr(&VMix, layer, buf);
}

unsigned display_num_layers(void)
{
	return VMix.Mix.Config.NumLayers;
}
