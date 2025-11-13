#!/bin/bash

################################################################################
# SSL Certificate Setup Functions for Migration
################################################################################

setup_certificates() {
    if check_step_completed "setup_certificates"; then
        log_info "Certificates already set up, skipping..."
        return 0
    fi
    
    print_step "Setting up SSL certificates"
    update_step_status "setup_certificates" "in_progress"
    
    CERT_FILE="$DOMAIN-cf-origin.crt"
    KEY_FILE="$DOMAIN-cf-origin.key"
    
    if [[ ! -f "$MIGRATION_DIR/$CERT_FILE" ]] || [[ ! -f "$MIGRATION_DIR/$KEY_FILE" ]]; then
        log_error "Cloudflare origin certificates not found"
        log_error "Required files:"
        log_error "  - $MIGRATION_DIR/$CERT_FILE"
        log_error "  - $MIGRATION_DIR/$KEY_FILE"
        update_step_status "setup_certificates" "failed"
        exit 1
    fi
    
    print_substep "Found Cloudflare origin certificates"
    
    exit 1
    fi
    
    print_substep "Installing certificates..."
    mkdir -p /home/ssl
    
    if ! cp "$MIGRATION_DIR/$CERT_FILE" /home/ssl/ 2>> "$LOG_FILE"; then
        log_error "Failed to copy certificate file"
        update_step_status "setup_certificates" "failed"
        exit 1
    fi
    
    if ! cp "$MIGRATION_DIR/$KEY_FILE" /home/ssl/ 2>> "$LOG_FILE"; then
        log_error "Failed to copy key file"
        update_step_status "setup_certificates" "failed"
        exit 1
    fi
    
    log_success "Certificates installed to /home/ssl/"
    
    update_step_status "setup_certificates" "completed"
}
