#!/bin/bash
set -e

BACKUP_DIR="/opt/max-infrastructure/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

docker exec mariadb mysqldump -u root -p${MYSQL_ROOT_PASSWORD} espocrm | gzip > "$BACKUP_DIR/espocrm_$TIMESTAMP.sql.gz"

docker run --rm -v espocrm-data:/data -v $BACKUP_DIR:/backup alpine tar czf "/backup/espocrm_data_$TIMESTAMP.tar.gz" /data

docker run --rm -v max-conversations:/conversations -v max-logs:/logs -v $BACKUP_DIR:/backup alpine tar czf "/backup/max_data_$TIMESTAMP.tar.gz" /conversations /logs

find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

ls -lh $BACKUP_DIR
