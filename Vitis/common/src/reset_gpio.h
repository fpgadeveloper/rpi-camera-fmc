/*
 * Opsero Electronic Design Inc. Copyright 2025
 * 
 * These functions facilitate the control of the resets in the design.
*/
#pragma once
#include <stdint.h>

// Reset GPIO masks
#define RESET_GPIO_CAM0_DEMOSAIC_RST_N_MASK (0x1 << 0)  // CAM0 Demosaic IP reset
#define RESET_GPIO_CAM0_VPROC_RST_N_MASK    (0x1 << 1)  // CAM0 Vproc IP reset
#define RESET_GPIO_CAM0_GAMMA_RST_N_MASK    (0x1 << 2)  // CAM0 Gamma LUT IP reset
#define RESET_GPIO_CAM0_FRMBUFRD_RST_N_MASK (0x1 << 3)  // CAM0 Frame Buffer Read IP reset
#define RESET_GPIO_CAM0_FRMBUFWR_RST_N_MASK (0x1 << 4)  // CAM0 Frame Buffer Write IP reset
#define RESET_GPIO_VTPG_RST_N_MASK          (0x1 << 5)  // Video Pattern Generator IP reset
#define RESET_GPIO_VMIX_RST_N_MASK          (0x1 << 6)  // Video Mixer IP reset
#define RESET_GPIO_RSVD7_MASK               (0x1 << 7)
#define RESET_GPIO_CAM1_DEMOSAIC_RST_N_MASK (0x1 << 8)  // CAM1 Demosaic IP reset
#define RESET_GPIO_CAM1_VPROC_RST_N_MASK    (0x1 << 9)  // CAM1 Vproc IP reset
#define RESET_GPIO_CAM1_GAMMA_RST_N_MASK    (0x1 << 10) // CAM1 Gamma LUT IP reset
#define RESET_GPIO_CAM1_FRMBUFRD_RST_N_MASK (0x1 << 11) // CAM1 Frame Buffer Read IP reset
#define RESET_GPIO_CAM1_FRMBUFWR_RST_N_MASK (0x1 << 12) // CAM1 Frame Buffer Write IP reset
#define RESET_GPIO_RSVD12_MASK              (0x1 << 13)
#define RESET_GPIO_RSVD13_MASK              (0x1 << 14)
#define RESET_GPIO_RSVD14_MASK              (0x1 << 15)
#define RESET_GPIO_CAM2_DEMOSAIC_RST_N_MASK (0x1 << 16) // CAM2 Demosaic IP reset
#define RESET_GPIO_CAM2_VPROC_RST_N_MASK    (0x1 << 17) // CAM2 Vproc IP reset
#define RESET_GPIO_CAM2_GAMMA_RST_N_MASK    (0x1 << 18) // CAM2 Gamma LUT IP reset
#define RESET_GPIO_CAM2_FRMBUFRD_RST_N_MASK (0x1 << 19) // CAM2 Frame Buffer Read IP reset
#define RESET_GPIO_CAM2_FRMBUFWR_RST_N_MASK (0x1 << 20) // CAM2 Frame Buffer Write IP reset
#define RESET_GPIO_RSVD21_MASK              (0x1 << 21)
#define RESET_GPIO_RSVD22_MASK              (0x1 << 22)
#define RESET_GPIO_RSVD23_MASK              (0x1 << 23)
#define RESET_GPIO_CAM3_DEMOSAIC_RST_N_MASK (0x1 << 24) // CAM2 Demosaic IP reset
#define RESET_GPIO_CAM3_VPROC_RST_N_MASK    (0x1 << 25) // CAM2 Vproc IP reset
#define RESET_GPIO_CAM3_GAMMA_RST_N_MASK    (0x1 << 26) // CAM2 Gamma LUT IP reset
#define RESET_GPIO_CAM3_FRMBUFRD_RST_N_MASK (0x1 << 27) // CAM2 Frame Buffer Read IP reset
#define RESET_GPIO_CAM3_FRMBUFWR_RST_N_MASK (0x1 << 28) // CAM2 Frame Buffer Write IP reset
#define RESET_GPIO_RSVD29_MASK              (0x1 << 29)
#define RESET_GPIO_RSVD30_MASK              (0x1 << 30)
#define RESET_GPIO_RSVD31_MASK              (0x1 << 31)

extern XGpio GpioVideoResets;

static inline uint32_t reset_gpio_read(void)   { return XGpio_DiscreteRead(&GpioVideoResets, 1); }
static inline void     reset_gpio_write(uint32_t v) { XGpio_DiscreteWrite(&GpioVideoResets, 1, v); }

/* ==== ACTIVE-LOW SEMANTICS: assert=0, deassert=1 ==== */
static inline void reset_assert(uint32_t mask)
{
    uint32_t v = reset_gpio_read();
    reset_gpio_write(v & ~mask);
}

static inline void reset_deassert(uint32_t mask)
{
    uint32_t v = reset_gpio_read();
    reset_gpio_write(v | mask);
}

/* ===== CAMERA GROUP MASKS =====
 * CAM0: bits 0..4 | CAM1: 8..12 | CAM2: 16..20 | CAM3: 24..28
 */
static inline uint32_t reset_cam_mask(unsigned cam_idx)
{
    /* each camera occupies 5 consecutive bits starting at cam*8 */
    if (cam_idx > 3u) return 0u;
    const unsigned base = cam_idx * 8u;
    return (1u << (base + 0)) | (1u << (base + 1)) | (1u << (base + 2))
         | (1u << (base + 3)) | (1u << (base + 4));
}

static inline void reset_cam_assert(unsigned cam_idx)
{
    reset_assert(reset_cam_mask(cam_idx));
}

static inline void reset_cam_deassert(unsigned cam_idx)
{
    reset_deassert(reset_cam_mask(cam_idx));
}

/* All cameras at once (only the camera bits) */
static inline uint32_t reset_all_cams_mask(void)
{
    return reset_cam_mask(0) | reset_cam_mask(1) | reset_cam_mask(2) | reset_cam_mask(3);
}
static inline void reset_all_cams_assert(void)   { reset_assert(reset_all_cams_mask()); }
static inline void reset_all_cams_deassert(void) { reset_deassert(reset_all_cams_mask()); }

/* Optional convenience for VTPG/VMIX (single-bit masks) */
#define RESET_MASK_VTPG (1u << 5)
#define RESET_MASK_VMIX (1u << 6)
