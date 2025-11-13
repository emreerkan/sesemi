#!/bin/bash

################################################################################
# State Management Functions
################################################################################

init_state_directory() {
    STATE_DIR="$STATE_BASE_DIR/$DOMAIN"
    LOG_FILE="$STATE_DIR/$LOG_FILE_NAME"
    STATE_FILE="$STATE_DIR/$STATE_FILE_NAME"
    CREDENTIALS_FILE="$STATE_DIR/$CREDENTIALS_FILE_NAME"
    CONFIG_FILE="$STATE_DIR/$CONFIG_FILE_NAME"
    
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR"
        touch "$LOG_FILE"
        log "State directory created: $STATE_DIR"
    fi
}

create_initial_state() {
    cat > "$STATE_FILE" <<EOF
{
  "domain": "$DOMAIN",
  "timestamp_start": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "timestamp_last_update": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "in_progress",
  "current_step": 0,
  "script_version": "$SCRIPT_VERSION",
  "steps": {
    "validate_environment": "pending",
    "setup_certificates": "pending",
    "setup_system": "pending",
    "install_packages": "pending",
    "configure_apache": "pending",
    "configure_firewall": "pending",
    "configure_database": "pending",
    "configure_ftp": "pending",
    "install_wpcli": "pending",
    "install_wordpress_prod": "pending",
    "install_wordpress_stage": "pending",
    "finalize": "pending"
  }
}
EOF
    log "Initial state file created"
}

update_step_status() {
    local step_name="$1"
    local status="$2"  # pending, in_progress, completed, failed
    
    if [[ -f "$STATE_FILE" ]]; then
        sed -i.bak "s/\"$step_name\": \"[^\"]*\"/\"$step_name\": \"$status\"/" "$STATE_FILE"
        sed -i.bak "s/\"timestamp_last_update\": \"[^\"]*\"/\"timestamp_last_update\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$STATE_FILE"
        rm -f "$STATE_FILE.bak"
        log "Step '$step_name' marked as '$status'"
    fi
}

update_state_status() {
    local status="$1"  # in_progress, completed, failed
    
    if [[ -f "$STATE_FILE" ]]; then
        sed -i.bak "s/\"status\": \"[^\"]*\"/\"status\": \"$status\"/" "$STATE_FILE"
        rm -f "$STATE_FILE.bak"
        log "Overall status updated to '$status'"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
# Generated configuration for $DOMAIN
DOMAIN="$DOMAIN"
USER="$USER"
PASSWORD="$PASSWORD"
DOMAIN_USER="$DOMAIN_USER"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
DB_NAME_STAGE="$DB_NAME_STAGE"
DB_USER_STAGE="$DB_USER_STAGE"
DB_PASS_STAGE="$DB_PASS_STAGE"
MARIADB_ROOT_PWD="$MARIADB_ROOT_PWD"
WP_USER="$WP_USER"
WP_PASS="$WP_PASS"
CERT_FILE="$CERT_FILE"
KEY_FILE="$KEY_FILE"
PHP_VER="$PHP_VER"
EOF
    chmod 600 "$CONFIG_FILE"
    log "Configuration saved to $CONFIG_FILE"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log "Configuration loaded from $CONFIG_FILE"
        return 0
    else
        log_warning "No configuration file found"
        return 1
    fi
}

check_step_completed() {
    local step_name="$1"
    if [[ -f "$STATE_FILE" ]]; then
        if grep -q "\"$step_name\": \"completed\"" "$STATE_FILE"; then
            return 0
        fi
    fi
    return 1
}

get_next_pending_step() {
    local steps=("validate_environment" "setup_certificates" "setup_system" "install_packages" 
                 "configure_apache" "configure_firewall" "configure_database" "configure_ftp" 
                 "install_wpcli" "install_wordpress_prod" "install_wordpress_stage" "finalize")
    
    for step in "${steps[@]}"; do
        if ! check_step_completed "$step"; then
            echo "$step"
            return 0
        fi
    done
    
    echo "all_completed"
}
