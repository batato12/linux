#!/bin/bash
# Aether OS - Construir Sistema Base com Debootstrap
# Cria rootfs baseado em Debian/Ubuntu usando debootstrap

set -euo pipefail

# Configurações
export AETHER_ROOT="${AETHER_ROOT:-/workspace/aether-os}"
SCRIPT_DIR="$AETHER_ROOT/scripts"
ROOTFS_DIR="$AETHER_ROOT/rootfs"
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
    local required_tools=("debootstrap" "wget" "tar" "xz" "gzip" "fakeroot")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Ferramentas faltando: ${missing[*]}"
        echo ""
        echo "Instale os pacotes necessários:"
        echo "  Debian/Ubuntu: sudo apt install debootstrap wget tar xz-utils fakeroot"
        echo "  Fedora: sudo dnf install debootstrap wget tar xz fakeroot"
        exit 1
    fi
    
    # Verificar se está rodando como root ou tem sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script precisa ser executado como root (debootstrap requer privilégios)"
        exit 1
    fi
    
    log_success "Pré-requisitos verificados!"
}

# Limpar rootfs anterior
cleanup_rootfs() {
    log_header "Limpando Rootfs Anterior"
    
    if [ -d "$ROOTFS_DIR" ]; then
        log_step "Removendo rootfs antigo..."
        rm -rf "$ROOTFS_DIR"
        log_success "Rootfs antigo removido"
    fi
    
    mkdir -p "$ROOTFS_DIR"
    log_success "Diretório rootfs criado: $ROOTFS_DIR"
}

# Executar debootstrap
run_debootstrap() {
    log_header "Executando Debootstrap"
    
    # Selecionar distribuição (padrão: Debian Stable)
    local DISTRO="${DISTRO:-debian}"
    local SUITE="${SUITE:-bookworm}"  # Debian 12 Stable
    local MIRROR="${MIRROR:-http://deb.debian.org/debian}"
    local ARCH="${ARCH:-amd64}"
    
    # Opções para Ubuntu
    if [[ "$DISTRO" == "ubuntu" ]]; then
        SUITE="${SUITE:-jammy}"  # Ubuntu 22.04 LTS
        MIRROR="${MIRROR:-http://archive.ubuntu.com/ubuntu}"
    fi
    
    log_step "Distribuição: $DISTRO $SUITE"
    log_step "Mirror: $MIRROR"
    log_step "Arquitetura: $ARCH"
    log_step "Destino: $ROOTFS_DIR"
    
    # Componentes a incluir
    local components="main,contrib,non-free,non-free-firmware"
    
    # Pacotes essenciais para incluir
    local include_packages="systemd,bash,coreutils,util-linux,procps,kmod,tar,gzip,wget,curl,nano,vim,less,man-db,locales,dbus,udev,netbase,ifupdown,iproute2,isc-dhcp-client,wpasupplicant,wireless-tools,net-tools,openssh-server,openssl,ca-certificates,gpg,gnupg,software-properties-common"
    
    # Excluir pacotes desnecessários para reduzir tamanho
    local exclude_packages="apt,dpkg"
    
    log_step "Executando debootstrap (isso pode demorar alguns minutos)..."
    
    debootstrap \
        --arch="$ARCH" \
        --include="$include_packages" \
        --exclude="$exclude_packages" \
        --components="$components" \
        --variant=minbase \
        "$SUITE" \
        "$ROOTFS_DIR" \
        "$MIRROR" \
        /var/log/debootstrap.log 2>&1 | tee -a "$LOG_FILE" || {
        log_error "Falha na execução do debootstrap"
        return 1
    }
    
    log_success "Debootstrap concluído com sucesso!"
}

# Configurar fontes de repositórios
configure_sources() {
    log_header "Configurando Fontes de Repositórios"
    
    local DISTRO="${DISTRO:-debian}"
    local SUITE="${SUITE:-bookworm}"
    
    # Backup do sources.list original
    cp "$ROOTFS_DIR/etc/apt/sources.list" "$ROOTFS_DIR/etc/apt/sources.list.orig"
    
    # Criar novo sources.list otimizado
    cat > "$ROOTFS_DIR/etc/apt/sources.list" << EOF
# Aether OS - Fontes de Repositórios
# Base: $DISTRO $SUITE

# Repositórios principais
deb http://deb.debian.org/debian $SUITE main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $SUITE-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security $SUITE-security main contrib non-free non-free-firmware

# Repositórios de debugging (opcional, comentar se não precisar)
# deb http://deb.debian.org/debian-debug $SUITE-debug main contrib non-free
# deb http://deb.debian.org/debian-debug $SUITE-updates-debug main contrib non-free
EOF
    
    # Para Ubuntu, usar fontes apropriadas
    if [[ "$DISTRO" == "ubuntu" ]]; then
        cat > "$ROOTFS_DIR/etc/apt/sources.list" << EOF
# Aether OS - Fontes de Repositórios Ubuntu
# Base: Ubuntu $SUITE

deb http://archive.ubuntu.com/ubuntu $SUITE main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $SUITE-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $SUITE-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $SUITE-security main restricted universe multiverse
EOF
    fi
    
    log_success "Fontes de repositórios configuradas"
    
    # Mostrar conteúdo
    log_step "Conteúdo de sources.list:"
    cat "$ROOTFS_DIR/etc/apt/sources.list"
}

# Configurar sistema básico
configure_base_system() {
    log_header "Configurando Sistema Básico"
    
    # Montar sistemas de arquivos necessários para chroot
    log_step "Montando sistemas de arquivos virtuais..."
    mount -t proc /proc "$ROOTFS_DIR/proc"
    mount -t sysfs /sys "$ROOTFS_DIR/sys"
    mount --rbind /dev "$ROOTFS_DIR/dev"
    mount --rbind /run "$ROOTFS_DIR/run"
    
    # Copiar resolv.conf para ter acesso à rede no chroot
    cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"
    
    # Configurar hostname
    log_step "Configurando hostname..."
    echo "aether-os" > "$ROOTFS_DIR/etc/hostname"
    
    # Configurar hosts
    cat > "$ROOTFS_DIR/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   aether-os
::1         localhost ip6-localhost ip6-loopback
EOF
    
    # Configurar locale
    log_step "Configurando locale PT-BR..."
    cat > "$ROOTFS_DIR/etc/locale.gen" << EOF
pt_BR.UTF-8 UTF-8
en_US.UTF-8 UTF-8
EOF
    
    # Configurar timezone
    log_step "Configurando timezone America/Sao_Paulo..."
    echo "America/Sao_Paulo" > "$ROOTFS_DIR/etc/timezone"
    ln -sf /usr/share/zoneinfo/America/Sao_Paulo "$ROOTFS_DIR/etc/localtime"
    
    # Configurar teclado PT-BR no console
    log_step "Configurando layout de teclado PT-BR..."
    cat > "$ROOTFS_DIR/etc/vconsole.conf" << EOF
KEYMAP=br-ab
FONT=Lat2-Terminus16
EOF
    
    # Ou para systemd-console
    mkdir -p "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d"
    cat > "$ROOTFS_DIR/etc/systemd/system/getty@tty1.service.d/override.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear --keymap br-ab %I \$TERM
EOF
    
    log_success "Sistema básico configurado"
}

# Atualizar pacotes e instalar kernel
update_and_install_kernel() {
    log_header "Atualizando Pacotes e Instalando Kernel"
    
    # Preparar comando chroot
    chroot_cmd() {
        chroot "$ROOTFS_DIR" "$@"
    }
    
    # Atualizar lista de pacotes
    log_step "Atualizando lista de pacotes..."
    chroot_cmd apt-get update || {
        log_warn "Falha ao atualizar lista de pacotes"
    }
    
    # Upgrade dos pacotes base
    log_step "Realizando upgrade dos pacotes base..."
    chroot_cmd apt-get upgrade -y || {
        log_warn "Falha no upgrade"
    }
    
    # Instalar kernel Linux (genérico ou específico)
    log_step "Instalando kernel Linux..."
    
    # Opção 1: Usar kernel do Debian/Ubuntu (mais compatível)
    # chroot_cmd apt-get install -y linux-image-amd64 linux-headers-amd64
    
    # Opção 2: Instalar kernel customizado (será copiado depois)
    # Por enquanto, instalar headers para compilar módulos
    chroot_cmd apt-get install -y linux-headers-amd64 kmod initramfs-tools || {
        log_warn "Falha ao instalar headers do kernel"
    }
    
    log_success "Pacotes atualizados e kernel instalado"
}

# Configurar gerenciador de pacotes APM como wrapper do apt
setup_apm_wrapper() {
    log_header "Configurando APM como Wrapper do APT"
    
    # Copiar script apm.sh atualizado
    local apm_source="$SCRIPT_DIR/package-manager/apm-deb-wrapper.sh"
    local apm_dest="$ROOTFS_DIR/usr/bin/apm"
    
    if [ -f "$apm_source" ]; then
        cp "$apm_source" "$apm_dest"
        chmod +x "$apm_dest"
        log_success "APM wrapper instalado em $apm_dest"
    else
        log_warn "Script apm-deb-wrapper.sh não encontrado, criando wrapper básico..."
        
        # Criar wrapper simples
        cat > "$apm_dest" << 'WRAPPER_EOF'
#!/bin/bash
# APM - Aether Package Manager (Wrapper para APT/DPKG)
# Compatibilidade com pacotes .deb do Debian/Ubuntu

exec apt "$@"
WRAPPER_EOF
        chmod +x "$apm_dest"
        log_success "Wrapper básico criado"
    fi
    
    # Configurar diretórios do APM
    mkdir -p "$ROOTFS_DIR/etc/apm"
    mkdir -p "$ROOTFS_DIR/var/cache/apm"
    
    # Criar configuração do APM
    cat > "$ROOTFS_DIR/etc/apm/apm.conf" << EOF
# Configuração do Aether Package Manager
# Modo: wrapper (usa apt/dpkg internamente)

MODE=wrapper
BACKEND=apt
ENABLE_AUTO_UPDATE=true
AUTO_UPDATE_INTERVAL=daily
LOG_LEVEL=info
EOF
    
    log_success "APM configurado como wrapper do APT"
}

# Instalar pacotes adicionais recomendados
install_additional_packages() {
    log_header "Instalando Pacotes Adicionais"
    
    chroot_cmd() {
        chroot "$ROOTFS_DIR" "$@"
    }
    
    # Lista de pacotes úteis para desktop
    local desktop_packages=(
        "firmware-linux-nonfree"      # Firmware proprietário
        "firmware-misc-nonfree"       # Firmware adicional
        "firmware-realtek"            # Firmware Realtek
        "firmware-iwlwifi"            # Firmware Intel WiFi
        "firmware-atheros"            # Firmware Atheros
        "alsa-base"                   # Áudio
        "pulseaudio"                  # PulseAudio
        "xorg"                        # X.Org (base para desktop)
        "xserver-xorg-input-all"      # Drivers de entrada
        "xserver-xorg-video-all"      # Drivers de vídeo
        "fonts-noto"                  # Fontes
        "network-manager"             # NetworkManager
        "sudo"                        # Sudo
        "htop"                        # Monitor de sistema
        "tree"                        # Utilitário
        "git"                         # Git
        "curl"                        # Curl
        "wget"                        # Wget
    )
    
    log_step "Instalando pacotes adicionais: ${desktop_packages[*]}"
    
    # Instalar pacotes (ignora erros individuais)
    chroot_cmd apt-get install -y "${desktop_packages[@]}" || {
        log_warn "Alguns pacotes falharam ao instalar, continuando..."
    }
    
    log_success "Pacotes adicionais instalados"
}

# Desmontar sistemas de arquivos
unmount_systems() {
    log_header "Desmontando Sistemas de Arquivos"
    
    log_step "Desmontando..."
    umount -l "$ROOTFS_DIR/run" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/dev" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/sys" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/proc" 2>/dev/null || true
    
    log_success "Sistemas desmontados"
}

# Copiar kernel customizado (se existir)
copy_custom_kernel() {
    log_header "Copiando Kernel Customizado (se existir)"
    
    local kernel_dir="$AETHER_ROOT/rootfs-kernel"
    
    if [ -d "$kernel_dir/boot" ]; then
        log_step "Copiando kernel customizado..."
        
        # Copiar kernel e initrd
        cp -v "$kernel_dir/boot/vmlinuz"* "$ROOTFS_DIR/boot/" 2>/dev/null || true
        cp -v "$kernel_dir/boot/initrd"* "$ROOTFS_DIR/boot/" 2>/dev/null || true
        cp -v "$kernel_dir/boot/System.map"* "$ROOTFS_DIR/boot/" 2>/dev/null || true
        cp -v "$kernel_dir/boot/config"* "$ROOTFS_DIR/boot/" 2>/dev/null || true
        
        # Copiar módulos
        if [ -d "$kernel_dir/lib/modules" ]; then
            cp -rv "$kernel_dir/lib/modules"/* "$ROOTFS_DIR/lib/modules/" 2>/dev/null || true
        fi
        
        log_success "Kernel customizado copiado"
    else
        log_warn "Nenhum kernel customizado encontrado em $kernel_dir"
        log_step "Usando kernel padrão do Debian/Ubuntu"
    fi
}

# Mostrar resumo
show_summary() {
    log_header "Resumo da Construção"
    
    echo -e "${GREEN}Sistema base construído com sucesso!${NC}"
    echo ""
    echo "Informações:"
    echo "  Rootfs: $ROOTFS_DIR"
    echo "  Tamanho: $(du -sh "$ROOTFS_DIR" | cut -f1)"
    echo "  Distribuição: ${DISTRO:-debian} ${SUITE:-bookworm}"
    echo ""
    echo "Próximos passos:"
    echo "  1. Instalar ambiente desktop (KDE, GNOME, etc.)"
    echo "  2. Configurar usuário e senha root"
    echo "  3. Gerar ISO bootável"
    echo ""
    echo "Para entrar no chroot manualmente:"
    echo "  chroot $ROOTFS_DIR /bin/bash"
    echo ""
}

# Main
main() {
    echo -e "${CYAN}"
    cat << EOF
    
    ╔══════════════════════════════════════════════════╗
    ║     Aether OS - Debootstrap Build System        ║
    ║     Criando rootfs baseado em Debian/Ubuntu     ║
    ╚══════════════════════════════════════════════════╝
    
EOF
    echo -e "${NC}"
    
    local start_time=$(date +%s)
    
    # Executar etapas
    check_prerequisites
    cleanup_rootfs
    run_debootstrap
    configure_sources
    configure_base_system
    update_and_install_kernel
    setup_apm_wrapper
    install_additional_packages
    unmount_systems
    copy_custom_kernel
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    show_summary
    
    echo -e "${GREEN}Tempo total: $((duration / 60))m $((duration % 60))s${NC}"
}

# Executar
main "$@"
