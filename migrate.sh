#!/bin/bash

################################################################################
# Ubuntu Server Migration Script for WordPress
# Migrates WordPress site from Server A to Server B
# Version: 1.0.0
################################################################################

set -euo pipefail

################################################################################
# CONSTANTS
################################################################################

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STATE_BASE_DIR="/root/sesemi/migration"
readonly LOG_FILE_NAME="migration.log"
readonly STATE_FILE_NAME="state.json"

################################################################################
# GLOBAL VARIABLES
################################################################################

DOMAIN=""
MIGRATION_DIR=""
STATE_DIR=""
LOG_FILE=""
STATE_FILE=""
STEP_COUNTER=0
TOTAL_STEPS=13

# Configuration variables (loaded from config.env)
PROD_DB_NAME=""
PROD_DB_USERNAME=""
PROD_DB_PASSWORD=""
STAGE_DB_NAME=""
STAGE_DB_USERNAME=""
STAGE_DB_PASSWORD=""
FTP_USERNAME=""
FTP_PASSWORD=""
USER=""
PASSWORD=""
MARIADB_ROOT_PWD=""
CERT_FILE=""
KEY_FILE=""
PHP_VER=""

################################################################################
# SOURCE LIBRARY MODULES
################################################################################

source "$SCRIPT_DIR/lib/common/colors.sh"
source "$SCRIPT_DIR/lib/common/logger.sh"
source "$SCRIPT_DIR/lib/migrate/state.sh"
source "$SCRIPT_DIR/lib/migrate/validators.sh"
source "$SCRIPT_DIR/lib/common/packages.sh"
source "$SCRIPT_DIR/lib/migrate/system.sh"
source "$SCRIPT_DIR/lib/migrate/certificates.sh"
source "$SCRIPT_DIR/lib/common/apache.sh"
source "$SCRIPT_DIR/lib/common/firewall.sh"
source "$SCRIPT_DIR/lib/migrate/database.sh"
source "$SCRIPT_DIR/lib/common/ftp.sh"
source "$SCRIPT_DIR/lib/migrate/files.sh"
source "$SCRIPT_DIR/lib/common/wpcli.sh"

################################################################################
# FINALIZATION
################################################################################

finalize_migration() {
    if check_step_completed "finalize"; then
        return 0
    fi
    
    print_step "Finalizing migration"
    update_step_status "finalize" "in_progress"

    source "$MIGRATION_DIR/config.env"

    cat > "$STATE_DIR/migration_summary.txt" <<EOF
════════════════════════════════════════════════════════════
  WordPress Server Migration - Summary
════════════════════════════════════════════════════════════

Domain: $DOMAIN
Migration completed: $(date)

────────────────────────────────────────────────────────────
MIGRATION DETAILS
────────────────────────────────────────────────────────────
Source: Previous server
Destination: This server ($(hostname))

────────────────────────────────────────────────────────────
FTP ACCESS
────────────────────────────────────────────────────────────
Host: $DOMAIN
Username: $FTP_USERNAME
Password: $FTP_PASSWORD
Port: 21

────────────────────────────────────────────────────────────
MARIADB (MySQL)
────────────────────────────────────────────────────────────
Root Password: $MARIADB_ROOT_PWD

Production Database:
  Database: $PROD_DB_NAME
  Username: $PROD_DB_USERNAME
  Password: $PROD_DB_PASSWORD

Staging Database:
  Database: $STAGE_DB_NAME
  Username: $STAGE_DB_USERNAME
  Password: $STAGE_DB_PASSWORD

────────────────────────────────────────────────────────────
WORDPRESS SITES
────────────────────────────────────────────────────────────
Production: https://$DOMAIN/wp-admin/
Staging: https://stage.$DOMAIN/wp-admin/

Note: Use the WordPress admin credentials from your previous server.
Database credentials are from the config.env file.

────────────────────────────────────────────────────────────
SSL CERTIFICATES
────────────────────────────────────────────────────────────
Certificate: /home/ssl/$CERT_FILE
Key: /home/ssl/$KEY_FILE

────────────────────────────────────────────────────────────
NEXT STEPS
────────────────────────────────────────────────────────────
1. Update DNS records to point to this server
2. Test both production and staging sites
3. Verify database connections
4. Test FTP access
5. Monitor Apache logs for any issues

════════════════════════════════════════════════════════════
EOF
    
    chmod 600 "$STATE_DIR/migration_summary.txt"
    log_success "Migration summary saved to $STATE_DIR/migration_summary.txt"
    
    update_step_status "finalize" "completed"
    update_state_status "completed"
}

################################################################################
# MAIN EXECUTION FLOW
################################################################################

show_usage() {
    cat <<EOF
Usage: $0 <domain> [migration-directory] [options]

Arguments:
  domain                 Domain name being migrated (e.g., example.com)
  migration-directory    Directory containing migration files (default: current directory)

Options:
  --continue            Continue from last successful step
  --restart             Restart migration from beginning
  -h, --help            Show this help message

Required Files (in migration directory):
  - domain-cf-origin.crt
  - domain-cf-origin.key
  - domain.sql
  - stage.domain.sql
  - config.env
  - domain.zip
  - stage.domain.zip

Examples:
  $0 example.com
  $0 example.com /root/migration-files
  $0 example.com --continue
  $0 example.com /root/migration-files --restart

EOF
}

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo -n "Enter domain name: "
        read DOMAIN
        DOMAIN=${DOMAIN/www./}
        MIGRATION_DIR="$(pwd)"
    else
        DOMAIN="${1/www./}"
        shift
        
        # Check if next argument is a directory or an option
        if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; then
            MIGRATION_DIR="$1"
            shift
        else
            MIGRATION_DIR="$(pwd)"
        fi
    fi
    
    if ! validate_domain_format "$DOMAIN"; then
        exit 1
    fi

    MIGRATION_DIR="$(cd "$MIGRATION_DIR" 2>/dev/null && pwd)" || {
        log_error "Migration directory does not exist: $MIGRATION_DIR"
        exit 1
    }

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

detect_previous_migration() {
    init_state_directory
    
    if [[ -f "$STATE_FILE" ]]; then
        local status=$(grep -o '"status": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        
        if [[ "$status" == "completed" ]]; then
            echo ""
            log_warning "Previous migration detected for $DOMAIN (Status: completed)"
            echo ""
            echo "What would you like to do?"
            echo "  [1] Start over (restart migration)"
            echo "  [2] Cancel"
            echo ""
            read -p "Choose an option (1-2): " choice
            
            case $choice in
                1)
                    MODE="restart"
                    ;;
                2)
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
            log_warning "Previous migration detected for $DOMAIN (Status: $status)"
            echo ""
            echo "What would you like to do?"
            echo "  [1] Continue from last step"
            echo "  [2] Start over (restart migration)"
            echo "  [3] Cancel"
            echo ""
            read -p "Choose an option (1-3): " choice
            
            case $choice in
                1)
                    MODE="continue"
                    ;;
                2)
                    MODE="restart"
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
        fi
    else
        MODE="fresh"
    fi
}

main() {
    local MODE="fresh"

    parse_arguments "$@"

    init_state_directory

    if [[ "$MODE" == "fresh" ]]; then
        detect_previous_migration
    fi

    print_header "Ubuntu Server Migration for WordPress - v$SCRIPT_VERSION"
    echo -e "Domain: ${COLOR_BOLD}$DOMAIN${COLOR_RESET}"
    echo -e "Migration Directory: ${COLOR_BOLD}$MIGRATION_DIR${COLOR_RESET}"
    echo "Log file: $LOG_FILE"
    echo ""

    if [[ "$MODE" == "restart" ]]; then
        log_info "Restarting migration..."
        rm -f "$STATE_FILE"
        init_state_directory
        MODE="fresh"
    fi

    if [[ "$MODE" == "continue" ]]; then
        log_info "Continuing from last step..."
        if [[ -f "$STATE_FILE" ]]; then
            local next_step=$(get_next_pending_step)
            if [[ "$next_step" == "all_completed" ]]; then
                log_success "All steps already completed!"
                cat "$STATE_DIR/migration_summary.txt"
                exit 0
            fi
            log_info "Next step: $next_step"
        else
            log_error "Cannot continue: no previous state found"
            exit 1
        fi
    else
        create_initial_state
    fi

    CERT_FILE="$DOMAIN-cf-origin.crt"
    KEY_FILE="$DOMAIN-cf-origin.key"

    validate_required_files
    validate_environment
    install_packages
    install_wpcli
    setup_system
    setup_certificates
    configure_apache
    configure_firewall
    configure_database
    import_databases
    configure_ftp
    extract_files
    finalize_migration

    echo ""
    print_header "Migration Completed Successfully!"
    
    echo ""
    echo -e "${COLOR_GREEN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║                  MIGRATION SUMMARY                        ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""

    source "$MIGRATION_DIR/config.env"
    
    echo -e "${COLOR_BOLD}Sites Migrated:${COLOR_RESET}"
    echo "  Production: https://$DOMAIN"
    echo "  Staging:    https://stage.$DOMAIN"
    echo ""
    
    echo -e "${COLOR_BOLD}FTP Access:${COLOR_RESET}"
    echo "  Host:     $DOMAIN"
    echo "  User:     $FTP_USERNAME"
    echo "  Password: $FTP_PASSWORD"
    echo ""
    
    echo -e "${COLOR_BOLD}Database (MariaDB):${COLOR_RESET}"
    echo "  Root Password: $MARIADB_ROOT_PWD"
    echo ""
    
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET}  ${COLOR_BOLD}Next Steps:${COLOR_RESET}"
    echo "  1. Update DNS records to point to this server"
    echo "  2. Test both production and staging sites"
    echo "  3. Verify database connections"
    echo ""
    
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} Full migration summary: ${COLOR_BOLD}$STATE_DIR/migration_summary.txt${COLOR_RESET}"
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} Migration log: ${COLOR_BOLD}$LOG_FILE${COLOR_RESET}"
    echo ""
}

trap 'log_error "Script failed at line $LINENO"' ERR

main "$@"
