#!/bin/bash

################################################################################
# WordPress Installation Functions
################################################################################

install_wpcli() {
    if check_step_completed "install_wpcli"; then
        log_info "WP-CLI already installed, skipping..."
        return 0
    fi
    
    print_step "Installing WP-CLI"
    update_step_status "install_wpcli" "in_progress"
    
    print_substep "Downloading WP-CLI..."
    if ! curl -sS https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /tmp/wp-cli.phar &>> "$LOG_FILE"; then
        log_error "Failed to download WP-CLI"
        update_step_status "install_wpcli" "failed"
        exit 1
    fi
    
    chmod +x /tmp/wp-cli.phar
    
    print_substep "Installing WP-CLI to /usr/local/bin/wp..."
    if ! mv /tmp/wp-cli.phar /usr/local/bin/wp &>> "$LOG_FILE"; then
        log_error "Failed to install WP-CLI"
        update_step_status "install_wpcli" "failed"
        exit 1
    fi
    
    if ! grep -q 'alias wp="wp --allow-root"' ~/.bash_aliases 2>/dev/null; then
        echo 'alias wp="wp --allow-root"' >> ~/.bash_aliases
    fi
    
    log_success "WP-CLI installed successfully"
    
    update_step_status "install_wpcli" "completed"
}

install_wordpress_prod() {
    if check_step_completed "install_wordpress_prod"; then
        log_info "WordPress production already installed, skipping..."
        return 0
    fi
    
    print_step "Installing WordPress (Production)"
    update_step_status "install_wordpress_prod" "in_progress"
    
    cd "/home/$DOMAIN" || exit 1
    
    print_substep "Downloading WordPress core..."
    if ! wp --allow-root core download &>> "$LOG_FILE"; then
        log_error "Failed to download WordPress"
        update_step_status "install_wordpress_prod" "failed"
        exit 1
    fi
    
    print_substep "Creating wp-config.php..."
    if ! wp --allow-root config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" &>> "$LOG_FILE"; then
        log_error "Failed to create wp-config.php"
        update_step_status "install_wordpress_prod" "failed"
        exit 1
    fi
    
    print_substep "Running WordPress installation..."
    if ! wp --allow-root core install --url="https://$DOMAIN" --title="$DOMAIN" \
        --admin_user="$WP_USER" --admin_password="$WP_PASS" --admin_email="dev@ada.agency" &>> "$LOG_FILE"; then
        log_error "Failed to install WordPress"
        update_step_status "install_wordpress_prod" "failed"
        exit 1
    fi
    
    print_substep "Configuring wp-config.php..."
    sed -i "/\/\* Add any custom values between this line and the \"stop editing\" line. \*\//a \\
define( 'FS_METHOD', 'direct' );" wp-config.php
    log_success "Added FS_METHOD to wp-config.php"
    
    print_substep "Setting file permissions..."
    chown -R "$USER:www-data" . &>> "$LOG_FILE"
    find . -type d -exec chmod 775 {} \; &>> "$LOG_FILE"
    find . -type f -exec chmod 664 {} \; &>> "$LOG_FILE"
    chmod g+s "/home/$DOMAIN" &>> "$LOG_FILE"
    setfacl -d -m g::rwx "/home/$DOMAIN" &>> "$LOG_FILE"
    
    log_success "WordPress production installed at https://$DOMAIN"
    
    update_step_status "install_wordpress_prod" "completed"
}

install_wordpress_stage() {
    if check_step_completed "install_wordpress_stage"; then
        log_info "WordPress staging already installed, skipping..."
        return 0
    fi
    
    print_step "Installing WordPress (Staging)"
    update_step_status "install_wordpress_stage" "in_progress"
    
    cd "/home/stage.$DOMAIN" || exit 1
    
    print_substep "Downloading WordPress core..."
    if ! wp --allow-root core download &>> "$LOG_FILE"; then
        log_error "Failed to download WordPress"
        update_step_status "install_wordpress_stage" "failed"
        exit 1
    fi
    
    print_substep "Creating wp-config.php..."
    if ! wp --allow-root config create --dbname="$DB_NAME_STAGE" --dbuser="$DB_USER_STAGE" --dbpass="$DB_PASS_STAGE" &>> "$LOG_FILE"; then
        log_error "Failed to create wp-config.php"
        update_step_status "install_wordpress_stage" "failed"
        exit 1
    fi
    
    print_substep "Running WordPress installation..."
    if ! wp --allow-root core install --url="https://stage.$DOMAIN" --title="$DOMAIN (Staging)" \
        --admin_user="$WP_USER" --admin_password="$WP_PASS" --admin_email="dev@ada.agency" &>> "$LOG_FILE"; then
        log_error "Failed to install WordPress"
        update_step_status "install_wordpress_stage" "failed"
        exit 1
    fi
    
    print_substep "Configuring wp-config.php..."
    sed -i "/\/\* Add any custom values between this line and the \"stop editing\" line. \*\//a \\
define( 'FS_METHOD', 'direct' );" wp-config.php
    log_success "Added FS_METHOD to wp-config.php"
    
    print_substep "Setting file permissions..."
    chown -R "$USER:www-data" . &>> "$LOG_FILE"
    find . -type d -exec chmod 775 {} \; &>> "$LOG_FILE"
    find . -type f -exec chmod 664 {} \; &>> "$LOG_FILE"
    
    log_success "WordPress staging installed at https://stage.$DOMAIN"
    
    update_step_status "install_wordpress_stage" "completed"
}
