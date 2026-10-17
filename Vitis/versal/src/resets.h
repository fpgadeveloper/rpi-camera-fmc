/*
 * Opsero Electronic Design Inc. Copyright 2026
 * SPDX-License-Identifier: MIT
 */

#ifndef RESETS_H_
#define RESETS_H_

int  resets_init(void);           /* all IP resets asserted */
void reset_release(unsigned bit); /* EMIO bit number, see config.h */
void reset_assert(unsigned bit);

#endif /* RESETS_H_ */
