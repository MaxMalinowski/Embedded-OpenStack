# Guide for installing OpenStack on R-Car
All information in this document originates from different websites, guides and Google searches. 
If more indept knowledge can be found here for [yocto&rcar](https://elinux.org/R-Car/Boards/H3SK), [ubuntu&rcar](https://elinux.org/R-Car/Ubuntu) and [openstack&devstack](https://docs.openstack.org/devstack/latest/).
 
## Yocto and R-Car  
As the R-Car is an embedded SoC, it requires a custom OS and Kernel build with Yocto. For more information consult the webpage and the [Yocto Startup Guide](https://www.yoctoproject.org/docs/2.0/yocto-project-qs/yocto-project-qs.html). To prepare your host for building with Yocto.

    sudo apt-get install gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat libsdl1.2-dev xterm python-crypto cpio python python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping libssl-dev

Further, copy the *rcar_base* directory to place of your choice (or extract the zip). This directory contains all files necessary for a Yocto R-Car image. All following instructions will assume you are inside the *rcar_base*-directory. For starting the build, just run the *build.sh*-script and get some coffe.

    ./build.sh

### Kernel modification
If for some reason you wish to modify the futur kernel configuration you can do this also with Yocto. For that you should have executed the build script at least once, so that the /h3ulcb-directory is present. 

    cd h3ulcb
    . poky/oe-init-build-env build/
    cd build
    bitbake -c menuconfig virtual/kernel

Save and copy the configuration file, run the *build.sh*-script and get more coffe.

    bitbake -c savedefconfig virtual/kernel
    cp h3ulcb/build/tmp/work/h3ulcb-poky-linux/linux-renesas/5.4.0+gitAUTOINC+289de10299-r1/linux-h3ulcb-standard-build/defconfig h3ulcb/meta-renesas/meta-rcar-gen3/recipes-kernel/linux/


## SD-Card Preparation
Not all Yocto output are relevant. Copy the folling files to a separate directory, here denoted by *sources*.
 
    export SOURCES="~/Desktop/outputs"
    mkdir $SOURCES 

    cp h3ulcb/build/tmp/deploy/images/h3ulcb/Image $SOURCES
    cp h3ulcb/build/tmp/deploy/images/h3ulcb/r8a7795-h3ulcb.dtb $SOURCES
    cp h3ulcb/build/tmp/deploy/images/h3ulcb/modules-h3ulcb.tgz $SOURCES
    cp h3ulcb/build/tmp/deploy/images/h3ulcb/core-image-weston-h3ulcb.tar.bz2 $SOURCES
    wget http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-arm64.tar.gz -P $SOURCES

Depending on your build machine, if you don't have access to a USB or sd-card port, you have to copy (e.g. via scp) the just created and filled directory onto a different machine befor proceding.

After having access to the SD-Card, you first have to find out the card's name. The *dmesg*-command should show the insertion of a device called sda, sdb, sdc, ... . Using two environmental variables, the SD-Card can be followingly flashed.

    export CARD="sda"             # name of your sd-card discoverd with dmesg
    export SOURCES="~/outputs"    # directory containing all copied files

First we'll have to format the card and second partition the card. Using the interactive utility fdisk, the following inputs will take place in an interactive shell.

    sudo mkfs.ext4 /dev/${CARD}
    sudo fdisk /dev/${CARD} 
        -> n
        -> p
        -> 1
        -> 'enter'
        -> +2G
        -> n
        -> p
        -> 2
        -> 'enter'
        -> 'enter'
        -> 'Y'
        -> w

Third the new partitions have to be formated and all files can be copied and extracted onto the SD-Card.

    mkfs.ext4 /dev/${CARD}1
    mkfs.ext4 /dev/${CARD}2
    
    mount /dev/${CARD}1 /mnt
    tar -xvf $SOURCES/core-image-weston-h3ulcb.tar.bz2 -C /mnt
    tar -xvf $SOURCES/modules-h3ulcb.tgz -C /mnt
    rm /mnt/boot/*
    cp $SOURCES/Image $SOURCES/r8a7795-h3ulcb.dtb /mnt/boot/
    umount /mnt
    mount /dev/${CARD}2 /mnt
    tar -xvf $SOURCES/ubuntu-base-18.04.5-base-arm64.tar.gz -C /mnt
    tar -xvf $SOURCES/modules-h3ulcb.tgz  -C /mnt
    umount /mnt
    sync

## OS Configuration
Having prepared the sd-card, insert it into the R-Car, connect via the micro-usb port to the R-Car and stop the u-boot. More information on this procedure can be found [here](https://elinux.org/R-Car/Boards/H3SK#Connect_to_serial_console). 

Inside the u-boot, change the the boot source to be the sd-card. Change the *ip_address::gateway:netmask* according to your network configuration. The kernel should boot afterwards.

    setenv bootargs 'root=/dev/mmcblk1p1 rootwait rw ip=ip_address::gateway:netmask::eth0:off'
    setenv bootcmd 'ext4load mmc 0:1 0x48000000 /boot/r8a7795-h3ulcb.dtb; ext4load mmc 0:1 0x48080000 /boot/Image; booti 0x48080000 - 0x48000000'
    saveenv
    run bootcmd

After a successfull boot, login as root. First you have to set a timezone and the correct date in the Format MM(month) DD(day) HH(hour) MM(minute) YY(year). 

    export TZ=DE
    date 0101000821

Afterwards, load all kernel modules and mount the Ubuntu-partition as well as other stuff.

    cd /lib/modules/5.4.0-yocto-preempt-rt/
    depmod -a
    cd /
    mount /dev/mmcblk1p2 /mnt
    mount -t proc none /mnt/proc
    mount -t sysfs none /mnt/sys
    mount -t devtmpfs none /mnt/dev
    chroot /mnt /bin/bash
    echo "nameserver 8.8.4.4
    nameserver 8.8.8.8" > /etc/resolv.conf
    apt update && apt install -y apt-utils perl-modules iproute2 ubuntu-standard vim git net-tools ssh sudo tzdata rsyslog udev iputils-ping ifupdown kmod && apt upgrade -y

Next, the Ubuntu system can be configured. Change the relevant configuration (ip, netmask, gateway, hostname, nameserver) according to your needs.

    echo "auto eth0
    iface eth0 inet static
        address 1.2.3.4
        netmask 255.255.255.0
        gateway 1.2.3.1" >> /etc/network/interfaces
    echo "127.0.0.1 localhost.localdomain localhost rcar" > /etc/hosts
    echo "rcar" > /etc/hostname
    systemctl enable systemd-networkd
    cp /usr/share/systemd/tmp.mount /etc/systemd/system/tmp.mount
    systemctl enable tmp.mount
    systemctl enable systemd-resolved
    rm /etc/resolv.conf
    echo "nameserver 8.8.4.4
    nameserver 8.8.8.8" > /etc/resolv.conf>

Last a new user has to be created.

    useradd -s /bin/bash -d /home/rcar -m rcar
    usermod -aG sudo rcar
    passwd rcar

Now exit, unmount everything and reboot the system into u-boot.

    exit
    umount /mnt/proc
    umount /mnt/sys
    umount /mnt/dev
    umount /mnt
    reboot

Inside the u-boot, configure it to boot from the second partition.

    setenv bootargs 'root=/dev/mmcblk1p2 rootwait rw'
    saveenv
    run bootcmd

After a successfull boot you should be able to login with the previously created user and find yourself inside a familiar Ubuntu environemnt. Run the following commands and you are ready.

    sudo dpkg-reconfigure tzdata
    sudo apt-get install -y language-pack-en
    sudo update-locale LANG=en_US.UTF-8
    sudo reboot

# Install OpenStack
Installing OpenStack through DevStack can speedup and ease the installation process. First a user has to be created.

    useradd -s /bin/bash -d /opt/stack -m stack
    echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    passwd stack

Now, log out and log in as user stack again and clone the git repository.
   
   git clone https://opendev.org/openstack/devstack

From know on, the installation process varies depending on the node you performing it on. In this guide a controller node and a compute node is installed. The following configuration creates a multinode setup. If a different configuration is desired, consult the [DevStack Guides](https://docs.openstack.org/devstack/latest/guides.html). 

## Controller node
Edit the local.conf file inside the /devstack-directory. Adjust the necessary settings (ip addressed, passwords, interfaces) to fit your environment.

    echo '[[local|localrc]]
    PUBLIC_INTERFACE=eth0
    HOST_IP=192.168.2.200
    FLOATING_RANGE=192.168.2.0/24
    PUBLIC_NETWORK_GATEWAY=192.168.2.1
    Q_FLOATING_ALLOCATION_POOL=start=192.168.2.210,end=192.168.2.254

    LOGFILE=/opt/stack/logs/stack.sh.log

    ADMIN_PASSWORD=adminpass
    DATABASE_PASSWORD=adminpass
    RABBIT_PASSWORD=adminpass
    SERVICE_PASSWORD=adminpass' >> ~/devstack/local.conf

Start the OpenStack installation process and get a coffe.
    
    ~/devstack/stack.sh

## Compute node
Edit the local.conf file inside the /devstack-directory. Adjust the necessary settings (ip addressed, passwords, interfaces) to fit your environment.

    echo '[[local|localrc]]
    PUBLIC_INTERFACE=eth0
    HOST_IP=192.168.2.204
    FLOATING_RANGE=192.168.2.0/24
    PUBLIC_NETWORK_GATEWAY=192.168.2.1
    Q_FLOATING_ALLOCATION_POOL=start=192.168.2.210,end=192.168.2.254

    LOGFILE=/opt/stack/logs/stack.sh.log

    ADMIN_PASSWORD=adminpass
    DATABASE_PASSWORD=adminpass
    RABBIT_PASSWORD=adminpass
    SERVICE_PASSWORD=adminpass
    DATABASE_TYPE=mysql
    SERVICE_HOST=192.168.2.200
    MYSQL_HOST=$SERVICE_HOST
    RABBIT_HOST=$SERVICE_HOST
    GLANCE_HOSTPORT=$SERVICE_HOST:9292
    ENABLED_SERVICES=n-cpu,q-agt,c-vol,placement-client
    NOVA_VNC_ENABLED=True
    NOVNCPROXY_URL="http://$SERVICE_HOST:6080/vnc_lite.html"
    VNCSERVER_LISTEN=$HOST_IP
    VNCSERVER_PROXYCLIENT_ADDRESS=$VNCSERVER_LISTEN' >> ~/devstack/local.conf

Start the OpenStack installation process and get a coffe.
    
    ~/devstack/stack.sh