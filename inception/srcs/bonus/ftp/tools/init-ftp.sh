#!/bin/sh

set -e

echo "============ START INIT FTP ==============="

# Configurer le mot de passe de l'utilisateur ftpuser
if [ -n "${FTP_PASSWORD}" ]; then
    echo "Configuration de l'utilisateur FTP: ftpuser"
    
    # Définir le mot de passe de l'utilisateur ftpuser
    echo "ftpuser:${FTP_PASSWORD}" | chpasswd 2>/dev/null
    
    echo "Utilisateur FTP configuré avec succès"
else
    echo "Erreur : FTP_PASSWORD non défini"
    exit 1
fi

# S'assurer que le répertoire WordPress est accessible
echo "Attente du répertoire WordPress..."
MAX_RETRIES=5
COUNT=0
while [ ! -d "/home/ftpuser/wordpress" ] && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    COUNT=$((COUNT + 1))
done

if [ -d "/home/ftpuser/wordpress" ]; then
    chown -R ftpuser:ftpuser /home/ftpuser/wordpress || true
    chmod -R 755 /home/ftpuser/wordpress || true
    echo "Répertoire WordPress monté et accessible"
else
    echo "Attention : répertoire WordPress non trouvé, création..."
    mkdir -p /home/ftpuser/wordpress
    chown -R ftpuser:ftpuser /home/ftpuser/wordpress
fi

# Création du dossier nécessaire au processus vsftpd
mkdir -p /var/run/vsftpd
# On s'assure qu'aucun vieux fichier PID ne bloque le démarrage
rm -f /var/run/vsftpd/vsftpd.pid

echo "Démarrage de vsftpd..."

# Lancer vsftpd en mode foreground
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
