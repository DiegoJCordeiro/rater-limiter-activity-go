package limiter

import (
	"fmt"
	"time"

	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/config"
	"github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/storage"
)

type RateLimiter struct {
	storage storage.Storage
	config  *config.Config
}

type LimitResult struct {
	Allowed bool
	Reason  string
}

func NewRateLimiter(storage storage.Storage, cfg *config.Config) *RateLimiter {
	return &RateLimiter{
		storage: storage,
		config:  cfg,
	}
}

// CheckIP verifica se um IP pode fazer requisições
func (rl *RateLimiter) CheckIP(ip string) (*LimitResult, error) {
	key := fmt.Sprintf("ip:%s", ip)

	// Verifica se está bloqueado
	blocked, err := rl.storage.IsBlocked(key)
	if err != nil {
		return nil, err
	}

	if blocked {
		return &LimitResult{
			Allowed: false,
			Reason:  "IP bloqueado temporariamente",
		}, nil
	}

	// Incrementa contador
	count, err := rl.storage.Increment(key, time.Second)
	if err != nil {
		return nil, err
	}

	// Verifica se excedeu o limite
	if count > int64(rl.config.IPRateLimit) {
		// Bloqueia o IP
		if err := rl.storage.Block(key, rl.config.IPBlockTime); err != nil {
			return nil, err
		}

		return &LimitResult{
			Allowed: false,
			Reason:  fmt.Sprintf("Limite de %d requisições por segundo excedido", rl.config.IPRateLimit),
		}, nil
	}

	return &LimitResult{Allowed: true}, nil
}

// CheckToken verifica se um token pode fazer requisições
func (rl *RateLimiter) CheckToken(token string) (*LimitResult, error) {
	key := fmt.Sprintf("token:%s", token)

	// Verifica se está bloqueado
	blocked, err := rl.storage.IsBlocked(key)
	if err != nil {
		return nil, err
	}

	if blocked {
		return &LimitResult{
			Allowed: false,
			Reason:  "Token bloqueado temporariamente",
		}, nil
	}

	// Incrementa contador
	count, err := rl.storage.Increment(key, time.Second)
	if err != nil {
		return nil, err
	}

	// Verifica se excedeu o limite
	if count > int64(rl.config.TokenRateLimit) {
		// Bloqueia o token
		if err := rl.storage.Block(key, rl.config.TokenBlockTime); err != nil {
			return nil, err
		}

		return &LimitResult{
			Allowed: false,
			Reason:  fmt.Sprintf("Limite de %d requisições por segundo excedido", rl.config.TokenRateLimit),
		}, nil
	}

	return &LimitResult{Allowed: true}, nil
}
