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

	macaddr_canonicalize $(hexdump -v -s "$offset" -n "$length" -e '6/1 "%02x"' "$path" 2>/dev/null)
}

get_mac_label_dt() {
	local basepath="/proc/device-tree"
	local macdevice mac

	macdevice=$(cat "$basepath/aliases/label-mac-device" 2>/dev/null)
	[ -n "$macdevice" ] || return

	mac=$(get_mac_binary "$basepath/$macdevice/mac-address" 2>/dev/null)
	[ -n "$mac" ] &&
		printf '%s' "$mac" ||
		printf '%s' $(get_mac_binary "$basepath/$macdevice/local-mac-address" 2>/dev/null)
}

get_mac_label_json() {
	local cfg="/etc/board.json"
	local mac

	[ -s "$cfg" ] || return

	. /usr/share/libubox/jshn.sh

	json_init
	json_load_file "$cfg"

	if json_is_a system object; then
		json_select system
			json_get_var mac label_macaddr
		json_select ..
	fi

	printf '%s' "$mac"
}

get_mac_label() {
	local mac

	mac=$(get_mac_label_dt)
	[ -n "$mac" ] &&
		printf '%s' "$mac" ||
		printf '%s' "$(get_mac_label_json)"
}

find_mtd_chardev() {
	local mtdname="$1"
	local prefix index

	index=$(find_mtd_index "$mtdname")
	[ -d /dev/mtd ] && prefix="/dev/mtd/" || prefix="/dev/mtd"

	printf '%s' "${index:+${prefix}${index}}"
}

mtd_get_mac_ascii() {
	local mtdname="$1"
	local key="$2"
	local cmd="$3"
	local part keys var mac

	part=$(find_mtd_part "$mtdname")
	if [ -z "$part" ]; then
		echo "mtd_get_mac_ascii: partition $mtdname not found!" >&2
		return
	fi

	[ -z "$cmd" ] &&
		case "$mtdname" in
			 "u"*"boot"*"env"*) cmd="tail -c +5" ;;
					 *) cmd="cat" ;;
		esac

	keys=$($cmd "$part" | strings -n 12 -)

	for var in $keys; do
		case "$var" in
			 "$key"*) mac="$var"; break ;;
			*"$key"*) mac="$var"; continue ;;
		esac
	done

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

	[ $((offset + length)) -le $(mtd_get_part_size "$mtdname") ] || return

	macaddr_canonicalize $(dd bs=1 if="$part" skip="$offset" count="$length")
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
			*"$mtdname"*) printf '%d' $((0x${size})); break ;;
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
	local oui="${mac%:*:*:*}"
	local nic="${mac#*:*:*:}"

	macaddr_canonicalize $(printf '%s%06x' "$oui" $(((0x${nic//$delimiter/} + val) & 0xffffff)))
}

macaddr_octet() {
	local mac="$1"
	local off="${2:-3}"
	local len="${3:-3}"
	local sep="$4"
	local oct=""

	while [ "$off" -ne 0 ]; do
		mac="${mac#*$delimiter}"
		off=$((off - 1))
	done

	while [ "$len" -ne 0 ]; do
		oct="${oct}${oct:+$sep}${mac%%$delimiter*}"
		mac="${mac#*$delimiter}"
		len=$((len - 1))
	done

	printf '%s' "$oct"
}

macaddr_setbit() {
	local hex="${1//$delimiter/}"
	local bit="${2:-0}"

	[ "$bit" -ge 1 ] && [ "$bit" -le 48 ] || return

	macaddr_canonicalize $(printf '%012x' $((0x${hex} | (2 ** ((${#hex} * 4) - bit)))))
}

macaddr_unsetbit() {
	local hex="${1//$delimiter/}"
	local bit="${2:-0}"

	[ "$bit" -ge 1 ] && [ "$bit" -le 48 ] || return

	macaddr_canonicalize $(printf '%012x' $((0x${hex} &~(2 ** ((${#hex} * 4) - bit)))))
}

macaddr_setbit_la() {
	macaddr_setbit "$@" 7
}

macaddr_unsetbit_mc() {
	macaddr_unsetbit "$@" 8
}

macaddr_random() {
	macaddr_unsetbit_mc $(macaddr_setbit_la $(get_mac_binary "/dev/urandom"))
}

macaddr_2bin() {
	printf '%b' "\\x${@//$delimiter/\\x}"
}

macaddr_split() {
	local sub="$1"
	local mod="${2:-2}"
	local mac

	[ $((${#sub} % mod)) -eq 1 ] &&
		mac="${sub%${sub#?}}" &&
		sub="${sub#?}"

	while [ "${#sub}" -ge 2 ]; do
		mac="${mac}${mac:+ }${sub%${sub#??}}"
		sub="${sub#??}"
	done

	printf '%s' "$mac"
}

macaddr_canonicalize() {
	local mac="$@"
	local hex octet octets canon wc

	mac="${mac//[![:xdigit:][:punct:]]/}"
	mac="${mac//$blockchar/}"
	mac="${mac//$operators/}"
	hex="${mac//$delimiter/}"

	[ "${#hex}" -ge 6 ] || return
	[ "${#hex}" -gt 12 ] && mac="${hex:0:12}"

	for octet in ${mac//$delimiter/ }; do
		[ "${#octet}" -le 2 ] || octet=$(macaddr_split "$octet")
		octets="${octets}${octets:+ }${octet}"
	done

	for octet in $octets; do
		canon="${canon}${canon:+ }0x${octet}"
		wc=$((wc + 1))
	done

	[ "$wc" -eq 6 ] || return

	printf '%02x:%02x:%02x:%02x:%02x:%02x' $canon
}
