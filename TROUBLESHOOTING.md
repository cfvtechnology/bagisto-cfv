# 🔧 Guía de Troubleshooting - Bagisto Docker

Esta guía te ayudará a resolver problemas comunes durante la instalación y configuración de Bagisto en Docker/Dokploy.

---

## ❌ Problema: "MySQL no está disponible después de 30 intentos"

### Descripción del Error

```
[ERROR] MySQL no está disponible después de 30 intentos
```

Este es el error más común y ocurre cuando el contenedor PHP-FPM intenta conectarse a MySQL pero no puede establecer la conexión.

### 🔍 Causas Posibles

1. **MySQL aún está iniciando** - MySQL puede tardar más en arrancar
2. **Orden de inicio incorrecto** - PHP-FPM inicia antes que MySQL
3. **Nombre del servicio incorrecto** - El hostname de MySQL no es correcto en Dokploy
4. **Credenciales incorrectas** - Usuario o contraseña de base de datos no coinciden
5. **MySQL no se está levantando** - El servicio MySQL tiene un error

---

## ✅ Soluciones

### Solución 1: Verificar que TODOS los servicios estén corriendo

**En Dokploy:**

1. Ve a tu proyecto
2. Verifica el estado de TODOS los servicios
3. **IMPORTANTE:** Asegúrate que el servicio `mysql` esté en estado **"Running"**

**Servicios que deben estar corriendo:**
- ✅ php-fpm
- ✅ nginx
- ✅ **mysql** ← Este es crítico
- ✅ redis
- ✅ elasticsearch

**Si MySQL no está corriendo:**
- Revisa los logs del servicio MySQL
- Puede haber un error de configuración
- Verifica que tenga suficiente memoria/recursos

---

### Solución 2: Verificar Orden de Inicio en Dokploy

En Dokploy, a veces los servicios no respetan el `depends_on` de docker-compose.

**Pasos:**

1. **Detén todos los servicios**
2. **Inicia SOLO MySQL primero:**
   - Espera 30-60 segundos
   - Verifica que esté "Running"
   - Revisa sus logs para confirmar que inicializó correctamente
3. **Luego inicia los demás servicios**

**Cómo iniciar servicios manualmente en Dokploy:**
- Ve a cada servicio
- Usa los botones Stop/Start
- Espera que cada uno confirme estado "Running"

---

### Solución 3: Verificar Variables de Entorno

El problema puede ser que las variables de entorno no estén configuradas correctamente.

**En Dokploy, verifica que tengas configuradas:**

```env
# Estas son REQUERIDAS
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=bagisto
DB_USERNAME=root
DB_PASSWORD=tu_password_aqui
AUTO_SETUP=true
```

**¿Cómo verificar en Dokploy?**

1. Ve a tu servicio `php-fpm`
2. Click en "Environment Variables"
3. Confirma que existan todas las variables arriba
4. **IMPORTANTE:** El valor de `DB_HOST` debe ser exactamente `mysql`

---

### Solución 4: Verificar Nombre del Servicio MySQL en la Red Docker

En algunos casos, Dokploy puede nombrar el servicio MySQL diferente.

**Cómo verificar:**

1. **Accede al contenedor php-fpm:**

   En Dokploy:
   - Ve al servicio `php-fpm`
   - Click en "Terminal" o "Shell"

   O desde línea de comandos:
   ```bash
   docker exec -it <nombre-contenedor-php-fpm> bash
   ```

2. **Intenta hacer ping a MySQL:**

   ```bash
   # Intenta el nombre por defecto
   ping -c 2 mysql

   # Si no funciona, intenta estas variantes:
   ping -c 2 bagisto-mysql-1
   ping -c 2 mysql-1
   ```

3. **Si encuentras el nombre correcto** pero NO es `mysql`:

   En Dokploy, actualiza la variable de entorno:
   ```env
   DB_HOST=nombre_correcto_que_encontraste
   ```

4. **Redeploy** el servicio php-fpm

---

### Solución 5: Aumentar Tiempo de Espera

La versión actualizada del script ya aumenta el tiempo de espera a 3 minutos (60 intentos x 3 segundos).

**Si aún no es suficiente:**

1. Accede al contenedor php-fpm
2. Edita el script:
   ```bash
   nano /var/www/scripts/setup-bagisto.sh
   ```
3. Busca la línea:
   ```bash
   local max_attempts=60
   ```
4. Auméntala a:
   ```bash
   local max_attempts=120
   ```
5. Guarda y ejecuta manualmente:
   ```bash
   bash /var/www/scripts/setup-bagisto.sh
   ```

---

### Solución 6: Instalación Manual (Bypass del Problema)

Si ninguna solución funciona, puedes instalar manualmente:

**Paso 1: Deshabilitar AUTO_SETUP**

En Dokploy, cambia:
```env
AUTO_SETUP=false
# o
SKIP_SETUP=true
```

**Paso 2: Redeploy y espera que los servicios estén estables**

**Paso 3: Ejecutar setup manualmente**

```bash
# Accede al contenedor
docker exec -it <php-fpm-container> bash

# Verifica conexión a MySQL
mysql -hmysql -uroot -p -e "SELECT 1"
# Ingresa la contraseña cuando te la pida

# Si la conexión funciona, ejecuta el setup
bash /var/www/scripts/setup-bagisto.sh
```

---

## 🔍 Diagnóstico Avanzado

### Ver logs del servicio MySQL

**En Dokploy:**
1. Ve al servicio `mysql`
2. Click en "Logs"
3. Busca errores o warnings

**Línea de comandos:**
```bash
docker logs <mysql-container-name>
```

**Busca errores como:**
- `[ERROR] InnoDB: ...`
- `[ERROR] Fatal error: ...`
- `killed` (sin memoria)

### Verificar conectividad desde PHP-FPM a MySQL

```bash
# Accede al contenedor php-fpm
docker exec -it <php-fpm-container> bash

# Verifica que el hostname se resuelva
getent hosts mysql

# Verifica que el puerto esté abierto
nc -zv mysql 3306

# Intenta conectarte a MySQL
mysql -hmysql -uroot -p<tu-password> -e "SELECT 1"
```

### Verificar recursos del servidor

```bash
# Memoria disponible
free -h

# Espacio en disco
df -h

# Contenedores corriendo
docker ps
```

---

## 📋 Checklist de Verificación

Antes de pedir ayuda, verifica:

- [ ] Todos los servicios están en estado "Running" en Dokploy
- [ ] El servicio `mysql` específicamente está corriendo
- [ ] Las variables de entorno están configuradas
- [ ] `DB_HOST=mysql` está configurado correctamente
- [ ] `DB_PASSWORD` coincide en todos los servicios
- [ ] Has esperado al menos 2-3 minutos después del deploy
- [ ] Los logs de MySQL no muestran errores críticos
- [ ] El servidor tiene suficiente memoria (mínimo 2GB)
- [ ] El servidor tiene suficiente espacio en disco (mínimo 5GB)

---

## 🆘 ¿Aún no funciona?

Si después de seguir todas las soluciones aún tienes problemas:

### Información para recopilar:

1. **Logs del servicio php-fpm:**
   ```bash
   docker logs <php-fpm-container> > php-fpm.log 2>&1
   ```

2. **Logs del servicio mysql:**
   ```bash
   docker logs <mysql-container> > mysql.log 2>&1
   ```

3. **Variables de entorno del php-fpm:**
   ```bash
   docker exec <php-fpm-container> env | grep -E "(DB_|AUTO_)" > env-vars.txt
   ```

4. **Estado de servicios:**
   ```bash
   docker ps -a > containers-status.txt
   ```

5. **Resultado de diagnóstico de red:**
   ```bash
   docker exec <php-fpm-container> bash -c "
   echo '=== Hostname resolution ==='
   getent hosts mysql
   echo '=== Port check ==='
   nc -zv mysql 3306
   echo '=== Ping test ==='
   ping -c 3 mysql
   " > network-diagnostic.txt 2>&1
   ```

### Reporta el problema con:
- Los archivos de log generados arriba
- Captura de pantalla de Dokploy mostrando el estado de servicios
- Configuración de variables de entorno (SIN incluir passwords)

---

## 📚 Recursos Adicionales

- [Documentación de Bagisto](https://devdocs.bagisto.com/)
- [Documentación de Dokploy](https://docs.dokploy.com/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [MySQL Docker Documentation](https://hub.docker.com/_/mysql)

---

**Última actualización:** Diciembre 2025
