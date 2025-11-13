#!/bin/bash

################################################################################
# Validation Functions
################################################################################

validate_domain_format() {
    local domain="$1"
    
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi
    
    return 0
}

validate_environment() {
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
    local critical_ports=(80 443 21 3306)
    local passive_range_start=40000
    local passive_range_end=40100
    
    for port in "${critical_ports[@]}"; do
        if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=("$port")
        fi
    done
    
    local passive_in_use=0
    for port in $(seq $passive_range_start $passive_range_end); do
        if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
            ((passive_in_use++))
        fi
    done
    
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
