#!/bin/bash

################################################################################
# Validation Functions for Migration
################################################################################

validate_domain_format() {
    local domain="$1"
    
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi
    
    return 0
}

validate_required_files() {
    print_step "Validating required files"
    update_step_status "validate_files" "in_progress"
    
    local missing_files=()
    local required_files=(
        "$DOMAIN-cf-origin.crt"
        "$DOMAIN-cf-origin.key"
        "config.env"
        "$DOMAIN.zip"
        "stage.$DOMAIN.zip"
    )
    
    if [[ "$NO_DATA" != "1" ]]; then
        required_files+=("$DOMAIN.sql" "stage.$DOMAIN.sql")
    fi
    
    print_substep "Checking for required files..."
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$MIGRATION_DIR/$file" ]]; then
            missing_files+=("$file")
            log_error "Missing required file: $file"
        else
            log_info "Found: $file"
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo ""
        log_error "Missing ${#missing_files[@]} required file(s):"
        for file in "${missing_files[@]}"; do
            echo "  ✗ $file"
        done
        echo ""
        log_error "Please ensure all required files are in: $MIGRATION_DIR"
        update_step_status "validate_files" "failed"
        exit 1
    fi
    
    log_success "All required files present"
    
    print_substep "Validating config.env..."
    
    source "$MIGRATION_DIR/config.env"
    
    local missing_vars=()
    local required_vars=(
        "PROD_DB_NAME"
        "PROD_DB_USERNAME"
        "PROD_DB_PASSWORD"
        "STAGE_DB_NAME"
        "STAGE_DB_USERNAME"
        "STAGE_DB_PASSWORD"
    )
    
    if [[ "$WITH_FTP" == "1" ]]; then
        required_vars+=("FTP_USERNAME" "FTP_PASSWORD")
    fi
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
            log_error "Missing variable in config.env: $var"
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo ""
        log_error "Missing ${#missing_vars[@]} required variable(s) in config.env:"
        for var in "${missing_vars[@]}"; do
            echo "  ✗ $var"
        done
        echo ""
        update_step_status "validate_files" "failed"
        exit 1
    fi
    
    log_success "config.env contains all required variables"
    
    update_step_status "validate_files" "completed"
}

validate_environment() {
    # On --continue our own Apache/MariaDB hold 80/443/3306; don't re-check
    if check_step_completed "validate_environment"; then
        log_info "Environment already validated, skipping..."
        return 0
    fi
    
    print_step "Validating environment"
    update_step_status "validate_environment" "in_progress"
    
    print_substep "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        update_step_status "validate_environment" "failed"
        exit 1
    fi
    log_success "Running as root"
    
    print_substep "Checking operating system..."
    if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu"
        update_step_status "validate_environment" "failed"
        exit 1
    fi
    local ubuntu_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    log_success "Running on Ubuntu $ubuntu_version"
    
    print_substep "Checking disk space..."
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 5242880 ]]; then
        log_warning "Less than 5GB free disk space available"
    else
        log_success "Sufficient disk space available"
    fi
    
    print_substep "Checking port availability..."
    local ports_in_use=()
    local critical_ports=(80 443 3306)
    # Must match pasv_min_port/pasv_max_port in lib/common/ftp.sh
    local passive_range_start=30000
    local passive_range_end=31000
    
    if [[ "${WITH_FTP:-0}" == "1" ]]; then
        critical_ports+=(21)
    fi
    
    for port in "${critical_ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=("$port")
        fi
    done
    
    local passive_in_use=0
    if [[ "${WITH_FTP:-0}" == "1" ]]; then
        passive_in_use=$(ss -Htuln 2>/dev/null | awk -v s="$passive_range_start" -v e="$passive_range_end" \
            '{ n = split($5, a, ":"); p = a[n] + 0; if (p >= s && p <= e) c++ } END { print c + 0 }')
    fi
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log_error "Critical ports already in use: ${ports_in_use[*]}"
        log_error "Please stop services using these ports before continuing"
        update_step_status "validate_environment" "failed"
        exit 1
    fi
    
    if [[ $passive_in_use -gt 10 ]]; then
        log_error "Too many passive FTP ports ($passive_range_start-$passive_range_end) are in use: $passive_in_use ports"
        log_error "Please ensure passive FTP port range is available"
        update_step_status "validate_environment" "failed"
        exit 1
    fi
    
    log_success "Required ports are available"
    
    update_step_status "validate_environment" "completed"
}
