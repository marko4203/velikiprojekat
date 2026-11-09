# Makefile za pathfinder_driver.ko
#
# Nativno na Zybo ploci (kernel headers/build dir mora postojati):
#     make
#
# Kros-kompajliranje na host racunaru (isti kernel source koji je pravio image!):
#     make KERNELDIR=/putanja/do/linux-xlnx ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
#
# NAPOMENA: obj-m mora da se poklapa sa imenom .c fajla (u EOS1 Makefile-u
# je stajalo filter_driver_v2.o dok se fajl zove filter_driver.c - to ne radi).

ifneq ($(KERNELRELEASE),)
	obj-m := pathfinder_driver.o
else
	KERNELDIR ?= /lib/modules/$(shell uname -r)/build
	PWD := $(shell pwd)

default:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) clean
endif
