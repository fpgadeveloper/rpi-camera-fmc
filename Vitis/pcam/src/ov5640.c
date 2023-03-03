
#include "xstatus.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "i2c_axi.h"
#include "sleep.h"
#include "ov5640.h"

XIIC_TYPE *ov5640_iic;
XGpio *ov5640_gpio;
uint8_t ov5640_gpio_mask;

config_word_t const cfg_advanced_awb_[] =
{
	// Enable Advanced AWB
	{0x3406 ,0x00},
	{0x5192 ,0x04},
	{0x5191 ,0xf8},
	{0x518d ,0x26},
	{0x518f ,0x42},
	{0x518e ,0x2b},
	{0x5190 ,0x42},
	{0x518b ,0xd0},
	{0x518c ,0xbd},
	{0x5187 ,0x18},
	{0x5188 ,0x18},
	{0x5189 ,0x56},
	{0x518a ,0x5c},
	{0x5186 ,0x1c},
	{0x5181 ,0x50},
	{0x5184 ,0x20},
	{0x5182 ,0x11},
	{0x5183 ,0x00},
	{0x5001 ,0x03}
};

config_word_t const cfg_simple_awb_[] =
{
	// Disable Advanced AWB
	{0x518d ,0x00},
	{0x518f ,0x20},
	{0x518e ,0x00},
	{0x5190 ,0x20},
	{0x518b ,0x00},
	{0x518c ,0x00},
	{0x5187 ,0x10},
	{0x5188 ,0x10},
	{0x5189 ,0x40},
	{0x518a ,0x40},
	{0x5186 ,0x10},
	{0x5181 ,0x58},
	{0x5184 ,0x25},
	{0x5182 ,0x11},

	// Enable simple AWB
	{0x3406 ,0x00},
	{0x5183 ,0x80},
	{0x5191 ,0xff},
	{0x5192 ,0x00},
	{0x5001 ,0x03}
};

config_word_t const cfg_disable_awb_[] =
{
	{0x5001 ,0x02}
};

config_word_t const cfg_720p_60fps_[] =
{//1280 x 720 binned, RAW10, MIPISCLK=280M, SCLK=56Mz, PCLK=56M
	//PLL1 configuration
	//[7:4]=0010 System clock divider /2, [3:0]=0001 Scale divider for MIPI /1
	{0x3035, 0x21},
	//[7:0]=70 PLL multiplier
	{0x3036, 0x46},
	//[4]=0 PLL root divider /1, [3:0]=5 PLL pre-divider /1.5
	{0x3037, 0x05},
	//[5:4]=01 PCLK root divider /2, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
	{0x3108, 0x11},

	//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
	{0x3034, 0x1A},

	//[3:0]=0 X address start high byte
	{0x3800, (0 >> 8) & 0x0F},
	//[7:0]=0 X address start low byte
	{0x3801, 0 & 0xFF},
	//[2:0]=0 Y address start high byte
	{0x3802, (8 >> 8) & 0x07},
	//[7:0]=0 Y address start low byte
	{0x3803, 8 & 0xFF},

	//[3:0] X address end high byte
	{0x3804, (2619 >> 8) & 0x0F},
	//[7:0] X address end low byte
	{0x3805, 2619 & 0xFF},
	//[2:0] Y address end high byte
	{0x3806, (1947 >> 8) & 0x07},
	//[7:0] Y address end low byte
	{0x3807, 1947 & 0xFF},

	//[3:0]=0 timing hoffset high byte
	{0x3810, (0 >> 8) & 0x0F},
	//[7:0]=0 timing hoffset low byte
	{0x3811, 0 & 0xFF},
	//[2:0]=0 timing voffset high byte
	{0x3812, (0 >> 8) & 0x07},
	//[7:0]=0 timing voffset low byte
	{0x3813, 0 & 0xFF},

	//[3:0] Output horizontal width high byte
	{0x3808, (1280 >> 8) & 0x0F},
	//[7:0] Output horizontal width low byte
	{0x3809, 1280 & 0xFF},
	//[2:0] Output vertical height high byte
	{0x380a, (720 >> 8) & 0x7F},
	//[7:0] Output vertical height low byte
	{0x380b, 720 & 0xFF},

	//HTS line exposure time in # of pixels
	{0x380c, (1896 >> 8) & 0x1F},
	{0x380d, 1896 & 0xFF},
	//VTS frame exposure time in # lines
	{0x380e, (984 >> 8) & 0xFF},
	{0x380f, 984 & 0xFF},

	//[7:4]=0x3 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
	{0x3814, 0x31},
	//[7:4]=0x3 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
	{0x3815, 0x31},

	//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=1 horizontal binning
	{0x3821, 0x01},

	//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
	{0x4837, 36}, // 1/56M*2

	//Undocumented anti-green settings
	{0x3618, 0x00}, // Removes vertical lines appearing under bright light
	{0x3612, 0x59},
	{0x3708, 0x64},
	{0x3709, 0x52},
	{0x370c, 0x03},

	//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
	{0x4300, 0x00},
	//[2:0]=0x3 Format select ISP RAW (DPC)
	{0x501f, 0x03}
};
config_word_t const cfg_1080p_15fps_[] =
{//1920 x 1080 @ 15 fps, RAW10, MIPISCLK=210, SCLK=42MHz, PCLK=42M
	// PLL1 configuration
	// [7:4]=0100 System clock divider /4, [3:0]=0001 Scale divider for MIPI /1
	{0x3035, 0x41},
	// [7:0]=105 PLL multiplier
	{0x3036, 0x69},
	// [4]=0 PLL root divider /1, [3:0]=5 PLL pre-divider /1.5
	{0x3037, 0x05},
	// [5:4]=01 PCLK root divider /2, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
	{0x3108, 0x11},

	// [6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
	{0x3034, 0x1A},

	// [3:0]=0 X address start high byte
	{0x3800, (336 >> 8) & 0x0F},
	// [7:0]=0 X address start low byte
	{0x3801, 336 & 0xFF},
	// [2:0]=0 Y address start high byte
	{0x3802, (426 >> 8) & 0x07},
	// [7:0]=0 Y address start low byte
	{0x3803, 426 & 0xFF},

	// [3:0] X address end high byte
	{0x3804, (2287 >> 8) & 0x0F},
	// [7:0] X address end low byte
	{0x3805, 2287 & 0xFF},
	// [2:0] Y address end high byte
	{0x3806, (1529 >> 8) & 0x07},
	// [7:0] Y address end low byte
	{0x3807, 1529 & 0xFF},

	// [3:0]=0 timing hoffset high byte
	{0x3810, (16 >> 8) & 0x0F},
	// [7:0]=0 timing hoffset low byte
	{0x3811, 16 & 0xFF},
	// [2:0]=0 timing voffset high byte
	{0x3812, (12 >> 8) & 0x07},
	// [7:0]=0 timing voffset low byte
	{0x3813, 12 & 0xFF},

	// [3:0] Output horizontal width high byte
	{0x3808, (1920 >> 8) & 0x0F},
	// [7:0] Output horizontal width low byte
	{0x3809, 1920 & 0xFF},
	// [2:0] Output vertical height high byte
	{0x380a, (1080 >> 8) & 0x7F},
	// [7:0] Output vertical height low byte
	{0x380b, 1080 & 0xFF},

	// HTS line exposure time in # of pixels Tline=HTS/sclk
	{0x380c, (2500 >> 8) & 0x1F},
	{0x380d, 2500 & 0xFF},
	// VTS frame exposure time in # lines
	{0x380e, (1120 >> 8) & 0xFF},
	{0x380f, 1120 & 0xFF},

	// [7:4]=0x1 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
	{0x3814, 0x11},
	// [7:4]=0x1 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
	{0x3815, 0x11},

	// [2]=0 ISP mirror, [1]=0 sensor mirror, [0]=0 no horizontal binning
	{0x3821, 0x00},

	// little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
	{0x4837, 48}, // 1/42M*2

	// Undocumented anti-green settings
	{0x3618, 0x00}, // Removes vertical lines appearing under bright light
	{0x3612, 0x59},
	{0x3708, 0x64},
	{0x3709, 0x52},
	{0x370c, 0x03},

	// [7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
	{0x4300, 0x00},
	// [2:0]=0x3 Format select ISP RAW (DPC)
	{0x501f, 0x03}
};
config_word_t const cfg_1080p_30fps_[] =
{//1920 x 1080 @ 30fps, RAW10, MIPISCLK=420, SCLK=84MHz, PCLK=84M
	//PLL1 configuration
	//[7:4]=0010 System clock divider /2, [3:0]=0001 Scale divider for MIPI /1
	{0x3035, 0x21}, // 30fps setting
	//[7:0]=105 PLL multiplier
	{0x3036, 0x69},
	//[4]=0 PLL root divider /1, [3:0]=5 PLL pre-divider /1.5
	{0x3037, 0x05},
	//[5:4]=01 PCLK root divider /2, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
	{0x3108, 0x11},

	//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
	{0x3034, 0x1A},

	//[3:0]=0 X address start high byte
	{0x3800, (336 >> 8) & 0x0F},
	//[7:0]=0 X address start low byte
	{0x3801, 336 & 0xFF},
	//[2:0]=0 Y address start high byte
	{0x3802, (426 >> 8) & 0x07},
	//[7:0]=0 Y address start low byte
	{0x3803, 426 & 0xFF},

	//[3:0] X address end high byte
	{0x3804, (2287 >> 8) & 0x0F},
	//[7:0] X address end low byte
	{0x3805, 2287 & 0xFF},
	//[2:0] Y address end high byte
	{0x3806, (1529 >> 8) & 0x07},
	//[7:0] Y address end low byte
	{0x3807, 1529 & 0xFF},

	//[3:0]=0 timing hoffset high byte
	{0x3810, (16 >> 8) & 0x0F},
	//[7:0]=0 timing hoffset low byte
	{0x3811, 16 & 0xFF},
	//[2:0]=0 timing voffset high byte
	{0x3812, (12 >> 8) & 0x07},
	//[7:0]=0 timing voffset low byte
	{0x3813, 12 & 0xFF},

	//[3:0] Output horizontal width high byte
	{0x3808, (1920 >> 8) & 0x0F},
	//[7:0] Output horizontal width low byte
	{0x3809, 1920 & 0xFF},
	//[2:0] Output vertical height high byte
	{0x380a, (1080 >> 8) & 0x7F},
	//[7:0] Output vertical height low byte
	{0x380b, 1080 & 0xFF},

	//HTS line exposure time in # of pixels Tline=HTS/sclk
	{0x380c, (2500 >> 8) & 0x1F},
	{0x380d, 2500 & 0xFF},
	//VTS frame exposure time in # lines
	{0x380e, (1120 >> 8) & 0xFF},
	{0x380f, 1120 & 0xFF},

	//[7:4]=0x1 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
	{0x3814, 0x11},
	//[7:4]=0x1 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
	{0x3815, 0x11},

	//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=0 no horizontal binning
	{0x3821, 0x00},

	//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
	{0x4837, 24}, // 1/84M*2

	//Undocumented anti-green settings
	{0x3618, 0x00}, // Removes vertical lines appearing under bright light
	{0x3612, 0x59},
	{0x3708, 0x64},
	{0x3709, 0x52},
	{0x370c, 0x03},

	//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
	{0x4300, 0x00},
	//[2:0]=0x3 Format select ISP RAW (DPC)
	{0x501f, 0x03}
};
config_word_t const cfg_1080p_30fps_336M_mipi_[] =
	{//1920 x 1080 @ 30fps, RAW10, MIPISCLK=672, SCLK=67.2MHz, PCLK=134.4M
		//PLL1 configuration
		//[7:4]=0001 System clock divider /1, [3:0]=0001 Scale divider for MIPI /1
		{0x3035, 0x11}, // 30fps setting
		//[7:0]=84 PLL multiplier
		{0x3036, 0x54},
		//[4]=1 PLL root divider /2, [3:0]=5 PLL pre-divider /1.5
		{0x3037, 0x15},
	//[5:4]=00 PCLK root divider /1, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
		{0x3108, 0x01},

		//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
		{0x3034, 0x1A},

		//[3:0]=0 X address start high byte
		{0x3800, (336 >> 8) & 0x0F},
		//[7:0]=0 X address start low byte
		{0x3801, 336 & 0xFF},
		//[2:0]=0 Y address start high byte
		{0x3802, (426 >> 8) & 0x07},
		//[7:0]=0 Y address start low byte
		{0x3803, 426 & 0xFF},

		//[3:0] X address end high byte
		{0x3804, (2287 >> 8) & 0x0F},
		//[7:0] X address end low byte
		{0x3805, 2287 & 0xFF},
		//[2:0] Y address end high byte
		{0x3806, (1529 >> 8) & 0x07},
		//[7:0] Y address end low byte
		{0x3807, 1529 & 0xFF},

		//[3:0]=0 timing hoffset high byte
		{0x3810, (16 >> 8) & 0x0F},
		//[7:0]=0 timing hoffset low byte
		{0x3811, 16 & 0xFF},
		//[2:0]=0 timing voffset high byte
		{0x3812, (12 >> 8) & 0x07},
		//[7:0]=0 timing voffset low byte
		{0x3813, 12 & 0xFF},

		//[3:0] Output horizontal width high byte
		{0x3808, (1920 >> 8) & 0x0F},
		//[7:0] Output horizontal width low byte
		{0x3809, 1920 & 0xFF},
		//[2:0] Output vertical height high byte
		{0x380a, (1080 >> 8) & 0x7F},
		//[7:0] Output vertical height low byte
		{0x380b, 1080 & 0xFF},

		//HTS line exposure time in # of pixels Tline=HTS/sclk
		{0x380c, (2500 >> 8) & 0x1F},
		{0x380d, 2500 & 0xFF},
		//VTS frame exposure time in # lines
		{0x380e, (1120 >> 8) & 0xFF},
		{0x380f, 1120 & 0xFF},

		//[7:4]=0x1 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
		{0x3814, 0x11},
		//[7:4]=0x1 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
		{0x3815, 0x11},

		//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=0 no horizontal binning
		{0x3821, 0x00},

		//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
		{0x4837, 14}, // 1/84M*2

		//Undocumented anti-green settings
		{0x3618, 0x00}, // Removes vertical lines appearing under bright light
		{0x3612, 0x59},
		{0x3708, 0x64},
		{0x3709, 0x52},
		{0x370c, 0x03},

		//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
		{0x4300, 0x00},
		//[2:0]=0x3 Format select ISP RAW (DPC)
		{0x501f, 0x03}
	};
config_word_t const cfg_1080p_30fps_336M_1lane_mipi_[] =
{//1920 x 1080 @ 30fps, RAW10, MIPISCLK=672, SCLK=67.2MHz, PCLK=134.4M
	//PLL1 configuration
	//[7:4]=0001 System clock divider /1, [3:0]=0001 Scale divider for MIPI /1
	{0x3035, 0x11}, // 30fps setting
	//[7:0]=84 PLL multiplier
	{0x3036, 0x54},
	//[4]=1 PLL root divider /2, [3:0]=5 PLL pre-divider /1.5
	{0x3037, 0x15},
	//[5:4]=00 PCLK root divider /1, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
	{0x3108, 0x01},

	//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
	{0x3034, 0x1A},

	//[7:5]=001 One lane mode, [4]=0 MIPI HS TX no power down, [3]=0 MIPI LP RX no power down, [2]=1 MIPI enable, [1:0]=10 Debug mode; Default=0x58
	{0x300e, 0x25},

	//[3:0]=0 X address start high byte
	{0x3800, (336 >> 8) & 0x0F},
	//[7:0]=0 X address start low byte
	{0x3801, 336 & 0xFF},
	//[2:0]=0 Y address start high byte
	{0x3802, (426 >> 8) & 0x07},
	//[7:0]=0 Y address start low byte
	{0x3803, 426 & 0xFF},

	//[3:0] X address end high byte
	{0x3804, (2287 >> 8) & 0x0F},
	//[7:0] X address end low byte
	{0x3805, 2287 & 0xFF},
	//[2:0] Y address end high byte
	{0x3806, (1529 >> 8) & 0x07},
	//[7:0] Y address end low byte
	{0x3807, 1529 & 0xFF},

	//[3:0]=0 timing hoffset high byte
	{0x3810, (16 >> 8) & 0x0F},
	//[7:0]=0 timing hoffset low byte
	{0x3811, 16 & 0xFF},
	//[2:0]=0 timing voffset high byte
	{0x3812, (12 >> 8) & 0x07},
	//[7:0]=0 timing voffset low byte
	{0x3813, 12 & 0xFF},

	//[3:0] Output horizontal width high byte
	{0x3808, (1920 >> 8) & 0x0F},
	//[7:0] Output horizontal width low byte
	{0x3809, 1920 & 0xFF},
	//[2:0] Output vertical height high byte
	{0x380a, (1080 >> 8) & 0x7F},
	//[7:0] Output vertical height low byte
	{0x380b, 1080 & 0xFF},

	//HTS line exposure time in # of pixels Tline=HTS/sclk
	{0x380c, (2500 >> 8) & 0x1F},
	{0x380d, 2500 & 0xFF},
	//VTS frame exposure time in # lines
	{0x380e, (1120 >> 8) & 0xFF},
	{0x380f, 1120 & 0xFF},

	//[7:4]=0x1 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
	{0x3814, 0x11},
	//[7:4]=0x1 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
	{0x3815, 0x11},

	//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=0 no horizontal binning
	{0x3821, 0x00},

	//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
	{0x4837, 28}, // 1/84M*2

	//Undocumented anti-green settings
	{0x3618, 0x00}, // Removes vertical lines appearing under bright light
	{0x3612, 0x59},
	{0x3708, 0x64},
	{0x3709, 0x52},
	{0x370c, 0x03},

	//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
	{0x4300, 0x00},
	//[2:0]=0x3 Format select ISP RAW (DPC)
	{0x501f, 0x03}
};
config_word_t const cfg_init_[] =
{
	//[7]=0 Software reset; [6]=1 Software power down; Default=0x02
	{0x3008, 0x42},
	//[1]=1 System input clock from PLL; Default read = 0x11
	{0x3103, 0x03},
	//[3:0]=0000 MD2P,MD2N,MCP,MCN input; Default=0x00
	{0x3017, 0x00},
	//[7:2]=000000 MD1P,MD1N, D3:0 input; Default=0x00
	{0x3018, 0x00},
	//[6:4]=001 PLL charge pump, [3:0]=1000 MIPI 8-bit mode
	{0x3034, 0x18},

	//              +----------------+        +------------------+         +---------------------+        +---------------------+
	//XVCLK         | PRE_DIV0       |        | Mult (4+252)     |         | Sys divider (0=16)  |        | MIPI divider (0=16) |
	//+-------+-----> 3037[3:0]=0001 +--------> 3036[7:0]=0x38   +---------> 3035[7:4]=0001      +--------> 3035[3:0]=0001      |
	//12MHz   |     | / 1            | 12MHz  | * 56             | 672MHz  | / 1                 | 672MHz | / 1                 |
	//        |     +----------------+        +------------------+         +----------+----------+        +----------+----------+
	//        |                                                                       |                              |
	//        |                                                                       |                      MIPISCLK|672MHz
	//        |                                                                       |                              |
	//        |     +----------------+        +------------------+         +----------v----------+        +----------v----------+
	//        |     | PRE_DIVSP      |        | R_DIV_SP         |         | PLL R divider       |        | MIPI PHY            | MIPI_CLK
	//        +-----> 303d[5:4]=01   +--------> 303d[2]=0 (+1)   |         | 3037[4]=1 (+1)      |        |                     +------->
	//              | / 1.5          |  8MHz  | / 1              |         | / 2                 |        | / 2                 | 336MHz
	//              +----------------+        +---------+--------+         +----------+----------+        +---------------------+
	//                                                  |                             |
	//                                                  |                             |
	//                                                  |                             |
	//              +----------------+        +---------v--------+         +----------v----------+        +---------------------+
	//              | SP divider     |        | Mult             |         | BIT div (MIPI 8/10) |        | SCLK divider        | SCLK
	//              | 303c[3:0]=0x1  +<-------+ 303b[4:0]=0x19   |         | 3034[3:0]=0x8)      +----+---> 3108[1:0]=01 (2^)   +------->
	//              | / 1            | 200MHz | * 25             |         | / 2                 |    |   | / 2                 | 84MHz
	//              +--------+-------+        +------------------+         +----------+----------+    |   +---------------------+
	//                       |                                                        |               |
	//                       |                                                        |               |
	//                       |                                                        |               |
	//              +--------v-------+                                     +----------v----------+    |   +---------------------+
	//              | R_SELD5 div    | ADCCLK                              | PCLK div            |    |   | SCLK2x divider      |
	//              | 303d[1:0]=001  +------->                             | 3108[5:4]=00 (2^)   |    +---> 3108[3:2]=00 (2^)   +------->
	//              | / 1            | 200MHz                              | / 1                 |        | / 1                 | 168MHz
	//              +----------------+                                     +----------+----------+        +---------------------+
	//                                                                                |
	//                                                                                |
	//                                                                                |
	//                                                                     +----------v----------+        +---------------------+
	//                                                                     | P divider (* #lanes)| PCLK   | Scale divider       |
	//                                                                     | 3035[3:0]=0001      +--------> 3824[4:0]           |
	//                                                                     | / 1                 | 168MHz | / 2                 |
	//                                                                     +---------------------+        +---------------------+

	//PLL1 configuration
	//[7:4]=0001 System clock divider /1, [3:0]=0001 Scale divider for MIPI /1
	{0x3035, 0x11},
	//[7:0]=56 PLL multiplier
	{0x3036, 0x38},
	//[4]=1 PLL root divider /2, [3:0]=1 PLL pre-divider /1
	{0x3037, 0x11},
	//[5:4]=00 PCLK root divider /1, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
	{0x3108, 0x01},
	//PLL2 configuration
	//[5:4]=01 PRE_DIV_SP /1.5, [2]=1 R_DIV_SP /1, [1:0]=00 DIV12_SP /1
	{0x303D, 0x10},
	//[4:0]=11001 PLL2 multiplier DIV_CNT5B = 25
	{0x303B, 0x19},

	{0x3630, 0x2e},
	{0x3631, 0x0e},
	{0x3632, 0xe2},
	{0x3633, 0x23},
	{0x3621, 0xe0},
	{0x3704, 0xa0},
	{0x3703, 0x5a},
	{0x3715, 0x78},
	{0x3717, 0x01},
	{0x370b, 0x60},
	{0x3705, 0x1a},
	{0x3905, 0x02},
	{0x3906, 0x10},
	{0x3901, 0x0a},
	{0x3731, 0x02},
	//VCM debug mode
	{0x3600, 0x37},
	{0x3601, 0x33},
	//System control register changing not recommended
	{0x302d, 0x60},
	//??
	{0x3620, 0x52},
	{0x371b, 0x20},
	//?? DVP
	{0x471c, 0x50},

	{0x3a13, 0x43},
	{0x3a18, 0x00},
	{0x3a19, 0xf8},
	{0x3635, 0x13},
	{0x3636, 0x06},
	{0x3634, 0x44},
	{0x3622, 0x01},
	{0x3c01, 0x34},
	{0x3c04, 0x28},
	{0x3c05, 0x98},
	{0x3c06, 0x00},
	{0x3c07, 0x08},
	{0x3c08, 0x00},
	{0x3c09, 0x1c},
	{0x3c0a, 0x9c},
	{0x3c0b, 0x40},

	//[7]=1 color bar enable, [3:2]=00 eight color bar
	{0x503d, 0x00},
	//[2]=1 ISP vflip, [1]=1 sensor vflip
	{0x3820, 0x46},

	//[7:5]=010 Two lane mode, [4]=0 MIPI HS TX no power down, [3]=0 MIPI LP RX no power down, [2]=1 MIPI enable, [1:0]=10 Debug mode; Default=0x58
	{0x300e, 0x45},
	//[5]=0 Clock free running, [4]=1 Send line short packet, [3]=0 Use lane1 as default, [2]=1 MIPI bus LP11 when no packet; Default=0x04
	{0x4800, 0x14},
	{0x302e, 0x08},
	//[7:4]=0x3 YUV422, [3:0]=0x0 YUYV
	//{0x4300, 0x30},
	//[7:4]=0x6 RGB565, [3:0]=0x0 {b[4:0],g[5:3],g[2:0],r[4:0]}
	{0x4300, 0x6f},
	{0x501f, 0x01},

	{0x4713, 0x03},
	{0x4407, 0x04},
	{0x440e, 0x00},
	{0x460b, 0x35},
	//[1]=0 DVP PCLK divider manual control by 0x3824[4:0]
	{0x460c, 0x20},
	//[4:0]=1 SCALE_DIV=INT(3824[4:0]/2)
	{0x3824, 0x01},

	//MIPI timing
	//		{0x4805, 0x10}, //LPX global timing select=auto
	//		{0x4818, 0x00}, //hs_prepare + hs_zero_min ns
	//		{0x4819, 0x96},
	//		{0x482A, 0x00}, //hs_prepare + hs_zero_min UI
	//
	//		{0x4824, 0x00}, //lpx_p_min ns
	//		{0x4825, 0x32},
	//		{0x4830, 0x00}, //lpx_p_min UI
	//
	//		{0x4826, 0x00}, //hs_prepare_min ns
	//		{0x4827, 0x32},
	//		{0x4831, 0x00}, //hs_prepare_min UI

	//[7]=1 LENC correction enabled, [5]=1 RAW gamma enabled, [2]=1 Black pixel cancellation enabled, [1]=1 White pixel cancellation enabled, [0]=1 Color interpolation enabled
	{0x5000, 0x07},
	//[7]=0 Special digital effects, [5]=0 scaling, [2]=0 UV average disabled, [1]=1 Color matrix enabled, [0]=1 Auto white balance enabled
	{0x5001, 0x03}
};

config_modes_t const modes[] =
{
		{ MAP_ENUM_TO_CFG(MODE_720P_1280_720_60fps, cfg_720p_60fps_) },
		{ MAP_ENUM_TO_CFG(MODE_1080P_1920_1080_15fps, cfg_1080p_15fps_) },
		{ MAP_ENUM_TO_CFG(MODE_1080P_1920_1080_30fps, cfg_1080p_30fps_), },
		{ MAP_ENUM_TO_CFG(MODE_1080P_1920_1080_30fps_336M_MIPI, cfg_1080p_30fps_336M_mipi_) },
		{ MAP_ENUM_TO_CFG(MODE_1080P_1920_1080_30fps_336M_1LANE_MIPI, cfg_1080p_30fps_336M_1lane_mipi_) },
};

config_awb_t const awbs[] =
{
		{ MAP_ENUM_TO_CFG(AWB_DISABLED, cfg_disable_awb_) },
		{ MAP_ENUM_TO_CFG(AWB_SIMPLE, cfg_simple_awb_) },
		{ MAP_ENUM_TO_CFG(AWB_ADVANCED, cfg_advanced_awb_) }
};

// Initialize the OV5640 driver with a pointer to the I2C instance
int ov5640_init(XIIC_TYPE *iic_inst,XGpio *gpio_inst,uint8_t gpio_mask)
{
	// Copy the IIC instance pointer that connects to the OV5640
	ov5640_iic = iic_inst;
	// Copy the GPIO instance for the reset signal
	ov5640_gpio = gpio_inst;
	ov5640_gpio_mask = gpio_mask;

	return XST_SUCCESS;
}

/*
 * Configure and start the camera
 *
 * Known issue:
 * I have put the config sequence in a do while loop because I have found that
 * it is not completely reliable and sometimes needs repeating - sometimes the camera
 * seems to not have started properly, or is not outputting images.
 * More work needs to be done on this to figure out the cause, however
 * my feeling is that there may have been something wrong with my flex
 * cable, because the results were intermittent and sometimes depended
 * on how the camera/cable was positioned.
 *
 */
int ov5640_config(vmode_t mode,awb_t awb)
{
	int Status;
	uint8_t gpi_status_high,gpi_status_low,frame_status_high,frame_status_low;
	uint8_t mask;
	// Reset the camera
	ov5640_reset();
	do {
		// Initial configuration from step 4:
		// https://digilent.com/reference/add-ons/pcam-5c/reference-manual?redirect=1#power-up_and_reset
		// 4. Choose system input clock from pad by writing 0x11 to register address 0x3103.
		Status = ov5640_writeReg(0x3103,0x11);
		//[7]=1 Software reset; [6]=0 Software power down; Default=0x02
		// 5. Execute software reset by writing 0x82 to register address 0x3008.
		Status = ov5640_writeReg(0x3008, 0x82);
		// 6. Wait 10ms
		usleep(10000);
		// Steps 7+
		Status = ov5640_write_config(cfg_init_,sizeof(cfg_init_)/sizeof(cfg_init_[0]));
		// AWB config
		config_awb_t const *cfg_awb = &awbs[awb];
	    Status = ov5640_write_config(cfg_awb->cfg,cfg_awb->cfg_size);
	    // Video mode config
		config_modes_t const *cfg_mode = &modes[mode];
	    //[7]=0 Software reset; [6]=1 Software power down; Default=0x02
	    ov5640_writeReg(0x3008, 0x42);
	    usleep(20000);
	    Status = ov5640_write_config(cfg_mode->cfg,cfg_mode->cfg_size);
	    //[7]=0 Software reset; [6]=0 Software power down; Default=0x02
	    ov5640_writeReg(0x3008, 0x02);

	    /*
	     * Releasing the OV5640 from software reset seems to lock up the I2C driver
	     * and the only way I have found to fix the problem is to
	     * reset the driver.
	     */
	    usleep(10000);
	    XIic_Reset(ov5640_iic);

		// Check GPI_STATUS and FRAME_STATUS registers to ensure
		// that the camera has started properly
		ov5640_readReg(0x3026,&gpi_status_high);
		ov5640_readReg(0x3027,&gpi_status_low);
		ov5640_readReg(0x303C,&frame_status_high);
		ov5640_readReg(0x303D,&frame_status_low);

		if ((gpi_status_high == 0xFF) && (gpi_status_low == 0xFF)) {
			xil_printf("OV5640 repeating configuration\n\r");
			usleep(10000);
		}
	} while ((gpi_status_high == 0xFF) && (gpi_status_low == 0xFF));
	xil_printf("OV5640 camera configured\n\r");
	return XST_SUCCESS;
}

/*
 * Looks for the OV5640 on the I2C bus
 *
 * This function will ensure that the I2C MUX is properly configured before attempting
 * to communicate with the OV5640. It will return the MUX to its original state afterwards.
 */
int ov5640_detect()
{
	int Status;
	uint8_t data;
	uint8_t mask;

	// Read the register
	Status = ov5640_readReg(0x3100,&data);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: ov5640_detect could not read register\n\r");
		return XST_FAILURE;
	}
	if(data != 0x78) {
		return XST_FAILURE;
	}
	else {
		return XST_SUCCESS;
	}
}

/*
 * Internal functions
 *
 * The following functions are intended to be used only internally to this library.
 */

// Reset the OV5640 by toggling the enable pin
int ov5640_reset()
{
	// Disable the camera, wait 100ms
	XGpio_DiscreteClear(ov5640_gpio, 1, ov5640_gpio_mask);
	usleep(100000);
	// Enable the camera, wait 50ms
	XGpio_DiscreteWrite(ov5640_gpio, 1, ov5640_gpio_mask);
	usleep(50000);
	return XST_SUCCESS;
}

// Write to a register of the OV5640
int ov5640_writeReg(uint16_t addr, uint8_t data)
{
	int Status;
	// Write to OV5640 register
	uint8_t buf[10];
	buf[0] = addr >> 8;
	buf[1] = addr & 0x00FF;
	buf[2] = data;
	Status = IicWrite(ov5640_iic,IIC_OV5640_ADDR,buf,3);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: ov5640_writeReg failed\n\r");
	}
	return Status;
}

// Read from a register of the OV5640
int ov5640_readReg(uint16_t addr, uint8_t *data)
{
	int Status;
	// Read the OV5640 register
	uint8_t buf[10];
	buf[0] = addr >> 8;
	buf[1] = addr & 0x00FF;
	Status = IicWrite(ov5640_iic,IIC_OV5640_ADDR,buf,2);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: ov5640_readReg failed to write the address\n\r");
		return(Status);
	}
	Status = IicRead(ov5640_iic,IIC_OV5640_ADDR,buf,1);
	if (Status != XST_SUCCESS) {
		xil_printf("ERROR: ov5640_readReg failed to read from address\n\r");
		return(Status);
	}
	*data = buf[0];
	return Status;
}

// Write a set configuration to the OV5640
// The configs originated from this Digilent design:
// https://github.com/Digilent/Zybo-Z7-20-pcam-5c/blob/master/sdk/appsrc/pcam_vdma_hdmi/ov5640/OV5640.h
int ov5640_write_config(config_word_t const *cfg, size_t len)
{
	int Status;
    for(int i = 0; i < len; i++)
    {
    	Status = ov5640_writeReg(cfg[i].addr,cfg[i].data);
    	if (Status != XST_SUCCESS)
    	{
    		return(Status);
    	}
    	// The following delay seems to have an impact on the reliability of the
    	// OV5640 bring up. 15ms is too long, 8ms is too short
		usleep(10000);
    }

    return XST_SUCCESS;
}

