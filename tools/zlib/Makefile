#
# Copyright (C) 2006-2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=zlib
PKG_VERSION:=1.2.12
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/madler/zlib/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=d8688496ea40fb61787500e863cc63c9afcbc524468cedeb478068924eb54932

PKG_LICENSE:=Zlib
PKG_LICENSE_FILES:=README
PKG_CPE_ID:=cpe:/a:gnu:zlib

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/cmake.mk

HOST_CFLAGS +=-fPIC

define Host/Install
	$(CP) $(HOST_BUILD_DIR)/libz.a $(STAGING_DIR_HOST)/lib/
	$(CP) $(HOST_BUILD_DIR)/zconf.h $(STAGING_DIR_HOST)/include/
	$(CP) $(HOST_BUILD_DIR)/zlib.h $(STAGING_DIR_HOST)/include/
	$(CP) $(HOST_BUILD_DIR)/zlib.pc $(STAGING_DIR_HOST)/lib/pkgconfig/
endef

define Host/Clean
	rm -f $(STAGING_DIR_HOST)/lib/libz.a
	rm -f $(STAGING_DIR_HOST)/include/zconf.h
	rm -f $(STAGING_DIR_HOST)/include/zlib.h
	rm -f $(STAGING_DIR_HOST)/lib/pkgconfig//zlib.pc
endef

$(eval $(call HostBuild))
