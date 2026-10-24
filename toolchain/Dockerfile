FROM arm64v8/ubuntu:16.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      gcc-4.9-arm-linux-gnueabihf binutils-arm-linux-gnueabihf \
      gcc make bc perl python3 xz-utils ca-certificates libc6-dev \
 && apt-get clean \
 && for t in gcc cpp; do ln -s /usr/bin/arm-linux-gnueabihf-$t-4.9 /usr/local/bin/arm-linux-gnueabihf-$t; done
ENV ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
WORKDIR /w
