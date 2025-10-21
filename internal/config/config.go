package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	// Configurações do Redis
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// Configurações de Rate Limiting por IP
	IPRateLimit int
	IPBlockTime time.Duration

	// Configurações de Rate Limiting por Token
	TokenRateLimit int
	TokenBlockTime time.Duration
}

func Load() *Config {
	return &Config{
		RedisAddr:      getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword:  getEnv("REDIS_PASSWORD", ""),
		RedisDB:        getEnvAsInt("REDIS_DB", 0),
		IPRateLimit:    getEnvAsInt("IP_RATE_LIMIT", 10),
		IPBlockTime:    getEnvAsDuration("IP_BLOCK_TIME", 1*time.Minute),
		TokenRateLimit: getEnvAsInt("TOKEN_RATE_LIMIT", 100),
		TokenBlockTime: getEnvAsDuration("TOKEN_BLOCK_TIME", 1*time.Minute),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	valueStr := os.Getenv(key)
	if value, err := time.ParseDuration(valueStr); err == nil {
		return value
	}
	return defaultValue
}
