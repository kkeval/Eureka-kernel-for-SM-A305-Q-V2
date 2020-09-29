#!/bin/bash
#
# Copyright © 2020, Samar Vispute "SamarV-121" <samarvispute121@gmail.com>
#
# Custom build script
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
PLATFORM=universal7904
export TELEGRAM_CHAT=@SamarCI

if [ $GITHUB_ACTIONS = true ]; then
GITHUB_WORKFLOW="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
else
ZIPNAME=FuseKernel-test-$(date '+%Y%m%d-%H')-$PLATFORM.zip
fi

blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'

git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc
export KBUILD_BUILD_USER="SamarV-121"
export ARCH=arm64
export CROSS_COMPILE=$(pwd)/gcc/bin/aarch64-linux-android-
git config --global user.name "SamarV-121" && git config --global user.email "samarvispute121@gmail.com"

## Custom Roms (any other than OneUI)
# Generic MTP driver
generic_mtp() {
curl https://github.com/SamarV-121/android_kernel_samsung_universal7904/commit/dcea56dd7942305897e63ec57ede912d4f3b500b.patch | git am
}
# Hardcode SELinux to Permissive
permissive() { 
curl https://github.com/SamarV-121/android_kernel_samsung_universal7904/commit/d32e21c9d25c2ce0f7cd9d664b073c99e9267ec9.patch | git am
}

## OneUI
# Samsung MTP driver
samsung_mtp() {
curl https://github.com/SamarV-121/android_kernel_samsung_universal7904/commit/9c575e78b54380f607b003d1ce712d94327ac9e4.patch | git am
}
# Enforce SELinux
enforcing() {
curl https://github.com/SamarV-121/android_kernel_samsung_universal7904/commit/b6d4e2b03b52f81da94420b8ca15a6f3db22aaee.patch | git am
}

kernel () {
cp -f out/arch/$ARCH/boot/Image AnyKernel3/Image_${DEVICE}
}

kernel_oneui () {
cp -f out/arch/$ARCH/boot/Image AnyKernel3/Image_${DEVICE}_oneui
}

build () {
echo -e "$blue***********************************************"
echo "        Compiling Fuse kernel for $DEVICE         "
echo -e "$blue***********************************************"
make ${DEVICE}_defconfig O=out
make O=out -j$(nproc)
}

make_zip () {
echo -e "$blue***********************************************"
echo -e "     Making flashable zip         "
echo -e "$blue***********************************************"
cd AnyKernel3
zip -r9 $ZIPNAME META-INF tools patch anykernel.sh Image_m20lte Image_m20lte_oneui Image_m30lte Image_m30lte_oneui Image_a30 Image_a30_oneui Image_a40 Image_a40_oneui
cd ..
}

upload () {
echo -e "$blue***********************************************"
echo -e "     Uploading         "
echo -e "$blue***********************************************"
curl -F "file=@AnyKernel3/$ZIPNAME" https://api.bayfiles.com/upload | awk 'BEGIN { FS="https://"; } { print $2; }' | sed 's|","short":"||' | sed 's|^|https://|' > lenk
}

show_link () {
echo -e "$cyan Link: $(<lenk)"
curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d chat_id=$TELEGRAM_CHAT -d text="Build completed successfully
Filename: $ZIPNAME
Download: $(<lenk)" -d chat_id=$TELEGRAM_CHAT > /dev/null
curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQAD8gADLG6EE1T3chaNrvilFgQ --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker > /dev/null
}

DEVICE=m20lte
permissive
curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d parse_mode=MarkdownV2 -d disable_web_page_preview=true -d text="Started Compiling Kernel for *Samsung Exynos 7904 devices*: [See Progress]($GITHUB_WORKFLOW)" -d chat_id=$TELEGRAM_CHAT > /dev/null
echo -e "$blue***********************************************"
echo "        Compiling Fuse kernel for $DEVICE         "
echo -e "$blue***********************************************"
make ${DEVICE}_defconfig O=out
make O=out -j$(nproc) 2>&1 | tee build.log
grep "error:" build.log > error
if [ -e "out/arch/$ARCH/boot/Image" ]; then
kernel
else
echo -e "$red Kernel Compilation failed "
curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d text="Build failed" -d chat_id=$TELEGRAM_CHAT > /dev/null
curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage -d text="Here is the error:
$(<error)" -d chat_id=$TELEGRAM_CHAT > /dev/null
curl --data parse_mode=HTML --data chat_id=$TELEGRAM_CHAT --data sticker=CAADBQAD8gADLG6EE1T3chaNrvilFgQ --request POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker > /dev/null
exit 1
fi

enforcing
samsung_mtp
build
kernel_oneui

DEVICE=m30lte
generic_mtp
permissive
build
kernel

enforcing
samsung_mtp
build
kernel_oneui

DEVICE=a30
generic_mtp
permissive
build
kernel

enforcing
samsung_mtp
build
kernel_oneui

DEVICE=a40
generic_mtp
permissive
build
kernel

enforcing
samsung_mtp
build
kernel_oneui

# Make Flashable zip and Upload it
make_zip
upload

show_link
