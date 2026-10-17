// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Opsero Electronic Design Inc.
//
// dvi-reg: 32-bit MMIO read/write via /dev/mem (used by dvi-status).
//   dvi-reg <phys addr>            read, prints 0x%08x
//   dvi-reg <phys addr> <value>    write
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 2 || argc > 3) {
		fprintf(stderr, "usage: %s <addr> [value]\n", argv[0]);
		return 2;
	}
	uint64_t addr = strtoull(argv[1], NULL, 0);
	long pg = sysconf(_SC_PAGESIZE);
	uint64_t base = addr & ~(uint64_t)(pg - 1);
	int fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (fd < 0) { perror("/dev/mem"); return 1; }
	void *m = mmap(NULL, pg, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)base);
	if (m == MAP_FAILED) { perror("mmap"); close(fd); return 1; }
	volatile uint32_t *r = (volatile uint32_t *)((char *)m + (addr - base));
	if (argc == 3)
		*r = (uint32_t)strtoul(argv[2], NULL, 0);
	else
		printf("0x%08x\n", *r);
	munmap(m, pg);
	close(fd);
	return 0;
}
