#! /bin/bash

XILINX_SDK_BASE=/opt/Xilinx/SDK/2017.4
export CROSS_COMPILE=$XILINX_SDK_BASE/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-
#export CROSS_COMPILE=$XILINX_SDK_BASE/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-
#XILINX_SDK_BASE=/opt/Xilinx/SDK/2016.4
#export CROSS_COMPILE=$XILINX_SDK_BASE/gnu/arm/lin/bin/arm-xilinx-eabi-
#CROSS_COMPILE=arm-none-eabi-
export ARCH=arm

CONFIG_NAME=zynq_snickerdoodle_black_config

BASE=${PWD}
export UBOOT_SOURCE=$BASE/snickerdoodle-u-boot
export UBOOT_OUT=$BASE/build/uboot

echo "Setting up Environment"
source $XILINX_SDK_BASE/settings64.sh

COMMAND="BUILD"

PATH=$BASE/build/kernel/scripts/dtc:$PATH

#Parse the Inputs
echo "Key: $1"

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -r|--rebuild)
    COMMAND="REBUILD"
    shift # past argument
    ;;
    -m|--menu)
    COMMAND="MENU"
    shift # past argument
    ;;
    -c|--clean)
    COMMAND="CLEAN"
    shift # past argument
    ;;
    *)
    # unknown option
    ;;
esac
shift
done

echo "Finished parsing inputs"

cd $UBOOT_SOURCE

if [ "$COMMAND" == "CLEAN" ]; then
  echo "Clean"
  make -j4 clean
  #make O=$UBOOT_OUT -j4 clean
fi
if [ "$COMMAND" == "MENU" ]; then
  echo "Menu Config"
  make O=$UBOOT_OUT -j4 menuconfig
fi
if [ "$COMMAND" == "REBUILD" ]; then
  echo "Re-Build"
  make mrproper
  make O=$UBOOT_OUT -j4 distclean
  make O=$UBOOT_OUT -j4 $CONFIG_NAME
  COMMAND="BUILD"
fi
if [ "$COMMAND" == "BUILD" ]; then
  echo "Build"
  #make O=$UBOOT_OUT -j4 u-boot.elf
  make O=$UBOOT_OUT -j4
fi



