#!/bin/bash
# scripts/iso/build-release-iso.sh
# Gera a ISO final do Aether OS pronta para upload no GitHub Releases

set -e

SOURCE_DIR="${BASH_SOURCE%/*}"
ROOT_DIR="$(cd "$SOURCE_DIR/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ISO_DIR="$BUILD_DIR/iso_root"
OUTPUT_DIR="$BUILD_DIR/releases"
ISO_NAME="aether-os-alpha-0.1.iso"
ISO_PATH="$OUTPUT_DIR/$ISO_NAME"

VERSION="alpha-0.1"
DATE=$(date +%Y%m%d)

echo "🚀 Iniciando build da ISO de Release: $ISO_NAME"

# 1. Criar diretório de saída
mkdir -p "$OUTPUT_DIR"

# 2. Verificar pré-requisitos básicos
if [ ! -d "$ISO_DIR/boot" ]; then
    echo "❌ Erro: Diretório de boot não encontrado em $ISO_DIR/boot"
    echo "   Execute primeiro: ./scripts/system-build/01-build-kernel.sh"
    exit 1
fi

if ! command -v xorriso &> /dev/null; then
    echo "❌ Erro: xorriso não encontrado. Instale com: sudo apt install xorriso"
    exit 1
fi

# 3. Gerar ISO Híbrida (BIOS + UEFI)
echo "📀 Gerando imagem ISO híbrida..."

xorriso -as mkisofs \
    -iso-level 3 \
    -rock \
    -J \
    -joliet-long \
    -max-pop \
    -sysid "" \
    -V "AETHER_OS_$VERSION" \
    -b boot/grub/i386-pc/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-mbr "$BUILD_DIR/iso_root/boot/grub/i386-pc/eltorito.img" \
    -eltorito-alt-boot \
    -e EFI/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_PATH" \
    "$ISO_DIR"

if [ $? -eq 0 ]; then
    echo "✅ ISO gerada com sucesso: $ISO_PATH"
    
    # 4. Calcular Checksums
    echo "🔐 Calculando checksums..."
    sha256sum "$ISO_PATH" > "$ISO_PATH.sha256"
    md5sum "$ISO_PATH" > "$ISO_PATH.md5"
    
    echo "--- SHA256 ---"
    cat "$ISO_PATH.sha256"
    echo "--- MD5 ---"
    cat "$ISO_PATH.md5"

    # 5. Tamanho do arquivo
    ls -lh "$ISO_PATH"
    
    echo ""
    echo "🎉 Build de Release Concluído!"
    echo "📂 Arquivo pronto: $ISO_PATH"
    echo ""
    echo "📤 Para enviar ao GitHub Releases, execute:"
    echo "   gh release create v$VERSION-$DATE $ISO_PATH $ISO_PATH.sha256 $ISO_PATH.md5 --title 'Aether OS $VERSION' --notes 'Primeira alpha com suporte a pacotes Debian/Ubuntu'"
else
    echo "❌ Falha ao gerar a ISO."
    exit 1
fi
