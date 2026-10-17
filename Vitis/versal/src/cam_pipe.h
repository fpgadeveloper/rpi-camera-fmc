/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 */

#ifndef CAM_PIPE_H_
#define CAM_PIPE_H_

#include "xil_types.h"
#include "xgpio.h"
#include "xv_hscaler_l2.h"
#include "xv_vscaler_l2.h"
#include "xv_frmbufwr_l2.h"
#include "rpi_cam.h"
#include "imx219.h"
#include "config.h"

/* Base addresses of one camera port's IP (from xparameters.h) */
typedef struct {
	u8      port;
	UINTPTR iic, gpio, csi, isp, vsc, hsc, vproc_rst, frmbuf;
} CamPorts;

typedef struct {
	const CamPorts *ports;
	u8           port;          /* camera port = CAMn on the RPi Camera FMC = display quadrant */
	u8           iic_id;
	int          active;
	const char  *sensor;
	XGpio        Gpio;
	RpiCamera    Camera;
	XV_Vscaler_l2 Vsc;          /* v_proc_ss sub-cores */
	XV_Hscaler_l2 Hsc;
	XGpio        VprocRst;
	XV_FrmbufWr_l2 Frmbuf;
	UINTPTR      buf[FRMBUF_NUM];
	u32          seq;           /* frame buffer "done" count since start */
	u32          frames;        /* frames written (reset by the caller for rate measurement) */
	unsigned     layer;         /* mixer layer */
} CamPipe;

unsigned cam_num_ports(void);
CamPipe *cam_pipe(unsigned i);
int      cam_detect(unsigned i);
int      cam_start(unsigned i, unsigned layer);
void     cam_poll(CamPipe *p);
u32      cam_csi_isr(CamPipe *p, int clear);
u32      cam_csi_packets(CamPipe *p);

#endif /* CAM_PIPE_H_ */
