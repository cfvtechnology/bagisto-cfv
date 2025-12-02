## Unreleased

### ✨ Major Features

- **Automated Setup for Dokploy/Production Environments**
  - Added automated installation scripts that run inside containers
  - No need for manual `setup.sh` execution from host
  - Full support for orchestration platforms like Dokploy
  - Idempotent setup process (safe to run multiple times)

### 🚀 New Scripts

- `scripts/setup-bagisto.sh` - Main automated installation script with:
  - Automatic MySQL readiness detection
  - Database creation and initialization
  - Bagisto source code cloning
  - Composer dependency installation
  - Environment configuration
  - Migration and seeder execution
  - Comprehensive error handling and logging
  - Lock file mechanism to prevent re-installation

- `scripts/entrypoint.sh` - Container entrypoint with:
  - Automatic setup trigger on first run
  - Environment-based configuration
  - Manual setup support
  - Graceful PHP-FPM startup

### 📝 Configuration

- Updated `Dockerfile`:
  - Added automation scripts with proper permissions
  - Configured custom entrypoint
  - Maintained backward compatibility

- Enhanced `docker-compose.yml`:
  - Added environment variables for automated setup
  - Database configuration auto-injection
  - Setup behavior controls (AUTO_SETUP, FORCE_SETUP, SKIP_SETUP)
  - Optional features (SEED_SAMPLE_DATA, CREATE_TEST_DB)

### 📚 Documentation

- Comprehensive `DOKPLOY.md` guide including:
  - Step-by-step deployment instructions
  - Environment variable reference
  - Troubleshooting section
  - Maintenance and monitoring commands
  - Security best practices

- Updated `README.md` with:
  - Automated setup section
  - Dokploy deployment guide
  - Environment variables table
  - Troubleshooting tips
  - Scripts reference

### 🔧 Technical Improvements

- Replaced Apache services with Nginx
- Added support for [Bagisto](https://github.com/bagisto/bagisto) v2.3.6 and up
- Container-based setup removes dependency on host Docker commands
- Better separation of concerns (build vs runtime)
- Improved error handling and user feedback
- Colored console output for better debugging

### 🐛 Bug Fixes

- **MySQL Password Special Characters Fix**
  - Fixed issue with passwords containing special characters (e.g., `@`, `!`, `#`)
  - Changed from `-pPASSWORD` format to `MYSQL_PWD` environment variable
  - All MySQL commands now properly handle complex passwords
  - Resolves connection failures when using secure passwords

- **Docker Networking Clarification**
  - Fixed common `localhost` vs `mysql` hostname confusion in documentation
  - Clear warnings in all configuration files about correct `DB_HOST` value
  - Updated `.env.dokploy.example` with correct `DB_HOST=mysql`

### 📖 New Documentation

- **`DOKPLOY-FIX.md`** - Quick fix guide for Dokploy deployments
  - Corrects common configuration errors
  - Step-by-step variable configuration
  - Database cleanup procedures

### 🔐 Security Improvements

- **Environment Variables Externalization**
  - Removed hardcoded credentials from `docker-compose.yml`
  - All sensitive data now uses environment variables
  - Added `.env.example` for local development
  - Added `.env.dokploy.example` for production deployment
  - Created comprehensive `.gitignore` to prevent committing sensitive files
  - Database passwords, API keys, and configuration now externalized
  - Supports different configurations per environment (dev/staging/prod)

## **v1.1.1 (15th of September 2025)** - *Release*

- Added support for [Bagisto](https://github.com/bagisto/bagisto) v2.2.4 to v2.3.6.

## **v1.1.0 (1st of April 2025)** - *Release*

- Added support for [Bagisto](https://github.com/bagisto/bagisto) v2.2.4 and above.


## **v1.0.0 (29th of October 2024)** - *First Release*

- Added support for [Bagisto](https://github.com/bagisto/bagisto) v2.0.0 and above.
