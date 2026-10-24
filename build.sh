#!/bin/bash
# Builds everything the Kindle needs, in Docker, on an Apple Silicon Mac (the kernel toolchain image is arm64).
# Usage: ./build.sh KERNEL_TARBALL DEVICE_CONFIG [step...]
#   KERNEL_TARBALL  linux-4.9.tar.gz from the Kindle GPL source release (firmware 5.18.1)
#   DEVICE_CONFIG   the running kernel's config: ssh to the Kindle and `zcat /proc/config.gz`
#   steps           images kernel drm stage compat bridge rootfs (default: all, in that order)
set -euo pipefail
cd "$(dirname "$0")"
tarball=${1:?kernel tarball}; config=${2:?device kernel config}; shift 2
steps=${*:-images kernel drm stage compat bridge rootfs}
tarball=$(cd "$(dirname "$tarball")" && pwd)/$(basename "$tarball")
config=$(cd "$(dirname "$config")" && pwd)/$(basename "$config")
ARM=(--platform linux/arm/v7)
mkdir -p out/kernel-build out/drm-build out/stage

images() {
  docker run --privileged --rm tonistiigi/binfmt:qemu-v9.2.2 --install arm
  docker build -t okkernel:gcc49 toolchain
  docker image inspect okarch:base >/dev/null 2>&1 ||
    curl -fL http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz | docker import "${ARM[@]}" - okarch:base
  docker build "${ARM[@]}" -t okarch:build bridge
}

kernel() {
  docker run --rm -v okbuild:/w -v "$tarball":/src.tgz:ro okkernel:gcc49 \
    bash -c '[ -f /w/Makefile ] || tar -xzf /src.tgz -C /w'
  docker run --rm -v okbuild:/w -v okobj:/obj -v "$PWD/toolchain/build-kernel.sh":/build.sh:ro \
    -v "$config":/cfg:ro -v "$PWD/out/kernel-build":/out okkernel:gcc49 bash /build.sh
}

drm() {
  docker run --rm -v okbuild:/w -v okobjdrm:/obj-drm -v "$PWD/toolchain/build-drm.sh":/build.sh:ro \
    -v "$PWD/patches":/patches:ro -v "$config":/cfg:ro -v "$PWD/out/drm-build":/out okkernel:gcc49 bash /build.sh
  docker run --rm -v okbuild:/w -v okobj:/obj -v "$PWD/toolchain/ext-hdmi":/ext:ro \
    -v "$PWD/toolchain/build-hdmi.sh":/b.sh:ro -v "$PWD/out/drm-build":/out okkernel:gcc49 bash /b.sh \
    > out/drm-build/hdmi-Module.symvers
}

stage() {
  docker run --rm -v "$PWD":/p okkernel:gcc49 bash -c '
    set -e
    bash /p/tools/extract-modsections.sh /p/out/drm-build/modules
    for m in hdmi drm vgem; do arm-linux-gnueabihf-strip --strip-debug -o /p/out/stage/$m.ko /p/out/drm-build/modules/$m.ko; done'
  (cd out/stage && shasum -a 256 hdmi.ko drm.ko vgem.ko > SHA256SUMS)
  # Every symbol the new modules import must exist in the stock kernel with the same CRC.
  cat out/drm-build/drm-Module.symvers out/drm-build/hdmi-Module.symvers > out/drm-build/combined.symvers
  python3 tools/check_imports.py reference/stock-vmlinux-crcs.json out/drm-build/modules out/drm-build/combined.symvers
}

compat() { docker run --rm "${ARM[@]}" -v "$PWD":/src -w /src/compat okarch:build make install; }
bridge() { docker run --rm "${ARM[@]}" -v "$PWD":/src -w /src/bridge okarch:build make; }

rootfs() {
  docker run --rm --privileged "${ARM[@]}" -v okroot:/out -v "$PWD/rootfs/pacstrap.sh":/p.sh:ro \
    -v "$PWD/rootfs/packages.txt":/packages.txt:ro okarch:base bash /p.sh
  docker run --rm -v okroot:/out -v "$PWD/rootfs/mkimage.sh":/m.sh:ro debian:bookworm-slim bash /m.sh
}

for s in $steps; do echo "== $s"; "$s"; done
