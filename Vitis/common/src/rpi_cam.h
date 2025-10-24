/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 */

#ifndef RPI_CAM_H_
#define RPI_CAM_H_

#include <stdint.h>
#include "xil_types.h"
#include "xgpio.h"

// Bayer patterns to bayer phases for Sensor Demosaic
// https://docs.xilinx.com/r/en-US/pg286-v-demosaic/BAYER_PHASE-0x0028-Register
#define BAYER_PATTERN_RGGB 0x00
#define BAYER_PATTERN_GRBG 0x01
#define BAYER_PATTERN_GBRG 0x02
#define BAYER_PATTERN_BGGR 0x03

// Supported camera types
#define RPI_CAM_TYPE_OV5640 0
#define RPI_CAM_TYPE_IMX219 1

// Sensor bayer patterns
#define RPI_CAM_BAYER_PAT_OV5640 BAYER_PATTERN_BGGR
#define RPI_CAM_BAYER_PAT_IMX219 BAYER_PATTERN_RGGB

// Sensor adapter
typedef struct {
	uint8_t model;
	uint8_t bayer_pattern;
	int (*config) (uint8_t,XGpio*,uint8_t);
	int (*detect) (uint8_t);
} Sensor;

// RPi camera container
typedef struct {
	uint8_t iic_id;
	XGpio *gpio;
	uint32_t gpio_mask;
	Sensor sensor;
} RpiCamera;

int rpi_cam_init(RpiCamera *camera,uint8_t iic_id,XGpio *gpio_inst,uint32_t gpio_mask);
int rpi_cam_config(RpiCamera *camera);
int rpi_cam_detect(RpiCamera *camera);
uint8_t rpi_cam_bayer_phase(RpiCamera *camera);

#endif /* RPI_CAM_H_ */
