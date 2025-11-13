# Sesemi - Server Setup & Migration Scripts

An opinionated, production-ready Ubuntu server management toolkit for WordPress with modular architecture, state persistence, and beautiful CLI output.

## Prerequisites

Before using these scripts, ensure your server meets these requirements:

- **Fresh Ubuntu Install** - Ubuntu 24.04 LTS
- **Root Access** - Must have root or sudo privileges
- **Available Ports** - Ports 21, 22, 80, 443 must be free
- **FTP Passive Ports** - Ports 30000-31000 must be available

## 🚀 Quick Start

### Fresh WordPress Installation
```bash
# Clone the repository
git clone https://github.com/emreerkan/sesemi.git
cd sesemi

# Simple - just provide domain
sudo ./setup.sh example.com

# Continue interrupted installation
sudo ./setup.sh example.com --continue

# Restart from beginning
sudo ./setup.sh example.com --restart
```

### Server Migration
```bash
# 0. On target server: Clone the repository
git clone https://github.com/emreerkan/sesemi.git
cd sesemi

# 1. On source server: Prepare migration files
#    Use migration helper script or manually gather required files
./prepare-migration.sh

# 2. Transfer migration-example.com.tar.gz to target server
scp migration-example.com.tar.gz root@your-target-server-ip:~

# 3. On target server: Extract and migrate
tar -xzf migration-example.com.tar.gz
sudo ./migrate.sh example.com ./migration-example.com

# Continue interrupted migration
sudo ./migrate.sh example.com ./migration-example.com --continue
```

## 📚 Documentation

- **[docs/SETUP.md](docs/setup.md)** - Complete setup guide with quick start
- **[docs/MIGRATION.md](docs/migration.md)** - Complete migration guide with quick start
- **[docs/TESTING.md](docs/testing.md)** - Testing with Multipass VMs (macOS)

## ✨ Features

### Both Scripts
- **Modular Architecture** - Clean lib/ directory with versioned modules
- **State Persistence** - Resume from interruption points
- **Error Handling** - Comprehensive validation and error messages
- **Beautiful Output** - Color-coded progress with step counters
- **Detailed Logging** - Complete operation logs

### Setup Script
- Fresh WordPress installation (production + staging)
- Random credential generation (for setup)
- SSL (Cloudflare origin or self-signed)
- WP-CLI integration
- Cleanup capability

### Migration Script
- Server-to-server WordPress migration
- File validation (7 required files)
- Database import
- Cloudflare origin certificates required
- Helper script for source preparation

## 🗂️ Library Architecture

### Common Modules
Shared by both setup and migration scripts:
- `common/apache.sh` - Apache virtual hosts configuration
- `common/colors.sh` - ANSI color codes for terminal output
- `common/firewall.sh` - UFW firewall configuration
- `common/ftp.sh` - vsftpd FTP server setup
- `common/logger.sh` - Logging and output functions
- `common/packages.sh` - APT package installation
- `common/wpcli.sh` - WP-CLI installation

### Setup-Specific Modules
Used only by `setup.sh`:
- `setup/certificates.sh` - SSL certificate handling (Cloudflare or self-signed)
- `setup/cleanup.sh` - Cleanup operations for previous installations
- `setup/database.sh` - MariaDB database creation with random credentials
- `setup/state.sh` - State management and persistence
- `setup/system.sh` - User and folder creation
- `setup/validators.sh` - Input and environment validation
- `setup/wordpress.sh` - Fresh WordPress installation

### Migration-Specific Modules
Used only by `migrate.sh`:
- `migrate/certificates.sh` - SSL certificate installation (Cloudflare origin only)
- `migrate/database.sh` - Database import from SQL dumps
- `migrate/files.sh` - WordPress file extraction and permissions
- `migrate/state.sh` - Migration state management
- `migrate/system.sh` - User and folder creation
- `migrate/validators.sh` - File and environment validation

## 📦 Installed Stack

- Apache 2.4
- MariaDB 11.x
- PHP 8.3+ (auto-detected)
- vsftpd
- WP-CLI
- UFW firewall

## 🎯 Use Cases

### Use `setup.sh` when:
- Setting up a brand new server
- Creating a new WordPress site
- No existing WordPress installation
- Starting from scratch

### Use `migrate.sh` when:
- Moving site from Server A to Server B
- Same domain (no URL changes)
- Have existing database dumps and files
- Production environment migration

## 🔐 Security

- Firewall automatically configured (ports 80, 443, 21)
- Strong random password generation
- File permissions properly set (775/664)
- ACL support for shared access
- MariaDB secured with root password

## 📝 State Storage

### Setup Script
- `/root/sesemi/setup/$DOMAIN/`
  - `state.json` - Step tracking
  - `credentials.txt` - All passwords
  - `config.env` - Configuration
  - `setup.log` - Operation log

### Migration Script
- `/root/sesemi/migration/$DOMAIN/`
  - `state.json` - Step tracking
  - `migration_summary.txt` - Migration summary
  - `migration.log` - Operation log

## 🆘 Support

For issues or questions:
1. Check **[docs/SETUP.md](docs/SETUP.md)** for setup issues
2. Check **[docs/MIGRATION.md](docs/MIGRATION.md)** for migration issues
3. Review logs in `/root/sesemi/{setup,migration}/$DOMAIN/`
4. Use `--help` flag for usage information

## 📄 License

MIT License - Feel free to use and modify!

## 🙏 Credits

Base code: Emre Erkan | [X](https://x.com/IzzetEmreErkan) | [Web Site](https://karalamalar.net) | [GitHub](https://github.com/emreerkan).  
AI assistance: [Copilot](https://github.com/features/copilot) with [Claude Sonnet 4.5](https://www.anthropic.com/claude/sonnet)

Developed for reliable WordPress server management with focus on:
- Code maintainability through modular design
- Operational reliability through state persistence
- User experience through clear progress feedback
