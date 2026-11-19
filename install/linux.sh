#!/usr/bin/env bash

# Copyright (C) 2026 leechuihui
# SPDX-License-Identifier: GPL-3.0-or-later
# See LICENSE in the repository root.

set -euo pipefail

# ======================================================================================
# VARIABLES
# ======================================================================================

help_message="Usage: bash install.sh <mode>

MODES:
  server    Install server
  client    Install client
  all       Install server and client

EXAMPLES:
  bash install.sh server
  bash install.sh client
  bash install.sh all
"

# Packages that MUST be present for the build to work.
# NOTE: names here must exist on BOTH Ubuntu 22.04 and 24.04+.
# Anything renamed by the 64-bit time_t (t64) transition goes in
# apt_alternatives below instead.
apt_required=(
  build-essential
  pkg-config
  curl
  wget
  xz-utils
  ca-certificates
  git
  python3
  python3-dev
  python3-venv
  python3-pip
  sqlite3
  openssl
  libssl-dev
  libffi-dev
  libsnappy-dev
  libpango-1.0-0
  libpangoft2-1.0-0
  libcairo2
  libgdk-pixbuf-2.0-0
  bubblewrap
  # Electron runtime libraries (names stable across releases)
  libnss3
  libdrm2
  libgbm1
  libxkbcommon0
  libxcomposite1
  libxdamage1
  libxfixes3
  libxrandr2
  libx11-xcb1
  libxcb-dri3-0
)

# Packages renamed by the 64-bit time_t (t64) transition on Ubuntu 24.04+.
# Each entry is "new_name legacy_name"; the installer tries new first, then
# falls back to the legacy name. Missing both only produces a warning.
apt_alternatives=(
  "libgtk-3-0t64 libgtk-3-0"
  "libfuse2t64 libfuse2"
  "libasound2t64 libasound2"
  "libcups2t64 libcups2"
  "libatk1.0-0t64 libatk1.0-0"
  "libatk-bridge2.0-0t64 libatk-bridge2.0-0"
  "libatspi2.0-0t64 libatspi2.0-0"
  "libpulse0t64 libpulse0"
)

# Cross-compilers / toolchains. Missing ones only disable that target.
apt_optional=(
  binutils
  binutils-aarch64-linux-gnu
  binutils-mingw-w64-i686
  binutils-mingw-w64-x86-64
  gcc
  make
  gcc-aarch64-linux-gnu
  g++-aarch64-linux-gnu
  gcc-mingw-w64-i686
  gcc-mingw-w64-x86-64
  mingw-w64-i686-dev
  mingw-w64-x86-64-dev
  cargo
  rustc
  golang-go
  libgtk-3-bin
)

dnf_required=(
  gcc gcc-c++ make pkgconf-pkg-config curl wget xz ca-certificates git
  python3 python3-devel python3-pip sqlite openssl openssl-devel libffi-devel
  snappy-devel pango pango-devel cairo cairo-devel gdk-pixbuf2 gtk3 bubblewrap
)

dnf_optional=(
  binutils binutils-aarch64-linux-gnu mingw32-binutils mingw64-binutils
  gcc-aarch64-linux-gnu gcc-c++-aarch64-linux-gnu mingw32-gcc mingw64-gcc
  cargo rust golang fuse-libs
)

pacman_required=(
  base-devel pkgconf curl wget xz ca-certificates git
  python python-pip sqlite openssl libffi snappy pango cairo gdk-pixbuf2 gtk3 bubblewrap
)

pacman_optional=(
  binutils aarch64-linux-gnu-binutils mingw-w64-binutils gcc make
  aarch64-linux-gnu-gcc mingw-w64-gcc rust go fuse2
)

main_dir="$(cd "$(dirname "$0")/.." && pwd)"

# ======================================================================================
# UTILS
# ======================================================================================

update() {
  if command -v apt >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt update -y -q
  elif command -v dnf >/dev/null 2>&1; then
    dnf makecache -y -q
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm
  else
    echo "Unsupported package manager. Install the dependencies manually." >&2
    exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
  fi
}

check_sudo() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root: sudo $0 ${1:-}" >&2
    exit 1
  fi
}

validations_check() {
  check_sudo
  check_os
}

# Refuse to start when the target filesystem cannot hold the build.
# node_modules + electron + AppImage staging needs roughly 6 GB.
MIN_FREE_GB=6

check_disk_space() {
  local target avail_gb
  target="${main_dir}"
  avail_gb="$(df -Pk "$target" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}')"
  if [[ -z "$avail_gb" ]]; then
    echo "[warn] could not determine free space for $target" >&2
    return
  fi
  if (( avail_gb < MIN_FREE_GB )); then
    echo "ERROR: only ${avail_gb} GB free on the filesystem holding $target." >&2
    echo "       At least ${MIN_FREE_GB} GB is required to build the client." >&2
    echo "       Free some space and re-run." >&2
    exit 1
  fi
  echo "Free space: ${avail_gb} GB (>= ${MIN_FREE_GB} GB required)."
}

# electron-builder stages the AppImage in TMPDIR. On many distros /tmp is a
# small tmpfs, which makes packaging fail with ENOSPC even though the real
# disk has plenty of room. Point TMPDIR at a disk-backed directory instead.
prepare_build_tmpdir() {
  local tmpdir="${main_dir}/.build-tmp"
  mkdir -p "$tmpdir"
  export TMPDIR="$tmpdir"
  echo "Build TMPDIR: ${TMPDIR}"
}

restore_sudo_user_ownership() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    chown -R "${SUDO_USER}:${SUDO_USER}" "$@"
  fi
}

# True when apt knows the package name (i.e. it has a candidate).
apt_has() {
  local candidate
  candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

# Packages without which nothing else can proceed.
apt_critical=(
  build-essential
  curl
  git
  python3
  python3-venv
  python3-pip
  sqlite3
)

is_critical() {
  local needle="$1" p
  for p in "${apt_critical[@]}"; do
    [[ "$p" == "$needle" ]] && return 0
  done
  return 1
}

# Install required packages (fatal) then optional ones (warn only).
install_packages() {
  local pkg entry new_name legacy_name installed
  if command -v apt >/dev/null 2>&1; then
    # Install one at a time so a single unavailable name cannot abort the
    # whole run. Only apt_critical failures are fatal.
    for pkg in "${apt_required[@]}"; do
      if ! apt_has "$pkg"; then
        if is_critical "$pkg"; then
          echo "ERROR: required package unavailable: $pkg" >&2
          exit 1
        fi
        echo "[warn] required package unavailable: $pkg" >&2
        continue
      fi
      DEBIAN_FRONTEND=noninteractive apt install -y -q "$pkg" >/dev/null 2>&1 || {
        if is_critical "$pkg"; then
          echo "ERROR: failed to install $pkg" >&2
          exit 1
        fi
        echo "[warn] failed to install $pkg" >&2
      }
    done

    # t64-renamed packages: try the new name, fall back to the legacy one.
    for entry in "${apt_alternatives[@]}"; do
      read -r new_name legacy_name <<< "$entry"
      installed=""
      if apt_has "$new_name"; then
        installed="$new_name"
      elif apt_has "$legacy_name"; then
        installed="$legacy_name"
      fi
      if [[ -z "$installed" ]]; then
        echo "[warn] neither $new_name nor $legacy_name is available" >&2
        continue
      fi
      DEBIAN_FRONTEND=noninteractive apt install -y -q "$installed" >/dev/null 2>&1 \
        || echo "[warn] could not install $installed" >&2
    done

    for pkg in "${apt_optional[@]}"; do
      apt_has "$pkg" || { echo "[warn] optional package not available: $pkg" >&2; continue; }
      DEBIAN_FRONTEND=noninteractive apt install -y -q "$pkg" >/dev/null 2>&1 \
        || echo "[warn] optional package not available: $pkg" >&2
    done
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q "${dnf_required[@]}"
    for pkg in "${dnf_optional[@]}"; do
      dnf install -y -q "$pkg" >/dev/null 2>&1 \
        || echo "[warn] optional package not available: $pkg" >&2
    done
  elif command -v pacman >/dev/null 2>&1; then
    pacman -S --needed --noconfirm "${pacman_required[@]}"
    for pkg in "${pacman_optional[@]}"; do
      pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1 \
        || echo "[warn] optional package not available: $pkg" >&2
    done
  else
    echo "Unsupported package manager. Install the dependencies manually." >&2
    exit 1
  fi
}

node_major() {
  node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/'
}

ensure_node() {
  local major=""
  if command -v node >/dev/null 2>&1; then
    major="$(node_major)"
  fi
  if [[ -n "${major}" && "${major}" -ge 20 ]]; then
    echo "Node.js $(node -v) found."
    return
  fi

  echo "Node.js 20+ required (found: ${major:-none}). Installing Node.js 22..."
  if command -v apt >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    DEBIAN_FRONTEND=noninteractive apt install -y -q nodejs
  elif command -v dnf >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    dnf install -y -q nodejs
  elif command -v pacman >/dev/null 2>&1; then
    pacman -S --needed --noconfirm nodejs npm
  fi

  if ! command -v node >/dev/null 2>&1 || [[ "$(node_major)" -lt 20 ]]; then
    echo "ERROR: could not install Node.js 20+. Install it manually and re-run." >&2
    exit 1
  fi
  echo "Node.js $(node -v) installed."
}

ensure_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required." >&2
    exit 1
  fi
  local ver
  ver="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  echo "Python ${ver} found."
  if python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
    :
  else
    echo "ERROR: Python 3.10+ required (found ${ver})." >&2
    exit 1
  fi
  if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 13) else 1)'; then
    echo "[warn] Python 3.13 recommended; continuing with ${ver}." >&2
  fi
}

install_nim() {
  if command -v nim >/dev/null 2>&1; then
    return
  fi

  if [[ "${ID:-}" == "kali" ]]; then
    DEBIAN_FRONTEND=noninteractive apt install -y -q nim
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "[warn] curl missing, cannot install Nim. Implant builds will be unavailable." >&2
    return
  fi

  local nim_arch
  case "$(uname -m)" in
    x86_64) nim_arch="linux_x64" ;;
    *)
      echo "[warn] no Nim build for $(uname -m); implant builds will be unavailable." >&2
      return
      ;;
  esac
  local nim_ver="2.4.0"
  local nim_sha="23c1c83d9031c498a2b3ad0bce153b8905710d04eb5922cf8ebd8f9d12125743"
  local nim_src
  nim_src="$(mktemp -d)"
  if ! curl -fsSL "https://nim-lang.org/download/nim-${nim_ver}-${nim_arch}.tar.xz" -o "${nim_src}/nim.tar.xz"; then
    echo "[warn] could not download Nim; implant builds will be unavailable." >&2
    rm -rf "${nim_src}"
    return
  fi
  echo "${nim_sha}  ${nim_src}/nim.tar.xz" | sha256sum -c -
  tar -xJf "${nim_src}/nim.tar.xz" -C "${nim_src}"
  rm -rf /opt/nim
  mv "${nim_src}/nim-${nim_ver}" /opt/nim
  mkdir -p /usr/local/bin
  local bin
  for bin in /opt/nim/bin/*; do
    if [[ -f "${bin}" || -L "${bin}" ]]; then
      ln -sfn "${bin}" "/usr/local/bin/$(basename "${bin}")"
    fi
  done
  rm -rf "${nim_src}"
}

electron_files_setup() {
  local app_id="com.umbra.app"
  local gui_dir="${main_dir}/client/gui"
  local public="${gui_dir}/public"
  local home_dir="${HOME}"
  local owner=""

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    home_dir="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
    owner="${SUDO_USER}:${SUDO_USER}"
  fi
  if [[ -z "${home_dir}" || ! -d "${home_dir}" ]]; then
    echo "Could not resolve the user home for the desktop entry." >&2
    exit 1
  fi

  local icon_root="${home_dir}/.local/share/icons/hicolor"
  local desktop_dir="${home_dir}/.local/share/applications"
  local desktop_file="${desktop_dir}/${app_id}.desktop"
  local sizes=(16 24 32 48 64 128 256)
  local master="${public}/icon_256x256.png"
  local size src dest

  for size in "${sizes[@]}"; do
    src="${public}/icon_${size}x${size}.png"
    if [[ ! -f "${src}" && -f "${master}" ]]; then
      if command -v magick >/dev/null 2>&1; then
        magick "${master}" -filter Lanczos -resize "${size}x${size}" "${src}"
      elif command -v convert >/dev/null 2>&1; then
        convert "${master}" -filter Lanczos -resize "${size}x${size}" "${src}"
      fi
    fi
    [[ -f "${src}" ]] || continue
    dest="${icon_root}/${size}x${size}/apps"
    mkdir -p "${dest}"
    cp -f "${src}" "${dest}/${app_id}.png"
    if [[ -n "${owner}" ]]; then
      chown "${owner}" "${dest}/${app_id}.png" "${dest}" "${icon_root}/${size}x${size}"
    fi
  done

  local appimage=""
  local found=()
  shopt -s nullglob
  found=("${gui_dir}/dist/"*.AppImage)
  shopt -u nullglob
  if [[ ${#found[@]} -eq 0 ]]; then
    echo "No AppImage in ${gui_dir}/dist/." >&2
    exit 1
  fi
  appimage="$(readlink -f "${found[0]}")"
  if [[ ! -f "${appimage}" ]]; then
    echo "Not found: ${appimage}" >&2
    exit 1
  fi

  mkdir -p "${desktop_dir}"
  cat > "${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=UMBRA
Comment=UMBRA
Exec="${appimage}" %U
Path=$(dirname "${appimage}")
Icon=${app_id}
Terminal=false
Categories=Utility;
StartupNotify=true
StartupWMClass=${app_id}
EOF

  if [[ -n "${owner}" ]]; then
    chown "${owner}" \
      "${home_dir}/.local" \
      "${home_dir}/.local/share" \
      "${home_dir}/.local/share/icons" \
      "${icon_root}" \
      "${desktop_dir}" \
      "${desktop_file}"
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "${icon_root}" >/dev/null 2>&1 || true
  fi
}

# ======================================================================================
# CLIENT INSTALLATION
# ======================================================================================

install_client() {
  local gui_dir="${main_dir}/client/gui"

  # Base tools (curl, git, build-essential) are needed before ensure_node,
  # which downloads the NodeSource setup script with curl.
  install_packages
  ensure_node
  check_disk_space
  prepare_build_tmpdir

  cd "${gui_dir}"
  npm install --no-audit
  npm run dist
  electron_files_setup

  # TMPDIR staging directory is no longer needed once packaging succeeded.
  rm -rf "${main_dir}/.build-tmp" 2>/dev/null || true

  restore_sudo_user_ownership "${main_dir}/client"
}

# ======================================================================================
# SERVER INSTALLATION
# ======================================================================================

install_server() {
  install_packages
  install_nim
  ensure_python

  # pip packages install
  cd "${main_dir}/server"
  python3 -m venv venv
  # shellcheck source=/dev/null
  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt

  # sgn build (encoder)
  cd "${main_dir}/server/infra/bin/encoders/sgn"
  if command -v cargo >/dev/null 2>&1; then
    ./build.sh
  else
    echo "[warn] cargo missing; SGN encoder will be unavailable." >&2
  fi

  # golang.org/x/sys for the mac implants
  local go_bin
  go_bin="$(command -v go || true)"
  if [[ -n "${go_bin}" ]]; then
    local mod_dir
    for mod_dir in \
      "${main_dir}/implants/mac/loader" \
      "${main_dir}/implants/mac/stageless"
    do
      if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "${SUDO_USER}" -H "${go_bin}" -C "${mod_dir}" mod tidy \
          || echo "[warn] go mod tidy failed in ${mod_dir}" >&2
      else
        "${go_bin}" -C "${mod_dir}" mod tidy \
          || echo "[warn] go mod tidy failed in ${mod_dir}" >&2
      fi
    done
  else
    echo "[warn] go missing; macOS implant modules will not be prepared." >&2
  fi

  # sqlite database creation
  cd "${main_dir}/server/infra/database"
  sqlite3 database.db < init.sql

  restore_sudo_user_ownership "${main_dir}/server" "${main_dir}/implants"
}

# ======================================================================================
# MAIN ENTRYPOINT
# ======================================================================================

if [[ "${1:-}" = "server" || "${1:-}" = "client" || "${1:-}" = "all" ]]; then
  check_sudo "${1:-}"
  check_os
fi

if [ "${1:-}" = "server" ]; then
  update
  validations_check
  install_server
elif [ "${1:-}" = "client" ]; then
  update
  validations_check
  install_client
elif [ "${1:-}" = "all" ]; then
  update
  validations_check
  install_server
  install_client
else
  echo "$help_message" >&2
  exit 1
fi
