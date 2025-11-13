#!/bin/bash

################################################################################
# WP-CLI Installation Function (Shared)
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
