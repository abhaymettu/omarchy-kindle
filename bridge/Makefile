# Builds inside okarch:build (armv7h). FBInk is fetched at a pinned commit and linked statically.
# master: v1.25.0 does not know the 2024 Kindle Basic (3KM, Rossini/Bellatrix)
FBINK_COMMIT := 886f25f13368859ad8a899b88d04c26e19cda32e
PROTO := /usr/share/wlr-protocols/unstable/wlr-screencopy-unstable-v1.xml

all: kbridge kexit

# kexit runs on the Kindle host, outside the chroot, so it is static.
kexit: kexit.c
	cc -O2 -static -Wall -o $@ $< && strip $@

kbridge: kbridge.c wlr-screencopy-unstable-v1-protocol.c FBInk/Release/libfbink.a
	cc -O2 -Wall -IFBInk -o $@ kbridge.c wlr-screencopy-unstable-v1-protocol.c FBInk/Release/libfbink.a -lwayland-client -lm

wlr-screencopy-unstable-v1-protocol.c:
	wayland-scanner client-header $(PROTO) wlr-screencopy-unstable-v1-client-protocol.h
	wayland-scanner private-code $(PROTO) $@

# Diagnostics: the udev enumeration and GBM/EGL allocation paths Aquamarine takes.
probes: udevprobe.c gbmprobe.c
	cc -O2 -Wall -o udevprobe udevprobe.c -ludev
	cc -O2 -Wall -I/usr/include/libdrm -o gbmprobe gbmprobe.c -lgbm -lEGL -lGLESv2 -ldrm

FBInk/Release/libfbink.a:
	git clone --recurse-submodules https://github.com/NiLuJe/FBInk.git && git -C FBInk checkout -q $(FBINK_COMMIT) && git -C FBInk submodule update -q --init --recursive
	$(MAKE) -C FBInk KINDLE=1 MINIMAL=1 IMAGE=1 staticlib

.PHONY: all probes clean

clean:
	rm -f kbridge kexit udevprobe gbmprobe wlr-screencopy-unstable-v1-*
