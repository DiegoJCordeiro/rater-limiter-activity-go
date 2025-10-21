.PHONY: help build run test clean docker-up docker-down docker-logs

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Compila a aplicação
	go build -o bin/ratelimiter .

run: ## Executa a aplicação localmente
	go run main.go

test: ## Executa todos os testes
	go test ./... -v -cover

test-unit: ## Executa apenas testes unitários
	go test ./internal/... -v -cover

test-integration: ## Executa testes de integração
	go test ./test/... -v

test-coverage: ## Gera relatório de cobertura
	go test ./... -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html
	@echo "Relatório gerado em coverage.html"

docker-up: ## Sobe os containers com docker-compose
	docker-compose up --build -d

docker-down: ## Para os containers
	docker-compose down

docker-logs: ## Mostra logs dos containers
	docker-compose logs -f

docker-restart: ## Reinicia os containers
	docker-compose restart

clean: ## Remove arquivos gerados
	rm -rf bin/
	rm -f coverage.out coverage.html
	docker-compose down -v

deps: ## Instala dependências
	go mod download
	go mod tidy

load-test: ## Executa teste de carga básico
	@echo "Testando limite por IP (espera-se bloqueio após 10 requisições)..."
	@for i in {1..15}; do \
		curl -s http://localhost:8080/ > /dev/null && echo "✓ Request $$i OK" || echo "✗ Request $$i BLOCKED"; \
		sleep 0.1; \
	done
	@echo "\nTestando com token (espera-se bloqueio após 100 requisições)..."
	@for i in {1..105}; do \
		curl -s -H "API_KEY: token123" http://localhost:8080/ > /dev/null && echo "✓ Request $$i OK" || echo "✗ Request $$i BLOCKED"; \
		sleep 0.01; \
	done