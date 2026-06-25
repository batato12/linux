#!/bin/bash
# Aether OS - Build All Script (Master Build)
# Executa todo o processo de construção da distribuição

set -euo pipefail

# Configurações
export AETHER_ROOT="/workspace/aether-os"
SCRIPT_DIR="$AETHER_ROOT/scripts"
LOG_FILE="$AETHER_ROOT/build.log"

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
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Verificar pré-requisitos
check_prerequisites() {
    log_header "Verificando Pré-requisitos"
    
    local missing=()
    local required_tools=(
        "gcc" "g++" "make" "bison" "flex" "gawk" 
        "wget" "tar" "xz" "gzip" "cpio"
    )
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Ferramentas faltando: ${missing[*]}"
        echo ""
        echo "Instale os pacotes necessários:"
        echo "  Debian/Ubuntu: sudo apt install build-essential bison flex gawk wget"
        echo "  Fedora: sudo dnf install gcc gcc-c++ make bison flex gawk wget"
        exit 1
    fi
    
    # Verificar espaço em disco
    local available_space=$(df -P "$AETHER_ROOT" | awk 'NR==2 {print $4}')
    local min_space=50000000  # ~50GB em KB
    
    if [ "$available_space" -lt "$min_space" ]; then
        log_warn "Espaço em disco limitado: $(($available_space / 1024 / 1024))GB disponíveis"
        log_warn "Recomendado: mínimo 50GB livres"
    fi
    
    log_success "Pré-requisitos verificados!"
}

# Criar estrutura de diretórios
setup_directories() {
    log_header "Configurando Estrutura de Diretórios"
    
    mkdir -p "$AETHER_ROOT"/{tools,sources,patches,rootfs/{etc,var,usr,boot},iso,docs}
    mkdir -p "$SCRIPT_DIR"/{cross-toolchain,system-build,iso,installer,package-manager}
    
    log_success "Diretórios criados"
}

# Construir toolchain cruzada
build_toolchain() {
    log_header "Construindo Toolchain Cruzada"
    
    local toolchain_dir="$SCRIPT_DIR/cross-toolchain"
    
    log_step "Executando scripts da toolchain..."
    
    for script in 01-build-binutils.sh \
                  02-build-gcc-pass1.sh \
                  03-build-linux-headers.sh \
                  04-build-glibc.sh \
                  05-build-gcc-pass2.sh; do
        
        if [ -x "$toolchain_dir/$script" ]; then
            log_step "Executando: $script"
            "$toolchain_dir/$script" || {
                log_error "Falha em $script"
                return 1
            }
        else
            log_warn "Script não encontrado ou não executável: $script"
        fi
    done
    
    log_success "Toolchain construída com sucesso!"
}

# Construir sistema base
build_system() {
    log_header "Construindo Sistema Base"
    
    local system_dir="$SCRIPT_DIR/system-build"
    
    # Kernel
    if [ -x "$system_dir/01-build-kernel.sh" ]; then
        log_step "Construindo kernel Linux..."
        "$system_dir/01-build-kernel.sh" || {
            log_error "Falha na construção do kernel"
            return 1
        }
    fi
    
    # TODO: Adicionar mais componentes do sistema
    # - systemd
    # - coreutils
    # - bash
    # - etc.
    
    log_success "Sistema base construído!"
}

# Gerar ISO
create_iso() {
    log_header "Gerando Imagem ISO"
    
    local iso_script="$SCRIPT_DIR/iso/create-iso.sh"
    
    if [ -x "$iso_script" ]; then
        log_step "Criando ISO bootável..."
        "$iso_script" || {
            log_error "Falha ao criar ISO"
            return 1
        }
    else
        log_warn "Script de criação de ISO não encontrado"
    fi
    
    log_success "ISO gerada com sucesso!"
}

# Mostrar resumo
show_summary() {
    log_header "Resumo do Build"
    
    echo -e "${GREEN}Build do Aether OS concluído!${NC}"
    echo ""
    echo "Arquivos gerados:"
    
    if [ -d "$AETHER_ROOT/iso" ]; then
        echo -e "  ${CYAN}📀 ISO:${NC} $(ls -lh $AETHER_ROOT/iso/*.iso 2>/dev/null | head -1 || echo 'Não gerada')"
    fi
    
    if [ -f "$AETHER_ROOT/rootfs/boot/vmlinuz"* ]; then
        echo -e "  ${CYAN}🐧 Kernel:${NC} $(ls $AETHER_ROOT/rootfs/boot/vmlinuz* 2>/dev/null | head -1)"
    fi
    
    echo ""
    echo "Próximos passos:"
    echo "  1. Teste a ISO no QEMU:"
    echo "     qemu-system-x86_64 -cdrom $AETHER_ROOT/iso/aether-os-x86_64.iso -boot d -m 4G"
    echo ""
    echo "  2. Grave em USB:"
    echo "     dd if=$AETHER_ROOT/iso/aether-os-x86_64.iso of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "  3. Instale usando:"
    echo "     - Instalador Gráfico: install-gui"
    echo "     - Instalador Texto: install-text"
    echo ""
}

# Main
main() {
    echo -e "${CYAN}"
    cat << EOF
    
    ___       _   _                   ____  
   / _ \     | | (_)                 / __ \ 
  / /_\ \_   _| |_ _  ___  _ __  ___| /  \/ 
  |  _  | | | | __| |/ _ \| '_ \/ __| |     
  | | | | |_| | |_| | (_) | | | \__ \ \__/\ 
  \_| |_/\__,_|\__|_|\___/|_| |_|___/\____/ 
                                            
    Build System v1.0
    
EOF
    echo -e "${NC}"
    
    local start_time=$(date +%s)
    
    # Executar etapas
    check_prerequisites
    setup_directories
    
    # Perguntar se quer construir toolchain
    echo ""
    read -p "Deseja construir a toolchain cruzada? (s/N): " build_tc
    if [[ "$build_tc" =~ ^[Ss]$ ]]; then
        build_toolchain || exit 1
    fi
    
    # Perguntar se quer construir sistema
    echo ""
    read -p "Deseja construir o sistema base? (s/N): " build_sys
    if [[ "$build_sys" =~ ^[Ss]$ ]]; then
        build_system || exit 1
    fi
    
    # Perguntar se quer gerar ISO
    echo ""
    read -p "Deseja gerar a ISO bootável? (s/N): " build_iso
    if [[ "$build_iso" =~ ^[Ss]$ ]]; then
        create_iso || exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_summary
    
    echo -e "${GREEN}Tempo total de build: $((duration / 60))m $((duration % 60))s${NC}"
}

# Executar
main "$@"
