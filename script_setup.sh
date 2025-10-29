#!/bin/bash

# Script de setup automático para o Rate Limiter
# Uso: ./scripts/script_setup.sh

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   Rate Limiter - Setup Automático     ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar pré-requisitos
echo -e "${YELLOW}📋 Verificando pré-requisitos...${NC}"
echo ""

if command_exists docker; then
    echo -e "${GREEN}✓${NC} Docker instalado: $(docker --version)"
else
    echo -e "${RED}✗${NC} Docker não encontrado!"
    echo "   Por favor, instale Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose instalado"
else
    echo -e "${RED}✗${NC} Docker Compose não encontrado!"
    echo "   Por favor, instale Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

if command_exists go; then
    echo -e "${GREEN}✓${NC} Go instalado: $(go version)"
else
    echo -e "${YELLOW}⚠${NC} Go não instalado (opcional para desenvolvimento)"
fi

if command_exists curl; then
    echo -e "${GREEN}✓${NC} curl instalado"
else
    echo -e "${YELLOW}⚠${NC} curl não instalado (recomendado para testes)"
fi

echo ""

# Criar arquivo .env se não existir
echo -e "${YELLOW}📝 Configurando ambiente...${NC}"
if [ ! -f .env ]; then
    echo -e "${BLUE}→${NC} Criando arquivo .env..."
    cp .env .env
    echo -e "${GREEN}✓${NC} Arquivo .env criado com configurações padrão"
else
    echo -e "${GREEN}✓${NC} Arquivo .env já existe"
fi

echo ""

# Perguntar se quer customizar configurações
echo -e "${YELLOW}⚙️  Configurações:${NC}"
echo ""
read -p "Deseja customizar as configurações agora? (s/n): " customize

if [[ $customize =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${BLUE}Configuração do Rate Limit por IP:${NC}"
    read -p "  Requisições por segundo (padrão: 10): " ip_limit
    read -p "  Tempo de bloqueio (padrão: 5m): " ip_block

    echo ""
    echo -e "${BLUE}Configuração do Rate Limit por Token:${NC}"
    read -p "  Requisições por segundo (padrão: 100): " token_limit
    read -p "  Tempo de bloqueio (padrão: 5m): " token_block

    # Atualizar .env
    if [ ! -z "$ip_limit" ]; then
        sed -i.bak "s/IP_RATE_LIMIT=.*/IP_RATE_LIMIT=$ip_limit/" .env
    fi
    if [ ! -z "$ip_block" ]; then
        sed -i.bak "s/IP_BLOCK_TIME=.*/IP_BLOCK_TIME=$ip_block/" .env
    fi
    if [ ! -z "$token_limit" ]; then
        sed -i.bak "s/TOKEN_RATE_LIMIT=.*/TOKEN_RATE_LIMIT=$token_limit/" .env
    fi
    if [ ! -z "$token_block" ]; then
        sed -i.bak "s/TOKEN_BLOCK_TIME=.*/TOKEN_BLOCK_TIME=$token_block/" .env
    fi

    rm -f .env.bak
    echo -e "${GREEN}✓${NC} Configurações atualizadas"
else
    echo -e "${BLUE}→${NC} Usando configurações padrão"
fi

echo ""

# Baixar dependências Go (se Go estiver instalado)
if command_exists go; then
    echo -e "${YELLOW}📦 Baixando dependências Go...${NC}"
    go mod download
    echo -e "${GREEN}✓${NC} Dependências baixadas"
    echo ""
fi

# Construir e iniciar containers
echo -e "${YELLOW}🐳 Iniciando containers Docker...${NC}"
echo ""

docker-compose down -v 2>/dev/null || true
docker-compose up -d --build

echo ""
echo -e "${GREEN}✓${NC} Containers iniciados com sucesso!"
echo ""

# Aguardar serviços ficarem prontos
echo -e "${YELLOW}⏳ Aguardando serviços ficarem prontos...${NC}"
sleep 3

# Verificar se Redis está respondendo
if docker exec ratelimiter-redis redis-cli PING >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Redis pronto"
else
    echo -e "${RED}✗${NC} Redis não está respondendo"
    exit 1
fi

# Verificar se aplicação está respondendo
if curl -s http://localhost:8080/ >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Aplicação pronta"
else
    echo -e "${RED}✗${NC} Aplicação não está respondendo"
    echo ""
    echo "Logs da aplicação:"
    docker-compose logs app
    exit 1
fi

echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║        Setup Concluído! 🎉            ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${BLUE}📍 Serviços rodando:${NC}"
echo "   • Aplicação: http://localhost:8080"
echo "   • Redis: localhost:6379"
echo ""
echo -e "${BLUE}🧪 Teste rápido:${NC}"
echo "   curl http://localhost:8080/"
echo ""
echo -e "${BLUE}📊 Ver logs:${NC}"
echo "   docker-compose logs -f"
echo ""
echo -e "${BLUE}🔧 Comandos úteis:${NC}"
echo "   docker-compose ps          # Ver status"
echo "   docker-compose logs app    # Ver logs da app"
echo "   docker-compose down        # Parar tudo"
echo "   docker-compose restart     # Reiniciar"
echo ""
echo -e "${BLUE}📚 Documentação:${NC}"
echo "   • README.md         - Documentação completa"
echo "   • QUICKSTART.md     - Guia rápido"
echo "   • TESTING.md        - Guia de testes"
echo "   • ARCHITECTURE.md   - Arquitetura detalhada"
echo ""

# Oferecer executar teste
read -p "Deseja executar um teste rápido agora? (s/n): " run_test

set +e

if [[ $run_test =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${YELLOW}🧪 Executando teste rápido...${NC}"
    echo ""

    success=0
    blocked=0

    for i in {1..12}; do
        status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
        if [ "$status" == "200" ]; then
            echo -e "${GREEN}✓${NC} Request $i: OK"
            ((success++))
        else
            echo -e "${RED}✗${NC} Request $i: BLOCKED (429)"
            ((blocked++))
        fi
        sleep 0.15
    done

    echo ""
    echo -e "${BLUE}Resultado:${NC} $success OK, $blocked Bloqueadas"

    if [ $blocked -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Rate limiter funcionando corretamente!"
    else
        echo -e "${YELLOW}⚠${NC} Nenhuma requisição foi bloqueada. Verifique as configurações."
    fi
fi

set -e

echo ""
echo -e "${GREEN}Tudo pronto! Bom desenvolvimento! 🚀${NC}"
echo ""