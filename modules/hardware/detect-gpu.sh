#!/usr/bin/env bash
set -euo pipefail

# Enumerates PCI display-controller devices (class 0x03xxxx) straight from
# /sys/bus/pci/devices - this exists independent of which (or whether any)
# kernel driver is bound, unlike /sys/class/drm which only appears once a
# DRM driver has claimed the device. `lspci` is only used as a fallback if
# /sys/bus/pci is missing entirely (shouldn't happen on Linux, but per
# spec). Every adapter found is enumerated - never just the first one, and
# never a card0/card1 = integrated/discrete assumption. Topology
# classification itself is classify_gpus() (see gpu-classify.sh, prepended
# to this script at build time) - kept separate on purpose so it can be
# unit-tested with simulated vendor lists without touching real hardware.
#
# Output: JSON on stdout (see the example in
# modules/hardware/hardware-profile.nix's header comment). Exit status 0
# when the topology was classified unambiguously, 2 when it wasn't
# (AMD+NVIDIA, three vendors, no known vendor at all, ...) - the JSON is
# still printed in that case (with "ambiguous": true and a "reason"), just
# not meant to be persisted as-is.

pci_ids=()
pci_vendors=()
pci_devices=()

if [ -d /sys/bus/pci/devices ]; then
  for dev in /sys/bus/pci/devices/*/; do
    class_file="${dev}class"
    [ -r "$class_file" ] || continue
    class=$(cat "$class_file")
    case "$class" in
      0x03*) ;;
      *) continue ;;
    esac
    vendor_id=$(cat "${dev}vendor" 2>/dev/null || echo "")
    device_id=$(cat "${dev}device" 2>/dev/null || echo "")
    [ -n "$vendor_id" ] || continue
    pci_ids+=("$(basename "${dev%/}")")
    pci_vendors+=("$vendor_id")
    pci_devices+=("$device_id")
  done
else
  # Fallback: `lspci -Dn` prints "<domain:bus:slot.func> <class>: <ven>:<dev>
  # [rev]" - only class 03xx (display controllers) is kept.
  while read -r slot class rest; do
    case "$class" in
      03*) ;;
      *) continue ;;
    esac
    ids="${rest%% *}"
    pci_ids+=("$slot")
    pci_vendors+=("0x${ids%%:*}")
    pci_devices+=("0x${ids##*:}")
  done < <(lspci -Dn 2>/dev/null)
fi

vendor_of=()
for i in "${!pci_ids[@]}"; do
  vendor_of+=("$(vendor_name "${pci_vendors[$i]}")")
done

gpus_json="[]"
if [ "${#pci_ids[@]}" -gt 0 ]; then
  gpus_json=$(
    for i in "${!pci_ids[@]}"; do
      jq -n \
        --arg vendor "${vendor_of[$i]}" \
        --arg pciVendor "${pci_vendors[$i]#0x}" \
        --arg pciDevice "${pci_devices[$i]#0x}" \
        --arg pciAddress "${pci_ids[$i]}" \
        '{vendor: $vendor, pciVendor: $pciVendor, pciDevice: $pciDevice, pciAddress: $pciAddress}'
    done | jq -s '.'
  )
fi

classify_status=0
classify_output=$(classify_gpus "${vendor_of[@]}") || classify_status=$?

mode=$(printf '%s\n' "$classify_output" | sed -n 's/^mode=//p')
integratedVendor=$(printf '%s\n' "$classify_output" | sed -n 's/^integratedVendor=//p')
discreteVendor=$(printf '%s\n' "$classify_output" | sed -n 's/^discreteVendor=//p')
displayVendor=$(printf '%s\n' "$classify_output" | sed -n 's/^displayVendor=//p')
computeVendor=$(printf '%s\n' "$classify_output" | sed -n 's/^computeVendor=//p')
computeBackend=$(printf '%s\n' "$classify_output" | sed -n 's/^computeBackend=//p')
offload=$(printf '%s\n' "$classify_output" | sed -n 's/^offload=//p')
ambiguous=$(printf '%s\n' "$classify_output" | sed -n 's/^ambiguous=//p')
reason=$(printf '%s\n' "$classify_output" | sed -n 's/^reason=//p')

jq -n \
  --arg mode "$mode" \
  --argjson gpus "$gpus_json" \
  --arg integratedVendor "$integratedVendor" \
  --arg discreteVendor "$discreteVendor" \
  --arg displayVendor "$displayVendor" \
  --arg computeVendor "$computeVendor" \
  --arg computeBackend "$computeBackend" \
  --arg offload "$offload" \
  --argjson ambiguous "$ambiguous" \
  --arg reason "$reason" \
  '{
    mode: $mode,
    gpus: $gpus,
    integratedVendor: (if $integratedVendor == "" then null else $integratedVendor end),
    discreteVendor: (if $discreteVendor == "" then null else $discreteVendor end),
    displayVendor: (if $displayVendor == "" then null else $displayVendor end),
    computeVendor: (if $computeVendor == "" then null else $computeVendor end),
    computeBackend: (if $computeBackend == "" then null else $computeBackend end),
    offload: (if $offload == "" then null else $offload end),
    ambiguous: $ambiguous
  } + (if $ambiguous then {reason: $reason} else {} end)'

if [ "$classify_status" -ne 0 ]; then
  echo "warning: $reason" >&2
fi

exit "$classify_status"
