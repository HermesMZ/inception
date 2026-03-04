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

# Récupération du mot de passe
# Note: Dans ton docker-compose, le secret s'appelle ftp_password
# et la variable d'env FTP_PASSWORD_FILE pointe vers /run/secrets/ftp_password
FTP_PASS=$(get_secret "FTP_PASSWORD")

if [ -n "$FTP_PASS" ]; then
    echo "Configuration de l'utilisateur FTP: ftpuser"
    
    # Définir le mot de passe de l'utilisateur ftpuser
    echo "ftpuser:$FTP_PASS" | chpasswd
    
    echo "Utilisateur FTP configuré avec succès"
else
    echo "Erreur : FTP_PASSWORD ou FTP_PASSWORD_FILE non défini"
    exit 1
fi

# S'assurer que le répertoire WordPress est accessible
echo "Attente du répertoire WordPress..."
# ... (ton code de boucle while reste identique)

if [ -d "/home/ftpuser/wordpress" ]; then
    # Attention: dans Inception, l'utilisateur PHP est souvent www-data (UID 33)
    # et le FTP est ftpuser. Pour que les deux puissent écrire, 
    # vérifie bien tes UID/GID ou utilise les permissions de groupe.
    chown -R ftpuser:ftpuser /home/ftpuser/wordpress
    chmod -R 755 /home/ftpuser/wordpress
    echo "Répertoire WordPress monté et accessible"
fi

# Préparation du dossier de run
mkdir -p /var/run/vsftpd
rm -f /var/run/vsftpd/vsftpd.pid

echo "Démarrage de vsftpd..."
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf