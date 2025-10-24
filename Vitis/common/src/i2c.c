/* 
 * Opsero Electronic Design Inc. Copyright 2025
 * 
******************************************************************************/

#include "i2c.h"
#include "xparameters.h"
#include "xinterrupt_wrap.h"
#include <xstatus.h>

#ifdef XPAR_XIIC_NUM_INSTANCES
#include "xiic.h"
#endif
#ifdef XPAR_XIICPS_NUM_INSTANCES
#include "xiicps.h"
#endif
#include "sleep.h"

#define IIC_MAX_INSTANCES 10

// Timeout parameters
#ifndef IIC_AXI_TX_TIMEOUT_US
#define IIC_AXI_TX_TIMEOUT_US   (50000u)   // base timeout ~50 ms
#endif
#ifndef IIC_AXI_TX_TIMEOUT_PER_BYTE_US
#define IIC_AXI_TX_TIMEOUT_PER_BYTE_US (300u)   // add ~0.3 ms per byte
#endif
#ifndef IIC_AXI_POLL_STEP_US
#define IIC_AXI_POLL_STEP_US    (10u)      // poll granularity
#endif

/************************** Variable Definitions *****************************/

u8 IicNumInstances = 0;
IicIntHandlerInfo IicIntHandlerInfoArray[IIC_MAX_INSTANCES];

/************************** Function Definitions *****************************/

#ifndef XPAR_XIIC_NUM_INSTANCES
/*
 * IIC Write function
 */
int IicWrite(u8 index,u8 addr,u8 *buf, u16 len)
{
	return IicPsWrite(index,addr,buf,len);
}

/*
 * IIC Read function
 */
int IicRead(u8 index,u8 addr, u8 *buf, u16 len)
{
	return IicPsRead(index,addr,buf,len);
}

/*
 * IIC Reset function
 */
int IicReset(u8 index)
{
	XIicPs_Reset((XIicPs *)IicIntHandlerInfoArray[index].Iic);
    return XST_SUCCESS;
}

#endif

#ifndef XPAR_XIICPS_NUM_INSTANCES
/*
 * IIC Write function
 */
int IicWrite(u8 index,u8 addr,u8 *buf, u16 len)
{
	return IicAxiWrite(index,addr,buf,len);
}

/*
 * IIC Read function
 */
int IicRead(u8 index,u8 addr, u8 *buf, u16 len)
{
	return IicAxiRead(index,addr,buf,len);
}

/*
 * IIC Reset function
 */
int IicReset(u8 index)
{
	XIic_Reset((XIic *)IicIntHandlerInfoArray[index].Iic);
    return XST_SUCCESS;
}

#endif

#if defined(XPAR_XIIC_NUM_INSTANCES) && defined(XPAR_XIICPS_NUM_INSTANCES)
/*
 * IIC Write function
 * Determines the IIC type (AXI or PS) and calls the appropriate function
 */
int IicWrite(u8 index,u8 addr,u8 *buf, u16 len)
{
	if(IicIntHandlerInfoArray[index].IicType == IIC_TYPE_AXI_IIC)
		return IicAxiWrite(index,addr,buf,len);
	else
		return IicPsWrite(index,addr,buf,len);
}

/*
 * IIC Read function
 * Determines the IIC type (AXI or PS) and calls the appropriate function
 */
int IicRead(u8 index,u8 addr, u8 *buf, u16 len)
{
	if(IicIntHandlerInfoArray[index].IicType == IIC_TYPE_AXI_IIC)
		return IicAxiRead(index,addr,buf,len);
	else
		return IicPsRead(index,addr,buf,len);
}

/*
 * IIC Reset function
 */
int IicReset(u8 index)
{
	if(IicIntHandlerInfoArray[index].IicType == IIC_TYPE_AXI_IIC)
		XIic_Reset((XIic *)IicIntHandlerInfoArray[index].Iic);
	else
		XIicPs_Reset((XIicPs *)IicIntHandlerInfoArray[index].Iic);
    return XST_SUCCESS;
}

#endif

#ifdef XPAR_XIIC_NUM_INSTANCES
/*
 * Initialize IIC for AXI IIC
 */
int IicAxiInit(XIic *IicInstance, UINTPTR BaseAddr, u8 *Index)
{
	int Status;
	XIic_Config *ConfigPtr;

    if (IicNumInstances >= IIC_MAX_INSTANCES) {
        xil_printf("IicAxiInit: too many instances (max %d)\r\n", IIC_MAX_INSTANCES);
        return XST_FAILURE;
    }

	// Initialize IIC
	ConfigPtr = XIic_LookupConfig(BaseAddr);
	if (ConfigPtr == NULL) {
		xil_printf("IicAxiInit: Failed IIC lookup config\n\r");
		return XST_FAILURE;
	}

	Status = XIic_CfgInitialize(IicInstance, ConfigPtr,
			ConfigPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		xil_printf("IicAxiInit: Failed IIC config initialize\n\r");
		return XST_FAILURE;
	}

	// Initialize the IIC interrupt handler info
	IicIntHandlerInfoArray[IicNumInstances].Iic = IicInstance;
	IicIntHandlerInfoArray[IicNumInstances].IicType = IIC_TYPE_AXI_IIC;
	IicIntHandlerInfoArray[IicNumInstances].ReceiveComplete = 0;
	IicIntHandlerInfoArray[IicNumInstances].TransmitComplete = 0;
	IicIntHandlerInfoArray[IicNumInstances].ErrorCount = 0;

	// Setup interrupt system
    Status = XSetupInterruptSystem(IicInstance, &XIic_InterruptHandler,
				       ConfigPtr->IntrId, ConfigPtr->IntrParent,
				       XINTERRUPT_DEFAULT_PRIORITY);
	if (Status != XST_SUCCESS) {
        xil_printf("IicAxiInit: Failed to setup interrupts\r\n");
		return XST_FAILURE;
	}

	// Set the Handlers for transmit and reception.
	XIic_SetSendHandler(IicInstance,
			&IicIntHandlerInfoArray[IicNumInstances],(XIic_Handler) IicAxiSendHandler);
	XIic_SetRecvHandler(IicInstance,
			&IicIntHandlerInfoArray[IicNumInstances],(XIic_Handler) IicAxiRecvHandler);
	XIic_SetStatusHandler(IicInstance,
			&IicIntHandlerInfoArray[IicNumInstances],(XIic_StatusHandler) IicAxiStatusHandler);

	// Increment the number of IIC instances attached to the driver
	*Index = IicNumInstances;
	IicNumInstances++;

	return(XST_SUCCESS);
}

/*
 * AXI IIC Write function
 */
int IicAxiWrite(u8 index,u8 addr,u8 *buf, u16 len)
{
	int Status;
	IicIntHandlerInfo *Info = &IicIntHandlerInfoArray[index];
	XIic *IicInstance = (XIic *)Info->Iic;

	// Set the Slave address.
	Status = XIic_SetAddress(IicInstance, XII_ADDR_TO_SEND_TYPE,addr);
	if (Status != XST_SUCCESS) {
		xil_printf("IicAxiWrite: Failed to set address\n\r");
		return XST_FAILURE;
	}

	// Set the defaults.
	Info->TransmitComplete = 1;
	IicInstance->Stats.TxErrors = 0;

	/*
	 * Start the IIC device.
	 */
	Status = XIic_Start(IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Send the Data.
	 */
	Status = XIic_MasterSend(IicInstance, buf, len);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // Wait with timeout
    const u32 timeout_us = IIC_AXI_TX_TIMEOUT_US +
                           (u32)len * IIC_AXI_TX_TIMEOUT_PER_BYTE_US;
    u32 elapsed = 0;

    while (elapsed < timeout_us) {
        // done when ISR fired (TransmitComplete==0) AND bus is idle
        if ((Info->TransmitComplete == 0) && (XIic_IsIicBusy(IicInstance) == FALSE))
            break;

        // abort on hw-reported error
        if (IicInstance->Stats.TxErrors) {
            IicInstance->Stats.TxErrors = 0;
            (void)XIic_Stop(IicInstance);
            (void)XIic_Reset(IicInstance);
            return XST_FAILURE;
        }

        usleep(IIC_AXI_POLL_STEP_US);
        elapsed += IIC_AXI_POLL_STEP_US;
    }

    // Timeout?
    if (!((Info->TransmitComplete == 0) && (XIic_IsIicBusy(IicInstance) == FALSE))) {
        (void)XIic_Stop(IicInstance);
        (void)XIic_Reset(IicInstance);   // recover the core
        return XST_FAILURE;
    }

	/*
	 * Stop the IIC device.
	 */
	Status = XIic_Stop(IicInstance);
	if (Status != XST_SUCCESS) {
        xil_printf("IicAxiWrite: XIic_Stop failed\r\n");
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*
 * AXI IIC Read function
 */
int IicAxiRead(u8 index,u8 addr, u8 *buf, u16 len)
{
	int Status;
	volatile int timeout;
	IicIntHandlerInfo *Info = &IicIntHandlerInfoArray[index];
	XIic *IicInstance = (XIic *)Info->Iic;

	// Set the Slave address.
	Status = XIic_SetAddress(IicInstance, XII_ADDR_TO_SEND_TYPE,addr);
	if (Status != XST_SUCCESS) {
		xil_printf("IicWrite: Failed to set address\n\r");
		return XST_FAILURE;
	}

	// Set the Defaults.
	Info->ReceiveComplete = 1;

	// Start the IIC device.
	Status = XIic_Start(IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	// Receive the Data.
	Status = XIic_MasterRecv(IicInstance, buf, len);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	// Wait till all the data is received.
	timeout = 1000;
	while ((timeout) && (((Info->ReceiveComplete == 0) == 0) || (XIic_IsIicBusy(IicInstance) == TRUE))) {
		timeout--;
        usleep(10);
	}

	// If it timed out
	if(timeout == 0){
		return XST_FAILURE;
	}

	// Stop the IIC device.
	Status = XIic_Stop(IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*
 * AXI IIC Send interrupt handler - called when I2C transmission is complete
 */
void IicAxiSendHandler(IicIntHandlerInfo *Info)
{
	Info->TransmitComplete = 0;
}

/*
 * IIC Receive interrupt handler - called when I2C reception is complete
 */
void IicAxiRecvHandler(IicIntHandlerInfo *Info)
{
	Info->ReceiveComplete = 0;
}

/*
 * IIC Status interrupt handler - not being used
 */
void IicAxiStatusHandler(IicIntHandlerInfo *Info, int Event)
{

}

#endif

#ifdef XPAR_XIICPS_NUM_INSTANCES
/*
 * Initialize IIC for PS IIC
 */
int IicPsInit(XIicPs *IicInstance, UINTPTR BaseAddr, u8 *Index)
{
	XIicPs_Config *ConfigPtr;	/* Pointer to configuration data */
	int Status;

    if (IicNumInstances >= IIC_MAX_INSTANCES) {
        xil_printf("IicPsInit: too many instances (max %d)\r\n", IIC_MAX_INSTANCES);
        return XST_FAILURE;
    }

	// Initialize the IIC driver
	ConfigPtr = XIicPs_LookupConfig(BaseAddr);
	if (ConfigPtr == NULL) {
		return XST_FAILURE;
	}

	Status = XIicPs_CfgInitialize(IicInstance, ConfigPtr,
					ConfigPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	XIicPs_SetStatusHandler(IicInstance,
			(void *)&IicIntHandlerInfoArray[IicNumInstances],
			(XIicPs_IntrHandler)IicPsInterruptHandler);

	// Set the IIC serial clock rate.
	XIicPs_SetSClk(IicInstance, IIC_SCLK_RATE);

	// Initialize the IIC interrupt handler info
	IicIntHandlerInfoArray[IicNumInstances].Iic = IicInstance;
	IicIntHandlerInfoArray[IicNumInstances].IicType = IIC_TYPE_PS_IIC;
	IicIntHandlerInfoArray[IicNumInstances].ReceiveComplete = 0;
	IicIntHandlerInfoArray[IicNumInstances].TransmitComplete = 0;
	IicIntHandlerInfoArray[IicNumInstances].ErrorCount = 0;

	Status = XSetupInterruptSystem(IicInstance, XIicPs_MasterInterruptHandler,
			ConfigPtr->IntrId,
			ConfigPtr->IntrParent,
			XINTERRUPT_DEFAULT_PRIORITY);
	if (Status != XST_SUCCESS) {
        xil_printf("IicPsInit: Failed to setup interrupts\r\n");
		return XST_FAILURE;
	}

	// Increment the number of IIC instances attached to the driver
	*Index = IicNumInstances;
	IicNumInstances++;

	return(XST_SUCCESS);
}

/*
 * IIC PS Interrupt handler
 */
void IicPsInterruptHandler(IicIntHandlerInfo *Info, u32 Event)
{
	// All of the data transfer has been finished.
	if (0 != (Event & XIICPS_EVENT_COMPLETE_RECV)){
		Info->ReceiveComplete = TRUE;
	} else if (0 != (Event & XIICPS_EVENT_COMPLETE_SEND)) {
		Info->TransmitComplete = TRUE;
	} else if (0 == (Event & XIICPS_EVENT_SLAVE_RDY)){
		/*
		 * If it is other interrupt but not slave ready interrupt, it is
		 * an error.
		 * Data was received with an error.
		 */
		Info->ErrorCount++;
	}
}

/*
 * PS IIC write function
 */
int IicPsWrite(u8 index, u8 addr, u8 *buf,u16 len)
{
	IicIntHandlerInfo *Info = &IicIntHandlerInfoArray[index];
	XIicPs *IicInstance = (XIicPs *)Info->Iic;
	Info->TransmitComplete = FALSE;

	XIicPs_MasterSend(IicInstance, buf,len, addr);
	while (Info->TransmitComplete == FALSE) {
		if (0 != Info->ErrorCount) {
			Info->ErrorCount = 0;
			while (XIicPs_BusIsBusy(IicInstance));
			return XST_FAILURE;
		}
	}

	 // Wait until bus is idle to start another transfer.
	while (XIicPs_BusIsBusy(IicInstance));
	Info->ReceiveComplete = FALSE;

	return XST_SUCCESS;
}

/*
 * PS IIC read function
 */
int IicPsRead(u8 index, u8 addr, u8 *buf,u16 len)
{
	IicIntHandlerInfo *Info = &IicIntHandlerInfoArray[index];
	XIicPs *IicInstance = (XIicPs *)Info->Iic;
	Info->ReceiveComplete = FALSE;

	// Receive the data
	XIicPs_MasterRecv(IicInstance, buf,len, addr);
	while (Info->ReceiveComplete == FALSE) {
		if (0 != Info->ErrorCount) {
			Info->ErrorCount = 0;
			while (XIicPs_BusIsBusy(IicInstance));
			return XST_FAILURE;
		}
	}
	// Wait until bus is idle to start another transfer.
	while (XIicPs_BusIsBusy(IicInstance));
	return XST_SUCCESS;
}

#endif

