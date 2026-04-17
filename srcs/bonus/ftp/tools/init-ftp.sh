#!/bin/bash
set -e

echo "============ START INIT FTP ==============="

# --- FUNCTION TO RETRIEVE SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        echo "${!var_name:-}"
    fi
}

# Retrieve FTP password
FTP_PASS=$(get_secret "FTP_PASSWORD")

if [ -z "$FTP_PASS" ]; then
    echo "Error: FTP password is empty."
    exit 1
fi

# Set FTP user password
echo "ftpuser:$FTP_PASS" | chpasswd
echo "FTP user successfully configured."

# Wait for WordPress to be ready and the volume to be mounted
echo "Waiting for WordPress volume to be ready..."
timeout=60
while [ $timeout -gt 0 ]; do
    if [ -f "/home/ftpuser/wordpress/wp-config.php" ]; then
        echo "WordPress volume is ready!"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "ERROR: WordPress volume not found after 60 seconds"
    exit 1
fi

# Create a writable uploads directory in WordPress
mkdir -p /home/ftpuser/wordpress/wp-content/uploads
chown ftpuser:ftpuser /home/ftpuser/wordpress/wp-content/uploads
chmod 755 /home/ftpuser/wordpress/wp-content/uploads

# Home must belong to root for chroot (vsftpd security)
chown root:root /home/ftpuser
chmod 755 /home/ftpuser

echo "Configured permissions:"
ls -la /home/ftpuser/
echo "Uploads directory:"
ls -la /home/ftpuser/wordpress/wp-content/ | grep uploads || echo "WARNING: uploads directory not visible in listing"

echo "============ START VSFTPD ==============="
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf