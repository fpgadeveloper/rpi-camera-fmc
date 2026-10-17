/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * The functions in this module allow for initialization of the video pipe and starting of
 * the video pipe.
 */

#include "xstatus.h"
#include "xil_printf.h"
#include "i2c.h"
#include "sleep.h"
#include "xv_frmbufrd_l2.h"
#include "xv_frmbufwr_l2.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xvprocss_vdma.h"
#include "pipe.h"
#include "math.h"
#include "config.h"

/*
 * Initialize the video pipe
 */
int pipe_init(VideoPipe *pipe, VideoPipeBaseAddr *baseaddr)
{
	XVprocSs_Config *VprocSsConfigPtr;
	int Status;
    
	/*
	 * Initialize the GPIO driver
	 */
	Status = XGpio_Initialize(&(pipe->Gpio), baseaddr->Gpio);
	if (Status != XST_SUCCESS) {
		xil_printf("Gpio Initialization Failed\r\n");
		return XST_FAILURE;
	}

	// Set GPIO directions (1=input, 0=output)
	XGpio_SetDataDirection(&(pipe->Gpio), 1, 0);
	// Enable the camera and hold all video pipe elements in reset
	XGpio_DiscreteWrite(&(pipe->Gpio), 1, GPIO_CAM_IO0_MASK);
    usleep(10000);

	/*
	 * Initialize the IIC for communication with camera
	 */
	u8 iic_id;
	Status = IicAxiInit(&(pipe->Iic),baseaddr->Iic,&iic_id);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the I2C\n\r");
		return XST_FAILURE;
	}

	/*
	 * Initialize the camera
	 * This function will initialize the Camera container and try to communicate with the image sensor
	 * via the I2C bus so that we know what model it is and thus configure the Sensor Demosaic
	 * accordingly.
	 */
	Status = rpi_cam_init(&(pipe->Camera),iic_id,&(pipe->Gpio),GPIO_CAM_IO0_MASK);
	if(Status == XST_FAILURE) {
		pipe->IsConnected = FALSE;
		return(XST_FAILURE);
	}

	// Disable the camera while we setup the video pipe and until we use the pipe_start_camera function
	XGpio_DiscreteClear(&(pipe->Gpio), 1, GPIO_CAM_IO0_MASK);

	/*
	 * Frame Buffer Wr/Rd initialization and config
	 */
    pipe_reset_deassert(pipe,GPIO_CAM_FRMBUFWR_RST_N_MASK);
	Status = FrmbufWrInit(&(pipe->Frmbuf),baseaddr->FrmbufWr,baseaddr->FrmbufBufrBaseAddr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the Frame Buffer Write\n\r");
		return XST_FAILURE;
	}
    pipe_reset_deassert(pipe,GPIO_CAM_FRMBUFRD_RST_N_MASK);
	Status = FrmbufRdInit(&(pipe->Frmbuf),baseaddr->FrmbufRd,baseaddr->FrmbufBufrBaseAddr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the Frame Buffer Read\n\r");
		return XST_FAILURE;
	}

	/*
	 * Video Processor Subsystem initialization and config
	 */
    pipe_reset_deassert(pipe,GPIO_CAM_VPROC_RST_N_MASK);
	VprocSsConfigPtr = XVprocSs_LookupConfig(baseaddr->Vproc);
	if(VprocSsConfigPtr == NULL) {
		xil_printf("ERROR: Video Processor Subsystem device not found\r\n");
		return(XST_FAILURE);
	}
	// Start capturing event log
	XVprocSs_LogReset(&(pipe->Vproc));
	Status = XVprocSs_CfgInitialize(&(pipe->Vproc),
			                        VprocSsConfigPtr,
			                        VprocSsConfigPtr->BaseAddress);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Video Processing Subsystem Init. error\n\r");
		return(XST_FAILURE);
	}

	// Configure the Video Processing Subsystem INPUT stream parameters
	XVidC_VideoMode resIdIn = XVidC_GetVideoModeId(VMODE_WIDTH,VMODE_HEIGHT,VMODE_FRAMERATE,FALSE);
	XVidC_VideoTiming const *TimingInPtr = XVidC_GetTimingInfo(resIdIn);
	XVidC_VideoStream StreamIn;
	StreamIn.VmId           = resIdIn;
	StreamIn.Timing         = *TimingInPtr;
	StreamIn.ColorFormatId  = COLOR_FORMAT_ID;
	StreamIn.ColorDepth     = pipe->Vproc.Config.ColorDepth;
	StreamIn.PixPerClk      = pipe->Vproc.Config.PixPerClock;
	StreamIn.FrameRate      = XVidC_GetFrameRate(resIdIn);
	StreamIn.IsInterlaced   = XVidC_IsInterlaced(resIdIn);
	XVprocSs_SetVidStreamIn(&(pipe->Vproc), &StreamIn);

	// Configure the Video Processing Subsystem OUTPUT stream parameters
	XVidC_VideoMode resIdOut = XVidC_GetVideoModeId(VPROC_WIDTH_OUT,VPROC_HEIGHT_OUT,VPROC_FRAMERATE_OUT,FALSE);
	XVidC_VideoTiming const *TimingOutPtr = XVidC_GetTimingInfo(resIdOut);
	XVidC_VideoStream StreamOut;
	StreamOut.VmId           = resIdOut;
	StreamOut.Timing         = *TimingOutPtr;
	StreamOut.ColorFormatId  = COLOR_FORMAT_ID;
	StreamOut.ColorDepth     = pipe->Vproc.Config.ColorDepth;
	StreamOut.PixPerClk      = pipe->Vproc.Config.PixPerClock;
	StreamOut.FrameRate      = XVidC_GetFrameRate(resIdOut);
	StreamOut.IsInterlaced   = XVidC_IsInterlaced(resIdOut);
	XVprocSs_SetVidStreamOut(&(pipe->Vproc), &StreamOut);

	// Start the Video Processor Subsystem
	Status = XVprocSs_SetSubsystemConfig(&(pipe->Vproc));
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to start the Video Processing SS\n\r");
		return XST_FAILURE;
	}
    XVprocSs_Start(&(pipe->Vproc));

	/*
	 * Demosaic initialization and config
	 */
    pipe_reset_deassert(pipe,GPIO_CAM_DEMOSAIC_RST_N_MASK);
	Status = XV_demosaic_Initialize(&(pipe->Demosaic), baseaddr->Demosaic);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to initialize the Demosaic\n\r");
		return XST_FAILURE;
	}
	XV_demosaic_Set_HwReg_width(&(pipe->Demosaic), VMODE_WIDTH);
	XV_demosaic_Set_HwReg_height(&(pipe->Demosaic), VMODE_HEIGHT);
	XV_demosaic_Set_HwReg_bayer_phase(&(pipe->Demosaic), rpi_cam_bayer_phase(&(pipe->Camera)));
	XV_demosaic_EnableAutoRestart(&(pipe->Demosaic));
	XV_demosaic_Start(&(pipe->Demosaic));
    
	/*
	 * Gamma LUT initialization and config
	 */
    pipe_reset_deassert(pipe,GPIO_CAM_GAMMA_RST_N_MASK);
	Status = XV_gamma_lut_Initialize(&(pipe->GammaLut), baseaddr->GammaLut);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to initialize the Gamma LUT\n\r");
		return XST_FAILURE;
	}
	XV_gamma_lut_Set_HwReg_width(&(pipe->GammaLut), VMODE_WIDTH);
	XV_gamma_lut_Set_HwReg_height(&(pipe->GammaLut), VMODE_HEIGHT);
	XV_gamma_lut_Set_HwReg_video_format(&(pipe->GammaLut), 0);
	for(uint32_t i = 0; i < GAMMA_TABLE_SIZE; i++)
	{
		uint16_t value = pow((i / (double)GAMMA_TABLE_SIZE), GAMMA) * (float)GAMMA_TABLE_SIZE;
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x800 + i*2), value );
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x1000 + i*2), value );
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x1800 + i*2), value );
	}
	XV_gamma_lut_Start(&(pipe->GammaLut));
	XV_gamma_lut_EnableAutoRestart(&(pipe->GammaLut));
    
	pipe->IsConnected = TRUE;

	return(XST_SUCCESS);
}

int pipe_start_camera(VideoPipe *pipe)
{
	int Status;

	// Start the RPi camera
	Status = rpi_cam_config(&(pipe->Camera));
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to configure the camera\n\r");
		return XST_FAILURE;
	}
	// Start the Frame buffers
	Status = FrmbufStart(&(pipe->Frmbuf));
	return(Status);
}

