# Aether OS - Distribuição Linux do Zero

## Visão Geral

Aether OS é uma distribuição Linux construída completamente do zero, seguindo os princípios do Linux From Scratch (LFS), com foco em desempenho, estabilidade e segurança.

## Decisões Técnicas Fundamentais

### 1. Sistema de Inicialização: systemd vs sysvinit vs OpenRC

**Decisão:** Utilizar **systemd** como sistema de inicialização padrão.

**Justificativa Técnica:**
- Gerenciamento paralelo de serviços (inicialização mais rápida)
- Sistema de dependências automático entre serviços
- Journal unificado para logs do sistema
- Suporte nativo a cgroups para controle de processos
- Integração com recursos modernos como mount automático, networkd, resolved
- Amplamente adotado pela indústria (Red Hat, Debian, Arch, SUSE)
- Melhor suporte a hardware moderno e hotplug

**Alternativas consideradas:**
- sysvinit: Mais simples, mas inicialização sequencial lenta
- OpenRC: Leve, mas menos recursos e adoção limitada

### 2. Gerenciador de Pacotes Próprio: Aether Package Manager (APM)

**Decisão:** Desenvolver um gerenciador de pacotes baseado em formatos binários pré-compilados com fallback para compilação source-based.

**Arquitetura:**
- Formato de pacote: `.apm` (arquivo tar.xz com metadados JSON)
- Repositórios remotos assinados cryptographicamente
- Resolução de dependências via SAT solver (inspirado no DNF/APT)
- Cache local de pacotes compilados
- Suporte a múltiplas arquiteturas (x86_64, aarch64)

**Justificativa:**
- Controle total sobre o ciclo de vida dos pacotes
- Otimizações específicas para nosso toolchain
- Segurança através de assinatura de pacotes
- Flexibilidade para updates atômicos (inspirado em OSTree)

### 3. Bootloader: GRUB2 + systemd-boot

**Decisão:** Suporte dual para BIOS (GRUB2) e UEFI (systemd-boot).

**Justificativa Técnica:**
- **GRUB2:** Compatibilidade máxima com BIOS legacy, suporte a múltiplos sistemas de arquivos, tema customizável
- **systemd-boot:** Simplicidade para UEFI, integração nativa com systemd, boot mais rápido, configuração em formato simples
- **Fallback:** Ambos instalados para máxima compatibilidade

### 4. Kernel Linux

**Decisão:** Kernel Linux 6.6 LTS (Long Term Support) com patches de segurança e otimizações.

**Justificativa:**
- Versão LTS garante estabilidade e suporte prolongado
- Patches de segurança backportados da comunidade
- Configuração otimizada para desktop/workstation
- Módulos necessários para AMD, Intel e NVIDIA incluídos
- Recursos modernos: BTRFS, ZSTD compression, FSCACHE

### 5. Ambiente Gráfico

**Decisão:** KDE Plasma 6 como ambiente padrão, com GNOME e WM alternativos disponíveis.

**Justificativa:**
- KDE Plasma: Moderno, altamente customizável, Wayland nativo, bom suporte a HiDPI
- Qt6: Framework moderno e performático
- Alternativas: GNOME (para usuários que preferem simplicidade), i3/Sway (para power users)

### 6. Sistema de Arquivos

**Decisão:** 
- Padrão: BTRFS com compressão ZSTD
- Opções: EXT4 (compatibilidade), XFS (performance), ZFS (via módulo)

**Justificativa:**
- BTRFS: Snapshots automáticos, checksums de dados, compressão transparente, RAID software
- ZSTD: Melhor relação compressão/performance
- Snapshots permitem rollback fácil após updates problemáticos

### 7. Drivers de Vídeo

**Decisão:** Suporte completo para AMD, Intel e NVIDIA.

**Estratégia:**
- **AMD/Intel:** Drivers open-source (amdgpu, i915) incluídos no kernel
- **NVIDIA:** Driver proprietário (nvidia-dkms) como opção, com Nouveau como fallback
- **Wayland:** Prioridade, com Xorg como fallback para compatibilidade

### 8. Segurança

**Decisões:**
- SELinux habilitado por padrão (política targeted)
- Firewall: nftables com frontend (firewalld)
- Secure Boot suportado (assinatura de kernel e módulos)
- ASLR, PIE, Stack Protector habilitados no toolchain
- Atualizações automáticas opcionais com verificação de assinatura

### 9. Instalador

**Decisão:** Instalador duplo (gráfico e texto).

**Implementação:**
- **Gráfico:** Baseado em Qt6, interface moderna, particionamento assistido
- **Texto:** Baseado em ncurses, para sistemas sem X/Wayland ou recovery
- **Backend comum:** Calamares adaptado ou solução própria em Python

### 10. Toolchain

**Decisão:** GCC 13.x com binutils 2.41, glibc 2.38.

**Justificativa:**
- GCC 13: Suporte a C++20, otimizações modernas, melhor diagnóstico
- glibc 2.38: Estabilidade, suporte a features recentes do kernel
- Compilação com -O2 -pipe -fstack-protector-strong

---

## Estrutura de Diretórios

```
aether-os/
├── tools/                    # Ferramentas auxiliares
├── sources/                  # Código-fonte dos pacotes
│   ├── kernel/
│   ├── bootloader/
│   ├── system/
│   └── desktop/
├── patches/                  # Patches customizados
│   ├── kernel/
│   ├── gcc/
│   └── glibc/
├── scripts/
│   ├── cross-toolchain/     # Scripts para toolchain cruzada
│   │   ├── 01-build-binutils.sh
│   │   ├── 02-build-gcc-pass1.sh
│   │   ├── 03-build-linux-headers.sh
│   │   ├── 04-build-glibc.sh
│   │   └── 05-build-gcc-pass2.sh
│   ├── system-build/        # Construção do sistema base
│   │   ├── 01-kernel.sh
│   │   ├── 02-systemd.sh
│   │   ├── 03-coreutils.sh
│   │   └── ...
│   ├── iso/                 # Geração da ISO
│   │   └── create-iso.sh
│   └── installer/           # Scripts do instalador
├── rootfs/                   # Raiz do sistema alvo
│   ├── etc/
│   ├── var/
│   ├── usr/
│   └── boot/
├── configs/
│   ├── kernel/              # Configurações do kernel
│   │   └── config-x86_64
│   ├── systemd/
│   └── grub/
├── docs/                     # Documentação
│   ├── building.md
│   ├── installation.md
│   └── package-management.md
├── packages/                 # Pacotes binários resultantes
└── iso/                      # Imagem ISO final
    └── aether-os-x86_64.iso
```

---

## Próximos Passos

1. **Cross-Toolchain:** Compilar toolchain inicial (binutils, gcc pass1, linux-headers, glibc, gcc pass2)
2. **Sistema Base:** Compilar pacotes essenciais (coreutils, bash, systemd, etc.)
3. **Kernel:** Configurar e compilar kernel Linux 6.6 LTS
4. **Bootloader:** Configurar GRUB2 e systemd-boot
5. **Desktop:** Integrar KDE Plasma 6 e dependências
6. **APM:** Implementar gerenciador de pacotes
7. **Instalador:** Desenvolver instalador gráfico e texto
8. **ISO:** Gerar imagem inicializável

Vamos começar implementando os scripts de construção da cross-toolchain.
