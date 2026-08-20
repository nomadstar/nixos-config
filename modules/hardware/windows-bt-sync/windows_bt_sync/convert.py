"""Converts a Windows BTHPORT device key blob into BlueZ's key material.

Byte-order rules below are verified against bluez-5.84's src/adapter.c
(get_ltk/get_irk_info/store_ltk_group), not guessed:
  - LongTermKey.Key / IdentityResolvingKey.Key / LinkKey.Key: bluez's
    str2buf() parses these hex strings byte-for-byte in the order written -
    no reversal. Windows' LTK/IRK registry values are already plain byte
    dumps in that same order, so they're copied through as-is.
  - LongTermKey.EDiv / EncSize: read by bluez via g_key_file_get_integer,
    i.e. plain decimal. hivexregedit's `dword:XXXXXXXX` export is already
    the normalized big-endian value of the DWORD (confirmed against this
    hive's own KeyLength=dword:00000010 decoding to 16, the expected size
    of a 128-bit LTK) - so this is just int(hex, 16), no byte swap.
  - LongTermKey.Rand: bluez accepts a decimal string (sscanf %llu) or a
    "0x"-prefixed hex string it treats as raw little-endian bytes
    (str2buf into a uint64, then le64_to_cpu). Windows' ERand registry
    value (hex(b), REG_QWORD) is *also* a raw little-endian byte dump
    (confirmed the same way as above, via a device's "Address" value
    reversing to its own subkey name). Both sides agree on
    little-endian, so the decimal form is just
    int.from_bytes(raw_bytes, "little").
"""

from dataclasses import dataclass


@dataclass
class DeviceKeys:
    is_le: bool
    ltk_hex: str
    irk_hex: str | None
    enc_size: int
    ediv: int | None
    rand: int | None
    address_type: int  # Windows AddressType dword: 0 = public, 1 = random


def convert_device(values: dict[str, str]) -> DeviceKeys | None:
    ltk_raw = values.get("LTK")
    if ltk_raw is None:
        return None

    ediv_raw = values.get("EDIV")
    erand_raw = values.get("ERand")
    is_le = ediv_raw is not None and erand_raw is not None

    irk_raw = values.get("IRK")
    key_length_raw = values.get("KeyLength")
    address_type_raw = values.get("AddressType")

    return DeviceKeys(
        is_le=is_le,
        ltk_hex=_hex_bytes(ltk_raw).hex(),
        irk_hex=_hex_bytes(irk_raw).hex() if irk_raw else None,
        enc_size=_dword(key_length_raw) if key_length_raw else 16,
        ediv=_dword(ediv_raw) if is_le else None,
        rand=int.from_bytes(_hex_bytes(erand_raw), "little") if is_le else None,
        address_type=_dword(address_type_raw) if address_type_raw else 0,
    )


def _hex_bytes(raw: str) -> bytes:
    # raw looks like "hex(3):5a,ff,9d,b9,..." (REG_BINARY) or
    # "hex(b):55,f8,ab,..." (REG_QWORD) - both are comma-separated byte lists.
    _, data = raw.split(":", 1)
    return bytes(int(b, 16) for b in data.split(",") if b.strip())


def _dword(raw: str) -> int:
    # raw looks like "dword:000041b2"
    return int(raw.split(":", 1)[1], 16)
