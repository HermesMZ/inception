NAME          = inception
SCRIPTS_DIR   = ./scripts
COMPOSE       = docker compose -f srcs/docker-compose.yml -p $(NAME)

GREEN         = \033[0;32m
YELLOW        = \033[0;33m
RED           = \033[0;31m
NC            = \033[0m

all: up

# Construction et lancement

build:
	@echo "$(YELLOW)Construction des images Docker...$(NC)"
	@$(COMPOSE) build

up: setup_volumes build
	@echo "$(GREEN)Démarrage des conteneurs Inception...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)Projet opérationnel !$(NC)"
	@echo "$(YELLOW)Lancer 'make test' pour vérifier la conformité.$(NC)"
	@echo "$(YELLOW)Open your browser at: $(NC)\033[4;32mhttps://$(USER).42.fr\033[0m"

# Préparation des volumes
setup_volumes:
	@echo "$(YELLOW)Vérification des volumes...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/check_volumes.sh
	@bash $(SCRIPTS_DIR)/check_volumes.sh

# Arrêt sans suppression
stop:
	@echo "$(YELLOW)Arrêt des conteneurs...$(NC)"
	@$(COMPOSE) stop

# Arrêt et suppression des conteneurs/réseaux
down:
	@echo "$(YELLOW)Suppression des conteneurs...$(NC)"
	@$(COMPOSE) down

# Si les conteneurs n'existent pas, Docker Compose les créera quand même.
start:
	@echo "$(YELLOW)Démarrage des conteneurs existants...$(NC)"
	@$(COMPOSE) start

# Applique les changements de config
restart:
	@echo "$(YELLOW)Application des modifications et redémarrage...$(NC)"
	@$(COMPOSE) up -d --build

# Tests de conformité
test:
	@echo "$(YELLOW)Lancement des tests de conformité...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/test-inception.sh
	@bash $(SCRIPTS_DIR)/test-inception.sh

status:
	@echo "$(YELLOW)--- État des services Inception ---$(NC)"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}"

# Monitoring
ps:
	@$(COMPOSE) ps

logs:
	@$(COMPOSE) logs -f

# Nettoyage partiel (Conteneurs, Réseaux, Volumes Docker)
clean:
	@echo "$(RED)Nettoyage des conteneurs et volumes Docker...$(NC)"
	@$(COMPOSE) down -v

# Nettoyage Total (Fichiers sur le host + Images + Cache)
# Création d'un conteneur temporaire qui monte le dossier data pour tout raser proprement, puis nettoyage des images et du cache Docker
# ATTENTION : Cette commande supprimera TOUTES les données dans /home/$(USER)/data.
fclean: clean
	@echo "$(RED)Nettoyage profond des données sur le host...$(NC)"
	@# Utilisation de -v pour monter le dossier parent et tout raser proprement
	@docker run --rm -v /home/$(USER)/data:/data alpine sh -c "rm -rf /data/*"
	@echo "$(RED)Suppression de toutes les images et du cache...$(NC)"
	@docker system prune -af
	@echo "$(GREEN)Nettoyage terminé. Site vierge.$(NC)"

re: fclean all

.PHONY: all up setup_volumes down stop restart test ps logs clean fclean re