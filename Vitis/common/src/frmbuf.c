/* 
 * Opsero Electronic Design Inc. Copyright 2023
 * 
 * The functions in this module setup the Frame buffer Rd and Wr for pass-through
 * such that video frames coming into the FrmbufWr are written to memory and then
 * immediately read back from memory by the FrmbufRd. The init function is given
 * a pointer to the Frmbuf struct which contains the Rd and Wr cores, as well
 * as the variables for keeping track of the read/write addresses. Each
 * Frmbuf is given it's own "base address" at which it will store three frames.
 * The callback functions rotate the read/write addresses such that the next
 * frame to read is the one that we just wrote, and the pointer to the next
 * write location is incremented and wrapped around when needed.
 *
******************************************************************************/

#include "frmbuf.h"
#include "xparameters.h"
#include "config.h"

#define COLOR_FORMAT_INDEX 7 // RGB

#define NUM_TEST_FORMATS 26

//mapping between memory and streaming video formats
typedef struct {
  XVidC_ColorFormat MemFormat;
  XVidC_ColorFormat StreamFormat;
  u16 FormatBits;
} VideoFormats;

VideoFormats ColorFormats[NUM_TEST_FORMATS] =
{
  //memory format            stream format        bits per component
  {XVIDC_CSF_MEM_RGBX8,      XVIDC_CSF_RGB,       8},
  {XVIDC_CSF_MEM_YUVX8,      XVIDC_CSF_YCRCB_444, 8},
  {XVIDC_CSF_MEM_YUYV8,      XVIDC_CSF_YCRCB_422, 8},
  {XVIDC_CSF_MEM_RGBX10,     XVIDC_CSF_RGB,       10},
  {XVIDC_CSF_MEM_YUVX10,     XVIDC_CSF_YCRCB_444, 10},
  {XVIDC_CSF_MEM_Y_UV8,      XVIDC_CSF_YCRCB_422, 8},
  {XVIDC_CSF_MEM_Y_UV8_420,  XVIDC_CSF_YCRCB_420, 8},
  {XVIDC_CSF_MEM_RGB8,       XVIDC_CSF_RGB,       8},
  {XVIDC_CSF_MEM_YUV8,       XVIDC_CSF_YCRCB_444, 8},
  {XVIDC_CSF_MEM_Y_UV10,     XVIDC_CSF_YCRCB_422, 10},
  {XVIDC_CSF_MEM_Y_UV10_420, XVIDC_CSF_YCRCB_420, 10},
  {XVIDC_CSF_MEM_Y8,         XVIDC_CSF_YONLY, 8},
  {XVIDC_CSF_MEM_Y10,        XVIDC_CSF_YONLY, 10},
  {XVIDC_CSF_MEM_BGRX8,      XVIDC_CSF_RGB,       8},
  {XVIDC_CSF_MEM_UYVY8,      XVIDC_CSF_YCRCB_422, 8},
  {XVIDC_CSF_MEM_BGR8,       XVIDC_CSF_RGB,       8},
  {XVIDC_CSF_MEM_RGBX12,     XVIDC_CSF_RGB,       12},
  {XVIDC_CSF_MEM_RGB16,      XVIDC_CSF_RGB,       16},
  {XVIDC_CSF_MEM_YUVX12,     XVIDC_CSF_YCRCB_444, 12},
  {XVIDC_CSF_MEM_YUV16,      XVIDC_CSF_YCRCB_444, 16},
  {XVIDC_CSF_MEM_Y_UV12,     XVIDC_CSF_YCRCB_422, 12},
  {XVIDC_CSF_MEM_Y_UV16,     XVIDC_CSF_YCRCB_422, 16},
  {XVIDC_CSF_MEM_Y_UV12_420, XVIDC_CSF_YCRCB_420, 12},
  {XVIDC_CSF_MEM_Y_UV16_420, XVIDC_CSF_YCRCB_420, 16},
  {XVIDC_CSF_MEM_Y12,        XVIDC_CSF_YONLY, 12},
  {XVIDC_CSF_MEM_Y16,        XVIDC_CSF_YONLY, 16}
};

/*
 * Initialize Frame Buffer Write
 * - Enable interrupts
 * - Assign the callback function
 * - Enable auto-restart mode
 * - Sets the stream parameters to align with the VProc SS output stream
 */
int FrmbufWrInit(Frmbuf *Frmbuf, u16 DeviceId, XScuGic *Intc, u16 VectorId, u64 BufrBaseAddr)
{
	XVidC_VideoStream FrmbufWrStream;
	int FrmbufWrStride;
	XVidC_VideoTiming const *TimingPtr;
	XVidC_ColorFormat Cfmt;
	int Status;
	// Hook up interrupt service routine
	Status = XScuGic_Connect(Intc,VectorId,
			(XInterruptHandler)XVFrmbufWr_InterruptHandler,
			(void *)&(Frmbuf->FrmbufWr));
	if (Status != XST_SUCCESS) {
		xil_printf("ERR:: Frame Buffer Read interrupt connect failed!\r\n");
		return XST_FAILURE;
	}
	// Enable the interrupt vector at the interrupt controller
	XScuGic_Enable(Intc, VectorId);

    // Init Frame buffers
	Status = XVFrmbufWr_Initialize(&(Frmbuf->FrmbufWr), DeviceId);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR:: Frame Buffer Write initialization failed\r\n");
		return(XST_FAILURE);
	}

	// Frame Buffer Write video stream properties
	FrmbufWrStream.PixPerClk  = Frmbuf->FrmbufWr.FrmbufWr.Config.PixPerClk;
	FrmbufWrStream.ColorDepth = Frmbuf->FrmbufWr.FrmbufWr.Config.MaxDataWidth;
	Cfmt = ColorFormats[COLOR_FORMAT_INDEX].MemFormat;
	FrmbufWrStream.ColorFormatId = ColorFormats[COLOR_FORMAT_INDEX].StreamFormat;
	FrmbufWrStream.VmId = XVidC_GetVideoModeId(VPROC_WIDTH_OUT,VPROC_HEIGHT_OUT,VPROC_FRAMERATE_OUT,FALSE);
    TimingPtr = XVidC_GetTimingInfo(FrmbufWrStream.VmId);
    FrmbufWrStream.Timing = *TimingPtr;
    FrmbufWrStream.FrameRate = XVidC_GetFrameRate(FrmbufWrStream.VmId);
    FrmbufWrStride = CalcStride(Cfmt,Frmbuf->FrmbufWr.FrmbufWr.Config.AXIMMDataWidth,&FrmbufWrStream);

	// Assign the Frame buffer callbacks
	XVFrmbufWr_SetCallback(&(Frmbuf->FrmbufWr), XVFRMBUFWR_HANDLER_DONE, FrmbufWrCallback,
			(void *)Frmbuf);

	// Configure Frame Buffers
	Frmbuf->FrmbufWrBufrAddr = BufrBaseAddr;
	Frmbuf->FrmbufBufrBaseAddr = BufrBaseAddr;
	Status = XVFrmbufWr_SetMemFormat(&(Frmbuf->FrmbufWr), FrmbufWrStride, Cfmt, &FrmbufWrStream);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to configure Frame Buffer Write\r\n");
		return(XST_FAILURE);
	}
	Status = XVFrmbufWr_SetBufferAddr(&(Frmbuf->FrmbufWr), Frmbuf->FrmbufWrBufrAddr);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to configure Frame Buffer Write buffer address\r\n");
		return(XST_FAILURE);
	}

	// Enable Interrupt
	XVFrmbufWr_InterruptEnable(&(Frmbuf->FrmbufWr), XVFRMBUFWR_IRQ_DONE_MASK);

	// Frame Buffers in Auto-restart mode
	XV_frmbufwr_EnableAutoRestart(&(Frmbuf->FrmbufWr.FrmbufWr));

	return(XST_SUCCESS);
}

/*
 * Initialize Frame Buffer Read
 * - Enable interrupts
 * - Assign the callback function
 * - Enable auto-restart mode
 * - Sets the stream parameters to align with the VProc SS output stream
 */
int FrmbufRdInit(Frmbuf *Frmbuf, u16 DeviceId, XScuGic *Intc, u16 VectorId, u64 BufrBaseAddr)
{
	XVidC_VideoStream FrmbufRdStream;
	int FrmbufRdStride;
	XVidC_VideoTiming const *TimingPtr;
	XVidC_ColorFormat Cfmt;
	int Status;
	// Hook up interrupt service routine
	Status = XScuGic_Connect(Intc,VectorId,
			(XInterruptHandler)XVFrmbufRd_InterruptHandler,
			(void *)&(Frmbuf->FrmbufRd));
	if (Status != XST_SUCCESS) {
		xil_printf("ERR:: Frame Buffer Read interrupt connect failed!\r\n");
		return XST_FAILURE;
	}
	// Enable the interrupt vector at the interrupt controller
	XScuGic_Enable(Intc, VectorId);

    // Init Frame buffers
	Status = XVFrmbufRd_Initialize(&(Frmbuf->FrmbufRd), DeviceId);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR:: Frame Buffer Read initialization failed\r\n");
		return(XST_FAILURE);
	}

	// Frame Buffer Read video stream properties
	FrmbufRdStream.PixPerClk  = Frmbuf->FrmbufRd.FrmbufRd.Config.PixPerClk;
	FrmbufRdStream.ColorDepth = Frmbuf->FrmbufRd.FrmbufRd.Config.MaxDataWidth;
	Cfmt = ColorFormats[COLOR_FORMAT_INDEX].MemFormat;
	FrmbufRdStream.ColorFormatId = ColorFormats[COLOR_FORMAT_INDEX].StreamFormat;
	FrmbufRdStream.VmId = XVidC_GetVideoModeId(VPROC_WIDTH_OUT,VPROC_HEIGHT_OUT,VPROC_FRAMERATE_OUT,FALSE);
    TimingPtr = XVidC_GetTimingInfo(FrmbufRdStream.VmId);
    FrmbufRdStream.Timing = *TimingPtr;
    FrmbufRdStream.FrameRate = XVidC_GetFrameRate(FrmbufRdStream.VmId);
    FrmbufRdStride = CalcStride(Cfmt,Frmbuf->FrmbufRd.FrmbufRd.Config.AXIMMDataWidth,&FrmbufRdStream);

	// Assign the Frame buffer callbacks
	XVFrmbufRd_SetCallback(&(Frmbuf->FrmbufRd), XVFRMBUFRD_HANDLER_DONE, FrmbufRdCallback,
			(void *)Frmbuf);

	// Configure Frame Buffers
	Frmbuf->FrmbufRdBufrAddr = BufrBaseAddr;
	Frmbuf->FrmbufBufrBaseAddr = BufrBaseAddr;
	Status = XVFrmbufRd_SetMemFormat(&(Frmbuf->FrmbufRd), FrmbufRdStride, Cfmt, &FrmbufRdStream);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to configure Frame Buffer Read 0x%X\r\n",Status);
		return(XST_FAILURE);
	}
	Status = XVFrmbufRd_SetBufferAddr(&(Frmbuf->FrmbufRd), Frmbuf->FrmbufRdBufrAddr);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to configure Frame Buffer Read buffer address\r\n");
		return(XST_FAILURE);
	}

	// Enable Interrupt
	XVFrmbufRd_InterruptEnable(&(Frmbuf->FrmbufRd), XVFRMBUFRD_IRQ_DONE_MASK);

	// Frame Buffers in Auto-restart mode
	XV_frmbufrd_EnableAutoRestart(&(Frmbuf->FrmbufRd.FrmbufRd));

	return(XST_SUCCESS);
}

/*
 * Start the Frame Buffers
 */
int FrmbufStart(Frmbuf *Frmbuf)
{
	XVFrmbufWr_Start(&(Frmbuf->FrmbufWr));
	XVFrmbufRd_Start(&(Frmbuf->FrmbufRd));
	return(XST_SUCCESS);
}


void *FrmbufRdCallback(void *data)
{
	Frmbuf *frmbuf = (Frmbuf *)data;
	XV_FrmbufRd_l2 *frmbufrd = &(frmbuf->FrmbufRd);
	// Nothing to do - Frame Buffer Read is configured for auto-restart
}

#define FRAME_SIZE 0x01000000

void *FrmbufWrCallback(void *data)
{
	Frmbuf *frmbuf = (Frmbuf *)data;
	XV_FrmbufWr_l2 *frmbufwr = &(frmbuf->FrmbufWr);
	XV_FrmbufRd_l2 *frmbufrd = &(frmbuf->FrmbufRd);
	u32 Status;

	// Rotate the Read and Write Frame Buffer addresses
	if(frmbuf->FrmbufWrBufrAddr >= (frmbuf->FrmbufBufrBaseAddr + (FRAME_SIZE * 3))){
		frmbuf->FrmbufRdBufrAddr = frmbuf->FrmbufBufrBaseAddr + (FRAME_SIZE * 2);
		frmbuf->FrmbufWrBufrAddr = frmbuf->FrmbufBufrBaseAddr + (FRAME_SIZE);
	}else{
		frmbuf->FrmbufRdBufrAddr = frmbuf->FrmbufWrBufrAddr;
		frmbuf->FrmbufWrBufrAddr = frmbuf->FrmbufWrBufrAddr + FRAME_SIZE;
	}

	// Set the buffer address to write the next frame
	Status = XVFrmbufWr_SetBufferAddr(frmbufwr, frmbuf->FrmbufWrBufrAddr);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to set Frame Buffer Write address\r\n");
	}

	// Set the buffer address to read the next frame
	Status = XVFrmbufRd_SetBufferAddr(frmbufrd, frmbuf->FrmbufRdBufrAddr);
	if(Status != XST_SUCCESS) {
		xil_printf("ERROR: Unable to set Frame Buffer Read address\r\n");
	}
}

/*****************************************************************************/
/**
 * This function calculates the stride
 *
 * @returns stride in bytes
 *
 *****************************************************************************/
static u32 CalcStride(XVidC_ColorFormat Cfmt,
						u16 AXIMMDataWidth,
						XVidC_VideoStream *StreamPtr)
{
  u32 stride;
  int width = StreamPtr->Timing.HActive;
  u16 MMWidthBytes = AXIMMDataWidth/8;
  u8 bpp_numerator;
  u8 bpp_denominator = 1;

  switch (Cfmt) {
    case XVIDC_CSF_MEM_Y_UV10:
    case XVIDC_CSF_MEM_Y_UV10_420:
    case XVIDC_CSF_MEM_Y10:
      /* 4 bytes per 3 pixels (Y_UV10, Y_UV10_420, Y10) */
      bpp_numerator = 4;
      bpp_denominator = 3;
      break;
    case XVIDC_CSF_MEM_Y_UV8:
    case XVIDC_CSF_MEM_Y_UV8_420:
    case  XVIDC_CSF_MEM_Y8:
      /* 1 byte per pixel (Y_UV8, Y_UV8_420, Y8) */
      bpp_numerator = 1;
      break;
    case XVIDC_CSF_MEM_RGB8:
    case  XVIDC_CSF_MEM_YUV8:
    case XVIDC_CSF_MEM_BGR8:
      /* 3 bytes per pixel (RGB8, YUV8, BGR8) */
      bpp_numerator = 3;
      break;
    case XVIDC_CSF_MEM_RGBX12:
    case  XVIDC_CSF_MEM_YUVX12:
      /* 5 bytes per pixel (RGBX12, YUVX12) */
      bpp_numerator = 5;
      break;
    case XVIDC_CSF_MEM_Y_UV12:
    case  XVIDC_CSF_MEM_Y_UV12_420:
    case XVIDC_CSF_MEM_Y12:
      /* 3 bytes per 2 pixels (Y_UV12, Y_UV12_420, Y12) */
      bpp_numerator = 3;
      bpp_denominator = 2;
      break;
    case XVIDC_CSF_MEM_RGB16:
    case XVIDC_CSF_MEM_YUV16:
      /* 6 bytes per pixel (RGB16, YUV16) */
      bpp_numerator = 6;
      break;
    case XVIDC_CSF_MEM_YUYV8:
    case XVIDC_CSF_MEM_UYVY8:
    case XVIDC_CSF_MEM_Y_UV16:
    case XVIDC_CSF_MEM_Y_UV16_420:
    case XVIDC_CSF_MEM_Y16:
      /* 2 bytes per pixel (YUYV8, UYVY8, Y_UV16, Y_UV16_420, Y16) */
      bpp_numerator = 2;
      break;
    default:
      /* 4 bytes per pixel */
      bpp_numerator = 4;
  }
  stride = ((((width * bpp_numerator) / bpp_denominator) +
    MMWidthBytes - 1) / MMWidthBytes) * MMWidthBytes;

  return(stride);
}

