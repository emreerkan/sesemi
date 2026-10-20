#!/bin/bash

################################################################################
# Site Ownership and Permission Functions
################################################################################

# With FTP the site user owns the files and shares group write with Apache.
# Without FTP there is no site user: www-data owns everything.
set_site_permissions() {
    local dir="$1"
    local shared_root="${2:-0}"
    
    if [[ "$WITH_FTP" == "1" ]]; then
        {
            chown -R "$USER:www-data" "$dir"
            find "$dir" -type d -exec chmod 775 {} +
            find "$dir" -type f -exec chmod 664 {} +
        } &>> "$LOG_FILE"
        
        if [[ -f "$dir/wp-config.php" ]]; then
            chmod 640 "$dir/wp-config.php" &>> "$LOG_FILE"
        fi
        
        if [[ "$shared_root" == "1" ]]; then
            chmod g+s "$dir" &>> "$LOG_FILE"
            if command -v setfacl &> /dev/null; then
                setfacl -d -m g::rwx "$dir" &>> "$LOG_FILE"
            fi
        fi
    else
        {
            chown -R www-data:www-data "$dir"
            find "$dir" -type d -exec chmod 755 {} +
            find "$dir" -type f -exec chmod 644 {} +
        } &>> "$LOG_FILE"
        
        if [[ -f "$dir/wp-config.php" ]]; then
            chmod 640 "$dir/wp-config.php" &>> "$LOG_FILE"
        fi
    fi
}
