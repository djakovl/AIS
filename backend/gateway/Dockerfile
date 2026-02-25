FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/gateway ./cmd/main.go

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata && \
    adduser -D -u 1001 appuser
WORKDIR /app
COPY --from=builder /app/gateway /app/gateway
RUN chown appuser:appuser /app/gateway
USER appuser

EXPOSE 8080
ENTRYPOINT ["/app/gateway"]
