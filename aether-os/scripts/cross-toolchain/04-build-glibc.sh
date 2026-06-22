#!/bin/bash
# Aether OS - Build Cross-Toolchain Script 04: Glibc
# Compila a biblioteca C do GNU (glibc)

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_TOOLS="$AETHER_ROOT/tools"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export AETHER_PATCHES="$AETHER_ROOT/patches"
export PATH="$AETHER_TOOLS/bin:$PATH"

# Versões
GLIBC_VERSION="2.38"
GLIBC_URL="https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de erro
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

log "Iniciando build da Glibc ${GLIBC_VERSION}..."

# Verificar dependências
if ! command -v x86_64-aether-linux-gnu-gcc &> /dev/null; then
    die "GCC Pass 1 não encontrado. Execute 02-build-gcc-pass1.sh primeiro."
fi

# Download se necessário
if [ ! -f "$AETHER_SOURCES/glibc-${GLIBC_VERSION}.tar.xz" ]; then
    log "Baixando glibc..."
    wget -c "$GLIBC_URL" -P "$AETHER_SOURCES" || die "Falha no download da glibc"
fi

# Extrair
log "Extraindo glibc..."
cd "$AETHER_SOURCES"
tar xf "glibc-${GLIBC_VERSION}.tar.xz" || die "Falha na extração da glibc"

# Configurar e compilar
BUILD_DIR="$AETHER_SOURCES/glibc-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log "Configurando glibc..."
"$AETHER_SOURCES/glibc-${GLIBC_VERSION}/configure" \
    --prefix=/usr \
    --host=x86_64-aether-linux-gnu \
    --build=$(../glibc-${GLIBC_VERSION}/scripts/config.guess) \
    --disable-nls \
    --enable-stack-protector=strong \
    --enable-kernel=4.19 \
    --enable-cet \
    libc_cv_slibdir=/usr/lib || die "Falha na configuração da glibc"

log "Compilando glibc - isso pode demorar..."
make -j"$(nproc)" || die "Falha na compilação da glibc"

log "Instalando glibc..."
make install || die "Falha na instalação da glibc"

# Limpeza
log "Limpando arquivos de build..."
rm -rf "$BUILD_DIR"
rm -rf "$AETHER_SOURCES/glibc-${GLIBC_VERSION}"

log "Glibc compilada e instalada com sucesso!"
log "Próximo passo: GCC Pass 2 (completo)"
