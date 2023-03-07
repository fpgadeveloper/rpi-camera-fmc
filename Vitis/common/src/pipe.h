/*
 * Opsero Electronic Design Inc. Copyright 2022
 *
 */

#ifndef PIPE_H_
#define PIPE_H_

#include "xil_types.h"
#include "xgpio.h"
#include "xiic.h"
#include "board.h"
#include "ov5640.h"

// Camera GPIO masks
#define GPIO_CAM_IO0_MASK	0x01
#define GPIO_CAM_IO1_MASK	0x01

// Memory for the frame buffers
#define DDR_BASE_ADDR		XPAR_PSU_DDR_0_S_AXI_BASEADDR
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x01000000)
#define FRAME_BUF_ADDR_BASE	(MEM_BASE_ADDR + 0x02000000)

// Video mode and frame size defines
//#define DEMO_VMODE_720P60     1
#define DEMO_VMODE_1080P30     1

#if defined (DEMO_VMODE_720P60)
#define VMODE_WIDTH			1280
#define VMODE_HEIGHT		720
#define VMODE_VTC           XVTC_VMODE_720P
#define VMODE_CAM			MODE_720P_1280_720_60fps
#define VMODE_DP			XVIDC_VM_1280x720_60_P
#define GAMMA               1/1.0
#define PIXEL_SIZE			8	// In bits
#define GAMMA_TABLE_SIZE	256  // 2^PIXEL_SIZE
#define FRAME_HORI_LEN	  	VMODE_WIDTH*3  // Each pixel is 3 bytes
#define FRAME_VERT_LEN		VMODE_HEIGHT
#define SUBFRAME_START_OFFSET    (FRAME_HORI_LEN * 5 + 64)
#endif
#if defined (DEMO_VMODE_1080P30)
#define VMODE_WIDTH			1920
#define VMODE_HEIGHT		1080
#define VMODE_VTC           XVTC_VMODE_1080P
#define VMODE_CAM			MODE_1080P_1920_1080_30fps
#define VMODE_DP			XVIDC_VM_1920x1080_30_P
#define GAMMA               1/1.0
#define PIXEL_SIZE			8	// In bits
#define GAMMA_TABLE_SIZE	256  // 2^PIXEL_SIZE
#define FRAME_HORI_LEN	  	VMODE_WIDTH*3  // Each pixel is 3 bytes
#define FRAME_VERT_LEN		VMODE_HEIGHT
#define SUBFRAME_START_OFFSET    (FRAME_HORI_LEN * 5 + 64)
#endif


// VideoPipe struct
typedef struct {
	XIic Iic;
	XGpio Gpio;
	XAxiVdma Vdma;
	XV_demosaic Demosaic;
	XV_gamma_lut GammaLut;
	OV5640 Ov5640;
} VideoPipe;

// VideoPipe device IDs
typedef struct {
	u16 Iic;
	u16 Gpio;
	u16 Vdma;
	u32 VdmaFrameBufOffset;
	u16 Demosaic;
	u16 GammaLut;
	u16 IicIntr;
} VideoPipeDevIds;

int pipe_init(VideoPipe *pipe, VideoPipeDevIds *devids, XScuGic *intc);
int config_camera(VideoPipe *pipe);

#endif /* PIPE_H_ */
