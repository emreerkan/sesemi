#!/bin/bash

################################################################################
# Database Configuration and Import Functions for Migration
################################################################################

configure_database() {
    if check_step_completed "configure_database"; then
        log_info "Database already configured, skipping..."
        return 0
    fi
    
    print_step "Configuring MariaDB"
    update_step_status "configure_database" "in_progress"
    
    log "Loading credentials from config.env"
    source "$MIGRATION_DIR/config.env"
    log "Credentials loaded: PROD_DB_NAME=$PROD_DB_NAME, STAGE_DB_NAME=$STAGE_DB_NAME"
    
    log "Generating MariaDB root password"
    MARIADB_ROOT_PWD=$(openssl rand -base64 16 | tr -d '+/=' | head -c16)
    log "Root password generated (length: ${#MARIADB_ROOT_PWD})"
    
    print_substep "Setting root password and creating databases..."
    log "Creating temporary SQL file"
    
    local temp_sql=$(mktemp)
    log "Temp SQL file created: $temp_sql"
    
    cat > "$temp_sql" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PWD}';

CREATE DATABASE IF NOT EXISTS ${PROD_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${PROD_DB_USERNAME}'@'localhost' IDENTIFIED BY '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${PROD_DB_NAME}.* TO '${PROD_DB_USERNAME}'@'localhost';

CREATE DATABASE IF NOT EXISTS ${STAGE_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${STAGE_DB_USERNAME}'@'localhost' IDENTIFIED BY '${STAGE_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${STAGE_DB_NAME}.* TO '${STAGE_DB_USERNAME}'@'localhost';

FLUSH PRIVILEGES;
EOF
    
    log "SQL file contents written, executing MySQL commands"
    if ! mysql -u root < "$temp_sql" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to configure MariaDB"
        log_error "Check log file for details: $LOG_FILE"
        log "Displaying temp SQL file contents:"
        cat "$temp_sql" >> "$LOG_FILE"
        rm -f "$temp_sql"
        update_step_status "configure_database" "failed"
        exit 1
    fi
    log "MySQL commands executed successfully"
    rm -f "$temp_sql"
    
    log_success "Production database: $PROD_DB_NAME"
    log_success "Staging database: $STAGE_DB_NAME"
    
    print_substep "Creating MySQL credentials file..."
    cat > ~/.my.cnf <<EOF
[client]
user=root
password=$MARIADB_ROOT_PWD
EOF
    chmod 600 ~/.my.cnf
    log_success "MySQL credentials file created"
    
    update_step_status "configure_database" "completed"
}

import_databases() {
    if check_step_completed "import_databases"; then
        log_info "Databases already imported, skipping..."
        return 0
    fi
    
    print_step "Importing database dumps"
    update_step_status "import_databases" "in_progress"
    
    source "$MIGRATION_DIR/config.env"
    
    print_substep "Importing production database ($DOMAIN.sql)..."
    if [[ ! -f "$MIGRATION_DIR/$DOMAIN.sql" ]]; then
        log_error "Production database dump not found: $MIGRATION_DIR/$DOMAIN.sql"
        update_step_status "import_databases" "failed"
        exit 1
    fi
    
    if ! mysql -u root "$PROD_DB_NAME" < "$MIGRATION_DIR/$DOMAIN.sql" 2>> "$LOG_FILE"; then
        log_error "Failed to import production database"
        update_step_status "import_databases" "failed"
        exit 1
    fi
    log_success "Production database imported"
    
    print_substep "Importing staging database (stage.$DOMAIN.sql)..."
    if [[ ! -f "$MIGRATION_DIR/stage.$DOMAIN.sql" ]]; then
        log_error "Staging database dump not found: $MIGRATION_DIR/stage.$DOMAIN.sql"
        update_step_status "import_databases" "failed"
        exit 1
    fi
    
    if ! mysql -u root "$STAGE_DB_NAME" < "$MIGRATION_DIR/stage.$DOMAIN.sql" 2>> "$LOG_FILE"; then
        log_error "Failed to import staging database"
        update_step_status "import_databases" "failed"
        exit 1
    fi
    log_success "Staging database imported successfully"
    
    update_step_status "import_databases" "completed"
}
