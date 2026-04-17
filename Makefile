NAME          = inception
SCRIPTS_DIR   = ./scripts
COMPOSE       = docker compose -f srcs/docker-compose.yml -p $(NAME)

GREEN         = \033[0;32m
YELLOW        = \033[0;33m
RED           = \033[0;31m
NC            = \033[0m

all: up

build:
	@echo "$(YELLOW)Constructing Docker images...$(NC)"
	@$(COMPOSE) build

up: setup_volumes build
	@echo "$(GREEN)Start Inception Containers...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)Projet operational !$(NC)"
	@echo "$(YELLOW)Run 'make test' to test conformity.$(NC)"
	@echo "$(YELLOW)Open your browser at: $(NC)\033[4;32mhttps://$(USER).42.fr\033[0m"

setup_volumes:
	@echo "$(YELLOW)Checking volumes...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/check_volumes.sh
	@bash $(SCRIPTS_DIR)/check_volumes.sh

stop:
	@echo "$(YELLOW)Stoping containers...$(NC)"
	@$(COMPOSE) stop

down:
	@echo "$(YELLOW)Removing containers...$(NC)"
	@$(COMPOSE) down

start:
	@echo "$(YELLOW)Starting containers...$(NC)"
	@$(COMPOSE) start

restart:
	@echo "$(YELLOW)Update and restart...$(NC)"
	@$(COMPOSE) up -d --build

test:
	@echo "$(YELLOW)Conformity tests...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/test-inception.sh
	@bash $(SCRIPTS_DIR)/test-inception.sh

status:
	@echo "$(YELLOW)--- Inception services status ---$(NC)"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}"

ps:
	@$(COMPOSE) ps

logs:
	@$(COMPOSE) logs -f

clean:
	@echo "$(RED)Cleaning containers and images...$(NC)"
	@$(COMPOSE) down -v

# Full Cleanup (Host files + Images + Cache)
# Create a temporary container that mounts the data folder to completely wipe it, then clean Docker images and cache
# WARNING: This command will delete ALL data in /home/$(USER)/data.
fclean: clean
	@echo "$(RED)Deep cleaning data on the host...$(NC)"
	@# Using -v to mount the parent folder and clean everything properly
	@docker run --rm -v /home/$(USER)/data:/data alpine sh -c "rm -rf /data/*"
	@echo "$(RED)Removing all images and cache...$(NC)"
	@docker system prune -af
	@echo "$(GREEN)Cleanup complete. Fresh site.$(NC)"

re: fclean all

.PHONY: all up setup_volumes down stop restart test ps logs clean fclean re