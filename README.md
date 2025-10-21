# Rate Limiter em Go com Redis

Sistema de controle de taxa de requisições (rate limiting) implementado em Go, com suporte para limitação por IP e por token de acesso, utilizando Redis como mecanismo de persistência.

## 🚀 Características

- **Limitação por IP**: Controla requisições por endereço IP
- **Limitação por Token**: Permite limites customizados por token de acesso
- **Prioridade de Token**: Configurações de token sobrepõem as de IP
- **Redis como Storage**: Persistência eficiente com suporte a TTL
- **Strategy Pattern**: Fácil substituição do mecanismo de persistência
- **Middleware HTTP**: Integração simples com servidores web Go
- **Docker Ready**: Configuração completa com Docker Compose
- **Bloqueio Temporário**: IPs/tokens bloqueados após exceder o limite
- **Configuração Flexível**: Variáveis de ambiente ou arquivo .env

## 📋 Requisitos

- Docker e Docker Compose
- Go 1.21+ (para desenvolvimento local)

## 🏗️ Arquitetura

```
.
├── cmd/
│   └── server/
│       └── main.go              # Ponto de entrada da aplicação
├── internal/
│   ├── limiter/
│   │   ├── limiter.go           # Lógica principal do rate limiter
│   │   └── limiter_test.go      # Testes unitários
│   ├── middleware/
│   │   └── ratelimit.go         # Middleware HTTP
│   └── storage/
│       ├── storage.go           # Interface de Storage
│       └── redis.go             # Implementação Redis
├── test/
│   └── integration_test.go      # Testes de integração
├── docker-compose.yml
├── Dockerfile
├── .env.example
├── go.mod
└── README.md
```

### Componentes Principais

1. **Limiter**: Contém a lógica de rate limiting
2. **Storage**: Interface para persistência (implementação Redis)
3. **Middleware**: Intercepta requisições HTTP
4. **Config**: Gerenciamento de configurações

## ⚙️ Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto (ou use variáveis de ambiente):

```bash
# Redis
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=
REDIS_DB=0

# Limite por IP
RATE_LIMIT_IP_RPS=5                    # Requisições por segundo
RATE_LIMIT_BLOCK_DURATION=300          # Duração do bloqueio em segundos (5 minutos)

# Limites por Token
TOKEN_ABC123_RPS=100
TOKEN_ABC123_BLOCK_DURATION=300

TOKEN_XYZ789_RPS=50
TOKEN_XYZ789_BLOCK_DURATION=600
```

### Configuração de Tokens

Para adicionar novos tokens, adicione as variáveis de ambiente no formato:

```bash
TOKEN_<NOME_DO_TOKEN>_RPS=<requisições_por_segundo>
TOKEN_<NOME_DO_TOKEN>_BLOCK_DURATION=<duração_bloqueio_em_segundos>
```

## 🐳 Executando com Docker

### 1. Iniciar os serviços

```bash
docker-compose up -d
```

Isso irá:

- Iniciar um container Redis na porta 6379
- Construir e iniciar a aplicação na porta 8080

### 2. Verificar os logs

```bash
docker-compose logs -f app
```

### 3. Parar os serviços

```bash
docker-compose down
```

## 🧪 Testando a Aplicação

### Teste manual com curl

**Requisição normal (sem token):**

```bash
curl http://localhost:8080/
```

**Requisição com token:**

```bash
curl -H "API_KEY: abc123" http://localhost:8080/
```

**Teste de limite por IP:**

```bash
# Execute 6 vezes rapidamente
for i in {1..6}; do
  curl http://localhost:8080/
  echo ""
done
```

Resultado esperado: As primeiras 5 requisições retornam 200 OK, a 6ª retorna 429.

**Teste de limite por Token:**

```bash
# Execute 11 vezes com o token abc123 (limite de 10 req/s)
for i in {1..11}; do
  curl -H "API_KEY: abc123" http://localhost:8080/
  echo ""
done
```

### Executar testes automatizados

**Testes unitários:**

```bash
go test ./internal/limiter -v
```

**Testes de integração:**

```bash
# Certifique-se de que o Redis está rodando
docker-compose up -d redis

# Execute os testes
go test ./test -v
```

## 📊 Como Funciona

### Fluxo de Requisição

1. **Requisição chega** ao servidor HTTP
2. **Middleware intercepta** a requisição
3. **Extrai identificador**:
    - Se header `API_KEY` presente → usa token
    - Caso contrário → usa IP da requisição
4. **Verifica bloqueio**:
    - Se bloqueado → retorna 429
5. **Incrementa contador** no Redis com TTL de 1 segundo
6. **Compara com limite**:
    - Dentro do limite → permite requisição
    - Excede limite → bloqueia identificador e retorna 429

### Chaves Redis

O sistema usa as seguintes chaves no Redis:

- `ratelimit:ip:<IP>` - Contador de requisições por IP
- `ratelimit:token:<TOKEN>` - Contador de requisições por token
- `ratelimit:block:ip:<IP>` - Flag de bloqueio de IP
- `ratelimit:block:token:<TOKEN>` - Flag de bloqueio de token

### Exemplo de Comportamento

**Cenário 1: Limitação por IP**

- Limite: 5 req/s
- Duração de bloqueio: 300s (5 minutos)
- IP `192.168.1.1` faz 6 requisições em 1 segundo
- Resultado: Primeiras 5 aceitas, 6ª bloqueada
- Próxima requisição permitida: Após 300 segundos

**Cenário 2: Token sobrepõe IP**

- Limite IP: 5 req/s
- Limite Token `abc123`: 100 req/s
- IP já bloqueado por exceder limite
- Requisição com token `abc123`: **Permitida** (token tem prioridade)

## 🔧 Desenvolvimento Local

### Instalar dependências

```bash
go mod download
```

### Executar localmente

```bash
# Inicie o Redis
docker-compose up -d redis

# Execute a aplicação
go run main.go
```

### Implementar novo Storage

Para usar outro banco de dados além do Redis, implemente a interface `Storage`:

```go
type Storage interface {
    Increment(key string, ttl time.Duration) (int64, error)
    Get(key string) (int64, error)
    SetBlock(key string, ttl time.Duration) error
    IsBlocked(key string) (bool, error)
    Close() error
}
```

Exemplo com Memcached, MongoDB, ou qualquer outro banco:

```go
// internal/storage/memcached.go
type MemcachedStorage struct {
    // implementação
}

func (m *MemcachedStorage) Increment(key string, ttl time.Duration) (int64, error) {
    // sua implementação
}
// ... outros métodos
```

## 🎯 Casos de Uso

### API Pública

- Limite por IP para prevenir abuso
- Rate limiting justo para todos os usuários

### API com Autenticação

- Limites diferenciados por plano (free, premium, enterprise)
- Tokens com limites customizados

### Proteção contra DDoS

- Bloqueio temporário de IPs maliciosos
- Limite agressivo para requisições sem autenticação

## 📈 Performance

- **Redis**: Operações O(1) para increment e get
- **Overhead**: ~1-2ms por requisição
- **Capacidade**: Suporta milhares de requisições por segundo
- **Memória**: ~100 bytes por IP/token ativo

## 🔒 Segurança

- IPs extraídos considerando headers de proxy (X-Forwarded-For, X-Real-IP)
- Tokens validados antes do processamento
- Bloqueios com TTL automático
- Sem armazenamento de dados sensíveis

## 🐛 Troubleshooting

**Erro: Cannot connect to Redis**

```bash
# Verifique se o Redis está rodando
docker-compose ps

# Verifique os logs do Redis
docker-compose logs redis
```

**Limites não funcionando**

```bash
# Verifique as variáveis de ambiente
docker-compose config

# Limpe o Redis
docker-compose exec redis redis-cli FLUSHALL
```

## 📝 Licença

Este projeto é fornecido como exemplo educacional.

## 👥 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## 📞 Suporte

Para questões e suporte, abra uma issue no repositório.