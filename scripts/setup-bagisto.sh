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
APP_USER="${APP_USER:-bagisto}"

# Helper function to run commands as the app user
run_as_user() {
    if [ "$(whoami)" = "root" ]; then
        su - "$APP_USER" -c "cd $WORK_DIR && $*"
    else
        bash -c "cd $WORK_DIR && $*"
    fi
}

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

    # Debug: Print environment variables
    log_info "Configuración de conexión:"
    log_info "  - DB_HOST: ${DB_HOST:-mysql}"
    log_info "  - DB_PORT: ${DB_PORT:-3306}"
    log_info "  - DB_USERNAME: ${DB_USERNAME:-root}"
    log_info "  - DB_DATABASE: ${DB_DATABASE:-bagisto}"

    local max_attempts=60
    local attempt=1
    local sleep_time=3

    while [ $attempt -le $max_attempts ]; do
        # Try to connect to MySQL using PHP PDO
        if php -r "
            try {
                \$dsn = 'mysql:host=${DB_HOST:-mysql};port=${DB_PORT:-3306}';
                \$pdo = new PDO(\$dsn, '${DB_USERNAME:-root}', '${DB_PASSWORD:-root}');
                exit(0);
            } catch (PDOException \$e) {
                exit(1);
            }
        " 2>/dev/null; then
            log_success "MySQL está listo y aceptando conexiones"
            return 0
        fi

        # Show progress every 5 attempts
        if [ $((attempt % 5)) -eq 0 ]; then
            log_info "Intento $attempt/$max_attempts - MySQL aún no disponible..."
        fi

        sleep $sleep_time
        ((attempt++))
    done

    log_error "MySQL no está disponible después de $max_attempts intentos (${max_attempts}x${sleep_time}s = $((max_attempts * sleep_time))s total)"
    log_error ""
    log_error "Pasos para diagnosticar:"
    log_error "1. Verifica que el servicio 'mysql' esté corriendo en Dokploy"
    log_error "2. Revisa los logs del contenedor MySQL en Dokploy"
    log_error "3. Verifica que DB_HOST=${DB_HOST:-mysql} sea correcto"
    log_error "4. Verifica las credenciales en las variables de entorno:"
    log_error "   - DB_USERNAME=${DB_USERNAME:-root}"
    log_error "   - DB_PASSWORD está configurado correctamente"
    log_error "5. Verifica que ambos contenedores estén en la misma red Docker"

    return 1
}

# Create database if it doesn't exist
create_database() {
    local db_name="${DB_DATABASE:-bagisto}"

    log_info "Verificando/creando base de datos: $db_name"

    # Use PHP to create database
    if php -r "
        try {
            \$dsn = 'mysql:host=${DB_HOST:-mysql};port=${DB_PORT:-3306}';
            \$pdo = new PDO(\$dsn, '${DB_USERNAME:-root}', '${DB_PASSWORD:-root}');
            \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            exit(0);
        } catch (PDOException \$e) {
            file_put_contents('php://stderr', 'Error: ' . \$e->getMessage() . PHP_EOL);
            exit(1);
        }
    " 2>/dev/null; then
        log_success "Base de datos '$db_name' verificada/creada"
    else
        log_error "No se pudo crear la base de datos '$db_name'"
        log_error "Verifica los permisos del usuario ${DB_USERNAME:-root}"
        return 1
    fi

    # Create testing database if needed
    if [ "${CREATE_TEST_DB:-false}" = "true" ]; then
        log_info "Creando base de datos de pruebas..."
        php -r "
            try {
                \$dsn = 'mysql:host=${DB_HOST:-mysql};port=${DB_PORT:-3306}';
                \$pdo = new PDO(\$dsn, '${DB_USERNAME:-root}', '${DB_PASSWORD:-root}');
                \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`${db_name}_testing\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            } catch (PDOException \$e) {
                // Ignore errors for test database
            }
        " 2>/dev/null
        log_success "Base de datos de pruebas creada"
    fi
}

# Clone or verify Bagisto source code
setup_bagisto_source() {
    cd "$WORK_DIR"

    # Check if we already have Bagisto files
    if [ -f "composer.json" ] && grep -q "bagisto/bagisto" composer.json 2>/dev/null; then
        log_info "Código fuente de Bagisto ya existe"

        # Verify we're on the correct version
        if [ -d ".git" ]; then
            # Configure git safe.directory
            run_as_user "git config --global --add safe.directory /var/www/html" 2>/dev/null || true

            local current_version=$(run_as_user "git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD")
            log_info "Versión actual: $current_version"

            # If version doesn't match, update it
            if [ "$current_version" != "$BAGISTO_VERSION" ]; then
                log_info "Actualizando a versión $BAGISTO_VERSION..."
                run_as_user "git fetch --tags" 2>/dev/null || true
                if run_as_user "git reset --hard $BAGISTO_VERSION" 2>/dev/null; then
                    log_success "Versión actualizada a $BAGISTO_VERSION"
                else
                    log_warning "No se pudo actualizar la versión (continuando con versión actual)"
                fi
            fi
        fi

        return 0
    fi

    # Check if directory is empty or only has safe files to ignore
    local file_count=$(ls -A . 2>/dev/null | grep -v -E '^(\.gitignore|\.bagisto-setup-complete)$' | wc -l)

    if [ "$file_count" -gt 0 ]; then
        log_warning "El directorio $WORK_DIR no está vacío"

        # If FORCE_CLEAN is enabled, clean the directory
        if [ "${FORCE_CLEAN:-false}" = "true" ]; then
            log_warning "FORCE_CLEAN=true: Eliminando contenido del directorio..."

            # Remove all files and hidden files (except . and ..)
            find . -mindepth 1 -maxdepth 1 ! -name '.' ! -name '..' -exec rm -rf {} + 2>/dev/null || true

            log_success "Directorio limpiado"
        else
            log_info "Contenido actual:"
            ls -la

            # Check if it's just temporary files or lock files
            local critical_files=$(ls -A . 2>/dev/null | grep -v -E '^(\.|lost\+found)' | wc -l)

            if [ "$critical_files" -gt 0 ]; then
                log_error "El directorio contiene archivos que podrían ser importantes"
                log_error "Por seguridad, no se eliminará el contenido automáticamente"
                log_error ""
                log_error "Opciones:"
                log_error "1. Agrega la variable de entorno: FORCE_CLEAN=true"
                log_error "2. O ejecuta manualmente en el contenedor:"
                log_error "   rm -rf /var/www/html/*"
                log_error "   rm -rf /var/www/html/.[!.]*"
                return 1
            fi

            log_info "Solo hay archivos ocultos, procediendo con la clonación..."
        fi
    fi

    log_info "Clonando Bagisto $BAGISTO_VERSION..."
    log_info "Directorio de trabajo: $(pwd)"

    # Show what's in the directory before cloning
    log_info "Contenido actual del directorio:"
    ls -la 2>/dev/null || echo "No se puede listar el directorio"

    # Try to clone Bagisto
    if ! git clone https://github.com/bagisto/bagisto.git . 2>&1; then
        log_error "Fallo al clonar Bagisto en el primer intento"

        # If FORCE_CLEAN is true or we detect the specific git error, clean and retry
        if [ "${FORCE_CLEAN:-false}" = "true" ]; then
            log_warning "Limpiando directorio y reintentando..."
            log_info "Usuario actual: $(whoami)"

            # More aggressive cleanup - remove everything including .gitignore
            log_info "Eliminando todo el contenido del directorio..."

            # Remove .git directory if it exists
            rm -rf .git 2>/dev/null || true

            # Remove .gitignore specifically
            rm -f .gitignore 2>/dev/null || true

            # Remove all files and directories (visible and hidden)
            rm -rf ..?* .[!.]* * 2>/dev/null || true

            # Final cleanup with find (belt and suspenders)
            find . -mindepth 1 -delete 2>/dev/null || true

            # Verify directory is empty
            log_info "Contenido después de limpiar:"
            ls -la 2>/dev/null || echo "Directorio vacío"

            local remaining_files=$(ls -A 2>/dev/null | wc -l)
            if [ "$remaining_files" -gt 0 ]; then
                log_warning "Aún quedan $remaining_files archivos en el directorio"
            fi

            log_info "Reintentando clonación después de limpiar..."

            # Fix ownership before cloning as user
            chown -R "$APP_USER:www-data" . 2>/dev/null || true

            if run_as_user "git clone https://github.com/bagisto/bagisto.git ."; then
                log_success "Bagisto clonado exitosamente después de limpiar"
            else
                log_error "Fallo al clonar Bagisto incluso después de limpiar"
                log_error "Posibles causas:"
                log_error "1. Permisos insuficientes del usuario $(whoami)"
                log_error "2. Volumen montado con permisos incorrectos"
                log_error "3. Archivos bloqueados por otro proceso"
                return 1
            fi
        else
            log_error "El directorio no está vacío. Configura FORCE_CLEAN=true para limpiarlo automáticamente"
            return 1
        fi
    else
        log_success "Bagisto clonado exitosamente"
    fi

    log_info "Cambiando a versión $BAGISTO_VERSION..."

    # Configure git safe.directory to avoid ownership issues
    run_as_user "git config --global --add safe.directory /var/www/html" 2>/dev/null || true

    if run_as_user "git reset --hard $BAGISTO_VERSION"; then
        log_success "Versión $BAGISTO_VERSION configurada"
    else
        log_error "Fallo al cambiar a versión $BAGISTO_VERSION"
        return 1
    fi
}

# Prepare Laravel directories with correct permissions
prepare_laravel_directories() {
    cd "$WORK_DIR"

    log_info "Preparando directorios de Laravel..."

    # Create directories if they don't exist
    mkdir -p storage/logs storage/framework/{sessions,views,cache} bootstrap/cache 2>/dev/null || true

    # Set ownership to app user
    chown -R "$APP_USER:www-data" storage bootstrap/cache 2>/dev/null || true

    # Set permissions
    chmod -R 775 storage bootstrap/cache 2>/dev/null || true

    log_success "Directorios de Laravel preparados"
}

# Install Composer dependencies
install_dependencies() {
    cd "$WORK_DIR"

    if [ -d "$VENDOR_DIR" ] && [ -n "$(ls -A $VENDOR_DIR 2>/dev/null)" ]; then
        log_info "Dependencias de Composer ya instaladas"
        return 0
    fi

    # Ensure Laravel directories exist before composer install
    prepare_laravel_directories

    log_info "Instalando dependencias de Composer..."

    if run_as_user "composer install --no-interaction --prefer-dist --optimize-autoloader"; then
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

    # Fix ownership of .env file so user can modify it
    chown "$APP_USER:www-data" .env 2>/dev/null || true
    chmod 664 .env 2>/dev/null || true

    # Set all environment variables from Dokploy/docker-compose
    log_info "Configurando variables de entorno desde variables de entorno del contenedor..."

    # Database configuration
    [ -n "${DB_HOST}" ] && sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST}/" .env
    [ -n "${DB_PORT}" ] && sed -i "s/DB_PORT=.*/DB_PORT=${DB_PORT}/" .env
    [ -n "${DB_DATABASE}" ] && sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" .env
    [ -n "${DB_USERNAME}" ] && sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" .env
    [ -n "${DB_PASSWORD}" ] && sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env

    # Application configuration
    [ -n "${APP_URL}" ] && sed -i "s#APP_URL=.*#APP_URL=${APP_URL}#" .env
    [ -n "${APP_ENV}" ] && sed -i "s/APP_ENV=.*/APP_ENV=${APP_ENV}/" .env
    [ -n "${APP_DEBUG}" ] && sed -i "s/APP_DEBUG=.*/APP_DEBUG=${APP_DEBUG}/" .env
    [ -n "${APP_TIMEZONE}" ] && sed -i "s#APP_TIMEZONE=.*#APP_TIMEZONE=${APP_TIMEZONE}#" .env
    [ -n "${APP_LOCALE}" ] && sed -i "s/APP_LOCALE=.*/APP_LOCALE=${APP_LOCALE}/" .env
    [ -n "${APP_FALLBACK_LOCALE}" ] && sed -i "s/APP_FALLBACK_LOCALE=.*/APP_FALLBACK_LOCALE=${APP_FALLBACK_LOCALE}/" .env
    [ -n "${APP_CURRENCY}" ] && sed -i "s/APP_CURRENCY=.*/APP_CURRENCY=${APP_CURRENCY}/" .env

    # Redis configuration
    [ -n "${REDIS_HOST}" ] && sed -i "s/REDIS_HOST=.*/REDIS_HOST=${REDIS_HOST}/" .env
    [ -n "${REDIS_PORT}" ] && sed -i "s/REDIS_PORT=.*/REDIS_PORT=${REDIS_PORT}/" .env
    [ -n "${REDIS_PASSWORD}" ] && sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD}/" .env
    [ -n "${CACHE_STORE}" ] && sed -i "s/CACHE_STORE=.*/CACHE_STORE=${CACHE_STORE}/" .env
    [ -n "${SESSION_DRIVER}" ] && sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=${SESSION_DRIVER}/" .env
    [ -n "${QUEUE_CONNECTION}" ] && sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=${QUEUE_CONNECTION}/" .env

    # Mail configuration
    [ -n "${MAIL_MAILER}" ] && sed -i "s/MAIL_MAILER=.*/MAIL_MAILER=${MAIL_MAILER}/" .env
    [ -n "${MAIL_HOST}" ] && sed -i "s/MAIL_HOST=.*/MAIL_HOST=${MAIL_HOST}/" .env
    [ -n "${MAIL_PORT}" ] && sed -i "s/MAIL_PORT=.*/MAIL_PORT=${MAIL_PORT}/" .env
    [ -n "${MAIL_USERNAME}" ] && sed -i "s/MAIL_USERNAME=.*/MAIL_USERNAME=${MAIL_USERNAME}/" .env
    [ -n "${MAIL_PASSWORD}" ] && sed -i "s/MAIL_PASSWORD=.*/MAIL_PASSWORD=${MAIL_PASSWORD}/" .env
    [ -n "${MAIL_ENCRYPTION}" ] && sed -i "s/MAIL_ENCRYPTION=.*/MAIL_ENCRYPTION=${MAIL_ENCRYPTION}/" .env
    [ -n "${MAIL_FROM_ADDRESS}" ] && sed -i "s/MAIL_FROM_ADDRESS=.*/MAIL_FROM_ADDRESS=${MAIL_FROM_ADDRESS}/" .env
    # MAIL_FROM_NAME needs quotes if it contains spaces
    if [ -n "${MAIL_FROM_NAME}" ]; then
        # Escape any existing quotes and wrap in quotes
        local mail_name=$(echo "${MAIL_FROM_NAME}" | sed 's/"/\\"/g')
        sed -i "s/MAIL_FROM_NAME=.*/MAIL_FROM_NAME=\"${mail_name}\"/" .env
    fi

    # Admin configuration
    [ -n "${ADMIN_MAIL_ADDRESS}" ] && sed -i "s/ADMIN_MAIL_ADDRESS=.*/ADMIN_MAIL_ADDRESS=${ADMIN_MAIL_ADDRESS}/" .env
    # ADMIN_MAIL_NAME needs quotes if it contains spaces
    if [ -n "${ADMIN_MAIL_NAME}" ]; then
        local admin_name=$(echo "${ADMIN_MAIL_NAME}" | sed 's/"/\\"/g')
        sed -i "s/ADMIN_MAIL_NAME=.*/ADMIN_MAIL_NAME=\"${admin_name}\"/" .env
    fi

    # Elasticsearch configuration
    [ -n "${ELASTICSEARCH_HOST}" ] && sed -i "s/ELASTICSEARCH_HOST=.*/ELASTICSEARCH_HOST=${ELASTICSEARCH_HOST}/" .env
    [ -n "${ELASTICSEARCH_PORT}" ] && sed -i "s/ELASTICSEARCH_PORT=.*/ELASTICSEARCH_PORT=${ELASTICSEARCH_PORT}/" .env

    # Logging
    [ -n "${LOG_CHANNEL}" ] && sed -i "s/LOG_CHANNEL=.*/LOG_CHANNEL=${LOG_CHANNEL}/" .env
    [ -n "${LOG_LEVEL}" ] && sed -i "s/LOG_LEVEL=.*/LOG_LEVEL=${LOG_LEVEL}/" .env

    # Session
    [ -n "${SESSION_LIFETIME}" ] && sed -i "s/SESSION_LIFETIME=.*/SESSION_LIFETIME=${SESSION_LIFETIME}/" .env
    [ -n "${SESSION_ENCRYPT}" ] && sed -i "s/SESSION_ENCRYPT=.*/SESSION_ENCRYPT=${SESSION_ENCRYPT}/" .env

    # Broadcasting
    [ -n "${BROADCAST_CONNECTION}" ] && sed -i "s/BROADCAST_CONNECTION=.*/BROADCAST_CONNECTION=${BROADCAST_CONNECTION}/" .env

    # Filesystem
    [ -n "${FILESYSTEM_DISK}" ] && sed -i "s/FILESYSTEM_DISK=.*/FILESYSTEM_DISK=${FILESYSTEM_DISK}/" .env

    log_success "Variables de entorno configuradas desde el contenedor"

    # Ensure Laravel directories exist with correct permissions before running artisan commands
    prepare_laravel_directories

    # Generate application key
    log_info "Generando APP_KEY..."
    if run_as_user "php artisan key:generate --force"; then
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

    # Test database write capability before migrations
    log_info "Probando capacidad de escritura en MySQL..."
    if ! php -r "
        try {
            \$dsn = 'mysql:host=${DB_HOST:-mysql};port=${DB_PORT:-3306};dbname=${DB_DATABASE:-bagisto}';
            \$pdo = new PDO(\$dsn, '${DB_USERNAME:-root}', '${DB_PASSWORD:-root}');
            \$pdo->exec('CREATE TABLE IF NOT EXISTS __test_write_capability (id INT)');
            \$pdo->exec('DROP TABLE __test_write_capability');
            exit(0);
        } catch (PDOException \$e) {
            file_put_contents('php://stderr', 'Error de MySQL: ' . \$e->getMessage() . PHP_EOL);
            exit(1);
        }
    " 2>&1; then
        log_error "MySQL no puede crear tablas"
        log_error ""
        log_error "Posibles causas:"
        log_error "1. Espacio en disco lleno en el servidor"
        log_error "2. Permisos incorrectos en el volumen de MySQL"
        log_error "3. Corrupción del tablespace de InnoDB"
        log_error ""
        log_error "Verifica en Dokploy:"
        log_error "- Espacio disponible en disco"
        log_error "- Permisos del directorio ./.configs/data/mysql-data"
        log_error "- Logs del contenedor MySQL para más detalles"
        return 1
    fi
    log_success "MySQL puede escribir correctamente"

    # Check if migrations have been run
    if run_as_user "php artisan migrate:status" >/dev/null 2>&1; then
        log_info "Las migraciones ya fueron ejecutadas"
    else
        log_info "Ejecutando migraciones de base de datos..."
        if run_as_user "php artisan migrate --force"; then
            log_success "Migraciones ejecutadas exitosamente"
        else
            log_error "Fallo al ejecutar migraciones"
            return 1
        fi
    fi

    log_info "Ejecutando instalador de Bagisto..."
    if run_as_user "php artisan bagisto:install --skip-env-check --skip-admin-creation"; then
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

        if run_as_user "php artisan db:seed --class='Webkul\Installer\Database\Seeders\ProductTableSeeder'"; then
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
        if run_as_user "php artisan storage:link"; then
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
