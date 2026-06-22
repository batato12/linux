#!/bin/bash
# Aether OS - Build Cross-Toolchain Script 05: GCC Pass 2 (Completo)
# Compila GCC completo com todas as linguagens e bibliotecas

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_TOOLS="$AETHER_ROOT/tools"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export AETHER_PATCHES="$AETHER_ROOT/patches"
export PATH="$AETHER_TOOLS/bin:$PATH"

# Versões
GCC_VERSION="13.2.0"
ISL_VERSION="0.26"
ISL_URL="https://libisl.org/isl-${ISL_VERSION}.tar.xz"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de erro
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

log "Iniciando build do GCC ${GCC_VERSION} (Pass 2 - Completo)..."

# Verificar dependências
if ! command -v x86_64-aether-linux-gnu-gcc &> /dev/null; then
    die "GCC Pass 1 não encontrado."
fi
if [ ! -f "$AETHER_ROOT/rootfs/usr/include/stdio.h" ]; then
    die "Headers da glibc não encontrados. Execute 04-build-glibc.sh primeiro."
fi

# Download do ISL (Integer Set Library) se necessário
cd "$AETHER_SOURCES"
if [ ! -f "isl-${ISL_VERSION}.tar.xz" ]; then
    log "Baixando ISL..."
    wget -c "$ISL_URL" -P "$AETHER_SOURCES" || die "Falha no download do ISL"
fi

# Extrair GCC
log "Extraindo GCC..."
tar xf "gcc-${GCC_VERSION}.tar.xz" || die "Falha na extração do GCC"
cd "gcc-${GCC_VERSION}"

# Extrair ISL dentro do diretório do GCC
log "Extraindo ISL no diretório do GCC..."
tar xf "../isl-${ISL_VERSION}.tar.xz" && mv "isl-${ISL_VERSION}" isl || die "Falha ao extrair ISL"

# Configurar e compilar GCC Pass 2
BUILD_DIR="$AETHER_SOURCES/gcc-pass2-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log "Configurando GCC (Pass 2)..."
"$AETHER_SOURCES/gcc-${GCC_VERSION}/configure" \
    --prefix="$AETHER_TOOLS" \
    --target=x86_64-aether-linux-gnu \
    --with-local-prefix="$AETHER_ROOT/rootfs/usr/local" \
    --with-native-system-header-dir=/usr/include \
    --enable-languages=c,c++ \
    --disable-libstdcxx-pch \
    --disable-multilib \
    --disable-bootstrap \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-checking=release \
    --enable-lto \
    --enable-graphite \
    --enable-cet=host \
    --with-isl="$AETHER_TOOLS" \
    --with-gmp="$AETHER_TOOLS" \
    --with-mpfr="$AETHER_TOOLS" \
    --with-mpc="$AETHER_TOOLS" || die "Falha na configuração do GCC"

log "Compilando GCC (Pass 2) - isso pode demorar bastante..."
make -j"$(nproc)" || die "Falha na compilação do GCC"

log "Instalando GCC (Pass 2)..."
make install || die "Falha na instalação do GCC"

# Criar link simbólico para o compilador
ln -sv x86_64-aether-linux-gnu-gcc "$AETHER_TOOLS/bin/cc" || die "Falha ao criar link cc"

# Limpeza
log "Limpando arquivos de build..."
rm -rf "$BUILD_DIR"
rm -rf "$AETHER_SOURCES/gcc-${GCC_VERSION}"

log "GCC Pass 2 compilado e instalado com sucesso!"
log ""
log "=== Toolchain Cross-Compilation Completa! ==="
log "Próximos passos: Compilar sistema base (scripts/system-build/)"
