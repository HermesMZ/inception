#!/bin/bash
set -e

echo "============ START INIT FTP ==============="

# --- FONCTION POUR RÉCUPÉRER LES SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        echo "${!var_name:-}"
    fi
}

# Récupération du mot de passe FTP
FTP_PASS=$(get_secret "FTP_PASSWORD")

if [ -z "$FTP_PASS" ]; then
    echo "Erreur : Le mot de passe FTP est vide."
    exit 1
fi

# Configurer le mot de passe de l'utilisateur FTP
echo "ftpuser:$FTP_PASS" | chpasswd
echo "Utilisateur FTP configuré avec succès."

# Attendre que WordPress soit prêt et que le volume soit monté
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

# Créer un dossier uploads writable dans wordpress
mkdir -p /home/ftpuser/wordpress/wp-content/uploads
chown ftpuser:ftpuser /home/ftpuser/wordpress/wp-content/uploads
chmod 755 /home/ftpuser/wordpress/wp-content/uploads

# Le home doit appartenir à root pour le chroot (sécurité vsftpd)
chown root:root /home/ftpuser
chmod 755 /home/ftpuser

echo "Permissions configurées:"
ls -la /home/ftpuser/
echo "Uploads directory:"
ls -la /home/ftpuser/wordpress/wp-content/ | grep uploads || echo "WARNING: uploads directory not visible in listing"

echo "============ START VSFTPD ==============="
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf