# 🚀 Guía de Despliegue en Dokploy

Esta guía explica cómo desplegar Bagisto en **Dokploy** con configuración automatizada y sin intervención manual.

## 📋 Requisitos Previos

- Servidor con Dokploy instalado y configurado
- Dominio apuntando a tu servidor (opcional, pero recomendado)
- Acceso al repositorio Git

## 🎯 Características de la Automatización

El sistema automático incluye:

- ✅ **Inicialización automática** - No se requiere `setup.sh` manual
- ✅ **Idempotente** - Se puede ejecutar múltiples veces sin problemas
- ✅ **Validación de dependencias** - Espera a que MySQL esté listo
- ✅ **Configuración automática** - Genera `.env` con variables correctas
- ✅ **Instalación completa** - Ejecuta migraciones y seeders
- ✅ **Logs detallados** - Fácil diagnóstico de problemas

## 📝 Pasos de Despliegue

### 1. Crear Nuevo Proyecto en Dokploy

1. Ingresa a tu panel de Dokploy
2. Crea un nuevo proyecto: **"Bagisto Production"**
3. Selecciona tipo: **Docker Compose**

### 2. Conectar Repositorio

1. En la configuración del proyecto, selecciona:
   - **Source:** Git
   - **Repository URL:** `https://github.com/[tu-usuario]/bagisto-cfv`
   - **Branch:** `main`

2. Configura el archivo Docker Compose:
   - **Path:** `docker-compose.yml` (en la raíz del proyecto)

### 3. Configurar Variables de Entorno

En Dokploy, ve a la sección **Environment** y agrega estas variables.

> **Importante:** Puedes copiar todas las variables del archivo `.env.dokploy.example` como referencia.

#### Variables Obligatorias

```env
# URL de tu aplicación (cambia con tu dominio)
APP_URL=https://tienda.cfv.technology

# Entorno de aplicación
APP_ENV=production
APP_DEBUG=false

# Configuración de base de datos
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=bagisto
DB_USERNAME=root

# IMPORTANTE: Genera una contraseña segura (ejemplo: openssl rand -base64 32)
DB_PASSWORD=TU_CONTRASEÑA_SEGURA_AQUI

# Habilitar setup automático
AUTO_SETUP=true
```

> **Seguridad:** Las variables de entorno en Dokploy NO se guardan en el repositorio. Tus credenciales están seguras.

#### Variables Opcionales

```env
# Versión de Bagisto a instalar
BAGISTO_VERSION=v2.3.6

# Cargar productos de ejemplo
SEED_SAMPLE_DATA=true

# Crear base de datos de testing
CREATE_TEST_DB=false
```

### 4. Configurar Dominio y Traefik

1. En Dokploy, ve a la sección **Domains**
2. Agrega tu dominio: `tienda.cfv.technology`
3. Configura:
   - **Service:** `nginx`
   - **Port:** `80`
   - **Enable HTTPS:** ✅ (Dokploy generará certificado SSL automáticamente)

### 5. Configurar Volúmenes Persistentes

Dokploy debe configurar estos volúmenes automáticamente, pero verifica:

```yaml
volumes:
  workspace:       # Código de Bagisto
  mysql-data:      # Base de datos
  redis-data:      # Caché Redis
  elasticsearch-data:  # Búsqueda
```

### 6. Desplegar

1. Revisa la configuración
2. Haz clic en **Deploy**
3. Dokploy ejecutará:
   - Build de imágenes
   - Inicio de servicios
   - Setup automático de Bagisto

### 7. Monitorear Instalación

**⚠️ IMPORTANTE:** Antes de revisar los logs, asegúrate de que TODOS los servicios estén corriendo.

**Paso 1: Verificar Estado de Servicios**

1. Ve a tu proyecto en Dokploy
2. Verifica que estos servicios estén en estado **"Running"**:
   - ✅ `mysql` ← **CRÍTICO - debe estar corriendo primero**
   - ✅ `redis`
   - ✅ `elasticsearch`
   - ✅ `php-fpm`
   - ✅ `nginx`

3. **Si `mysql` NO está corriendo:**
   - Haz click en el servicio MySQL
   - Revisa sus logs para ver si hay errores
   - Espera 1-2 minutos (MySQL puede tardar en iniciar)
   - Si persiste el problema, verifica memoria y recursos del servidor

**Paso 2: Monitorear Logs de Instalación**

1. Una vez que todos los servicios estén "Running":
2. Ve a **Logs** en Dokploy
3. Selecciona el servicio `php-fpm`
4. Observa el progreso de la instalación:

```
[INFO] Iniciando instalación automatizada de Bagisto...
[INFO] Esperando a que MySQL esté disponible...
[INFO] Configuración de conexión:
[INFO]   - DB_HOST: mysql
[INFO]   - DB_PORT: 3306
[SUCCESS] MySQL está listo y aceptando conexiones
[INFO] Verificando/creando base de datos: bagisto
[SUCCESS] Base de datos 'bagisto' verificada/creada
[INFO] Clonando Bagisto v2.3.6...
[SUCCESS] Bagisto clonado exitosamente
...
[SUCCESS] Instalación de Bagisto completada exitosamente!
```

**Si ves el error: "MySQL no está disponible después de 60 intentos"**
- 📖 Consulta el archivo `TROUBLESHOOTING.md` en el repositorio
- Verifica que el servicio `mysql` esté corriendo en Dokploy
- Revisa las variables de entorno (especialmente `DB_HOST=mysql`)

## 🔍 Verificación Post-Despliegue

### Verificar que Bagisto está corriendo

1. Accede a tu dominio: `https://tienda.cfv.technology`
2. Deberías ver la página de inicio de Bagisto

### Acceder al Panel de Administración

1. URL: `https://tienda.cfv.technology/admin/login`
2. Credenciales por defecto:
   ```
   Email: admin@example.com
   Password: admin123
   ```
   > ⚠️ **IMPORTANTE:** Cambia estas credenciales inmediatamente

### Verificar servicios

En Dokploy, revisa que todos los servicios estén corriendo:

- ✅ `php-fpm` - Running
- ✅ `nginx` - Running
- ✅ `mysql` - Running
- ✅ `redis` - Running
- ✅ `elasticsearch` - Running
- ✅ `phpmyadmin` - Running (opcional)
- ✅ `mailpit` - Running

## 🛠️ Comandos Útiles

### Acceder al Contenedor PHP-FPM

En Dokploy, ve a **Terminal** y selecciona `php-fpm`, o usa:

```bash
docker exec -it bagisto-production-php-fpm-1 bash
```

### Verificar Estado de Instalación

```bash
# Ver si el setup se completó
docker exec bagisto-production-php-fpm-1 cat /var/www/html/.bagisto-setup-complete

# Ver logs del contenedor
docker logs bagisto-production-php-fpm-1
```

### Ejecutar Comandos Artisan

```bash
# Limpiar caché
docker exec bagisto-production-php-fpm-1 php artisan cache:clear

# Verificar migraciones
docker exec bagisto-production-php-fpm-1 php artisan migrate:status

# Crear usuario admin adicional
docker exec -it bagisto-production-php-fpm-1 php artisan bagisto:user:create-admin
```

### Reiniciar Setup (si es necesario)

```bash
# Método 1: Desde Dokploy
# 1. Ve a Environment Variables
# 2. Agrega: FORCE_SETUP=true
# 3. Redeploy

# Método 2: Manualmente
docker exec bagisto-production-php-fpm-1 rm /var/www/html/.bagisto-setup-complete
docker restart bagisto-production-php-fpm-1
```

## 🐛 Solución de Problemas

### Problema: "MySQL connection failed"

**Causa:** MySQL aún no está listo o credenciales incorrectas

**Solución:**
```bash
# Verificar que MySQL esté corriendo
docker ps | grep mysql

# Probar conexión
docker exec bagisto-production-mysql-1 mysql -uroot -proot -e "SELECT 1"

# Si falla, verifica las variables DB_HOST, DB_USERNAME, DB_PASSWORD
```

### Problema: "Permission denied"

**Causa:** Permisos de volúmenes incorrectos

**Solución:**
```bash
# Verificar propietario de archivos
docker exec bagisto-production-php-fpm-1 ls -la /var/www/html

# Corregir permisos (ejecutar como root)
docker exec -u root bagisto-production-php-fpm-1 chown -R bagisto:www-data /var/www/html
docker exec -u root bagisto-production-php-fpm-1 chmod -R 775 /var/www/html/storage
```

### Problema: "Página en blanco o error 500"

**Causa:** Error en la aplicación o configuración

**Solución:**
```bash
# Ver logs de Laravel
docker exec bagisto-production-php-fpm-1 tail -f storage/logs/laravel.log

# Limpiar caché
docker exec bagisto-production-php-fpm-1 php artisan cache:clear
docker exec bagisto-production-php-fpm-1 php artisan config:clear
docker exec bagisto-production-php-fpm-1 php artisan view:clear

# Regenerar autoload
docker exec bagisto-production-php-fpm-1 composer dump-autoload
```

### Problema: "Setup no se ejecuta automáticamente"

**Causa:** `AUTO_SETUP` no está configurado

**Solución:**
```bash
# Verificar variable
docker exec bagisto-production-php-fpm-1 env | grep AUTO_SETUP

# Si no existe, agrégala en Dokploy y redeploy

# O ejecuta manualmente
docker exec bagisto-production-php-fpm-1 bash /var/www/scripts/setup-bagisto.sh
```

### Problema: "Error al clonar repositorio"

**Causa:** Sin acceso a internet o GitHub

**Solución:**
```bash
# Verificar conectividad
docker exec bagisto-production-php-fpm-1 ping -c 3 github.com

# Intentar clonar manualmente
docker exec -it bagisto-production-php-fpm-1 bash
cd /var/www/html
git clone https://github.com/bagisto/bagisto.git .
```

## 📊 Monitoreo y Mantenimiento

### Logs de la Aplicación

```bash
# Logs de Laravel
docker exec bagisto-production-php-fpm-1 tail -f /var/www/html/storage/logs/laravel.log

# Logs de Nginx
docker logs -f bagisto-production-nginx-1

# Logs de MySQL
docker logs -f bagisto-production-mysql-1
```

### Backups

```bash
# Backup de base de datos
docker exec bagisto-production-mysql-1 mysqldump -uroot -proot bagisto > backup-$(date +%Y%m%d).sql

# Backup de archivos
docker run --rm -v bagisto-production_workspace:/data -v $(pwd):/backup ubuntu tar czf /backup/workspace-backup-$(date +%Y%m%d).tar.gz /data
```

### Actualizaciones

```bash
# Pull nueva versión del código
# En Dokploy: Redeploy con la última versión del repositorio

# Ejecutar migraciones
docker exec bagisto-production-php-fpm-1 php artisan migrate --force

# Limpiar caché
docker exec bagisto-production-php-fpm-1 php artisan cache:clear
docker exec bagisto-production-php-fpm-1 php artisan config:cache
```

## 🔐 Seguridad

### Cambiar Credenciales de Admin

1. Accede a `/admin/login`
2. Inicia sesión con credenciales por defecto
3. Ve a **Settings → Users**
4. Cambia email y contraseña

### Cambiar Credenciales de Base de Datos

1. Actualiza en Dokploy:
   ```env
   DB_PASSWORD=nueva_contraseña_segura
   ```
2. Actualiza en MySQL:
   ```bash
   docker exec -it bagisto-production-mysql-1 mysql -uroot -proot
   ALTER USER 'root'@'%' IDENTIFIED BY 'nueva_contraseña_segura';
   FLUSH PRIVILEGES;
   ```
3. Redeploy la aplicación

### Habilitar HTTPS

Dokploy maneja esto automáticamente con Let's Encrypt cuando configuras un dominio.

## 📚 Recursos Adicionales

- [Documentación oficial de Bagisto](https://devdocs.bagisto.com/)
- [Documentación de Dokploy](https://docs.dokploy.com/)
- [Soporte de Bagisto](https://webkul.uvdesk.com/)

## ✅ Checklist de Despliegue

- [ ] Proyecto creado en Dokploy
- [ ] Repositorio conectado
- [ ] Variables de entorno configuradas
- [ ] Dominio configurado y apuntando
- [ ] Deploy ejecutado exitosamente
- [ ] Todos los servicios corriendo
- [ ] Sitio accesible desde el navegador
- [ ] Panel de admin accesible
- [ ] Credenciales de admin cambiadas
- [ ] HTTPS funcionando
- [ ] Backup configurado

---

**¿Necesitas ayuda?** Abre un issue en el repositorio o contacta al equipo de soporte.
