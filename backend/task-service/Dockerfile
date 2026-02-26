FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o task-service .

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata && \
    adduser -D -u 1001 appuser
WORKDIR /app
COPY --from=builder /app/task-service .
RUN chown appuser:appuser ./task-service
USER appuser

EXPOSE 3003
ENTRYPOINT ["./task-service"]
