#!/bin/bash

################################################################################
# FTP Configuration Functions
################################################################################

configure_ftp() {
    if check_step_completed "configure_ftp"; then
        log_info "FTP already configured, skipping..."
        return 0
    fi
    
    print_step "Configuring FTP server"
    update_step_status "configure_ftp" "in_progress"
    
    print_substep "Backing up original vsftpd configuration..."
    if [[ -f /etc/vsftpd.conf ]] && [[ ! -f /etc/vsftpd.conf.bak ]]; then
        mv /etc/vsftpd.conf /etc/vsftpd.conf.bak
    fi
    
    print_substep "Creating vsftpd configuration..."
    cat <<EOF > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO

anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES

user_sub_token=\$USER
local_root=/home/$DOMAIN
allow_writeable_chroot=YES

pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
EOF
    
    print_substep "Restarting FTP service..."
    if ! systemctl restart vsftpd &>> "$LOG_FILE"; then
        log_error "Failed to restart vsftpd"
        update_step_status "configure_ftp" "failed"
        exit 1
    fi
    
    log_success "FTP server configured"
    
    update_step_status "configure_ftp" "completed"
}
