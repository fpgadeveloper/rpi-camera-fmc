/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 */

#ifndef DVI_H_
#define DVI_H_

#include "xil_types.h"

int  dvi_init(void);          /* clock generator, retimer/redriver, transceiver restart, link check */
u32  dvi_status(void);        /* raw status register (Vivado/src/hdl/dvi/dvi_ctrl.v) */
void dvi_print_status(void);
void dvi_pattern(int on);     /* colour-bar test pattern with the encoder's own timing */

#endif /* DVI_H_ */
