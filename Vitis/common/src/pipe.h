/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 */

#ifndef PIPE_H_
#define PIPE_H_

#include "xil_types.h"
#include "xgpio.h"
#include "xiic.h"
#include "board.h"
#include "rpi_cam.h"
#include "xaxivdma.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xscugic.h"

// Camera GPIO masks
#define GPIO_CAM_IO0_MASK	0x01
#define GPIO_CAM_IO1_MASK	0x02

// Memory for the frame buffers
#define DDR_BASE_ADDR		XPAR_PSU_DDR_0_S_AXI_BASEADDR
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x01000000)
#define FRAME_BUF_ADDR_BASE	(MEM_BASE_ADDR + 0x02000000)

// VideoPipe struct
typedef struct {
	uint8_t IsConnected;
	XIic Iic;
	XGpio Gpio;
	XAxiVdma Vdma;
	XV_demosaic Demosaic;
	XV_gamma_lut GammaLut;
	RpiCamera Camera;
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
int pipe_start_camera(VideoPipe *pipe);

#endif /* PIPE_H_ */
