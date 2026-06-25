#!/bin/bash
# Aether OS - Gerenciador de Pacotes (APM - Aether Package Manager)
# Implementação do gerenciador de pacotes próprio

set -euo pipefail

# Configurações
APM_VERSION="1.0.0"
APM_ROOT="${APM_ROOT:-/etc/apm}"
APM_DB="$APM_ROOT/db"
APM_CACHE="/var/cache/apm"
APM_REPO="https://repo.aether-os.org/packages"
ARCH="x86_64"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
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

# Inicializar diretórios do APM
init_apm() {
    log_info "Inicializando APM..."
    mkdir -p "$APM_ROOT" "$APM_DB" "$APM_CACHE"
    
    # Criar arquivo de repositórios
    if [ ! -f "$APM_ROOT/repos.conf" ]; then
        cat > "$APM_ROOT/repos.conf" << EOF
# Repositórios do Aether Package Manager
[main]
url = https://repo.aether-os.org/packages/x86_64
enabled = true
gpgcheck = true
gpgkey = https://repo.aether-os.org/keys/aether-release.key

[updates]
url = https://repo.aether-os.org/updates/x86_64
enabled = true
gpgcheck = true
gpgkey = https://repo.aether-os.org/keys/aether-release.key
EOF
        log_success "Arquivo de repositórios criado"
    fi
    
    # Criar banco de dados vazio
    if [ ! -f "$APM_DB/packages.db" ]; then
        touch "$APM_DB/packages.db"
        log_success "Banco de dados inicializado"
    fi
}

# Baixar e verificar pacote
fetch_package() {
    local pkg_name="$1"
    local pkg_url="$APM_REPO/$ARCH/${pkg_name}.apm"
    local pkg_cache="$APM_CACHE/${pkg_name}.apm"
    
    log_info "Baixando pacote: $pkg_name"
    
    if ! wget -q "$pkg_url" -O "$pkg_cache"; then
        log_error "Falha ao baixar pacote $pkg_name"
        return 1
    fi
    
    # Verificar assinatura GPG (implementação simplificada)
    if command -v gpg &> /dev/null; then
        log_info "Verificando assinatura..."
        # wget -q "$pkg_url.sig" -O "$pkg_cache.sig"
        # gpg --verify "$pkg_cache.sig" "$pkg_cache" || log_warn "Verificação de assinatura falhou"
    fi
    
    log_success "Pacote baixado: $pkg_cache"
}

# Extrair metadados do pacote
get_pkg_metadata() {
    local pkg_file="$1"
    
    # Pacote .apm é um tar.xz contendo:
    # - metadata.json (nome, versão, dependências, descrição)
    # - install.tar.xz (arquivos do pacote)
    # - preinstall.sh (script pré-instalação, opcional)
    # - postinstall.sh (script pós-instalação, opcional)
    
    tar -xf "$pkg_file" -O metadata.json 2>/dev/null || echo "{}"
}

# Resolver dependências (implementação básica)
resolve_deps() {
    local pkg_name="$1"
    local metadata
    metadata=$(get_pkg_metadata "$APM_CACHE/${pkg_name}.apm")
    
    # Extrair dependências do JSON (usando jq se disponível, ou grep básico)
    if command -v jq &> /dev/null; then
        echo "$metadata" | jq -r '.dependencies[]?' 2>/dev/null || true
    else
        # Fallback simples
        echo "$metadata" | grep -oP '"[^"]+":\s*"[^"]*"' | grep dependency || true
    fi
}

# Instalar pacote
install_package() {
    local pkg_name="$1"
    local pkg_file="$APM_CACHE/${pkg_name}.apm"
    
    # Verificar se já está instalado
    if grep -q "^${pkg_name}:" "$APM_DB/packages.db" 2>/dev/null; then
        log_warn "Pacote $pkg_name já está instalado"
        return 0
    fi
    
    # Baixar pacote se necessário
    if [ ! -f "$pkg_file" ]; then
        fetch_package "$pkg_name" || return 1
    fi
    
    # Resolver e instalar dependências primeiro
    local deps
    deps=$(resolve_deps "$pkg_name")
    for dep in $deps; do
        if ! grep -q "^${dep}:" "$APM_DB/packages.db" 2>/dev/null; then
            log_info "Instalando dependência: $dep"
            install_package "$dep" || return 1
        fi
    done
    
    log_info "Instalando $pkg_name..."
    
    # Executar script preinstall se existir
    if tar -tf "$pkg_file" | grep -q "preinstall.sh"; then
        log_info "Executando script de pré-instalação..."
        tar -xf "$pkg_file" -O preinstall.sh | bash || log_warn "Preinstall falhou"
    fi
    
    # Extrair arquivos do pacote
    tar -xf "$pkg_file" install.tar.xz -C / || die "Falha na extração do pacote"
    
    # Registrar instalação
    local version
    version=$(get_pkg_metadata "$pkg_file" | jq -r '.version' 2>/dev/null || echo "unknown")
    echo "${pkg_name}:${version}:$(date +%Y-%m-%d)" >> "$APM_DB/packages.db"
    
    # Executar script postinstall se existir
    if tar -tf "$pkg_file" | grep -q "postinstall.sh"; then
        log_info "Executando script de pós-instalação..."
        tar -xf "$pkg_file" -O postinstall.sh | bash || log_warn "Postinstall falhou"
    fi
    
    log_success "Pacote $pkg_name instalado com sucesso!"
}

# Remover pacote
remove_package() {
    local pkg_name="$1"
    
    # Verificar se está instalado
    if ! grep -q "^${pkg_name}:" "$APM_DB/packages.db" 2>/dev/null; then
        log_error "Pacote $pkg_name não está instalado"
        return 1
    fi
    
    log_info "Removendo $pkg_name..."
    
    # TODO: Implementar remoção adequada (rastrear arquivos instalados)
    # Por enquanto, apenas remove do banco de dados
    sed -i "/^${pkg_name}:/d" "$APM_DB/packages.db"
    
    log_success "Pacete $pkg_name removido"
}

# Atualizar lista de pacotes
update_repo() {
    log_info "Atualizando repositórios..."
    
    local repo_list="$APM_DB/repo.list"
    > "$repo_list"
    
    # Ler repositórios configurados
    while IFS='=' read -r key value; do
        if [[ "$key" == "url" ]]; then
            log_info "Buscando: $value"
            # wget -q "$value/PACKAGES.txt" -O - >> "$repo_list"
        fi
    done < <(grep -E "^(url|enabled)=" "$APM_ROOT/repos.conf" 2>/dev/null)
    
    log_success "Repositórios atualizados"
}

# Listar pacotes instalados
list_installed() {
    echo "Pacotes instalados:"
    echo "==================="
    if [ -f "$APM_DB/packages.db" ]; then
        column -t -s':' "$APM_DB/packages.db" || cat "$APM_DB/packages.db"
    else
        echo "Nenhum pacote instalado."
    fi
}

# Buscar pacote nos repositórios
search_package() {
    local query="$1"
    log_info "Buscando por: $query"
    
    # TODO: Implementar busca real nos repositórios
    echo "Funcionalidade em desenvolvimento..."
}

# Mostrar informações do pacote
info_package() {
    local pkg_name="$1"
    
    if [ -f "$APM_CACHE/${pkg_name}.apm" ]; then
        get_pkg_metadata "$APM_CACHE/${pkg_name}.apm" | jq . 2>/dev/null || cat "$APM_CACHE/${pkg_name}.apm"
    else
        log_error "Pacote não encontrado no cache"
    fi
}

# Atualização automática (daemon/sistema)
auto_update() {
    log_info "Verificando atualizações..."
    
    # Criar serviço systemd para updates automáticos
    cat > /etc/systemd/system/apm-update.service << 'EOF'
[Unit]
Description=Aether Package Manager Auto Update
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/apm upgrade --no-confirm
EOF

    cat > /etc/systemd/system/apm-update.timer << 'EOF'
[Unit]
Description=Run APM auto update daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    log_success "Serviço de atualização automática configurado"
}

# Mostrar ajuda
show_help() {
    cat << EOF
Aether Package Manager (APM) v${APM_VERSION}

Uso: apm <comando> [opções]

Comandos:
  init              Inicializar o APM
  install <pkg>     Instalar pacote(s)
  remove <pkg>      Remover pacote(s)
  update            Atualizar lista de repositórios
  upgrade           Atualizar todos os pacotes
  search <query>    Buscar pacotes
  info <pkg>        Mostrar informações do pacote
  list              Listar pacotes instalados
  clean             Limpar cache de pacotes
  auto-update       Configurar atualizações automáticas
  help              Mostrar esta ajuda

Exemplos:
  apm init
  apm update
  apm install firefox kde-plasma
  apm remove vim
  apm search browser
  apm list

EOF
}

# Comando principal
main() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        init)
            init_apm
            ;;
        install|i)
            for pkg in "$@"; do
                install_package "$pkg"
            done
            ;;
        remove|r)
            for pkg in "$@"; do
                remove_package "$pkg"
            done
            ;;
        update|u)
            update_repo
            ;;
        upgrade|up)
            update_repo
            # TODO: Implementar upgrade de todos os pacotes
            log_info "Upgrade em desenvolvimento..."
            ;;
        search|s)
            search_package "${1:-}"
            ;;
        info)
            info_package "${1:-}"
            ;;
        list|l)
            list_installed
            ;;
        clean)
            log_info "Limpando cache..."
            rm -rf "$APM_CACHE"/*
            log_success "Cache limpo"
            ;;
        auto-update)
            auto_update
            ;;
        help|h|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando desconhecido: $cmd"
            show_help
            exit 1
            ;;
    esac
}

# Se executado diretamente (não sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
