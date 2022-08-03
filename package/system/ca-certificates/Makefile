#
# Copyright (C) 2006-2017 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
DL_MKDIR:=1

PKG_NAME:=ca-certificates
PKG_VERSION:=103.0.1

include $(TOPDIR)/rules.mk

PKG_VERSION_URL:=$(word 1,$(subst ., ,$(PKG_VERSION)))_$(word 2,$(subst ., ,$(PKG_VERSION)))_$(word 3,$(subst ., ,$(PKG_VERSION)))
PKG_RELEASE:=1
PKG_MAINTAINER:=

PKG_SOURCE:=certdata.txt
PKG_SOURCE_URL:=https://hg.mozilla.org/releases/mozilla-release/raw-file/FIREFOX_$(PKG_VERSION_URL)_RELEASE/security/nss/lib/ckfw/builtins
PKG_HASH:=9bf3799611fb58197f61d45e71ce3dc19f30e7dd73731915872ce5108a7bb066
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

PKG_SOURCE_DIR:=$(PKG_BUILD_DIR)
PKG_BUILD_DIR:=$(PKG_SOURCE_DIR)/build

define Package/ca-certificates
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=System CA certificates
  PKGARCH:=all
  PROVIDES:=ca-certs
endef

define Package/ca-bundle
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=System CA certificates as a bundle
  PKGARCH:=all
  PROVIDES:=ca-certs
endef

define Build/Prepare
	$(CP) $(DL_DIR)/$(PKG_SOURCE) $(PKG_SOURCE_DIR)
	$(CP) ./files/* $(PKG_SOURCE_DIR)
endef

define Build/Configure
endef

define Build/Compile
	( \
		cd $(PKG_BUILD_DIR); \
		$(STAGING_DIR_HOST)/bin/python3 \
			$(SCRIPT_DIR)/certdata2pem.py \
			$(PKG_SOURCE_DIR)/$(PKG_SOURCE) \
			$(PKG_SOURCE_DIR)/blacklist.txt \
		; \
	)
endef

define Build/Install
	mkdir -p \
		$(PKG_INSTALL_DIR)/usr/sbin \
		$(PKG_INSTALL_DIR)/usr/share/ca-certificates
	$(INSTALL_BIN) $(PKG_SOURCE_DIR)/update-ca-certificates $(PKG_INSTALL_DIR)/usr/sbin
	for p in $(PKG_BUILD_DIR)/*.crt; do \
		$(INSTALL_DATA) $$$$p $(PKG_INSTALL_DIR)/usr/share/ca-certificates ; \
	done
endef

define Package/ca-certificates/install
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	$(INSTALL_DATA) $(PKG_INSTALL_DIR)/usr/share/ca-certificates/*.crt $(1)/etc/ssl/certs/

	for CERTFILE in `ls -1 $(1)/etc/ssl/certs`; do \
		HASH=`openssl x509 -hash -noout -in $(1)/etc/ssl/certs/$$$$CERTFILE` ; \
		SUFFIX=0 ; \
		while [ -h "$(1)/etc/ssl/certs/$$$$HASH.$$$$SUFFIX" ]; do \
			let "SUFFIX += 1" ; \
		done ; \
		$(LN) "$$$$CERTFILE" "$(1)/etc/ssl/certs/$$$$HASH.$$$$SUFFIX" ; \
	done
endef

define Package/ca-bundle/install
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	cat $(PKG_INSTALL_DIR)/usr/share/ca-certificates/*.crt >$(1)/etc/ssl/certs/ca-certificates.crt
	$(LN) /etc/ssl/certs/ca-certificates.crt $(1)/etc/ssl/cert.pem
endef

$(eval $(call BuildPackage,ca-bundle))
$(eval $(call BuildPackage,ca-certificates))
