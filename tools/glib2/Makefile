#
# Copyright (C) 2007-2019 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=glib2
PKG_VERSION:=2.72.2
PKG_VERSION_MAJOR:=$(word 1,$(subst ., ,$(PKG_VERSION))).$(word 2,$(subst ., ,$(PKG_VERSION)))
PKG_RELEASE:=1

PKG_SOURCE:=glib-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=@GNOME/glib/$(PKG_VERSION_MAJOR)
PKG_HASH:=78d599a133dba7fe2036dfa8db8fb6131ab9642783fc9578b07a20995252d2de

PKG_LICENSE:=LGPL-2.1-or-later
PKG_LICENSE_FILES:=COPYING
PKG_CPE_ID:=cpe:/a:gnome:glib

HOST_BUILD_DIR:=$(BUILD_DIR_HOST)/glib-$(PKG_VERSION)

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/meson.mk

HOSTCC:=$(HOSTCC_NOCACHE)
HOSTCXX:=$(HOSTCXX_NOCACHE)

MESON_HOST_ARGS := \
	--default-library static \
	--force-fallback-for libffi,libpcre \
	-Dxattr=false \
	-Dtests=false \
	-Dinstalled_tests=true \
	-Dnls=disabled \
	-Dglib_debug=disabled \
	-Dglib_assert=false \
	-Dglib_checks=true

$(eval $(call HostBuild))
