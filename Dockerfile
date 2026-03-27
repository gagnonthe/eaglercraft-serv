FROM eclipse-temurin:21-jre

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app
RUN chmod +x /app/start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
