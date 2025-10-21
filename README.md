# Rate Limiter em Go

Sistema de rate limiting configurável para controlar o tráfego de requisições HTTP baseado em endereço IP ou token de acesso.

## Funcionalidades

- **Rate Limiting por IP**: Limita requisições por endereço IP
- **Rate Limiting por Token**: Limita requisições por token de acesso (header `API_KEY`)
- **Prioridade de Token**: Configurações de token sobrepõem as de IP
- **Bloqueio Temporário**: Bloqueia IP/Token após exceder o limite
- **Redis como Storage**: Persistência e consulta de dados no Redis
- **Pattern Strategy**: Fácil troca do Redis por outro mecanismo de persistência
- **Middleware Desacoplado**: Lógica de rate limiting separada do middleware
- **Configuração Flexível**: Via variáveis de ambiente ou arquivo `.env`

## Arquitetura

```
.
├── internal/
│   ├── config/         # Configurações da aplicação
│   ├── limiter/        # Lógica do rate limiter
│   ├── middleware/     # Middleware HTTP
│   └── storage/        # Interface e implementações de storage
├── test/              # Testes de integração
├── main.go            # Entry point da aplicação
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

### Componentes Principais

**Storage Interface**: Define contrato para persistência, permitindo trocar Redis por outro mecanismo facilmente.

**Rate Limiter**: Contém a lógica de limitação, separada do middleware HTTP.

**Middleware**: Injeta o rate limiter no pipeline HTTP, extraindo IP/Token e aplicando as regras.

## Como Executar

### Pré-requisitos

- Docker e Docker Compose instalados
- Go 1.21+ (apenas para desenvolvimento local)

### Executar com Docker Compose

1. Clone o repositório

2. Copie o arquivo de exemplo de configuração:
```bash
cp .env.example .env
```

3. Ajuste as configurações no arquivo `.env` conforme necessário

4. Inicie os serviços:
```bash
docker-compose up --build
```

O servidor estará disponível em `http://localhost:8080`

### Executar Localmente (Desenvolvimento)

1. Certifique-se de ter Redis rodando:
```bash
docker run -d -p 6379:6379 redis:7-alpine
```

2. Instale as dependências:
```bash
go mod download
```

3. Configure as variáveis de ambiente ou crie arquivo `.env`

4. Execute a aplicação:
```bash
go run main.go
```

## Configuração

Todas as configurações podem ser feitas via variáveis de ambiente ou arquivo `.env`:

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `REDIS_ADDR` | Endereço do Redis | `localhost:6379` |
| `REDIS_PASSWORD` | Senha do Redis | `` |
| `REDIS_DB` | Database do Redis | `0` |
| `IP_RATE_LIMIT` | Requisições por segundo por IP | `10` |
| `IP_BLOCK_TIME` | Tempo de bloqueio do IP | `5m` |
| `TOKEN_RATE_LIMIT` | Requisições por segundo por Token | `100` |
| `TOKEN_BLOCK_TIME` | Tempo de bloqueio do Token | `5m` |
| `PORT` | Porta do servidor | `8080` |

### Formato de Tempo

Use formato Go duration: `5m` (5 minutos), `1h` (1 hora), `30s` (30 segundos)

## Uso da API

### Requisição Normal (limitada por IP)

```bash
curl http://localhost:8080/
```

### Requisição com Token (limitada por token)

```bash
curl -H "API_KEY: seu_token_aqui" http://localhost:8080/
```

### Resposta de Sucesso

```
Status: 200 OK
Body: Hello! Request aceito.
```

### Resposta quando Limite Excedido

```
Status: 429 Too Many Requests
Body: {
  "error": "you have reached the maximum number of requests or actions allowed within a certain time frame"
}
```

## Testes

### Executar Testes Unitários

```bash
go test ./internal/limiter -v
```

### Executar Testes de Integração

```bash
go test ./test -v
```

### Executar Todos os Testes

```bash
go test ./... -v
```

### Teste de Carga Manual

Teste o rate limiter fazendo múltiplas requisições rapidamente:

```bash
# Teste por IP (10 requisições - deve bloquear após a 10ª)
for i in {1..15}; do
  curl http://localhost:8080/ && echo " - Request $i"
  sleep 0.1
done

# Teste por Token (100 requisições - deve bloquear após a 100ª)
for i in {1..105}; do
  curl -H "API_KEY: token123" http://localhost:8080/ && echo " - Request $i"
  sleep 0.01
done
```

## Trocando o Storage

A implementação usa o pattern Strategy para permitir fácil troca do Redis:

1. Implemente a interface `storage.Storage`:

```go
type Storage interface {
    Increment(key string, expiration time.Duration) (int64, error)
    Get(key string) (int64, error)
    IsBlocked(key string) (bool, error)
    Block(key string, duration time.Duration) error
    Close() error
}
```

2. Crie sua implementação (exemplo com Memcached, PostgreSQL, etc.)

3. No `main.go`, substitua:

```go
// Antes
store, err := storage.NewRedisStorage(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)

// Depois
store, err := storage.NewYourStorage(...)
```

## Exemplos de Cenários

### Cenário 1: Limitação por IP

- **Configuração**: `IP_RATE_LIMIT=5`, `IP_BLOCK_TIME=5m`
- **Comportamento**: IP `192.168.1.1` pode fazer 5 req/s. A 6ª requisição retorna 429. Novas requisições só após 5 minutos.

### Cenário 2: Limitação por Token

- **Configuração**: `TOKEN_RATE_LIMIT=10`, `TOKEN_BLOCK_TIME=5m`
- **Comportamento**: Token `abc123` pode fazer 10 req/s. A 11ª requisição retorna 429. Novas requisições só após 5 minutos.

### Cenário 3: Token Sobrepõe IP

- **Configuração**: `IP_RATE_LIMIT=10`, `TOKEN_RATE_LIMIT=100`
- **Comportamento**: Mesmo IP que atingiu limite sem token, pode fazer até 100 req/s com token válido.

## Tecnologias Utilizadas

- **Go 1.21+**: Linguagem de programação
- **Redis**: Armazenamento de dados do rate limiter
- **go-redis**: Cliente Redis para Go
- **godotenv**: Carregamento de variáveis de ambiente
- **testify**: Framework de testes

## Estrutura do Código

### Separação de Responsabilidades

- **Config**: Carrega e valida configurações
- **Storage**: Interface de persistência (Strategy Pattern)
- **Limiter**: Lógica de rate limiting (independente de HTTP)
- **Middleware**: Integração com HTTP (extrai IP/Token, aplica limiter)

Esta arquitetura permite:
- Testar o limiter sem HTTP
- Trocar storage facilmente
- Reusar o limiter em diferentes contextos (HTTP, gRPC, etc.)