/*
 * Opsero Electronic Design Inc. Copyright 2025
 *
 * This example standalone application for the RPi Camera FMC will configure all of the connected
 * cameras that it finds connected, and then displays the video outputs on the DisplayPort monitor.
 * To display all four video streams on the single display, it uses the Video Processor Subsystem IP
 * to downsize the 1080p videos coming from the cameras to 720x480 resolution and then combines them
 * with the Video Mixer to produce a 1080p resolution video containing all four video streams.
 * The background is created by a Test Pattern Generator that is connected to the master layer of
 * the Video Mixer. The camera streams are organized on the screen as shown below:
 *
 * +------------------------------------------+
 * |              1920x1080px                 |
 * |  +----------------+  +----------------+  |
 * |  |                |  |                |  |
 * |  |     CAM0       |  |     CAM1       |  |
 * |  |   720x480px    |  |   720x480px    |  |
 * |  +----------------+  +----------------+  |
 * |                                          |
 * |  +----------------+  +----------------+  |
 * |  |                |  |                |  |
 * |  |     CAM2       |  |     CAM3       |  |
 * |  |   720x480px    |  |   720x480px    |  |
 * |  +----------------+  +----------------+  |
 * |                                          |
 * +------------------------------------------+
 *
 * Camera-to-DDR video pipe (x4):
 * ------------------------------
 *  RPi cam -> MIPI CSI SS -> Demosaic -> Gamma LUT -> VProc SS -> Frame Buffer Write -> DDR
 *
 *  The video pipe runs at 1 pixel per clock.
 *
 * DDR-to-HDMI video pipe:
 * ---------------------
 *                                    +-------------+
 *    Video Test Pattern Generator -> |             |
 * DDR -> Frame Buffer Read (CAM0) -> |             |
 * DDR -> Frame Buffer Read (CAM1) -> | Video Mixer |-> HDMI TX
 * DDR -> Frame Buffer Read (CAM2) -> |   (2ppc)    |   (2ppc)
 * DDR -> Frame Buffer Read (CAM3) -> |             |
 *                                    +-------------+
 *
 * The Frame Buffer Reads operate at 2 pixels per clock to match the Video Mixer and HDMI TX.
 */

/***************************** Include Files *********************************/
#include <stdint.h>
#include "xinterrupt_wrap.h"
#include "xv_mix_l2.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xil_exception.h"
#include "string.h"
#include "idt_8t49n24x.h"
#include "xvidc.h"
#include "xv_hdmic.h"
#include "xv_hdmic_vsif.h"
#include "dp159.h"
#include "sleep.h"
#include "xhdmi_edid.h"
#include "xv_hdmitxss.h"
#include "xvphy.h"
#include "xv_tpg.h"
#include "xgpio.h"
#include "xintc.h"
#include "reset_gpio.h"
#include "config.h"
#include "rpi_cam.h"
#include "pipe.h"


/************************** Constant Definitions *****************************/
#define I2C_CLK_ADDR    0x7C  /**< I2C Clk Address IDT_8T49N241*/

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"

/************************** Constant Definitions *****************************/
/* Assign Mode ID Enumeration. First entry Must be > XVIDC_VM_CUSTOM */
typedef enum {
	XVIDC_VM_1152x864_60_P = (XVIDC_VM_CUSTOM + 1),
	XVIDC_CM_NUM_SUPPORTED
}
XVIDC_CUSTOM_MODES;

/* Enabling this will register a custom resolution to the video timing table
 */
#define CUSTOM_RESOLUTION_ENABLE 1

/***************** Macros (Inline Functions) Definitions *********************/
/* These macro values need to changed whenever there is a change in version */
#define APP_MAJ_VERSION 5
#define APP_MIN_VERSION 4

#define INTRNAME_HDMITX 0
#define INTRNAME_HDCP1XTX  1
#define INTRNAME_HDCP1XTX_TIMER 2
#define INTRNAME_HDCP2XTX_TIMER   3

// Number of cameras/video pipes in the design
#define NUM_CAMS XPAR_XMIPICSISS_NUM_INSTANCES

// Frame buffer Rd/Wr buffer addresses (using physical memory)
#define CAM0_FRMBUF_BUFR_ADDR 0xA0000000
#define CAM1_FRMBUF_BUFR_ADDR 0xA1000000
#define CAM2_FRMBUF_BUFR_ADDR 0xA2000000
#define CAM3_FRMBUF_BUFR_ADDR 0xA3000000

/**************************** Type Definitions *******************************/

/************************** Function Prototypes ******************************/
int I2cClk(u32 InFreq, u32 OutFreq);

void EnableHdmiTx(XVphy *VphyPtr, XV_HdmiTxSs *HdmiTxSsPtr,
					XVidC_VideoMode VideoMode,
					XVidC_ColorFormat ColorFormat,
					XVidC_ColorDepth Bpc);

void TxConnectCallback(void *CallbackRef);
void TxToggleCallback(void *CallbackRef);
void TxBrdgUnlockedCallback(void *CallbackRef);
void TxStreamUpCallback(void *CallbackRef);
void TxStreamDownCallback(void *CallbackRef);
void VphyHdmiTxInitCallback(void *CallbackRef);
void VphyHdmiTxReadyCallback(void *CallbackRef);

void VphyErrorCallback(void *CallbackRef);
void VphyProcessError(void);

/************************* Variable Definitions *****************************/
// VPHY structure
XVphy              Vphy;
u8                 VphyErrorFlag;
u8                 VphyPllLayoutErrorFlag;

// HDMI TX SS structure
XV_HdmiTxSs        HdmiTxSs;
XV_HdmiTxSs_Config *XV_HdmiTxSs_ConfigPtr;

EdidHdmi20 EdidHdmi20_t;

// Test Pattern Generator Structure
XV_tpg             Tpg;
XV_tpg_Config      *Tpg_ConfigPtr;

// Video Mixer
XV_Mix_l2  VMix;

// Flag indicates whether the TX Cable is connected or not
u8                 TxCableConnect = (FALSE);

// TX busy flag. This flag is set while the TX is initialized
u8                 TxBusy = (TRUE);
// TX restart HDMI TX. This flag is set when the TX cable has been reconnected.
u8                 TxRestartHdmiTx = (FALSE);
// TX Stream Up Status Flag, Avoiding Race condition
u8                 IsStreamUp = (FALSE);
u64                TxLineRate = 0;
// Sink Ready: Become true when the EDID parsing is completed upon cable connect
u8                 SinkReady = (FALSE);

// Interrupt Controller
static XIntc       Intc;

// GPIO for resets of the video pipes
XGpio GpioVideoResets;
XGpio_Config *GpioVideoResets_ConfigPtr;

#ifdef XPAR_MIPI_0_AXI_IIC_0_BASEADDR
// Video pipe 0
VideoPipe Cam0;

VideoPipeBaseAddr CamBaseAddr0 = {
		XPAR_MIPI_0_AXI_IIC_0_BASEADDR,
		XPAR_MIPI_0_AXI_GPIO_0_BASEADDR,
		XPAR_MIPI_0_V_FRMBUF_WR_BASEADDR,
		XPAR_MIPI_0_V_FRMBUF_RD_BASEADDR,
		CAM0_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_0_DEMOSAIC_0_BASEADDR,
		XPAR_MIPI_0_V_GAMMA_LUT_BASEADDR,
		XPAR_MIPI_0_V_PROC_BASEADDR
};
#endif

#ifdef XPAR_MIPI_1_AXI_IIC_0_BASEADDR
// Video pipe 1
VideoPipe Cam1;

VideoPipeBaseAddr CamBaseAddr1 = {
		XPAR_MIPI_1_AXI_IIC_0_BASEADDR,
		XPAR_MIPI_1_AXI_GPIO_0_BASEADDR,
		XPAR_MIPI_1_V_FRMBUF_WR_BASEADDR,
		XPAR_MIPI_1_V_FRMBUF_RD_BASEADDR,
		CAM1_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_1_DEMOSAIC_0_BASEADDR,
		XPAR_MIPI_1_V_GAMMA_LUT_BASEADDR,
		XPAR_MIPI_1_V_PROC_BASEADDR
};
#endif

#ifdef XPAR_MIPI_2_AXI_IIC_0_BASEADDR
// Video pipe 2
VideoPipe Cam2;

VideoPipeBaseAddr CamBaseAddr2 = {
		XPAR_MIPI_2_AXI_IIC_0_BASEADDR,
		XPAR_MIPI_2_AXI_GPIO_0_BASEADDR,
		XPAR_MIPI_2_V_FRMBUF_WR_BASEADDR,
		XPAR_MIPI_2_V_FRMBUF_RD_BASEADDR,
		CAM2_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_2_DEMOSAIC_0_BASEADDR,
		XPAR_MIPI_2_V_GAMMA_LUT_BASEADDR,
		XPAR_MIPI_2_V_PROC_BASEADDR
};
#endif

#ifdef XPAR_MIPI_3_AXI_IIC_0_BASEADDR
// Video pipe 3
VideoPipe Cam3;

VideoPipeBaseAddr CamBaseAddr3 = {
		XPAR_MIPI_3_AXI_IIC_0_BASEADDR,
		XPAR_MIPI_3_AXI_GPIO_0_BASEADDR,
		XPAR_MIPI_3_V_FRMBUF_WR_BASEADDR,
		XPAR_MIPI_3_V_FRMBUF_RD_BASEADDR,
		CAM3_FRMBUF_BUFR_ADDR,
		XPAR_MIPI_3_DEMOSAIC_0_BASEADDR,
		XPAR_MIPI_3_V_GAMMA_LUT_BASEADDR,
		XPAR_MIPI_3_V_PROC_BASEADDR
};
#endif

// Indices of the video pipes in this design
static const int g_mipi_present[] = {
#ifdef XPAR_MIPI_0_AXI_IIC_0_BASEADDR
    0,
#endif
#ifdef XPAR_MIPI_1_AXI_IIC_0_BASEADDR
    1,
#endif
#ifdef XPAR_MIPI_2_AXI_IIC_0_BASEADDR
    2,
#endif
#ifdef XPAR_MIPI_3_AXI_IIC_0_BASEADDR
    3,
#endif
};

/* Return the 1-based Video Mixer channel for a given MIPI index,
   or 0 if that MIPI isn’t present. */
static int mixer_channel_for_mipi(int mipi_idx)
{
    for (int i = 0; i < NUM_CAMS; ++i) {
        if (g_mipi_present[i] == mipi_idx) {
            return i + 1;  // 1-based channels: [1..NUM_ACTIVE_MIPI]
        }
    }
    return 0; // not present
}

/*
 * The table below determines how the four camera video streams are organized
 * on a single 1080p video stream
 */
static const XVidC_VideoWindow MixLayerConfig[4] =
{// X   Y     W    H
  {160, 40,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 1
  {1040, 40,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 2
  {160, 560,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}, //Layer 3
  {1040, 560,  VPROC_WIDTH_OUT, VPROC_HEIGHT_OUT}  //Layer 4
};

// VideoPipe struct
typedef struct {
	uint8_t Index;
    VideoPipe *VideoPipePtr;    
} Cam;

/*
 * ActiveCams - the cameras that are found to be actually connected 
 * (as confirmed by I2C comms) are placed in an array so that they 
 * can be iterated
 */
Cam ActiveCams[NUM_CAMS];
u8 NumActiveCams = 0;

/************************** Function Definitions *****************************/

/*****************************************************************************/
/**
*
* This function checks the TX Busy flag, and returns TRUE with prompt. and
* FALSE
* @return TRUE/FALSE.
*
* @note   None.
*
******************************************************************************/
u8 CheckTxBusy (void)
{
	if (TxBusy) {
		xil_printf("Either TX still on transition to a new video"
		            " format\r\nor the TX cable is not connected\r\n");
	}
	return (TxBusy);
}

/*****************************************************************************/
/**
*
* This function sets up the IDT 8T49N24x clock generator either in free or 
* locked mode.
*
* @param  Index specifies an index for selecting mode frequency.
* @param  Mode specifies either free or locked mode.
*
* @return
*   - Zero if error in programming external clock.
*   - One if programmed external clock.
*
* @note   None.
*
******************************************************************************/
int I2cClk(u32 InFreq, u32 OutFreq)
{
	int Status;

	/* Reset I2C controller before issuing new transaction.
	 * This is required to recover the IIC controller in case a previous
	 * transaction is pending.
	 */
	XIic_WriteReg(XPAR_AXI_IIC_HDMI_CLK_BASEADDR, XIIC_RESETR_OFFSET,
				  XIIC_RESET_MASK);

	/* Free running mode */
	if (InFreq == 0) {
		Status = IDT_8T49N24x_SetClock((XPAR_AXI_IIC_HDMI_CLK_BASEADDR),
					       (I2C_CLK_ADDR),
					       (IDT_8T49N24X_XTAL_FREQ),
					       OutFreq,
					       TRUE);

		if (Status != (XST_SUCCESS)) {
			xil_printf("Error programming IDT_8T49N241\r\n");
			return XST_FAILURE;
		}
	}

	/* Locked mode */
	else {
		Status = IDT_8T49N24x_SetClock((XPAR_AXI_IIC_HDMI_CLK_BASEADDR),
					       (I2C_CLK_ADDR),
					       InFreq,
					       OutFreq,
					       FALSE);

		if (Status != (XST_SUCCESS)) {
			xil_printf("Error programming IDT_8T49N241\r\n");
			return XST_FAILURE;
		}
	}

	return XST_SUCCESS;
}


/*****************************************************************************/
/**
*
* This function is called when a TX connect event has occurred.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxConnectCallback(void *CallbackRef) {
    xil_printf("TX connect callback\n\r");
	XV_HdmiTxSs *HdmiTxSsPtr = (XV_HdmiTxSs *)CallbackRef;
	if(HdmiTxSsPtr->IsStreamConnected == (FALSE)) {
		/* TX Cable is disconnected */
		TxCableConnect = (FALSE);

		/* Cable is disconnected, don't restart HDMI TX */
		TxRestartHdmiTx = (FALSE);
		/* Cable is disconnected, don't allow any TX operation */
		TxBusy = (TRUE);

		XVphy_IBufDsEnable(&Vphy, 0, XVPHY_DIR_TX, (FALSE));

	} else {
		/* Set TX Cable Connect Flag to (TRUE) as the cable is
		 * connected
		 */
		TxCableConnect = (TRUE);

		TxRestartHdmiTx = (TRUE);
		TxBusy = (FALSE);

		XVphy_IBufDsEnable(&Vphy, 0, XVPHY_DIR_TX, (TRUE));

		/* Initialize EDID App during cable connect */
		EDIDConnectInit(&EdidHdmi20_t);
		/* Read the EDID and the SCDC */
		EdidScdcCheck(HdmiTxSsPtr, &EdidHdmi20_t);

	}
}

/*****************************************************************************/
/**
*
* This function is called when a TX toggle event has occurred.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxToggleCallback(void *CallbackRef) {
	XV_HdmiTxSs_StreamStart(&HdmiTxSs);

}

/*****************************************************************************/
/**
*
* This function is called when the GT TX reference input clock has changed.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void VphyHdmiTxInitCallback(void *CallbackRef) {
	XV_HdmiTxSs_RefClockChangeInit(&HdmiTxSs);
}

/*****************************************************************************/
/**
*
* This function is called when the GT TX has been initialized
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void VphyHdmiTxReadyCallback(void *CallbackRef) {
}


/*****************************************************************************/
/**
*
* This function is called whenever an error condition in VPHY occurs.
* This will fill the FIFO of VPHY error events which will be processed outside
* the ISR.
*
* @param  CallbackRef is the VPHY instance pointer
* @param  ErrIrqType is the VPHY error type
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void VphyErrorCallback(void *CallbackRef) {
	VphyErrorFlag = TRUE;
}

/*****************************************************************************/
/**
*
* This function is called in the application to process the pending
* VPHY errors
*
* @param  None.
*
* @return None.
*
* @note   This function can be expanded to perform necessary actions depending
*		on the error type. For example, XVPHY_ERR_PLL_LAYOUT can be
*		used to automatically switch in and out of bonded mode for
*               GTXE2 devices
*
******************************************************************************/
void VphyProcessError(void) {
	if (VphyErrorFlag == TRUE) {
		xil_printf(ANSI_COLOR_RED "VPHY Error: See log for details"
				   ANSI_COLOR_RESET "\r\n");
	}
	/* Clear Flag */
	VphyErrorFlag = FALSE;

}

/*****************************************************************************/
/**
*
* This function is called when a bridge unlocked has occurred.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxBrdgUnlockedCallback(void *CallbackRef) {
}

/*****************************************************************************/
/**
*
* This function is called when the TX stream is up.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxStreamUpCallback(void *CallbackRef) {

	XHdmiC_AVI_InfoFrame  *AVIInfoFramePtr;
	IsStreamUp = TRUE;

	XV_HdmiTxSs *HdmiTxSsPtr = (XV_HdmiTxSs *)CallbackRef;
	XVphy_PllType TxPllType;
	XVidC_VideoStream *HdmiTxSsVidStreamPtr;

	// Obtain the stream information
	HdmiTxSsVidStreamPtr = XV_HdmiTxSs_GetVideoStream(HdmiTxSsPtr);

	/* Check whether the sink is DVI/HDMI Supported */
	if (EdidHdmi20_t.EdidCtrlParam.IsHdmi == XVIDC_ISDVI) {
		if (HdmiTxSsVidStreamPtr->ColorDepth != XVIDC_BPC_8 ||
			HdmiTxSsVidStreamPtr->ColorFormatId != XVIDC_CSF_RGB) {
			xil_printf(ANSI_COLOR_YELLOW "Un-able to set TX "
						"stream, sink is DVI\r\n"
						ANSI_COLOR_RESET "\r\n");
			/* Clear TX busy flag */
			TxBusy = (FALSE);
			/* Don't set TX, if the Sink is DVI, but the source
			 * properties are:
			 *      - Color Depth more than 8 BPC
			 *      - Color Space not RGB
			 */
			return;
		} else {
			xil_printf(ANSI_COLOR_YELLOW "Set TX stream to DVI,"
				" sink is DVI\r\n" ANSI_COLOR_RESET "\r\n");
			XV_HdmiTxSs_AudioMute(HdmiTxSsPtr, TRUE);
			XV_HdmiTxSS_SetDviMode(HdmiTxSsPtr);
		}
	} else {
		XV_HdmiTxSS_SetHdmiMode(HdmiTxSsPtr);
		XV_HdmiTxSs_AudioMute(HdmiTxSsPtr, FALSE);
	}

	xil_printf("TX stream is up\r\n");

	/* Check for the 480i/576i during color bar mode
	 * When it's (TRUE), set the Info Frame Pixel Repetition to x2
	 */
	AVIInfoFramePtr = XV_HdmiTxSs_GetAviInfoframe(HdmiTxSsPtr);

	if ( (HdmiTxSsVidStreamPtr->VmId == XVIDC_VM_1440x480_60_I) ||
		     (HdmiTxSsVidStreamPtr->VmId == XVIDC_VM_1440x576_50_I) ) {
			AVIInfoFramePtr->PixelRepetition =
					XHDMIC_PIXEL_REPETITION_FACTOR_2;
	} else {
			AVIInfoFramePtr->PixelRepetition =
					XHDMIC_PIXEL_REPETITION_FACTOR_1;
	}
	TxPllType = XVphy_GetPllType(&Vphy,
	                             0,
				     XVPHY_DIR_TX,
				     XVPHY_CHANNEL_ID_CH1);

	if ((TxPllType == XVPHY_PLL_TYPE_CPLL)) {
		TxLineRate = XVphy_GetLineRateHz(&Vphy,
		                                 0,
						 XVPHY_CHANNEL_ID_CH1);

	} else if((TxPllType == XVPHY_PLL_TYPE_QPLL) ||
			  (TxPllType == XVPHY_PLL_TYPE_QPLL0) ||
			  (TxPllType == XVPHY_PLL_TYPE_PLL0)) {
		TxLineRate =
			XVphy_GetLineRateHz(&Vphy, 0, XVPHY_CHANNEL_ID_CMN0);
	} else {
		TxLineRate =
			XVphy_GetLineRateHz(&Vphy, 0, XVPHY_CHANNEL_ID_CMN1);
	}

	/* Copy Sampling Rate */
	XV_HdmiTxSs_SetSamplingRate(HdmiTxSsPtr, Vphy.HdmiTxSampleRate);

	/* Clear TX busy flag */
	TxBusy = (FALSE);

}

/*****************************************************************************/
/**
*
* This function is called when the TX stream is down.
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxStreamDownCallback(void *CallbackRef) {
	xil_printf("TX stream is down\r\n");
}

/*****************************************************************************/
/**
*
* This function is called when a TX Bridge Overflow event has occurred.
* TX Video Bridge Debug Utility
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxBrdgOverflowCallback(void *CallbackRef) {

	/* xil_printf(ANSI_COLOR_YELLOW "TX Video Bridge Overflow"
			ANSI_COLOR_RESET "\r\n"); */
}

/*****************************************************************************/
/**
*
* This function is called when a TX Bridge Underflow event has occurred.
* TX Video Bridge Debug Utility
*
* @param  None.
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void TxBrdgUnderflowCallback(void *CallbackRef) {

	/* xil_printf(ANSI_COLOR_YELLOW "TX Video Bridge Underflow"
			ANSI_COLOR_RESET "\r\n"); */
}


/*****************************************************************************/
/**
*
* This function enables the HDMI TX
*
* @param VphyPtr is a pointer to the VPHY core instance.
* @param HdmiTxSsPtr is a pointer to the XV_HdmiTxSs instance.
* @param Requested Video mode
* @param Requested ColorFormat
* @param Requested ColorDepth
* @param Requested Pixels per clock
*
* @return None.
*
* @note   None.
*
******************************************************************************/
void EnableHdmiTx(XVphy                *VphyPtr,
		    XV_HdmiTxSs          *HdmiTxSsPtr,
		    XVidC_VideoMode      VideoMode,
		    XVidC_ColorFormat    ColorFormat,
		    XVidC_ColorDepth     Bpc) {

	u32 TmdsClock = 0;
	u32 Result;
	XVidC_VideoStream *HdmiTxSsVidStreamPtr;
	XHdmiC_AVI_InfoFrame *AviInfoFramePtr;
	XHdmiC_VSIF *VSIFPtr;

	HdmiTxSsVidStreamPtr = XV_HdmiTxSs_GetVideoStream(HdmiTxSsPtr);
	AviInfoFramePtr = XV_HdmiTxSs_GetAviInfoframe(HdmiTxSsPtr);
	VSIFPtr = XV_HdmiTxSs_GetVSIF(HdmiTxSsPtr);

	/* Reset Avi InfoFrame */
	(void)memset((void *)AviInfoFramePtr, 0, sizeof(XHdmiC_AVI_InfoFrame));
	/* Reset Vendor Specific InfoFrame */
	(void)memset((void *)VSIFPtr, 0, sizeof(XHdmiC_VSIF));

	/* Check if the TX isn't busy already */
	if (!CheckTxBusy()) {

		TxBusy = (TRUE);         /* Set TX busy flag */
#if(CUSTOM_RESOLUTION_ENABLE == 1)
		if (VideoMode < XVIDC_VM_NUM_SUPPORTED ||
		       (VideoMode > XVIDC_VM_CUSTOM &&
		        VideoMode < (XVidC_VideoMode)XVIDC_CM_NUM_SUPPORTED)) {
#else
		if (VideoMode < XVIDC_VM_NUM_SUPPORTED) {
#endif

			/* Disable TX TDMS clock */
			XVphy_Clkout1OBufTdsEnable(VphyPtr,
						XVPHY_DIR_TX,
						(FALSE));

		} else {
			TxBusy = (FALSE);
			xil_printf("Video mode not supported, please change"
					" video mode\r\n");
			return;
		}

		TmdsClock = XV_HdmiTxSs_SetStream(HdmiTxSsPtr,
						VideoMode,
						ColorFormat,
						Bpc,
						NULL);

		/* Calling this API can enable or disable scrambler even
		 * if the TMDS clock is >340MHz.
		 * E.g:
		 * 	XV_HdmiTxSs_SetScrambler(HdmiTxSsPtr, TRUE);
		 */

		/* Update AVI InfoFrame */
		AviInfoFramePtr->Version = 2;
		AviInfoFramePtr->ColorSpace =
				XV_HdmiC_XVidC_To_IfColorformat(ColorFormat);
		AviInfoFramePtr->VIC =
				HdmiTxSsPtr->HdmiTxPtr->Stream.Vic;

		/* Set TX reference clock */
		VphyPtr->HdmiTxRefClkHz = TmdsClock;

		/* Set GT TX parameters */
		Result = XVphy_SetHdmiTxParam(VphyPtr,
					0,
					XVPHY_CHANNEL_ID_CHA,
					HdmiTxSsVidStreamPtr->PixPerClk,
					HdmiTxSsVidStreamPtr->ColorDepth,
					HdmiTxSsVidStreamPtr->ColorFormatId);

		if (Result == (XST_FAILURE)) {
			TxBusy = (FALSE);
			xil_printf
			  ("Unable to set requested TX video resolution.\r\n");
			xil_printf
			  ("Returning to previously TX video resolution.\r\n");
			return;
		}

		/* Disable RX clock forwarding */
		XVphy_Clkout1OBufTdsEnable(VphyPtr, XVPHY_DIR_RX, (FALSE));

		/* Program external clock generator in free running mode */
		I2cClk(0, VphyPtr->HdmiTxRefClkHz);
	}
}

void Xil_AssertCallbackRoutine(u8 *File, s32 Line) {
	xil_printf("Assertion in File %s, on line %0d\r\n", File, Line);
}

/*
 * Initializes a video pipe by index
 * First releases the resets, then initializes the video pipe
 */
static void try_init_pipe(int idx, VideoPipe* cam, const VideoPipeBaseAddr* addrs)
{
    if (pipe_init(cam, addrs) == XST_SUCCESS && cam->IsConnected) {
        ActiveCams[NumActiveCams].Index = (uint8_t)idx;
        ActiveCams[NumActiveCams].VideoPipePtr = cam;
        ++NumActiveCams;
    }
}

// Returns the name of a specific camera model
static const char* cam_type_name(uint8_t model)
{
    switch (model) {
        case RPI_CAM_TYPE_OV5640: return "Digilent P-Cam";
        case RPI_CAM_TYPE_IMX219: return "Raspberry Pi Camera v2";
        default:                  return "Unknown";
    }
}

/*
 * Main function
 */
int main() {
	u32 Status = XST_FAILURE;
	XVphy_Config *XVphyCfgPtr;
	XVidC_VideoStream *HdmiTxSsVidStreamPtr;
    XVidC_VideoTiming const *TimingPtr;

	xil_printf("\r\n\r\n");
	xil_printf("################################################\r\n");
	xil_printf("#    Raspberry Pi Camera to HDMI Example       #\r\n");
	xil_printf("#    For the Opsero RPi Camera FMC (OP068)     #\r\n");
	xil_printf("################################################\r\n");

	TxBusy            = (TRUE);
	TxRestartHdmiTx = (FALSE);
	VphyErrorFlag = FALSE;
	VphyPllLayoutErrorFlag = FALSE;

	/* Initialize platform */
	init_platform();

	/* Initialize IIC */
	IDT_8T49N24x_Init(XPAR_AXI_IIC_HDMI_CLK_BASEADDR, I2C_CLK_ADDR);

	/* Initialize IRQ */
	Xil_ExceptionInit();

	/*
	 * Register the interrupt controller handler with the exception table.
	 */
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
				(Xil_ExceptionHandler)XIntc_InterruptHandler,
				(XIntc *)&Intc);

	/* Initialize HDMI TX Subsystem */

	XV_HdmiTxSs_ConfigPtr =
		XV_HdmiTxSs_LookupConfig(XPAR_XV_HDMITX_0_BASEADDR);

	if(XV_HdmiTxSs_ConfigPtr == NULL) {
		HdmiTxSs.IsReady = 0;
	}

	/* Initialize top level and all included sub-cores */
	Status = XV_HdmiTxSs_CfgInitialize(&HdmiTxSs, XV_HdmiTxSs_ConfigPtr,
					XV_HdmiTxSs_ConfigPtr->BaseAddress);
	if(Status != XST_SUCCESS) {
		xil_printf
		       ("ERR:: HDMI TX Subsystem Initialization failed %d\r\n",
		        Status);
	}

	/* Set the Application version in TXSs driver structure */
	XV_HdmiTxSS_SetAppVersion(&HdmiTxSs, APP_MAJ_VERSION, APP_MIN_VERSION);

	/* Register HDMI TX SS Interrupt Handler with Interrupt Controller */
	Status = XSetupInterruptSystem(&HdmiTxSs,
				       XV_HdmiTxSS_HdmiTxIntrHandler,
				       XV_HdmiTxSs_ConfigPtr->IntrId[INTRNAME_HDMITX],
				       XV_HdmiTxSs_ConfigPtr->IntrParent,
				       XINTERRUPT_DEFAULT_PRIORITY);
	if (Status == XST_SUCCESS) {
	} else {
		xil_printf
			("ERR:: Unable to register HDMI TX interrupt handler");
		xil_printf("HDMI TX SS initialization error\r\n");
		return XST_FAILURE;
	}

	/* HDMI TX SS callback setup */
	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_CONNECT,
				(void *)TxConnectCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_TOGGLE,
				(void *)TxToggleCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_BRDGUNLOCK,
				(void *)TxBrdgUnlockedCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_BRDGOVERFLOW,
				(void *)TxBrdgOverflowCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_BRDGUNDERFLOW,
				(void *)TxBrdgUnderflowCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_STREAM_UP,
				(void *)TxStreamUpCallback,
				(void *)&HdmiTxSs);

	XV_HdmiTxSs_SetCallback(&HdmiTxSs,
				XV_HDMITXSS_HANDLER_STREAM_DOWN,
				(void *)TxStreamDownCallback,
				(void *)&HdmiTxSs);

	/*
	 *  Initialize Video PHY
	 *  The GT needs to be initialized after the HDMI RX and TX.
	 *  The reason for this is the GtRxInitStartCallback
	 *  calls the RX stream down callback.
	 *
         */
	XVphyCfgPtr = XVphy_LookupConfig(XPAR_XVPHY_0_BASEADDR);
	if (XVphyCfgPtr == NULL) {
		xil_printf("Video PHY device not found\r\n\r\n");
		return XST_FAILURE;
	}

	/* Register VPHY Interrupt Handler */
	Status = XSetupInterruptSystem(&Vphy,
				(XInterruptHandler)XVphy_InterruptHandler,
				XVphyCfgPtr->IntrId,
				XVphyCfgPtr->IntrParent,
				XINTERRUPT_DEFAULT_PRIORITY);
	if (Status != XST_SUCCESS) {
		xil_printf("HDMI VPHY Interrupt Vec ID not found!\r\n");
		return XST_FAILURE;
	}

	/* Initialize HDMI VPHY */
	Status = XVphy_Hdmi_CfgInitialize(&Vphy, 0, XVphyCfgPtr);

	if (Status != XST_SUCCESS) {
		xil_printf("HDMI VPHY initialization error\r\n");
		return XST_FAILURE;
	}

	/* Enable VPHY Interrupt */
	/* VPHY callback setup */
	XVphy_SetHdmiCallback(&Vphy,
				XVPHY_HDMI_HANDLER_TXINIT,
				(void *)VphyHdmiTxInitCallback,
				(void *)&Vphy);
	XVphy_SetHdmiCallback(&Vphy,
				XVPHY_HDMI_HANDLER_TXREADY,
				(void *)VphyHdmiTxReadyCallback,
				(void *)&Vphy);

	XVphy_SetErrorCallback(&Vphy,
				(void *)VphyErrorCallback,
				(void *)&Vphy);

    /*
     * Initialize the main AXI GPIO for resets
     */
    GpioVideoResets_ConfigPtr = XGpio_LookupConfig(XPAR_MAIN_RESETN_GPIO_BASEADDR);
	if(GpioVideoResets_ConfigPtr == NULL) {
        xil_printf("GPIO for main resets not found\r\n");
		GpioVideoResets.IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	Status = XGpio_CfgInitialize(&GpioVideoResets,
				GpioVideoResets_ConfigPtr,
				GpioVideoResets_ConfigPtr->BaseAddress);
	if(Status != XST_SUCCESS) {
		xil_printf("Failed to initialize GPIO for Video pipe resets\r\n");
		return(XST_FAILURE);
	}

	// Set GPIO directions (1=input, 0=output) - ALL OUTPUTS
	XGpio_SetDataDirection(&GpioVideoResets, 1, 0x00);

	// Assert reset for Video Mixer and Test Pattern Generator
	reset_assert(RESET_MASK_VMIX | RESET_MASK_VTPG);
    usleep(10000);

	/*
	 * Initialize and configure the Video Mixer
	 */
    reset_deassert(RESET_MASK_VMIX);
	XVidC_VideoStream Stream;
	XVidC_ColorFormat Cfmt;
	Status  = XVMix_Initialize(&VMix, XPAR_V_MIX_BASEADDR);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Video Mixer device not initialized\r\n");
		return(XST_FAILURE);
	}

	// Video stream properties of the mixer's master input and output
	Stream.VmId = XVidC_GetVideoModeId(VMODE_WIDTH,VMODE_HEIGHT,VMODE_FRAMERATE,FALSE);
	XVMix_GetLayerColorFormat(&VMix, XVMIX_LAYER_MASTER, &Cfmt);
	Stream.PixPerClk = VMix.Mix.Config.PixPerClk;
	Stream.ColorFormatId = Cfmt;
	Stream.ColorDepth = VMix.Mix.Config.MaxDataWidth;
	TimingPtr = XVidC_GetTimingInfo(Stream.VmId);
	Stream.Timing = *TimingPtr;
	Stream.FrameRate = XVidC_GetFrameRate(Stream.VmId);

	XVMix_LayerDisable(&VMix, XVMIX_LAYER_MASTER);
	XVMix_LayerDisable(&VMix, XVMIX_LAYER_ALL);
	XVMix_SetVidStream(&VMix, &Stream);

	// Background color used when a streaming layer is disabled
	XVMix_SetBackgndColor(&VMix, XVMIX_BKGND_GREEN, Stream.ColorDepth);

	XVidC_VideoWindow Win;
	u32 Stride;
	for(u8 layerIndex = 0; layerIndex < NUM_CAMS; layerIndex++) {
		Win = MixLayerConfig[layerIndex];
		XVMix_GetLayerColorFormat(&VMix, layerIndex+1, &Cfmt);
		Stride = ((Cfmt == XVIDC_CSF_YCRCB_422) ? 2: 4); //BytesPerPixel
		Stride *= Win.Width;
		Status = XVMix_SetLayerWindow(&VMix, layerIndex+1, &Win, Stride);
		if(Status != XST_SUCCESS) {
			xil_printf("ERROR: Failed to set window for Video Mixer layer %d\r\n",layerIndex+1);
		}
	}

	XVMix_LayerEnable(&VMix, XVMIX_LAYER_MASTER);
	XVMix_InterruptDisable(&VMix);
	XVMix_Start(&VMix);

	/*
	 * Initialize and configure the Test Pattern Generator
     * The TPG generates the background for the screen and also ensures that we always
     * have a video to display, regardless of which cameras are actually connected.
	 */
    reset_deassert(RESET_MASK_VTPG);
	Tpg_ConfigPtr = XV_tpg_LookupConfig(XPAR_V_TPG_BASEADDR);
	if(Tpg_ConfigPtr == NULL) {
		Tpg.IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	Status = XV_tpg_CfgInitialize(&Tpg,
				Tpg_ConfigPtr, Tpg_ConfigPtr->BaseAddress);
	if(Status != XST_SUCCESS) {
		xil_printf("ERR:: TPG Initialization failed %d\r\n", Status);
		return(XST_FAILURE);
	}
    XV_tpg_DisableAutoRestart(&Tpg);
	XV_tpg_Set_height(&Tpg, VMODE_HEIGHT);
	XV_tpg_Set_width(&Tpg, VMODE_WIDTH);
	XV_tpg_Set_colorFormat(&Tpg, Cfmt);
	XV_tpg_Set_bckgndId(&Tpg, XTPG_BKGND_CROSS_HATCH);
	XV_tpg_Set_ovrlayId(&Tpg, 0);
	XV_tpg_EnableAutoRestart(&Tpg);
	XV_tpg_Start(&Tpg);
	
	/* Start with 1080p stream */
	XV_HdmiTxSs_SetStream(
		&HdmiTxSs,
		XVIDC_VM_1920x1080_60_P,
		XVIDC_CSF_RGB,
		XVIDC_BPC_8,
		NULL);

	/*
	 * Initialize Video pipe for each camera
	 */
#ifdef XPAR_MIPI_0_AXI_IIC_0_BASEADDR
    try_init_pipe(0, &Cam0, &CamBaseAddr0);
#endif
#ifdef XPAR_MIPI_1_AXI_IIC_0_BASEADDR
    try_init_pipe(1, &Cam1, &CamBaseAddr1);
#endif
#ifdef XPAR_MIPI_2_AXI_IIC_0_BASEADDR
    try_init_pipe(2, &Cam2, &CamBaseAddr2);
#endif
#ifdef XPAR_MIPI_3_AXI_IIC_0_BASEADDR
    try_init_pipe(3, &Cam3, &CamBaseAddr3);
#endif
    
	if(NumActiveCams == 0) {
		xil_printf("ERROR: No video pipes were activated.\n\r");
		return 0;
	}

	/*
	 * List the connected cameras
	 */
	xil_printf("\n\rDetected %d connected cameras:\n\r",NumActiveCams);
    for (int i = 0; i < NumActiveCams; ++i) {
        int layer = mixer_channel_for_mipi(ActiveCams[i].Index);
        RpiCamera *rcam = &(ActiveCams[i].VideoPipePtr->Camera);

        const char *type  = cam_type_name(rcam->sensor.model);

        xil_printf("  - CAM%-1d: %-24s to Mixer layer %-2d\r\n",
                ActiveCams[i].Index, type, layer);
    }

	/*
	 * Start the connected cameras and enable corresponding mixer layers
	 */
    xil_printf("\n\rConfiguring cameras:\n\r");
	for(int i = 0; i < NumActiveCams; i++) {
        xil_printf("  - CAM%-1d: ",ActiveCams[i].Index);
		Status = pipe_start_camera(ActiveCams[i].VideoPipePtr);
        if(Status == XST_SUCCESS) {
            xil_printf("SUCCESS\n\r");
        } else {
            xil_printf("FAILED\n\r");
        }
		XVMix_LayerEnable(&VMix, mixer_channel_for_mipi(ActiveCams[i].Index));
	}
    xil_printf("\n\r");

	XV_HdmiTxSS_MaskDisable(&HdmiTxSs);

    /*
     * Bring up the HDMI monitor
     */
    TxCableConnect = (TRUE);
	TxRestartHdmiTx = (TRUE);
	TxBusy = (FALSE);
	XVphy_IBufDsEnable(&Vphy, 0, XVPHY_DIR_TX, (TRUE));
	// Initialize EDID App during cable connect
	EDIDConnectInit(&EdidHdmi20_t);
	// Read the EDID and the SCDC
	EdidScdcCheck(&HdmiTxSs, &EdidHdmi20_t);

	/* Main loop */
	do {

		SinkReady = SinkReadyCheck(&HdmiTxSs, &EdidHdmi20_t);

        if (TxRestartHdmiTx && SinkReady) {
			/* Clear TxRestartHdmiTx Flag */
			TxRestartHdmiTx = (FALSE);
			HdmiTxSsVidStreamPtr =
					XV_HdmiTxSs_GetVideoStream(&HdmiTxSs);
			EnableHdmiTx(&Vphy,
					&HdmiTxSs,
					HdmiTxSsVidStreamPtr->VmId,
					HdmiTxSsVidStreamPtr->ColorFormatId,
					HdmiTxSsVidStreamPtr->ColorDepth);
		}

		if (IsStreamUp && SinkReady) {
			IsStreamUp = FALSE;

			i2c_dp159(&Vphy, 0, TxLineRate);
			XVphy_Clkout1OBufTdsEnable
				(&Vphy, XVPHY_DIR_TX, (TRUE));
		}

		/* VPHY error */
		VphyProcessError();

	}
	while (1);

	return 0;
}
