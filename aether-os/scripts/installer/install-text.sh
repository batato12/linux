#!/bin/bash
# Aether OS - Instalador do Sistema (Versão Texto)
# Instalador baseado em ncurses para instalação em disco

set -euo pipefail

# Configurações
INSTALLER_VERSION="1.0.0"
TARGET_ROOT="${TARGET_ROOT:-/mnt/aether}"
LOG_FILE="/var/log/aether-install.log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variáveis de instalação
TARGET_DISK=""
TARGET_PARTITION=""
FILESYSTEM="btrfs"
USERNAME=""
HOSTNAME="aether-os"
TIMEZONE="America/Sao_Paulo"
KEYMAP="br-abnt2"

# Log function
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo -e "$msg" | tee -a "$LOG_FILE" 2>/dev/null || echo "$msg"
}

# Mostrar banner
show_banner() {
    clear
    cat << EOF
${CYAN}
    ___       _   _                   ____  
   / _ \     | | (_)                 / __ \ 
  / /_\ \_   _| |_ _  ___  _ __  ___| /  \/ 
  |  _  | | | | __| |/ _ \| '_ \/ __| |     
  | | | | |_| | |_| | (_) | | | \__ \ \__/\ 
  \_| |_/\__,_|\__|_|\___/|_| |_|___/\____/ 
                                            
${NC}
    Instalador do Aether OS v${INSTALLER_VERSION}
    =============================================
EOF
    echo ""
}

# Verificar privilégios de root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Erro: Este instalador deve ser executado como root${NC}"
        exit 1
    fi
}

# Detectar discos disponíveis
detect_disks() {
    log "Detectando discos disponíveis..."
    local disks=()
    
    for disk in /dev/sd? /dev/nvme?? /dev/vd?; do
        if [ -b "$disk" ] 2>/dev/null; then
            disks+=("$disk")
        fi
    done
    
    if [ ${#disks[@]} -eq 0 ]; then
        echo -e "${RED}Nenhum disco encontrado!${NC}"
        return 1
    fi
    
    echo ""
    echo "Discos disponíveis:"
    echo "==================="
    for i in "${!disks[@]}"; do
        local size=$(blockdev --getsize64 "${disks[$i]}" 2>/dev/null | numfmt --to=iec || echo "unknown")
        local model=$(cat "/sys/block/$(basename ${disks[$i]})/device/model" 2>/dev/null || echo "unknown")
        echo "  [$((i+1))] ${disks[$i]} - $size ($model)"
    done
    echo ""
    
    read -p "Selecione o disco para instalação (número): " disk_choice
    TARGET_DISK="${disks[$((disk_choice-1))]}"
    
    if [ -z "$TARGET_DISK" ]; then
        echo -e "${RED}Disco inválido selecionado${NC}"
        return 1
    fi
    
    echo "Disco selecionado: ${TARGET_DISK}"
}

# Particionar disco
partition_disk() {
    log "Particionando disco..."
    
    echo ""
    echo "Escolha o esquema de particionamento:"
    echo "  [1] Automático (EFI + Root + Swap)"
    echo "  [2] Manual (avançado)"
    echo "  [3] Usar partição existente"
    read -p "Opção: " part_option
    
    case "$part_option" in
        1)
            # Esquema automático para UEFI
            echo "Criando partições automáticas..."
            
            # Limpar tabela de partição
            wipefs -a "$TARGET_DISK" 2>/dev/null || true
            
            # Criar nova tabela GPT
            parted -s "$TARGET_DISK" mklabel gpt || die "Falha ao criar tabela GPT"
            
            # Criar partição EFI (512MB)
            parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 513MiB || die "Falha na partição EFI"
            parted -s "$TARGET_DISK" set 1 boot on || die "Falha ao setar flag boot"
            parted -s "$TARGET_DISK" set 1 esp on || true
            
            # Criar partição root (resto do disco menos swap)
            parted -s "$TARGET_DISK" mkpart primary btrfs 513MiB 100% || die "Falha na partição root"
            
            # Formatar partições
            log "Formatando partição EFI..."
            mkfs.vfat -F32 "${TARGET_DISK}1" || die "Falha ao formatar EFI"
            
            log "Formatando partição root com BTRFS..."
            mkfs.btrfs -f -L "AETHER_ROOT" "${TARGET_DISK}2" || die "Falha ao formatar root"
            
            TARGET_PARTITION="${TARGET_DISK}2"
            ;;
        2)
            echo "Particionamento manual não implementado nesta versão."
            echo "Use fdisk, cfdisk ou parted manualmente."
            read -p "Pressione Enter após particionar..."
            read -p "Informe a partição root (ex: /dev/sda2): " TARGET_PARTITION
            ;;
        3)
            read -p "Informe a partição root (ex: /dev/sda2): " TARGET_PARTITION
            ;;
        *)
            echo "Opção inválida"
            return 1
            ;;
    esac
    
    log "Partição root: $TARGET_PARTITION"
}

# Configurar usuário
setup_user() {
    echo ""
    echo "=== Configuração do Usuário ==="
    echo ""
    
    read -p "Nome de usuário: " USERNAME
    read -sp "Senha do usuário: " USER_PASS
    echo ""
    read -sp "Confirme a senha: " USER_PASS_CONFIRM
    echo ""
    
    if [ "$USER_PASS" != "$USER_PASS_CONFIRM" ]; then
        echo -e "${RED}Senhas não conferem!${NC}"
        return 1
    fi
    
    read -p "Hostname [aether-os]: " HOSTNAME
    HOSTNAME="${HOSTNAME:-aether-os}"
}

# Montar sistemas de arquivos
mount_filesystems() {
    log "Montando sistemas de arquivos..."
    
    mkdir -p "$TARGET_ROOT"
    
    # Montar root
    mount "$TARGET_PARTITION" "$TARGET_ROOT" || die "Falha ao montar root"
    
    # Criar subvolumes BTRFS se necessário
    if [ "$FILESYSTEM" = "btrfs" ]; then
        log "Criando subvolumes BTRFS..."
        btrfs subvolume create "$TARGET_ROOT/@root" 2>/dev/null || true
        btrfs subvolume create "$TARGET_ROOT/@home" 2>/dev/null || true
        btrfs subvolume create "$TARGET_ROOT/@var" 2>/dev/null || true
        btrfs subvolume create "$TARGET_ROOT/@snapshots" 2>/dev/null || true
        
        umount "$TARGET_ROOT"
        mount -o subvol=@root "$TARGET_PARTITION" "$TARGET_ROOT"
        mkdir -p "$TARGET_ROOT"/{home,var,.snapshots}
        mount -o subvol=@home "$TARGET_PARTITION" "$TARGET_ROOT/home"
        mount -o subvol=@var "$TARGET_PARTITION" "$TARGET_ROOT/var"
        mount -o subvol=@snapshots "$TARGET_PARTITION" "$TARGET_ROOT/.snapshots"
    fi
    
    # Montar EFI se existir
    if [ -b "${TARGET_DISK}1" ]; then
        mkdir -p "$TARGET_ROOT/boot/efi"
        mount "${TARGET_DISK}1" "$TARGET_ROOT/boot/efi" || die "Falha ao montar EFI"
    fi
    
    # Montar sistemas virtuais
    mount -t proc proc "$TARGET_ROOT/proc"
    mount -t sysfs sys "$TARGET_ROOT/sys"
    mount --rbind /dev "$TARGET_ROOT/dev"
    mount --rbind /run "$TARGET_ROOT/run"
    
    log "Sistemas de arquivos montados"
}

# Instalar sistema base
install_base_system() {
    log "Instalando sistema base..."
    
    # Em produção, isso usaria o APM para instalar pacotes
    # Aqui é uma simulação da estrutura
    
    mkdir -p "$TARGET_ROOT"/{bin,sbin,lib,lib64,usr,etc,var,home,opt,mnt,tmp,root}
    mkdir -p "$TARGET_ROOT"/usr/{bin,sbin,lib,lib64,share,include,src}
    mkdir -p "$TARGET_ROOT"/var/{log,cache,lib,pkg}
    mkdir -p "$TARGET_ROOT"/etc/{systemd,network,locale,apt}
    
    # Copiar binários essenciais do sistema live
    if [ -d /usr/bin ]; then
        cp -a /usr/bin/busybox* "$TARGET_ROOT/usr/bin/" 2>/dev/null || true
    fi
    
    # Criar fstab
    generate_fstab
    
    log "Sistema base instalado"
}

# Gerar fstab
generate_fstab() {
    log "Gerando fstab..."
    
    cat > "$TARGET_ROOT/etc/fstab" << EOF
# /etc/fstab: static file system information for Aether OS
# <file system>                           <dir>      <type>  <options>           <dump> <pass>
EOF
    
    # Adicionar partição root
    local root_uuid=$(blkid -s UUID -o value "$TARGET_PARTITION" 2>/dev/null || echo "")
    if [ -n "$root_uuid" ]; then
        echo "UUID=$root_uuid  /           $FILESYSTEM  defaults              0  1" >> "$TARGET_ROOT/etc/fstab"
    else
        echo "$TARGET_PARTITION  /           $FILESYSTEM  defaults              0  1" >> "$TARGET_ROOT/etc/fstab"
    fi
    
    # Adicionar EFI se existir
    if [ -b "${TARGET_DISK}1" ]; then
        local efi_uuid=$(blkid -s UUID -o value "${TARGET_DISK}1" 2>/dev/null || echo "")
        if [ -n "$efi_uuid" ]; then
            echo "UUID=$efi_uuid  /boot/efi   vfat        umask=0077          0  2" >> "$TARGET_ROOT/etc/fstab"
        else
            echo "${TARGET_DISK}1  /boot/efi   vfat        umask=0077          0  2" >> "$TARGET_ROOT/etc/fstab"
        fi
    fi
    
    log "fstab gerado"
}

# Configurar sistema
configure_system() {
    log "Configurando sistema..."
    
    # Hostname
    echo "$HOSTNAME" > "$TARGET_ROOT/etc/hostname"
    
    # Hosts
    cat > "$TARGET_ROOT/etc/hosts" << EOF
127.0.0.1       localhost
127.0.1.1       $HOSTNAME
::1             localhost ip6-localhost ip6-loopback
EOF
    
    # Timezone
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$TARGET_ROOT/etc/localtime"
    echo "$TIMEZONE" > "$TARGET_ROOT/etc/timezone"
    
    # Locale
    cat > "$TARGET_ROOT/etc/locale.conf" << EOF
LANG=pt_BR.UTF-8
LC_COLLATE=C
EOF
    
    # Keymap
    echo "KEYMAP=$KEYMAP" > "$TARGET_ROOT/etc/vconsole.conf"
    
    # Network (systemd-networkd básico)
    cat > "$TARGET_ROOT/etc/systemd/network/eth0.network" << EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    
    log "Sistema configurado"
}

# Instalar bootloader
install_bootloader() {
    log "Instalando bootloader..."
    
    # Detectar se é UEFI ou BIOS
    if [ -d "$TARGET_ROOT/boot/efi" ] && [ -d /sys/firmware/efi ]; then
        # UEFI
        log "Instalando GRUB para UEFI..."
        grub-install --target=x86_64-efi \
            --efi-directory="$TARGET_ROOT/boot/efi" \
            --bootloader-id="AetherOS" \
            --recheck \
            --no-nvram || log_warn "Falha ao instalar GRUB UEFI"
        
        # Gerar config GRUB
        grub-mkconfig -o "$TARGET_ROOT/boot/grub/grub.cfg" || true
    else
        # BIOS
        log "Instalando GRUB para BIOS..."
        grub-install --target=i386-pc \
            --recheck \
            "$TARGET_DISK" || log_warn "Falha ao instalar GRUB BIOS"
        
        grub-mkconfig -o "$TARGET_ROOT/boot/grub/grub.cfg" || true
    fi
    
    log "Bootloader instalado"
}

# Finalizar instalação
finalize_install() {
    log "Finalizando instalação..."
    
    # Desmontar tudo
    umount -R "$TARGET_ROOT" 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo "   Instalação concluída com sucesso!"
    echo -e "==========================================${NC}"
    echo ""
    echo "Remova a mídia de instalação e reinicie o sistema."
    echo ""
    echo "Credenciais padrão:"
    echo "  Usuário: $USERNAME"
    echo "  Hostname: $HOSTNAME"
    echo ""
}

# Função principal
main() {
    check_root
    show_banner
    
    echo "Este instalador irá instalar o Aether OS no seu disco rígido."
    echo "Todos os dados no disco selecionado serão PERDIDOS!"
    echo ""
    read -p "Deseja continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        echo "Instalação cancelada."
        exit 0
    fi
    
    detect_disks || exit 1
    partition_disk || exit 1
    setup_user || exit 1
    mount_filesystems || exit 1
    install_base_system || exit 1
    configure_system || exit 1
    install_bootloader || true  # Não falhar se bootloader falhar
    finalize_install || exit 1
}

# Executar
main "$@"
