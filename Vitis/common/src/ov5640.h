/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 * Credit to Adam Taylor https://www.adiuvoengineering.com/post/microzed-chronicles-kria-raspberry-pi-camera
 */

#ifndef OV5640_H_
#define OV5640_H_

#include "xil_types.h"
#include "rpi_cam.h"

#define IIC_OV5640_ADDR		0x3c
#define SIZEOF_ARRAY(x) sizeof(x)/sizeof(x[0])
#define MAP_ENUM_TO_CFG(en, cfg) en, cfg, SIZEOF_ARRAY(cfg)

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
int ov5640_config(RpiCamera *camera,vmode_t mode,awb_t awb);
int ov5640_detect(RpiCamera *camera);

/*
 * Internal functions
 * These functions are intended for use internal to this library
 */
int ov5640_reset(RpiCamera *camera);
int ov5640_writeReg(RpiCamera *camera,uint16_t addr, uint8_t data);
int ov5640_readReg(RpiCamera *camera,uint16_t addr, uint8_t *data);
int ov5640_write_config(RpiCamera *camera,config_word_t const *cfg, size_t len);

#endif /* OV5640_H_ */
