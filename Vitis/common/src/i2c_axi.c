/* 
 * Opsero Electronic Design Inc. Copyright 2022
 * 
******************************************************************************/

#include "i2c_axi.h"

#include "xiic.h"

/************************** Variable Definitions *****************************/

u32 IicBaseAddr[2];
volatile u8 TransmitComplete[2];	/* Flag to check completion of Transmission */
volatile u8 ReceiveComplete[2];	/* Flag to check completion of Reception */

/************************** Function Definitions *****************************/

/*****************************************************************************/
/**
*
******************************************************************************/
int IicInit(XIic *IicInstance, u16 DeviceId, XScuGic *Intc, u16 VectorId)
{
	int Status;
	XIic_Config *ConfigPtr;	/* Pointer to configuration data */

	/*
	 * Initialize the IIC driver so that it is ready to use.
	 */
	ConfigPtr = XIic_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		xil_printf("IicInit: Failed IIC lookup config\n\r");
		return XST_FAILURE;
	}

	Status = XIic_CfgInitialize(IicInstance, ConfigPtr,
			ConfigPtr->BaseAddress);
	if (Status != XST_SUCCESS) {
		xil_printf("IicInit: Failed IIC config initialize\n\r");
		return XST_FAILURE;
	}

	// Copy the base address for use by the interrupt handlers
	IicBaseAddr[DeviceId] = IicInstance->BaseAddress;

	// Setup the Interrupt System.
	Status = SetupInterruptSystem(IicInstance,Intc,VectorId);
	if (Status != XST_SUCCESS) {
		xil_printf("IicInit: Failed interrupt setup\n\r");
		return XST_FAILURE;
	}

	// Set the Handlers for transmit and reception.
	XIic_SetSendHandler(IicInstance, IicInstance,(XIic_Handler) IicSendHandler);
	XIic_SetRecvHandler(IicInstance, IicInstance,(XIic_Handler) IicRecvHandler);
	XIic_SetStatusHandler(IicInstance, IicInstance,(XIic_StatusHandler) IicStatusHandler);

	return(XST_SUCCESS);
}

/*****************************************************************************/
/**
* This function writes a buffer of data to IIC.
*
* @param	ByteCount contains the number of bytes in the buffer to be
*		written.
*
* @return	XST_SUCCESS if successful else XST_FAILURE.
*
* @note		The Byte count should not exceed the page size of the EEPROM as
*		noted by the constant PAGE_SIZE.
*
******************************************************************************/
int IicWrite(XIic *IicInstance,u8 addr,u8 *buf, u16 ByteCount)
{
	int Status;

	// Set the Slave address.
	Status = XIic_SetAddress(IicInstance, XII_ADDR_TO_SEND_TYPE,addr);
	if (Status != XST_SUCCESS) {
		xil_printf("IicWrite: Failed to set address\n\r");
		return XST_FAILURE;
	}

	// Set the defaults.
	IicStartSendHandler(IicInstance);
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
	Status = XIic_MasterSend(IicInstance, buf, ByteCount);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Wait till the transmission is completed.
	 */
	for(int i = 0; i<1000; i++){
		if ((IicSendComplete(IicInstance) != 0) && (XIic_IsIicBusy(IicInstance) == FALSE))
			break;
		usleep(100);
	}

	/*
	 * Stop the IIC device.
	 */
	Status = XIic_Stop(IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

/*****************************************************************************/
/**
* This function reads data from the IIC serial EEPROM into a specified buffer.
*
* @param	BufferPtr contains the address of the data buffer to be filled.
* @param	ByteCount contains the number of bytes in the buffer to be read.
*
* @return	XST_SUCCESS if successful else XST_FAILURE.
*
* @note		None.
*
******************************************************************************/
int IicRead(XIic *IicInstance,u8 addr, u8 *BufferPtr, u16 ByteCount)
{
	int Status;
	volatile int timeout;

	// Set the Slave address.
	Status = XIic_SetAddress(IicInstance, XII_ADDR_TO_SEND_TYPE,addr);
	if (Status != XST_SUCCESS) {
		xil_printf("IicWrite: Failed to set address\n\r");
		return XST_FAILURE;
	}

	// Set the Defaults.
	IicStartRecvHandler(IicInstance);

	// Start the IIC device.
	Status = XIic_Start(IicInstance);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	// Receive the Data.
	Status = XIic_MasterRecv(IicInstance, BufferPtr, ByteCount+1);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	// Wait till all the data is received.
	timeout = 100000;
	while ((timeout) && ((IicRecvComplete(IicInstance) == 0) || (XIic_IsIicBusy(IicInstance) == TRUE))) {
		timeout--;
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

/*****************************************************************************/
/**
* This function setups the interrupt system so interrupts can occur for the
* IIC devices. The function is application-specific since the actual system may
* or may not have an interrupt controller. The IIC device could be directly
* connected to a processor without an interrupt controller. The user should
* modify this function to fit the application.
*
* @param	IicInstPtr contains a pointer to the instance of the IIC device
*		which is going to be connected to the interrupt controller.
*
* @return	XST_SUCCESS if successful else XST_FAILURE.
*
* @note		None.
*
******************************************************************************/
int SetupInterruptSystem(XIic *IicInstPtr, XScuGic *Intc, u16 VectorId)
{
	int Status;

	XScuGic_SetPriorityTriggerType(Intc, VectorId,	0xA0, 0x3);

	/*
	 * Connect the interrupt handler that will be called when an
	 * interrupt occurs for the device.
	 */
	Status = XScuGic_Connect(Intc, VectorId,
				 (Xil_InterruptHandler)XIic_InterruptHandler,
				 IicInstPtr);
	if (Status != XST_SUCCESS) {
		return Status;
	}

	/*
	 * Enable the interrupt for the IIC device.
	 */
	XScuGic_Enable(Intc, VectorId);


	/*
	 * Initialize the exception table and register the interrupt
	 * controller handler with the exception table
	 */
	/*
	Xil_ExceptionInit();

	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
			 (Xil_ExceptionHandler)INTC_HANDLER, Intc);

	Xil_ExceptionEnable();
	*/

	return XST_SUCCESS;
}

/*****************************************************************************/
/**
* This Send handler is called asynchronously from an interrupt
* context and indicates that data in the specified buffer has been sent.
*
* @param	InstancePtr is not used, but contains a pointer to the IIC
*		device driver instance which the handler is being called for.
*
* @return	None.
*
* @note		None.
*
******************************************************************************/
void IicSendHandler(XIic *InstancePtr)
{
	int i;
	// Reset the TransmitComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			TransmitComplete[i] = 0;
			break;
		}
	}
}

void IicStartSendHandler(XIic *InstancePtr)
{
	int i;
	// Reset the ReceiveComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			TransmitComplete[i] = 1;
			break;
		}
	}
}

int IicSendComplete(XIic *InstancePtr)
{
	int i;
	// Return the ReceiveComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			return(TransmitComplete[i] == 0);
		}
	}
	return(0);
}

/*****************************************************************************/
/**
* This Receive handler is called asynchronously from an interrupt
* context and indicates that data in the specified buffer has been Received.
*
* @param	InstancePtr is not used, but contains a pointer to the IIC
*		device driver instance which the handler is being called for.
*
* @return	None.
*
* @note		None.
*
******************************************************************************/
void IicRecvHandler(XIic *InstancePtr)
{
	int i;
	// Reset the ReceiveComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			ReceiveComplete[i] = 0;
			break;
		}
	}
}

void IicStartRecvHandler(XIic *InstancePtr)
{
	int i;
	// Reset the ReceiveComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			ReceiveComplete[i] = 1;
			break;
		}
	}
}

int IicRecvComplete(XIic *InstancePtr)
{
	int i;
	// Return the ReceiveComplete flag for this IIC instance
	for(i=0; i<2; i++){
		if(InstancePtr->BaseAddress == IicBaseAddr[i]){
			return(ReceiveComplete[i] == 0);
		}
	}
	return(0);
}

/*****************************************************************************/
/**
* This Status handler is called asynchronously from an interrupt
* context and indicates the events that have occurred.
*
* @param	InstancePtr is a pointer to the IIC driver instance for which
*		the handler is being called for.
* @param	Event indicates the condition that has occurred.
*
* @return	None.
*
* @note		None.
*
******************************************************************************/
void IicStatusHandler(XIic *InstancePtr, int Event)
{

}

