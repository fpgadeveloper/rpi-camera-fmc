
#include "xstatus.h"
#include "xil_printf.h"
#include "i2c_axi.h"
#include "sleep.h"
#include "ov5640.h"
#include "xaxivdma.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "pipe.h"

/*
 * Initialize the video pipe
 */
int pipe_init(VideoPipe *pipe, VideoPipeDevIds *devids, XScuGic *intc)
{
	XAxiVdma_DmaSetup VdmaDma;
	XAxiVdma_Config *VdmaConfig;
	int Status;

	/*
	 * Initialize the GPIO driver
	 */
	Status = XGpio_Initialize(&(pipe->Gpio), devids->Gpio);
	if (Status != XST_SUCCESS) {
		xil_printf("Gpio Initialization Failed\r\n");
		return XST_FAILURE;
	}

	// Set GPIO directions (1=input, 0=output)
	XGpio_SetDataDirection(&(pipe->Gpio), 1, ~(GPIO_CAM_IO0_MASK+GPIO_CAM_IO1_MASK));
	// Enable the camera
	XGpio_DiscreteWrite(&(pipe->Gpio), 1, GPIO_CAM_IO0_MASK);

	/*
	 * Initialize the IIC for communication with camera
	 */
	Status = IicInit(&(pipe->Iic),devids->Iic,intc,devids->IicIntr);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the I2C\n\r");
		return XST_FAILURE;
	}

	/*
	 * VDMA initialization and config
	 */
	VdmaConfig = XAxiVdma_LookupConfig(devids->Vdma);
	Status = XAxiVdma_CfgInitialize(&(pipe->Vdma), VdmaConfig, VdmaConfig->BaseAddress);
	VdmaDma.VertSizeInput = FRAME_VERT_LEN;
	VdmaDma.HoriSizeInput = FRAME_HORI_LEN;
	VdmaDma.Stride = FRAME_HORI_LEN;
	VdmaDma.FrameDelay = 0;  // Does not test frame delay
	VdmaDma.EnableCircularBuf = 1;
	VdmaDma.EnableSync = 0;  // No Gen-Lock
	VdmaDma.PointNum = 0;  // No Gen-Lock
	VdmaDma.EnableFrameCounter = 0;  // Endless transfers
	VdmaDma.FixedFrameStoreAddr = 0;  // We are not doing parking
	// Initialize buffer addresses, use physical addresses
	UINTPTR Addr = devids->VdmaFrameBufOffset + FRAME_BUF_ADDR_BASE + SUBFRAME_START_OFFSET;
	for(uint32_t i = 0; i < VdmaConfig->MaxFrameStoreNum; i++) {
		VdmaDma.FrameStoreStartAddr[i] = Addr;
		Addr += FRAME_HORI_LEN * FRAME_VERT_LEN;
	}
	// Set the buffer addresses for transfer in the DMA engine
	Status = XAxiVdma_DmaConfig(&(pipe->Vdma), XAXIVDMA_WRITE, &VdmaDma);
	Status = XAxiVdma_DmaSetBufferAddr(&(pipe->Vdma), XAXIVDMA_WRITE, VdmaDma.FrameStoreStartAddr);
	Status = XAxiVdma_DmaConfig(&(pipe->Vdma), XAXIVDMA_READ, &VdmaDma);
	Status = XAxiVdma_DmaSetBufferAddr(&(pipe->Vdma), XAXIVDMA_READ, VdmaDma.FrameStoreStartAddr);

	/*
	 * Demosaic initialization and config
	 */
	XV_demosaic_Initialize(&(pipe->Demosaic), devids->Demosaic);
	XV_demosaic_Set_HwReg_width(&(pipe->Demosaic), VMODE_WIDTH);
	XV_demosaic_Set_HwReg_height(&(pipe->Demosaic), VMODE_HEIGHT);
	XV_demosaic_Set_HwReg_bayer_phase(&(pipe->Demosaic), 0x03);
	XV_demosaic_EnableAutoRestart(&(pipe->Demosaic));
	XV_demosaic_Start(&(pipe->Demosaic));

	/*
	 * Gamma LUT initialization and config
	 */
	Status = XV_gamma_lut_Initialize(&(pipe->GammaLut), devids->GammaLut);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the Gamma LUT\n\r");
		return XST_FAILURE;
	}
	XV_gamma_lut_Set_HwReg_width(&(pipe->GammaLut), VMODE_WIDTH);
	XV_gamma_lut_Set_HwReg_height(&(pipe->GammaLut), VMODE_HEIGHT);
	XV_gamma_lut_Set_HwReg_video_format(&(pipe->GammaLut), 0);
	for(uint32_t i = 0; i < GAMMA_TABLE_SIZE; i++)
	{
		uint16_t value = pow((i / (float)GAMMA_TABLE_SIZE), GAMMA) * (float)GAMMA_TABLE_SIZE;
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x800 + i*2), value );
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x1000 + i*2), value );
		Xil_Out16((pipe->GammaLut.Config.BaseAddress + 0x1800 + i*2), value );
	}
	XV_gamma_lut_Start(&(pipe->GammaLut));
	XV_gamma_lut_EnableAutoRestart(&(pipe->GammaLut));

	/*
	 * Start the VDMA
	 */
	Status = XAxiVdma_DmaStart(&(pipe->Vdma), XAXIVDMA_WRITE);
	Status = XAxiVdma_StartParking(&(pipe->Vdma), 0, XAXIVDMA_WRITE);
	Status = XAxiVdma_DmaStart(&(pipe->Vdma), XAXIVDMA_READ);
	Status = XAxiVdma_StartParking(&(pipe->Vdma), 0, XAXIVDMA_READ);

	/*
	 * Initialize the camera
	 */
	ov5640_init(&(pipe->Ov5640),&(pipe->Iic),&(pipe->Gpio),GPIO_CAM_IO0_MASK);
}

int config_camera(VideoPipe *pipe)
{
	int Status;
	/*
	 * OV5640 camera setup
	 */
	Status = ov5640_detect(&(pipe->Ov5640));
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to detect OV5640 camera\n\r");
		return XST_FAILURE;
	}
	else {
		xil_printf("OV5640 camera detected\n\r");
	}

	ov5640_config(&(pipe->Ov5640),VMODE_CAM,AWB_SIMPLE);

}
