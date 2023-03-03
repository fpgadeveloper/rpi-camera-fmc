/*
 * Opsero Electronic Design Inc. Copyright 2022
 *
 */

#ifndef OV5640_H_
#define OV5640_H_

#include "xil_types.h"
#include "board.h"

#if defined (BOARD_PYNQZU_PCAM)
// PYNQ-ZU PCAM design uses IIC in the PS
#include "xiicps.h"
#define XIIC_TYPE XIicPs

#else
// All other designs use AXI IIC
#include "xiic.h"
#define XIIC_TYPE XIic

#endif

#define IIC_OV5640_ADDR		0x3c
#define SIZEOF_ARRAY(x) sizeof(x)/sizeof(x[0])
#define MAP_ENUM_TO_CFG(en, cfg) en, cfg, SIZEOF_ARRAY(cfg)

typedef struct { uint16_t addr; uint8_t data; } config_word_t;
typedef enum { MODE_720P_1280_720_60fps = 0, MODE_1080P_1920_1080_15fps,
	MODE_1080P_1920_1080_30fps, MODE_1080P_1920_1080_30fps_336M_MIPI,
	MODE_1080P_1920_1080_30fps_336M_1LANE_MIPI, MODE_END } vmode_t;
typedef struct { vmode_t mode; config_word_t const* cfg; size_t cfg_size; } config_modes_t;
typedef enum { AWB_DISABLED = 0, AWB_SIMPLE, AWB_ADVANCED, AWB_END } awb_t;
typedef struct { awb_t awb; config_word_t const* cfg; size_t cfg_size; } config_awb_t;

/*
 * Public functions
 * These functions are intended to be called by the user
 */
int ov5640_init(XIIC_TYPE *iic_inst,XGpio *gpio_inst,uint8_t gpio_mask);
int ov5640_config(vmode_t mode,awb_t awb);
int ov5640_detect();

/*
 * Internal functions
 * These functions are intended for use internal to this library
 */
int ov5640_reset();
int ov5640_writeReg(uint16_t addr, uint8_t data);
int ov5640_readReg(uint16_t addr, uint8_t *data);
int ov5640_write_config(config_word_t const *cfg, size_t len);

#endif /* OV5640_H_ */
