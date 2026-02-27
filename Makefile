NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml -p $(NAME)

all: up

up:
	bash ./scripts/check_volumes.sh
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) down
	$(COMPOSE) up --build -d

test:
	bash ./scripts/test-inception.sh

logs:
	$(COMPOSE) logs

logs-f:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean: clean
	docker system prune -af
	docker network rm inception 2>/dev/null || true

re: fclean all

.PHONY: all up down stop restart logs logs-f ps clean fclean re
