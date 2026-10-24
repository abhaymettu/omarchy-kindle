# Userland shims for the 4.9 kernel. Builds inside okarch:build; `make install` stages them into the rootfs overlay.
# libudev-zero: libudev without udevd or statx, patched to tag MT-only panels as touchscreens.
# libqt-sigchld: makes Qt reap child processes on a kernel without pidfd (see qt-sigchld.cpp).
TAG := 1.0.5
OVERLAY := ../rootfs/overlay/usr/local/lib

all: out/libudev.so.1 out/libqt-sigchld.so

install: all
	mkdir -p $(OVERLAY)/udev-zero
	cp out/libudev.so.1 $(OVERLAY)/udev-zero/libudev.so.1
	cp out/libqt-sigchld.so $(OVERLAY)/libqt-sigchld.so

out/libudev.so.1: libudev-zero/libudev.so.1
	mkdir -p out && cp libudev-zero/libudev.so.1 $@

libudev-zero/libudev.so.1:
	git clone --depth 1 --branch $(TAG) https://github.com/illiliti/libudev-zero.git
	patch -d libudev-zero -p1 < mt-touchscreen.patch
	$(MAKE) -C libudev-zero

out/libqt-sigchld.so: qt-sigchld.cpp
	mkdir -p out && g++ -O2 -shared -fPIC -o $@ $< $$(pkg-config --cflags --libs Qt6Core)

.PHONY: all install
