vendor_name() {
  case "$1" in
    0x1002) echo amd ;;
    0x10de) echo nvidia ;;
    0x8086) echo intel ;;
    *) echo unknown ;;
  esac
}

# classify_gpus <vendor1> [<vendor2> ...]
# One argument per detected GPU adapter (vendor name: amd/nvidia/intel/
# unknown), duplicates included. Prints key=value lines describing the
# display/compute topology. Exit status 0 = classified, 2 = ambiguous/
# unknown (caller must not persist the result as-is). Pure function - no
# PCI/sysfs access, safe to unit-test with simulated vendor lists (see
# gpu-classify-test.sh).
classify_gpus() {
  local vendors=("$@")

  if [ "${#vendors[@]}" -eq 0 ]; then
    echo "mode=unknown"
    echo "ambiguous=true"
    echo "reason=no GPU adapters given"
    return 2
  fi

  local -A seen=()
  local v
  for v in "${vendors[@]}"; do
    seen["$v"]=1
  done

  local non_intel=()
  for v in "${!seen[@]}"; do
    [ "$v" = intel ] || non_intel+=("$v")
  done

  local has_intel=false
  [ -n "${seen[intel]:-}" ] && has_intel=true

  # More than one *distinct* non-Intel vendor => topology alone can't say
  # which one is the compute target (AMD+NVIDIA, Intel+AMD+NVIDIA, several
  # discrete GPUs from different vendors, ...). Not a popularity contest -
  # refuse to guess.
  if [ "${#non_intel[@]}" -gt 1 ]; then
    echo "mode=unknown"
    echo "ambiguous=true"
    echo "reason=more than one non-Intel GPU vendor present (${non_intel[*]}) - topology doesn't disambiguate the compute target"
    return 2
  fi

  if [ "${#non_intel[@]}" -eq 0 ]; then
    if [ "$has_intel" = true ]; then
      echo "mode=integrated"
      echo "integratedVendor=intel"
      echo "discreteVendor="
      echo "displayVendor=intel"
      echo "computeVendor=intel"
      echo "computeBackend="
      echo "offload="
      echo "ambiguous=false"
      return 0
    fi
    echo "mode=unknown"
    echo "ambiguous=true"
    echo "reason=no known GPU vendor present"
    return 2
  fi

  local dgpu="${non_intel[0]}"
  local backend=""
  case "$dgpu" in
    amd) backend=rocm ;;
    nvidia) backend=cuda ;;
  esac

  if [ "$has_intel" = true ]; then
    # Intel iGPU + exactly one discrete vendor => hybrid.
    echo "mode=hybrid"
    echo "integratedVendor=intel"
    echo "discreteVendor=$dgpu"
    echo "displayVendor=intel"
    echo "computeVendor=$dgpu"
    echo "computeBackend=$backend"
    if [ "$dgpu" = nvidia ]; then
      echo "offload=prime"
    else
      # Intel+AMD hybrid: Mesa/DRI_PRIME is not the same mechanism as
      # NVIDIA PRIME, and this repo has no equivalent offload module yet -
      # left unset on purpose instead of reusing "prime".
      echo "offload="
    fi
    echo "ambiguous=false"
    return 0
  fi

  # Single non-Intel vendor, no Intel present: discrete-only machine (this
  # repo's desktop - AMD only). If the same vendor appears more than once
  # (e.g. an AMD iGPU alongside an AMD dGPU), integrated/discrete roles are
  # deliberately left unset here - PCI vendor/class alone can't reliably
  # tell them apart, and every real host in this repo only ever has one
  # adapter in this branch anyway. Known limitation, not solved here.
  echo "mode=discrete"
  echo "integratedVendor="
  echo "discreteVendor=$dgpu"
  echo "displayVendor=$dgpu"
  echo "computeVendor=$dgpu"
  echo "computeBackend=$backend"
  echo "offload="
  echo "ambiguous=false"
  return 0
}
