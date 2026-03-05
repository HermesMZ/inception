NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml -p $(NAME)

all: up

up:
	@chmod +x ./scripts/check_volumes.sh
	@bash ./scripts/check_volumes.sh
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) down
	$(COMPOSE) up --build -d

test:
	@chmod +x ./scripts/test-inception.sh
	@bash ./scripts/test-inception.sh

logs:
	$(COMPOSE) logs

logs-f:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean: clean
	@echo "Nettoyage des volumes via un conteneur temporaire..."
	docker run --rm -v /home/$(USER)/data:/data alpine sh -c "rm -rf /data/*"
	@docker system prune -af

re: fclean all

.PHONY: all up down stop restart logs logs-f ps clean fclean re
