#!/bin/bash

################################################################################
# Package Installation Functions
################################################################################

install_packages() {
    if check_step_completed "install_packages"; then
        log_info "Packages already installed, skipping..."
        return 0
    fi
    
    print_step "Installing packages"
    update_step_status "install_packages" "in_progress"
    
    print_substep "Updating package lists..."
    if ! apt update &>> "$LOG_FILE"; then
        log_error "Failed to update package lists"
        update_step_status "install_packages" "failed"
        exit 1
    fi
    log_success "Package lists updated"
    
    print_substep "Installing system utilities..."
    if ! apt install -y byobu lnav ncdu htop btop tar zip unzip wget rsync nano curl acl &>> "$LOG_FILE"; then
        log_error "Failed to install system utilities"
        update_step_status "install_packages" "failed"
        exit 1
    fi
    log_success "System utilities installed"
    
    print_substep "Installing croc file transfer tool..."
    if ! curl -s https://getcroc.schollz.com | bash &>> "$LOG_FILE"; then
        log_warning "Failed to install croc (non-critical)"
    else
        log_success "Croc installed"
    fi
    
    print_substep "Installing Apache, MariaDB, PHP, and related packages..."
    print_substep "This may take several minutes..."
    
    if ! apt install -y apache2 mariadb-server libapache2-mod-php ufw vsftpd \
        php php-{opcache,imagick,pear,cgi,curl,gd,mysqlnd,bcmath,json,intl,zip,imap,mbstring} &>> "$LOG_FILE"; then
        log_error "Failed to install web server packages"
        update_step_status "install_packages" "failed"
        exit 1
    fi
    log_success "Web server packages installed"
    
    log_success "All packages installed"
    
    print_substep "Removing default Apache configurations..."
    rm -f /etc/apache2/sites-available/default-ssl.conf \
          /etc/apache2/sites-available/000-default.conf \
          /etc/apache2/sites-enabled/000-default.conf 2>> "$LOG_FILE"
    
    print_substep "Enabling and starting services..."
    systemctl enable apache2 &>> "$LOG_FILE"
    systemctl enable mariadb &>> "$LOG_FILE"
    systemctl start apache2 &>> "$LOG_FILE"
    systemctl start mariadb &>> "$LOG_FILE"
    
    print_substep "Enabling Apache modules..."
    a2enmod ssl &>> "$LOG_FILE"
    a2enmod rewrite &>> "$LOG_FILE"
    
    PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
    a2enmod php${PHP_VER} &>> "$LOG_FILE" || true
    
    log_success "Services enabled and started"
    
    # Save config (only for setup script, migration loads from config.env)
    if type save_config &>/dev/null; then
        save_config
    fi
    
    update_step_status "install_packages" "completed"
}
