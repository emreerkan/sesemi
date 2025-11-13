#!/bin/bash

################################################################################
# File Extraction and Permissions Functions for Migration
################################################################################

extract_files() {
    if check_step_completed "extract_files"; then
        log_info "Files already extracted, skipping..."
        return 0
    fi
    
    print_step "Extracting WordPress files"
    update_step_status "extract_files" "in_progress"
    
    USER=$(cut -d '.' -f 1 <<< "$DOMAIN")
    
    print_substep "Extracting production files ($DOMAIN.zip)..."
    if [[ ! -f "$MIGRATION_DIR/$DOMAIN.zip" ]]; then
        log_error "Production zip file not found: $MIGRATION_DIR/$DOMAIN.zip"
        update_step_status "extract_files" "failed"
        exit 1
    fi
    
    cd "/home/$DOMAIN" || exit 1
    
    if ! unzip -q "$MIGRATION_DIR/$DOMAIN.zip" 2>> "$LOG_FILE"; then
        log_error "Failed to extract production files"
        update_step_status "extract_files" "failed"
        exit 1
    fi
    log_success "Production files extracted"
    
    print_substep "Configuring production wp-config.php..."
    if ! grep -q "FS_METHOD" wp-config.php; then
        sed -i "/\/\* Add any custom values between this line and the \"stop editing\" line. \*\//a \\
define( 'FS_METHOD', 'direct' );" wp-config.php
        log_success "Added FS_METHOD to production wp-config.php"
    else
        log_info "FS_METHOD already exists in production wp-config.php"
    fi
    
    print_substep "Setting ownership and permissions for production..."
    chown -R "$USER:www-data" . &>> "$LOG_FILE"
    find . -type d -exec chmod 775 {} \; &>> "$LOG_FILE"
    find . -type f -exec chmod 664 {} \; &>> "$LOG_FILE"
    chmod g+s "/home/$DOMAIN" &>> "$LOG_FILE"
    
    if command -v setfacl &> /dev/null; then
        setfacl -d -m g::rwx "/home/$DOMAIN" &>> "$LOG_FILE"
    fi
    
    log_success "Production file permissions set"
    
    print_substep "Extracting staging files (stage.$DOMAIN.zip)..."
    if [[ ! -f "$MIGRATION_DIR/stage.$DOMAIN.zip" ]]; then
        log_error "Staging zip file not found: $MIGRATION_DIR/stage.$DOMAIN.zip"
        update_step_status "extract_files" "failed"
        exit 1
    fi
    
    cd "/home/stage.$DOMAIN" || exit 1
    
    if ! unzip -q "$MIGRATION_DIR/stage.$DOMAIN.zip" 2>> "$LOG_FILE"; then
        log_error "Failed to extract staging files"
        update_step_status "extract_files" "failed"
        exit 1
    fi
    log_success "Staging files extracted"
    
    print_substep "Configuring staging wp-config.php..."
    if ! grep -q "FS_METHOD" wp-config.php; then
        sed -i "/\/\* Add any custom values between this line and the \"stop editing\" line. \*\//a \\
define( 'FS_METHOD', 'direct' );" wp-config.php
        log_success "Added FS_METHOD to staging wp-config.php"
    else
        log_info "FS_METHOD already exists in staging wp-config.php"
    fi
    
    print_substep "Setting ownership and permissions for staging..."
    chown -R "$USER:www-data" . &>> "$LOG_FILE"
    find . -type d -exec chmod 775 {} \; &>> "$LOG_FILE"
    find . -type f -exec chmod 664 {} \; &>> "$LOG_FILE"
    
    log_success "Staging file permissions set"
    
    update_step_status "extract_files" "completed"
}
