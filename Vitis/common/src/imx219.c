/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * Credit to Greg Taylor https://github.com/gtaylormb/ultra96v2_imx219_to_displayport
 */
#include "sleep.h"
#include "imx219.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "i2c.h"

// config from https://android.googlesource.com/kernel/bcm/+/android-bcm-tetra-3.10-lollipop-wear-release/drivers/media/video/imx219.c
/* 1920x1080P48 */
imx219_config_word_t const imx219_cfg[] =
{
    {0x30EB, 0x05},
    {0x30EB, 0x0C},
    {0x300A, 0xFF},
    {0x300B, 0xFF},
    {0x30EB, 0x05},
    {0x30EB, 0x09},
    {0x0114, 0x01}, // 2-wire csi
    {0x0128, 0x00}, // auto MIPI global timing
    {0x012A, 0x18}, // INCK freq: 24.0Mhz
    {0x012B, 0x00},
    {0x0160, 0x04}, // frame length lines = 1113
    {0x0161, 0x59},
    {0x0162, 0x0D}, // line length pixels = 3448
    {0x0163, 0x78},
    {0x0164, 0x02}, // x-start address = 680
    {0x0165, 0xA8},
    {0x0166, 0x0A}, // x-end address = 2599
    {0x0167, 0x27},
    {0x0168, 0x02}, // y-start address = 692
    {0x0169, 0xB4},
    {0x016A, 0x06}, // y-end address = 1771
    {0x016B, 0xEB},
    {0x016C, 0x07}, // x-output size = 1920
    {0x016D, 0x80},
    {0x016E, 0x04}, // y-output size = 1080
    {0x016F, 0x38},
    {0x0170, 0x01}, //
    {0x0171, 0x01},
    {0x0174, 0x00},
    {0x0175, 0x00},
    {0x018C, 0x0A},
    {0x018D, 0x0A},
    {0x0301, 0x05}, // video timing pixel clock divider value = 5
    {0x0303, 0x01}, // video timing system clock divider value = 1
    {0x0304, 0x03}, // external clock 24-27MHz
    {0x0305, 0x03}, // external clock 24-27MHz
    {0x0306, 0x00}, // PLL Video Timing system multiplier value = 57
    {0x0307, 0x39},
    {0x0309, 0x0A}, // output pixel clock divider value = 10
    {0x030B, 0x01}, // output system clock divider value = 1
    {0x030C, 0x00}, // PLL output system multiplier value = 114
    {0x030D, 0x72},
    {0x455E, 0x00},
    {0x471E, 0x4B},
    {0x4767, 0x0F},
    {0x4750, 0x14},
    {0x4540, 0x00},
    {0x47B4, 0x14},
    {0x4713, 0x30},
    {0x478B, 0x10},
    {0x478F, 0x10},
    {0x4793, 0x10},
    {0x4797, 0x0E},
    {0x479B, 0x0E},
    {0x0100, 0x01}
};

/*
 * Looks for the IMX219 on the I2C bus
 */
int imx219_detect(uint8_t iic_id)
{
	int Status;
	uint8_t data;

	// Read the register
	Status = imx219_read(iic_id,0x00,&data);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	if(data != 0x02) {
		return XST_FAILURE;
	}
	else {
		return XST_SUCCESS;
	}
}

int imx219_config(uint8_t iic_id,XGpio *gpio,uint32_t gpio_mask) {
	int Status;
	// Reset the camera
	imx219_reset(gpio,gpio_mask);
    // Stop streaming
    Status = imx219_write(iic_id, 0x0100, 0x00);
    if(Status != XST_SUCCESS) {
    	return(Status);
    }
    usleep(1000);	// Write the config registers
	size_t len = sizeof(imx219_cfg)/sizeof(imx219_cfg[0]);
    for(size_t i = 0; i < len; i++)
    {
    	Status = imx219_write(iic_id,imx219_cfg[i].addr,imx219_cfg[i].data);
    	if(Status != XST_SUCCESS) {
    		return(Status);
    	}
    	// Delay between writes does not seem to be required for IMX219
		//usleep(1000);
    }

	imx219_write(iic_id,IMX219_ANA_GAIN_GLOBAL, 232);

	// Commented out in Greg Taylor's code
//	imx219_write(iic_id,IMX219_COARSE_INT_TIME_HI, 0x02);

	return XST_SUCCESS;
}

// Reset the IMX219 by toggling the enable pin
int imx219_reset(XGpio *gpio,uint32_t gpio_mask)
{
	// Disable the camera, wait 100ms
	XGpio_DiscreteClear(gpio, 1, gpio_mask);
	usleep(100000);
	// Enable the camera, wait 50ms
	XGpio_DiscreteSet(gpio, 1, gpio_mask);
	usleep(100000);
	return XST_SUCCESS;
}

int imx219_write(uint8_t iic_id,uint16_t addr, uint8_t data)
{
	int Status;
	uint8_t buf[10];
	buf[0] = addr >> 8;
	buf[1] = addr & 0x00FF;
	buf[2] = data;
	Status = IicWrite(iic_id,IMX219_I2C_SLAVE_ADDR,buf,3);
	return Status;
}

int imx219_read(uint8_t iic_id,uint16_t addr, uint8_t *data)
{
	int Status;
	uint8_t buf[10];
	buf[0] = addr >> 8;
	buf[1] = addr & 0x00FF;
	Status = IicWrite(iic_id,IMX219_I2C_SLAVE_ADDR,buf,2);
	if (Status != XST_SUCCESS) {
		return(Status);
	}
	Status = IicRead(iic_id,IMX219_I2C_SLAVE_ADDR,buf,1);
	if (Status != XST_SUCCESS) {
		return(Status);
	}
	*data = buf[0];
	return XST_SUCCESS;
}



