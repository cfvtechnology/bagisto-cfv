# ⚡ Quick Fix - Error MySQL no disponible

## 🎯 Lo que estás viendo:

```
[ERROR] MySQL no está disponible después de 30/60 intentos
```

## ✅ Solución Rápida (5 minutos)

### Paso 1: Verifica que MySQL esté corriendo

**En Dokploy:**
1. Ve a tu proyecto
2. Busca el servicio llamado `mysql`
3. **¿Está en estado "Running"?**
   - ✅ SÍ → Ve al Paso 2
   - ❌ NO → Ve al Paso 1.1

#### Paso 1.1: Iniciar MySQL

1. Click en el servicio `mysql`
2. Click en **"Start"** o **"Restart"**
3. Espera 30-60 segundos
4. Verifica que cambie a "Running"
5. **Si no inicia:**
   - Click en "Logs"
   - Busca mensajes de error
   - Puede ser falta de memoria o espacio en disco

### Paso 2: Orden de Inicio

**Si MySQL está corriendo pero php-fpm sigue fallando:**

1. **Detén el servicio php-fpm:**
   - Ve al servicio `php-fpm`
   - Click en "Stop"
   - Espera que se detenga completamente

2. **Verifica que MySQL siga corriendo**

3. **Reinicia php-fpm:**
   - Click en "Start"
   - Ve a "Logs"
   - Deberías ver: `[SUCCESS] MySQL está listo y aceptando conexiones`

### Paso 3: Verificar Variables de Entorno

**En Dokploy, servicio php-fpm:**

1. Ve a "Environment Variables"
2. **Verifica que existan:**
   ```
   DB_HOST = mysql
   DB_USERNAME = root
   DB_PASSWORD = (tu password)
   DB_DATABASE = bagisto
   AUTO_SETUP = true
   ```

3. **Si falta alguna:**
   - Agrégala
   - Haz "Redeploy" del servicio

### Paso 4: Si nada funciona - Setup Manual

```bash
# 1. Desactiva el auto-setup
# En Dokploy → Environment Variables:
AUTO_SETUP = false

# 2. Redeploy

# 3. Una vez que todo esté corriendo, accede al contenedor:
docker exec -it <nombre-php-fpm> bash

# 4. Verifica conexión:
mysql -hmysql -uroot -p<tu-password> -e "SELECT 1"

# 5. Si funciona, ejecuta:
bash /var/www/scripts/setup-bagisto.sh
```

## 🆘 ¿Aún no funciona?

Lee el archivo completo: `TROUBLESHOOTING.md`

## 📊 Checklist Rápido

- [ ] Servicio `mysql` está en "Running"
- [ ] He esperado al menos 2 minutos después del deploy
- [ ] Las variables DB_HOST, DB_USERNAME, DB_PASSWORD están configuradas
- [ ] Los logs de MySQL no muestran errores
- [ ] El servidor tiene suficiente memoria (mínimo 2GB)

---

**Recuerda:** MySQL puede tardar 1-2 minutos en estar completamente listo después de mostrar "Running".
