/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 */

#include "rpi_cam.h"
#include "ov5640.h"
#include "imx219.h"
#include "pipe.h"

u8 NumRpiCameras = 0;
RpiCamera RpiCameraArray[4];

Sensor SupportedSensors[2] =
{
	{
		RPI_CAM_TYPE_OV5640,
		IIC_OV5640_ADDR
	},
	{
		RPI_CAM_TYPE_IMX219,
		IMX219_I2C_SLAVE_ADDR
	}
};


// Initialize the RPi Camera driver with a pointer to the I2C instance
int rpi_cam_init(RpiCamera *camera,uint8_t iic_id,XGpio *gpio_inst,uint8_t gpio_mask)
{
	// Copy the IIC instance pointer that connects to the RPi Camera
	camera->iic_id = iic_id;
	// Copy the GPIO instance for the reset signal
	camera->gpio = gpio_inst;
	camera->gpio_mask = gpio_mask;

	// Determine the type of camera (if any) is connected
	// Read the detect register and check the returned value
	int Status;
	for(int i = 0; i < 2; i++) {
		camera->sensor = SupportedSensors[i];
		Status = rpi_cam_detect(camera);
		if (Status == XST_SUCCESS) {
			return(XST_SUCCESS);
		}
	}
	// Otherwise neither camera was found - FAILURE
	xil_printf("ERROR: Could not find camera\n\r");
	return XST_FAILURE;
}

// Configure the camera, using the appropriate driver
int rpi_cam_config(RpiCamera *camera)
{
	int Status;
	// Run the config function of the appropriate driver
	switch(camera->sensor.model) {
	case RPI_CAM_TYPE_OV5640:
		Status = ov5640_config(camera,VMODE_CAM,AWB_SIMPLE);
		break;
	case RPI_CAM_TYPE_IMX219:
		Status = imx219_config(camera);
		break;
	default:
		break;
	}
	return(Status);
}

// Detect the camera, using the appropriate driver
int rpi_cam_detect(RpiCamera *camera)
{
	int Status;
	// Run the detect function of the appropriate driver
	switch(camera->sensor.model) {
	case RPI_CAM_TYPE_OV5640:
		Status = ov5640_detect(camera);
		break;
	case RPI_CAM_TYPE_IMX219:
		Status = imx219_detect(camera);
		break;
	default:
		break;
	}
	return(Status);
}

