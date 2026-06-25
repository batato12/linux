#!/bin/bash
# Aether OS - Construir Sistema Base com Debootstrap (Versão Otimizada para Espaço)
# Cria rootfs baseado em Ubuntu usando debootstrap com mínimo de pacotes

set -euo pipefail

export AETHER_ROOT="${AETHER_ROOT:-/workspace/aether-os}"
SCRIPT_DIR="$AETHER_ROOT/scripts"
ROOTFS_DIR="$AETHER_ROOT/rootfs"
LOG_FILE="$AETHER_ROOT/build-debootstrap.log"

# Ubuntu 22.04 LTS para melhor compatibilidade
DISTRO="ubuntu"
SUITE="jammy"
MIRROR="http://archive.ubuntu.com/ubuntu"
ARCH="amd64"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() { echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}\n${CYAN}  $*${NC}\n${CYAN}═══════════════════════════════════════════════════════════${NC}\n"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }

check_prerequisites() {
    log_header "Verificando Pré-requisitos"
    local missing=()
    for tool in debootstrap wget tar xz gzip fakeroot; do
        command -v "$tool" &> /dev/null || missing+=("$tool")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Ferramentas faltando: ${missing[*]}"
        exit 1
    fi
    [ "$EUID" -ne 0 ] && log_error "Execute como root" && exit 1
    log_success "Pré-requisitos OK!"
}

cleanup_rootfs() {
    log_header "Limpando Rootfs Anterior"
    [ -d "$ROOTFS_DIR" ] && rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    log_success "Diretório rootfs criado: $ROOTFS_DIR"
}

run_debootstrap() {
    log_header "Executando Debootstrap"
    log_step "Distribuição: $DISTRO $SUITE"
    log_step "Mirror: $MIRROR"
    log_step "Arquitetura: $ARCH"
    log_step "Destino: $ROOTFS_DIR"
    
    local components="main,universe"
    local include_packages="bash,coreutils,util-linux,tar,gzip,wget,nano,curl,ca-certificates,lsb-release"
    local exclude_packages="apt,dpkg,man-db,vim,systemd,dbus,udev"
    
    log_step "Pacotes: $include_packages"
    log_step "Variant: minbase"
    
    if ! debootstrap --arch="$ARCH" --include="$include_packages" --exclude="$exclude_packages" --components="$components" --variant=minbase "$SUITE" "$ROOTFS_DIR" "$MIRROR"; then
        log_error "Falha no debootstrap"
        return 1
    fi
    log_success "Debootstrap concluído!"
}

configure_sources() {
    log_header "Configurando Repositórios"
    cat > "$ROOTFS_DIR/etc/apt/sources.list" << SOURCES
deb http://archive.ubuntu.com/ubuntu jammy main universe
deb http://archive.ubuntu.com/ubuntu jammy-updates main universe
deb http://archive.ubuntu.com/ubuntu jammy-security main universe
SOURCES
    log_success "Repositórios configurados"
}

configure_base_system() {
    log_header "Configurando Sistema Base"
    mount -t proc proc "$ROOTFS_DIR/proc" 2>/dev/null || true
    mount -t sysfs sys "$ROOTFS_DIR/sys" 2>/dev/null || true
    mount -o bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
    
    chroot "$ROOTFS_DIR" apt-get update || true
    chroot "$ROOTFS_DIR" locale-gen en_US.UTF-8 || true
    echo "LANG=en_US.UTF-8" > "$ROOTFS_DIR/etc/default/locale"
    echo "aether-os" > "$ROOTFS_DIR/etc/hostname"
    echo "127.0.0.1 localhost" > "$ROOTFS_DIR/etc/hosts"
    echo "127.0.1.1 aether-os" >> "$ROOTFS_DIR/etc/hosts"
    
    umount "$ROOTFS_DIR/proc" 2>/dev/null || true
    umount "$ROOTFS_DIR/sys" 2>/dev/null || true
    umount "$ROOTFS_DIR/dev" 2>/dev/null || true
    log_success "Sistema base configurado"
}

show_summary() {
    log_header "Resumo"
    echo -e "${GREEN}Sistema base construído!${NC}"
    echo "Rootfs: $ROOTFS_DIR"
    echo "Tamanho: $(du -sh "$ROOTFS_DIR" 2>/dev/null | cut -f1)"
    echo ""
    echo "Para testar: chroot $ROOTFS_DIR /bin/bash"
}

main() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Aether OS - Debootstrap (Ubuntu Minimal)    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}${NC}"
    
    check_prerequisites
    cleanup_rootfs
    run_debootstrap
    configure_sources
    configure_base_system
    show_summary
}

main "$@"
