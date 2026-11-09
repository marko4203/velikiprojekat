#if defined(CONFIG_MICROBLAZE)
#include <configs/microblaze-generic.h>
#define CONFIG_SYS_BOOTM_LEN 0xF000000
#endif
#if defined(CONFIG_ARCH_ZYNQ)
#include <configs/zynq-common.h>
#endif
#if defined(CONFIG_ARCH_ZYNQMP)
#include <configs/xilinx_zynqmp.h>
#endif
#if defined(CONFIG_ARCH_VERSAL)
#include <configs/xilinx_versal.h>
#endif
#if defined(CONFIG_ARCH_VERSAL_NET)
#include <configs/xilinx_versal_net.h>
#endif

/*
 * NAPOMENA: blok "#undef/#define CONFIG_BOOTCOMMAND" iz Vezbe 11 (PetaLinux 2019.2)
 * ovde NE SME da stoji. U u-boot-u 2026.1 bootcmd je Kconfig opcija, a sistem se
 * podize distro-boot skriptom boot.scr; komande cp_kernel2ram/cp_dtb2ram/netstart
 * iz 2019.2 vise ne postoje, pa bi taj bootcmd zaustavio boot u u-boot promptu.
 */
