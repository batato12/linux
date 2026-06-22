# Aether OS - Distribuição Linux do Zero

![Aether OS](https://img.shields.io/badge/Aether-OS-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)
![Kernel](https://img.shields.io/badge/Kernel-6.6_LTS-orange)
![Status](https://img.shields.io/badge/Status-Development-red)

## Visão Geral

**Aether OS** é uma distribuição Linux construída completamente do zero, seguindo os princípios do **Linux From Scratch (LFS)**. O projeto tem como objetivo criar um sistema operacional moderno, performático e seguro, com controle total sobre cada componente.

## ✨ Características Principais

| Recurso | Descrição |
|---------|-----------|
| 🐧 **Kernel** | Linux 6.6 LTS com otimizações para desktop |
| 🔐 **Segurança** | SELinux, AppArmor, ASLR, Stack Protector |
| 📦 **Pacotes** | APM (Aether Package Manager) próprio |
| 🖥️ **Desktop** | KDE Plasma 6 (padrão), GNOME, i3/Sway disponíveis |
| 🚀 **Boot** | Suporte dual UEFI (systemd-boot) + BIOS (GRUB2) |
| 💾 **Filesystem** | BTRFS com compressão ZSTD e snapshots |
| 🎮 **GPU** | Suporte completo AMD, Intel e NVIDIA |
| 🔄 **Updates** | Atualizações automáticas opcionais |
| 📀 **ISO** | Imagem híbrida bootável BIOS/UEFI |

## 🏗️ Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    Aether OS Architecture                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  KDE/GNOME  │  │   Wayland   │  │    X11 (fallback)   │ │
│  │   Desktop   │  │   Display   │  │      Compatibil.    │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │              systemd (Init & Service Manager)           ││
│  │         JournalD │ NetworkD │ ResolveD │ TimedateD     ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    APM      │  │   Bash/Zsh  │  │    Core Utilities   │ │
│  │  Pkg Mgr    │  │   Shells    │  │     (GNU/BusyBox)   │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │                  GNU C Library (glibc 2.38)             ││
│  │            GCC 13 Toolchain │ Binutils 2.41            ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Linux Kernel 6.6 LTS (Custom Config)       ││
│  │     DRM │ Network │ Storage │ Security │ Virtualization ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 📁 Estrutura do Projeto

```
aether-os/
├── docs/                      # Documentação completa
│   ├── ARCHITECTURE.md        # Decisões técnicas e arquitetura
│   ├── BUILDING.md            # Guia de compilação
│   ├── INSTALLATION.md        # Guia de instalação
│   └── PACKAGE_MANAGEMENT.md  # Documentação do APM
│
├── configs/
│   └── kernel/
│       └── config-x86_64      # Configuração customizada do kernel
│
├── scripts/
│   ├── cross-toolchain/       # Toolchain cruzada
│   │   ├── 01-build-binutils.sh
│   │   ├── 02-build-gcc-pass1.sh
│   │   ├── 03-build-linux-headers.sh
│   │   ├── 04-build-glibc.sh
│   │   └── 05-build-gcc-pass2.sh
│   │
│   ├── system-build/          # Sistema base
│   │   ├── 01-build-kernel.sh
│   │   ├── 02-build-systemd.sh
│   │   └── ...
│   │
│   ├── package-manager/       # Gerenciador de pacotes
│   │   └── apm.sh
│   │
│   ├── installer/             # Instaladores
│   │   ├── install-text.sh    # Modo texto (ncurses)
│   │   └── install-gui.py     # Modo gráfico (PyQt6)
│   │
│   └── iso/                   # Geração da ISO
│       └── create-iso.sh
│
├── rootfs/                    # Raiz do sistema alvo
│   ├── boot/
│   ├── etc/
│   ├── usr/
│   └── var/
│
├── sources/                   # Código-fonte dos pacotes
├── patches/                   # Patches customizados
├── tools/                     # Ferramentas de build
└── iso/                       # ISO gerada
    └── aether-os-x86_64.iso
```

## 🚀 Quick Start

### Pré-requisitos

- Sistema Linux x86_64 (recomendado: Debian/Ubuntu/Fedora)
- Mínimo 50GB de espaço em disco
- Mínimo 8GB RAM (16GB recomendado)
- Pacotes necessários:
  ```bash
  # Debian/Ubuntu
  sudo apt install build-essential bison flex gawk gettext git wget \
                   libncurses-dev libssl-dev python3 python3-pip \
                   xorriso syslinux grub-common grub-efi-amd64 \
                   squashfs-tools cpio kmod
  
  # Fedora
  sudo dnf install gcc gcc-c++ make bison flex gawk gettext git wget \
                   ncurses-devel openssl-devel python3 python3-pip \
                   xorriso syslinux grub2-efi-x64 squashfs-tools \
                   cpio kmod
  ```

### Processo de Build

#### 1. Clonar o repositório
```bash
git clone https://github.com/aether-os/aether-os.git
cd aether-os
```

#### 2. Construir toolchain cruzada
```bash
cd scripts/cross-toolchain
./01-build-binutils.sh
./02-build-gcc-pass1.sh
./03-build-linux-headers.sh
./04-build-glibc.sh
./05-build-gcc-pass2.sh
```

#### 3. Construir sistema base
```bash
cd ../system-build
./01-build-kernel.sh
# ... outros componentes
```

#### 4. Gerar ISO bootável
```bash
cd ../iso
./create-iso.sh
```

### Script Mestre (Recomendado)
```bash
# Build completo automatizado
./build-all.sh
```

## 📦 Gerenciador de Pacotes (APM)

O **APM (Aether Package Manager)** é o gerenciador de pacotes nativo do Aether OS:

```bash
# Inicializar
apm init

# Atualizar repositórios
apm update

# Instalar pacotes
apm install firefox kde-plasma vlc

# Buscar pacotes
apm search browser

# Listar instalados
apm list

# Remover pacote
apm remove vim

# Atualizar sistema
apm upgrade

# Configurar atualizações automáticas
apm auto-update
```

## 🖥️ Instalação

### Via Live USB
1. Grave a ISO em um pendrive:
   ```bash
   dd if=aether-os-x86_64.iso of=/dev/sdX bs=4M status=progress
   ```

2. Boot pelo USB e execute o instalador:
   - **Modo Gráfico**: `install-gui`
   - **Modo Texto**: `install-text`

### Requisitos de Sistema

| Componente | Mínimo | Recomendado |
|------------|--------|-------------|
| CPU | Dual-core 64-bit | Quad-core ou superior |
| RAM | 4 GB | 8 GB ou mais |
| Disco | 20 GB | 50 GB SSD |
| GPU | Qualquer com 128MB | GPU dedicada 2GB+ |

## 🔧 Customização

### Kernel Personalizado

Edite `configs/kernel/config-x86_64` e reconstrua:
```bash
./scripts/system-build/01-build-kernel.sh
```

### Adicionar Pacotes

Crie um arquivo `.apm`:
```bash
mkdir mypackage
echo '{"name": "mypackage", "version": "1.0", "dependencies": []}' > mypackage/metadata.json
tar -cf mypackage.apm mypackage/
```

## 📊 Status do Desenvolvimento

| Componente | Status | Progresso |
|------------|--------|-----------|
| Toolchain | ✅ Completo | 100% |
| Kernel | ✅ Completo | 100% |
| Bootloader | ✅ Completo | 100% |
| Systemd | 🚧 Em progresso | 75% |
| APM | 🚧 Em progresso | 60% |
| Desktop (KDE) | ⏳ Pendente | 25% |
| Instalador GUI | ✅ Protótipo | 80% |
| Instalador TUI | ✅ Funcional | 90% |
| ISO Builder | ✅ Funcional | 95% |

Legenda: ✅ Completo | 🚧 Em andamento | ⏳ Pendente

## 🤝 Contribuindo

Contribuições são bem-vindas! Veja como ajudar:

1. **Reportar bugs**: Abra uma issue no GitHub
2. **Corrigir bugs**: Envie um PR com a correção
3. **Documentação**: Melhore a documentação existente
4. **Pacotes**: Crie novos pacotes para o repositório
5. **Tradução**: Ajude a traduzir para outros idiomas

### Guidelines de Desenvolvimento

- Siga o padrão de código existente
- Comente decisões técnicas complexas
- Teste localmente antes de enviar PRs
- Mantenha commits atômicos e descritivos

## 📄 Licença

Este projeto está licenciado sob a **GPL-3.0**. Veja [LICENSE](LICENSE) para detalhes.

## 🔗 Links Úteis

- [Linux From Scratch](http://www.linuxfromscratch.org/)
- [Kernel.org](https://kernel.org/)
- [systemd Documentation](https://systemd.io/)
- [KDE Plasma](https://kde.org/plasma-desktop)
- [BTRFS Wiki](https://btrfs.wiki.kernel.org/)

## 📞 Contato

- **GitHub Issues**: Para bugs e feature requests
- **Discord**: [link do servidor]
- **Email**: team@aether-os.org

---

**Aether OS** - Construído do zero, para você. 🚀
