"""Writes BlueZ's per-device /var/lib/bluetooth/<adapter>/<device>/info files.

Layout verified against bluez-5.84's src/adapter.c:
  - load_devices() takes the directory name itself as the device address
    (bachk()-validated "XX:XX:XX:XX:XX:XX"), and reads "<dir>/info" as a
    GKeyFile - a plain, case-sensitive INI file.
  - get_addr_type() reads [General] AddressType as the *string* "public"
    or "static" (bluez's internal name for a static random address, not
    "random"); anything else defaults to public.
  - update_technologies() is where [General] SupportedTechnologies and
    AddressType normally get set for a live connection - reproduced here
    since this writes the file directly instead of connecting.
"""

import configparser
import subprocess
from io import StringIO
from pathlib import Path

from .convert import DeviceKeys

BLUETOOTH_DIR = Path("/var/lib/bluetooth")


def format_mac(raw_no_colons: str) -> str:
    raw = raw_no_colons.upper()
    return ":".join(raw[i:i + 2] for i in range(0, len(raw), 2))


def find_adapter_dir(adapter_mac: str) -> Path | None:
    if not BLUETOOTH_DIR.is_dir():
        return None
    target = format_mac(adapter_mac)
    for entry in BLUETOOTH_DIR.iterdir():
        if entry.is_dir() and entry.name.upper() == target:
            return entry
    return None


def write_device_info(adapter_dir: Path, device_mac: str, keys: DeviceKeys, dry_run: bool) -> bool:
    """Merges `keys` into the device's info file. Returns whether anything changed."""
    device_dir = adapter_dir / format_mac(device_mac)
    info_path = device_dir / "info"

    cfg = configparser.ConfigParser(strict=False)
    cfg.optionxform = str  # GKeyFile option names are case-sensitive (EDiv, PINLength, ...)
    if info_path.exists():
        cfg.read(info_path)
    before = _serialize(cfg)

    if not cfg.has_section("General"):
        cfg.add_section("General")
    _add_technology(cfg, "LE" if keys.is_le else "BR/EDR")
    if keys.is_le:
        cfg.set("General", "AddressType", "static" if keys.address_type else "public")
    if not cfg.has_option("General", "Trusted"):
        cfg.set("General", "Trusted", "true")

    if keys.is_le:
        if keys.irk_hex:
            if not cfg.has_section("IdentityResolvingKey"):
                cfg.add_section("IdentityResolvingKey")
            cfg.set("IdentityResolvingKey", "Key", keys.irk_hex)

        if not cfg.has_section("LongTermKey"):
            cfg.add_section("LongTermKey")
        cfg.set("LongTermKey", "Key", keys.ltk_hex)
        cfg.set("LongTermKey", "Authenticated", "0")
        cfg.set("LongTermKey", "EncSize", str(keys.enc_size))
        cfg.set("LongTermKey", "EDiv", str(keys.ediv))
        cfg.set("LongTermKey", "Rand", str(keys.rand))
    else:
        if not cfg.has_section("LinkKey"):
            cfg.add_section("LinkKey")
        cfg.set("LinkKey", "Key", keys.ltk_hex)
        cfg.set("LinkKey", "Type", "4")
        cfg.set("LinkKey", "PINLength", "0")

    after = _serialize(cfg)
    changed = before != after
    if changed and not dry_run:
        device_dir.mkdir(parents=True, exist_ok=True)
        with info_path.open("w") as fh:
            fh.write(after)
    return changed


def _add_technology(cfg: configparser.ConfigParser, tech: str) -> None:
    existing = [t for t in cfg.get("General", "SupportedTechnologies", fallback="").split(";") if t]
    if tech not in existing:
        existing.append(tech)
    cfg.set("General", "SupportedTechnologies", ";".join(existing))


def _serialize(cfg: configparser.ConfigParser) -> str:
    buf = StringIO()
    cfg.write(buf, space_around_delimiters=False)
    return buf.getvalue()


def restart_bluetooth(dry_run: bool) -> None:
    if not dry_run:
        subprocess.run(["systemctl", "try-restart", "bluetooth.service"], check=False)
