#!/bin/bash
# Aether OS - Build Cross-Toolchain Script 01: Binutils
# Compila binutils (assembler, linker e ferramentas relacionadas)

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_TOOLS="$AETHER_ROOT/tools"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export AETHER_PATCHES="$AETHER_ROOT/patches"
export PATH="$AETHER_TOOLS/bin:$PATH"

# Versões
BINUTILS_VERSION="2.41"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de erro
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

# Criar diretórios necessários
mkdir -p "$AETHER_TOOLS" "$AETHER_SOURCES"

log "Iniciando build do binutils ${BINUTILS_VERSION}..."

# Download se necessário
if [ ! -f "$AETHER_SOURCES/binutils-${BINUTILS_VERSION}.tar.xz" ]; then
    log "Baixando binutils..."
    wget -c "$BINUTILS_URL" -P "$AETHER_SOURCES" || die "Falha no download do binutils"
fi

# Extrair
log "Extraindo binutils..."
cd "$AETHER_SOURCES"
tar xf "binutils-${BINUTILS_VERSION}.tar.xz" || die "Falha na extração"

# Configurar e compilar
BUILD_DIR="$AETHER_SOURCES/binutils-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log "Configurando binutils..."
"$AETHER_SOURCES/binutils-${BINUTILS_VERSION}/configure" \
    --prefix="$AETHER_TOOLS" \
    --with-sysroot="$AETHER_ROOT/rootfs" \
    --target=x86_64-aether-linux-gnu \
    --disable-nls \
    --disable-werror \
    --enable-gold \
    --enable-plugins \
    --enable-lto || die "Falha na configuração do binutils"

log "Compilando binutils..."
make -j"$(nproc)" || die "Falha na compilação do binutils"

log "Instalando binutils..."
make install || die "Falha na instalação do binutils"

# Limpeza
log "Limpando arquivos de build..."
rm -rf "$BUILD_DIR"
rm -rf "$AETHER_SOURCES/binutils-${BINUTILS_VERSION}"

log "Binutils compilado e instalado com sucesso!"
log "Próximo passo: GCC Pass 1"
