package main

import (
	"log"
	"net/http"
	"os"

	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/config"
	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/limiter"
	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/middleware"
	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/storage"
	"github.com/joho/godotenv"
)

func main() {
	// Carrega variáveis de ambiente
	if err := godotenv.Load(); err != nil {
		log.Println("Aviso: arquivo .env não encontrado, usando variáveis de ambiente do sistema")
	}

	// Carrega configurações
	cfg := config.Load()

	// Inicializa o storage (Redis)
	store, err := storage.NewRedisStorage(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)
	if err != nil {
		log.Fatalf("Erro ao conectar ao Redis: %v", err)
	}
	defer store.Close()

	// Cria o rate limiter
	rateLimiter := limiter.NewRateLimiter(store, cfg)

	// Configura rotas
	mux := http.NewServeMux()

	// Rota de exemplo
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Hello! Request aceito."))
	})

	// Aplica middleware de rate limiting
	handler := middleware.RateLimitMiddleware(rateLimiter)(mux)

	// Inicia servidor
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Servidor rodando na porta %s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Erro ao iniciar servidor: %v", err)
	}
}
