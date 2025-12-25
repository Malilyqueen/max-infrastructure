FROM espocrm/espocrm:8.3

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html/custom/Espo/Custom && chown -R www-data:www-data /var/www/html/custom

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:80/api/v1/App/user || exit 1
