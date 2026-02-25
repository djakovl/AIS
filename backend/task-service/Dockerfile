FROM golang:1.23-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o task-service .

FROM alpine:3.20

RUN apk --no-cache add ca-certificates wget

WORKDIR /app

COPY --from=builder /build/task-service .

EXPOSE 3003

CMD ["./task-service"]
