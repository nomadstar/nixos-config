import argparse
import sys
from pathlib import Path

from . import bluez, convert, registry

DEFAULT_HIVE_CANDIDATES = [
    "/mnt/winC/Windows/System32/config/SYSTEM",
]


def find_hive(explicit: str | None) -> str:
    if explicit:
        return explicit
    for candidate in DEFAULT_HIVE_CANDIDATES:
        if Path(candidate).is_file():
            return candidate
    raise SystemExit(
        "windows-bt-sync: no Windows SYSTEM hive found under the default "
        f"mount points ({', '.join(DEFAULT_HIVE_CANDIDATES)}); pass --hive"
    )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="windows-bt-sync",
        description="Copy Bluetooth LE/classic pairing keys from a mounted Windows partition's registry into BlueZ",
    )
    parser.add_argument(
        "--hive",
        help="path to Windows' Windows/System32/config/SYSTEM hive (default: autodetect under /mnt/winC)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="report which devices would be updated without touching /var/lib/bluetooth",
    )
    args = parser.parse_args(argv)

    hive_path = find_hive(args.hive)
    control_set = registry.active_control_set(hive_path)
    reg_text = registry.export_bthport_keys(hive_path, control_set)
    devices_by_adapter = registry.parse_bthport_export(reg_text)

    changed_any = False
    for adapter_mac, devices in devices_by_adapter.items():
        adapter_dir = bluez.find_adapter_dir(adapter_mac)
        if adapter_dir is None:
            print(
                f"windows-bt-sync: no local BlueZ adapter matches Windows adapter "
                f"{bluez.format_mac(adapter_mac)}, skipping its {len(devices)} device(s)",
                file=sys.stderr,
            )
            continue

        for device_mac, values in devices.items():
            keys = convert.convert_device(values)
            if keys is None:
                continue
            changed = bluez.write_device_info(adapter_dir, device_mac, keys, args.dry_run)
            if changed:
                changed_any = True
                verb = "would update" if args.dry_run else "updated"
                kind = "LE" if keys.is_le else "classic"
                print(f"windows-bt-sync: {verb} {bluez.format_mac(device_mac)} ({kind})")

    if changed_any:
        print("windows-bt-sync: restarting bluetooth.service" if not args.dry_run
              else "windows-bt-sync: would restart bluetooth.service")
        bluez.restart_bluetooth(args.dry_run)
    else:
        print("windows-bt-sync: nothing to sync")

    return 0


if __name__ == "__main__":
    sys.exit(main())
