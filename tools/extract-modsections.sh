#!/bin/bash
# Extract __versions and .modinfo from every .ko in $1 (run inside okkernel:gcc49).
for ko in "$1"/*.ko; do
  arm-linux-gnueabihf-objcopy -O binary --only-section=__versions "$ko" "${ko%.ko}.versions"
  arm-linux-gnueabihf-objcopy -O binary --only-section=.modinfo "$ko" "${ko%.ko}.modinfo"
done
