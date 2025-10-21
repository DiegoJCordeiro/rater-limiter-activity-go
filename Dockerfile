FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copia arquivos de dependências
COPY go.mod go.sum ./
RUN go mod download

# Copia código fonte
COPY . .

# Compila a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -o ratelimiter .

# Imagem final
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copia o binário compilado
COPY --from=builder /app/ratelimiter .

# Copia arquivo .env (opcional)
COPY .env* ./

EXPOSE 8080

CMD ["./ratelimiter"]