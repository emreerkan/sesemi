#!/bin/bash

################################################################################
# Logging and Output Functions
################################################################################

source "${SCRIPT_DIR}/lib/common/colors.sh"

log() {
    local message="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

log_info() {
    local message="$1"
    echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $message"
    log "INFO: $message"
}

log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $message"
    log "SUCCESS: $message"
}

log_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $message"
    log "WARNING: $message"
}

log_error() {
    local message="$1"
    echo -e "${COLOR_RED}✗${COLOR_RESET} $message" >&2
    log "ERROR: $message"
}

print_header() {
    local title="$1"
    echo ""
    echo -e "${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
    printf "${COLOR_CYAN}║${COLOR_RESET} %-57s ${COLOR_CYAN}║${COLOR_RESET}\n" "$title"
    echo -e "${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

print_step() {
    local step_name="$1"
    STEP_COUNTER=$((STEP_COUNTER + 1))
    echo ""
    echo -e "${COLOR_BOLD}[$STEP_COUNTER/$TOTAL_STEPS]${COLOR_RESET} ${COLOR_WHITE}$step_name${COLOR_RESET}"
    log "STEP [$STEP_COUNTER/$TOTAL_STEPS]: $step_name"
}

print_substep() {
    local message="$1"
    echo -e "  ${COLOR_CYAN}→${COLOR_RESET} $message"
}

spinner() {
    local pid=$1
    local message=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    echo -n "  "
    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf "${COLOR_CYAN}%c${COLOR_RESET} %s" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "  %-60s\r" " "
}
