# libudev-zero: libudev without udevd or modern syscalls, for the 4.9 kernel. Builds inside okarch:build.
TAG := 1.0.5

out/libudev.so.1: libudev-zero/libudev.so.1
	mkdir -p out && cp libudev-zero/libudev.so.1 $@

libudev-zero/libudev.so.1:
	git clone --depth 1 --branch $(TAG) https://github.com/illiliti/libudev-zero.git
	patch -d libudev-zero -p1 < mt-touchscreen.patch
	$(MAKE) -C libudev-zero
