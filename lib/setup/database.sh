#!/bin/bash

################################################################################
# MariaDB Configuration Functions
################################################################################

configure_database() {
    if check_step_completed "configure_database"; then
        log_info "Database already configured, skipping..."
        return 0
    fi
    
    print_step "Configuring MariaDB"
    update_step_status "configure_database" "in_progress"
    
    print_substep "Setting root password and creating databases..."
    
    local temp_sql=$(mktemp)
    cat > "$temp_sql" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PWD}';

CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';

CREATE DATABASE IF NOT EXISTS ${DB_NAME_STAGE} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER_STAGE}'@'localhost' IDENTIFIED BY '${DB_PASS_STAGE}';
GRANT ALL PRIVILEGES ON ${DB_NAME_STAGE}.* TO '${DB_USER_STAGE}'@'localhost';

FLUSH PRIVILEGES;
EOF
    
    if ! mysql -u root < "$temp_sql" &>> "$LOG_FILE"; then
        log_error "Failed to configure MariaDB"
        log_error "Check log file for details: $LOG_FILE"
        rm -f "$temp_sql"
        update_step_status "configure_database" "failed"
        exit 1
    fi
    rm -f "$temp_sql"
    
    log_success "Production database: $DB_NAME"
    log_success "Staging database created"
    
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
