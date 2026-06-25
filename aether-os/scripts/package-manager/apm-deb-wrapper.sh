#!/bin/bash
# APM - Aether Package Manager (Wrapper para APT/DPKG)
# Compatibilidade total com pacotes .deb do Debian/Ubuntu

set -euo pipefail

# Configurações
APM_VERSION="2.0.0-deb"
APM_CONF="/etc/apm/apm.conf"
APM_LOG="/var/log/apm.log"
BACKEND="${APM_BACKEND:-apt}"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções de log
log_info() {
    echo -e "${BLUE}[APM]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[ATENÇÃO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $*" >&2
}

# Verificar se está rodando como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este comando precisa ser executado como root"
        exit 1
    fi
}

# Comando: install (instalar pacotes)
cmd_install() {
    check_root
    
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm install <pacote1> [pacote2] ..."
        exit 1
    fi
    
    log_info "Instalando pacotes: $*"
    log_info "(usando backend: $BACKEND)"
    
    case "$BACKEND" in
        apt|apt-get)
            apt-get update -qq
            apt-get install -y "$@"
            ;;
        dpkg)
            for pkg in "$@"; do
                if [ -f "$pkg" ]; then
                    dpkg -i "$pkg" || apt-get install -f -y
                else
                    log_error "Arquivo não encontrado: $pkg"
                fi
            done
            ;;
        *)
            log_error "Backend desconhecido: $BACKEND"
            exit 1
            ;;
    esac
    
    log_success "Pacotes instalados com sucesso!"
}

# Comando: remove (remover pacotes)
cmd_remove() {
    check_root
    
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm remove <pacote1> [pacote2] ..."
        exit 1
    fi
    
    log_info "Removendo pacotes: $*"
    
    case "$BACKEND" in
        apt|apt-get)
            apt-get remove -y "$@"
            apt-get autoremove -y
            ;;
        dpkg)
            dpkg -r "$@"
            ;;
        *)
            log_error "Backend desconhecido: $BACKEND"
            exit 1
            ;;
    esac
    
    log_success "Pacotes removidos com sucesso!"
}

# Comando: purge (remover completamente com configurações)
cmd_purge() {
    check_root
    
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm purge <pacote1> [pacote2] ..."
        exit 1
    fi
    
    log_info "Removendo pacotes completamente: $*"
    
    apt-get purge -y "$@"
    apt-get autoremove -y
    
    log_success "Pacotes removidos completamente!"
}

# Comando: update (atualizar lista de repositórios)
cmd_update() {
    log_info "Atualizando lista de repositórios..."
    
    apt-get update
    
    log_success "Repositórios atualizados!"
}

# Comando: upgrade (atualizar todos os pacotes)
cmd_upgrade() {
    check_root
    
    log_info "Atualizando todos os pacotes..."
    
    case "${1:-standard}" in
        standard)
            apt-get upgrade -y
            ;;
        full)
            apt-get full-upgrade -y
            ;;
        dist)
            apt-get dist-upgrade -y
            ;;
        *)
            log_error "Tipo de upgrade desconhecido: $1"
            echo "Tipos válidos: standard, full, dist"
            exit 1
            ;;
    esac
    
    log_success "Sistema atualizado com sucesso!"
}

# Comando: search (buscar pacotes)
cmd_search() {
    if [ $# -eq 0 ]; then
        log_error "Termo de busca não especificado"
        echo "Uso: apm search <termo>"
        exit 1
    fi
    
    log_info "Buscando por: $*"
    echo ""
    
    apt-cache search "$@" | head -50
}

# Comando: info (mostrar informações do pacote)
cmd_info() {
    if [ $# -eq 0 ]; then
        log_error "Nome do pacote não especificado"
        echo "Uso: apm info <pacote>"
        exit 1
    fi
    
    log_info "Informações do pacote: $1"
    echo ""
    
    apt-cache show "$1" | head -30
}

# Comando: list (listar pacotes)
cmd_list() {
    local mode="${1:-installed}"
    
    case "$mode" in
        installed)
            echo "Pacotes instalados:"
            echo "==================="
            dpkg --get-selections | grep -v deinstall | wc -l
            echo "pacotes no total"
            echo ""
            dpkg --get-selections | grep -v deinstall | head -50
            ;;
        available)
            echo "Pacotes disponíveis:"
            apt-cache dumpavail | grep "^Package:" | wc -l
            echo "pacotes disponíveis"
            ;;
        upgradable)
            echo "Pacotes atualizáveis:"
            apt list --upgradable
            ;;
        *)
            log_error "Modo desconhecido: $mode"
            echo "Modos válidos: installed, available, upgradable"
            exit 1
            ;;
    esac
}

# Comando: clean (limpar cache)
cmd_clean() {
    check_root
    
    log_info "Limpando cache de pacotes..."
    
    apt-get clean
    apt-get autoclean
    
    local cache_size=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    log_success "Cache limpo! Tamanho atual: $cache_size"
}

# Comando: autoremove (remover dependências órfãs)
cmd_autoremove() {
    check_root
    
    log_info "Removendo dependências órfãs..."
    
    apt-get autoremove -y
    
    log_success "Dependências órfãs removidas!"
}

# Comando: download (baixar pacote sem instalar)
cmd_download() {
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm download <pacote>"
        exit 1
    fi
    
    log_info "Baixando pacote: $1"
    
    apt-get download "$1"
    
    log_success "Pacote baixado: $(ls -lh *.deb 2>/dev/null | head -1)"
}

# Comando: source (baixar código fonte)
cmd_source() {
    check_root
    
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm source <pacote>"
        exit 1
    fi
    
    log_info "Baixando código fonte: $1"
    
    apt-get source "$1"
    
    log_success "Código fonte baixado!"
}

# Comando: build-dep (instalar dependências de build)
cmd_build_dep() {
    check_root
    
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm build-dep <pacote>"
        exit 1
    fi
    
    log_info "Instalando dependências de build: $1"
    
    apt-get build-dep -y "$1"
    
    log_success "Dependências de build instaladas!"
}

# Comando: policy (mostrar política de versões)
cmd_policy() {
    if [ $# -eq 0 ]; then
        log_info "Mostrando política de todos os repositórios..."
        apt-cache policy
    else
        log_info "Mostrando política do pacote: $1"
        apt-cache policy "$1"
    fi
}

# Comando: depends (mostrar dependências)
cmd_depends() {
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm depends <pacote>"
        exit 1
    fi
    
    echo "Dependências de $1:"
    apt-cache depends "$1"
}

# Comando: rdepends (mostrar dependências reversas)
cmd_rdepends() {
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm rdepends <pacote>"
        exit 1
    fi
    
    echo "Pacotes que dependem de $1:"
    apt-cache rdepends "$1"
}

# Comando: changelog (mostrar changelog)
cmd_changelog() {
    if [ $# -eq 0 ]; then
        log_error "Nenhum pacote especificado"
        echo "Uso: apm changelog <pacote>"
        exit 1
    fi
    
    log_info "Changelog de $1:"
    apt-cache changelog "$1" | head -50
}

# Comando: file (buscar pacote que contém arquivo)
cmd_file() {
    if [ $# -eq 0 ]; then
        log_error "Nenhum arquivo especificado"
        echo "Uso: apm file <caminho-do-arquivo>"
        exit 1
    fi
    
    log_info "Buscando pacote que contém: $1"
    
    # Instalar apt-file se necessário
    if ! command -v apt-file &> /dev/null; then
        log_info "Instalando apt-file..."
        apt-get install -y apt-file
        apt-file update
    fi
    
    apt-file search "$1" | head -20
}

# Comando: stats (mostrar estatísticas)
cmd_stats() {
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       Estatísticas do Aether Package Manager    ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Pacotes instalados:     $(dpkg --get-selections | grep -v deinstall | wc -l)"
    echo "Pacotes disponíveis:    $(apt-cache dumpavail | grep '^Package:' | wc -l)"
    echo "Pacotes atualizáveis:   $(apt list --upgradable 2>/dev/null | wc -l)"
    echo ""
    echo "Tamanho do cache APT:   $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Tamanho /var/lib/dpkg:  $(du -sh /var/lib/dpkg 2>/dev/null | cut -f1 || echo 'N/A')"
    echo ""
    echo "Backend:                $BACKEND"
    echo "Versão do APM:          $APM_VERSION"
}

# Comando: repo (gerenciar repositórios)
cmd_repo() {
    local action="${1:-list}"
    
    case "$action" in
        list)
            log_info "Repositórios configurados:"
            echo ""
            cat /etc/apt/sources.list
            echo ""
            if [ -d /etc/apt/sources.list.d ]; then
                log_info "Repositórios adicionais em /etc/apt/sources.list.d:"
                ls -la /etc/apt/sources.list.d/
            fi
            ;;
        add)
            if [ $# -lt 2 ]; then
                log_error "Uso: apm repo add <url-ou-ppa>"
                exit 1
            fi
            local repo="$2"
            if [[ "$repo" == ppa:* ]]; then
                log_info "Adicionando PPA: $repo"
                apt-get install -y software-properties-common
                add-apt-repository -y "$repo"
            else
                log_info "Adicionando repositório: $repo"
                echo "deb $repo" >> /etc/apt/sources.list
            fi
            apt-get update
            log_success "Repositório adicionado!"
            ;;
        *)
            log_error "Ação desconhecida: $action"
            echo "Ações válidas: list, add"
            exit 1
            ;;
    esac
}

# Mostrar ajuda
show_help() {
    cat << EOF
${CYAN}Aether Package Manager (APM) v${APM_VERSION}${NC}
Wrapper compatível com pacotes .deb do Debian/Ubuntu

${YELLOW}Uso:${NC} apm <comando> [opções]

${YELLOW}Comandos Principais:${NC}
  ${GREEN}install${NC} <pkg...>      Instalar pacote(s)
  ${GREEN}remove${NC} <pkg...>       Remover pacote(s)
  ${GREEN}purge${NC} <pkg...>        Remover pacote(s) com configurações
  ${GREEN}update${NC}                Atualizar lista de repositórios
  ${GREEN}upgrade${NC} [type]        Atualizar pacotes (standard|full|dist)
  ${GREEN}search${NC} <termo>        Buscar pacotes
  ${GREEN}info${NC} <pkg>            Informações do pacote
  ${GREEN}list${NC} [mode]           Listar pacotes (installed|available|upgradable)
  ${GREEN}clean${NC}                 Limpar cache
  ${GREEN}autoremove${NC}            Remover dependências órfãs

${YELLOW}Comandos Avançados:${NC}
  ${GREEN}download${NC} <pkg>        Baixar pacote sem instalar
  ${GREEN}source${NC} <pkg>          Baixar código fonte
  ${GREEN}build-dep${NC} <pkg>       Instalar dependências de build
  ${GREEN}policy${NC} [pkg]          Mostrar política de versões
  ${GREEN}depends${NC} <pkg>         Mostrar dependências
  ${GREEN}rdepends${NC} <pkg>        Mostrar dependências reversas
  ${GREEN}changelog${NC} <pkg>       Mostrar changelog
  ${GREEN}file${NC} <arquivo>        Buscar pacote que contém arquivo
  ${GREEN}stats${NC}                 Mostrar estatísticas
  ${GREEN}repo${NC} [list|add]       Gerenciar repositórios

${YELLOW}Exemplos:${NC}
  apm update
  apm install firefox kde-plasma vim
  apm remove libreoffice
  apm search browser
  apm info nginx
  apm list installed
  apm upgrade full
  apm repo add ppa:kisak/kubuntu-focal-backports

${YELLOW}Atalhos:${NC}
  apm i <pkg>        = apm install <pkg>
  apm r <pkg>        = apm remove <pkg>
  apm u              = apm update
  apm up             = apm upgrade
  apm s <termo>      = apm search <termo>
  apm l              = apm list
  apm c              = apm clean

EOF
}

# Main
main() {
    local cmd="${1:-help}"
    shift || true
    
    # Atalhos
    case "$cmd" in
        i)      cmd="install";;
        r)      cmd="remove";;
        u)      cmd="update";;
        up)     cmd="upgrade";;
        s)      cmd="search";;
        l)      cmd="list";;
        c)      cmd="clean";;
        h|--help|-h) cmd="help";;
    esac
    
    case "$cmd" in
        install)      cmd_install "$@";;
        remove)       cmd_remove "$@";;
        purge)        cmd_purge "$@";;
        update)       cmd_update;;
        upgrade)      cmd_upgrade "$@";;
        search)       cmd_search "$@";;
        info)         cmd_info "$@";;
        list)         cmd_list "$@";;
        clean)        cmd_clean;;
        autoremove)   cmd_autoremove;;
        download)     cmd_download "$@";;
        source)       cmd_source "$@";;
        build-dep)    cmd_build_dep "$@";;
        policy)       cmd_policy "$@";;
        depends)      cmd_depends "$@";;
        rdepends)     cmd_rdepends "$@";;
        changelog)    cmd_changelog "$@";;
        file)         cmd_file "$@";;
        stats)        cmd_stats;;
        repo)         cmd_repo "$@";;
        help|h|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando desconhecido: $cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Executar
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
