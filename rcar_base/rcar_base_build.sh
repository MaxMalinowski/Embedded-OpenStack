#!/bin/bash

# # # # # # # # # #
# Some initial configuration and env var settings
# # # # # # # # # #
TARGET_BOARD=h3ulcb
PROPRIETARY_DIR=`pwd`/proprietary
WORK=`pwd`/${TARGET_BOARD}

mkdir -p ${WORK}
cd ${WORK}

git config --global url."https://".insteadOf git://

# # # # # # # # # #
# Clone repos and checkout branches
# # # # # # # # # #
git clone https://git.yoctoproject.org/git/poky &
git clone https://github.com/openembedded/meta-openembedded.git &
git clone https://github.com/renesas-rcar/meta-renesas &
git clone https://git.yoctoproject.org/git/meta-virtualization &
wait

cd ${WORK}/poky
git checkout -b tmp 5e1f52edb7a9f790fb6cb5d96502f3690267c1b1
cd ${WORK}/meta-openembedded 
git checkout remotes/origin/zeus
cd ${WORK}/meta-renesas 
git checkout remotes/origin/zeus
cd ${WORK}/meta-virtualization 
git checkout remotes/origin/zeus

# # # # # # # # # #
# Setup build environment
# # # # # # # # # #
cd ${PROPRIETARY_DIR}
unzip -qo R-Car_Gen3_Series_Evaluation_Software_Package_for_Linux-20200910.zip
unzip -qo R-Car_Gen3_Series_Evaluation_Software_Package_of_Linux_Drivers-20200910.zip
cd ${WORK}/meta-renesas
sh meta-rcar-gen3/docs/sample/copyscript/copy_proprietary_softwares.sh -f ${PROPRIETARY_DIR}

cd ${WORK}
source poky/oe-init-build-env ${WORK}/build

cp ${WORK}/meta-renesas/meta-rcar-gen3/docs/sample/conf/${TARGET_BOARD}/poky-gcc/gfx-only/*.conf ./conf/



# # # # # # # # # #
# Edit configuration files
# # # # # # # # # #
cd ${WORK}/build
cp conf/local-wayland.conf conf/local.conf
cp -r ${WORK}/../help/arm-trusted-firmware/ ${WORK}/meta-renesas/meta-rcar-gen3/recipes-bsp/
cp -r ${WORK}/../help/linux/ ${WORK}/meta-renesas/meta-rcar-gen3/recipes-kernel/

echo 'BBLAYERS_append = " ${TOPDIR}/../meta-virtualization"' >> ${WORK}/build/conf/bblayers.conf
echo 'BBLAYERS_append = " ${TOPDIR}/../meta-openembedded/meta-filesystems"' >> ${WORK}/build/conf/bblayers.conf
echo 'BBLAYERS_append = " ${TOPDIR}/../meta-openembedded/meta-networking"' >> ${WORK}/build/conf/bblayers.conf
echo 'BBLAYERS_append = " ${TOPDIR}/../meta-openembedded/meta-webserver"' >> ${WORK}/build/conf/bblayers.conf

echo 'DISTRO_FEATURES_append = " virtualization kvm"' >> ${WORK}/build/conf/local.conf
echo 'DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"' >> ${WORK}/build/conf/local.conf
echo 'VIRTUAL-RUNTIME_initscripts = "systemd-compat-units"' >> ${WORK}/build/conf/local.con

# # # # # # # # # #
# Bake the image
# # # # # # # # # #
bitbake core-image-weston
