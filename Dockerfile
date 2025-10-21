FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copia arquivos de dependências
COPY go.mod go.sum ./
RUN go mod download

# Copia código fonte
COPY . .

# Compila a aplicação com arquitetura específica
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rater-limiter-activity ./cmd/rater-limiter-activity

# Imagem final
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copia o binário compilado
COPY --from=builder --chmod=755 /app/rater-limiter-activity .

# Copia arquivo .env (opcional)
COPY .env* ./

ENV REDIS_ADDR=redis:6379

EXPOSE 8080

CMD ["./rater-limiter-activity"]