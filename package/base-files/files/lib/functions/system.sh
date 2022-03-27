# Copyright (C) 2006-2013 OpenWrt.org

. /lib/functions.sh

get_mac_binary() {
	local path="$1"
	local offset="${2:-0}"
	local length="${3:-6}"

	if ! [ -e "$path" ]; then
		echo "get_mac_binary: file $path not found!" >&2
		return
	fi

	open_fd_rw_ro 3 4

	hexdump -v -s "$offset" -n "$length" -e '6/1 "%02x"' "$path" >&3
		close_fd 3
	read -u 4 MAC
		close_fd 4

	macaddr_canonicalize
}

get_mac_label_dt() {
	local basepath="/proc/device-tree"
	local macdevice

	open_fd_rw_ro 3 4

	cat "$basepath/aliases/label-mac-device" 2>/dev/null >&3
		close_fd 3
	read -u 4 macdevice
		close_fd 4

	[ -n "$macdevice" ] || return

	get_mac_binary "$basepath/$macdevice/mac-address" 2>/dev/null >/dev/null
	[ -n "$MAC" ] &&
		printf '%s' "$MAC" ||
		get_mac_binary "$basepath/$macdevice/local-mac-address" 2>/dev/null
}

get_mac_label_json() {
	local cfg="/etc/board.json"

	[ -s "$cfg" ] || return

	. /usr/share/libubox/jshn.sh

	json_init
	json_load_file "$cfg"

	if json_is_a system object; then
		json_select system
			json_get_var MAC label_macaddr
		json_select ..
	fi

	printf '%s' "$MAC"
}

get_mac_label() {
	MAC=""

	get_mac_label_dt 2>/dev/null >/dev/null
	[ -n "$MAC" ] &&
		printf '%s' "$MAC" && return

	get_mac_label_json 2>/dev/null
}

find_mtd_chardev() {
	local mtdname="$1"
	local prefix index

	index=$(find_mtd_index "$mtdname")
	[ -d /dev/mtd ] && prefix="/dev/mtd/" || prefix="/dev/mtd"

	echo -n "${index:+${prefix}${index}}"
}

mtd_get_mac_ascii() {
	local mtdname="$1"
	local key="$2"
	local cmd="$3"
	local part var mac

	part=$(find_mtd_part "$mtdname")
	if [ -z "$part" ]; then
		echo "mtd_get_mac_ascii: partition $mtdname not found!" >&2
		return
	fi

	[ -z "$cmd" ] &&
		case "$mtdname" in
			"u"*"boot"*"env") cmd="tail -c +5" ;;
			*) cmd="cat" ;;
		esac

	mkdir -p "/tmp${part%/*}"
	$cmd "$part" > "/tmp${part}"

	open_fd_rw_ro 3 4

	strings -n 12 "/tmp${part}" >&3
		close_fd 3
		rm -rf "/tmp${part%/*}"

	while read -u 4 var; do
		case "$var" in
			"$key") mac="$var"; break ;;
			*"$key"*) mac="$var"; continue ;;
		esac
	done

	close_fd

	macaddr_canonicalize "${mac//$key/}"
}

mtd_get_mac_text() {
	local mtdname="$1"
	local offset=$((${2:-0}))
	local length="${3:-17}"
	local part

	part=$(find_mtd_part "$mtdname")
	if [ -z "$part" ]; then
		echo "mtd_get_mac_text: partition $mtdname not found!" >&2
		return
	fi

	open_fd_rw_ro 3 4

	dd bs=1 if="$part" skip="$offset" count="$length" 2>/dev/null >&3
		close_fd 3
	read -u 4 MAC
		close_fd 4

	macaddr_canonicalize
}

mtd_get_mac_binary() {
	local mtdname="$1"
	local offset="$2"
	local part

	part=$(find_mtd_part "$mtdname")
	get_mac_binary "$part" "$offset"
}

mtd_get_mac_binary_ubi() {
	local mtdname="$1"
	local offset="$2"
	local ubidev part

	. /lib/upgrade/nand.sh

	ubidev=$(nand_find_ubi "$CI_UBIPART")
	part=$(nand_find_volume "$ubidev" "$mtdname")
	get_mac_binary "/dev/$part" "$offset"
}

mtd_get_part_size() {
	local mtdname="$1"
	local dev size erasesize name

	while read dev size erasesize name; do
		case "$name" in
			*"$mtdname"*) echo -n $((0x${size})); break ;;
		esac
	done < /proc/mtd
}

mmc_get_mac_binary() {
	local part_name="$1"
	local offset="$2"
	local part

	part=$(find_mmc_part "$part_name")
	get_mac_binary "$part" "$offset"
}

macaddr_add() {
	local mac="$1"
	local val="${2:-1}"
	local oui nic

	[ -z "$mac" ] && [ -n "$MAC" ] && mac="$MAC"

	macaddr_octet "$mac" 0 >/dev/null; oui="$MAC"
	macaddr_octet "$mac" 3 >/dev/null; nic="$MAC"

	open_fd_rw_ro 5 6

	printf '%s%06x' "$oui" $(((0x${nic} + val) & 0xffffff)) >&5
		close_fd 5
	read -u 6 MAC
		close_fd 6

	macaddr_canonicalize
}

macaddr_octet() {
	local mac="$1"
	local off="${2:-3}"
	local len="${3:-3}"
	local sep="$4"
	local oct=""

	macaddr_canonicalize "$mac" >/dev/null; mac="$MAC"

	while [ "$off" -ne 0 ]; do
		mac="${mac#*$delimiter}"
		off=$((off - 1))
	done

	while [ "$len" -ne 0 ]; do
		oct="${oct}${oct:+$sep}${mac%%$delimiter*}"
		mac="${mac#*$delimiter}"
		len=$((len - 1))
	done

	open_fd_rw_ro 3 4

	printf '%s' "$oct" >&3
		close_fd 3
	read -u 4 MAC
		close_fd 4

	printf '%s' "$MAC"
}

macaddr_setbit() {
	local hex="${1//$delimiter/}"
	local bit="${2:-0}"

	[ "$bit" -ge 0 ] && [ "$bit" -le 47 ] || return

	open_fd_rw_ro 5 6

	printf '%012x' $((0x${hex} | (2**(((${#hex} * 4) - 1) - bit)))) >&5
		close_fd 5
	read -u 6 MAC
		close_fd 6

	macaddr_canonicalize
}

macaddr_unsetbit() {
	local hex="${1//$delimiter/}"
	local bit="${2:-0}"

	[ "$bit" -ge 0 ] && [ "$bit" -le 47 ] || return

	open_fd_rw_ro 5 6

	printf '%012x' $((0x${hex} &~(2**(((${#hex} * 4) - 1) - bit)))) >&5
		close_fd 5
	read -u 6 MAC
		close_fd 6

	macaddr_canonicalize
}

macaddr_setbit_la() {
	macaddr_setbit "$1" 6
}

macaddr_unsetbit_mc() {
	macaddr_unsetbit "$1" 7
}

macaddr_random() {
	local randmac

	get_mac_binary "/dev/urandom" >/dev/null
	macaddr_unsetbit_mc "$MAC" >/dev/null
	macaddr_setbit_la "$MAC"
}

macaddr_2bin() {
	local mac="$1"

	[ -z "$mac" ] && [ -n "$MAC" ] && mac="$MAC"

	macaddr_octet "$mac" 0 6 '\\x' >/dev/null

	printf '%b' "\\x${MAC}"
}

macaddr_split() {
	local sub="$1"
	local mac

	[ $((${#sub} % 2)) -eq 1 ] &&
		mac="${sub%${sub#?}}" &&
		sub="${sub#?}"

	while [ "${#sub}" -ge 2 ]; do
		mac="${mac}${mac:+ }${sub%${sub#??}}"
		sub="${sub#??}"
	done

	open_fd_rw_ro 5 6

	printf '%s' "$mac" >&5
		close_fd 5
	read -u 6 MAC
		close_fd 6

	printf '%s' "$MAC"
}

macaddr_canonicalize() {
	local mac="$1"
	local wc="0"
	local hex octet octets canon

	[ -z "$mac" ] && [ -n "$MAC" ] && mac="$MAC"

	mac="${mac//$blockchar/}"
	mac="${mac//$operators/}"
	hex="${mac//$delimiter/}"

	[ "${#hex}" -ge 6 ] && [ -z "${hex//[[:xdigit:]]/}" ] || return
	[ "${#hex}" -gt 12 ] && mac="${hex:0:12}"

	for octet in ${mac//$delimiter/ }; do
		macaddr_split "${octet}" >/dev/null
		octets="${octets}${octets:+ }${MAC}"
	done

	for octet in $octets; do
		canon="${canon}${canon:+ }0x${octet}"
		wc=$((wc + 1))
	done

	[ "$wc" -eq 6 ] || return

	open_fd_rw_ro 7 8

	printf '%02x:%02x:%02x:%02x:%02x:%02x' $canon >&7
		close_fd 7
	read -u 8 MAC
		close_fd 8

	printf '%s' "$MAC"
}
