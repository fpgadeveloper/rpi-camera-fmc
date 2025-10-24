/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 */

#ifndef PIPE_H_
#define PIPE_H_

#include "xil_types.h"
#include "xgpio.h"
#include "xiic.h"
#include "rpi_cam.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xvprocss_vdma.h"
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

// VideoPipe Base Addresses
typedef struct {
	UINTPTR Iic;
	UINTPTR Gpio;
	UINTPTR FrmbufWr;
	UINTPTR FrmbufRd;
	UINTPTR FrmbufBufrBaseAddr;
	UINTPTR Demosaic;
	UINTPTR GammaLut;
	UINTPTR Vproc;
} VideoPipeBaseAddr;

int pipe_init(VideoPipe *pipe, VideoPipeBaseAddr *baseaddr);
int pipe_start_camera(VideoPipe *pipe);

#endif /* PIPE_H_ */
