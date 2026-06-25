# 🚀 Guia Rápido - Aether OS com Base Debian/Ubuntu

Este guia explica como construir o Aether OS usando pacotes do Debian/Ubuntu para máxima compatibilidade.

## 📋 Visão Geral

O Aether OS agora utiliza `debootstrap` para criar um sistema base compatível com pacotes `.deb`, mantendo a identidade própria através do kernel customizado e do gerenciador APM (wrapper do APT).

### Vantagens desta abordagem:

- ✅ **Compatibilidade total** com pacotes .deb do Debian/Ubuntu
- ✅ **Estabilidade** de pacotes testados e validados
- ✅ **Ecossistema vasto** de software disponível
- ✅ **Manutenção simplificada** de segurança e updates
- ✅ **Identidade própria** com kernel customizado e APM

---

## 🔧 Pré-requisitos

```bash
# No sistema hospedeiro (Debian/Ubuntu)
sudo apt update
sudo apt install -y \
    debootstrap \
    wget \
    tar \
    xz-utils \
    fakeroot \
    xorriso \
    squashfs-tools \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools
```

---

## 🏗️ Processo de Build

### Método 1: Build Automático (Recomendado)

```bash
cd /workspace/aether-os

# Executar script mestre de build com debootstrap
sudo ./build-all-debootstrap.sh
```

### Método 2: Build Passo a Passo

#### Passo 1: Criar Sistema Base com Debootstrap

```bash
cd /workspace/aether-os

# Configurar variáveis opcionais
export DISTRO="debian"        # ou "ubuntu"
export SUITE="bookworm"       # Debian 12 ou "jammy" para Ubuntu 22.04
export ARCH="amd64"

# Executar build do rootfs
sudo ./scripts/system-build/02-build-rootfs-debootstrap.sh
```

**Tempo estimado:** 5-15 minutos (depende da conexão)

#### Passo 2: (Opcional) Compilar Kernel Customizado

Se quiser usar seu kernel customizado em vez do kernel padrão:

```bash
# Compilar kernel (se ainda não compilou)
sudo ./scripts/system-build/01-build-kernel.sh

# O script de ISO detectará automaticamente o kernel customizado
```

#### Passo 3: Gerar ISO Bootável

```bash
sudo ./scripts/iso/create-iso-debootstrap.sh
```

**Tempo estimado:** 3-10 minutos

---

## 📀 Testando a ISO

### QEMU (Recomendado para testes rápidos)

```bash
# BIOS/Legacy
qemu-system-x86_64 \
    -cdrom /workspace/aether-os/iso/aether-os-x86_64.iso \
    -boot d \
    -m 4G \
    -cpu host \
    -enable-kvm

# UEFI
qemu-system-x86_64 \
    -cdrom /workspace/aether-os/iso/aether-os-x86_64.iso \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -m 4G \
    -cpu host \
    -enable-kvm
```

### VMware/VirtualBox

1. Crie nova VM (Linux, 64-bit)
2. Aloque 4GB+ RAM
3. Selecione a ISO como disco de boot
4. Inicie a VM

### Hardware Real (USB)

```bash
# ⚠️ CUIDADO: Substitua /dev/sdX pelo dispositivo correto!
sudo dd if=/workspace/aether-os/iso/aether-os-x86_64.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    conv=fsync

# Ejetar com segurança
sync
sudo eject /dev/sdX
```

---

## 📦 Gerenciador de Pacotes APM

O APM v2.0 é um wrapper completo do APT com interface amigável:

### Comandos Básicos

```bash
# Atualizar repositórios
apm update

# Instalar pacotes
apm install firefox vim git

# Buscar pacotes
apm search browser

# Informações do pacote
apm info nginx

# Listar instalados
apm list installed

# Upgrade do sistema
apm upgrade

# Limpar cache
apm clean

# Remover pacotes
apm remove nome-do-pacote

# Estatísticas
apm stats
```

### Atalhos

```bash
apm i <pkg>     # install
apm u           # update
apm up          # upgrade
apm s <termo>   # search
apm l           # list
apm c           # clean
apm r <pkg>     # remove
```

### Comandos Avançados

```bash
# Adicionar PPA (Ubuntu)
apm repo add ppa:kisak/kubuntu-focal-backports

# Instalar dependências de build
apm build-dep linux

# Baixar código fonte
apm source firefox

# Ver dependências
apm depends systemd

# Buscar arquivo em pacotes
apm file /usr/bin/python3
```

---

## ⌨️ Configurações Padrão

- **Layout de teclado:** PT-BR (br-ab)
- **Locale:** pt_BR.UTF-8
- **Timezone:** America/Sao_Paulo
- **Hostname:** aether-os
- **Usuário root:** Sem senha (configurar no primeiro boot)

---

## 🛠️ Personalização

### Mudar Distribuição Base

Edite as variáveis no script:

```bash
# Para Ubuntu 22.04 LTS
export DISTRO="ubuntu"
export SUITE="jammy"
export MIRROR="http://archive.ubuntu.com/ubuntu"

# Para Debian Testing
export DISTRO="debian"
export SUITE="testing"
export MIRROR="http://deb.debian.org/debian"
```

### Adicionar Pacotes Extras

Edite `install_additional_packages()` em `02-build-rootfs-debootstrap.sh`:

```bash
local desktop_packages=(
    "kde-plasma-desktop"     # KDE Plasma
    "gnome-core"             # GNOME
    "xfce4"                  # XFCE
    "libreoffice"            # LibreOffice
    # Adicione seus pacotes aqui
)
```

### Kernel Customizado

Para usar seu kernel compilado:

1. Compile o kernel com `01-build-kernel.sh`
2. Copie para `rootfs-kernel/boot/`
3. Execute `create-iso-debootstrap.sh` (detecta automaticamente)

---

## 🐛 Solução de Problemas

### ISO não boota

Verifique se o kernel foi copiado corretamente:
```bash
ls -lh /workspace/aether-os/iso_root/isolinux/
```

### Erro no debootstrap

Verifique conexão e mirrors:
```bash
ping deb.debian.org
wget http://deb.debian.org/debian/dists/bookworm/Release
```

### APM não encontrado no live system

O APM é instalado automaticamente. Se faltar:
```bash
cp /workspace/aether-os/scripts/package-manager/apm-deb-wrapper.sh /usr/bin/apm
chmod +x /usr/bin/apm
```

### Espaço em disco insuficiente

Libere espaço ou use disco externo:
```bash
df -h
# Mínimo recomendado: 20GB livres
```

---

## 📊 Estrutura de Arquivos

```
/workspace/aether-os/
├── scripts/
│   ├── system-build/
│   │   ├── 01-build-kernel.sh          # Kernel customizado
│   │   └── 02-build-rootfs-debootstrap.sh  # ✨ NOVO: Rootfs Debian/Ubuntu
│   ├── package-manager/
│   │   ├── apm.sh                      # APM original (formato .apm)
│   │   └── apm-deb-wrapper.sh          # ✨ NOVO: APM wrapper APT
│   └── iso/
│       ├── create-iso.sh               # ISO tradicional
│       └── create-iso-debootstrap.sh   # ✨ NOVO: ISO com rootfs Debian
├── rootfs/                             # Sistema gerado pelo debootstrap
├── iso/                                # ISOs geradas
└── build-all-debootstrap.sh            # ✨ NOVO: Script mestre
```

---

## 🎯 Próximos Passos

1. **Desktop Environment:** Instale KDE, GNOME ou XFCE
2. **Display Manager:** Configure SDDM, GDM ou LightDM
3. **Aplicativos:** Adicione Firefox, LibreOffice, etc.
4. **Temas:** Personalize aparência
5. **Installer:** Finalize instalador para HD/SSD

---

## 📚 Recursos

- [Documentação Debian](https://www.debian.org/doc/)
- [Debootstrap Wiki](https://wiki.debian.org/Debootstrap)
- [APT Documentation](https://wiki.debian.org/Apt)
- [Aether OS Architecture](docs/ARCHITECTURE.md)

---

**Aether OS** - Construído com ❤️ sobre a base mais estável do Linux
