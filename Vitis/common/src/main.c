/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 */

#include <stdio.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "xscugic.h"
#include "xgpio.h"
#include "xiic.h"
#include "xvtc.h"
#include "xavbuf.h"
#include "xaxivdma.h"
#include "xv_demosaic.h"
#include "xv_gamma_lut.h"
#include "xaxis_switch.h"
#include "math.h"
#include "i2c_axi.h"
#include "xdpdma_video_example.h"
#include "board.h"
#include "pipe.h"

// PCam OV5640 driver
#include "ov5640.h"

// Common IP
XScuGic Intc;
XVtc VtcInst;
XGpio RsvdGpio;
XAxis_Switch AxisSwitch;

// Video pipes
VideoPipe Cam0,Cam1,Cam2,Cam3;

// Provide the device IDs for the elements of each video pipe
VideoPipeDevIds CamDevIds0 = {
		XPAR_MIPI_0_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_0_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_0_AXI_VDMA_0_DEVICE_ID,
		0x00000000,
		XPAR_MIPI_0_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_0_V_GAMMA_LUT_DEVICE_ID,
		XPAR_FABRIC_MIPI_0_AXI_IIC_0_IIC2INTC_IRPT_INTR
};
VideoPipeDevIds CamDevIds1 = {
		XPAR_MIPI_1_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_1_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_1_AXI_VDMA_0_DEVICE_ID,
		0x01000000,
		XPAR_MIPI_1_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_1_V_GAMMA_LUT_DEVICE_ID,
		XPAR_FABRIC_MIPI_1_AXI_IIC_0_IIC2INTC_IRPT_INTR
};
VideoPipeDevIds CamDevIds2 = {
		XPAR_MIPI_2_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_2_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_2_AXI_VDMA_0_DEVICE_ID,
		0x02000000,
		XPAR_MIPI_2_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_2_V_GAMMA_LUT_DEVICE_ID,
		XPAR_FABRIC_MIPI_2_AXI_IIC_0_IIC2INTC_IRPT_INTR
};
VideoPipeDevIds CamDevIds3 = {
		XPAR_MIPI_3_AXI_IIC_0_DEVICE_ID,
		XPAR_MIPI_3_AXI_GPIO_0_DEVICE_ID,
		XPAR_MIPI_3_AXI_VDMA_0_DEVICE_ID,
		0x03000000,
		XPAR_MIPI_3_DEMOSAIC_0_DEVICE_ID,
		XPAR_MIPI_3_V_GAMMA_LUT_DEVICE_ID,
		XPAR_FABRIC_MIPI_3_AXI_IIC_0_IIC2INTC_IRPT_INTR
};

// Common target device IDs
#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define VTC_DEVICE_ID		XPAR_VTC_0_DEVICE_ID
#define RSVD_GPIO_DEVICE_ID XPAR_RSVD_GPIO_DEVICE_ID

// Interrupt controller defines
//#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define IIC_INTR_ID			XPAR_FABRIC_IIC_0_VEC_ID
#define INTC_HANDLER		XScuGic_InterruptHandler

// Reserved GPIO

#define CAM0_TST_OE_MASK    (0x0001<<0) // LA04_P
#define CAM1_TST_OE_MASK    (0x0001<<1) // LA04_N
#define CAM1_CLK_P_TST_MASK (0x0001<<2) // LA07_P
#define CAM1_CLK_N_TST_MASK (0x0001<<3) // LA07_N
#define CAM_IO0_DIR_MASK    (0x0001<<4) // LA13_P
#define CAM_IO1_DIR_MASK    (0x0001<<5) // LA13_N
#define CAM_IO0_OE_N_MASK   (0x0001<<6) // LA27_P
#define CAM_IO1_OE_N_MASK   (0x0001<<7) // LA27_N
#define CAM3_CLK_P_TST_MASK (0x0001<<8) // LA29_P
#define CAM3_CLK_N_TST_MASK (0x0001<<9) // LA29_N

// Reserved GPIO default direction mask (1=input, 0=output)
#define RSVD_GPIO_DEF_DIR_MASK 0 // All outputs
// Reserved GPIO default value mask
#define RSVD_GPIO_DEF_VAL_MASK (CAM_IO0_DIR_MASK|CAM_IO1_DIR_MASK)

int main()
{
	XScuGic_Config *IntcConfig;
	XVtc_Config *VtcConfig;
	XVtc_Timing VtcTiming;
	XVtc_SourceSelect SourceSelect;
	Run_Config RunCfg;
	XAxis_Switch_Config *SwitchConfig;

	int Status;

    xil_printf("---------------------------------------\n\r");
    xil_printf(" 4x RPi camera to Display Port example\n\r");
    xil_printf("---------------------------------------\n\r");

	/*
	 * Initialize the Reserved GPIO driver
	 */
	Status = XGpio_Initialize(&RsvdGpio, RSVD_GPIO_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("RsvdGpio Initialization Failed\r\n");
		return XST_FAILURE;
	}

	// Set Rsvd GPIO default directions (1=input, 0=output) and values
	XGpio_SetDataDirection(&RsvdGpio, 1, RSVD_GPIO_DEF_DIR_MASK);
	XGpio_DiscreteWrite(&RsvdGpio, 1, RSVD_GPIO_DEF_VAL_MASK);

	/*
	 * Initialize AXIS switch
	 */
	SwitchConfig = XAxisScr_LookupConfig(XPAR_AXIS_SWITCH_0_DEVICE_ID);
	if (NULL == SwitchConfig) {
		return XST_FAILURE;
	}

	Status = XAxisScr_CfgInitialize(&AxisSwitch, SwitchConfig,
			SwitchConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		xil_printf("AXI4-Stream initialization failed.\r\n");
		return XST_FAILURE;
	}

	/* Disable register update */
	XAxisScr_RegUpdateDisable(&AxisSwitch);

	/* Disable all MI ports */
	XAxisScr_MiPortDisableAll(&AxisSwitch);

	/* Source SI[0] to MI[0] */
	XAxisScr_MiPortEnable(&AxisSwitch, 0, 0);

	/* Enable register update */
	XAxisScr_RegUpdateEnable(&AxisSwitch);

	/*
	 * Initialize the interrupt controller
	 * The init functions of the I2C driver and DPDMA driver will each setup and
	 * enable their respective interrupts later.
	 */
	IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
	if (NULL == IntcConfig) {
		return XST_FAILURE;
	}
	Status = XScuGic_CfgInitialize(&Intc, IntcConfig, IntcConfig->CpuBaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
	// Initialize exceptions
	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
			(Xil_ExceptionHandler)XScuGic_DeviceInterruptHandler,
			INTC_DEVICE_ID);
	// Enable exceptions for interrupts
	Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
	Xil_ExceptionEnable();

	/*
	 * Initialize Video pipe for each camera
	 */
	pipe_init(&Cam0, &CamDevIds0, &Intc);
	pipe_init(&Cam1, &CamDevIds1, &Intc);
	pipe_init(&Cam2, &CamDevIds2, &Intc);
	pipe_init(&Cam3, &CamDevIds3, &Intc);

	/*
	 * Initialize VTC
	 */
	VtcConfig = XVtc_LookupConfig(VTC_DEVICE_ID);
    XVtc_CfgInitialize(&VtcInst, VtcConfig, VtcConfig->BaseAddress);
	XVtc_ConvVideoMode2Timing(&VtcInst,VMODE_VTC,&VtcTiming);

    /*
     * Setup the VTC Source Select config structure.
     * 1=Generator registers are source
     * 0=Detector registers are source
     */
	memset((void *)&SourceSelect, 0, sizeof(SourceSelect));
	SourceSelect.VBlankPolSrc = 1;
	SourceSelect.VSyncPolSrc = 1;
	SourceSelect.HBlankPolSrc = 1;
	SourceSelect.HSyncPolSrc = 1;
	SourceSelect.ActiveVideoPolSrc = 1;
	SourceSelect.ActiveChromaPolSrc= 1;
	SourceSelect.VChromaSrc = 1;
	SourceSelect.VActiveSrc = 1;
	SourceSelect.VBackPorchSrc = 1;
	SourceSelect.VSyncSrc = 1;
	SourceSelect.VFrontPorchSrc = 1;
	SourceSelect.VTotalSrc = 1;
	SourceSelect.HActiveSrc = 1;
	SourceSelect.HBackPorchSrc = 1;
	SourceSelect.HSyncSrc = 1;
	SourceSelect.HFrontPorchSrc = 1;
	SourceSelect.HTotalSrc = 1;
	XVtc_SelfTest(&VtcInst);
	XVtc_RegUpdateEnable(&VtcInst);
	XVtc_SetGeneratorTiming(&VtcInst, &VtcTiming);
	XVtc_SetSource(&VtcInst, &SourceSelect);
	XVtc_EnableGenerator(&VtcInst);
	XVtc_Enable(&VtcInst);

	/*
	 * Run the DisplayPort video example
	 */
	Xil_DCacheDisable();
	Xil_ICacheDisable();

	Status = DpdmaVideoExample(&RunCfg,&Intc,VMODE_DP);
	if (Status != XST_SUCCESS) {
			xil_printf("DPDMA Video Example Test Failed\r\n");
			return XST_FAILURE;
	}

	/*
	 * Start the cameras
	 */
	config_camera(&Cam0);
	config_camera(&Cam1);
	config_camera(&Cam2);
	config_camera(&Cam3);

	u8 cam_index = 0;
	while(1){
		sleep(5);
		cam_index++;
		if(cam_index == 4)
			cam_index = 0;
		/* Disable register update */
		XAxisScr_RegUpdateDisable(&AxisSwitch);

		/* Disable all MI ports */
		XAxisScr_MiPortDisableAll(&AxisSwitch);

		/* Source SI[0] to MI[0] */
		XAxisScr_MiPortEnable(&AxisSwitch, 0, cam_index);

		/* Enable register update */
		XAxisScr_RegUpdateEnable(&AxisSwitch);
	}

    return 0;
}

