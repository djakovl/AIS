FROM drogonframework/drogon:latest

WORKDIR /app

COPY . .
RUN mkdir -p build /opt/storage
RUN cd build && cmake .. -DBUILD_TESTS=OFF && make -j$(nproc)

# Install envsubst for config template substitution
RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*

# Generate config from template at runtime (env vars)
ENV DB_HOST=localhost
ENV DB_PORT=5432
ENV DB_NAME=s3storage
ENV DB_USER=s3user
ENV DB_PASSWORD=
ENV STORAGE_BASE_PATH=/opt/storage

EXPOSE 3002

CMD sh -c 'envsubst < config.json.template > config.json && exec ./build/s3-storage-service'
