package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisStorage struct {
	client *redis.Client
	ctx    context.Context
}

func NewRedisStorage(addr, password string, db int) (*RedisStorage, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})

	ctx := context.Background()

	// Testa a conexão
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("falha ao conectar ao Redis: %w", err)
	}

	return &RedisStorage{
		client: client,
		ctx:    ctx,
	}, nil
}

func (r *RedisStorage) Increment(key string, expiration time.Duration) (int64, error) {
	pipe := r.client.Pipeline()

	incr := pipe.Incr(r.ctx, key)
	pipe.Expire(r.ctx, key, expiration)

	_, err := pipe.Exec(r.ctx)
	if err != nil {
		return 0, err
	}

	return incr.Val(), nil
}

func (r *RedisStorage) Get(key string) (int64, error) {
	val, err := r.client.Get(r.ctx, key).Int64()
	if err == redis.Nil {
		return 0, nil
	}
	return val, err
}

func (r *RedisStorage) IsBlocked(key string) (bool, error) {
	blockedKey := fmt.Sprintf("blocked:%s", key)
	exists, err := r.client.Exists(r.ctx, blockedKey).Result()
	return exists > 0, err
}

func (r *RedisStorage) Block(key string, duration time.Duration) error {
	blockedKey := fmt.Sprintf("blocked:%s", key)
	return r.client.Set(r.ctx, blockedKey, "1", duration).Err()
}

func (r *RedisStorage) Close() error {
	return r.client.Close()
}
