/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 * A simple interrupt based driver for AXI IIC and PS IIC.
 * This driver allows device drivers to use the IIC bus without being
 * concerned about the underlying IP (AXI IIC or PS IIC). Each bus that
 * is initialized is given an index that the device drivers can use to
 * make reads/writes on the bus.
 *
 * Limitations: Only supports XSCUGIC interrupt controller.
 */

#ifndef I2C_AXI_H_
#define I2C_AXI_H_

#include "xparameters.h"
#include "xiic.h"
#include "xiicps.h"
#include "xil_exception.h"

//#include "xintc.h"
#include "xscugic.h"

#define IIC_SCLK_RATE		100000
#define INTC_HANDLER	XScuGic_InterruptHandler

// Types of IIC that can be used with this driver
#define IIC_TYPE_AXI_IIC 0
#define IIC_TYPE_PS_IIC  1

typedef struct {
	volatile void *Iic;
	volatile u8 IicType;
	volatile u8 TransmitComplete;
	volatile u8 ReceiveComplete;
	volatile u8 ErrorCount;
} IicIntHandlerInfo;


int IicWrite(u8 index,u8 addr,u8 *buf, u16 len);
int IicRead(u8 index,u8 addr, u8 *buf, u16 len);
int IicReset(u8 index);

/*
 * AXI IIC functions
 */
int IicAxiInit(XIic *IicInstance, u16 DeviceId, XScuGic *Intc, u16 VectorId, u8 *Index);
int IicAxiWrite(u8 index, u8 addr,u8 *buf, u16 len);
int IicAxiRead(u8 index, u8 addr, u8 *buf, u16 len);

void IicAxiSendHandler(IicIntHandlerInfo *Info);
void IicAxiRecvHandler(IicIntHandlerInfo *Info);
void IicAxiStatusHandler(IicIntHandlerInfo *Info, int Event);

/*
 * PS IIC functions
 */
int IicPsInit(XIicPs *IicInstance, u16 DeviceId, XScuGic *Intc, u16 VectorId, u8 *Index);
void IicPsInterruptHandler(IicIntHandlerInfo *Info, u32 Event);
int IicPsWrite(u8 index, u8 addr, u8 *buf,u16 len);
int IicPsRead(u8 index, u8 addr, u8 *buf,u16 len);

#endif /* AXI_I2C_H_ */
