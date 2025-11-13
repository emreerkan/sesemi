#!/bin/bash

################################################################################
# SSL Certificate Setup Functions
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
    
    if [[ -f "./$CERT_FILE" ]] && [[ -f "./$KEY_FILE" ]]; then
        print_substep "Found Cloudflare origin certificates"
        log_success "Using provided Cloudflare certificates"
    else
        print_substep "Generating self-signed certificate..."
        CERT_FILE="$DOMAIN-self-signed.crt"
        KEY_FILE="$DOMAIN-self-signed.key"
        
        cat <<EOF > /tmp/$DOMAIN.cnf
[req]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = req_ext
prompt             = no

[req_distinguished_name]
C  = CA
ST = Vancouver
L  = Yaletown
O  = $DOMAIN
CN = $DOMAIN

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
EOF
        
        if ! openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout "./$KEY_FILE" \
            -out "./$CERT_FILE" \
            -config /tmp/$DOMAIN.cnf &>> "$LOG_FILE"; then
            log_error "Failed to generate self-signed certificate"
            update_step_status "setup_certificates" "failed"
            exit 1
        fi
        
        rm -f /tmp/$DOMAIN.cnf
        log_success "Self-signed certificate generated"
    fi
    
    print_substep "Installing certificates..."
    mkdir -p /home/ssl
    
    if ! mv "./$CERT_FILE" /home/ssl/ 2>> "$LOG_FILE"; then
        log_error "Failed to move certificate file"
        update_step_status "setup_certificates" "failed"
        exit 1
    fi
    
    if ! mv "./$KEY_FILE" /home/ssl/ 2>> "$LOG_FILE"; then
        log_error "Failed to move key file"
        update_step_status "setup_certificates" "failed"
        exit 1
    fi
    
    log_success "Certificates installed to /home/ssl/"
    
    save_config
    update_step_status "setup_certificates" "completed"
}
