# qemu-edid, qemu-img, qemu-io, qemu-nbd, qemu-pr-helper, qemu-storage-daemon
include $(TOPDIR)/rules.mk

PKG_NAME:=qemu-utils
PKG_VERSION:=6.2.0

PKG_SOURCE:=qemu-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://download.qemu.org
PKG_HASH:=68e15d8e45ac56326e0b9a4afa8b49a3dfe8aba3488221d098c84698bca65b45

PKG_LICENSE:=GPL-2.0-only
PKG_LICENSE_FILES:=COPYING LICENSE tcg/LICENSE
PKG_CPE_ID:=cpe:/a:qemu:qemu

HOST_BUILD_DIR:=$(BUILD_DIR_HOST)/qemu-$(PKG_VERSION)/openwrt-build
HOST_SOURCE_DIR:=$(BUILD_DIR_HOST)/qemu-$(PKG_VERSION)

include $(INCLUDE_DIR)/host-build.mk

HOST_CONFIGURE_CMD = ../configure

HOST_CONFIGURE_VARS += \
	EXTRA_CFLAGS="$(HOST_CFLAGS)" \
	EXTRA_CXXFLAGS="$(HOST_CFLAGS)"

HOST_CONFIGURE_ARGS := \
	--cc="$(HOSTCC_NOCACHE)" \
	--host-cc="$(HOSTCC_NOCACHE)" \
	--objcc="$(HOSTCC_NOCACHE)" \
	--cxx="$(HOSTCXX_NOCACHE)" \
	--cpu="$(HOST_ARCH)" \
	--prefix="$(STAGING_DIR_HOST)" \
	--make="$(STAGING_DIR_HOST)/bin/make" \
	--with-git="$(STAGING_DIR_HOST)/bin/git" \
	--ninja="$(STAGING_DIR_HOST)/bin/ninja" \
	--meson="$(STAGING_DIR_HOST)/bin/meson.py" \
	--extra-cflags="-Wall" \
	--without-default-devices \
	--disable-modules \
	--disable-slirp \
	--disable-tcg \
	--disable-system \
	--disable-user \
	--disable-werror \
	--disable-plugins \
	--disable-blobs \
	--disable-capstone \
	--disable-guest-agent \
	--disable-numa \
	--disable-tpm \
	--disable-vhost-net \
	--disable-vhost-vsock \
	--disable-vhost-scsi \
	--disable-vhost-crypto \
	--disable-vhost-kernel \
	--disable-vhost-user \
	--disable-vhost-vdpa \
	--enable-debug \
	--enable-tools \
	--enable-bochs \
	--enable-bzip2 \
	--enable-cloop \
	--enable-dmg \
	--enable-parallels \
	--enable-qcow1 \
	--enable-qed \
	--enable-vdi \
	--enable-vvfat \
	--enable-lzo \
	--enable-zstd \
	--enable-gio \
	--static

$(eval $(call HostBuild))
