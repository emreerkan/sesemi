# Contributing to Sesemi

Thank you for your interest in contributing to Sesemi! This document provides guidelines and information for contributors.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Commit Message Guidelines](#commit-message-guidelines)

## 📜 Code of Conduct

This project adheres to a simple code of conduct:
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Assume good intentions

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Environment details** (Ubuntu version, PHP version, etc.)
- **Relevant logs** from `/root/sesemi/{setup,migration}/$DOMAIN/`

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **Include examples** of how it would work

### Pull Requests

Pull requests are actively welcomed:

1. Fork the repo and create your branch from `main`
2. Make your changes following our coding standards
3. Test your changes on a fresh Ubuntu installation
4. Update documentation if needed
5. Ensure your code follows the existing style
6. Submit your pull request

## 🛠️ Development Setup

### Prerequisites

- Ubuntu 24.04 LTS (for testing)
- Root access on a test server/VM
- Basic knowledge of Bash scripting
- Familiarity with WordPress, Apache, MariaDB, and PHP

### Testing Your Changes

1. **Use a fresh Ubuntu installation** (VM or container)
2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/sesemi.git
   cd sesemi
   ```

3. **Test the setup script:**
   ```bash
   sudo ./setup.sh test.local
   ```

4. **Test the migration script:**
   - Prepare migration files from an existing WordPress installation
   - Run the migration on a fresh server

5. **Check for errors:**
   ```bash
   cat /root/sesemi/setup/test.local/setup.log
   ```

### Development Tips

- **Test in isolation** - Use VMs or containers to avoid affecting your main system
- **Check logs** - Always review log files after running scripts
- **Verify state** - Ensure state files are created and updated correctly
- **Test resume functionality** - Interrupt and resume scripts to test state persistence

## 📁 Project Structure

```
sesemi/
├── setup.sh                    # Main setup script
├── migrate.sh                  # Main migration script
├── prepare-migration.sh        # Helper for source server
├── lib/
│   ├── common/                 # Shared modules (both scripts use these)
│   ├── setup/                  # Setup-specific modules
│   └── migrate/                # Migration-specific modules
└── docs/                       # Documentation
```

### Module Guidelines

- **Common modules** - Used by both setup and migration scripts
- **Setup modules** - Only used by `setup.sh`
- **Migrate modules** - Only used by `migrate.sh`
- Each module should have a single, clear responsibility

## 💻 Coding Standards

### Bash Script Style

- **Use `#!/bin/bash`** at the top of each script
- **Enable strict mode** where appropriate: `set -euo pipefail`
- **Use meaningful variable names** in UPPER_CASE for globals
- **Quote variables** to prevent word splitting: `"$VARIABLE"`
- **Use functions** for reusable code
- **Add comments** for complex logic

### Function Guidelines

```bash
# Good: Clear function with documentation
# Description: Sets up Apache virtual host
# Args: $1 - Domain name
# Returns: 0 on success, 1 on failure
setup_apache() {
    local domain="$1"
    # Function implementation
}
```

### Error Handling

- Always check command return codes
- Use `log_error` for errors
- Update step status on failure
- Exit with appropriate error codes

```bash
if ! some_command &>> "$LOG_FILE"; then
    log_error "Failed to execute command"
    update_step_status "step_name" "failed"
    exit 1
fi
```

### Logging Best Practices

- Use appropriate log levels:
  - `log_info` - General information
  - `log_success` - Successful operations
  - `log_warning` - Non-critical issues
  - `log_error` - Errors requiring attention

- Use print functions for user output:
  - `print_header` - Section headers
  - `print_step` - Main steps
  - `print_substep` - Detailed substeps

### State Management

- Update step status before starting: `update_step_status "step_name" "in_progress"`
- Check if step completed: `check_step_completed "step_name"`
- Mark completed on success: `update_step_status "step_name" "completed"`
- Mark failed on error: `update_step_status "step_name" "failed"`

## 🔄 Pull Request Process

1. **Update documentation** if you're changing functionality
2. **Follow the coding standards** outlined above
3. **Test thoroughly** on a fresh Ubuntu installation
4. **Write clear commit messages** following our guidelines
5. **Reference related issues** in your PR description
6. **Respond to feedback** in a timely manner

### PR Title Format

- `feat: Add Let's Encrypt SSL support`
- `fix: Correct permission issues on staging files`
- `docs: Update SETUP.md with new prerequisites`
- `refactor: Reorganize certificate handling code`
- `test: Add validation for missing migration files`

## 📝 Commit Message Guidelines

### Format

```
<type>: <subject>

<body>

<footer>
```

### Types

- **feat** - New feature
- **fix** - Bug fix
- **docs** - Documentation changes
- **style** - Code style changes (formatting, no logic change)
- **refactor** - Code refactoring
- **test** - Adding or updating tests
- **chore** - Maintenance tasks

### Examples

```
feat: Add Redis object caching support

- Install and configure Redis
- Add WordPress Redis plugin
- Update documentation

Closes #42
```

```
fix: Resolve FTP passive port configuration

The passive port range was not being set correctly in vsftpd.conf,
causing connection issues from certain networks.

Fixes #38
```

## 🎯 Areas Needing Contribution

Check the [ROADMAP.md](ROADMAP.md) for planned features. High-priority areas include:

- Let's Encrypt integration
- PHP and MariaDB optimization
- Security enhancements (Fail2Ban, ModSecurity)
- Documentation improvements

## 💡 Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Create an issue with the "bug" label
- **Feature requests**: Create an issue with the "enhancement" label
- **Security issues**: Please email the maintainers directly

## 🙏 Thank You!

Your contributions make Sesemi better for everyone. Your time and effort in improving this project is appreciated!

---

*Happy Contributing!*
