#!/bin/bash

BITSTREAM=$1
MODEL=$(/opt/redpitaya/bin/monitor -f)
PROJ=v0.94

# Enable read write priviliges
mount -o rw,remount $PATH_REDPITAYA

# Create backup of original fpga.bit.bin
cp -n "/opt/redpitaya/fpga/$MODEL/$PROJ/fpga.bit.bin" "/opt/redpitaya/fpga/$MODEL/$PROJ/fpga_orig.bit.bin"

if [ $# -eq 0 ]
then
    # Original file overwrites fpga.bit.bin
    cp -f "/opt/redpitaya/fpga/$MODEL/$PROJ/fpga_orig.bit.bin" "/opt/redpitaya/fpga/$MODEL/$PROJ/fpga.bit.bin"
    conf="Restored original fpga.bit.bin"
else
    # fpga.bit.bin replaced with custom image
    cp -f "$(realpath $1)" "/opt/redpitaya/fpga/$MODEL/$PROJ/fpga.bit.bin"
    conf="fpga.bit.bin overwritten with $BITSTREAM"
fi

mount -o ro,remount $PATH_REDPITAYA
echo "$conf"