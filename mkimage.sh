#!/usr/bin/env bash
# Based on https://raw2.github.com/tmc/docker/master/contrib/mkimage-arch.sh

set -e

# Hack to make TTY a thing (https://github.com/dotcloud/docker/issues/728)
exec >/dev/tty 2>/dev/tty </dev/tty

# chdir to the script path
cd $(dirname "${BASH_SOURCE[0]}")

if [ ! -e /etc/pacman.d/gnupg ] ; then
    echo 'Generating pacman keys on build system'
    pacman-key --init &>/dev/null
    pacman-key --populate &>/dev/null
fi

echo 'Installing packages on build system'
pacman -Syu --noconfirm arch-install-scripts tar base-devel &>/dev/null
echo 'Bootstrap new root FS with packages'
rootfs=$(mktemp -d /build-XXXXXXXXXX)
pacstrap -c -d -G $rootfs pacman gzip &>/dev/null

echo 'Copy over pacman configuration'
cp /etc/pacman.conf $rootfs/etc/pacman.conf
cp /etc/pacman.d/mirrorlist $rootfs/etc/pacman.d/mirrorlist

echo 'Generate image pacman keys'
arch-chroot $rootfs pacman-key --init &>/dev/null
arch-chroot $rootfs pacman-key --populate &>/dev/null

echo 'Set timezone and locale'
ln -s /usr/share/zoneinfo/Etc/UTC $rootfs/etc/localtime
echo 'en_US.UTF-8 UTF-8' > $rootfs/etc/locale.gen
arch-chroot $rootfs locale-gen >/dev/null

echo 'Copy over skel configuration'
git clone git://github.com/fly/dotfiles /tmp/dotfiles &>/dev/null
(cd /tmp/dotfiles && make TARGET="$rootfs/etc/skel/" install &>/dev/null)

echo 'Install runit'
git clone git://github.com/akerl/runit /opt/runit &>/dev/null
(cd /opt/runit && ./package/compile &>/dev/null)
cp /opt/runit/command/* $rootfs/sbin/
mkdir $rootfs/etc/runit $rootfs/etc/sv $rootfs/service
cp /opt/runit/etc/debian/{1,2,3,ctrlaltdel} $rootfs/etc/runit/
ln -s /sbin/runit-init $rootfs/sbin/init

echo 'Populate /dev on new root FS'
dev=$rootfs/dev
rm -rf $dev
mkdir -p $dev
mknod -m 666 $dev/null c 1 3
mknod -m 666 $dev/zero c 1 5
mknod -m 666 $dev/random c 1 8
mknod -m 666 $dev/urandom c 1 9
mkdir -m 755 $dev/pts
mkdir -m 1777 $dev/shm
mknod -m 666 $dev/tty c 5 0
mknod -m 600 $dev/console c 5 1
mknod -m 666 $dev/tty0 c 4 0
mknod -m 666 $dev/full c 1 7
mknod -m 600 $dev/initctl p
mknod -m 666 $dev/ptmx c 5 2
ln -s /proc/self/fd/0 $dev/stdin
ln -s /proc/self/fd/1 $dev/stdout
ln -s /proc/self/fd/2 $dev/stderr
ln -s /proc/self/fd $dev/fd

echo 'Clean up some unneeded files'
rm -rf $rootfs/user/share/man/*
find $rootfs/usr/share/locale \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -not -name 'en_US' \
    -exec rm -r {} \;

echo 'Pack up the root FS'
rm -rf root.tar.xz
tar --numeric-owner -C $rootfs -cJf root.tar.xz .

