/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 * Credit to Adam Taylor https://www.adiuvoengineering.com/post/microzed-chronicles-kria-raspberry-pi-camera
 */

#ifndef OV5640_H_
#define OV5640_H_

#include "xil_types.h"
#include "xgpio.h"

#define IIC_OV5640_ADDR		0x3c
#define SIZEOF_ARRAY(x) sizeof(x)/sizeof(x[0])
#define MAP_ENUM_TO_CFG(en, cfg) en, cfg, SIZEOF_ARRAY(cfg)

// Register address and value
typedef struct {
	uint16_t addr;
	uint8_t data;
} config_word_t;

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
int ov5640_config(uint8_t iic_id,XGpio *gpio,uint8_t gpio_mask);
int ov5640_detect(uint8_t iic_id);

/*
 * Internal functions
 * These functions are intended for use internal to this library
 */
int ov5640_reset(XGpio *gpio,uint8_t gpio_mask);
int ov5640_write(uint8_t iic_id,uint16_t addr, uint8_t data);
int ov5640_read(uint8_t iic_id,uint16_t addr, uint8_t *data);
int ov5640_write_config(uint8_t iic_id,config_word_t const *cfg, size_t len);

#endif /* OV5640_H_ */
