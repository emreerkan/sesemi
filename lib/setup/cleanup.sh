#!/bin/bash

################################################################################
# Cleanup Functions
################################################################################

cleanup_installation() {
    print_header "Cleanup Mode - $DOMAIN"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "No previous installation found for $DOMAIN"
        exit 1
    fi
    
    load_config
    
    echo ""
    echo "This will remove the following:"
    echo ""
    echo "  • WordPress files (production and staging)"
    echo "  • Databases ($DB_NAME, $DB_NAME_STAGE)"
    echo "  • Database users ($DB_USER, $DB_USER_STAGE)"
    echo "  • Apache virtual hosts"
    echo "  • System user ($USER)"
    echo "  • SSL certificates"
    echo "  • State files"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
    
    log_info "Starting cleanup..."
    
    if [[ -d "/home/$DOMAIN" ]]; then
        print_substep "Removing WordPress production files..."
        rm -rf "/home/$DOMAIN"
        log_success "Production files removed"
    fi
    
    if [[ -d "/home/stage.$DOMAIN" ]]; then
        print_substep "Removing WordPress staging files..."
        rm -rf "/home/stage.$DOMAIN"
        log_success "Staging files removed"
    fi
    
    print_substep "Removing databases and users..."
    mysql -u root <<EOF &>> "$LOG_FILE"
DROP DATABASE IF EXISTS ${DB_NAME};
DROP DATABASE IF EXISTS ${DB_NAME_STAGE};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER_STAGE}'@'localhost';
FLUSH PRIVILEGES;
EOF
    log_success "Databases and users removed"
    
    print_substep "Removing Apache virtual hosts..."
    a2dissite $DOMAIN.conf &>> "$LOG_FILE" || true
    a2dissite stage.$DOMAIN.conf &>> "$LOG_FILE" || true
    a2dissite $DOMAIN-ssl.conf &>> "$LOG_FILE" || true
    a2dissite stage.$DOMAIN-ssl.conf &>> "$LOG_FILE" || true
    
    rm -f /etc/apache2/sites-available/$DOMAIN.conf
    rm -f /etc/apache2/sites-available/stage.$DOMAIN.conf
    rm -f /etc/apache2/sites-available/$DOMAIN-ssl.conf
    rm -f /etc/apache2/sites-available/stage.$DOMAIN-ssl.conf
    
    systemctl reload apache2 &>> "$LOG_FILE"
    log_success "Apache configurations removed"
    
    if id "$USER" &>/dev/null; then
        print_substep "Removing system user..."
        userdel -r "$USER" &>> "$LOG_FILE" || true
        log_success "System user removed"
    fi
    
    if [[ -f "/home/ssl/$CERT_FILE" ]]; then
        print_substep "Removing SSL certificates..."
        rm -f "/home/ssl/$CERT_FILE"
        rm -f "/home/ssl/$KEY_FILE"
        log_success "SSL certificates removed"
    fi
    
    print_substep "Removing state files..."
    rm -rf "$STATE_DIR"
    log_success "State files removed"
    
    echo ""
    log_success "Cleanup completed successfully"
    echo ""
}
