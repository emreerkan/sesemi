#!/bin/bash

################################################################################
# State Management Functions for Migration
################################################################################

init_state_directory() {
    STATE_DIR="$STATE_BASE_DIR/$DOMAIN"
    LOG_FILE="$STATE_DIR/$LOG_FILE_NAME"
    STATE_FILE="$STATE_DIR/$STATE_FILE_NAME"
    
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
    "validate_files": "pending",
    "validate_environment": "pending",
    "install_packages": "pending",
    "install_wpcli": "pending",
    "setup_system": "pending",
    "setup_certificates": "pending",
    "configure_apache": "pending",
    "configure_firewall": "pending",
    "configure_database": "pending",
    "import_databases": "pending",
    "configure_ftp": "pending",
    "extract_files": "pending",
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
    local steps=("validate_files" "validate_environment" "install_packages" "install_wpcli" "setup_system"
                 "setup_certificates" "configure_apache" "configure_firewall" "configure_database"
                 "import_databases" "configure_ftp" "extract_files" "finalize")
    
    for step in "${steps[@]}"; do
        if ! check_step_completed "$step"; then
            echo "$step"
            return 0
        fi
    done
    
    echo "all_completed"
}
