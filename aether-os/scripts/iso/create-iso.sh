#!/bin/bash
# Aether OS - Script de Criação da ISO Bootável
# Gera imagem ISO inicializável para BIOS e UEFI

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
export AETHER_SOURCES="$AETHER_ROOT/sources"
export ISO_DIR="$AETHER_ROOT/iso_root"
export ISO_OUTPUT="$AETHER_ROOT/iso"
KERNEL_VERSION="6.6.15"
ISO_NAME="aether-os-x86_64.iso"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERRO]${NC} $*" >&2; exit 1; }

log "=== Criando ISO do Aether OS ==="

# Limpar e criar estrutura da ISO
log "Preparando estrutura da ISO..."
rm -rf "$ISO_DIR" "$ISO_OUTPUT/$ISO_NAME"
mkdir -p "$ISO_DIR"/{boot,EFI/boot,isolinux,LiveOS,syslinux}
mkdir -p "$ISO_OUTPUT"

# Copiar kernel e initramfs para a ISO
log "Copiando kernel e initramfs..."
if [ -f "$AETHER_ROOT/rootfs/boot/vmlinuz-${KERNEL_VERSION}-aether" ]; then
    cp "$AETHER_ROOT/rootfs/boot/vmlinuz-${KERNEL_VERSION}-aether" "$ISO_DIR/isolinux/vmlinuz"
    cp "$AETHER_ROOT/rootfs/boot/vmlinuz-${KERNEL_VERSION}-aether" "$ISO_DIR/EFI/boot/vmlinuz"
    success "Kernel copiado"
else
    warn "Kernel não encontrado, criando stub..."
    touch "$ISO_DIR/isolinux/vmlinuz"
    touch "$ISO_DIR/EFI/boot/vmlinuz"
fi

# Criar initramfs básico (stub para demonstração)
log "Criando initramfs..."
cat > /tmp/initramfs_init << 'EOF'
#!/bin/sh
echo "Aether OS Initramfs"
echo "Mounting root filesystem..."
# Em produção, isso montaria o squashfs da LiveOS
exec switch_root /newroot /sbin/init
EOF

mkdir -p /tmp/initramfs_root/{bin,sbin,etc,proc,sys,newroot}
cp /tmp/initramfs_init /tmp/initramfs_root/init
chmod +x /tmp/initramfs_root/init

# Criar busybox estático se disponível
if command -v busybox &> /dev/null; then
    cp "$(which busybox)" /tmp/initramfs_root/busybox
    cd /tmp/initramfs_root
    for cmd in sh ls mount mkdir cp cat echo; do
        ln -sf busybox "$cmd" 2>/dev/null || true
    done
fi

cd /tmp/initramfs_root
find . | cpio -o -H newc 2>/dev/null | gzip > "$ISO_DIR/isolinux/initrd.img"
cp "$ISO_DIR/isolinux/initrd.img" "$ISO_DIR/EFI/boot/initrd.img"
success "Initramfs criado"

cd "$AETHER_ROOT"

# Configuração do Syslinux (BIOS)
log "Configurando bootloader BIOS (Syslinux)..."
cat > "$ISO_DIR/isolinux/isolinux.cfg" << EOF
DEFAULT aether
LABEL aether
    MENU LABEL ^Aether OS (Padrão)
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live quiet splash
LABEL text
    MENU LABEL Aether OS (^Modo Texto)
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live quiet text
LABEL rescue
    MENU LABEL ^Rescue System
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live rescue
LABEL hd
    MENU LABEL ^Boot from Hard Drive
    LOCALBOOT 0
TIMEOUT 100
PROMPT 0
MENU TITLE Aether OS - Escolha uma opção
EOF

# Configuração do GRUB (UEFI)
log "Configurando bootloader UEFI (GRUB)..."
cat > "$ISO_DIR/EFI/boot/grub.cfg" << EOF
set timeout=10
set default=0

menuentry "Aether OS" {
    linux /EFI/boot/vmlinuz boot=live quiet splash
    initrd /EFI/boot/initrd.img
}

menuentry "Aether OS (Modo Texto)" {
    linux /EFI/boot/vmlinuz boot=live quiet text
    initrd /EFI/boot/initrd.img
}

menuentry "Rescue System" {
    linux /EFI/boot/vmlinuz boot=live rescue
    initrd /EFI/boot/initrd.img
}

menuentry "Boot from Hard Drive" {
    chainloader (hd0)+1
}
EOF

# Copiar binários do isolinux (se disponíveis no sistema host)
log "Copiando binários do isolinux..."
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
    cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_DIR/isolinux/"
    cp /usr/lib/syslinux/modules/bios/*.c32 "$ISO_DIR/isolinux/" 2>/dev/null || true
elif [ -f /usr/share/syslinux/isolinux.bin ]; then
    cp /usr/share/syslinux/isolinux.bin "$ISO_DIR/isolinux/"
    cp /usr/share/syslinux/*.c32 "$ISO_DIR/isolinux/" 2>/dev/null || true
else
    warn "ISOLinux não encontrado no sistema host"
    # Criar placeholders
    touch "$ISO_DIR/isolinux/isolinux.bin"
fi

# Criar imagem squashfs do sistema LiveOS (simulação)
log "Criando sistema de arquivos LiveOS..."
mkdir -p "$ISO_DIR/LiveOS"

# Em produção, aqui seria criado um squashfs completo do rootfs
if command -v mksquashfs &> /dev/null && [ -d "$AETHER_ROOT/rootfs/usr" ]; then
    mksquashfs "$AETHER_ROOT/rootfs" "$ISO_DIR/LiveOS/squashfs.img" -noappend -comp xz || {
        warn "Falha ao criar squashfs, criando arquivo vazio"
        touch "$ISO_DIR/LiveOS/squashfs.img"
    }
else
    warn "mksquashfs não disponível ou rootfs incompleto"
    touch "$ISO_DIR/LiveOS/squashfs.img"
fi

# Arquivo de identificação da ISO
cat > "$ISO_DIR/.disk/info" << EOF
Aether OS x86_64
Build: $(date +%Y%m%d)
Kernel: ${KERNEL_VERSION}
EOF

touch "$ISO_DIR/.disk/info"

# Gerar checksums
log "Gerando checksums..."
cd "$ISO_DIR"
find . -type f ! -name "md5sum.txt" ! -name "sha256sum.txt" -exec md5sum {} \; > md5sum.txt 2>/dev/null || true
find . -type f ! -name "md5sum.txt" ! -name "sha256sum.txt" -exec sha256sum {} \; > sha256sum.txt 2>/dev/null || true

# Criar ISO híbrida (BIOS + UEFI)
log "Criando imagem ISO..."
cd "$AETHER_ROOT"

if command -v xorriso &> /dev/null; then
    # Método recomendado com xorriso (suporte completo a UEFI e BIOS)
    log "Usando xorriso..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -rock \
        -joliet \
        -max-pop 32 \
        -V "AETHER_OS" \
        -sysid "" \
        -preparer "Aether OS Team" \
        -publisher "Aether Project" \
        -A "Aether OS x86_64" \
        -input-charset utf-8 \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e EFI/boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -o "$ISO_OUTPUT/$ISO_NAME" \
        "$ISO_DIR" 2>/dev/null || {
        warn "xorriso falhou, tentando genisoimage..."
        create_iso_genisoimage
    }
elif command -v genisoimage &> /dev/null || command -v mkisofs &> /dev/null; then
    create_iso_genisoimage() {
        local iso_cmd="${ISO_CMD:-genisoimage}"
        command -v mkisofs &> /dev/null && iso_cmd="mkisofs"
        
        $iso_cmd \
            -iso-level 3 \
            -rock \
            -joliet \
            -V "AETHER_OS" \
            -sysid "" \
            -preparer "Aether OS Team" \
            -publisher "Aether Project" \
            -A "Aether OS x86_64" \
            -input-charset utf-8 \
            -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -o "$ISO_OUTPUT/$ISO_NAME" \
            "$ISO_DIR" || error "Falha ao criar ISO"
    }
    create_iso_genisoimage
else
    error "Nenhuma ferramenta de criação de ISO encontrada (xorriso, genisoimage ou mkisofs)"
fi

# Tornar ISO híbrida (se isohybrid disponível)
if command -v isohybrid &> /dev/null; then
    log "Aplicando isohybrid para suporte dual-boot..."
    isohybrid --uefi "$ISO_OUTPUT/$ISO_NAME" 2>/dev/null || warn "isohybrid falhou"
fi

# Calcular checksum final
log "Calculando checksum da ISO..."
cd "$ISO_OUTPUT"
sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
md5sum "$ISO_NAME" > "${ISO_NAME}.md5"

success "=== ISO criada com sucesso! ==="
echo ""
echo "Localização: $ISO_OUTPUT/$ISO_NAME"
echo "Tamanho: $(du -h "$ISO_OUTPUT/$ISO_NAME" | cut -f1)"
echo "SHA256: $(cat ${ISO_NAME}.sha256)"
echo ""
echo "Para testar com QEMU:"
echo "  qemu-system-x86_64 -cdrom $ISO_OUTPUT/$ISO_NAME -boot d"
echo ""
echo "Para gravar em USB:"
echo "  dd if=$ISO_OUTPUT/$ISO_NAME of=/dev/sdX bs=4M status=progress"
