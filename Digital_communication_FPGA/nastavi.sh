#!/bin/bash
if [ $# -eq 0 ]
then
  conf="/opt/redpitaya/fpga/fpga_0.94.bit"
else
 conf=$(realpath $1)
  #echo "test1/2" > file.conf
fi
mount -o rw,remount $PATH_REDPITAYA
echo $conf > /opt/redpitaya/www/apps/la_pro/fpga.conf
mount -o ro,remount $PATH_REDPITAYA
echo "set to "$conf