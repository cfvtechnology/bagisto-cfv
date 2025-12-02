# 🔧 Corrección del Problema en Dokploy

## ❌ Error Detectado

En tus logs veo:
```
DB_HOST: localhost  ← INCORRECTO
DB_USERNAME: cfvtienda
DB_DATABASE: tiendacfv
```

**Problema:** `localhost` en Docker apunta al mismo contenedor, no al servicio MySQL.

---

## ✅ Solución - Configuración Correcta para Dokploy

### Paso 1: Actualizar Variables de Entorno en Dokploy

**Ve a tu servicio en Dokploy → Environment Variables**

**Configura EXACTAMENTE así:**

```env
# ============================================================================
# CRÍTICO: DB_HOST debe ser "mysql", NO "localhost"
# ============================================================================

# Application
APP_URL=https://tienda.cfv.technology
APP_ENV=production
APP_DEBUG=false

# Database Configuration
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=tiendacfv
DB_USERNAME=cfvtienda
DB_PASSWORD=ADmin@2025

# Bagisto Setup
AUTO_SETUP=true
BAGISTO_VERSION=v2.3.6
SEED_SAMPLE_DATA=false
CREATE_TEST_DB=false
```

### Paso 2: Limpiar Datos de MySQL (Importante)

Como ya intentaste instalar con configuración incorrecta, necesitas limpiar MySQL:

**Opción A: En Dokploy UI**
1. Ve al servicio `mysql`
2. Detén el servicio
3. Ve a "Volumes" o "Data"
4. Elimina el volumen de MySQL (si existe opción)
5. Reinicia el servicio

**Opción B: Desde línea de comandos**
```bash
# Encuentra el contenedor MySQL
docker ps | grep mysql

# Detén el contenedor
docker stop <mysql-container-id>

# Elimina el volumen de datos (esto borrará la base de datos)
docker volume rm <project-name>_mysql-data

# O si está en .configs/data/mysql-data, elimina la carpeta
# (ajusta la ruta según tu configuración)
rm -rf .configs/data/mysql-data/*

# Inicia de nuevo
docker start <mysql-container-id>
```

### Paso 3: Orden Correcto de Inicio

**IMPORTANTE:** Inicia los servicios en este orden:

1. **MySQL primero:**
   - En Dokploy, ve al servicio `mysql`
   - Click en "Start"
   - **ESPERA 60-90 segundos**
   - Verifica logs: Debe decir "ready for connections"

2. **Luego los demás:**
   - Redis
   - Elasticsearch
   - PHP-FPM
   - Nginx

### Paso 4: Verificar Instalación

1. Ve a los logs del servicio `php-fpm`
2. Deberías ver:

```
[INFO] Configuración de conexión:
[INFO]   - DB_HOST: mysql          ← Debe decir "mysql" no "localhost"
[INFO]   - DB_PORT: 3306
[INFO]   - DB_USERNAME: cfvtienda
[INFO]   - DB_DATABASE: tiendacfv
[INFO] Intentando resolver hostname mysql...
[SUCCESS] Hostname resuelto a IP: xxx.xxx.xxx.xxx
[SUCCESS] MySQL está listo y aceptando conexiones
[INFO] Verificando/creando base de datos: tiendacfv
[SUCCESS] Base de datos 'tiendacfv' verificada/creada
```

---

## 📋 Checklist Antes de Reiniciar

- [ ] He cambiado `DB_HOST` de `localhost` a `mysql` en Dokploy
- [ ] He limpiado los datos de MySQL (volumen/carpeta)
- [ ] He reiniciado MySQL y esperado que esté "ready for connections"
- [ ] He revisado que TODAS las variables estén configuradas
- [ ] He esperado al menos 2 minutos después de reiniciar MySQL

---

## 🎯 Configuración Completa para Copy/Paste en Dokploy

**Variables de Entorno del servicio php-fpm:**

```
APP_URL=https://tienda.cfv.technology
APP_ENV=production
APP_DEBUG=false
APP_TIMEZONE=America/Mexico_City
APP_LOCALE=es
APP_CURRENCY=MXN

DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=tiendacfv
DB_USERNAME=cfvtienda
DB_PASSWORD=ADmin@2025

AUTO_SETUP=true
BAGISTO_VERSION=v2.3.6
SEED_SAMPLE_DATA=false
CREATE_TEST_DB=false
```

**¿Por qué funciona ahora?**

1. **`DB_HOST=mysql`** - Apunta al servicio MySQL en la red Docker
2. **MySQL crea el usuario automáticamente** - Gracias a `MYSQL_USER` y `MYSQL_DATABASE` en docker-compose.yml
3. **Password consistente** - Mismo password para root y usuario personalizado

---

## 🔍 Verificación de Conectividad (Opcional)

Si quieres verificar la conexión manualmente:

```bash
# Accede al contenedor php-fpm
docker exec -it <php-fpm-container> bash

# Verifica que "mysql" se resuelva correctamente
getent hosts mysql
# Debe mostrar una IP, NO ::1 (localhost)

# Prueba conexión a MySQL
mysql -h mysql -u cfvtienda -pADmin@2025 -e "SELECT 1"
# Debe mostrar: | 1 |

# Si funciona, ejecuta el setup
bash /var/www/scripts/setup-bagisto.sh
```

---

## 🆘 Si Aún No Funciona

Revisa estos puntos:

1. **¿Los servicios están en la misma red Docker?**
   - En Dokploy, todos los servicios del mismo proyecto deben estar en la misma red

2. **¿MySQL está realmente corriendo?**
   ```bash
   docker logs <mysql-container>
   ```
   Busca: `ready for connections`

3. **¿Las credenciales son correctas?**
   - Verifica que `DB_PASSWORD` sea EXACTAMENTE `ADmin@2025`
   - No debe tener espacios ni caracteres extra

---

## 📚 Cambios Realizados en el Repositorio

1. **`docker-compose.yml`** - MySQL ahora crea automáticamente usuario y base de datos personalizados
2. **`.env.example`** - Documentado que DB_HOST debe ser "mysql"
3. **`.env.dokploy.example`** - Corregido DB_HOST=mysql

**Para aplicar estos cambios:**
```bash
git pull origin main
# Luego redeploy en Dokploy
```

---

**Última actualización:** Diciembre 2025
