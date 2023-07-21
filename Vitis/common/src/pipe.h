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
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xvprocss_vdma.h"
#include "xscugic.h"
#include "frmbuf.h"

// Camera GPIO masks
#define GPIO_CAM_IO0_MASK	0x01
#define GPIO_CAM_IO1_MASK	0x02

// VideoPipe struct
typedef struct {
	uint8_t IsConnected;
	XIic Iic;
	XGpio Gpio;
	XV_demosaic Demosaic;
	XV_gamma_lut GammaLut;
	XVprocSs Vproc;
	RpiCamera Camera;
	Frmbuf Frmbuf;
} VideoPipe;

// VideoPipe device IDs
typedef struct {
	u16 Iic;
	u16 Gpio;
	u16 FrmbufWr;
	u16 FrmbufRd;
	u32 FrmbufBufrBaseAddr;
	u16 Demosaic;
	u16 GammaLut;
	u16 Vproc;
	u16 IicIntr;
	u16 FrmbufWrIntr;
	u16 FrmbufRdIntr;
} VideoPipeDevIds;

int pipe_init(VideoPipe *pipe, VideoPipeDevIds *devids, XScuGic *intc);
int pipe_start_camera(VideoPipe *pipe);

#endif /* PIPE_H_ */
