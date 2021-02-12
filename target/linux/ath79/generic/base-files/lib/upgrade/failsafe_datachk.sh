# U-Boot with the datachk patchset requires image sizes, offsets,
# and checksums to be provided in the U-Boot environment.
# This script is based on the dualboot version for devices that come with 2 OS partitions.
# For Senao boards with a "failsafe" partition image, the process is almost the same.
# Instead of booting a secondary instalation on checksum failure,
# the failsafe image is booted instead.
# These boards also use the OKLI lzma kernel loader and mtd-concat
# So the kernel check is for the loader, the rootfs check is for kernel + rootfs

platform_do_upgrade_failsafe_datachk() {
	local backup
	local setenv_script="/tmp/fw_env_upgrade"

	local flash_start=0x9f000000
	local kernel_mtd="$(find_mtd_index loader)"
	local rootfs_mtd="$(find_mtd_index fwconcat0)"
	local kernel_offset="$(cat /sys/class/mtd/mtd${kernel_mtd}/offset)"
	local rootfs_offset="$(cat /sys/class/mtd/mtd${rootfs_mtd}/offset)"

	tar xzf $1 || {
		echo "failed to unpack sysupgrade.bin"
		return 1
	}

	local kernel_length=$(cat *-uImage-lzma.bin | wc -c)
	local rootfs_length=$(cat *-root.squashfs | wc -c)

	# rootfs without JFFS2 marker
	rootfs_length=$((rootfs_length-4))

	local kernel_md5=$(cat *-uImage-lzma.bin | md5sum)
	local rootfs_md5=$(cat *-root.squashfs | dd bs=1 count=$rootfs_length | md5sum)

	kernel_md5="${kernel_md5%% *}"
	rootfs_md5="${rootfs_md5%% *}"

	mtd -q erase loader
	mtd -q erase firmware

	# take care of restoring a saved config
	[ -n "$UPGRADE_BACKUP" ] && backup="${MTD_CONFIG_ARGS} -j ${UPGRADE_BACKUP}"

	cat *-uImage-lzma.bin | mtd -n write - loader
	cat *-root.squashfs | mtd -n $backup write - fwconcat0

	# prepare new u-boot env
	printf "vmlinux_start_addr 0x%08x\n" $((flash_start + kernel_offset)) >> $setenv_script
	printf "vmlinux_size 0x%08x\n" ${kernel_length} >> $setenv_script
	printf "vmlinux_checksum %s\n" ${kernel_md5} >> $setenv_script

	printf "rootfs_start_addr 0x%08x\n" $((flash_start + rootfs_offset)) >> $setenv_script
	printf "rootfs_size 0x%08x\n" ${rootfs_length} >> $setenv_script
	printf "rootfs_checksum %s\n" ${rootfs_md5} >> $setenv_script

	# store u-boot env changes
	mkdir -p /var/lock
	fw_setenv -s $setenv_script || {
		echo "failed to update U-Boot environment"
	}
}
