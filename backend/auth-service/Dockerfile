FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o auth-service ./cmd/main.go

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata && \
    adduser -D -u 1001 appuser
WORKDIR /app
COPY --from=builder /app/auth-service .
RUN chown appuser:appuser ./auth-service
USER appuser

EXPOSE 3000
ENTRYPOINT ["./auth-service"]
