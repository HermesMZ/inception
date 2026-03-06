#!/bin/bash
set -e

echo "============ START INIT FTP ==============="

# Récupérer le mot de passe FTP depuis les secrets Docker
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        echo "${!var_name:-}"
    fi
}

FTP_PASS=$(get_secret "FTP_PASSWORD")

if [ -z "$FTP_PASS" ]; then
    echo "Erreur : FTP_PASSWORD ou FTP_PASSWORD_FILE non défini."
    exit 1
fi

# Configurer le mot de passe de l'utilisateur FTP
echo "ftpuser:$FTP_PASS" | chpasswd
echo "Utilisateur FTP configuré avec succès."

# Attendre que le répertoire WordPress soit monté
while [ ! -d "/home/ftpuser/wordpress" ]; do
    echo "En attente du montage du répertoire WordPress..."
    sleep 1
done

# Configurer les permissions
chown -R ftpuser:ftpuser /home/ftpuser/wordpress
chmod -R 755 /home/ftpuser/wordpress
echo "Répertoire WordPress monté et accessible."

# Préparer le dossier de run et les logs
mkdir -p /var/run/vsftpd
rm -f /var/run/vsftpd/vsftpd.pid
touch /var/log/vsftpd.log
chmod 644 /var/log/vsftpd.log

# Démarrer vsftpd en affichant les logs en temps réel
echo "Démarrage de vsftpd avec logs activés..."
tail -f /var/log/vsftpd.log &
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf 