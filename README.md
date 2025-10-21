# Rate Limiter Activity - Go

[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?style=flat&logo=go)](https://golang.org)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)](https://www.docker.com/)
[![Redis](https://img.shields.io/badge/Redis-7.0-DC382D?style=flat&logo=redis)](https://redis.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Sistema de **Rate Limiting** configurável para controlar o tráfego de requisições HTTP baseado em endereço IP ou token de acesso (header `API_KEY`).

---

## 📋 Índice

- [Sobre o Projeto](#-sobre-o-projeto)
- [Funcionalidades](#-funcionalidades)
- [Arquitetura](#-arquitetura)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Como Executar](#-como-executar)
- [Testes](#-testes)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Análise Técnica](#-análise-técnica)
- [API e Uso](#-api-e-uso)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Sobre o Projeto

Sistema de rate limiting desenvolvido em Go que implementa controle de taxa de requisições através de duas estratégias:

1. **Rate Limiting por IP**: Controla requisições baseadas no endereço IP do cliente
2. **Rate Limiting por Token**: Controla requisições através de token de acesso (header `API_KEY`)

### Características Principais

- ⚡ **Alta Performance**: Latência adicional < 5ms por requisição
- 🔐 **Prioridade de Token**: Configurações de token sobrepõem as de IP
- 🚫 **Bloqueio Temporário**: Bloqueia IP/Token após exceder o limite
- 📊 **Redis como Storage**: Persistência distribuída e escalável
- 🔄 **Pattern Strategy**: Fácil troca do Redis por outro mecanismo
- 🧩 **Middleware Desacoplado**: Lógica de rate limiting separada do middleware HTTP
- ⚙️ **Configuração Flexível**: Via variáveis de ambiente ou arquivo `.env`

---

## ✨ Funcionalidades

### Rate Limiting por IP

```
┌─────────────────────────────────────┐
│   Limitação por Endereço IP         │
├─────────────────────────────────────┤
│ • Limite padrão: 10 req/segundo     │
│ • Bloqueio: 5 minutos (padrão)      │
│ • Extração automática de IP real    │
│ • Suporte a X-Forwarded-For         │
│ • Suporte a X-Real-IP               │
│ • Contador por janela de 1 segundo  │
└─────────────────────────────────────┘
```

**Como funciona:**
- Sistema extrai o IP do cliente (considerando proxies)
- Incrementa contador no Redis com chave `ip:{endereço}`
- Se exceder o limite, bloqueia com chave `blocked:ip:{endereço}`
- Após o tempo de bloqueio, permite novas requisições

### Rate Limiting por Token

```
┌─────────────────────────────────────┐
│   Limitação por API Token           │
├─────────────────────────────────────┤
│ • Limite padrão: 100 req/segundo    │
│ • Bloqueio: 5 minutos (padrão)      │
│ • Header: API_KEY                   │
│ • Prioridade sobre limite de IP     │
│ • Contador independente por token   │
│ • Suporte a múltiplos tokens        │
└─────────────────────────────────────┘
```

**Como funciona:**
- Cliente envia token no header `API_KEY`
- Sistema usa limite de token (maior que IP)
- Contador independente: `token:{valor}`
- Bloqueio: `blocked:token:{valor}`

---

## 🏗️ Arquitetura

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────┐
│                    HTTP Request                          │
│           (IP: 192.168.1.1, Header: API_KEY)            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              RateLimitMiddleware                         │
│          (internal/middleware/raterlimiter.go)           │
├─────────────────────────────────────────────────────────┤
│  1. Extrai token do header API_KEY                      │
│  2. Se token presente → usa CheckToken()                │
│  3. Se não → extrai IP → usa CheckIP()                  │
│  4. Retorna 200 OK ou 429 Too Many Requests             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  RateLimiter                             │
│              (internal/limiter/limiter.go)               │
├─────────────────────────────────────────────────────────┤
│  • CheckIP(ip string) → verifica limite por IP          │
│  • CheckToken(token string) → verifica limite por token │
│  • Retorna LimitResult{Allowed: bool, Reason: string}   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Storage Interface                           │
│            (internal/storage/storage.go)                 │
├─────────────────────────────────────────────────────────┤
│  • Increment(key, ttl) → incrementa contador            │
│  • Get(key) → obtém valor atual                         │
│  • IsBlocked(key) → verifica se está bloqueado          │
│  • Block(key, duration) → bloqueia chave                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│             RedisStorage                                 │
│          (internal/storage/redis.go)                     │
├─────────────────────────────────────────────────────────┤
│  Redis Keys:                                            │
│  • ip:192.168.1.1 → contador de requisições             │
│  • blocked:ip:192.168.1.1 → flag de bloqueio            │
│  • token:abc123 → contador de requisições               │
│  • blocked:token:abc123 → flag de bloqueio              │
│                                                          │
│  TTL: 1 segundo para contadores                         │
│  TTL: 5 minutos (padrão) para bloqueios                 │
└─────────────────────────────────────────────────────────┘
```

### Fluxo de Decisão

```
┌─────────────────────────────────────────────────────────┐
│                 Request Recebido                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
            ┌────────────────┐
            │ Header API_KEY │
            │   presente?    │
            └───┬────────┬───┘
                │        │
         NÃO ◄──┘        └──► SIM
                │            │
                ▼            ▼
        ┌───────────┐  ┌────────────┐
        │ CheckIP() │  │CheckToken()│
        └─────┬─────┘  └──────┬─────┘
              │               │
              └───────┬───────┘
                      │
                      ▼
            ┌──────────────────┐
            │ Está bloqueado?  │
            └────┬────────┬────┘
                 │        │
          SIM ◄──┘        └──► NÃO
                 │            │
                 ▼            ▼
        ┌────────────┐  ┌──────────────┐
        │ Retorna    │  │ Incrementa   │
        │ 429 + msg  │  │ contador     │
        └────────────┘  └──────┬───────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │ Excedeu limite?  │
                    └────┬────────┬────┘
                         │        │
                  SIM ◄──┘        └──► NÃO
                         │            │
                         ▼            ▼
                ┌────────────┐  ┌────────────┐
                │ Bloqueia + │  │ Retorna    │
                │ Retorna    │  │ 200 OK     │
                │ 429        │  └────────────┘
                └────────────┘
```

---

## 📦 Pré-requisitos

### Obrigatórios

| Ferramenta | Versão | Verificação |
|------------|--------|-------------|
| **Docker** | 20.10+ | `docker --version` |
| **Docker Compose** | 2.0+ | `docker compose version` |

### Opcionais (para desenvolvimento local)

| Ferramenta | Versão | Uso |
|------------|--------|-----|
| **Go** | 1.24+ | Desenvolvimento local |
| **Make** | 4.0+ | Automação de comandos |
| **curl** | 7.0+ | Testes manuais |
| **Redis CLI** | 7.0+ | Debug |

### Verificação Rápida

```bash
# Verificar Docker
docker --version

# Verificar Docker Compose
docker compose version

# Verificar Go (opcional)
go version

# Verificar Make (opcional)
make --version
```

---

## 🚀 Instalação

### Método 1: Script Automatizado ⭐ (Recomendado)

O script `script_setup.sh` configura todo o ambiente automaticamente.

```bash
# 1. Clone o repositório
git clone https://github.com/DiegoJCordeiro/rater-limiter-activity-go.git
cd rater-limiter-activity-go

# 2. Execute o script de setup
chmod +x script_setup.sh
./script_setup.sh
```

**O que o script faz:**

```
✓ Verifica Docker e Docker Compose instalados
✓ Verifica Go (opcional)
✓ Cria arquivo .env com configurações padrão
✓ Permite customizar configurações interativamente
✓ Baixa dependências Go (se disponível)
✓ Constrói imagens Docker
✓ Inicia containers (app + redis)
✓ Aguarda serviços ficarem prontos
✓ Verifica health dos serviços
✓ Executa teste rápido (opcional)
```

**Saída esperada:**

```
╔════════════════════════════════════════╗
║   Rate Limiter - Setup Automático     ║
╚════════════════════════════════════════╝

📋 Verificando pré-requisitos...

✓ Docker instalado: Docker version 24.0.6
✓ Docker Compose instalado
✓ Go instalado: go1.24.1

📝 Configurando ambiente...
✓ Arquivo .env criado com configurações padrão

🐳 Iniciando containers Docker...
✓ Containers iniciados com sucesso!

⏳ Aguardando serviços ficarem prontos...
✓ Redis pronto
✓ Aplicação pronta

╔════════════════════════════════════════╗
║        Setup Concluído! 🎉            ║
╚════════════════════════════════════════╝

📍 Serviços rodando:
   • Aplicação: http://localhost:8080
   • Redis: localhost:6379
```

---

### Método 2: Docker Compose Manual

```bash
# 1. Clone o repositório
git clone https://github.com/DiegoJCordeiro/rater-limiter-activity-go.git
cd rater-limiter-activity-go

# 2. Crie arquivo .env (opcional)
cat > .env << EOF
REDIS_ADDR=redis:6379
REDIS_PASSWORD=
REDIS_DB=0
IP_RATE_LIMIT=10
IP_BLOCK_TIME=5m
TOKEN_RATE_LIMIT=100
TOKEN_BLOCK_TIME=5m
PORT=8080
EOF

# 3. Inicie os containers
docker compose up -d --build

# 4. Verifique os logs
docker compose logs -f

# 5. Teste a aplicação
curl http://localhost:8080/
```

---

### Método 3: Makefile

```bash
# 1. Clone o repositório
git clone https://github.com/DiegoJCordeiro/rater-limiter-activity-go.git
cd rater-limiter-activity-go

# 2. Ver comandos disponíveis
make help

# 3. Instalar dependências (se Go instalado)
make deps

# 4. Subir containers
make docker-up

# 5. Ver logs
make docker-logs
```

**Comandos Make disponíveis:**

```bash
make help              # Mostra ajuda com todos os comandos
make build             # Compila a aplicação
make run               # Executa localmente
make tests              # Executa todos os testes
make tests-unit         # Testes unitários
make tests-integration  # Testes de integração
make tests-coverage     # Relatório de cobertura
make docker-up         # Sobe containers
make docker-down       # Para containers
make docker-logs       # Mostra logs
make docker-restart    # Reinicia containers
make clean             # Remove arquivos gerados
make deps              # Instala dependências
make load-tests         # Teste de carga básico
```

---

### Método 4: Desenvolvimento Local (sem Docker)

```bash
# 1. Certifique-se de ter Redis rodando
docker run -d -p 6379:6379 redis:7-alpine

# 2. Clone e entre no diretório
git clone https://github.com/DiegoJCordeiro/rater-limiter-activity-go.git
cd rater-limiter-activity-go

# 3. Instale dependências
go mod download

# 4. Configure variáveis de ambiente
export REDIS_ADDR=localhost:6379
export REDIS_PASSWORD=
export REDIS_DB=0
export IP_RATE_LIMIT=10
export IP_BLOCK_TIME=5m
export TOKEN_RATE_LIMIT=100
export TOKEN_BLOCK_TIME=5m
export PORT=8080

# 5. Execute a aplicação
go run cmd/rater-limiter-activity/rater-limiter-activity.go

# Ou compile e execute
go build -o bin/ratelimiter cmd/rater-limiter-activity/rater-limiter-activity.go
./bin/ratelimiter
```

---

## ⚙️ Configuração

### Variáveis de Ambiente

Todas as configurações podem ser feitas via variáveis de ambiente ou arquivo `.env`:

```env
# Configurações do Redis
REDIS_ADDR=localhost:6379        # Endereço do Redis
REDIS_PASSWORD=                  # Senha (vazio por padrão)
REDIS_DB=0                       # Database number

# Configurações de Rate Limiting por IP
IP_RATE_LIMIT=10                 # Requisições por segundo
IP_BLOCK_TIME=5m                 # Tempo de bloqueio (formato: 1s, 5m, 1h)

# Configurações de Rate Limiting por Token
TOKEN_RATE_LIMIT=100             # Requisições por segundo
TOKEN_BLOCK_TIME=5m              # Tempo de bloqueio

# Configurações do Servidor
PORT=8080                        # Porta do servidor HTTP
```

### Formato de Tempo (Duration)

Use o formato Go duration:

| Formato | Significado |
|---------|-------------|
| `30s` | 30 segundos |
| `5m` | 5 minutos |
| `1h` | 1 hora |
| `24h` | 24 horas |
| `1h30m` | 1 hora e 30 minutos |

### Tabela de Configurações

| Variável | Descrição | Padrão | Exemplo |
|----------|-----------|--------|---------|
| `REDIS_ADDR` | Endereço do Redis | `localhost:6379` | `redis:6379` |
| `REDIS_PASSWORD` | Senha do Redis | `` | `secret123` |
| `REDIS_DB` | Database do Redis | `0` | `0` |
| `IP_RATE_LIMIT` | Req/s por IP | `10` | `20` |
| `IP_BLOCK_TIME` | Bloqueio de IP | `5m` | `10m` |
| `TOKEN_RATE_LIMIT` | Req/s por Token | `100` | `200` |
| `TOKEN_BLOCK_TIME` | Bloqueio de Token | `5m` | `15m` |
| `PORT` | Porta do servidor | `8080` | `3000` |

---

## 🏃 Como Executar

### Iniciar Aplicação

```bash
# Com Docker Compose
docker compose up -d

# Ver logs em tempo real
docker compose logs -f

# Ver apenas logs da aplicação
docker compose logs -f app

# Parar aplicação
docker compose down
```

### Verificar Status

```bash
# Status dos containers
docker compose ps

# Teste rápido
curl http://localhost:8080/

# Resposta esperada: "Hello! Request aceito."
```

### Comandos Úteis

```bash
# Reiniciar aplicação
docker compose restart app

# Reiniciar Redis
docker compose restart redis

# Ver logs do Redis
docker compose logs redis

# Parar e remover volumes
docker compose down -v

# Reconstruir imagens
docker compose up --build -d

# Executar comando no container
docker compose exec app sh
```

---

## 🧪 Testes

### Estrutura de Testes

```
tests/
├── scripts/
│   └── script_tests.sh       # Script automatizado de testes
└── requests/
    ├── ip_tests.http         # Testes manuais por IP
    └── token_tests.http      # Testes manuais por Token
```

---

### Teste 1: Script Automatizado ⭐ (Recomendado)

O script `script_tests.sh` executa uma bateria completa de testes.

```bash
# Tornar executável
chmod +x tests/scripts/script_tests.sh

# Executar todos os testes
./tests/scripts/script_tests.sh
```

**O que o script testa:**

```
══════════════════════════════════════
Rate Limiter - Teste de Carga
══════════════════════════════════════

✓ Teste 1: Limitação por IP
  - Faz 15 requisições sem token
  - Verifica bloqueio após 10ª requisição
  - Confirma mensagem 429

✓ Teste 2: Limitação por Token
  - Faz 15 requisições com token
  - Verifica que permite mais requisições
  - Testa limite de 100 req/s

✓ Teste 3: Token sobrepõe IP
  - Bloqueia IP primeiro
  - Faz requisições com token
  - Confirma que token bypassa bloqueio de IP
```

**Saída esperada:**

```bash
====================================== Rate Limiter - Teste de Carga
======================================
URL Base: http://localhost:8080
Limite por IP: 10 req/s
Limite por Token: 100 req/s

Teste 1: Limitação por IP
Fazendo 15 requisições sem token...

✓ Request 1: OK (Status 200)
✓ Request 2: OK (Status 200)
✓ Request 3: OK (Status 200)
...
✓ Request 10: OK (Status 200)
✗ Request 11: BLOCKED (Status 429)
✗ Request 12: BLOCKED (Status 429)

Resultado: 10 sucesso, 5 bloqueadas

Aguardando 2 segundos para reset do contador...

Teste 2: Limitação por Token
Fazendo 15 requisições com token 'test_token_123'...

✓ Request 1: OK (Status 200)
✓ Request 2: OK (Status 200)
...
✓ Request 15: OK (Status 200)

Resultado: 15 sucesso, 0 bloqueadas

Teste 3: Token sobrepõe IP
Primeiro bloqueando por IP, depois testando com token...

Bloqueando IP com 11 requisições sem token...
✗ IP bloqueado na requisição 11

Agora fazendo requisições com token mesmo com IP bloqueado...

✓ Request 1 com token: OK (Status 200)
✓ Request 2 com token: OK (Status 200)
✓ Request 3 com token: OK (Status 200)
✓ Request 4 com token: OK (Status 200)
✓ Request 5 com token: OK (Status 200)

✓ Token sobrepôs limitação de IP corretamente!

======================================
Testes Concluídos!
======================================
```

---

### Teste 2: Testes Manuais com HTTP Files

Use os arquivos `.http` com REST Client (VS Code) ou IntelliJ HTTP Client.

#### Teste de Limitação por IP

Arquivo: `tests/requests/ip_tests.http`

```http
### Teste 1: Requisições sem token (limite de IP = 10)
GET http://localhost:8080/

### Teste 2: Segunda requisição
GET http://localhost:8080/

### ... (repita até 10 vezes)

### Teste 11: Deve retornar 429
GET http://localhost:8080/
```

**Como usar:**

1. Abra `tests/requests/ip_tests.http` no VS Code
2. Instale a extensão "REST Client"
3. Clique em "Send Request" acima de cada requisição
4. Observe os status codes

**Comportamento esperado:**

- Requisições 1-10: `200 OK`
- Requisições 11+: `429 Too Many Requests`

#### Teste de Limitação por Token

Arquivo: `tests/requests/token_tests.http`

```http
### Teste com token (limite de token = 100)
GET http://localhost:8080/
API_KEY: test_token_123

### Segunda requisição com token
GET http://localhost:8080/
API_KEY: test_token_123
```

**Comportamento esperado:**

- Token permite até 100 requisições/segundo
- Muito mais que o limite de IP (10)

---

### Teste 3: Testes com curl

#### Teste Básico de IP

```bash
# Fazer 15 requisições rapidamente
for i in {1..15}; do
  echo "Request $i:"
  curl -i http://localhost:8080/
  echo ""
  sleep 0.1
done
```

**Resultado esperado:**

```
Request 1:
HTTP/1.1 200 OK
Hello! Request aceito.

...

Request 10:
HTTP/1.1 200 OK
Hello! Request aceito.

Request 11:
HTTP/1.1 429 Too Many Requests
{"error": "you have reached the maximum number of requests or actions allowed within a certain time frame"}
```

#### Teste com Token

```bash
# Fazer requisições com token
for i in {1..15}; do
  echo "Request $i com token:"
  curl -H "API_KEY: test_token_123" http://localhost:8080/
  echo ""
  sleep 0.1
done
```

#### Teste de Prioridade Token > IP

```bash
# 1. Bloquear IP
echo "Bloqueando IP..."
for i in {1..12}; do
  curl -s http://localhost:8080/ > /dev/null
done

# 2. Tentar sem token (deve estar bloqueado)
echo "Tentando sem token (bloqueado):"
curl -i http://localhost:8080/

# 3. Tentar com token (deve funcionar)
echo ""
echo "Tentando com token (deve funcionar):"
curl -i -H "API_KEY: premium_token" http://localhost:8080/
```

---

### Teste 4: Testes com Makefile

```bash
# Teste de carga básico
make load-tests

# Testes unitários
make tests-unit

# Todos os testes
make tests

# Com cobertura
make tests-coverage
```

---

### Teste 5: Testes Unitários Go

```bash
# Executar todos os testes
go tests ./... -v

# Testes com cobertura
go tests ./... -cover

# Relatório HTML de cobertura
go tests ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

**Saída esperada:**

```
?   	github.com/DiegoJCordeiro/rater-limiter-activity-go/cmd/server	[no test files]
ok  	github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/config	0.002s
ok  	github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/limiter	0.015s
ok  	github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/middleware	0.012s
ok  	github.com/DiegoJCordeiro/rater-limiter-activity-go/internal/storage	0.025s
```

---

### Teste 6: Teste de Carga com Apache Bench

```bash
# Instalar Apache Bench (se necessário)
# Ubuntu/Debian: sudo apt-get install apache2-utils
# macOS: brew install apache-bench

# Teste de carga - 1000 requisições, 10 concorrentes
ab -n 1000 -c 10 http://localhost:8080/

# Com token
ab -n 1000 -c 10 -H "API_KEY: test_token" http://localhost:8080/
```

---

## 📂 Estrutura do Projeto

```
rater-limiter-activity-go/
├── cmd/
│   └── server/
│       └── main.go                 # Entry point da aplicação
│
├── internal/
│   ├── config/
│   │   └── config.go               # Carregamento de configurações
│   │
│   ├── limiter/
│   │   └── limiter.go              # Lógica de rate limiting
│   │
│   ├── middleware/
│   │   └── raterlimiter.go         # Middleware HTTP
│   │
│   └── storage/
│       ├── storage.go              # Interface Storage
│       └── redis.go                # Implementação Redis
│
├── tests/
│   ├── requests/
│   │   ├── ip_tests.http           # Testes HTTP por IP
│   │   └── token_tests.http        # Testes HTTP por Token
│   │
│   └── scripts/
│       └── script_tests.sh         # Script de teste automatizado
│
├── .env                            # Configurações (não versionado)
├── .env.example                    # Exemplo de configuração
├── .gitignore                      # Arquivos ignorados pelo Git
├── docker-compose.yml              # Orquestração de containers
├── Dockerfile                      # Imagem da aplicação
├── go.mod                          # Dependências Go
├── go.sum                          # Checksums das dependências
├── LICENSE                         # Licença MIT
├── Makefile                        # Automação de tarefas
├── README.md                       # Este arquivo
└── script_setup.sh                 # Script de instalação
```

### Descrição dos Componentes

#### `/cmd/server/main.go`

Ponto de entrada da aplicação. Responsabilidades:

- Carregar variáveis de ambiente
- Inicializar storage (Redis)
- Criar instância do rate limiter
- Configurar rotas e middleware
- Iniciar servidor HTTP

#### `/internal/config/config.go`

Gerenciamento de configurações:

```go
type Config struct {
    RedisAddr      string        // Endereço do Redis
    RedisPassword  string        // Senha do Redis
    RedisDB        int           // Database number
    IPRateLimit    int           // Requisições por segundo (IP)
    IPBlockTime    time.Duration // Tempo de bloqueio (IP)
    TokenRateLimit int           // Requisições por segundo (Token)
    TokenBlockTime time.Duration // Tempo de bloqueio (Token)
}
```

#### `/internal/limiter/limiter.go`

Lógica central de rate limiting:

```go
type RateLimiter struct {
    storage storage.Storage
    config  *config.Config
}

// Verifica se IP pode fazer requisições
func (rl *RateLimiter) CheckIP(ip string) (*LimitResult, error)

// Verifica se Token pode fazer requisições
func (rl *RateLimiter) CheckToken(token string) (*LimitResult, error)
```

**Fluxo de CheckIP/CheckToken:**

1. Verifica se chave está bloqueada (`blocked:ip:{ip}` ou `blocked:token:{token}`)
2. Se bloqueado, retorna `Allowed: false`
3. Se não bloqueado, incrementa contador no Redis
4. Se contador > limite, bloqueia a chave
5. Retorna resultado da verificação

#### `/internal/middleware/raterlimiter.go`

Middleware HTTP que integra rate limiter:

```go
func RateLimitMiddleware(rateLimiter *limiter.RateLimiter) func(http.Handler) http.Handler
```

**Lógica:**

1. Verifica se existe header `API_KEY`
2. Se sim, usa `CheckToken(token)`
3. Se não, extrai IP e usa `CheckIP(ip)`
4. Se não permitido, retorna `429 Too Many Requests`
5. Se permitido, chama próximo handler

**Extração de IP:**

- Prioriza `X-Forwarded-For` (primeiro IP da lista)
- Depois `X-Real-IP`