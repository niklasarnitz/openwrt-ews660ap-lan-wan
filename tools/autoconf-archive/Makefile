include $(TOPDIR)/rules.mk

PKG_NAME:=autoconf-archive
PKG_VERSION:=2022.09.03

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=@GNU/autoconf-archive
PKG_HASH:=e07454f00d8cae7907bed42d0747798927809947684d94c37207a4d63a32f423

include $(INCLUDE_DIR)/host-build.mk

HOST_CONFIGURE_ARGS += \
	--datarootdir=$(STAGING_DIR_HOST)/share

define Host/Compile
	export SHELL="$(BASH)"; $(MAKE) -C $(HOST_BUILD_DIR)
endef

define Host/Install
	export SHELL="$(BASH)"; $(MAKE) -C $(HOST_BUILD_DIR) install
endef

define Host/Clean
	-export SHELL="$(BASH)"; $(MAKE) -C $(HOST_BUILD_DIR) uninstall
	$(call Host/Clean/Default)
endef

$(eval $(call HostBuild))
