BOARDNAME:=MIPS 74K
CPU_TYPE:=74kc
CPU_SUBTYPE:=dsp2

DEFAULT_PACKAGES += wpad-basic-wolfssl

define Target/Description
	Build firmware for Broadcom BCM47xx and BCM53xx devices with
	MIPS 74K CPU.
endef
