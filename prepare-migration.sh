#!/bin/bash

################################################################################
# WordPress Migration Preparation Script
# Run this on the SOURCE server to prepare migration files
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

NO_DATA=0
WITH_FTP="${INSTALL_FTP:-0}"
for arg in "$@"; do
    case $arg in
        --no-data)
            NO_DATA=1
            ;;
        --with-ftp)
            WITH_FTP=1
            ;;
        -h|--help)
            echo "Usage: $0 [--no-data] [--with-ftp]"
            echo "  --no-data   Skip the prod and stage SQL dumps (files, certs, config.env only)"
            echo "  --with-ftp  Ask for the FTP password and add FTP credentials to config.env"
            exit 0
            ;;
        *)
            echo -e "${RED}✗${RESET} Unknown option: $arg"
            exit 1
            ;;
    esac
done

# Reads a define() value from wp-config.php. WP-CLI evaluates the file, so
# getenv() and double quotes work; the PHP tokenizer fallback handles literal
# values in either quote style and ignores commented-out defines.
wp_config_get() {
    local config_file="$1"
    local name="$2"
    local value
    
    if command -v wp &> /dev/null && value=$(wp --allow-root config get "$name" --config-file="$config_file" 2>/dev/null); then
        printf '%s' "$value"
        return 0
    fi
    
    # shellcheck disable=SC2016
    php -r '
        $tokens = array();
        foreach (token_get_all(file_get_contents($argv[1])) as $t) {
            if (is_array($t) && in_array($t[0], array(T_WHITESPACE, T_COMMENT, T_DOC_COMMENT))) continue;
            $tokens[] = $t;
        }
        $lit = function ($t) {
            if (!is_array($t) || $t[0] !== T_CONSTANT_ENCAPSED_STRING) return null;
            return $t[1][0] === "\x27" ? strtr(substr($t[1], 1, -1), array("\\\x27" => "\x27", "\\\\" => "\\")) : stripcslashes(substr($t[1], 1, -1));
        };
        for ($i = 0; $i + 4 < count($tokens); $i++) {
            if (is_array($tokens[$i]) && strtolower($tokens[$i][1]) === "define" && $tokens[$i + 1] === "("
                && $lit($tokens[$i + 2]) === $argv[2] && $tokens[$i + 3] === ",") {
                $v = $lit($tokens[$i + 4]);
                if ($v === null) exit(2);
                echo $v;
                exit(0);
            }
        }
        exit(1);
    ' "$config_file" "$name"
}

# Reads DB_NAME/DB_USER/DB_PASSWORD/DB_HOST into <PREFIX>_DB_* variables
read_db_config() {
    local config_file="$1"
    local prefix="$2"
    local key var value
    
    for key in NAME USER PASSWORD HOST; do
        if ! value=$(wp_config_get "$config_file" "DB_$key"); then
            if [[ "$key" == "HOST" ]]; then
                value="localhost"
            else
                echo -e "${RED}✗${RESET} Could not read DB_$key from $config_file"
                exit 1
            fi
        fi
        var="${prefix}_DB_$key"
        printf -v "$var" '%s' "$value"
    done
}

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║           WordPress Migration File Preparation            ║${RESET}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${RESET}"
echo ""

read -p "Enter domain name (e.g., example.com): " DOMAIN
DOMAIN=${DOMAIN/www./}

MIGRATION_DIR="/root/migration-$DOMAIN"
mkdir -p "$MIGRATION_DIR"

echo -e "${GREEN}✓${RESET} Created migration directory: $MIGRATION_DIR"
echo ""

if [[ "$NO_DATA" == "1" ]]; then
    echo -e "${BLUE}[1/7]${RESET} Exporting production database... ${YELLOW}skipped (--no-data)${RESET}"
    echo -e "${BLUE}[2/7]${RESET} Exporting staging database... ${YELLOW}skipped (--no-data)${RESET}"
    if [[ ! -d "/home/$DOMAIN" ]]; then
        echo -e "${RED}✗${RESET} Production directory not found: /home/$DOMAIN"
        exit 1
    fi
else
    echo -e "${BLUE}[1/7]${RESET} Exporting production database..."
    if [[ -d "/home/$DOMAIN" ]]; then
        cd "/home/$DOMAIN"
        if wp --allow-root db export "$MIGRATION_DIR/$DOMAIN.sql" 2>/dev/null; then
            echo -e "${GREEN}✓${RESET} Production database exported"
        else
            echo -e "${YELLOW}⚠${RESET} Could not export with WP-CLI, trying mysqldump..."
            if [[ -f wp-config.php ]]; then
                read_db_config "$PWD/wp-config.php" DUMP
            
                mysqldump --single-transaction --quick -h "${DUMP_DB_HOST%%:*}" -u "$DUMP_DB_USER" -p"$DUMP_DB_PASSWORD" "$DUMP_DB_NAME" > "$MIGRATION_DIR/$DOMAIN.sql"
                echo -e "${GREEN}✓${RESET} Production database exported with mysqldump"
            else
                echo -e "${RED}✗${RESET} Could not export production database"
                exit 1
            fi
        fi
    else
        echo -e "${RED}✗${RESET} Production directory not found: /home/$DOMAIN"
        exit 1
    fi

    echo -e "${BLUE}[2/7]${RESET} Exporting staging database..."
    if [[ -d "/home/stage.$DOMAIN" ]]; then
        cd "/home/stage.$DOMAIN"
        if wp --allow-root db export "$MIGRATION_DIR/stage.$DOMAIN.sql" 2>/dev/null; then
            echo -e "${GREEN}✓${RESET} Staging database exported"
        else
            echo -e "${YELLOW}⚠${RESET} Could not export with WP-CLI, trying mysqldump..."
            if [[ -f wp-config.php ]]; then
                read_db_config "$PWD/wp-config.php" DUMP
            
                mysqldump --single-transaction --quick -h "${DUMP_DB_HOST%%:*}" -u "$DUMP_DB_USER" -p"$DUMP_DB_PASSWORD" "$DUMP_DB_NAME" > "$MIGRATION_DIR/stage.$DOMAIN.sql"
                echo -e "${GREEN}✓${RESET} Staging database exported with mysqldump"
            else
                echo -e "${RED}✗${RESET} Could not export staging database"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠${RESET} Staging directory not found: /home/stage.$DOMAIN"
        echo -e "${YELLOW}⚠${RESET} Creating empty SQL file for staging"
        touch "$MIGRATION_DIR/stage.$DOMAIN.sql"
    fi
fi

echo -e "${BLUE}[3/7]${RESET} Creating production files archive..."
cd "/home/$DOMAIN"
zip -rq "$MIGRATION_DIR/$DOMAIN.zip" .
echo -e "${GREEN}✓${RESET} Production files archived ($(du -h "$MIGRATION_DIR/$DOMAIN.zip" | cut -f1))"

echo -e "${BLUE}[4/7]${RESET} Creating staging files archive..."
if [[ -d "/home/stage.$DOMAIN" ]]; then
    cd "/home/stage.$DOMAIN"
    zip -rq "$MIGRATION_DIR/stage.$DOMAIN.zip" .
    echo -e "${GREEN}✓${RESET} Staging files archived ($(du -h "$MIGRATION_DIR/stage.$DOMAIN.zip" | cut -f1))"
else
    echo -e "${YELLOW}⚠${RESET} Creating empty staging archive"
    cd "$MIGRATION_DIR"
    zip -q "stage.$DOMAIN.zip" -T
fi

echo -e "${BLUE}[5/7]${RESET} Copying SSL certificates..."
if [[ -f "/home/ssl/$DOMAIN-cf-origin.crt" ]] && [[ -f "/home/ssl/$DOMAIN-cf-origin.key" ]]; then
    cp "/home/ssl/$DOMAIN-cf-origin.crt" "$MIGRATION_DIR/"
    cp "/home/ssl/$DOMAIN-cf-origin.key" "$MIGRATION_DIR/"
    echo -e "${GREEN}✓${RESET} SSL certificates copied"
else
    echo -e "${RED}✗${RESET} SSL certificates not found in /home/ssl/"
    echo -e "${RED}✗${RESET} Required: $DOMAIN-cf-origin.crt and $DOMAIN-cf-origin.key"
    exit 1
fi

echo -e "${BLUE}[6/7]${RESET} Creating config.env..."

read_db_config "/home/$DOMAIN/wp-config.php" PROD

if [[ -f "/home/stage.$DOMAIN/wp-config.php" ]]; then
    read_db_config "/home/stage.$DOMAIN/wp-config.php" STAGE
else
    STAGE_DB_NAME="stage_db_name"
    STAGE_DB_USER="stage_db_user"
    STAGE_DB_PASSWORD="stage_db_pass"
    STAGE_DB_HOST="localhost"
fi

echo -e "${GREEN}✓${RESET} Production DB: $PROD_DB_NAME (user $PROD_DB_USER, host $PROD_DB_HOST)"
echo -e "${GREEN}✓${RESET} Staging DB: $STAGE_DB_NAME (user $STAGE_DB_USER, host $STAGE_DB_HOST)"

# %q keeps passwords with quotes, $ or backslashes intact when sourced
{
    printf 'PROD_DB_NAME=%q\n' "$PROD_DB_NAME"
    printf 'PROD_DB_USERNAME=%q\n' "$PROD_DB_USER"
    printf 'PROD_DB_PASSWORD=%q\n' "$PROD_DB_PASSWORD"
    printf 'PROD_DB_HOST=%q\n\n' "$PROD_DB_HOST"
    printf 'STAGE_DB_NAME=%q\n' "$STAGE_DB_NAME"
    printf 'STAGE_DB_USERNAME=%q\n' "$STAGE_DB_USER"
    printf 'STAGE_DB_PASSWORD=%q\n' "$STAGE_DB_PASSWORD"
    printf 'STAGE_DB_HOST=%q\n' "$STAGE_DB_HOST"
} > "$MIGRATION_DIR/config.env"

if [[ "$WITH_FTP" == "1" ]]; then
    FTP_USER=$(cut -d '.' -f 1 <<< "$DOMAIN")
    echo ""
    echo -e "${YELLOW}Please enter FTP password for user: $FTP_USER${RESET}"
    read -r -s -p "FTP Password: " FTP_PASS
    echo ""
    {
        echo ""
        printf 'FTP_USERNAME=%q\n' "$FTP_USER"
        printf 'FTP_PASSWORD=%q\n' "$FTP_PASS"
    } >> "$MIGRATION_DIR/config.env"
fi

chmod 600 "$MIGRATION_DIR/config.env"
echo -e "${GREEN}✓${RESET} config.env created"

echo -e "${BLUE}[7/7]${RESET} Creating migration tarball..."
cd "$(dirname "$MIGRATION_DIR")"
tar -czf "migration-$DOMAIN.tar.gz" "$(basename "$MIGRATION_DIR")"
echo -e "${GREEN}✓${RESET} Migration tarball created"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                  Preparation Complete!                    ║${RESET}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${RESET}"
echo ""

echo "Files created in: $MIGRATION_DIR"
echo ""
echo "Contents:"
ls -lh "$MIGRATION_DIR"
echo ""

TARBALL="$(dirname "$MIGRATION_DIR")/migration-$DOMAIN.tar.gz"
echo "Tarball: $TARBALL"
echo "Size: $(du -h "$TARBALL" | cut -f1)"
echo ""

echo -e "${BLUE}Next steps:${RESET}"
echo "1. Transfer tarball to new server:"
echo -e "   ${YELLOW}scp $TARBALL root@NEW_SERVER_IP:~${RESET}"
echo ""
echo "2. On new server, extract and run migration:"
echo -e "   ${YELLOW}tar -xzf migration-$DOMAIN.tar.gz${RESET}"
echo -e "   ${YELLOW}./migrate.sh $DOMAIN ./migration-$DOMAIN$([[ "$NO_DATA" == "1" ]] && echo " --no-data")$([[ "$WITH_FTP" == "1" ]] && echo " --with-ftp")${RESET}"
echo ""
