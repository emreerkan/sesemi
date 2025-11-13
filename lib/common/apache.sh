#!/bin/bash

################################################################################
# Apache Configuration Functions
################################################################################

configure_apache() {
    if check_step_completed "configure_apache"; then
        log_info "Apache already configured, skipping..."
        return 0
    fi
    
    print_step "Configuring Apache"
    update_step_status "configure_apache" "in_progress"
    
    print_substep "Creating virtual host configuration for $DOMAIN..."
    cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>
EOF
    
    cat <<EOF > /etc/apache2/sites-available/stage.$DOMAIN.conf
<VirtualHost *:80>
    ServerName stage.$DOMAIN
    Redirect permanent / https://stage.$DOMAIN/
</VirtualHost>
EOF
    
    cat <<EOF > /etc/apache2/sites-available/$DOMAIN-ssl.conf
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /home/$DOMAIN
    SSLEngine on
    SSLCertificateFile /home/ssl/$CERT_FILE
    SSLCertificateKeyFile /home/ssl/$KEY_FILE
    <Directory /home/$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
</IfModule>
EOF
    
    cat <<EOF > /etc/apache2/sites-available/stage.$DOMAIN-ssl.conf
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName stage.$DOMAIN
    DocumentRoot /home/stage.$DOMAIN
    SSLEngine on
    SSLCertificateFile /home/ssl/$CERT_FILE
    SSLCertificateKeyFile /home/ssl/$KEY_FILE
    <Directory /home/stage.$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/stage.$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/stage.$DOMAIN-access.log combined
</VirtualHost>
</IfModule>
EOF
    
    log_success "Virtual host configurations created"
    
    print_substep "Enabling virtual hosts..."
    a2ensite $DOMAIN.conf &>> "$LOG_FILE"
    a2ensite stage.$DOMAIN.conf &>> "$LOG_FILE"
    a2ensite $DOMAIN-ssl.conf &>> "$LOG_FILE"
    a2ensite stage.$DOMAIN-ssl.conf &>> "$LOG_FILE"
    log_success "Virtual hosts enabled"
    
    print_substep "Configuring PHP settings..."
    if [[ -z "$PHP_VER" ]]; then
        PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
        save_config
    fi
    
    PHP_INI="/etc/php/$PHP_VER/apache2/php.ini"
    
    if [[ -f "$PHP_INI" ]]; then
        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 128M/' "$PHP_INI"
        sed -i 's/^post_max_size = .*/post_max_size = 128M/' "$PHP_INI"
        sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
        sed -i 's/^;*max_input_vars = .*/max_input_vars = 10000/' "$PHP_INI"
        log_success "PHP settings configured"
    else
        log_warning "PHP configuration file not found: $PHP_INI"
    fi
    
    print_substep "Restarting Apache..."
    if ! systemctl restart apache2 &>> "$LOG_FILE"; then
        log_error "Failed to restart Apache"
        update_step_status "configure_apache" "failed"
        exit 1
    fi
    log_success "Apache restarted successfully"
    
    update_step_status "configure_apache" "completed"
}
