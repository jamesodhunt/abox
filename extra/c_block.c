/*--------------------------------------------------------------------
 * vim:set noexpandtab:
 *--------------------------------------------------------------------
 * Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 *--------------------------------------------------------------------
 * Description: See DESIGN.md.
 *--------------------------------------------------------------------
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PAGE_SIZE   4096

#if 0
    #define IO_READ_BUF_SIZE        (PAGE_SIZE * 16)
#else
    // For debugging - the actual size is too big for gdb(1) to cope with.
    #define IO_READ_BUF_SIZE        (PAGE_SIZE)
#endif

struct c_block
{
    size_t  amount;
    size_t  bytes;
    size_t  num;
    size_t  data;
    size_t  done;
	char    buffer[IO_READ_BUF_SIZE];
};

typedef struct c_block CBlock;

CBlock foo;
