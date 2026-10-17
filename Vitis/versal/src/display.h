/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 */

#ifndef DISPLAY_H_
#define DISPLAY_H_

#include "xil_types.h"

int      display_init(void);   /* mixer (background only) + VTC 1080p60 */
int      display_layer_setup(unsigned layer, unsigned quad, UINTPTR buf);
void     display_layer_enable(unsigned layer);
void     display_layer_buffer(unsigned layer, UINTPTR buf);
unsigned display_num_layers(void);

#endif /* DISPLAY_H_ */
