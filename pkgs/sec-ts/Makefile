KERNEL_RELEASE ?= $(shell uname -r)
KERNEL_DIR ?= /lib/modules/$(KERNEL_RELEASE)/build

obj-m += sec_ts.o
sec_ts-objs += sec_ts_main.o sec_ts_fw.o sec_ts_fn.o sec_ts_selftest.o

.PHONY: all clean

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean
