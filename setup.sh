#!/bin/bash

################################################################################
# Ubuntu Server Setup Script for WordPress
# Main orchestrator - sources all library modules
# Version: 2.0.0
################################################################################

set -euo pipefail

################################################################################
# CONSTANTS
################################################################################

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STATE_BASE_DIR="/root/sesemi/setup"
readonly LOG_FILE_NAME="setup.log"
readonly STATE_FILE_NAME="state.json"
readonly CREDENTIALS_FILE_NAME="credentials.txt"
readonly CONFIG_FILE_NAME="config.env"

################################################################################
# GLOBAL VARIABLES
################################################################################

DOMAIN=""
STATE_DIR=""
LOG_FILE=""
STATE_FILE=""
CREDENTIALS_FILE=""
CONFIG_FILE=""
STEP_COUNTER=0
TOTAL_STEPS=12

# Domain-specific variables (loaded from state or generated)
USER=""
PASSWORD=""
DOMAIN_USER=""
DB_NAME=""
DB_USER=""
DB_PASS=""
DB_NAME_STAGE=""
DB_USER_STAGE=""
DB_PASS_STAGE=""
MARIADB_ROOT_PWD=""
WP_USER=""
WP_PASS=""
CERT_FILE=""
KEY_FILE=""
PHP_VER=""

################################################################################
# SOURCE LIBRARY MODULES
################################################################################

source "$SCRIPT_DIR/lib/common/colors.sh"
source "$SCRIPT_DIR/lib/common/logger.sh"
source "$SCRIPT_DIR/lib/setup/state.sh"
source "$SCRIPT_DIR/lib/setup/validators.sh"
source "$SCRIPT_DIR/lib/setup/certificates.sh"
source "$SCRIPT_DIR/lib/setup/system.sh"
source "$SCRIPT_DIR/lib/common/packages.sh"
source "$SCRIPT_DIR/lib/common/apache.sh"
source "$SCRIPT_DIR/lib/common/firewall.sh"
source "$SCRIPT_DIR/lib/setup/database.sh"
source "$SCRIPT_DIR/lib/common/ftp.sh"
source "$SCRIPT_DIR/lib/common/wpcli.sh"
source "$SCRIPT_DIR/lib/setup/wordpress.sh"
source "$SCRIPT_DIR/lib/setup/cleanup.sh"

################################################################################
# FINALIZATION
################################################################################

finalize_setup() {
    if check_step_completed "finalize"; then
        return 0
    fi
    
    print_step "Finalizing setup"
    update_step_status "finalize" "in_progress"
    
    cat > "$CREDENTIALS_FILE" <<EOF
════════════════════════════════════════════════════════════
  WordPress Server Setup - Credentials
════════════════════════════════════════════════════════════

Domain: $DOMAIN
Setup completed: $(date)

────────────────────────────────────────────────────────────
FTP ACCESS
────────────────────────────────────────────────────────────
Host: $DOMAIN
Username: $USER
Password: $PASSWORD
Port: 21

────────────────────────────────────────────────────────────
MARIADB (MySQL)
────────────────────────────────────────────────────────────
Root Password: $MARIADB_ROOT_PWD

Production Database:
  Database: $DB_NAME
  Username: $DB_USER
  Password: $DB_PASS

Staging Database:
  Database: $DB_NAME_STAGE
  Username: $DB_USER_STAGE
  Password: $DB_PASS_STAGE

────────────────────────────────────────────────────────────
WORDPRESS
────────────────────────────────────────────────────────────
Production Site: https://$DOMAIN/wp-admin/
Staging Site: https://stage.$DOMAIN/wp-admin/

Username: $WP_USER
Password: $WP_PASS

────────────────────────────────────────────────────────────
SSL CERTIFICATES
────────────────────────────────────────────────────────────
Certificate: /home/ssl/$CERT_FILE
Key: /home/ssl/$KEY_FILE

════════════════════════════════════════════════════════════
EOF
    
    chmod 600 "$CREDENTIALS_FILE"
    log_success "Credentials saved to $CREDENTIALS_FILE"
    
    update_step_status "finalize" "completed"
    update_state_status "completed"
}

################################################################################
# MAIN EXECUTION FLOW
################################################################################

show_usage() {
    cat <<EOF
Usage: $0 <domain> [options]

Arguments:
  domain                 Domain name to set up (e.g., example.com)

Options:
  --continue            Continue from last successful step
  --restart             Restart installation from beginning
  --cleanup             Remove previous installation
  -h, --help            Show this help message

Examples:
  $0 example.com
  $0 example.com --continue
  $0 example.com --restart
  $0 example.com --cleanup

EOF
}

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo -n "Enter domain name: "
        read DOMAIN
        DOMAIN=${DOMAIN/www./}
    else
        DOMAIN="${1/www./}"
        shift
    fi
    
    if ! validate_domain_format "$DOMAIN"; then
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continue)
                MODE="continue"
                shift
                ;;
            --restart)
                MODE="restart"
                shift
                ;;
            --cleanup)
                MODE="cleanup"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

detect_previous_installation() {
    init_state_directory
    
    if [[ -f "$STATE_FILE" ]]; then
        local status=$(grep -o '"status": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        
        if [[ "$status" == "completed" ]]; then
            echo ""
            log_warning "Previous installation detected for $DOMAIN (Status: completed)"
            echo ""
            echo "What would you like to do?"
            echo "  [1] Start over (remove and reinstall)"
            echo "  [2] Clean up (remove installation)"
            echo "  [3] Cancel"
            echo ""
            read -p "Choose an option (1-3): " choice
            
            case $choice in
                1)
                    MODE="restart"
                    ;;
                2)
                    MODE="cleanup"
                    ;;
                3)
                    log_info "Operation cancelled"
                    exit 0
                    ;;
                *)
                    log_error "Invalid option"
                    exit 1
                    ;;
            esac
        elif [[ "$status" == "in_progress" ]] || [[ "$status" == "failed" ]]; then
            echo ""
            log_warning "Previous installation detected for $DOMAIN (Status: $status)"
            echo ""
            echo "What would you like to do?"
            echo "  [1] Continue from last step"
            echo "  [2] Start over (remove and reinstall)"
            echo "  [3] Clean up (remove installation)"
            echo "  [4] Cancel"
            echo ""
            read -p "Choose an option (1-4): " choice
            
            case $choice in
                1)
                    MODE="continue"
                    ;;
                2)
                    MODE="restart"
                    ;;
                3)
                    MODE="cleanup"
                    ;;
                4)
                    log_info "Operation cancelled"
                    exit 0
                    ;;
                *)
                    log_error "Invalid option"
                    exit 1
                    ;;
            esac
        fi
    else
        MODE="fresh"
    fi
}

main() {
    local MODE="fresh"
    
    parse_arguments "$@"
    
    init_state_directory
    
    if [[ "$MODE" == "cleanup" ]]; then
        cleanup_installation
        exit 0
    fi
    
    if [[ "$MODE" == "fresh" ]] && [[ -z "${1:-}" ]]; then
        detect_previous_installation
    fi
    
    print_header "Ubuntu Server Setup for WordPress - v$SCRIPT_VERSION"
    echo -e "Domain: ${COLOR_BOLD}$DOMAIN${COLOR_RESET}"
    echo "Log file: $LOG_FILE"
    echo ""
    
    if [[ "$MODE" == "restart" ]]; then
        log_info "Restarting installation..."
        cleanup_installation
        init_state_directory
        MODE="fresh"
    fi
    
    if [[ "$MODE" == "continue" ]]; then
        log_info "Continuing from last step..."
        if load_config; then
            log_success "Configuration loaded"
            local next_step=$(get_next_pending_step)
            if [[ "$next_step" == "all_completed" ]]; then
                log_success "All steps already completed!"
                display_credentials
                exit 0
            fi
            log_info "Next step: $next_step"
        else
            log_error "Cannot continue: no previous configuration found"
            exit 1
        fi
    else
        create_initial_state
    fi
    
    validate_environment
    setup_certificates
    setup_system
    install_packages
    configure_apache
    configure_firewall
    configure_database
    configure_ftp
    install_wpcli
    install_wordpress_prod
    install_wordpress_stage
    finalize_setup
    
    echo ""
    print_header "Setup Completed Successfully!"
    
    echo ""
    echo -e "${COLOR_GREEN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║                     CREDENTIALS                           ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_BOLD}FTP Access:${COLOR_RESET}"
    echo "  Host:     $DOMAIN"
    echo "  User:     $USER"
    echo "  Password: $PASSWORD"
    echo ""
    
    echo -e "${COLOR_BOLD}MariaDB:${COLOR_RESET}"
    echo "  Root Password: $MARIADB_ROOT_PWD"
    echo ""
    
    echo -e "${COLOR_BOLD}WordPress:${COLOR_RESET}"
    echo "  Production: https://$DOMAIN/wp-admin/"
    echo "  Staging:    https://stage.$DOMAIN/wp-admin/"
    echo "  Username:   $WP_USER"
    echo "  Password:   $WP_PASS"
    echo ""
    
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} Full credentials saved to: ${COLOR_BOLD}$CREDENTIALS_FILE${COLOR_RESET}"
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} Installation log: ${COLOR_BOLD}$LOG_FILE${COLOR_RESET}"
    echo ""
}

trap 'log_error "Script failed at line $LINENO"' ERR

main "$@"
