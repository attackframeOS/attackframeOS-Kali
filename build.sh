#!/usr/bin/env bash
# AttackFrame OS (Kali edition) — ISO build entry point (Docker + Docker Compose).
#
# Builds a Kali-based live/install ISO inside a privileged builder container
# (docker-compose.yml). Kali is the host OS: its tools are installed natively.
# BlackArch (Arch/pacman) can't share a Debian root, so it runs as a Docker
# (distrobox) container. Its image is built here on your Docker daemon and
# shipped inside the ISO, so `blackarch <tool>` works offline on the live system.
#
#   ./build.sh                          # TOOLSET=core   (curated Kali tools + BlackArch image)
#   TOOLSET=minimal ./build.sh          # Kali desktop only; BlackArch pulled on first use
#   TOOLSET=large ./build.sh            # + kali-linux-default + BlackArch groups in BA_GROUPS
#   LIVE_PASSWORD=s3cret ./build.sh     # live user ghost's password (default: ghost)
#
# Needs: docker + the compose plugin (`docker compose`) or docker-compose v1.
# Output: ./out/attackframe-kali-<date>-amd64.iso
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

export TOOLSET="${TOOLSET:-core}"
export KALI_SUITE="${KALI_SUITE:-kali-rolling}"
case "$TOOLSET" in minimal|core|large) ;; *) echo "TOOLSET must be minimal|core|large" >&2; exit 1;; esac

command -v docker >/dev/null || { echo "docker is required: sudo apt install docker.io docker-buildx docker-compose" >&2; exit 1; }

# talk to the daemon directly when we can (docker group), otherwise via sudo
if ! docker info >/dev/null 2>&1; then
  if (( EUID != 0 )); then
    echo ">> can't reach the Docker daemon as $(id -un) — re-running with sudo"
    echo "   (or: sudo usermod -aG docker $(id -un) and log in again)"
    exec sudo --preserve-env=TOOLSET,KALI_SUITE,KALI_MIRROR,KERNEL_PKG,KALI_META,BUILDER_IMAGE,BLACKARCH_BASE,BA_GROUPS,STRAP_SHA1,SQUASHFS_LEVEL,LIVE_PASSWORD \
      "$0" "$@"
  fi
  echo "the Docker daemon isn't running: sudo systemctl enable --now docker" >&2; exit 1
fi

if docker compose version >/dev/null 2>&1; then COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null; then COMPOSE=(docker-compose)
else echo "Docker Compose is required: sudo apt install docker-compose" >&2; exit 1; fi

export HOST_UID="${SUDO_UID:-$(id -u)}" HOST_GID="${SUDO_GID:-$(id -g)}"
# separate kali-* caches so the Ubuntu-era .debs in .cache/apt never mix in
mkdir -p out .cache/kali-apt .cache/kali-debootstrap .cache/fonts .work
echo ">> AttackFrame build  base=kali:$KALI_SUITE  toolset=$TOOLSET  (${COMPOSE[*]})"

exec "${COMPOSE[@]}" -f "$HERE/docker-compose.yml" run --rm builder
