#!/bin/bash

# Script de teste de carga para o Rate Limiter
# Uso: ./scripts/load_test.sh

set -e

BASE_URL="${BASE_URL:-http://localhost:8080}"
IP_LIMIT="${IP_LIMIT:-10}"
TOKEN_LIMIT="${TOKEN_LIMIT:-10}"

echo "======================================"
echo "Rate Limiter - Teste de Carga"
echo "======================================"
echo "URL Base: $BASE_URL"
echo "Limite por IP: $IP_LIMIT req/s"
echo "Limite por Token: $TOKEN_LIMIT req/s"
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para fazer requisição e verificar status
make_request() {
    local url=$1
    local header=$2
    if [ -z "$header" ]; then
        curl -s -o /dev/null -w "%{http_code}" "$url"
    else
        curl -s -o /dev/null -w "%{http_code}" -H "$header" "$url"
    fi
}

# Teste 1: Limitação por IP
echo -e "${YELLOW}Teste 1: Limitação por IP${NC}"
echo "Fazendo $((IP_LIMIT + 5)) requisições sem token..."
echo ""

success_count=0
blocked_count=0
total_requests=$((IP_LIMIT + 5))

set +e
for i in $(seq 1 $total_requests)
 do
    status=$(make_request "$BASE_URL")

    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✓${NC} Request $i: OK (Status 200)"
        ((success_count++))
    elif [ "$status" == "429" ]; then
        echo -e "${RED}✗${NC} Request $i: BLOCKED (Status 429)"
        ((blocked_count++))
    else
        echo -e "${YELLOW}?${NC} Request $i: Unexpected Status $status"
    fi

    sleep 0.09
done
set -e

echo ""
echo "Resultado: $success_count sucesso, $blocked_count bloqueadas"
echo ""

# Aguarda reset (2 segundos para garantir nova janela)
echo "Aguardando 2 segundos para reset do contador..."
sleep 2
echo ""

# Teste 2: Limitação por Token
echo -e "${YELLOW}Teste 2: Limitação por Token${NC}"
echo "Fazendo 15 requisições com token 'test_token_123'..."
echo ""

success_count=0
blocked_count=0
test_limit=15

set +e
for i in $(seq 1 $test_limit)
 do
    status=$(make_request "$BASE_URL" "API_KEY: test_token_123")

    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✓${NC} Request $i: OK (Status 200)"
        ((success_count++))
    elif [ "$status" == "429" ]; then
        echo -e "${RED}✗${NC} Request $i: BLOCKED (Status 429)"
        ((blocked_count++))
    else
        echo -e "${YELLOW}?${NC} Request $i: Unexpected Status $status"
    fi

    sleep 0.09
done
set -e

echo ""
echo "Resultado: $success_count sucesso, $blocked_count bloqueadas"
echo ""

# Aguarda reset
echo "Aguardando 2 segundos para reset do contador..."
sleep 2
echo ""

# Teste 3: Token sobrepõe IP
echo -e "${YELLOW}Teste 3: Token sobrepõe IP${NC}"
echo "Primeiro bloqueando por IP, depois testando com token..."
echo ""

# Bloqueia o IP
echo "Bloqueando IP com $((IP_LIMIT + 1)) requisições sem token..."

set +e
for i in $(seq 1 $((IP_LIMIT + 1))); do
    status=$(make_request "$BASE_URL")
    if [ "$status" == "429" ]; then
        echo -e "${RED}✗${NC} IP bloqueado na requisição $i"
        break
    fi
    sleep 0.09
done
set -e

echo ""
echo "Agora fazendo requisições com token mesmo com IP bloqueado..."
echo ""

success_with_token=0

set +e
for i in $(seq 1 5); do
    status=$(make_request "$BASE_URL" "API_KEY: premium_token")

    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✓${NC} Request $i com token: OK (Status 200)"
        ((success_with_token++))
    else
        echo -e "${RED}✗${NC} Request $i com token: FALHOU (Status $status)"
    fi

    sleep 0.09
done
set -e

echo ""
if [ "$success_with_token" -gt 0 ]; then
    echo -e "${GREEN}✓ Token sobrepôs limitação de IP corretamente!${NC}"
else
    echo -e "${RED}✗ Token NÃO sobrepôs limitação de IP${NC}"
fi

echo ""
echo "======================================"
echo "Testes Concluídos!"
echo "======================================"