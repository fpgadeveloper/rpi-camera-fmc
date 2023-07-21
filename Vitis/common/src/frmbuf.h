/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 */

#ifndef FRMBUF_H_
#define FRMBUF_H_

#include "xparameters.h"
#include "xv_frmbufrd_l2.h"
#include "xv_frmbufwr_l2.h"
#include "xil_exception.h"
#include "xscugic.h"

// Frmbuf struct
typedef struct {
	XV_FrmbufWr_l2 FrmbufWr;
	XV_FrmbufRd_l2 FrmbufRd;
	u64 FrmbufBufrBaseAddr;
	u64 FrmbufWrBufrAddr;
	u64 FrmbufRdBufrAddr;
} Frmbuf;

// Main functions for use by the outside
int FrmbufWrInit(Frmbuf *Frmbuf, u16 DeviceId, XScuGic *Intc, u16 VectorId, u64 BufrBaseAddr);
int FrmbufRdInit(Frmbuf *Frmbuf, u16 DeviceId, XScuGic *Intc, u16 VectorId, u64 BufrBaseAddr);
int FrmbufStart(Frmbuf *Frmbuf);

// Callback (ISR) functions
void *FrmbufRdCallback(void *data);
void *FrmbufWrCallback(void *data);

// Stride calculator (should probably be placed in a module with other useful video calc functions)
static u32 CalcStride(XVidC_ColorFormat Cfmt,u16 AXIMMDataWidth,XVidC_VideoStream *StreamPtr);

#endif /* FRMBUF_H_ */
