package config

import (
	"github.com/spf13/viper"
	"time"
)

type TokenLimit struct {
	LimitPerSecond int           `mapstructure:"limit_per_second"`
	BlockFor       time.Duration `mapstructure:"block_for"`
}

type Config struct {
	RedisAddr     string `mapstructure:"redis_addr"`
	RedisDB       int    `mapstructure:"redis_db"`
	RedisUsername string `mapstructure:"redis_username"`
	RedisPassword string `mapstructure:"redis_password"`
}

func setDefaultValues() {
	viper.SetDefault("http_port", 8080)
	viper.SetDefault("redis_addr", "localhost:6379")
	viper.SetDefault("redis_db", 0)
}

func Load() (*Config, error) {
	viper.SetConfigName(".env")
	viper.SetConfigType("env")
	viper.AddConfigPath(".")
	viper.AutomaticEnv()
	setDefaultValues()
	_ = viper.ReadInConfig()

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
