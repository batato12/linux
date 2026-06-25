#!/bin/bash
# Aether OS - Build All com Debootstrap (Script Mestre)
# Constrói sistema base usando pacotes Debian/Ubuntu

set -euo pipefail

# Configurações
export AETHER_ROOT="${AETHER_ROOT:-/workspace/aether-os}"
SCRIPT_DIR="$AETHER_ROOT/scripts"
LOG_FILE="$AETHER_ROOT/build-debootstrap.log"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $*" >&2
}

# Verificar pré-requisitos
check_prerequisites() {
    log_header "Verificando Pré-requisitos"
    
    local missing=()
    local required_tools=("debootstrap" "wget" "tar" "xz" "xorriso" "mksquashfs")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Ferramentas faltando: ${missing[*]}"
        echo ""
        echo "Instale os pacotes necessários:"
        echo "  sudo apt install debootstrap wget tar xz-utils xorriso squashfs-tools"
        exit 1
    fi
    
    # Verificar se está rodando como root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script precisa ser executado como root"
        exit 1
    fi
    
    # Verificar espaço em disco
    local available_space=$(df -P "$AETHER_ROOT" | awk 'NR==2 {print $4}')
    local min_space=20000000  # ~20GB em KB
    
    if [ "$available_space" -lt "$min_space" ]; then
        log_warn "Espaço em disco limitado: $(($available_space / 1024 / 1024))GB disponíveis"
        log_warn "Recomendado: mínimo 20GB livres"
    fi
    
    log_success "Pré-requisitos verificados!"
}

# Criar estrutura de diretórios
setup_directories() {
    log_header "Configurando Estrutura de Diretórios"
    
    mkdir -p "$AETHER_ROOT"/{tools,sources,patches,rootfs/{etc,var,usr,boot},iso,docs}
    mkdir -p "$SCRIPT_DIR"/{cross-toolchain,system-build,iso,installer,package-manager}
    
    log_success "Diretórios configurados"
}

# Construir sistema base com debootstrap
build_rootfs() {
    log_header "Construindo Sistema Base (Debootstrap)"
    
    local rootfs_script="$SCRIPT_DIR/system-build/02-build-rootfs-debootstrap.sh"
    
    if [ -x "$rootfs_script" ]; then
        log_step "Executando debootstrap..."
        "$rootfs_script" || {
            log_error "Falha na construção do rootfs"
            return 1
        }
    else
        log_error "Script não encontrado: $rootfs_script"
        return 1
    fi
    
    log_success "Sistema base construído!"
}

# (Opcional) Construir kernel customizado
build_kernel() {
    log_header "Construindo Kernel Customizado (Opcional)"
    
    local kernel_script="$SCRIPT_DIR/system-build/01-build-kernel.sh"
    
    read -p "Deseja compilar o kernel customizado? (s/N): " build_kernel
    if [[ "$build_kernel" =~ ^[Ss]$ ]]; then
        if [ -x "$kernel_script" ]; then
            log_step "Construindo kernel..."
            "$kernel_script" || {
                log_warn "Falha na construção do kernel, usará kernel padrão"
            }
        else
            log_warn "Script do kernel não encontrado"
        fi
    else
        log_step "Usando kernel padrão do Debian/Ubuntu"
    fi
}

# Gerar ISO
create_iso() {
    log_header "Gerando Imagem ISO Bootável"
    
    local iso_script="$SCRIPT_DIR/iso/create-iso-debootstrap.sh"
    
    read -p "Deseja gerar a ISO bootável? (s/N): " build_iso
    if [[ "$build_iso" =~ ^[Ss]$ ]]; then
        if [ -x "$iso_script" ]; then
            log_step "Criando ISO..."
            "$iso_script" || {
                log_error "Falha ao criar ISO"
                return 1
            }
        else
            log_error "Script de ISO não encontrado: $iso_script"
            return 1
        fi
    else
        log_step "ISO não gerada"
    fi
}

# Mostrar resumo
show_summary() {
    log_header "Resumo do Build"
    
    echo -e "${GREEN}Build do Aether OS concluído!${NC}"
    echo ""
    
    # Informações do rootfs
    if [ -d "$AETHER_ROOT/rootfs/usr" ]; then
        echo -e "${CYAN}📦 Rootfs:${NC}"
        echo "   Localização: $AETHER_ROOT/rootfs"
        echo "   Tamanho: $(du -sh "$AETHER_ROOT/rootfs" 2>/dev/null | cut -f2)"
        echo "   Pacotes: $(chroot "$AETHER_ROOT/rootfs" dpkg --get-selections 2>/dev/null | wc -l || echo 'N/A')"
        echo ""
    fi
    
    # Informações da ISO
    if [ -f "$AETHER_ROOT/iso/aether-os-x86_64.iso" ]; then
        echo -e "${CYAN}📀 ISO:${NC}"
        echo "   Arquivo: $AETHER_ROOT/iso/aether-os-x86_64.iso"
        echo "   Tamanho: $(du -h "$AETHER_ROOT/iso/aether-os-x86_64.iso" | cut -f2)"
        echo "   SHA256:  $(cat "$AETHER_ROOT/iso/aether-os-x86_64.iso.sha256" 2>/dev/null | cut -d' ' -f1 || echo 'N/A')"
        echo ""
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Próximos passos:"
    echo ""
    echo "1️⃣  Testar no QEMU:"
    echo "   qemu-system-x86_64 -cdrom $AETHER_ROOT/iso/aether-os-x86_64.iso -boot d -m 4G"
    echo ""
    echo "2️⃣  Testar com UEFI:"
    echo "   qemu-system-x86_64 -cdrom $AETHER_ROOT/iso/aether-os-x86_64.iso -bios OVMF.fd -m 4G"
    echo ""
    echo "3️⃣  Gravar em USB:"
    echo "   dd if=$AETHER_ROOT/iso/aether-os-x86_64.iso of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "4️⃣  Entrar no chroot para personalizar:"
    echo "   chroot $AETHER_ROOT/rootfs /bin/bash"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📚 Documentação: docs/QUICKSTART-DEBOOTSTRAP.md"
    echo ""
}

# Main
main() {
    echo -e "${CYAN}"
    cat << EOF
    
    ╔══════════════════════════════════════════════════╗
    ║                                                  ║
    ║     ___       _   _                   ____       ║
    ║    / _ \\     | | (_)                 / __ \\      ║
    ║   / /_\\ \\_   _| |_ _  ___  _ __  ___| /  \\/      ║
    ║   |  _  | | | | __| |/ _ \\| '_ \\/ __| |          ║
    ║   | | | | |_| | |_| | (_) | | | \\__ \\ \\__/\\      ║
    ║   \\_| |_/\\__,_|\\__|_|\\___/|_| |_|___/\\____/      ║
    ║                                                  ║
    ║         Build System com Debootstrap v2.0       ║
    ║                                                  ║
    ╚══════════════════════════════════════════════════╝
    
    Base: Debian/Ubuntu
    Compatibilidade: Pacotes .deb
    Gerenciador: APM (wrapper APT)
    
EOF
    echo -e "${NC}"
    
    local start_time=$(date +%s)
    
    # Executar etapas
    check_prerequisites
    setup_directories
    
    # Perguntar configurações
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Configurações do Build"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    read -p "Distribuição base (debian/ubuntu) [debian]: " distro_input
    export DISTRO="${distro_input:-debian}"
    
    if [[ "$DISTRO" == "ubuntu" ]]; then
        read -p "Versão Ubuntu (jammy/noble/mantic) [jammy]: " suite_input
        export SUITE="${suite_input:-jammy}"
        export MIRROR="http://archive.ubuntu.com/ubuntu"
    else
        read -p "Versão Debian (bookworm/testing/trixie) [bookworm]: " suite_input
        export SUITE="${suite_input:-bookworm}"
        export MIRROR="http://deb.debian.org/debian"
    fi
    
    echo ""
    log_step "Configuração selecionada:"
    echo "   Distribuição: $DISTRO"
    echo "   Versão:       $SUITE"
    echo "   Mirror:       $MIRROR"
    echo ""
    
    # Executar builds
    build_rootfs
    build_kernel
    create_iso
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_summary
    
    echo -e "${GREEN}⏱️  Tempo total: $((duration / 60))m $((duration % 60))s${NC}"
    echo ""
}

# Executar
main "$@"
