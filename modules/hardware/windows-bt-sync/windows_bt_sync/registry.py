"""Reads Bluetooth pairing keys out of a Windows SYSTEM registry hive.

Windows stores them at
SYSTEM\\<ControlSet>\\Services\\BTHPORT\\Parameters\\Keys\\<adapter MAC>\\<device MAC>,
as plain hex-string MACs (no colons, no reversal - confirmed by cross-checking
a device subkey's own "Address" value, which decodes to the same MAC as its
key name once its bytes are reversed the way Windows' little-endian byte
arrays normally require). Read-only: this module only ever runs
`hivexregedit --export`, never `--merge`.
"""

import re
import subprocess

_KEY_HEADER = re.compile(r"^\[HKEY_LOCAL_MACHINE\\SYSTEM\\(?P<path>[^\]]+)\]$")
_VALUE_LINE = re.compile(r'^"(?P<name>[^"]+)"=(?P<raw>.+)$')


def active_control_set(hive_path: str) -> str:
    """SYSTEM\\Select\\Current holds the number of the live ControlSetNNN."""
    out = _hivexregedit_export(hive_path, "Select")
    m = re.search(r'"Current"=dword:([0-9a-fA-F]+)', out)
    if not m:
        return "ControlSet001"
    return f"ControlSet{int(m.group(1), 16):03d}"


def export_bthport_keys(hive_path: str, control_set: str) -> str:
    return _hivexregedit_export(hive_path, f"{control_set}\\Services\\BTHPORT\\Parameters\\Keys")


def _hivexregedit_export(hive_path: str, key: str) -> str:
    result = subprocess.run(
        ["hivexregedit", "--export", "--prefix", "HKEY_LOCAL_MACHINE\\SYSTEM", hive_path, key],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def parse_bthport_export(reg_text: str) -> dict[str, dict[str, dict[str, str]]]:
    """{adapter_mac: {device_mac: {value_name: raw_reg_value}}}, MACs lowercase.

    Only two-levels-deep subkeys (adapter\\device) are kept. Values sitting
    directly on the adapter key itself (e.g. "CentralIRK", or stray
    MAC-named values with no matching device subkey) are the local
    adapter's own identity material, not a remote device's pairing data -
    BlueZ manages its own local identity independently, so there is
    nothing there worth cloning.
    """
    devices: dict[str, dict[str, dict[str, str]]] = {}
    current: tuple[str, str] | None = None

    for line in _join_continuations(reg_text):
        header = _KEY_HEADER.match(line)
        if header:
            parts = header.group("path").split("\\")
            current = None
            if "Keys" in parts:
                tail = parts[parts.index("Keys") + 1:]
                if len(tail) == 2:
                    current = (tail[0].lower(), tail[1].lower())
                    devices.setdefault(current[0], {}).setdefault(current[1], {})
            continue

        value = _VALUE_LINE.match(line)
        if value and current:
            devices[current[0]][current[1]][value.group("name")] = value.group("raw")

    return devices


def _join_continuations(reg_text: str):
    """Undoes regedit's backslash-newline wrapping of long hex(...) values."""
    buf = ""
    for line in reg_text.replace("\r\n", "\n").split("\n"):
        buf += line if not buf else line.strip()
        if buf.endswith("\\"):
            buf = buf[:-1]
            continue
        yield buf
        buf = ""
    if buf:
        yield buf
