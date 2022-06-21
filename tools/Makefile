#
# Copyright (C) 2006-2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Main makefile for the host tools
#
curdir:=tools

# subdirectories to descend into
tools-y :=

ifeq ($(CONFIG_EXTERNAL_TOOLCHAIN),)
  BUILD_TOOLCHAIN := y
  ifdef CONFIG_GCC_USE_GRAPHITE
    BUILD_ISL := y
  endif
endif
ifneq ($(CONFIG_SDK)$(CONFIG_PACKAGE_kmod-b43)$(CONFIG_PACKAGE_b43legacy-firmware)$(CONFIG_BRCMSMAC_USE_FW_FROM_WL),)
  BUILD_B43_TOOLS := y
endif

tools-y += autoconf-archive bc bison cmake cpio dosfstools
tools-y += e2fsprogs fakeroot findutils firmware-utils flex
tools-y += gengetopt libressl libtool lzma
tools-y += make-ext4fs missing-macros mkimage mklibs mtd-utils mtools
tools-y += padjffs2 patch-image patchelf quilt
tools-y += squashfskit4 sstrip xxd zip zlib zstd
tools-$(BUILD_B43_TOOLS) += b43-tools
tools-$(BUILD_ISL) += isl
tools-$(BUILD_TOOLCHAIN) += expat gmp mpc mpfr
tools-$(CONFIG_TARGET_apm821xx)$(CONFIG_TARGET_gemini) += genext2fs
tools-$(CONFIG_TARGET_ath79) += lzma-old squashfs
tools-$(CONFIG_TARGET_mxs) += elftosb sdimage
tools-$(CONFIG_TARGET_tegra) += cbootimage cbootimage-configs
tools-$(CONFIG_TARGET_x86) += glib2 qemu-utils
tools-$(CONFIG_USES_MINOR) += kernel2minor
tools-$(CONFIG_USE_SPARSE) += sparse
tools-$(CONFIG_USE_LLVM_BUILD) += llvm-bpf

# builddir dependencies
$(curdir)/autoconf-archive/compile :=
$(curdir)/cbootimage/compile :=
$(curdir)/cbootimage-configs/compile :=
$(curdir)/cpio/compile :=
$(curdir)/dosfstools/compile :=
$(curdir)/elftosb/compile :=
$(curdir)/genext2fs/compile :=
$(curdir)/kernel2minor/compile :=
$(curdir)/libressl/compile :=
$(curdir)/lzma/compile :=
$(curdir)/mtools/compile :=
$(curdir)/patch-image/compile :=
$(curdir)/sdimage/compile :=
$(curdir)/sparse/compile :=
$(curdir)/sstrip/compile :=
$(curdir)/xxd/compile :=
$(curdir)/zip/compile :=
$(curdir)/zstd/compile :=

$(curdir)/b43-tools/compile := $(curdir)/bison/compile
$(curdir)/bc/compile := $(curdir)/bison/compile
$(curdir)/bison/compile := $(curdir)/flex/compile
$(curdir)/cmake/compile := $(curdir)/libressl/compile
$(curdir)/expat/compile := $(curdir)/cmake/compile
$(curdir)/e2fsprogs/compile := $(curdir)/libtool/compile
$(curdir)/fakeroot/compile := $(curdir)/libtool/compile
$(curdir)/findutils/compile := $(curdir)/bison/compile
$(curdir)/firmware-utils/compile := $(curdir)/zlib/compile
$(curdir)/flex/compile := $(curdir)/libtool/compile
$(curdir)/gengetopt/compile := $(curdir)/libtool/compile
$(curdir)/glib2/compile := $(curdir)/zlib/compile
$(curdir)/gmp/compile := $(curdir)/libtool/compile
$(curdir)/isl/compile := $(curdir)/gmp/compile
$(curdir)/libtool/compile := $(curdir)/missing-macros/compile
$(curdir)/lzma-old/compile := $(curdir)/zlib/compile
$(curdir)/llvm-bpf/compile := $(curdir)/cmake/compile
$(curdir)/make-ext4fs/compile := $(curdir)/zlib/compile
$(curdir)/missing-macros/compile := $(curdir)/autoconf-archive/compile
$(curdir)/mkimage/compile := $(curdir)/bison/compile $(curdir)/libressl/compile
$(curdir)/mklibs/compile := $(curdir)/libtool/compile
$(curdir)/mpc/compile := $(curdir)/mpfr/compile
$(curdir)/mpfr/compile := $(curdir)/gmp/compile
$(curdir)/mtd-utils/compile := $(curdir)/e2fsprogs/compile $(curdir)/zlib/compile
$(curdir)/padjffs2/compile := $(curdir)/findutils/compile
$(curdir)/patchelf/compile := $(curdir)/libtool/compile
$(curdir)/qemu-utils/compile := $(curdir)/glib2/compile $(curdir)/zstd/compile
$(curdir)/quilt/compile := $(curdir)/findutils/compile
$(curdir)/sdcc/compile := $(curdir)/bison/compile
$(curdir)/squashfs/compile := $(curdir)/lzma-old/compile
$(curdir)/squashfskit4/compile := $(curdir)/zlib/compile
$(curdir)/zlib/compile := $(curdir)/cmake/compile

ifneq ($(HOST_OS),Linux)
  $(curdir)/squashfskit4/compile += $(curdir)/coreutils/compile
  tools-y += coreutils
endif

ifeq ($(HOST_OS),Darwin)
  tools-y += bash
else
  $(curdir)/dwarves/compile += $(curdir)/elfutils/compile
  $(curdir)/elfutils/compile += $(curdir)/zlib/compile
  tools-$(CONFIG_DWARVES) += dwarves
  tools-y += elfutils
endif

# if ccache is used, all tools rely on it
# except those it depends on
ifneq ($(CONFIG_CCACHE)$(CONFIG_SDK),)
$(foreach tool, $(filter-out libressl cmake zstd,$(tools-y)), \
	$(eval $(curdir)/$(tool)/compile += $(curdir)/ccache/compile) \
)
$(curdir)/ccache/compile += $(curdir)/libressl/compile $(curdir)/cmake/compile $(curdir)/zstd/compile
tools-y += ccache
endif

# let all tools depend on core-tools (archives, build systems)
# but all tools should depend on xz, sed, except themselves
tools-core := sed xz tar ninja meson automake autoconf pkgconf m4
$(foreach tool, $(filter-out $(tools-core),$(tools-y)), \
	$(eval $(curdir)/$(tool)/compile += $(patsubst %,$(curdir)/%/compile,$(tools-core))) \
)
$(foreach tool, $(filter-out sed xz,$(tools-core)), \
	$(eval $(curdir)/$(tool)/compile += $(curdir)/sed/compile) \
)

# static dependencies between core-tools
$(curdir)/tar/compile := $(curdir)/automake/compile
$(curdir)/automake/compile := $(curdir)/autoconf/compile $(curdir)/pkgconf/compile
$(curdir)/autoconf/compile := $(curdir)/m4/compile
$(curdir)/pkgconf/compile := $(curdir)/meson/compile
$(curdir)/meson/compile := $(curdir)/ninja/compile
$(curdir)/sed/compile := $(curdir)/xz/compile
tools-y += $(tools-core)

# let all tools with patches directory depend on host-build of patch, except core-tools
# host machine patch handles the patches for the rest
$(foreach tool, $(filter-out $(tools-core),$(tools-y)), \
	$(if $(wildcard $(curdir)/$(tool)/patches), \
		$(eval $(curdir)/$(tool)/compile += $(curdir)/patch/compile) \
	) \
)
$(curdir)/patch/compile := $(curdir)/automake/compile
tools-y += patch

# tools that can be built without any build preparation
# and with no other tools as prerequisites
# good for single C file programs
tools-simple := mkhash flock

$(curdir)/autoremove := 1
$(curdir)/builddirs := $(tools-y) $(tools-dep) $(tools-) $(tools-simple)
$(curdir)/builddirs-default := $(tools-y)

ifdef CHECK_ALL
$(curdir)/builddirs-check:=$($(curdir)/builddirs)
$(curdir)/builddirs-download:=$($(curdir)/builddirs)
endif

ifndef DUMP_TARGET_DB
define PrepareStaging
	$(Q)for dir in $(1); do ( \
		$(if $(Q),,set -x;) \
		mkdir -p "$$dir"; \
		cd "$$dir"; \
		mkdir -p bin lib stamp usr/include usr/lib; \
	); done
endef

$(BIN_DIR):
	mkdir -p $@

# preparatory work
$(STAGING_DIR)/.prepared: $(TMP_DIR)/.build
	$(call PrepareStaging,$(STAGING_DIR))
	mkdir -p $(BUILD_DIR)/stamp
	touch $@

$(STAGING_DIR_HOST)/.prepared: $(TMP_DIR)/.build
	$(call PrepareStaging,$(STAGING_DIR_HOST))
	mkdir -p $(BUILD_DIR_HOST)/stamp $(STAGING_DIR_HOST)/include/sys
	$(INSTALL_DATA) $(TOPDIR)/tools/include/*.h $(STAGING_DIR_HOST)/include/
	$(INSTALL_DATA) $(TOPDIR)/tools/include/sys/*.h $(STAGING_DIR_HOST)/include/sys/
ifneq ($(HOST_OS),Linux)
	mkdir -p $(STAGING_DIR_HOST)/include/asm
	$(INSTALL_DATA) $(TOPDIR)/tools/include/asm/*.h $(STAGING_DIR_HOST)/include/asm/
endif
	ln -snf lib $(STAGING_DIR_HOST)/lib64
	touch $@

endif

# prerequisites for individual targets
$(foreach tool, $(tools-y), \
	$(eval $(curdir)/$(tool)/prepare += $(STAGING_DIR)/.prepared $(STAGING_DIR_HOST)/.prepared $(BIN_DIR)) \
	$(eval $(curdir)/$(tool)/compile += $(STAGING_DIR)/.prepared $(STAGING_DIR_HOST)/.prepared $(BIN_DIR)) \
)

$(curdir)/install: $(curdir)/compile

# prerequisites for all targets
$(curdir)/ := .config prereq

tools_enabled = $(foreach tool,$(sort $(tools-y) $(tools-)),$(if $(filter $(tool),$(tools-y)),y,n))
$(eval $(call stampfile,$(curdir),tools,compile,,_$(subst $(space),,$(tools_enabled)),$(STAGING_DIR_HOST)))
$(eval $(call stampfile,$(curdir),tools,check,$(TMP_DIR)/.build,,$(STAGING_DIR_HOST)))
$(eval $(call subdir,$(curdir)))
