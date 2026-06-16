#!/bin/sh
# factory-eeprom.sh — AT24C02 256B dual-slot factory EEPROM tool (CTFB v1 A/B)
# Matches: eeprom-layout-v1.txt (dual-slot A/B), Slot A=0x00..0x7F, Slot B=0x80..0xFF
#
# Provides:
#   - slot selection (valid+newest seq)
#   - read fields (SN/MAC/PN/BATCH/HWREV)
#   - set fields (writes other slot, seq++)
#   - verify CRC
#
# Notes:
#   - Writes are power-fail safer by writing the inactive slot.
#   - EEPROM wear: avoid repeated writes; batch updates into one `set` call if possible.

set -eu

PROG=$(basename "$0")

DEFAULT_EEPROM_PATH=/sys/bus/i2c/devices/1-0050/eeprom
DEV="${FACTORY_EEPROM_PATH:-$DEFAULT_EEPROM_PATH}"

UBOOT_MAC_VAR="${FACTORY_EEPROM_UBOOT_MAC_VAR:-ethaddr}"

EEPROM_SIZE=256
SLOT_SIZE=128
SLOT_A_BASE=0
SLOT_B_BASE=128

MAGIC_ASCII=CTFB
LAYOUT_VERSION=1

die() { echo "$PROG: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage:
  $PROG [-d DEV] info
  $PROG [-d DEV] verify
  $PROG [-d DEV] get <SN|MAC|PN|BATCH|HWREV>
  $PROG [-d DEV] set <SN|MAC|PN|BATCH|HWREV> <VALUE>
  $PROG [-d DEV] dump-slot <A|B>
  $PROG [-d DEV] erase

  -d DEV   EEPROM sysfs node or file (default: $DEFAULT_EEPROM_PATH)
  FACTORY_EEPROM_UBOOT_MAC_VAR   U-Boot env var for MAC (default: ethaddr)
  FACTORY_EEPROM_FORCE_ERASE=1   skip interactive erase confirmation

Examples:
  $PROG info
  $PROG verify
  $PROG get SN
  $PROG set SN CT2026-000812
  $PROG set MAC 00:11:22:33:44:55
  $PROG erase
EOF
	exit "${1:-0}"
}

sync_uboot_mac_env() {
	mac="$1"
	validate_mac "$mac" || die "invalid MAC (expected aa:bb:cc:dd:ee:ff)"
	command -v fw_setenv >/dev/null 2>&1 || die "fw_setenv not found; cannot sync U-Boot env ($UBOOT_MAC_VAR)"
	fw_setenv "$UBOOT_MAC_VAR" "$mac" >/dev/null 2>&1 || die "fw_setenv failed for $UBOOT_MAC_VAR"
}

confirm_erase() {
	if [ "${FACTORY_EEPROM_FORCE_ERASE:-}" = "1" ]; then
		return 0
	fi
	if [ -t 0 ] && [ -t 1 ]; then
		printf 'This will erase EEPROM (%s bytes) to 0xFF. Type ERASE to continue: ' "$EEPROM_SIZE" >&2
		IFS= read -r ans || ans=""
		[ "$ans" = "ERASE" ] || die "erase cancelled"
		return 0
	fi
	die "non-interactive erase blocked; set FACTORY_EEPROM_FORCE_ERASE=1"
}

need_dev_readable() {
	[ -n "$DEV" ] || die "device path empty (use -d or FACTORY_EEPROM_PATH)"
	[ -r "$DEV" ] || die "cannot read: $DEV"
}

need_dev_writable() {
	need_dev_readable
	[ -w "$DEV" ] || die "cannot write: $DEV"
}

tmpfile() {
	# mktemp is expected on build/target; if missing, fallback.
	if command -v mktemp >/dev/null 2>&1; then
		mktemp
	else
		echo "/tmp/${PROG}.$$.$(date +%s)"
	fi
}

read_slot_to_file() {
	base="$1"
	out="$2"
	need_dev_readable
	dd if="$DEV" of="$out" bs=1 skip="$base" count="$SLOT_SIZE" 2>/dev/null
}

write_slot_from_file() {
	base="$1"
	in="$2"
	need_dev_writable
	# Write exactly SLOT_SIZE bytes starting at base.
	dd if="$in" of="$DEV" bs=1 seek="$base" count="$SLOT_SIZE" conv=notrunc 2>/dev/null
}

u8_at() {
	file="$1"; off="$2"
	dd if="$file" bs=1 skip="$off" count=1 2>/dev/null | od -An -tu1 -v | awk '{print $1+0}'
}

u16le_at() {
	file="$1"; off="$2"
	dd if="$file" bs=1 skip="$off" count=2 2>/dev/null | od -An -tu1 -v | awk '{print ($1+0) + 256*($2+0)}'
}

u32le_at() {
	file="$1"; off="$2"
	dd if="$file" bs=1 skip="$off" count=4 2>/dev/null | od -An -tu1 -v | awk '{print ($1+0) + 256*($2+0) + 65536*($3+0) + 16777216*($4+0)}'
}

hex2byte() {
	# input: two hex chars -> decimal 0..255
	printf '%s' "$1" | awk 'BEGIN{FS=""}{v=0;for(i=1;i<=2;i++){c=toupper($i);d=index("0123456789ABCDEF",c)-1;if(d<0)exit 1;v=v*16+d}print v}'
}

validate_mac() {
	printf '%s' "$1" | grep -qxE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'
}

trim_ff_ascii() {
	# stdin is bytes; strip trailing 0xFF and NUL; print as text
	tmp=$(tmpfile)
	cat >"$tmp"
	LC_ALL=C od -An -tu1 -v "$tmp" | awk '
	{
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^[0-9]+$/) buf[++n] = $i + 0
		}
	}
	END {
		while (n > 0 && (buf[n] == 255 || buf[n] == 0)) n--
		for (i = 1; i <= n; i++) printf "%c", buf[i]
	}
	'
	rm -f "$tmp"
}

crc16_ccitt_false_file_region() {
	file="$1"; off="$2"; len="$3"
	dd if="$file" bs=1 skip="$off" count="$len" 2>/dev/null | od -An -tu1 -v | awk '
	function crc16_update(crc, b,    i, mix) {
		crc = xor(crc, lshift(b, 8))
		for (i = 0; i < 8; i++) {
			if (and(crc, 0x8000)) crc = xor(lshift(crc, 1), 0x1021)
			else crc = lshift(crc, 1)
			crc = and(crc, 0xFFFF)
		}
		return crc
	}
	BEGIN { crc = 0xFFFF }
	{
		for (i = 1; i <= NF; i++) {
			if ($i ~ /^[0-9]+$/) crc = crc16_update(crc, $i + 0)
		}
	}
	END { printf "%d\n", crc }
	'
}

slot_magic_ok() {
	file="$1"
	m=$(dd if="$file" bs=1 count=4 2>/dev/null)
	[ "$m" = "$MAGIC_ASCII" ]
}

slot_version_ok() {
	file="$1"
	v=$(u8_at "$file" 4)
	[ "$v" -eq "$LAYOUT_VERSION" ]
}

slot_crc_ok() {
	file="$1"
	stored=$(u16le_at "$file" 6)
	computed=$(crc16_ccitt_false_file_region "$file" 16 112)
	[ "$stored" -eq "$computed" ]
}

slot_valid() {
	file="$1"
	slot_magic_ok "$file" && slot_version_ok "$file" && slot_crc_ok "$file"
}

slot_seq() {
	file="$1"
	u32le_at "$file" 8
}

choose_active_slot() {
	# outputs: "A" or "B" or "NONE"
	a=$(tmpfile); b=$(tmpfile)
	read_slot_to_file "$SLOT_A_BASE" "$a"
	read_slot_to_file "$SLOT_B_BASE" "$b"

	aval=0; bval=0
	if slot_valid "$a"; then aval=1; fi
	if slot_valid "$b"; then bval=1; fi

	if [ "$aval" -eq 1 ] && [ "$bval" -eq 1 ]; then
		aseq=$(slot_seq "$a"); bseq=$(slot_seq "$b")
		rm -f "$a" "$b"
		if [ "$aseq" -ge "$bseq" ]; then echo A; else echo B; fi
		return 0
	fi
	if [ "$aval" -eq 1 ]; then rm -f "$a" "$b"; echo A; return 0; fi
	if [ "$bval" -eq 1 ]; then rm -f "$a" "$b"; echo B; return 0; fi
	rm -f "$a" "$b"
	echo NONE
}

other_slot() {
	case "$1" in
	A) echo B ;;
	B) echo A ;;
	*) die "internal: bad slot $1" ;;
	esac
}

slot_base() {
	case "$1" in
	A) echo "$SLOT_A_BASE" ;;
	B) echo "$SLOT_B_BASE" ;;
	*) die "invalid slot: $1" ;;
	esac
}

init_blank_slot_file() {
	out="$1"
	dd if=/dev/zero bs=1 count="$SLOT_SIZE" 2>/dev/null | tr '\000' '\377' >"$out"
}

write_ascii_field() {
	# write string into file at offset with fixed length, pad with 0xFF
	file="$1"; off="$2"; maxlen="$3"; val="$4"
	tmp=$(tmpfile)
	# truncate to maxlen bytes
	printf '%s' "$val" | dd bs=1 count="$maxlen" 2>/dev/null >"$tmp"
	n=$(wc -c <"$tmp" | tr -d ' ')
	if [ "$n" -lt "$maxlen" ]; then
		fill=$((maxlen - n))
		dd if=/dev/zero bs=1 count="$fill" 2>/dev/null | tr '\000' '\377' >>"$tmp"
	fi
	dd if="$tmp" of="$file" bs=1 seek="$off" count="$maxlen" conv=notrunc 2>/dev/null
	rm -f "$tmp"
}

write_mac_bin() {
	file="$1"; off="$2"; mac="$3"
	validate_mac "$mac" || die "invalid MAC (expected aa:bb:cc:dd:ee:ff)"
	tmp=$(tmpfile)
	: >"$tmp"
	# shellcheck disable=SC2039
	IFS=:
	set -- $mac
	IFS=' '
	for oct in "$@"; do
		b=$(hex2byte "$oct") || die "invalid MAC octet: $oct"
		printf "\\$(printf '%03o' "$b")" >>"$tmp"
	done
	unset IFS
	dd if="$tmp" of="$file" bs=1 seek="$off" count=6 conv=notrunc 2>/dev/null
	rm -f "$tmp"
}

write_u16le() {
	file="$1"; off="$2"; val="$3"
	lo=$((val & 255))
	hi=$(((val >> 8) & 255))
	printf "\\$(printf '%03o' "$lo")\\$(printf '%03o' "$hi")" | dd of="$file" bs=1 seek="$off" count=2 conv=notrunc 2>/dev/null
}

write_u32le() {
	file="$1"; off="$2"; val="$3"
	b0=$((val & 255))
	b1=$(((val >> 8) & 255))
	b2=$(((val >> 16) & 255))
	b3=$(((val >> 24) & 255))
	printf "\\$(printf '%03o' "$b0")\\$(printf '%03o' "$b1")\\$(printf '%03o' "$b2")\\$(printf '%03o' "$b3")" | dd of="$file" bs=1 seek="$off" count=4 conv=notrunc 2>/dev/null
}

write_magic_version_flags() {
	file="$1"; flags="$2"
	printf '%s' "$MAGIC_ASCII" | dd of="$file" bs=1 seek=0 count=4 conv=notrunc 2>/dev/null
	printf "\\$(printf '%03o' "$LAYOUT_VERSION")" | dd of="$file" bs=1 seek=4 count=1 conv=notrunc 2>/dev/null
	printf "\\$(printf '%03o' "$flags")" | dd of="$file" bs=1 seek=5 count=1 conv=notrunc 2>/dev/null
}

field_offsets() {
	# outputs: off len type
	# type: mac|ascii
	case "$1" in
	MAC)   echo "16 6 mac" ;;
	SN)    echo "24 32 ascii" ;;
	PN)    echo "56 16 ascii" ;;
	BATCH) echo "72 8 ascii" ;;
	HWREV) echo "80 8 ascii" ;;
	*) die "unknown field: $1 (use SN|MAC|PN|BATCH|HWREV)" ;;
	esac
}

read_field_from_slot_file() {
	slotfile="$1"; field="$2"
	set -- $(field_offsets "$field")
	off="$1"; len="$2"; typ="$3"
	if [ "$typ" = "mac" ]; then
		dd if="$slotfile" bs=1 skip="$off" count="$len" 2>/dev/null | od -An -tx1 -v | awk '
		{
			for (i=1;i<=NF;i++) {
				b=$i
				printf "%s%s", (i==1?"":":"), b
			}
			printf "\n"
		}' | tr 'a-f' 'A-F'
	else
		dd if="$slotfile" bs=1 skip="$off" count="$len" 2>/dev/null | trim_ff_ascii
		printf "\n"
	fi
}

cmd_info() {
	active=$(choose_active_slot)
	echo "device: $DEV"
	echo "layout: CTFB v1 A/B"
	echo "active_slot: $active"

	a=$(tmpfile); b=$(tmpfile)
	read_slot_to_file "$SLOT_A_BASE" "$a"
	read_slot_to_file "$SLOT_B_BASE" "$b"

	for s in A B; do
		f="$a"; [ "$s" = "B" ] && f="$b"
		if slot_magic_ok "$f" && slot_version_ok "$f"; then
			seq=$(slot_seq "$f")
			crc=$(u16le_at "$f" 6)
			if slot_crc_ok "$f"; then ok=1; else ok=0; fi
			echo "slot_$s: magic_ok=1 version_ok=1 crc_ok=$ok seq=$seq crc16=$crc"
		else
			echo "slot_$s: magic_ok=0 version_ok=0 crc_ok=0"
		fi
	done

	if [ "$active" != "NONE" ]; then
		f=$(tmpfile)
		read_slot_to_file "$(slot_base "$active")" "$f"
		if slot_valid "$f"; then
			echo "fields:"
			echo -n "  SN="; read_field_from_slot_file "$f" SN | tr -d '\n'; echo
			echo -n "  MAC="; read_field_from_slot_file "$f" MAC | tr -d '\n'; echo
			echo -n "  PN="; read_field_from_slot_file "$f" PN | tr -d '\n'; echo
			echo -n "  BATCH="; read_field_from_slot_file "$f" BATCH | tr -d '\n'; echo
			echo -n "  HWREV="; read_field_from_slot_file "$f" HWREV | tr -d '\n'; echo
		fi
		rm -f "$f"
	fi

	rm -f "$a" "$b"
}

cmd_verify() {
	active=$(choose_active_slot)
	[ "$active" != "NONE" ] || die "no valid slot (A/B invalid); EEPROM unprogrammed?"
	f=$(tmpfile)
	read_slot_to_file "$(slot_base "$active")" "$f"
	slot_valid "$f" || { rm -f "$f"; die "active slot failed validation"; }
	rm -f "$f"
	echo "OK: active slot $active valid"
}

cmd_get() {
	field="$1"
	active=$(choose_active_slot)
	[ "$active" != "NONE" ] || die "no valid slot (A/B invalid); EEPROM unprogrammed?"
	f=$(tmpfile)
	read_slot_to_file "$(slot_base "$active")" "$f"
	slot_valid "$f" || { rm -f "$f"; die "active slot failed validation"; }
	read_field_from_slot_file "$f" "$field"
	rm -f "$f"
}

cmd_dump_slot() {
	s="$1"
	[ "$s" = "A" ] || [ "$s" = "B" ] || die "dump-slot requires A or B"
	f=$(tmpfile)
	read_slot_to_file "$(slot_base "$s")" "$f"
	if command -v hexdump >/dev/null 2>&1; then
		hexdump -C "$f"
	else
		od -An -tx1 -v "$f"
	fi
	rm -f "$f"
}

cmd_set() {
	field="$1"; value="$2"
	need_dev_writable

	active=$(choose_active_slot)
	target=A
	seq=0
	base_target="$SLOT_A_BASE"

	if [ "$active" = "NONE" ]; then
		# first programming: write slot A with seq=1
		target=A
		seq=1
	else
		target=$(other_slot "$active")
		f=$(tmpfile)
		read_slot_to_file "$(slot_base "$active")" "$f"
		slot_valid "$f" || { rm -f "$f"; die "active slot failed validation"; }
		seq=$(( $(slot_seq "$f") + 1 ))
		rm -f "$f"
	fi

	base_target=$(slot_base "$target")

	# Build new slot content in a temp file.
	out=$(tmpfile)
	if [ "$active" = "NONE" ]; then
		init_blank_slot_file "$out"
	else
		# Start from the full active slot image to preserve all fields, then modify.
		read_slot_to_file "$(slot_base "$active")" "$out"
	fi

	# Apply field update on payload offsets.
	set -- $(field_offsets "$field")
	off="$1"; len="$2"; typ="$3"
	if [ "$typ" = "mac" ]; then
		write_mac_bin "$out" "$off" "$value"
	else
		write_ascii_field "$out" "$off" "$len" "$value"
	fi

	# Compute CRC over payload and write header.
	crc=$(crc16_ccitt_false_file_region "$out" 16 112)

	# flags: set programmed + mac_valid if MAC is not all 0xFF
	flags=1
	m0=$(u8_at "$out" 16)
	if [ "$m0" -ne 255 ]; then flags=$((flags | 2)); fi

	write_magic_version_flags "$out" "$flags"
	write_u16le "$out" 6 "$crc"
	write_u32le "$out" 8 "$seq"
	# reserved0 in header (+0x0C..+0x0F) should be 0xFF
	printf '\377\377\377\377' | dd of="$out" bs=1 seek=12 count=4 conv=notrunc 2>/dev/null

	# For MAC updates, sync U-Boot env first to avoid partial EEPROM update when fw_setenv is misconfigured.
	if [ "$field" = "MAC" ]; then
		sync_uboot_mac_env "$value"
	fi

	# Write slot and verify.
	write_slot_from_file "$base_target" "$out"
	ver=$(tmpfile)
	read_slot_to_file "$base_target" "$ver"
	slot_valid "$ver" || { rm -f "$out" "$ver"; die "verify after write failed for slot $target"; }

	rm -f "$out" "$ver"
	if [ "$field" = "MAC" ]; then
		echo "OK: wrote $field to slot $target (seq=$seq) and synced U-Boot $UBOOT_MAC_VAR"
		return 0
	fi
	echo "OK: wrote $field to slot $target (seq=$seq)"
}

cmd_erase() {
	confirm_erase
	need_dev_writable
	tmp=$(tmpfile)
	dd if=/dev/zero bs=1 count="$EEPROM_SIZE" 2>/dev/null | tr '\000' '\377' >"$tmp"
	dd if="$tmp" of="$DEV" bs=1 count="$EEPROM_SIZE" conv=notrunc 2>/dev/null
	rm -f "$tmp"
	echo "OK: erased EEPROM (${EEPROM_SIZE} bytes to 0xFF)"
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-d) DEV=${2:-}; shift 2 ;;
		-h|--help) usage 0 ;;
		--) shift; break ;;
		-*) die "unknown option: $1 (try --help)" ;;
		*) break ;;
		esac
	done

	[ $# -ge 1 ] || usage 1
	cmd="$1"; shift

	case "$cmd" in
	info) [ $# -eq 0 ] || die "info: no args"; cmd_info ;;
	verify) [ $# -eq 0 ] || die "verify: no args"; cmd_verify ;;
	get) [ $# -eq 1 ] || die "get: need FIELD"; cmd_get "$1" ;;
	set) [ $# -eq 2 ] || die "set: need FIELD VALUE"; cmd_set "$1" "$2" ;;
	dump-slot) [ $# -eq 1 ] || die "dump-slot: need A|B"; cmd_dump_slot "$1" ;;
	erase) [ $# -eq 0 ] || die "erase: no args"; cmd_erase ;;
	*) die "unknown command: $cmd (try --help)" ;;
	esac
}

main "$@"

