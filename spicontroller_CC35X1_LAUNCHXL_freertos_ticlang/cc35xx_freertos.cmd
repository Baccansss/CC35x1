/*
 * Copyright (c) 2022-2024, Texas Instruments Incorporated
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * *  Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * *  Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * *  Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

--stack_size=2048
--heap_size=0
--entry_point resetISR

/* Retain interrupt vector table variable                                    */
--retain "*(.resetVecs)"

/* Suppress warnings and errors:                                             */
/* - 10063: Warning about entry point not being _c_int00                     */
/* - 16011, 16012: 8-byte alignment errors. Observed when linking in object  */
/*   files compiled using Keil (ARM compiler)                                */
--diag_suppress=10063,16011,16012

/* Set severity of diagnostics to Remark instead of Warning                  */
/* - 10068: Warning about no matching log_ptr* sections                      */
--diag_remark=10068

#define FLASH_BASE              0x10000000
#define FLASH_SIZE              0x00040000 /* TODO: Update flash size for non FPGA device. The external flash on FPGAs (M24M02-DRMN6TP) has 256KB (2Mbit) of external flash */
#define CRAM_BASE               0x00000000
#define CRAM_SIZE               0x00008000
#define DRAM_BASE               0x28000000
#define DRAM_SIZE               0x00030000 /* (Static only) DRAM1: 128K + DRAM2: 64K */

/* System memory map */
MEMORY
{
    /* Application stored in and executes from external flash */
    FLASH (RX) : origin = FLASH_BASE, length = FLASH_SIZE
    /* Application uses internal CRAM for code/data */
    CRAM (RWX) : origin = CRAM_BASE, length = CRAM_SIZE
    /* Application uses internal DRAM for data */
    DRAM (RWX) : origin = DRAM_BASE, length = DRAM_SIZE
    /* Explicitly placed off target for the storage of logging data.
     * The ARM memory map allocates 1 GB of external memory from 0x60000000 - 0x9FFFFFFF.
     * Unlikely that all of this will be used, so we are using the upper parts of the region.
     * ARM memory map: https://developer.arm.com/documentation/ddi0337/e/memory-map/about-the-memory-map*/
    LOG_DATA (R) : origin = 0x90000000, length = 0x40000        /* 256 KB */
    LOG_PTR  (R) : origin = 0x94000008, length = 0x40000        /* 256 KB */

    /* Other memory regions */
    PERIPH_API (RW)  : origin = 0x45602000, length = 0x0000001F
    MEM_POOL   (RW)  : origin = 0x28044000, length = 0x00004000
    DB_MEM     (RW)  : origin = 0x45A80000, length = 0x0000FFFF
    PHY_CTX    (RW)  : origin = 0x45900000, length = 0x00010000
    PHY_SCR    (RW)  : origin = 0x45910000, length = 0x00004800
    CPERAM     (RWX) : origin = 0x45C00000, length = 0x00010000 /* 64K PROGRAM MEMORY  */
    MCERAM     (RWX) : origin = 0x45C80000, length = 0x00001000 /* 4K PROGRAM MEMORY   */
    RFERAM     (RWX) : origin = 0x45CA0000, length = 0x00001000 /* 4K PROGRAM MEMORY   */
    MDMRAM     (RWX) : origin = 0x45CC0000, length = 0x00000100 /* 256B PROGRAM MEMORY */
}

/* Section allocation in memory */
SECTIONS
{
    /* Flash */
    GROUP {
        /* The first flash sector (4KB bytes)
         * and the first 0x1C bytes of the second flash sector is reserved for
         * metadata used by the bootloader. The interrupt vectors must be 512B
         * aligned so the vector table must be at 0x10000000 + 0x1000 + 0x200 =
         * 0x10001200
         * TODO: Incorrect alignment of 256B resulting in 0x10001100 is
         * currently used, to match what the bootloader currently expects. This
         * needs to be fixed when the bootloader uses the correct alignment.
         * See TIDRIVERS-6649.
         * The bytes from the end of bootloader metadata to the vector table
         * (0x1000101C to 0x100010FF, both inlcuded) must be filled with 0xFF.
         */
        .reserved:                   { . += 0x101C; } (NOLOAD) /* Reserved for bootloader metadata */
        .padding : fill = 0xFFFFFFFF { . += 0x00E4; }
        .resetVecs:                  {} PALIGN(4)
    } > FLASH_BASE
    .text           :   > FLASH PALIGN(4)
    .text.__TI      : { *(.text.__TI*) } > FLASH PALIGN(4)
    .const          :   > FLASH PALIGN(4)
    .constdata      :   > FLASH PALIGN(4)
    .rodata         :   > FLASH PALIGN(4)
    .binit          :   > FLASH PALIGN(4)
    .cinit          :   > FLASH PALIGN(4)
    .pinit          :   > FLASH PALIGN(4)
    .init_array     :   > FLASH PALIGN(4)
    .emb_text       :   > FLASH PALIGN(4)

    /* Code RAM */
    .ramVecs        :   > CRAM_BASE, type = NOLOAD, ALIGN(512)
    .TI.ramfunc     : {} load=FLASH, run=CRAM, table(BINIT)

    /* Data RAM */
    .data           :   > DRAM
    .bss            :   > DRAM
    .sysmem         :   > DRAM
    .stack          :   > DRAM (HIGH)
    .nonretenvar    :   > DRAM

    .cio            :   > DRAM
    .ARM.exidx      :   > DRAM
    .vtable         :   > DRAM
    .args           :   > DRAM

    /* Other meomory regions */
    .ctx_ull        :   > PHY_CTX
    .scr_ull        :   > PHY_SCR
    .cperam         :   > CPERAM         /* CPE CODE */
    .rferam         :   > RFERAM         /* RFE CODE */
    .mceram         :   > MCERAM         /* MCE CODE */
    .mdmram         :   > MDMRAM         /* MDM CODE */
    .db_mem         :   > DB_MEM
    .perif_if       :   > PERIPH_API
    .mem_pool       :   > MEM_POOL

    .log_data       :   > LOG_DATA, type = COPY
    .log_ptr        : { *(.log_ptr*) } > LOG_PTR align 4, type = COPY
}
