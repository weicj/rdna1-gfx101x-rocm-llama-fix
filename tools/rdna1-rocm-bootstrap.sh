#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

default_arch_for_asic() {
  case "${1:-}" in
    navi10) echo gfx1010 ;;
    navi12) echo gfx1011 ;;
    navi14) echo gfx1012 ;;
    *) return 1 ;;
  esac
}

default_pci_id_for_asic() {
  case "${1:-}" in
    navi10) echo 731F ;;
    navi12) echo 7360 ;;
    navi14) echo 7341 ;;
    *) return 1 ;;
  esac
}

bundled_dir_for_asic() {
  echo "$SCRIPT_DIR/assets/firmware/$1"
}

usage() {
  cat <<'EOF'
RDNA1 ROCm bootstrap helper

Usage:
  rdna1-rocm-bootstrap.sh [--asic navi10|navi12|navi14] doctor [--pci-bdf BDF] [--pci-id HEX] [--marketing STRING]
  rdna1-rocm-bootstrap.sh [--asic navi10|navi12|navi14] backup-firmware [--out DIR]
  rdna1-rocm-bootstrap.sh [--asic navi10|navi12|navi14] install-firmware-overlay [--from DIR] [--kernel KVER] [--dry-run]
  rdna1-rocm-bootstrap.sh [--arch gfx1010|gfx1011|gfx1012] link-rocm7-arch --rocm6-lib DIR --rocm7-lib DIR [--dry-run]
  rdna1-rocm-bootstrap.sh [--arch gfx1010|gfx1011|gfx1012] print-build-rocm6
  rdna1-rocm-bootstrap.sh [--arch gfx1010|gfx1011|gfx1012] print-build-rocm7
  rdna1-rocm-bootstrap.sh print-paths

Compatibility aliases:
  rdna1-rocm-bootstrap.sh link-rocm7-gfx1012 ...

Notes:
  - This is a staged bootstrap helper, not a blind magic one-click script.
  - Firmware replacement and initramfs rebuild still require judgment and reboot discipline.
  - If --from is omitted for install-firmware-overlay, bundled firmware for the selected ASIC is used.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

ASIC=""
ARCH=""

resolve_arch() {
  if [[ -n "$ARCH" ]]; then
    echo "$ARCH"
    return 0
  fi
  [[ -n "$ASIC" ]] || die "either --arch or --asic is required"
  default_arch_for_asic "$ASIC" || die "unknown asic: $ASIC"
}

resolve_asic() {
  if [[ -n "$ASIC" ]]; then
    echo "$ASIC"
    return 0
  fi
  case "${ARCH:-}" in
    gfx1010) echo navi10 ;;
    gfx1011) echo navi12 ;;
    gfx1012) echo navi14 ;;
    *) die "either --asic or a known --arch is required" ;;
  esac
}

cmd_doctor() {
  local asic arch pci_bdf="0000:05:00.0" pci_id marketing=""
  asic="$(resolve_asic)"
  arch="$(resolve_arch)"
  pci_id="$(default_pci_id_for_asic "$asic" || true)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pci-bdf) pci_bdf="${2:?}"; shift 2 ;;
      --pci-id) pci_id="${2:?}"; shift 2 ;;
      --marketing) marketing="${2:?}"; shift 2 ;;
      *) die "unknown doctor arg: $1" ;;
    esac
  done

  need_cmd lspci
  need_cmd uname

  local grep_hint
  grep_hint="${pci_id}|${asic}|${arch}"
  if [[ -n "$marketing" ]]; then
    grep_hint="${grep_hint}|${marketing}"
  fi

  echo "== target =="
  echo "asic=$asic"
  echo "arch=$arch"
  echo "pci_id=${pci_id:-unknown}"
  echo "pci_bdf=$pci_bdf"
  [[ -n "$marketing" ]] && echo "marketing=$marketing"
  echo

  echo "== kernel =="
  uname -r
  echo

  echo "== pci devices =="
  lspci -nn | grep -Ei "$grep_hint|vga|display|audio" || true
  echo

  echo "== pci tree =="
  lspci -tv || true
  echo

  echo "== kfd / amdgpu log hints =="
  sudo journalctl -k -b 0 | grep -Ein "kfd|amdgpu|${pci_id}|${asic}|${arch}|atomics" || true
  echo

  echo "== firmware info: $pci_bdf =="
  sudo cat "/sys/kernel/debug/dri/$pci_bdf/amdgpu_firmware_info" || true
  echo

  if command -v rocminfo >/dev/null 2>&1; then
    echo "== rocminfo hints =="
    rocminfo | grep -E "$arch|${marketing:-$asic}|Agent" || true
    echo
  fi

  if command -v rocm-smi >/dev/null 2>&1; then
    echo "== rocm-smi =="
    rocm-smi || true
    echo
  fi
}

cmd_backup_firmware() {
  local asic out=""
  asic="$(resolve_asic)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) out="${2:?}"; shift 2 ;;
      *) die "unknown backup-firmware arg: $1" ;;
    esac
  done
  if [[ -z "$out" ]]; then
    out="/home/max/firmware-backups/${asic}-$(date +%Y%m%d-%H%M%S)"
  fi
  echo "backing up $asic firmware to: $out"
  sudo mkdir -p "$out"
  sudo cp -a "/lib/firmware/amdgpu/${asic}_"* "$out"/ 2>/dev/null || true
}

cmd_install_firmware_overlay() {
  local asic from="" kernel="" dry_run=0
  asic="$(resolve_asic)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from="${2:?}"; shift 2 ;;
      --kernel) kernel="${2:?}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) die "unknown install-firmware-overlay arg: $1" ;;
    esac
  done
  if [[ -z "$from" ]]; then
    from="$(bundled_dir_for_asic "$asic")"
  fi
  [[ -d "$from" ]] || die "firmware source dir does not exist: $from"
  kernel="${kernel:-$(uname -r)}"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$from" -maxdepth 1 \( -type f -o -type l \) -name "${asic}_*.bin" -print0 | sort -z)
  [[ ${#files[@]} -gt 0 ]] || die "no ${asic}_*.bin found in $from"

  echo "asic: $asic"
  echo "source dir: $from"
  if [[ "$from" == "$(bundled_dir_for_asic "$asic")" ]]; then
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

cmd_link_rocm7_arch() {
  local arch rocm6="" rocm7="" dry_run=0
  arch="$(resolve_arch)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rocm6-lib) rocm6="${2:?}"; shift 2 ;;
      --rocm7-lib) rocm7="${2:?}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) die "unknown link-rocm7-arch arg: $1" ;;
    esac
  done
  [[ -d "$rocm6" ]] || die "rocm6 lib dir does not exist: $rocm6"
  [[ -n "$rocm7" ]] || die "--rocm7-lib is required"

  mkdir -p "$rocm7"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$rocm6" -maxdepth 1 -type f \( -name "*${arch}*" -o -name "TensileLibrary*${arch}*" -o -name "*lazy*${arch}*" \) -print0 | sort -z)
  [[ ${#files[@]} -gt 0 ]] || die "no ${arch} rocBLAS/Tensile files found in $rocm6"

  echo "arch: $arch"
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
  local arch
  arch="$(resolve_arch)"
  cat <<EOF
cmake -S /path/to/llama.cpp -B build-rocm-${arch} \\
  -DCMAKE_BUILD_TYPE=Release \\
  -DGGML_HIP=ON \\
  -DAMDGPU_TARGETS=${arch} \\
  -DGPU_TARGETS=${arch} \\
  -DCMAKE_HIP_ARCHITECTURES=${arch} \\
  -DGGML_HIP_GRAPHS=ON \\
  -DGGML_HIP_MMQ_MFMA=ON \\
  -DGGML_HIP_NO_VMM=ON \\
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm-${arch} -j
EOF
}

cmd_print_build_rocm7() {
  local arch
  arch="$(resolve_arch)"
  cat <<EOF
cmake -S /path/to/llama.cpp -B build-rocm7-${arch} \\
  -DCMAKE_BUILD_TYPE=Release \\
  -DGGML_HIP=ON \\
  -DAMDGPU_TARGETS=${arch} \\
  -DGPU_TARGETS=${arch} \\
  -DCMAKE_HIP_ARCHITECTURES=${arch} \\
  -DGGML_HIP_MMQ_MFMA=ON \\
  -DGGML_HIP_NO_VMM=ON \\
  -DGGML_HIP_ROCWMMA_FATTN=OFF

cmake --build build-rocm7-${arch} -j
EOF
}

cmd_print_paths() {
  cat <<EOF
project_root=$PROJECT_ROOT
script_dir=$SCRIPT_DIR
bundled_navi10_dir=$(bundled_dir_for_asic navi10)
bundled_navi12_dir=$(bundled_dir_for_asic navi12)
bundled_navi14_dir=$(bundled_dir_for_asic navi14)
EOF
}

main() {
  local cmd
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --asic) ASIC="${2:?}"; shift 2 ;;
      --arch) ARCH="${2:?}"; shift 2 ;;
      --help|-h|help) usage; exit 0 ;;
      *) break ;;
    esac
  done
  [[ $# -gt 0 ]] || { usage; exit 1; }
  cmd="$1"; shift
  case "$cmd" in
    doctor) cmd_doctor "$@" ;;
    backup-firmware) cmd_backup_firmware "$@" ;;
    install-firmware-overlay) cmd_install_firmware_overlay "$@" ;;
    link-rocm7-arch) cmd_link_rocm7_arch "$@" ;;
    link-rocm7-gfx1012) ARCH="gfx1012"; ASIC="${ASIC:-navi14}"; cmd_link_rocm7_arch "$@" ;;
    print-build-rocm6) cmd_print_build_rocm6 ;;
    print-build-rocm7) cmd_print_build_rocm7 ;;
    print-paths) cmd_print_paths ;;
    -h|--help|help) usage ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
