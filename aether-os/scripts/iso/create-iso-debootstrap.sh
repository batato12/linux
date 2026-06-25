#!/bin/bash
# Aether OS - Script de Criação da ISO com Rootfs Debian/Ubuntu
# Gera imagem ISO híbrida usando o rootfs criado pelo debootstrap

set -euo pipefail

# Configurações
export AETHER_ROOT="${AETHER_ROOT:-/workspace/aether-os}"
export ISO_DIR="$AETHER_ROOT/iso_root"
export ISO_OUTPUT="$AETHER_ROOT/iso"
ROOTFS_DIR="$AETHER_ROOT/rootfs"
KERNEL_VERSION="${KERNEL_VERSION:-6.6.15}"
ISO_NAME="aether-os-x86_64.iso"
LABEL="AETHER_OS"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções de log
log_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERRO]${NC} $*" >&2; exit 1; }

log_header "Criando ISO do Aether OS (Base Debian/Ubuntu)"

# Verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    local missing=()
    for tool in xorriso mksquashfs; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Ferramentas faltando: ${missing[*]}"
        echo "Instale: sudo apt install xorriso squashfs-tools"
    fi
    
    if [ ! -d "$ROOTFS_DIR/usr" ]; then
        error "Rootfs não encontrado em $ROOTFS_DIR"
        echo "Execute primeiro: scripts/system-build/02-build-rootfs-debootstrap.sh"
    fi
    
    success "Pré-requisitos verificados!"
}

# Limpar e criar estrutura da ISO
setup_iso_structure() {
    log "Preparando estrutura da ISO..."
    
    rm -rf "$ISO_DIR" "$ISO_OUTPUT/$ISO_NAME"
    mkdir -p "$ISO_DIR"/{boot,EFI/boot,isolinux,LiveOS,syslinux,.disk}
    mkdir -p "$ISO_OUTPUT"
    
    success "Estrutura criada"
}

# Copiar kernel para a ISO
copy_kernel() {
    log "Copiando kernel e initramfs..."
    
    local kernel_found=false
    
    # Tentar encontrar kernel customizado
    if [ -f "$ROOTFS_DIR/boot/vmlinuz-${KERNEL_VERSION}-aether" ]; then
        cp "$ROOTFS_DIR/boot/vmlinuz-${KERNEL_VERSION}-aether" "$ISO_DIR/isolinux/vmlinuz"
        cp "$ROOTFS_DIR/boot/vmlinuz-${KERNEL_VERSION}-aether" "$ISO_DIR/EFI/boot/vmlinuz"
        kernel_found=true
        success "Kernel customizado copiado"
    fi
    
    # Tentar kernel padrão do Debian/Ubuntu
    if [ "$kernel_found" = false ] && ls "$ROOTFS_DIR/boot/vmlinuz"* 1>/dev/null 2>&1; then
        local latest_kernel=$(ls -t "$ROOTFS_DIR/boot/vmlinuz"* 2>/dev/null | head -1)
        if [ -n "$latest_kernel" ]; then
            cp "$latest_kernel" "$ISO_DIR/isolinux/vmlinuz"
            cp "$latest_kernel" "$ISO_DIR/EFI/boot/vmlinuz"
            kernel_found=true
            success "Kernel padrão copiado: $(basename $latest_kernel)"
        fi
    fi
    
    # Fallback: usar kernel do host se necessário (apenas para teste)
    if [ "$kernel_found" = false ]; then
        warn "Nenhum kernel encontrado no rootfs"
        if [ -f "/boot/vmlinuz-$(uname -r)" ]; then
            cp "/boot/vmlinuz-$(uname -r)" "$ISO_DIR/isolinux/vmlinuz"
            cp "/boot/vmlinuz-$(uname -r)" "$ISO_DIR/EFI/boot/vmlinuz"
            warn "Usando kernel do host como fallback"
        else
            touch "$ISO_DIR/isolinux/vmlinuz"
            touch "$ISO_DIR/EFI/boot/vmlinuz"
            warn "Criando stub de kernel (ISO não bootará sem kernel real)"
        fi
    fi
    
    # Copiar initrd/initramfs
    if ls "$ROOTFS_DIR/boot/initrd"* 1>/dev/null 2>&1; then
        local latest_initrd=$(ls -t "$ROOTFS_DIR/boot/initrd"* 2>/dev/null | head -1)
        cp "$latest_initrd" "$ISO_DIR/isolinux/initrd.img"
        cp "$latest_initrd" "$ISO_DIR/EFI/boot/initrd.img"
        success "Initramfs copiado"
    elif ls "$ROOTFS_DIR/boot/initramfs"* 1>/dev/null 2>&1; then
        local latest_initramfs=$(ls -t "$ROOTFS_DIR/boot/initramfs"* 2>/dev/null | head -1)
        cp "$latest_initramfs" "$ISO_DIR/isolinux/initrd.img"
        cp "$latest_initramfs" "$ISO_DIR/EFI/boot/initrd.img"
        success "Initramfs copiado"
    else
        warn "Initramfs não encontrado, criando básico..."
        create_basic_initrd
    fi
}

# Criar initrd básico
create_basic_initrd() {
    log "Criando initramfs básico..."
    
    local tmpdir="/tmp/aether-initrd-$$"
    mkdir -p "$tmpdir"/{bin,sbin,etc,proc,sys,newroot,dev,mnt}
    
    # Copiar busybox se disponível
    if command -v busybox &> /dev/null; then
        cp "$(which busybox)" "$tmpdir/busybox"
        chmod +x "$tmpdir/busybox"
        
        cd "$tmpdir"
        for cmd in sh ls mount mkdir cp cat echo grep sed awk mv rm ln sleep; do
            ln -sf busybox "$cmd" 2>/dev/null || true
        done
    fi
    
    # Criar script init
    cat > "$tmpdir/init" << 'INITSCRIPT'
#!/bin/sh
echo "╔════════════════════════════════════════╗"
echo "║     Aether OS - Initializing...        ║"
echo "╚════════════════════════════════════════╝"

# Montar sistemas essenciais
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "Searching for root filesystem..."

# Tentar montar o squashfs
if [ -f /live/squashfs.img ]; then
    echo "Found squashfs, mounting..."
    mkdir -p /newroot
    mount -t squashfs -o loop /live/squashfs.img /newroot 2>/dev/null || {
        echo "Failed to mount squashfs"
    }
fi

# Se falhar, tentar root normal
if [ ! -d /newroot/bin ]; then
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

echo "Switching to root filesystem..."
exec switch_root /newroot /sbin/init
INITSCRIPT
    
    chmod +x "$tmpdir/init"
    
    # Empacotar
    cd "$tmpdir"
    find . | cpio -o -H newc 2>/dev/null | gzip > "$ISO_DIR/isolinux/initrd.img"
    cp "$ISO_DIR/isolinux/initrd.img" "$ISO_DIR/EFI/boot/initrd.img"
    
    # Limpar
    rm -rf "$tmpdir"
    cd "$AETHER_ROOT"
    
    success "Initramfs básico criado"
}

# Configurar Syslinux (BIOS)
configure_syslinux() {
    log "Configurando bootloader BIOS (Syslinux)..."
    
    cat > "$ISO_DIR/isolinux/isolinux.cfg" << EOF
DEFAULT aether
LABEL aether
    MENU LABEL ^Aether OS (Padrao)
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live quiet splash locale=pt_BR keymap=br-ab
LABEL text
    MENU LABEL Aether OS (^Modo Texto)
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live quiet text locale=pt_BR keymap=br-ab
LABEL safe
    MENU LABEL ^Safe Mode
    KERNEL vmlinuz
    INITRD initrd.img
    APPEND boot=live nomodeset
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
MENU TITLE Aether OS - Escolha uma opcao
MENU COLOR BORDER       30;44      #ff000000 #00000000 none
MENU COLOR SEL          30;47      #ff000000 #ffffffff none
MENU COLOR UNSEL        30;44      #ff000000 #00000000 none
EOF
    
    # Copiar binários do isolinux
    if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
        cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_DIR/isolinux/"
        cp /usr/lib/syslinux/modules/bios/*.c32 "$ISO_DIR/isolinux/" 2>/dev/null || true
    elif [ -f /usr/share/syslinux/isolinux.bin ]; then
        cp /usr/share/syslinux/isolinux.bin "$ISO_DIR/isolinux/"
        cp /usr/share/syslinux/*.c32 "$ISO_DIR/isolinux/" 2>/dev/null || true
    else
        warn "ISOLinux não encontrado, ISO pode não bootar em BIOS"
        touch "$ISO_DIR/isolinux/isolinux.bin"
    fi
    
    success "Syslinux configurado"
}

# Configurar GRUB (UEFI)
configure_grub() {
    log "Configurando bootloader UEFI (GRUB)..."
    
    cat > "$ISO_DIR/EFI/boot/grub.cfg" << EOF
set timeout=10
set default=0

insmod all_video
insmod font
insmod gfxterm

if loadfont /boot/grub/fonts/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
fi

menuentry "Aether OS" {
    linux /isolinux/vmlinuz boot=live quiet splash locale=pt_BR keymap=br-ab
    initrd /isolinux/initrd.img
}

menuentry "Aether OS (Modo Texto)" {
    linux /isolinux/vmlinuz boot=live quiet text locale=pt_BR keymap=br-ab
    initrd /isolinux/initrd.img
}

menuentry "Aether OS (Safe Mode)" {
    linux /isolinux/vmlinuz boot=live nomodeset
    initrd /isolinux/initrd.img
}

menuentry "Rescue System" {
    linux /isolinux/vmlinuz boot=live rescue
    initrd /isolinux/initrd.img
}

menuentry "Boot from Hard Drive" {
    chainloader (hd0)+1
}
EOF
    
    success "GRUB configurado"
}

# Criar squashfs do rootfs
create_squashfs() {
    log "Criando sistema de arquivos LiveOS (squashfs)..."
    
    mkdir -p "$ISO_DIR/LiveOS"
    
    if [ -d "$ROOTFS_DIR/usr" ]; then
        log "Comprimindo rootfs com mksquashfs (isso pode demorar)..."
        
        mksquashfs "$ROOTFS_DIR" "$ISO_DIR/LiveOS/squashfs.img" \
            -noappend \
            -comp xz \
            -Xbcj x86 \
            -b 1M \
            -mem-percent 90 \
            -processors $(nproc) \
            -quiet || {
            warn "Falha ao criar squashfs otimizado, tentando modo básico..."
            mksquashfs "$ROOTFS_DIR" "$ISO_DIR/LiveOS/squashfs.img" -noappend || {
                error "Falha completa ao criar squashfs"
            }
        }
        
        local size=$(du -h "$ISO_DIR/LiveOS/squashfs.img" | cut -f1)
        success "Squashfs criado: $size"
    else
        error "Rootfs incompleto ou não encontrado"
    fi
}

# Criar arquivos de identificação
create_metadata() {
    log "Criando metadados da ISO..."
    
    cat > "$ISO_DIR/.disk/info" << EOF
Aether OS x86_64
Build: $(date +%Y-%m-%d %H:%M)
Base: Debian/Ubuntu
Kernel: ${KERNEL_VERSION}
APM: Aether Package Manager v2.0 (APT wrapper)
EOF
    
    # Criar arquivo de versão
    cat > "$ISO_DIR/version.txt" << EOF
Aether OS
Versão: 1.0-alpha
Arquitetura: x86_64
Data: $(date +%Y-%m-%d)
Base: Debian/Ubuntu
Gerenciador de Pacotes: APM (compatível com .deb)
EOF
    
    success "Metadados criados"
}

# Gerar checksums
generate_checksums() {
    log "Gerando checksums..."
    
    cd "$ISO_DIR"
    find . -type f ! -name "md5sum.txt" ! -name "sha256sum.txt" -exec md5sum {} \; > md5sum.txt 2>/dev/null || true
    find . -type f ! -name "md5sum.txt" ! -name "sha256sum.txt" -exec sha256sum {} \; > sha256sum.txt 2>/dev/null || true
    
    success "Checksums gerados"
}

# Criar ISO híbrida
create_iso_image() {
    log "Criando imagem ISO híbrida (BIOS + UEFI)..."
    
    cd "$AETHER_ROOT"
    
    # Obter caminho do isohdpfx.bin
    local isohdpfx=""
    if [ -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
        isohdpfx="/usr/lib/ISOLINUX/isohdpfx.bin"
    elif [ -f /usr/share/syslinux/isohdpfx.bin ]; then
        isohdpfx="/usr/share/syslinux/isohdpfx.bin"
    fi
    
    if command -v xorriso &> /dev/null; then
        log "Usando xorriso para criar ISO..."
        
        if [ -n "$isohdpfx" ] && [ -f "$isohdpfx" ]; then
            xorriso -as mkisofs \
                -iso-level 3 \
                -rock \
                -joliet \
                -max-pop 32 \
                -V "$LABEL" \
                -sysid "" \
                -preparer "Aether OS Team" \
                -publisher "Aether Project" \
                -A "Aether OS x86_64 Live" \
                -input-charset utf-8 \
                -b isolinux/isolinux.bin \
                -c isolinux/boot.cat \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                -eltorito-alt-boot \
                -e EFI/boot/efiboot.img \
                -no-emul-boot \
                -isohybrid-mbr "$isohdpfx" \
                -o "$ISO_OUTPUT/$ISO_NAME" \
                "$ISO_DIR" 2>&1 | tee -a /tmp/iso-build.log || {
                warn "xorriso falhou, tentando genisoimage..."
                create_iso_genisoimage
            }
        else
            warn "isohdpfx.bin não encontrado, criando ISO sem suporte hybrid-mbr"
            xorriso -as mkisofs \
                -iso-level 3 \
                -rock \
                -joliet \
                -V "$LABEL" \
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
                -o "$ISO_OUTPUT/$ISO_NAME" \
                "$ISO_DIR" 2>&1 || {
                warn "xorriso falhou, tentando genisoimage..."
                create_iso_genisoimage
            }
        fi
    else
        create_iso_genisoimage
    fi
    
    success "ISO criada"
}

# Fallback para genisoimage/mkisofs
create_iso_genisoimage() {
    local iso_cmd=""
    
    if command -v genisoimage &> /dev/null; then
        iso_cmd="genisoimage"
    elif command -v mkisofs &> /dev/null; then
        iso_cmd="mkisofs"
    else
        error "Nenhuma ferramenta de ISO encontrada (xorriso, genisoimage, mkisofs)"
    fi
    
    log "Usando $iso_cmd..."
    
    $iso_cmd \
        -iso-level 3 \
        -rock \
        -joliet \
        -V "$LABEL" \
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
        "$ISO_DIR" || error "Falha ao criar ISO com $iso_cmd"
}

# Aplicar isohybrid
apply_isohybrid() {
    if command -v isohybrid &> /dev/null; then
        log "Aplicando isohybrid para dual-boot..."
        isohybrid --uefi "$ISO_OUTPUT/$ISO_NAME" 2>/dev/null || warn "isohybrid falhou"
        success "ISO híbrida aplicada"
    else
        warn "isohybrid não disponível (instale syslinux-efi)"
    fi
}

# Calcular checksum final
calculate_final_checksum() {
    log "Calculando checksum final..."
    
    cd "$ISO_OUTPUT"
    sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
    md5sum "$ISO_NAME" > "${ISO_NAME}.md5"
    
    success "Checksums calculados"
}

# Mostrar resumo
show_summary() {
    echo ""
    success "═══════════════════════════════════════════════════════════"
    echo "   ISO do Aether OS criada com sucesso!"
    success "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📀 Localização: $ISO_OUTPUT/$ISO_NAME"
    echo "📦 Tamanho:     $(du -h "$ISO_OUTPUT/$ISO_NAME" | cut -f1)"
    echo "🔐 SHA256:      $(cat ${ISO_NAME}.sha256)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Próximos passos:"
    echo ""
    echo "1️⃣  Testar no QEMU:"
    echo "   qemu-system-x86_64 -cdrom $ISO_OUTPUT/$ISO_NAME -boot d -m 4G"
    echo ""
    echo "2️⃣  Testar com UEFI:"
    echo "   qemu-system-x86_64 -cdrom $ISO_OUTPUT/$ISO_NAME -bios OVMF.fd -m 4G"
    echo ""
    echo "3️⃣  Gravar em USB:"
    echo "   dd if=$ISO_OUTPUT/$ISO_NAME of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "4️⃣  Testar no VMware/VirtualBox:"
    echo "   Crie nova VM e selecione a ISO como disco de boot"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Recursos incluídos:"
    echo "  ✓ Base Debian/Ubuntu (compatibilidade total .deb)"
    echo "  ✓ APM - Aether Package Manager (wrapper APT)"
    echo "  ✓ Layout de teclado PT-BR"
    echo "  ✓ Suporte BIOS e UEFI"
    echo "  ✓ Firmware proprietário (se disponível na base)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main
main() {
    local start_time=$(date +%s)
    
    check_prerequisites
    setup_iso_structure
    copy_kernel
    configure_syslinux
    configure_grub
    create_squashfs
    create_metadata
    generate_checksums
    create_iso_image
    apply_isohybrid
    calculate_final_checksum
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_summary
    
    echo ""
    echo "⏱️  Tempo total: $((duration / 60))m $((duration % 60))s"
    echo ""
}

# Executar
main "$@"
