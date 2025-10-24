/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * Credit to Greg Taylor https://github.com/gtaylormb/ultra96v2_imx219_to_displayport
 */
#ifndef IMX219_H_
#define IMX219_H_

#include <stdint.h>
#include "xgpio.h"

#define IMX219_I2C_SLAVE_ADDR  0x10

/* Lens */
/* infinity, 0 current */
#define IMX219_LENS_MIN					0
/* macro, max current */
#define IMX219_LENS_MAX					255
#define IMX219_LENS_STEP				1
/* AEC */
#define IMX219_DEFAULT_EXP		                10000
#define IMX219_DEFAULT_GAIN		                UINT8P8(1.0)
#define IMX219_GAIN_MIN					UINT8P8(1.0)
#define IMX219_GAIN_MAX					UINT8P8(8.0)
#define IMX219_EXP_MIN					1
#define IMX219_ANA_GAIN_GLOBAL                          0x0157
#define IMX219_COARSE_INT_TIME_HI                       0x015A
#define IMX219_COARSE_INT_TIME_LO                       0x015B
#define IMX219_FRM_LENGTH_HI                            0x0160
#define IMX219_FRM_LENGTH_LO                            0x0161

// Register address and value
typedef struct {
	uint16_t addr;
	uint8_t data;
} imx219_config_word_t;

int imx219_detect(uint8_t iic_id);
int imx219_config(uint8_t iic_id,XGpio *gpio,uint32_t gpio_mask);
int imx219_reset(XGpio *gpio,uint32_t gpio_mask);
int imx219_write(uint8_t iic_id,u16 addr, u8 data);
int imx219_read(uint8_t iic_id,u16 addr, u8 *data);

#endif /* IMX219_H_ */
