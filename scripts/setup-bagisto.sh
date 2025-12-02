#!/bin/bash

################################################################################
# Bagisto Automated Setup Script for Dokploy Environment
#
# This script automates the installation and configuration of Bagisto
# within a Docker container managed by Dokploy.
#
# Features:
# - Idempotent: Can be run multiple times safely
# - Error handling and validation
# - Clear logging for debugging
# - Database initialization
# - Environment configuration
#
# Usage:
#   bash /var/www/scripts/setup-bagisto.sh
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BAGISTO_VERSION="${BAGISTO_VERSION:-v2.3.6}"
WORK_DIR="/var/www/html"
ENV_FILE="${WORK_DIR}/.env"
VENDOR_DIR="${WORK_DIR}/vendor"
LOCK_FILE="${WORK_DIR}/.bagisto-setup-complete"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if setup has already been completed
check_if_installed() {
    if [ -f "$LOCK_FILE" ]; then
        log_warning "Bagisto ya está instalado (encontrado archivo de bloqueo)."
        log_info "Si deseas reinstalar, elimina el archivo: $LOCK_FILE"
        exit 0
    fi

    if [ -f "$ENV_FILE" ] && [ -d "$VENDOR_DIR" ]; then
        log_warning "Bagisto parece estar ya instalado (.env y vendor existen)."
        log_info "Si deseas continuar de todas formas, elimina .env o vendor."
        # Create lock file for future runs
        touch "$LOCK_FILE"
        exit 0
    fi
}

# Wait for MySQL to be ready
wait_for_mysql() {
    log_info "Esperando a que MySQL esté disponible..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if mysql -h"${DB_HOST:-mysql}" -u"${DB_USERNAME:-root}" -p"${DB_PASSWORD:-root}" -e "SELECT 1" >/dev/null 2>&1; then
            log_success "MySQL está listo"
            return 0
        fi

        log_info "Intento $attempt/$max_attempts - MySQL no disponible aún..."
        sleep 2
        ((attempt++))
    done

    log_error "MySQL no está disponible después de $max_attempts intentos"
    return 1
}

# Create database if it doesn't exist
create_database() {
    local db_name="${DB_DATABASE:-bagisto}"

    log_info "Verificando/creando base de datos: $db_name"

    if mysql -h"${DB_HOST:-mysql}" -u"${DB_USERNAME:-root}" -p"${DB_PASSWORD:-root}" \
        -e "CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null; then
        log_success "Base de datos '$db_name' verificada/creada"
    else
        log_error "No se pudo crear la base de datos '$db_name'"
        return 1
    fi

    # Create testing database if needed
    if [ "${CREATE_TEST_DB:-false}" = "true" ]; then
        log_info "Creando base de datos de pruebas..."
        mysql -h"${DB_HOST:-mysql}" -u"${DB_USERNAME:-root}" -p"${DB_PASSWORD:-root}" \
            -e "CREATE DATABASE IF NOT EXISTS \`${db_name}_testing\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
        log_success "Base de datos de pruebas creada"
    fi
}

# Clone or verify Bagisto source code
setup_bagisto_source() {
    cd "$WORK_DIR"

    # Check if we already have Bagisto files
    if [ -f "composer.json" ] && grep -q "bagisto/bagisto" composer.json 2>/dev/null; then
        log_info "Código fuente de Bagisto ya existe"
        return 0
    fi

    # Check if directory is empty or only has .gitignore
    if [ -n "$(ls -A . 2>/dev/null | grep -v '^\.gitignore$')" ]; then
        log_error "El directorio $WORK_DIR no está vacío y no contiene Bagisto"
        log_info "Contenido actual:"
        ls -la
        return 1
    fi

    log_info "Clonando Bagisto $BAGISTO_VERSION..."

    if git clone https://github.com/bagisto/bagisto.git .; then
        log_success "Bagisto clonado exitosamente"
    else
        log_error "Fallo al clonar Bagisto"
        return 1
    fi

    log_info "Cambiando a versión $BAGISTO_VERSION..."
    if git reset --hard "$BAGISTO_VERSION"; then
        log_success "Versión $BAGISTO_VERSION configurada"
    else
        log_error "Fallo al cambiar a versión $BAGISTO_VERSION"
        return 1
    fi
}

# Install Composer dependencies
install_dependencies() {
    cd "$WORK_DIR"

    if [ -d "$VENDOR_DIR" ] && [ -n "$(ls -A $VENDOR_DIR 2>/dev/null)" ]; then
        log_info "Dependencias de Composer ya instaladas"
        return 0
    fi

    log_info "Instalando dependencias de Composer..."

    if composer install --no-interaction --prefer-dist --optimize-autoloader; then
        log_success "Dependencias instaladas exitosamente"
    else
        log_error "Fallo al instalar dependencias de Composer"
        return 1
    fi
}

# Configure .env file
configure_environment() {
    cd "$WORK_DIR"

    if [ -f "$ENV_FILE" ]; then
        log_info "Archivo .env ya existe"
        return 0
    fi

    if [ ! -f ".env.example" ]; then
        log_error "No se encontró .env.example"
        return 1
    fi

    log_info "Creando archivo .env desde .env.example..."
    cp .env.example .env

    # Set database configuration
    log_info "Configurando variables de entorno..."

    sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST:-mysql}/" .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE:-bagisto}/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME:-root}/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD:-root}/" .env

    # Set APP_URL if provided
    if [ -n "${APP_URL}" ]; then
        sed -i "s#APP_URL=.*#APP_URL=${APP_URL}#" .env
    fi

    # Generate application key
    log_info "Generando APP_KEY..."
    if php artisan key:generate --force; then
        log_success "APP_KEY generada exitosamente"
    else
        log_error "Fallo al generar APP_KEY"
        return 1
    fi

    log_success "Archivo .env configurado"
}

# Run database migrations and installation
install_bagisto() {
    cd "$WORK_DIR"

    log_info "Verificando estado de la base de datos..."

    # Check if migrations have been run
    if php artisan migrate:status >/dev/null 2>&1; then
        log_info "Las migraciones ya fueron ejecutadas"
    else
        log_info "Ejecutando migraciones de base de datos..."
        if php artisan migrate --force; then
            log_success "Migraciones ejecutadas exitosamente"
        else
            log_error "Fallo al ejecutar migraciones"
            return 1
        fi
    fi

    log_info "Ejecutando instalador de Bagisto..."
    if php artisan bagisto:install --skip-env-check --skip-admin-creation; then
        log_success "Bagisto instalado exitosamente"
    else
        log_error "Fallo al ejecutar el instalador de Bagisto"
        return 1
    fi
}

# Seed sample data (optional)
seed_sample_data() {
    cd "$WORK_DIR"

    if [ "${SEED_SAMPLE_DATA:-false}" = "true" ]; then
        log_info "Cargando datos de ejemplo..."

        if php artisan db:seed --class="Webkul\Installer\Database\Seeders\ProductTableSeeder"; then
            log_success "Datos de ejemplo cargados"
        else
            log_warning "Fallo al cargar datos de ejemplo (no crítico)"
        fi
    else
        log_info "Omitiendo datos de ejemplo (SEED_SAMPLE_DATA no está habilitado)"
    fi
}

# Set proper permissions
set_permissions() {
    cd "$WORK_DIR"

    log_info "Configurando permisos de archivos..."

    # Directories that need to be writable
    local writable_dirs=(
        "storage"
        "bootstrap/cache"
        "public/storage"
        "public/themes"
        "public/vendor"
    )

    for dir in "${writable_dirs[@]}"; do
        if [ -d "$dir" ]; then
            chmod -R 775 "$dir" 2>/dev/null || true
        fi
    done

    log_success "Permisos configurados"
}

# Create storage link
create_storage_link() {
    cd "$WORK_DIR"

    if [ ! -L "public/storage" ]; then
        log_info "Creando enlace simbólico de storage..."
        if php artisan storage:link; then
            log_success "Enlace de storage creado"
        else
            log_warning "No se pudo crear el enlace de storage (puede no ser necesario)"
        fi
    else
        log_info "Enlace de storage ya existe"
    fi
}

# Create lock file to prevent re-installation
create_lock_file() {
    log_info "Creando archivo de bloqueo de instalación..."
    cat > "$LOCK_FILE" <<EOF
Bagisto setup completed successfully
Date: $(date)
Version: $BAGISTO_VERSION
EOF
    log_success "Archivo de bloqueo creado en: $LOCK_FILE"
}

# Show completion summary
show_summary() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    log_success "Instalación de Bagisto completada exitosamente!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    log_info "Detalles de la instalación:"
    echo "  • Versión: $BAGISTO_VERSION"
    echo "  • Directorio: $WORK_DIR"
    echo "  • Base de datos: ${DB_DATABASE:-bagisto}"
    echo "  • URL: ${APP_URL:-http://localhost}"
    echo ""
    log_info "Credenciales de administrador por defecto:"
    echo "  • Email: admin@example.com"
    echo "  • Password: admin123"
    echo ""
    log_warning "IMPORTANTE: Cambia las credenciales de administrador después del primer login"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}

################################################################################
# Main Execution Flow
################################################################################

main() {
    log_info "Iniciando instalación automatizada de Bagisto..."
    log_info "Versión objetivo: $BAGISTO_VERSION"
    echo ""

    # Step 1: Check if already installed
    check_if_installed

    # Step 2: Wait for MySQL
    wait_for_mysql || exit 1

    # Step 3: Create database
    create_database || exit 1

    # Step 4: Setup Bagisto source code
    setup_bagisto_source || exit 1

    # Step 5: Install dependencies
    install_dependencies || exit 1

    # Step 6: Configure environment
    configure_environment || exit 1

    # Step 7: Install Bagisto
    install_bagisto || exit 1

    # Step 8: Seed sample data (optional)
    seed_sample_data

    # Step 9: Set permissions
    set_permissions

    # Step 10: Create storage link
    create_storage_link

    # Step 11: Create lock file
    create_lock_file

    # Show summary
    show_summary
}

# Run main function
main "$@"
