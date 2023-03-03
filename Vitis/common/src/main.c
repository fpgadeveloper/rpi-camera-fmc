/*
 * Opsero Electronic Design Inc. Copyright 2022
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

// PCam OV5640 driver
#include "ov5640.h"

// Common IP
XScuGic Intc;
XVtc VtcInst;
XGpio RsvdGpio;
XAxis_Switch AxisSwitch;

// Camera 0 IP
XIic Iic;
XGpio Gpio;
XAxiVdma Vdma;
XAxiVdma_DmaSetup VdmaDma;
XAxiVdma_Config *VdmaConfig;
XV_demosaic Demosaic;
XV_gamma_lut GammaLut;

// Camera 1 IP
// TODO

// Common target device IDs
#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define VTC_DEVICE_ID		XPAR_VTC_0_DEVICE_ID
#define RSVD_GPIO_DEVICE_ID XPAR_RSVD_GPIO_DEVICE_ID

// Camera 0 target device IDs
#define GPIO_DEVICE_ID		XPAR_MIPI_0_AXI_GPIO_0_DEVICE_ID
#define VDMA_DEVICE_ID		XPAR_MIPI_0_AXI_VDMA_0_DEVICE_ID
#define DEMOSAIC_DEVICE_ID	XPAR_MIPI_0_DEMOSAIC_0_DEVICE_ID
#define GAMMA_LUT_DEVICE_ID	XPAR_MIPI_0_V_GAMMA_LUT_DEVICE_ID
#define IIC_DEVICE_ID		XPAR_MIPI_0_AXI_IIC_0_DEVICE_ID

// Camera 1 target device IDs
// TODO

// Camera GPIO masks
#define GPIO_CAM_IO0_MASK	0x01
#define GPIO_CAM_IO1_MASK	0x01

// Interrupt controller defines
//#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define IIC_INTR_ID			XPAR_FABRIC_IIC_0_VEC_ID
#define INTC_HANDLER		XScuGic_InterruptHandler

// Memory for the frame buffers
#define DDR_BASE_ADDR		XPAR_PSU_DDR_0_S_AXI_BASEADDR
#define MEM_BASE_ADDR		(DDR_BASE_ADDR + 0x01000000)
#define FRAME_BUF_ADDR_BASE	(MEM_BASE_ADDR + 0x02000000)

// Video mode and frame size defines
//#define DEMO_VMODE_720P60     1
#define DEMO_VMODE_1080P30     1

#if defined (DEMO_VMODE_720P60)
#define VMODE_WIDTH			1280
#define VMODE_HEIGHT		720
#define VMODE_VTC           XVTC_VMODE_720P
#define VMODE_CAM			MODE_720P_1280_720_60fps
#define VMODE_DP			XVIDC_VM_1280x720_60_P
#define GAMMA               1/1.0
#define PIXEL_SIZE			8	// In bits
#define GAMMA_TABLE_SIZE	256  // 2^PIXEL_SIZE
#define FRAME_HORI_LEN	  	VMODE_WIDTH*3  // Each pixel is 3 bytes
#define FRAME_VERT_LEN		VMODE_HEIGHT
#define SUBFRAME_START_OFFSET    (FRAME_HORI_LEN * 5 + 64)
#endif
#if defined (DEMO_VMODE_1080P30)
#define VMODE_WIDTH			1920
#define VMODE_HEIGHT		1080
#define VMODE_VTC           XVTC_VMODE_1080P
#define VMODE_CAM			MODE_1080P_1920_1080_30fps
#define VMODE_DP			XVIDC_VM_1920x1080_30_P
#define GAMMA               1/1.0
#define PIXEL_SIZE			8	// In bits
#define GAMMA_TABLE_SIZE	256  // 2^PIXEL_SIZE
#define FRAME_HORI_LEN	  	VMODE_WIDTH*3  // Each pixel is 3 bytes
#define FRAME_VERT_LEN		VMODE_HEIGHT
#define SUBFRAME_START_OFFSET    (FRAME_HORI_LEN * 5 + 64)
#endif

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

    xil_printf("-------------------------------------\n\r");
    xil_printf(" MIPI camera to Display Port example\n\r");
    xil_printf("-------------------------------------\n\r");

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
	 * Initialize the GPIO driver for CAM0
	 */
	Status = XGpio_Initialize(&Gpio, GPIO_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("Gpio Initialization Failed\r\n");
		return XST_FAILURE;
	}

	// Set GPIO directions (1=input, 0=output)
	XGpio_SetDataDirection(&Gpio, 1, ~(GPIO_CAM_IO0_MASK+GPIO_CAM_IO1_MASK));
	// Enable the camera
	XGpio_DiscreteWrite(&Gpio, 1, GPIO_CAM_IO0_MASK);

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
	 * Initialize the IIC for communication with camera
	 */
	Status = IicInit(&Iic,IIC_DEVICE_ID,&Intc,IIC_INTR_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the I2C\n\r");
		return XST_FAILURE;
	}

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
	 * VDMA initialization and config
	 */
	VdmaConfig = XAxiVdma_LookupConfig(VDMA_DEVICE_ID);
	Status = XAxiVdma_CfgInitialize(&Vdma, VdmaConfig, VdmaConfig->BaseAddress);
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
	UINTPTR Addr = FRAME_BUF_ADDR_BASE + SUBFRAME_START_OFFSET;
	for(uint32_t i = 0; i < VdmaConfig->MaxFrameStoreNum; i++) {
		VdmaDma.FrameStoreStartAddr[i] = Addr;
		Addr += FRAME_HORI_LEN * FRAME_VERT_LEN;
	}
	// Set the buffer addresses for transfer in the DMA engine
	Status = XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_WRITE, &VdmaDma);
	Status = XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_WRITE, VdmaDma.FrameStoreStartAddr);
	Status = XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &VdmaDma);
	Status = XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, VdmaDma.FrameStoreStartAddr);

	/*
	 * Demosaic initialization and config
	 */
	XV_demosaic_Initialize(&Demosaic, DEMOSAIC_DEVICE_ID);
	XV_demosaic_Set_HwReg_width(&Demosaic, VMODE_WIDTH);
	XV_demosaic_Set_HwReg_height(&Demosaic, VMODE_HEIGHT);
	XV_demosaic_Set_HwReg_bayer_phase(&Demosaic, 0x03);
	XV_demosaic_EnableAutoRestart(&Demosaic);
	XV_demosaic_Start(&Demosaic);

	/*
	 * Gamma LUT initialization and config
	 */
	Status = XV_gamma_lut_Initialize(&GammaLut, GAMMA_LUT_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize the Gamma LUT\n\r");
		return XST_FAILURE;
	}
	XV_gamma_lut_Set_HwReg_width(&GammaLut, VMODE_WIDTH);
	XV_gamma_lut_Set_HwReg_height(&GammaLut, VMODE_HEIGHT);
	XV_gamma_lut_Set_HwReg_video_format(&GammaLut, 0);
	for(uint32_t i = 0; i < GAMMA_TABLE_SIZE; i++)
	{
		uint16_t value = pow((i / (float)GAMMA_TABLE_SIZE), GAMMA) * (float)GAMMA_TABLE_SIZE;
		Xil_Out16((XPAR_MIPI_0_V_GAMMA_LUT_S_AXI_CTRL_BASEADDR + 0x800 + i*2), value );
		Xil_Out16((XPAR_MIPI_0_V_GAMMA_LUT_S_AXI_CTRL_BASEADDR + 0x1000 + i*2), value );
		Xil_Out16((XPAR_MIPI_0_V_GAMMA_LUT_S_AXI_CTRL_BASEADDR + 0x1800 + i*2), value );
	}
	XV_gamma_lut_Start(&GammaLut);
	XV_gamma_lut_EnableAutoRestart(&GammaLut);

	/*
	 * Start the VDMA
	 */
	Status = XAxiVdma_DmaStart(&Vdma, XAXIVDMA_WRITE);
	Status = XAxiVdma_StartParking(&Vdma, 0, XAXIVDMA_WRITE);
	Status = XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ);
	Status = XAxiVdma_StartParking(&Vdma, 0, XAXIVDMA_READ);

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
	 * OV5640 camera setup
	 */
	ov5640_init(&Iic,&Gpio,GPIO_CAM_IO0_MASK);
	Status = ov5640_detect();
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: Failed to detect OV5640 camera\n\r");
		return XST_FAILURE;
	}
	else {
		xil_printf("OV5640 camera detected\n\r");
	}

	ov5640_config(VMODE_CAM,AWB_SIMPLE);

	while(1){
	}

    return 0;
}

