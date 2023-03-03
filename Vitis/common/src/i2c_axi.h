/*
 * Opsero Electronic Design Inc. Copyright 2022
 *
 * A simple interrupt based driver for AXI IIC
 */

#ifndef I2C_AXI_H_
#define I2C_AXI_H_

#include "xparameters.h"
#include "xiic.h"
#include "xil_exception.h"

//#include "xintc.h"
#include "xscugic.h"

//#define INTC_DEVICE_ID	XPAR_INTC_0_DEVICE_ID
#define INTC_HANDLER	XScuGic_InterruptHandler

int IicInit(XIic *IicInstance, u16 DeviceId, XScuGic *Intc, u16 VectorId);
int IicWrite(XIic *IicInstance, u8 addr,u8 *buf, u16 ByteCount);
int IicRead(XIic *IicInstance, u8 addr, u8 *BufferPtr, u16 ByteCount);

// Interrupt setup
int SetupInterruptSystem(XIic *IicInstPtr, XScuGic *Intc, u16 VectorId);

// I2C interrupt handlers
void IicSendHandler(XIic *InstancePtr);
void IicStartSendHandler(XIic *InstancePtr);
int IicSendComplete(XIic *InstancePtr);
void IicRecvHandler(XIic *InstancePtr);
void IicStartRecvHandler(XIic *InstancePtr);
int IicRecvComplete(XIic *InstancePtr);
void IicStatusHandler(XIic *InstancePtr, int Event);

#endif /* AXI_I2C_H_ */
