#!/bin/bash
# Aether OS - Build Script 01: Kernel Linux
# Compila e instala o kernel Linux com configuração otimizada para desktop

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_TOOLS="$AETHER_ROOT/tools"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export AETHER_PATCHES="$AETHER_ROOT/patches"
export PATH="$AETHER_TOOLS/bin:$PATH"

# Versões
KERNEL_VERSION="6.6.15"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de erro
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

log "Iniciando build do Kernel Linux ${KERNEL_VERSION}..."

# Download se necessário
if [ ! -f "$AETHER_SOURCES/linux-${KERNEL_VERSION}.tar.xz" ]; then
    log "Baixando kernel Linux..."
    wget -c "$KERNEL_URL" -P "$AETHER_SOURCES" || die "Falha no download do kernel"
fi

# Extrair
log "Extraindo kernel Linux..."
cd "$AETHER_SOURCES"
tar xf "linux-${KERNEL_VERSION}.tar.xz" || die "Falha na extração do kernel"
cd "linux-${KERNEL_VERSION}"

# Aplicar patches customizados (se existirem)
if [ -d "$AETHER_PATCHES/kernel" ]; then
    log "Aplicando patches customizados..."
    for patch in "$AETHER_PATCHES/kernel"/*.patch; do
        if [ -f "$patch" ]; then
            log "Aplicando patch: $(basename $patch)"
            patch -p1 < "$patch" || die "Falha ao aplicar patch $(basename $patch)"
        fi
    done
fi

# Copiar configuração base otimizada
log "Configurando kernel com opções otimizadas..."
if [ -f "$AETHER_ROOT/configs/kernel/config-x86_64" ]; then
    cp "$AETHER_ROOT/configs/kernel/config-x86_64" .config
else
    # Criar configuração padrão otimizada
    log "Gerando configuração padrão otimizada..."
    make defconfig
    
    # Habilitar opções importantes para desktop
    scripts/config --enable CONFIG_PREEMPT_VOLUNTARY
    scripts/config --enable CONFIG_NO_HZ_FULL
    scripts/config --enable CONFIG_HIGHMEM64G
    scripts/config --module CONFIG_CRYPTO_ZSTD
    scripts/config --enable CONFIG_ZSWAP
    scripts/config --enable CONFIG_Z3FOLD
    scripts/config --enable CONFIG_BTRFS_FS
    scripts/config --enable CONFIG_BTRFS_FS_POSIX_ACL
    scripts/config --module CONFIG_XFS_FS
    scripts/config --module CONFIG_EXT4_FS
    scripts/config --enable CONFIG_EXT4_FS_POSIX_ACL
    scripts/config --module CONFIG_FUSE_FS
    scripts/config --enable CONFIG_AUTOFS4_FS
    scripts/config --module CONFIG_ISO9660_FS
    scripts/config --module CONFIG_UDF_FS
    
    # Suporte a hardware
    scripts/config --enable CONFIG_ACPI
    scripts/config --enable CONFIG_ACPI_BUTTON
    scripts/config --enable CONFIG_ACPI_VIDEO
    scripts/config --module CONFIG_DRM
    scripts/config --module CONFIG_DRM_AMDGPU
    scripts/config --enable CONFIG_DRM_AMDGPU_SI
    scripts/config --enable CONFIG_DRM_AMDGPU_CIK
    scripts/config --module CONFIG_DRM_I915
    scripts/config --module CONFIG_DRM_NOUVEAU
    scripts/config --module CONFIG_SENSORS_K10TEMP
    scripts/config --module CONFIG_SENSORS_CORETEMP
    
    # Rede
    scripts/config --enable CONFIG_NET
    scripts/config --enable CONFIG_INET
    scripts/config --module CONFIG_BRIDGE
    scripts/config --module CONFIG_VLAN_8021Q
    scripts/config --module CONFIG_NETFILTER
    scripts/config --module CONFIG_NF_TABLES
    scripts/config --module CONFIG_NFT_COMPAT
    scripts/config --module CONFIG_IP_NF_IPTABLES
    scripts/config --module CONFIG_IP6_NF_IPTABLES
    scripts/config --module CONFIG_NF_CONNTRACK
    scripts/config --module CONFIG_NF_CONNTRACK_EVENTS
    
    # Wireless
    scripts/config --module CONFIG_CFG80211
    scripts/config --module CONFIG_MAC80211
    scripts/config --module CONFIG_IWLMVM
    scripts/config --module CONFIG_IWLWIFI
    
    # Bluetooth
    scripts/config --module CONFIG_BT
    scripts/config --module CONFIG_BT_HCIBTUSB
    scripts/config --module CONFIG_BT_HCIUART
    
    # USB
    scripts/config --enable CONFIG_USB
    scripts/config --enable CONFIG_USB_XHCI_HCD
    scripts/config --enable CONFIG_USB_EHCI_HCD
    scripts/config --module CONFIG_USB_UAS
    scripts/config --module CONFIG_USB_STORAGE
    
    # Segurança
    scripts/config --enable CONFIG_SECURITY
    scripts/config --enable CONFIG_SECURITY_SELINUX
    scripts/config --enable CONFIG_SECURITY_APPARMOR
    scripts/config --enable CONFIG_AUDIT
    scripts/config --enable CONFIG_RANDOMIZE_BASE
    scripts/config --enable CONFIG_STACKPROTECTOR_STRONG
    
    # Systemd
    scripts/config --enable CONFIG_CGROUPS
    scripts/config --enable CONFIG_CGROUP_FREEZER
    scripts/config --enable CONFIG_CGROUP_DEVICE
    scripts/config --enable CONFIG_CGROUP_CPUACCT
    scripts/config --enable CONFIG_CGROUP_PERF
    scripts/config --enable CONFIG_NAMESPACES
    scripts/config --enable CONFIG_USER_NS
    scripts/config --enable CONFIG_SECCOMP
    scripts/config --enable CONFIG_SECCOMP_FILTER
fi

# Compilar kernel
log "Compilando kernel e módulos - isso pode demorar bastante..."
make -j"$(nproc)" bzImage modules || die "Falha na compilação do kernel"

# Instalar kernel e módulos no rootfs
log "Instalando kernel e módulos..."
mkdir -p "$AETHER_ROOT/rootfs/boot"
mkdir -p "$AETHER_ROOT/rootfs/lib/modules"

cp arch/x86/boot/bzImage "$AETHER_ROOT/rootfs/boot/vmlinuz-${KERNEL_VERSION}-aether" || die "Falha ao copiar kernel"
cp System.map "$AETHER_ROOT/rootfs/boot/System.map-${KERNEL_VERSION}-aether" || die "Falha ao copiar System.map"
cp .config "$AETHER_ROOT/rootfs/boot/config-${KERNEL_VERSION}-aether" || die "Falha ao copiar config"

make INSTALL_MOD_PATH="$AETHER_ROOT/rootfs" modules_install || die "Falha na instalação dos módulos"

# Gerar initramfs (será feito pelo script do systemd/dracut)
log "Kernel instalado em:"
log "  - $AETHER_ROOT/rootfs/boot/vmlinuz-${KERNEL_VERSION}-aether"
log "  - $AETHER_ROOT/rootfs/lib/modules/${KERNEL_VERSION}-aether/"

# Limpeza
log "Limpando arquivos de build..."
make clean

log "Kernel Linux ${KERNEL_VERSION} compilado e instalado com sucesso!"
