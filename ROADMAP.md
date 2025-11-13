# Roadmap

This document outlines planned features and improvements for Sesemi.

## 🎯 Planned Features

### SSL/TLS Enhancements
- [ ] **Let's Encrypt Integration** - Automatic SSL certificate generation and renewal using Certbot
- [ ] **Certificate Auto-Renewal** - Systemd timer or cron job for automatic certificate renewal
- [ ] **Multi-Certificate Support** - Allow choosing between Cloudflare Origin, Let's Encrypt, or self-signed

### PHP Configuration
- [ ] **Optimized PHP Settings** - Configure PHP.ini for WordPress performance:
  ```ini
  memory_limit = 512M
  max_input_vars = 10000
  upload_max_filesize = 128M
  post_max_size = 128M
  ```
- [ ] **PHP Version Selection** - Allow specifying PHP version during setup
- [ ] **PHP-FPM Optimization** - Configure PHP-FPM pools for better performance
- [ ] **OPcache Tuning** - Optimize OPcache settings for production

### Database Optimization
- [ ] **MariaDB Performance Tuning** - Enhanced MariaDB configuration:
  ```ini
  bind-address = 127.0.0.1
  skip-name-resolve = ON
  performance_schema = ON
  slow_query_log = 1
  long_query_time = 1
  slow_query_log_file = /var/log/mariadb/slow-query.log
  log_error = /var/log/mariadb/mariadb.log
  ```
- [ ] **InnoDB Optimization** - Configure buffer pool size based on available RAM

### Security Enhancements
- [ ] **Fail2Ban Integration** - Automatic ban for failed login attempts
- [ ] **ModSecurity WAF** - Web Application Firewall for Apache
- [ ] **SSH Hardening** - Disable root login, key-based authentication only
- [ ] **Automatic Security Updates** - Unattended upgrades for security patches
- [ ] **WordPress Security Headers** - Add security headers (X-Frame-Options, CSP, etc.)

### Performance Improvements
- [ ] **Redis Support** - Object caching for WordPress
- [ ] **Nginx Reverse Proxy with Microcache** - Nginx in front of Apache with microcaching for static assets
- [ ] **Apache MPM Worker** - Switch from prefork to worker/event MPM
- [ ] **HTTP/2 Support** - Enable HTTP/2 in Apache
- [ ] **Gzip/Brotli Compression** - Enable modern compression

### Developer Experience
- [ ] **Development Mode** - Debug mode with verbose logging
- [ ] **Staging Sync** - One-command sync from production to staging
- [ ] **WP-CLI Aliases** - Useful WP-CLI aliases and shortcuts

### Platform Support
- [ ] **Debian Support** - Add support for Debian-based systems
- [ ] **ARM64 Support** - Support for ARM-based servers

## 📝 Notes

- Features are listed in no particular order of priority
- Community feedback will help prioritize implementations
- Pull requests are welcome for any roadmap items

## 🤝 Contributing

If you'd like to work on any of these features, please:
1. Open an issue to discuss the implementation
2. Fork the repository
3. Submit a pull request

---

*Last updated: November 13, 2025*
