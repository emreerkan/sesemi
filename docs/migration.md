# WordPress Server Migration Guide

A modular, maintainable server migration script for moving WordPress sites from Server A to Server B on Ubuntu with Apache, MariaDB, PHP, and FTP support.

## Quick Start

### On Target Server (Server B)

#### 0. Clone Repository

```bash
# On the target server
ssh root@your-target-server-ip

# Clone the repository
git clone https://github.com/emreerkan/sesemi.git
cd sesemi
```

### On Source Server (Server A)

#### 1. Prepare Migration Directory

```bash
mkdir -p /root/migration
cd /root/migration
```

#### 2. Export Databases

```bash
# Production database
cd /home/example.com
wp db export /root/migration/example.com.sql

# Staging database
cd /home/stage.example.com
wp db export /root/migration/stage.example.com.sql
```

#### 3. Create ZIP Archives

```bash
# Production WordPress files
cd /home/example.com
zip -r /root/migration/example.com.zip .

# Staging WordPress files
cd /home/stage.example.com
zip -r /root/migration/stage.example.com.zip .
```

#### 4. Copy SSL Certificates

```bash
cp /home/ssl/example.com-cf-origin.crt /root/migration/
cp /home/ssl/example.com-cf-origin.key /root/migration/
```

#### 5. Create config.env

```bash
cd /root/migration

# Get database credentials from wp-config.php
PROD_DB_NAME=$(grep DB_NAME /home/example.com/wp-config.php | cut -d "'" -f 4)
PROD_DB_USER=$(grep DB_USER /home/example.com/wp-config.php | cut -d "'" -f 4)
PROD_DB_PASS=$(grep DB_PASSWORD /home/example.com/wp-config.php | cut -d "'" -f 4)

STAGE_DB_NAME=$(grep DB_NAME /home/stage.example.com/wp-config.php | cut -d "'" -f 4)
STAGE_DB_USER=$(grep DB_USER /home/stage.example.com/wp-config.php | cut -d "'" -f 4)
STAGE_DB_PASS=$(grep DB_PASSWORD /home/stage.example.com/wp-config.php | cut -d "'" -f 4)

# Get FTP username (first part of domain)
FTP_USER=$(cut -d '.' -f 1 <<< "example.com")

# Get FTP password (you need to know this or reset it)
FTP_PASS="your_ftp_password"

# Create config.env
cat > config.env <<EOF
PROD_DB_NAME="$PROD_DB_NAME"
PROD_DB_USERNAME="$PROD_DB_USER"
PROD_DB_PASSWORD="$PROD_DB_PASS"

STAGE_DB_NAME="$STAGE_DB_NAME"
STAGE_DB_USERNAME="$STAGE_DB_USER"
STAGE_DB_PASSWORD="$STAGE_DB_PASS"

FTP_USERNAME="$FTP_USER"
FTP_PASSWORD="$FTP_PASS"
EOF
```

#### 6. Verify All Files

```bash
cd /root/migration
ls -lh

# You should see:
# - example.com-cf-origin.crt
# - example.com-cf-origin.key
# - example.com.sql
# - stage.example.com.sql
# - example.com.zip
# - stage.example.com.zip
# - config.env
```

#### 7. Create Tarball and Transfer

```bash
# Create tarball
cd /root
tar -czf migration.tar.gz migration/

# Transfer to new server
scp migration.tar.gz root@NEW_SERVER_IP:~
```

### On Destination Server (Server B)

#### 1. Upload Migration Script

```bash
# On your local machine
scp -r sesemi root@NEW_SERVER_IP:~
```

#### 2. Extract Migration Files

```bash
# SSH to new server
ssh root@NEW_SERVER_IP

# Extract migration files
tar -xzf migration.tar.gz
```

#### 3. Run Migration

```bash
cd ~/sesemi
./migrate.sh example.com ~/migration
```

#### 4. Review Results

```bash
# View migration summary
cat /root/sesemi/migration/example.com/migration_summary.txt

# View log
cat /root/sesemi/migration/example.com/migration.log
```

### After Migration

#### 1. Update DNS

Point your domain to the new server IP:

```
example.com         → NEW_SERVER_IP
www.example.com     → NEW_SERVER_IP
stage.example.com   → NEW_SERVER_IP
```

#### 2. Test Sites

```bash
# Check production
curl -I https://example.com

# Check staging
curl -I https://stage.example.com
```

#### 3. Verify WordPress

- Visit https://example.com/wp-admin/
- Visit https://stage.example.com/wp-admin/
- Login with your existing WordPress credentials

#### 4. Test FTP

```bash
ftp example.com
# Use credentials from config.env
```

## Features

- **State Persistence** - Resume from interruption points
- **Error Handling** - Comprehensive validation and error checking
- **Modular Design** - Clean separation of concerns
- **Beautiful Output** - Color-coded, progress-tracked interface
- **File Validation** - Ensures all required files are present
- **Dual Environment** - Migrates both production and staging

## Required Files

Before running the migration, prepare these files in a directory:

### 1. SSL Certificates (Required - Cloudflare Origin only)
- `example.com-cf-origin.crt` - Cloudflare origin certificate
- `example.com-cf-origin.key` - Cloudflare origin private key

### 2. Database Dumps
- `example.com.sql` - Production database export
- `stage.example.com.sql` - Staging database export

### 3. WordPress Files
- `example.com.zip` - Production WordPress files (from web root)
- `stage.example.com.zip` - Staging WordPress files (from web root)

### 4. Configuration File: `config.env`

```bash
# Production Database
PROD_DB_NAME="example_com_core"
PROD_DB_USERNAME="example_com_user"
PROD_DB_PASSWORD="your_prod_db_password"

# Staging Database
STAGE_DB_NAME="example_com_stage"
STAGE_DB_USERNAME="example_com_stage"
STAGE_DB_PASSWORD="your_stage_db_password"

# FTP Credentials
FTP_USERNAME="example"
FTP_PASSWORD="your_ftp_password"
```

## Usage

### Basic Migration

```bash
# Run from directory containing migration files
cd /root/migration
sudo ./path/to/migrate.sh example.com

# Or specify migration directory
sudo ./path/to/migrate.sh example.com /root/migration
```

### Resume After Interruption

If the script is interrupted, simply run it again:

```bash
sudo ./migrate.sh example.com /root/migration
```

The script will detect the previous migration and offer to continue.

Or explicitly continue:

```bash
sudo ./migrate.sh example.com /root/migration --continue
```

### Restart Migration

```bash
sudo ./migrate.sh example.com /root/migration --restart
```

### Help

```bash
./migrate.sh --help
```

## What Gets Installed

### Migration Steps

The script performs 12 main steps:

1. **Validate Files** - Check all required files exist
2. **Validate Environment** - Check root access, Ubuntu, disk space, ports
3. **Install Packages** - Install all required software
4. **Setup System** - Create users and folders
5. **Setup Certificates** - Install SSL certificates
6. **Configure Apache** - Setup virtual hosts and PHP
7. **Configure Firewall** - Setup UFW rules
8. **Configure Database** - Create MariaDB databases
9. **Import Databases** - Import SQL dumps
10. **Configure FTP** - Setup vsftpd server
11. **Extract Files** - Extract and set permissions on WordPress files
12. **Finalize** - Save summary and complete

### System Packages
- **Utilities**: byobu, lnav, ncdu, htop, btop, tar, zip, unzip, wget, rsync, nano, curl, acl, croc
- **Web Server**: Apache2 with SSL/TLS support
- **Database**: MariaDB
- **PHP**: Latest version with extensions
- **FTP**: vsftpd
- **Firewall**: UFW

### Configuration
- Apache virtual hosts for production and staging
- MariaDB databases with imported data
- FTP server with configured user
- SSL certificates installed
- File permissions and ownership set correctly

## Migration State

All state files are stored in `/root/sesemi/migration/$DOMAIN/`:

- `state.json` - Migration progress and step tracking
- `migration_summary.txt` - Migration summary and credentials
- `migration.log` - Detailed migration log

## Important Notes

1. **Domain Does Not Change** - This is a server-to-server migration only
2. **wp-config.php** - Must have correct database credentials already
3. **Cloudflare Certificates Required** - Self-signed certificates not supported
4. **Same Credentials** - Uses credentials from config.env file
5. **No URL Updates** - Domain stays the same, no search-replace needed

## Requirements

- Ubuntu (any recent version)
- Root or sudo access
- Internet connection
- At least 5GB free disk space
- Ports 80, 443, and 21 available
- All required migration files prepared

## Troubleshooting

### Resume Migration

```bash
./migrate.sh example.com ~/migration --continue
```

### Restart Migration

```bash
./migrate.sh example.com ~/migration --restart
```

### View Migration Log
```bash
cat /root/sesemi/migration/example.com/migration.log
```

### Check State
```bash
cat /root/sesemi/migration/example.com/state.json
```

### View Summary
```bash
cat /root/sesemi/migration/example.com/migration_summary.txt
```

### Common Issues

**Missing Files Error**
- Ensure all 7 required files are in the migration directory
- Check file names match the domain exactly

**Certificate Error**
- Only Cloudflare origin certificates are supported
- Ensure both .crt and .key files are present

**Database Import Error**
- Check SQL file syntax
- Ensure database credentials in config.env are correct
- Verify SQL files are not corrupted

**File Extraction Error**
- Ensure ZIP files are not corrupted
- Check disk space availability
- Verify ZIP files contain WordPress files

## Complete Example

```bash
# === ON OLD SERVER ===
mkdir /root/migration && cd /root/migration

# Export databases
wp --allow-root db export example.com.sql --path=/home/example.com
wp --allow-root db export stage.example.com.sql --path=/home/stage.example.com

# Zip files
cd /home/example.com && zip -r /root/migration/example.com.zip .
cd /home/stage.example.com && zip -r /root/migration/stage.example.com.zip .

# Copy certificates
cp /home/ssl/example.com-cf-origin.* /root/migration/

# Create config (adjust values)
cat > /root/migration/config.env <<'EOF'
PROD_DB_NAME="example_com_core"
PROD_DB_USERNAME="example_com_user"
PROD_DB_PASSWORD="prod_password_here"

STAGE_DB_NAME="example_com_stage"
STAGE_DB_USERNAME="example_com_stage"
STAGE_DB_PASSWORD="stage_password_here"

FTP_USERNAME="example"
FTP_PASSWORD="ftp_password_here"
EOF

# Create tarball
cd /root && tar -czf migration.tar.gz migration/

# Transfer to new server
scp migration.tar.gz root@1.2.3.4:~

# === ON NEW SERVER ===
tar -xzf migration.tar.gz
cd ~/sesemi
./migrate.sh example.com ~/migration

# === UPDATE DNS ===
# Point example.com to 1.2.3.4

# === DONE! ===
```

## Timing Estimates

- Small site (< 100MB): ~5-10 minutes
- Medium site (100MB - 1GB): ~10-20 minutes
- Large site (> 1GB): ~20-30+ minutes

Times vary based on:
- Site size
- Database size
- Server speed
- Network speed

## Security

- New MariaDB root password is randomly generated
- FTP user uses password from config.env
- Database users use credentials from config.env
- All credentials saved to protected files (chmod 600)
- Firewall configured automatically

## Preparing with prepare-migration.sh Helper

For convenience, you can use the `prepare-migration.sh` helper script on the source server:

```bash
# On source server
./prepare-migration.sh

# Follow the prompts to:
# - Specify domain
# - Export databases automatically
# - Create ZIP archives
# - Copy certificates
# - Generate config.env
# - Create tarball

# Then transfer the generated tarball to the new server
```
