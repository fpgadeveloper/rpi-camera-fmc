/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 *
 * FMC VADJ for the RPi Camera FMC.
 *
 * VCK190: VADJ (shared by FMCP1 and FMCP2) comes from the IR38164 buck regulator U185 at I2C
 * address 0x1E, behind the mux at 0x74 (channel 0) on the PS LPD I2C0 (0xFF020000). In the Linux
 * images u-boot sets it to 1.2 V (vck190-vadj-1v2-bootcmd.cfg in the Yocto BSPs); a baremetal
 * boot has no u-boot, so this application writes the same register sequence before it touches
 * the cameras. Without it the FMC is unpowered and the camera I2C buses are dead.
 *
 * VEK280: VADJ is fixed (1.5 V) by the board, nothing to do.
 */

#include "vadj.h"
#include "config.h"
#include "xil_printf.h"
#include "sleep.h"

#if defined(BOARD_VCK190)
#include "xiicps.h"

#define VADJ_IIC_BASE   XPAR_I2C0_BASEADDR   /* LPD I2C0 = u-boot "i2c dev 3" */
#define VADJ_MUX_ADDR   0x74
#define VADJ_MUX_CH0    0x01
#define VADJ_REG_ADDR   0x1E                 /* IR38164 */

/* IR38164 "vadj_1v2_en" profile: VOUT 0x0133 (1/256 V LSB) = 1.199 V; enable (0x22) last */
static const u8 vadj_1v2[][2] = {
	{0x24, 0x01}, {0x25, 0x33}, {0x3A, 0x01}, {0x3B, 0x8F}, {0x3D, 0x01}, {0x3E, 0x8F},
	{0x3F, 0x00}, {0x40, 0x00}, {0x41, 0x00}, {0x42, 0x00}, {0x22, 0x80}
};

static XIicPs Iic;

static int ps_write(u8 addr, u8 *buf, int len)
{
	int st = XIicPs_MasterSendPolled(&Iic, buf, len, addr);
	while (XIicPs_BusIsBusy(&Iic))
		;
	return st;
}

static int ps_read_reg(u8 addr, u8 reg, u8 *val)
{
	if (ps_write(addr, &reg, 1) != XST_SUCCESS)
		return XST_FAILURE;
	int st = XIicPs_MasterRecvPolled(&Iic, val, 1, addr);
	while (XIicPs_BusIsBusy(&Iic))
		;
	return st;
}

int vadj_init(void)
{
	XIicPs_Config *cfg = XIicPs_LookupConfig(VADJ_IIC_BASE);
	if (cfg == NULL || XIicPs_CfgInitialize(&Iic, cfg, cfg->BaseAddress) != XST_SUCCESS) {
		xil_printf("VADJ: PS I2C0 init failed\r\n");
		return XST_FAILURE;
	}
	XIicPs_SetSClk(&Iic, 100000);

	u8 mux = VADJ_MUX_CH0;
	if (ps_write(VADJ_MUX_ADDR, &mux, 1) != XST_SUCCESS) {
		xil_printf("VADJ: I2C mux 0x74 does not answer\r\n");
		return XST_FAILURE;
	}
	for (unsigned i = 0; i < sizeof(vadj_1v2) / sizeof(vadj_1v2[0]); i++) {
		u8 buf[2] = { vadj_1v2[i][0], vadj_1v2[i][1] };
		if (ps_write(VADJ_REG_ADDR, buf, 2) != XST_SUCCESS) {
			xil_printf("VADJ: IR38164 write 0x%02x failed\r\n", buf[0]);
			return XST_FAILURE;
		}
	}
	usleep(50000);   /* let the rail and the FMC devices come up */

	u8 hi = 0, lo = 0, en = 0;
	if (ps_read_reg(VADJ_REG_ADDR, 0x24, &hi) != XST_SUCCESS ||
	    ps_read_reg(VADJ_REG_ADDR, 0x25, &lo) != XST_SUCCESS ||
	    ps_read_reg(VADJ_REG_ADDR, 0x22, &en) != XST_SUCCESS) {
		xil_printf("VADJ: IR38164 read back failed\r\n");
		return XST_FAILURE;
	}
	u32 mv = ((((u32)hi << 8) | lo) * 1000 + 128) / 256;
	xil_printf("VADJ: IR38164 VOUT 0x%02x%02x = %d.%03d V, enable 0x%02x\r\n",
		   hi, lo, mv / 1000, mv % 1000, en);
	return (en & 0x80) ? XST_SUCCESS : XST_FAILURE;
}

#else

int vadj_init(void)
{
	xil_printf("VADJ: fixed by the board (nothing to set)\r\n");
	return XST_SUCCESS;
}

#endif
