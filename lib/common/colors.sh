#!/bin/bash

################################################################################
# Color and Formatting Utilities
################################################################################

[[ -n "${COLORS_LOADED:-}" ]] && return 0
readonly COLORS_LOADED=1

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_BOLD='\033[1m'

export COLOR_RESET COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE \
       COLOR_MAGENTA COLOR_CYAN COLOR_WHITE COLOR_BOLD
