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

echo -e "${BLUE}[1/7]${RESET} Exporting production database..."
if [[ -d "/home/$DOMAIN" ]]; then
    cd "/home/$DOMAIN"
    if wp --allow-root db export "$MIGRATION_DIR/$DOMAIN.sql" 2>/dev/null; then
        echo -e "${GREEN}✓${RESET} Production database exported"
    else
        echo -e "${YELLOW}⚠${RESET} Could not export with WP-CLI, trying mysqldump..."
        if [[ -f wp-config.php ]]; then
            DB_NAME=$(grep DB_NAME wp-config.php | cut -d "'" -f 4)
            DB_USER=$(grep DB_USER wp-config.php | cut -d "'" -f 4)
            DB_PASS=$(grep DB_PASSWORD wp-config.php | cut -d "'" -f 4)
            
            mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$MIGRATION_DIR/$DOMAIN.sql"
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
            DB_NAME=$(grep DB_NAME wp-config.php | cut -d "'" -f 4)
            DB_USER=$(grep DB_USER wp-config.php | cut -d "'" -f 4)
            DB_PASS=$(grep DB_PASSWORD wp-config.php | cut -d "'" -f 4)
            
            mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$MIGRATION_DIR/stage.$DOMAIN.sql"
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

cd "/home/$DOMAIN"
PROD_DB_NAME=$(grep DB_NAME wp-config.php | cut -d "'" -f 4)
PROD_DB_USER=$(grep DB_USER wp-config.php | cut -d "'" -f 4)
PROD_DB_PASS=$(grep DB_PASSWORD wp-config.php | cut -d "'" -f 4)

if [[ -f "/home/stage.$DOMAIN/wp-config.php" ]]; then
    cd "/home/stage.$DOMAIN"
    STAGE_DB_NAME=$(grep DB_NAME wp-config.php | cut -d "'" -f 4)
    STAGE_DB_USER=$(grep DB_USER wp-config.php | cut -d "'" -f 4)
    STAGE_DB_PASS=$(grep DB_PASSWORD wp-config.php | cut -d "'" -f 4)
else
    STAGE_DB_NAME="stage_db_name"
    STAGE_DB_USER="stage_db_user"
    STAGE_DB_PASS="stage_db_pass"
fi

FTP_USER=$(cut -d '.' -f 1 <<< "$DOMAIN")
echo ""
echo -e "${YELLOW}Please enter FTP password for user: $FTP_USER${RESET}"
read -s -p "FTP Password: " FTP_PASS
echo ""

cat > "$MIGRATION_DIR/config.env" <<EOF
PROD_DB_NAME="$PROD_DB_NAME"
PROD_DB_USERNAME="$PROD_DB_USER"
PROD_DB_PASSWORD="$PROD_DB_PASS"

STAGE_DB_NAME="$STAGE_DB_NAME"
STAGE_DB_USERNAME="$STAGE_DB_USER"
STAGE_DB_PASSWORD="$STAGE_DB_PASS"

FTP_USERNAME="$FTP_USER"
FTP_PASSWORD="$FTP_PASS"
EOF

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
echo -e "   ${YELLOW}./migrate.sh $DOMAIN ./migration-$DOMAIN${RESET}"
echo ""
