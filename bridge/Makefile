# Builds inside okarch:build (armv7h). FBInk is fetched at a pinned tag and linked statically.
FBINK_TAG := v1.25.0
PROTO := /usr/share/wlr-protocols/unstable/wlr-screencopy-unstable-v1.xml

kbridge: kbridge.c wlr-screencopy-unstable-v1-protocol.c FBInk/Release/libfbink.a
	cc -O2 -Wall -IFBInk -o $@ kbridge.c wlr-screencopy-unstable-v1-protocol.c FBInk/Release/libfbink.a -lwayland-client -lm

wlr-screencopy-unstable-v1-protocol.c:
	wayland-scanner client-header $(PROTO) wlr-screencopy-unstable-v1-client-protocol.h
	wayland-scanner private-code $(PROTO) $@

FBInk/Release/libfbink.a:
	git clone --depth 1 --branch $(FBINK_TAG) --recurse-submodules https://github.com/NiLuJe/FBInk.git
	$(MAKE) -C FBInk KINDLE=1 MINIMAL=1 IMAGE=1 staticlib

clean:
	rm -f kbridge wlr-screencopy-unstable-v1-*
