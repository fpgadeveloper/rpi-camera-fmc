/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * This driver provides an interface to the image sensor. It currently supports:
 *
 *  - Digilent Pcam (OV5640)
 *  - Raspberry Pi camera v2 (IMX219)
 *
 */

#include "rpi_cam.h"
#include "ov5640.h"
#include "imx219.h"

u8 NumRpiCameras = 0;
RpiCamera RpiCameraArray[4];

static const Sensor SupportedSensors[2] =
{
	{
		RPI_CAM_TYPE_OV5640,
		RPI_CAM_BAYER_PAT_OV5640,
		&ov5640_config,
		&ov5640_detect
	},
	{
		RPI_CAM_TYPE_IMX219,
		RPI_CAM_BAYER_PAT_IMX219,
		&imx219_config,
		&imx219_detect
	}
};

#define NUM_SUPPORTED_SENSORS (sizeof(SupportedSensors)/sizeof(SupportedSensors[0]))

// Initialize the RPi Camera driver
// Returns XST_SUCCESS if a supported camera was found on the I2C bus else returns XST_FAILURE
int rpi_cam_init(RpiCamera *camera,uint8_t iic_id,XGpio *gpio_inst,uint32_t gpio_mask)
{
    if (!camera || !gpio_inst) return XST_INVALID_PARAM;
	// Copy the IIC instance pointer that connects to the RPi Camera
	camera->iic_id = iic_id;
	// Copy the GPIO instance for the reset signal
	camera->gpio = gpio_inst;
	camera->gpio_mask = gpio_mask;

	// Determine the type of camera (if any) is connected
	// Read the detect register and check the returned value
	int Status;
	for(uint8_t i = 0; i < NUM_SUPPORTED_SENSORS; i++) {
		camera->sensor = SupportedSensors[i];
		Status = rpi_cam_detect(camera);
		if (Status == XST_SUCCESS) {
			return(XST_SUCCESS);
		}
	}
	// Otherwise no supported camera was found - FAILURE
	return XST_FAILURE;
}

// Configure the camera, using the appropriate driver
int rpi_cam_config(RpiCamera *camera)
{
	int Status;
	Status = camera->sensor.config(camera->iic_id,camera->gpio,camera->gpio_mask);
	return(Status);
}

// Detect the camera, using the appropriate driver
int rpi_cam_detect(RpiCamera *camera)
{
	int Status;
	Status = camera->sensor.detect(camera->iic_id);
	return(Status);
}

// Returns the bayer pattern as a value for Demosaic bayer phase
uint8_t rpi_cam_bayer_phase(RpiCamera *camera)
{
	return(camera->sensor.bayer_pattern);
}

