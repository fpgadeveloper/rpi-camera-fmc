/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * A simple interrupt based driver for AXI IIC and PS IIC.
 * This driver allows device drivers to use the IIC bus without being
 * concerned about the underlying IP (AXI IIC or PS IIC). Each bus that
 * is initialized is given an index that the device drivers can use to
 * make reads/writes on the bus.
 *
 */

#ifndef I2C_H_
#define I2C_H_

#include "xparameters.h"
#ifdef XPAR_XIIC_NUM_INSTANCES
#include "xiic.h"
#endif
#ifdef XPAR_XIICPS_NUM_INSTANCES
#include "xiicps.h"
#endif

#define IIC_SCLK_RATE		100000

// Types of IIC that can be used with this driver
#define IIC_TYPE_AXI_IIC 0
#define IIC_TYPE_PS_IIC  1

typedef struct {
	void *Iic;
	u8 IicType;
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
#ifdef XPAR_XIIC_NUM_INSTANCES
int IicAxiInit(XIic *IicInstance, UINTPTR BaseAddr, u8 *Index);
int IicAxiWrite(u8 index, u8 addr,u8 *buf, u16 len);
int IicAxiRead(u8 index, u8 addr, u8 *buf, u16 len);

void IicAxiSendHandler(IicIntHandlerInfo *Info);
void IicAxiRecvHandler(IicIntHandlerInfo *Info);
void IicAxiStatusHandler(IicIntHandlerInfo *Info, int Event);
#endif

/*
 * PS IIC functions
 */
#ifdef XPAR_XIICPS_NUM_INSTANCES
int IicPsInit(XIicPs *IicInstance, UINTPTR BaseAddr, u8 *Index);
void IicPsInterruptHandler(IicIntHandlerInfo *Info, u32 Event);
int IicPsWrite(u8 index, u8 addr, u8 *buf,u16 len);
int IicPsRead(u8 index, u8 addr, u8 *buf,u16 len);
#endif

#endif /* I2C_H_ */
