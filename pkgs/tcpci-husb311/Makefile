KERNEL_RELEASE ?= $(shell uname -r)
KERNEL_DIR ?= /lib/modules/$(KERNEL_RELEASE)/build

obj-m += tcpci_husb311.o

.PHONY: all clean

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
