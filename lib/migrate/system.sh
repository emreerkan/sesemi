#!/bin/bash

########################################
# System Setup Functions for Migration #
########################################

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
    
    source "$MIGRATION_DIR/config.env"
    
    USER=$(cut -d '.' -f 1 <<< "$DOMAIN")
    PASSWORD="$FTP_PASSWORD"
    
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
        
        log_success "User $USER created with password from config.env"
    fi
    
    update_step_status "setup_system" "completed"
}
