/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * Polled AXI IIC back end of the i2c.h interface (used by the camera drivers in common/src).
 *
 * The Versal application runs without interrupts: every transfer uses the AXI IIC low-level
 * polled routines (XIic_Send / XIic_Recv). The MicroBlaze application keeps its interrupt
 * driven implementation (microblaze/src/i2c.c).
 */

#include "i2c.h"
#include "xiic_l.h"
#include "xil_printf.h"
#include "sleep.h"

#define IIC_MAX_INSTANCES 8

static UINTPTR IicBase[IIC_MAX_INSTANCES];
static u8 IicNum = 0;

/* Reset the AXI IIC core and clear its FIFOs */
static void iic_core_reset(UINTPTR base)
{
	XIic_WriteReg(base, XIIC_RESETR_OFFSET, XIIC_RESET_MASK);
	usleep(100);
	XIic_WriteReg(base, XIIC_CR_REG_OFFSET, XIIC_CR_TX_FIFO_RESET_MASK);
	XIic_WriteReg(base, XIIC_CR_REG_OFFSET, XIIC_CR_ENABLE_DEVICE_MASK);
}

/* Register an AXI IIC by base address; returns its index for IicWrite/IicRead */
int IicAxiInit(XIic *IicInstance, UINTPTR BaseAddr, u8 *Index)
{
	(void)IicInstance;
	if (IicNum >= IIC_MAX_INSTANCES)
		return XST_FAILURE;
	iic_core_reset(BaseAddr);
	IicBase[IicNum] = BaseAddr;
	*Index = IicNum++;
	return XST_SUCCESS;
}

int IicAxiWrite(u8 index, u8 addr, u8 *buf, u16 len)
{
	if (index >= IicNum)
		return XST_FAILURE;
	unsigned sent = XIic_Send(IicBase[index], addr, buf, len, XIIC_STOP);
	if (sent != len) {
		iic_core_reset(IicBase[index]);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

int IicAxiRead(u8 index, u8 addr, u8 *buf, u16 len)
{
	if (index >= IicNum)
		return XST_FAILURE;
	unsigned got = XIic_Recv(IicBase[index], addr, buf, len, XIIC_STOP);
	if (got != len) {
		iic_core_reset(IicBase[index]);
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

int IicWrite(u8 index, u8 addr, u8 *buf, u16 len) { return IicAxiWrite(index, addr, buf, len); }
int IicRead(u8 index, u8 addr, u8 *buf, u16 len)  { return IicAxiRead(index, addr, buf, len); }

int IicReset(u8 index)
{
	if (index >= IicNum)
		return XST_FAILURE;
	iic_core_reset(IicBase[index]);
	return XST_SUCCESS;
}

/* Unused by this application, kept so i2c.h's declarations resolve */
void IicAxiSendHandler(IicIntHandlerInfo *Info) { (void)Info; }
void IicAxiRecvHandler(IicIntHandlerInfo *Info) { (void)Info; }
void IicAxiStatusHandler(IicIntHandlerInfo *Info, int Event) { (void)Info; (void)Event; }
