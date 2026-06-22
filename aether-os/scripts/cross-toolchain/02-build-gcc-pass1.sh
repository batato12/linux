#!/bin/bash
# Aether OS - Build Cross-Toolchain Script 02: GCC Pass 1
# Compila GCC pela primeira vez (apenas compilador C, sem bibliotecas)
# Esta versão inicial é necessária para compilar a glibc

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_TOOLS="$AETHER_ROOT/tools"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export AETHER_PATCHES="$AETHER_ROOT/patches"
export PATH="$AETHER_TOOLS/bin:$PATH"

# Versões
GCC_VERSION="13.2.0"
MPFR_VERSION="4.2.1"
MPC_VERSION="1.3.1"
GMP_VERSION="6.3.0"

GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
MPFR_URL="https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz"
MPC_URL="https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz"
GMP_URL="https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz"

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Função de erro
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

log "Iniciando build do GCC ${GCC_VERSION} (Pass 1)..."

# Verificar se binutils está disponível
if ! command -v x86_64-aether-linux-gnu-ld &> /dev/null; then
    die "Binutils não encontrado. Execute 01-build-binutils.sh primeiro."
fi

# Download das dependências
log "Baixando dependências do GCC..."
cd "$AETHER_SOURCES"

for pkg in GCC MPFR MPC GMP; do
    var_name="${pkg}_URL"
    url="${!var_name}"
    if [ ! -f "$AETHER_SOURCES/${pkg,,}-${!${pkg}_VERSION}.tar."* ]; then
        wget -c "$url" -P "$AETHER_SOURCES" || die "Falha no download de ${pkg}"
    fi
done

# Extrair GCC
log "Extraindo GCC..."
tar xf "gcc-${GCC_VERSION}.tar.xz" || die "Falha na extração do GCC"
cd "gcc-${GCC_VERSION}"

# Extrair dependências dentro do diretório do GCC
log "Extraindo dependências no diretório do GCC..."
tar xf "../mpfr-${MPFR_VERSION}.tar.xz" && mv "mpfr-${MPFR_VERSION}" mpfr || die "Falha ao extrair MPFR"
tar xf "../mpc-${MPC_VERSION}.tar.gz" && mv "mpc-${MPC_VERSION}" mpc || die "Falha ao extrair MPC"
tar xf "../gmp-${GMP_VERSION}.tar.xz" && mv "gmp-${GMP_VERSION}" gmp || die "Falha ao extrair GMP"

# Configurar e compilar GCC Pass 1
BUILD_DIR="$AETHER_SOURCES/gcc-pass1-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log "Configurando GCC (Pass 1)..."
"$AETHER_SOURCES/gcc-${GCC_VERSION}/configure" \
    --prefix="$AETHER_TOOLS" \
    --target=x86_64-aether-linux-gnu \
    --disable-nls \
    --enable-languages=c,c++ \
    --disable-libstdcxx-pch \
    --disable-multilib \
    --disable-bootstrap \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libcilkrts \
    --disable-decimal-float \
    --disable-libsanitizer \
    --with-gmp="$AETHER_TOOLS" \
    --with-mpfr="$AETHER_TOOLS" \
    --with-mpc="$AETHER_TOOLS" || die "Falha na configuração do GCC"

log "Compilando GCC (Pass 1) - isso pode demorar..."
make -j"$(nproc)" all-gcc all-target-libgcc || die "Falha na compilação do GCC"

log "Instalando GCC (Pass 1)..."
make install-gcc install-target-libgcc || die "Falha na instalação do GCC"

# Limpeza
log "Limpando arquivos de build..."
rm -rf "$BUILD_DIR"
rm -rf "$AETHER_SOURCES/gcc-${GCC_VERSION}"

log "GCC Pass 1 compilado e instalado com sucesso!"
log "Próximo passo: Linux Headers"
