#!/bin/bash
# Aether OS - Build Cross-Toolchain Script 03: Linux Headers
# Instala headers do kernel Linux para compilação da glibc

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

log "Iniciando instalação dos Linux Headers ${KERNEL_VERSION}..."

# Download se necessário
if [ ! -f "$AETHER_SOURCES/linux-${KERNEL_VERSION}.tar.xz" ]; then
    log "Baixando kernel Linux..."
    wget -c "$KERNEL_URL" -P "$AETHER_SOURCES" || die "Falha no download do kernel"
fi

# Extrair
log "Extraindo kernel Linux..."
cd "$AETHER_SOURCES"
tar xf "linux-${KERNEL_VERSION}.tar.xz" || die "Falha na extração do kernel"

# Compilar e instalar headers
cd "linux-${KERNEL_VERSION}"

log "Configurando headers mínimos..."
make mrproper || die "Falha no make mrproper"

# Criar configuração mínima para headers
log "Gerando configuração mínima para headers..."
make defconfig || die "Falha no make defconfig"

# Limpar configuração para manter apenas headers essenciais
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS

log "Compilando headers..."
make headers || die "Falha na compilação dos headers"

log "Instalando headers..."
mkdir -p "$AETHER_ROOT/rootfs/usr"
make INSTALL_HDR_PATH="$AETHER_ROOT/rootfs/usr" headers_install || die "Falha na instalação dos headers"

# Limpeza
log "Limpando arquivos de build..."
cd "$AETHER_SOURCES"
rm -rf "linux-${KERNEL_VERSION}"

log "Linux Headers instalados com sucesso!"
log "Próximo passo: Glibc"
