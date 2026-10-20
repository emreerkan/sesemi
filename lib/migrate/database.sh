#!/bin/bash

################################################################################
# Database Configuration and Import Functions for Migration
################################################################################

# Escapes a value for a single-quoted SQL string
sql_str() {
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\'/\'\'}"
}

# Quotes an identifier (database name) with backticks
sql_ident() {
    # shellcheck disable=SC2016
    printf '`%s`' "${1//\`/\`\`}"
}

# Prints the extra MariaDB user host needed for a wp-config DB_HOST value.
# localhost (socket) is always created; 127.0.0.1/::1 connect over TCP and
# need their own account. Anything else points to a remote server.
db_user_extra_host() {
    local db_host="${1:-localhost}"
    local host="${db_host%%:*}"
    if [[ "$db_host" == "::1" ]]; then
        host="::1"
    elif [[ "$db_host" == \[* ]]; then
        host="${db_host%%]*}"
        host="${host#[}"
    fi
    case "$host" in
        ""|localhost) ;;
        127.0.0.1|::1) echo "$host" ;;
        *) log_warning "DB_HOST '$db_host' is not local; the migrated site will still connect there" >&2 ;;
    esac
}

# Prints CREATE/GRANT statements for one site database
db_site_sql() {
    local name="$1" user="$2" pass="$3" db_host="$4"
    local hosts=("localhost") extra h
    extra=$(db_user_extra_host "$db_host")
    [[ -n "$extra" ]] && hosts+=("$extra")
    
    echo "CREATE DATABASE IF NOT EXISTS $(sql_ident "$name") CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    for h in "${hosts[@]}"; do
        echo "CREATE USER IF NOT EXISTS '$(sql_str "$user")'@'$h' IDENTIFIED BY '$(sql_str "$pass")';"
        echo "GRANT ALL PRIVILEGES ON $(sql_ident "$name").* TO '$(sql_str "$user")'@'$h';"
    done
}

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

$(db_site_sql "$PROD_DB_NAME" "$PROD_DB_USERNAME" "$PROD_DB_PASSWORD" "${PROD_DB_HOST:-localhost}")

$(db_site_sql "$STAGE_DB_NAME" "$STAGE_DB_USERNAME" "$STAGE_DB_PASSWORD" "${STAGE_DB_HOST:-localhost}")

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
    if [[ "$NO_DATA" == "1" ]]; then
        log_info "Database import skipped (--no-data): databases stay empty"
        update_step_status "import_databases" "completed"
        return 0
    fi
    
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
