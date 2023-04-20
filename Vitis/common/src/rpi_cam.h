/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 */

#ifndef RPI_CAM_H_
#define RPI_CAM_H_

#include "xil_types.h"
#include "xgpio.h"

// Supported camera types
#define RPI_CAM_TYPE_OV5640 0
#define RPI_CAM_TYPE_IMX219 1

// Register address and value
typedef struct {
	uint16_t addr;
	uint8_t data;
} config_word_t;

// Sensor container
typedef struct {
	uint8_t model;
	uint8_t iic_addr;
} Sensor;

// RPi camera container
typedef struct {
	uint8_t iic_id;
	XGpio *gpio;
	uint8_t gpio_mask;
	Sensor sensor;
} RpiCamera;

int rpi_cam_init(RpiCamera *camera,uint8_t iic_id,XGpio *gpio_inst,uint8_t gpio_mask);
int rpi_cam_config(RpiCamera *camera);
int rpi_cam_detect(RpiCamera *camera);

#endif /* RPI_CAM_H_ */
