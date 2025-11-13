#!/bin/bash

################################################################################
# System Setup Functions
################################################################################

setup_system() {
    if check_step_completed "setup_system"; then
        log_info "System setup already completed, skipping..."
        return 0
    fi
    
    print_step "Setting up system (users, folders, aliases)"
    update_step_status "setup_system" "in_progress"
    
    print_substep "Configuring bash aliases..."
    if ! grep -q 'alias ..="cd .."' ~/.bash_aliases 2>/dev/null; then
        echo 'alias ..="cd .."' >> ~/.bash_aliases
        echo 'alias ...="cd ../.."' >> ~/.bash_aliases
        echo 'alias l="ls -lha"' >> ~/.bash_aliases
        log_success "Bash aliases configured"
    else
        log_info "Bash aliases already configured"
    fi
    
    if [[ -z "$USER" ]]; then
        USER=$(cut -d '.' -f 1 <<< "$DOMAIN")
        PASSWORD=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
        DOMAIN_USER=${DOMAIN//./_}
        DB_NAME="${DOMAIN_USER}_core"
        DB_USER="${DOMAIN_USER}_user"
        DB_PASS=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
        DB_NAME_STAGE="${DOMAIN_USER}_stage"
        DB_USER_STAGE="${DOMAIN_USER}_stage"
        DB_PASS_STAGE=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
        MARIADB_ROOT_PWD=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
        WP_USER=$(openssl rand -base64 8 | tr -d '+/=' | head -c8)
        WP_PASS=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
        save_config
    fi
    
    print_substep "Creating directories..."
    mkdir -p "/home/$DOMAIN"
    mkdir -p "/home/stage.$DOMAIN"
    log_success "Directories created"
    
    print_substep "Creating system user: $USER..."
    
    if ! grep -q "/usr/sbin/nologin" /etc/shells; then
        echo "/usr/sbin/nologin" >> /etc/shells
    fi
    
    if id "$USER" &>/dev/null; then
        log_warning "User $USER already exists"
    else
        ENCYPASSWD=$(perl -e 'print crypt($ARGV[0], "password")' "$PASSWORD")
        if ! useradd -m -g www-data -p "$ENCYPASSWD" -d "/home/$DOMAIN" "$USER" &>> "$LOG_FILE"; then
            log_error "Failed to create user"
            update_step_status "setup_system" "failed"
            exit 1
        fi
        
        if ! usermod "$USER" -s /usr/sbin/nologin &>> "$LOG_FILE"; then
            log_error "Failed to set user shell"
            update_step_status "setup_system" "failed"
            exit 1
        fi
        
        log_success "User $USER created"
    fi
    
    update_step_status "setup_system" "completed"
}
