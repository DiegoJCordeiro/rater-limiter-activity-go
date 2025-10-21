package storage

import "time"

// Storage define a interface para persistência do rate limiter
// Permite facilmente trocar Redis por outro mecanismo
type Storage interface {
	// Increment incrementa o contador para uma chave e retorna o valor atual
	Increment(key string, expiration time.Duration) (int64, error)

	// Get obtém o valor atual de uma chave
	Get(key string) (int64, error)

	// IsBlocked verifica se uma chave está bloqueada
	IsBlocked(key string) (bool, error)

	// Block bloqueia uma chave por um determinado tempo
	Block(key string, duration time.Duration) error

	// Close fecha a conexão com o storage
	Close() error
}
