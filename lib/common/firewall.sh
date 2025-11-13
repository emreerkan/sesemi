#!/bin/bash

################################################################################
# Firewall Configuration Functions
################################################################################

configure_firewall() {
    if check_step_completed "configure_firewall"; then
        log_info "Firewall already configured, skipping..."
        return 0
    fi
    
    print_step "Configuring UFW firewall"
    update_step_status "configure_firewall" "in_progress"
    
    print_substep "Allowing OpenSSH..."
    ufw allow OpenSSH &>> "$LOG_FILE"
    
    print_substep "Allowing Apache Full (HTTP + HTTPS)..."
    ufw allow 'Apache Full' &>> "$LOG_FILE"
    
    print_substep "Allowing FTP (port 21)..."
    ufw allow 21/tcp &>> "$LOG_FILE"
    
    print_substep "Allowing FTP passive mode (ports 30000-31000)..."
    ufw allow 30000:31000/tcp &>> "$LOG_FILE"
    
    print_substep "Enabling firewall..."
    if ! ufw --force enable &>> "$LOG_FILE"; then
        log_error "Failed to enable firewall"
        update_step_status "configure_firewall" "failed"
        exit 1
    fi
    
    log_success "Firewall configured and enabled"
    
    update_step_status "configure_firewall" "completed"
}
