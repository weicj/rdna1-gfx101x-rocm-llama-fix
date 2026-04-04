#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BUNDLED_NAVI14_DIR="$SCRIPT_DIR/assets/firmware/navi14"

usage() {
  cat <<'EOF'
W5500 ROCm bootstrap helper

Usage:
  w5500-rocm-bootstrap.sh doctor [--pci-bdf BDF]
  w5500-rocm-bootstrap.sh backup-firmware [--out DIR]
  w5500-rocm-bootstrap.sh install-firmware-overlay [--from DIR] [--kernel KVER] [--dry-run]
  w5500-rocm-bootstrap.sh link-rocm7-gfx1012 --rocm6-lib DIR --rocm7-lib DIR [--dry-run]
  w5500-rocm-bootstrap.sh print-build-rocm6
  w5500-rocm-bootstrap.sh print-build-rocm7

Notes:
  - This is a staged bootstrap helper, not a blind magic one-click script.
  - Firmware replacement and initramfs rebuild still require judgment and reboot discipline.
  - If --from is omitted for install-firmware-overlay, bundled Navi14 firmware in this repository is used.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

cmd_doctor() {
  local pci_bdf="0000:05:00.0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pci-bdf) pci_bdf="${2:?}"; shift 2 ;;
      *) die "unknown doctor arg: $1" ;;
    esac
  done

  need_cmd lspci
  need_cmd uname

  echo "== kernel =="
  uname -r
  echo

  echo "== pci devices =="
  lspci -nn | grep -Ei '7341|vga|display|audio' || true
  echo

  echo "== pci tree =="
  lspci -tv || true
  echo

  echo "== kfd / amdgpu log hints =="
  sudo journalctl -k -b 0 | grep -Ein 'kfd|amdgpu|7341|atomics|navi14' || true
  echo

  echo "== firmware info: $pci_bdf =="
  sudo cat "/sys/kernel/debug/dri/$pci_bdf/amdgpu_firmware_info" || true
  echo

  if command -v rocminfo >/dev/null 2>&1; then
    echo "== rocminfo hints =="
    rocminfo | grep -E 'gfx1012|W5500|Agent' || true
    echo
  fi

  if command -v rocm-smi >/dev/null 2>&1; then
    echo "== rocm-smi =="
    rocm-smi || true
    echo
  fi
}

cmd_backup_firmware() {
  local out=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) out="${2:?}"; shift 2 ;;
      *) die "unknown backup-firmware arg: $1" ;;
    esac
  done
  if [[ -z "$out" ]]; then
    out="/home/max/firmware-backups/navi14-$(date +%Y%m%d-%H%M%S)"
  fi
  echo "backing up to: $out"
  sudo mkdir -p "$out"
  sudo cp -a /lib/firmware/amdgpu/navi14_* "$out"/ 2>/dev/null || true
}

cmd_install_firmware_overlay() {
  local from="" kernel="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from="${2:?}"; shift 2 ;;
      --kernel) kernel="${2:?}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) die "unknown install-firmware-overlay arg: $1" ;;
    esac
  done
  if [[ -z "$from" ]]; then
    from="$BUNDLED_NAVI14_DIR"
  fi
  [[ -d "$from" ]] || die "firmware source dir does not exist: $from"
  kernel="${kernel:-$(uname -r)}"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$from" -maxdepth 1 -type f -name 'navi14_*.bin' -print0 | sort -z)
  [[ ${#files[@]} -gt 0 ]] || die "no navi14_*.bin found in $from"

  echo "source dir: $from"
  if [[ "$from" == "$BUNDLED_NAVI14_DIR" ]]; then
    echo "source kind: bundled repository firmware"
  else
    echo "source kind: external firmware directory"
  fi
  echo "target dir: /lib/firmware/amdgpu"
  echo "kernel: $kernel"
  printf 'files:\n'
  printf '  %s\n' "${files[@]}"

  if [[ $dry_run -eq 1 ]]; then
    echo "dry-run: no files copied, no initramfs rebuild"
    return 0
  fi

  sudo mkdir -p /lib/firmware/amdgpu
  for f in "${files[@]}"; do
    sudo install -m 0644 "$f" "/lib/firmware/amdgpu/$(basename "$f")"
  done
  sudo update-initramfs -u -k "$kernel"
}

cmd_link_rocm7_gfx1012() {
  local rocm6="" rocm7="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rocm6-lib) rocm6="${2:?}"; shift 2 ;;
      --rocm7-lib) rocm7="${2:?}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) die "unknown link-rocm7-gfx1012 arg: $1" ;;
    esac
  done
  [[ -d "$rocm6" ]] || die "rocm6 lib dir does not exist: $rocm6"
  [[ -n "$rocm7" ]] || die "--rocm7-lib is required"

  mkdir -p "$rocm7"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$rocm6" -maxdepth 1 -type f \( -name '*gfx1012*' -o -name 'TensileLibrary*gfx1012*' -o -name '*lazy*gfx1012*' \) -print0 | sort -z)
  [[ ${#files[@]} -gt 0 ]] || die "no gfx1012 rocBLAS/Tensile files found in $rocm6"

  echo "rocm6 source: $rocm6"
  echo "rocm7 target: $rocm7"
  echo "matching files: ${#files[@]}"

  if [[ $dry_run -eq 1 ]]; then
    printf 'would link:\n'
    printf '  %s\n' "${files[@]}"
    return 0
  fi

  for f in "${files[@]}"; do
    ln -sf "$f" "$rocm7/$(basename "$f")"
  done
}

cmd_print_build_rocm6() {
  cat <<'EOF'
cmake -S /path/to/llama.cpp -B build-rocm-gfx1012 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx1012 \
  -DGPU_TARGETS=gfx1012 \
  -DCMAKE_HIP_ARCHITECTURES=gfx1012 \
  -DGGML_HIP_GRAPHS=ON \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm-gfx1012 -j
EOF
}

cmd_print_build_rocm7() {
  cat <<'EOF'
cmake -S /path/to/llama.cpp -B build-rocm7-gfx1012 \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx1012 \
  -DGPU_TARGETS=gfx1012 \
  -DCMAKE_HIP_ARCHITECTURES=gfx1012 \
  -DGGML_HIP_MMQ_MFMA=ON \
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm7-gfx1012 -j
EOF
}

cmd_print_paths() {
  cat <<EOF
project_root=$PROJECT_ROOT
script_dir=$SCRIPT_DIR
bundled_navi14_dir=$BUNDLED_NAVI14_DIR
EOF
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 1; }
  local cmd="$1"; shift
  case "$cmd" in
    doctor) cmd_doctor "$@" ;;
    backup-firmware) cmd_backup_firmware "$@" ;;
    install-firmware-overlay) cmd_install_firmware_overlay "$@" ;;
    link-rocm7-gfx1012) cmd_link_rocm7_gfx1012 "$@" ;;
    print-build-rocm6) cmd_print_build_rocm6 ;;
    print-build-rocm7) cmd_print_build_rocm7 ;;
    print-paths) cmd_print_paths ;;
    -h|--help|help) usage ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
