# Bagisto Dockerization

The primary purpose of this repository is to provide a workspace along with all the necessary dependencies for Bagisto. In this repository, we include the following services:

- PHP-FPM
- Nginx
- MySQL
- Redis
- PHPMyAdmin
- Elasticsearch
- Kibana
- Mailpit

## Supported Bagisto Version

Currently, all these services are included to fulfill the dependencies for the following Bagisto version:

**Bagisto Version:** v2.3.6 and up.

However, there may be some specific cases where adjustments are necessary. We recommend reviewing the `Dockerfile` or the `docker-compose.yml` file for any required modifications.

> [!IMPORTANT]
> If you are using the master version, there is a possibility that the current setup script in this repository is configured for **Bagisto dev-master**. The `.env` files located in the `.configs` folder are aligned with this version. If you plan to modify the script or switch the Bagisto version, please ensure that your changes remain compatible with the updated version. 

## System Requirements

- System/Server requirements of Bagisto are mentioned [here](https://devdocs.bagisto.com/getting-started/before-you-start.html#system-requirements). Using Docker, these requirements will be fulfilled by docker images of PHP-FPM & Nginx, and our application will run in a multi-tier architecture.

- Install latest version of Docker and Docker Compose if it is not already installed. Docker supports Linux, MacOS and Windows Operating System. Click [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/) to find their installation guide.

## Installation

### Step 1: Configure Environment Variables

This repository uses environment variables for configuration to keep sensitive data secure.

1. **Copy the example environment file:**

   ```sh
   cp .env.example .env
   ```

2. **Edit the `.env` file** and update the values according to your needs:

   ```env
   # Update these values for your environment
   APP_URL=http://localhost
   DB_PASSWORD=your_secure_password_here
   AUTO_SETUP=true
   ```

   > **Important:** Never commit the `.env` file to the repository! It's already included in `.gitignore`.

### Step 2: Adjust Services (if needed)

- Most Linux users have a UID of 1000. If your UID is different, update it in the `.env` file:

   ```env
   APP_UID=1001  # Replace with your UID (run 'id -u' to find it)
   APP_USER=myuser  # Replace with your username
   ```

### Step 3: Start the Services

Once you have configured your `.env` file:

```sh
docker-compose up -d
```

The automated setup will:
- Wait for MySQL to be ready
- Create the database
- Clone Bagisto source code
- Install dependencies
- Configure the application
- Run migrations and seeders

> **Note:** The first startup may take several minutes as it downloads images and installs Bagisto.

## Automated Setup for Dokploy / Production

This repository includes automated setup scripts designed for deployment platforms like **Dokploy** that manage Docker Compose orchestration.

### How It Works

The automated setup runs inside the `php-fpm` container and handles:

- ✅ Waiting for MySQL to be ready
- ✅ Creating the database automatically
- ✅ Cloning Bagisto source code
- ✅ Installing Composer dependencies
- ✅ Configuring `.env` file
- ✅ Running migrations and Bagisto installer
- ✅ Setting proper file permissions

### Environment Variables

Configure these in your Dokploy environment settings or `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTO_SETUP` | `true` | Enable automatic setup on first container start |
| `BAGISTO_VERSION` | `v2.3.6` | Bagisto version to install |
| `SEED_SAMPLE_DATA` | `false` | Load sample product data |
| `CREATE_TEST_DB` | `false` | Create testing database |
| `APP_URL` | `http://localhost` | Your application URL (update with your domain) |
| `DB_HOST` | `mysql` | Database host |
| `DB_DATABASE` | `bagisto` | Database name |
| `DB_USERNAME` | `root` | Database username |
| `DB_PASSWORD` | `root` | Database password |
| `FORCE_SETUP` | `false` | Force reinstallation (deletes lock file) |
| `SKIP_SETUP` | `false` | Skip setup completely |

### Deployment in Dokploy

1. **Create a new service** in Dokploy pointing to this repository

2. **Configure environment variables** in Dokploy UI (see `.env.dokploy.example` for reference):

   **Required variables:**
   - `APP_URL` - Your domain (e.g., `https://tienda.cfv.technology`)
   - `DB_PASSWORD` - A strong password for MySQL (generate with `openssl rand -base64 32`)
   - `APP_ENV` - Set to `production`
   - `APP_DEBUG` - Set to `false`

   **Optional variables:**
   - `SEED_SAMPLE_DATA=true` - Enable if you want demo products
   - `BAGISTO_VERSION=v2.3.6` - Specify Bagisto version
   - `AUTO_SETUP=true` - Keep enabled for automatic installation

   > **Security Note:** Dokploy's environment variables are NOT committed to the repository, keeping your credentials safe.

3. **Deploy the service** - Bagisto will install automatically on first run

4. **Monitor the installation** via Dokploy logs:
   ```bash
   # In Dokploy UI, go to: Service → Logs
   # You'll see the installation progress
   ```

5. **Access your store** at your configured domain

### Manual Setup (if needed)

If you need to run setup manually or troubleshoot:

```bash
# Access the php-fpm container
docker exec -it <container-name> bash

# Run setup script
bash /var/www/scripts/setup-bagisto.sh
```

### Reinstalling Bagisto

To force a fresh installation:

```bash
# Method 1: Use environment variable
# In Dokploy, set: FORCE_SETUP=true and redeploy

# Method 2: Delete lock file manually
docker exec -it <container-name> rm /var/www/html/.bagisto-setup-complete
docker restart <container-name>
```

### Troubleshooting

**Setup not running automatically?**
- Check that `AUTO_SETUP=true` in environment variables
- Verify MySQL container is running and accessible
- Check container logs for errors

**Database connection failed?**
- Ensure MySQL service is named `mysql` in docker-compose.yml
- Verify `DB_HOST`, `DB_USERNAME`, and `DB_PASSWORD` are correct
- Wait a few seconds for MySQL to fully initialize

**Permission errors?**
- The container runs as user `bagisto` (UID 1000 by default)
- Ensure the workspace volume has proper permissions
- Check `uid` argument in docker-compose.yml matches your environment

**Need to check installation status?**
```bash
# Check if setup completed
docker exec <container-name> cat /var/www/html/.bagisto-setup-complete

# View setup logs
docker logs <container-name>
```

**Getting "MySQL no está disponible" error?**
- 📖 See `TROUBLESHOOTING.md` for detailed solutions
- Verify MySQL service is running
- Check environment variables
- Review MySQL logs for errors

## After installation

- To log in as admin.

  ```text
  http(s)://your_server_endpoint/admin/login

  Email: admin@example.com
  Password: admin123
  ```

- To log in as customer. You can directly register as customer and then login.

  ```text
  http(s):/your_server_endpoint/customer/register
  ```

> [!IMPORTANT]
> **Change the default admin credentials immediately after first login!**

## Traditional Setup (Legacy)

If you prefer the traditional manual setup process:

```sh
sh setup.sh
```

This script will set up everything step by step (Docker Compose must be available on host).

## Already Docker Expert?

- You can use this repository as your workspace. To build your container, simply run the following command:

  ```sh
  docker-compose build
  ```

- After building, you can run the container with:

  ```sh
  docker-compose up -d
  ```

- The automated setup will run on first start if `AUTO_SETUP=true`

## Scripts Reference

### `/var/www/scripts/setup-bagisto.sh`

Main installation script. Features:
- Idempotent (safe to run multiple times)
- Error handling and validation
- Colored output for easy debugging
- Lock file mechanism to prevent re-installation

### `/var/www/scripts/entrypoint.sh`

Container entrypoint that handles:
- Automatic setup trigger
- Environment variable configuration
- PHP-FPM startup

## Support

In case of any issues or queries, raise your ticket at [Webkul Support](https://webkul.uvdesk.com/en/customer/create-ticket/).
