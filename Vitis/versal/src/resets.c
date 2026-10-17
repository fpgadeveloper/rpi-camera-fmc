/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * IP resets of the Versal design: active-low outputs on the PMC GPIO EMIO. Bit map in config.h
 * (same as the Linux device tree reset-gpios: gpio1 pin 52 + bit).
 *
 * Only the pins of these resets are touched, one by one: the same GPIO banks also carry other
 * signals (e.g. the PL fabric resets), so whole-bank writes are not allowed here.
 */

#include "resets.h"
#include "config.h"
#include "xgpiops.h"
#include "xparameters.h"
#include "sleep.h"

#define EMIO_PIN_BASE   52   /* PMC GPIO: EMIO bit 0 = pin 52 (bank 3), bit 32 = pin 84 (bank 4) */

static XGpioPs PmcGpio;

static void pin_setup(unsigned bit)
{
	u32 pin = EMIO_PIN_BASE + bit;
	XGpioPs_WritePin(&PmcGpio, pin, 0);          /* asserted */
	XGpioPs_SetDirectionPin(&PmcGpio, pin, 1);
	XGpioPs_SetOutputEnablePin(&PmcGpio, pin, 1);
}

int resets_init(void)
{
	XGpioPs_Config *cfg = XGpioPs_LookupConfig(XPAR_XGPIOPS_0_BASEADDR);
	if (cfg == NULL)
		return XST_FAILURE;
	PmcGpio.PmcGpio = 1;   /* the driver does not detect it: PMC bank layout (pins 0..115) */
	if (XGpioPs_CfgInitialize(&PmcGpio, cfg, cfg->BaseAddr) != XST_SUCCESS)
		return XST_FAILURE;
	/* every reset of the design asserted (all four camera ports, unused ones are harmless) */
	pin_setup(RST_BIT_VMIX);
	for (unsigned n = 0; n < 4; n++) {
		pin_setup(RST_BIT_ISP(n));
		pin_setup(RST_BIT_VPROC(n));
		pin_setup(RST_BIT_FRMBUF(n));
	}
	usleep(1000);
	return XST_SUCCESS;
}

void reset_release(unsigned bit)
{
	XGpioPs_WritePin(&PmcGpio, EMIO_PIN_BASE + bit, 1);
	usleep(100);
}

void reset_assert(unsigned bit)
{
	XGpioPs_WritePin(&PmcGpio, EMIO_PIN_BASE + bit, 0);
	usleep(100);
}
