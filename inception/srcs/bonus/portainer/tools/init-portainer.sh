#!/bin/sh

# Récupérer le mot de passe depuis le secret
PORTAINER_PASSWORD=$(cat /run/secrets/portainer_password)

# Configurer l'utilisateur admin via l'API
curl -X POST \
  --header "Content-Type: application/json" \
  --data '{"Username": "admin", "Password": "'"$PORTAINER_PASSWORD"'"}' \
  http://localhost:9000/api/users/admin/init

echo "Portainer est configuré avec l'utilisateur admin."
