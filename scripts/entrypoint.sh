#!/bin/bash

################################################################################
# Docker Entrypoint for Bagisto PHP-FPM Container
#
# This script serves as the entrypoint for the php-fpm container.
# It handles:
# - Automatic setup on first run
# - Manual setup trigger via environment variable
# - Graceful startup of php-fpm
#
# Environment Variables:
#   AUTO_SETUP=true       - Run setup automatically on first boot
#   FORCE_SETUP=true      - Force setup even if already installed
#   SKIP_SETUP=true       - Skip setup completely
################################################################################

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[ENTRYPOINT]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ENTRYPOINT]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ENTRYPOINT]${NC} $1"
}

SETUP_SCRIPT="/var/www/scripts/setup-bagisto.sh"
LOCK_FILE="/var/www/html/.bagisto-setup-complete"

# Handle setup logic
handle_setup() {
    # Skip setup if explicitly disabled
    if [ "${SKIP_SETUP}" = "true" ]; then
        log_info "Setup omitido (SKIP_SETUP=true)"
        return 0
    fi

    # Force setup if requested
    if [ "${FORCE_SETUP}" = "true" ]; then
        log_warning "Forzando setup (FORCE_SETUP=true)..."
        if [ -f "$LOCK_FILE" ]; then
            rm -f "$LOCK_FILE"
            log_info "Archivo de bloqueo eliminado"
        fi
    fi

    # Run setup automatically if enabled and not already done
    if [ "${AUTO_SETUP}" = "true" ] || [ "${FORCE_SETUP}" = "true" ]; then
        if [ ! -f "$LOCK_FILE" ]; then
            log_info "Ejecutando setup automático de Bagisto..."

            if [ -f "$SETUP_SCRIPT" ]; then
                bash "$SETUP_SCRIPT"
            else
                log_warning "Script de setup no encontrado: $SETUP_SCRIPT"
                log_info "Para instalar manualmente, ejecuta:"
                log_info "  docker exec -it <container> bash /var/www/scripts/setup-bagisto.sh"
            fi
        else
            log_info "Bagisto ya está instalado (omitiendo setup)"
        fi
    else
        log_info "Setup automático deshabilitado"
        if [ ! -f "$LOCK_FILE" ]; then
            log_warning "Bagisto no parece estar instalado"
            log_info "Para instalar, ejecuta:"
            log_info "  docker exec -it <container> bash /var/www/scripts/setup-bagisto.sh"
            log_info "O activa AUTO_SETUP=true en las variables de entorno"
        fi
    fi
}

# Main entrypoint logic
main() {
    log_info "Iniciando contenedor Bagisto PHP-FPM..."

    # Run setup if needed
    handle_setup

    # Execute any additional commands passed to entrypoint
    if [ $# -gt 0 ]; then
        log_info "Ejecutando comando: $*"
        exec "$@"
    else
        # Start php-fpm by default
        log_success "Iniciando PHP-FPM..."
        exec php-fpm
    fi
}

# Run main function with all arguments
main "$@"
