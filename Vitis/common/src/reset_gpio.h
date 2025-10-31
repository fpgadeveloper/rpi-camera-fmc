/*
 * Opsero Electronic Design Inc. Copyright 2025
 * 
 * These functions facilitate the control of the resets in the design.
*/
#pragma once
#include <stdint.h>

// Reset GPIO masks
#define RESET_GPIO_VTPG_RST_N_MASK          (0x1 << 0)  // Video Pattern Generator IP reset
#define RESET_GPIO_VMIX_RST_N_MASK          (0x1 << 1)  // Video Mixer IP reset

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

/* Optional convenience for VTPG/VMIX (single-bit masks) */
#define RESET_MASK_VTPG (1u << 0)
#define RESET_MASK_VMIX (1u << 1)
