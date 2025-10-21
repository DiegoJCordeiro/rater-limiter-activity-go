package middleware

import (
	"log"
	"net"
	"net/http"
	"strings"

	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/limiter"
)

func RateLimitMiddleware(rateLimiter *limiter.RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Verifica se existe token no header
			token := r.Header.Get("API_KEY")

			var result *limiter.LimitResult
			var err error

			// Token tem prioridade sobre IP
			if token != "" {
				result, err = rateLimiter.CheckToken(token)
			} else {
				// Extrai IP do request
				ip := getIP(r)
				result, err = rateLimiter.CheckIP(ip)
			}

			if err != nil {
				log.Printf("Erro ao verificar rate limit: %v", err)
				http.Error(w, "Erro interno do servidor", http.StatusInternalServerError)
				return
			}

			if !result.Allowed {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error": "you have reached the maximum number of requests or actions allowed within a certain time frame"}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// getIP extrai o IP real do cliente, considerando proxies
func getIP(r *http.Request) string {
	// Tenta X-Forwarded-For primeiro
	forwarded := r.Header.Get("X-Forwarded-For")
	if forwarded != "" {
		// Pega o primeiro IP da lista
		ips := strings.Split(forwarded, ",")
		return strings.TrimSpace(ips[0])
	}

	// Tenta X-Real-IP
	realIP := r.Header.Get("X-Real-IP")
	if realIP != "" {
		return realIP
	}

	// Usa RemoteAddr como fallback
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}

	return ip
}
