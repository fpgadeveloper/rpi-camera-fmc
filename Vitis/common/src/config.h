/*
 * Opsero Electronic Design Inc. Copyright 2023
 *
 * This file should hold the major configuration parameters for the demo so that they can be set in
 * a single place.
 */

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

