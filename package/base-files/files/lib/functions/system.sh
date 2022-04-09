# Copyright (C) 2006-2013 OpenWrt.org

. /lib/functions.sh
. /usr/share/libubox/jshn.sh

get_mac_binary() {
	local path="$1"
	local offset="$2"

	if ! [ -e "$path" ]; then
		echo "get_mac_binary: file $path not found!" >&2
		return
	fi

	hexdump -v -n 6 -s $offset -e '5/1 "%02x:" 1/1 "%02x"' $path 2>/dev/null
}

get_mac_label_dt() {
	local basepath="/proc/device-tree"
	local macdevice="$(cat "$basepath/aliases/label-mac-device" 2>/dev/null)"
	local macaddr

	[ -n "$macdevice" ] || return

	macaddr=$(get_mac_binary "$basepath/$macdevice/mac-address" 0 2>/dev/null)
	[ -n "$macaddr" ] || macaddr=$(get_mac_binary "$basepath/$macdevice/local-mac-address" 0 2>/dev/null)

	echo $macaddr
}

get_mac_label_json() {
	local cfg="/etc/board.json"
	local macaddr

	[ -s "$cfg" ] || return

	json_init
	json_load "$(cat $cfg)"
	if json_is_a system object; then
		json_select system
			json_get_var macaddr label_macaddr
		json_select ..
	fi

	echo $macaddr
}

get_mac_label() {
	local macaddr=$(get_mac_label_dt)

	[ -n "$macaddr" ] || macaddr=$(get_mac_label_json)

	echo $macaddr
}

find_mtd_chardev() {
	local INDEX=$(find_mtd_index "$1")
	local PREFIX=/dev/mtd

	[ -d /dev/mtd ] && PREFIX=/dev/mtd/
	echo "${INDEX:+$PREFIX$INDEX}"
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
	local mtdname=$1
	local offset=$(($2))
	local part
	local mac_dirty

	part=$(find_mtd_part "$mtdname")
	if [ -z "$part" ]; then
		echo "mtd_get_mac_text: partition $mtdname not found!" >&2
		return
	fi

	if [ -z "$offset" ]; then
		echo "mtd_get_mac_text: offset missing!" >&2
		return
	fi

	mac_dirty=$(dd if="$part" bs=1 skip="$offset" count=17 2>/dev/null)

	# "canonicalize" mac
	[ -n "$mac_dirty" ] && macaddr_canonicalize "$mac_dirty"
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

	. /lib/upgrade/nand.sh

	local ubidev=$(nand_find_ubi $CI_UBIPART)
	local part=$(nand_find_volume $ubidev $1)

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
	local mac=$1
	local val=$2
	local oui=${mac%:*:*:*}
	local nic=${mac#*:*:*:}

	nic=$(printf "%06x" $((0x${nic//:/} + val & 0xffffff)) | sed 's/^\(.\{2\}\)\(.\{2\}\)\(.\{2\}\)/\1:\2:\3/')
	echo $oui:$nic
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
	local mac=$1
	local bit=${2:-0}

	[ $bit -gt 0 -a $bit -le 48 ] || return

	printf "%012x" $(( 0x${mac//:/} | 2**(48-bit) )) | sed -e 's/\(.\{2\}\)/\1:/g' -e 's/:$//'
}

macaddr_unsetbit() {
	local mac=$1
	local bit=${2:-0}

	[ $bit -gt 0 -a $bit -le 48 ] || return

	printf "%012x" $(( 0x${mac//:/} & ~(2**(48-bit)) )) | sed -e 's/\(.\{2\}\)/\1:/g' -e 's/:$//'
}

macaddr_setbit_la() {
	macaddr_setbit $1 7
}

macaddr_unsetbit_mc() {
	local mac=$1

	printf "%02x:%s" $((0x${mac%%:*} & ~0x01)) ${mac#*:}
}

macaddr_random() {
	local randsrc=$(get_mac_binary /dev/urandom 0)
	
	echo "$(macaddr_unsetbit_mc "$(macaddr_setbit_la "${randsrc}")")"
}

macaddr_2bin() {
	local mac=$1

	echo -ne \\x${mac//:/\\x}
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
