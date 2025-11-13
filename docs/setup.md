# WordPress Server Setup Guide

A modular, maintainable server setup script for deploying WordPress on Ubuntu with Apache, MariaDB, PHP, and FTP support.

## Quick Start

### 1. Clone Repository

```bash
# On the server
ssh root@your-server-ip

# Clone the repository
git clone https://github.com/emreerkan/sesemi.git
cd sesemi
```

### 2. Prepare SSL Certificates (Optional)

If you have Cloudflare origin certificates, place them in the script directory:

```bash
# Place your certificates here (rename to match your domain)
cp /path/to/cert example.com-cf-origin.crt .
cp /path/to/key example.com-cf-origin.key .
```

If you don't have Cloudflare certificates, the script will generate self-signed certificates automatically.

### 3. Run the Setup

```bash
# Make sure you're root
sudo su

# Run the setup
./setup.sh example.com
```

### 4. Configure DNS

After installation, configure your DNS:

**For Production (example.com):**
```
Type: A
Name: @
Value: [your-server-ip]
TTL: Auto

Type: A
Name: www
Value: [your-server-ip]
TTL: Auto
```

**For Staging (stage.example.com):**
```
Type: A
Name: stage
Value: [your-server-ip]
TTL: Auto
```

**Cloudflare Settings (if using):**
- SSL/TLS mode: Full (strict) if using Cloudflare origin certificates
- SSL/TLS mode: Full if using self-signed certificates
- Enable Always Use HTTPS

## Features

- **State Persistence** - Resume from interruption points
- **Error Handling** - Comprehensive validation and error checking
- **Modular Design** - Clean separation of concerns
- **Beautiful Output** - Color-coded, progress-tracked interface
- **Cleanup Support** - Remove previous installations
- **Dual Environment** - Production + Staging WordPress installations

## Usage

### Basic Installation

```bash
# Run with domain argument
sudo ./setup.sh example.com

# Or run without arguments (will prompt)
sudo ./setup.sh
```

### Resume After Interruption

If the script is interrupted, simply run it again:

```bash
sudo ./setup.sh example.com
```

The script will detect the previous installation and offer options to continue.

Or explicitly continue:

```bash
sudo ./setup.sh example.com --continue
```

### Start Over

Remove the previous installation and start fresh:

```bash
sudo ./setup.sh example.com --restart
```

### Cleanup Only

Remove a previous installation without reinstalling:

```bash
sudo ./setup.sh example.com --cleanup
```

### Help

```bash
./setup.sh --help
```

## What Gets Installed

### Installation Steps

The script performs 12 main steps:

1. **Validate Environment** - Check root access, Ubuntu version, disk space, ports
2. **Setup Certificates** - Install or generate SSL certificates
3. **Setup System** - Create users, folders, bash aliases
4. **Install Packages** - Install all required software
5. **Configure Apache** - Setup virtual hosts and PHP settings
6. **Configure Firewall** - Setup UFW rules
7. **Configure Database** - Create MariaDB databases and users
8. **Configure FTP** - Setup vsftpd server
9. **Install WP-CLI** - Install WordPress command-line tool
10. **Install WordPress (Production)** - Setup production WordPress
11. **Install WordPress (Staging)** - Setup staging WordPress
12. **Finalize** - Save credentials and complete setup

### System Packages
- **Utilities**: byobu, lnav, ncdu, htop, btop, tar, zip, unzip, wget, rsync, nano, curl, acl, croc
- **Web Server**: Apache2 with SSL/TLS support
- **Database**: MariaDB
- **PHP**: Latest version with extensions (opcache, imagick, curl, gd, mysqlnd, bcmath, intl, zip, imap, mbstring)
- **FTP**: vsftpd
- **Firewall**: UFW

### WordPress
- Production site at `https://example.com`
- Staging site at `https://stage.example.com`
- WP-CLI for WordPress management

### SSL Certificates
- Uses provided Cloudflare origin certificates if available
- Generates self-signed certificate if Cloudflare certs not found
- Place `example.com-cf-origin.crt` and `example.com-cf-origin.key` in the script directory before running

## After Installation

### Access WordPress

- **Production**: https://example.com/wp-admin/
- **Staging**: https://stage.example.com/wp-admin/

### View Credentials

```bash
cat /root/sesemi/setup/example.com/credentials.txt
```

### View Logs

```bash
cat /root/sesemi/setup/example.com/setup.log
```

### Connect via FTP

```
Host: example.com
Port: 21
Username: (shown in credentials)
Password: (shown in credentials)
```

### Connect to Database

```bash
# Root access
mysql -u root -p
# Password shown in credentials

# Application access
mysql -u example_com_user -p example_com_core
# Password shown in credentials
```

## Credentials

After installation, credentials are:

- **Displayed on screen**
- **Saved to** `/root/sesemi/setup/$DOMAIN/credentials.txt`
- **Saved to** `/root/sesemi/setup/$DOMAIN/config.env` (machine-readable)

### Generated Credentials

The script generates random credentials for:
- FTP user and password
- MariaDB root password
- Production database and user
- Staging database and user
- WordPress admin username and password

## Installation State

All state files are stored in `/root/sesemi/setup/$DOMAIN/`:

- `state.json` - Installation progress and step tracking
- `config.env` - All generated credentials and configuration
- `credentials.txt` - Human-readable credential summary
- `setup.log` - Detailed installation log

## Requirements

- Ubuntu (any recent version)
- Root or sudo access
- Internet connection
- At least 5GB free disk space
- Ports 80, 443, and 21 available

## Maintenance Commands

### Update WordPress Core
```bash
wp --allow-root core update
```

### Update WordPress Plugins
```bash
wp --allow-root plugin update --all
```

### Create Database Backup
```bash
wp --allow-root db export /backup/$(date +%Y%m%d).sql
```

### Check Apache Status
```bash
systemctl status apache2
```

### Check MariaDB Status
```bash
systemctl status mariadb
```

### View Apache Logs
```bash
tail -f /var/log/apache2/example.com-access.log
tail -f /var/log/apache2/example.com-error.log
```

## Troubleshooting

### Script Interrupted?

Just run it again:
```bash
./setup.sh example.com
```

It will detect the interruption and ask if you want to continue.

### Want to Start Over?

```bash
./setup.sh example.com --restart
```

### Just Want to Clean Up?

```bash
./setup.sh example.com --cleanup
```

### View Logs
```bash
cat /root/sesemi/setup/example.com/setup.log
```

### Check State
```bash
cat /root/sesemi/setup/example.com/state.json
```

### View Credentials
```bash
cat /root/sesemi/setup/example.com/credentials.txt
```

### Manual Cleanup
If automatic cleanup fails:
```bash
# Remove WordPress files
rm -rf /home/example.com
rm -rf /home/stage.example.com

# Remove databases (after logging into MySQL)
DROP DATABASE example_com_core;
DROP DATABASE example_com_stage;

# Remove Apache configs
a2dissite example.com.conf
rm /etc/apache2/sites-available/example.com*

# Remove user
userdel -r example

# Remove state
rm -rf /root/sesemi/setup/example.com
```

## Error Handling

- All commands are logged to `setup.log`
- Failed steps are marked in state file
- Script can be re-run to continue from failure point
- Error messages include context and suggestions

## Security Notes

- All credentials are randomly generated
- FTP user has limited access (chrooted to /home/example.com)
- Firewall is configured to allow only necessary ports
- SSL certificates secure all web traffic
- Database users have access only to their specific databases

## Module Descriptions

### lib/colors.sh
Defines color constants for console output.

### lib/logger.sh
Provides logging functions:
- `log()` - Write to log file
- `log_info()` - Info messages (blue)
- `log_success()` - Success messages (green)
- `log_warning()` - Warning messages (yellow)
- `log_error()` - Error messages (red)
- `print_header()` - Print section headers
- `print_step()` - Print step with counter
- `print_substep()` - Print substep details

### lib/state-setup.sh
Manages installation state:
- `init_state_directory()` - Initialize state directory
- `create_initial_state()` - Create state JSON file
- `update_step_status()` - Mark step as pending/in_progress/completed/failed
- `save_config()` - Save configuration to file
- `load_config()` - Load configuration from file
- `check_step_completed()` - Check if step is done

### lib/validators-setup.sh
Input and environment validation:
- `validate_domain_format()` - Validate domain name
- `validate_environment()` - Check system requirements

### lib/certificates-setup.sh
SSL certificate handling:
- `setup_certificates()` - Install or generate SSL certificates

### lib/system-setup.sh
System setup:
- `setup_system()` - Create users, folders, generate credentials

### lib/packages.sh
Package installation:
- `install_packages()` - Install all required packages

### lib/apache.sh
Apache configuration:
- `configure_apache()` - Create virtual hosts, configure PHP

### lib/firewall.sh
Firewall setup:
- `configure_firewall()` - Configure UFW rules

### lib/database-setup.sh
Database configuration:
- `configure_database()` - Setup MariaDB, create databases

### lib/ftp.sh
FTP server setup:
- `configure_ftp()` - Configure vsftpd

### lib/wordpress.sh
WordPress installation:
- `install_wpcli()` - Install WP-CLI
- `install_wordpress_prod()` - Install production WordPress
- `install_wordpress_stage()` - Install staging WordPress

### lib/cleanup.sh
Cleanup operations:
- `cleanup_installation()` - Remove previous installation
