#!/bin/bash

# Скрипт автоматического бэкапа HXK Backend
# Использование: ./backup.sh

set -e  # Остановка при ошибке

# Настройки
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_NAME="hxk-backend"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Создаем папку для бэкапов
mkdir -p "$BACKUP_DIR"

log "🚀 Начинаем бэкап HXK Backend..."

# Проверяем что контейнеры запущены
if ! docker ps | grep -q "hxk-postgres"; then
    error "Контейнер hxk-postgres не запущен!"
    exit 1
fi

# 1. Бэкап изображений (uploads volume)
log "📁 Создаем бэкап изображений..."
UPLOADS_BACKUP="$BACKUP_DIR/uploads-$DATE.tar.gz"

docker run --rm \
    -v ${PROJECT_NAME}_uploads:/data:ro \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine tar czf "/backup/uploads-$DATE.tar.gz" -C /data . 2>/dev/null

if [ -f "$UPLOADS_BACKUP" ]; then
    UPLOADS_SIZE=$(du -h "$UPLOADS_BACKUP" | cut -f1)
    success "Бэкап изображений создан: uploads-$DATE.tar.gz ($UPLOADS_SIZE)"
else
    error "Не удалось создать бэкап изображений!"
    exit 1
fi

# 2. Бэкап базы данных (SQL дамп)
log "🗄️ Создаем бэкап базы данных..."
DB_BACKUP="$BACKUP_DIR/database-$DATE.sql.gz"

# Получаем настройки БД из .env файла
if [ -f ".env" ]; then
    source .env
else
    warning "Файл .env не найден, используем значения по умолчанию"
    POSTGRES_DB=${POSTGRES_DB:-hxk_db}
    POSTGRES_USER=${POSTGRES_USER:-postgres}
fi

docker exec hxk-postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" 2>/dev/null | gzip > "$DB_BACKUP"

if [ -f "$DB_BACKUP" ] && [ -s "$DB_BACKUP" ]; then
    DB_SIZE=$(du -h "$DB_BACKUP" | cut -f1)
    success "Бэкап БД создан: database-$DATE.sql.gz ($DB_SIZE)"
else
    error "Не удалось создать бэкап базы данных!"
    exit 1
fi

# 3. Создание мета-информации
log "📝 Создаем мета-информацию..."
META_FILE="$BACKUP_DIR/backup-info-$DATE.txt"

cat > "$META_FILE" << EOF
HXK Backend Backup Information
==============================
Date: $(date)
Backup ID: $DATE

Files:
- uploads-$DATE.tar.gz ($UPLOADS_SIZE)
- database-$DATE.sql.gz ($DB_SIZE)

Docker Info:
- Project: $PROJECT_NAME
- Uploads Volume: ${PROJECT_NAME}_uploads
- Database Volume: ${PROJECT_NAME}_pgdata

Application Info:
- Database: $POSTGRES_DB
- Database User: $POSTGRES_USER

Restoration Commands:
====================

1. Restore Uploads:
docker-compose down
docker run --rm -v ${PROJECT_NAME}_uploads:/data -v \$(pwd)/backups:/backup alpine sh -c "cd /data && tar xzf /backup/uploads-$DATE.tar.gz"

2. Restore Database:
gunzip -c backups/database-$DATE.sql.gz | docker exec -i hxk-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB

3. Restart:
docker-compose up -d
EOF

success "Мета-информация сохранена: backup-info-$DATE.txt"

# 4. Показываем результат
log "📊 Результаты бэкапа:"
echo "─────────────────────────────────────"
ls -lh "$BACKUP_DIR"/*$DATE*
echo "─────────────────────────────────────"

TOTAL_SIZE=$(du -sh "$BACKUP_DIR"/*$DATE* | awk '{sum+=$1} END {print sum}')
success "Общий размер бэкапа: $(du -sh "$BACKUP_DIR"/*$DATE* | tail -1 | cut -f1)"

# 5. Очистка старых бэкапов (старше 7 дней)
log "🧹 Удаление старых бэкапов (старше 7 дней)..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "*backup*" -o -name "uploads-*" -o -name "database-*" -o -name "backup-info-*" | grep -E '[0-9]{8}_[0-9]{6}' | head -n -21 | wc -l)

find "$BACKUP_DIR" -name "*backup*" -o -name "uploads-*" -o -name "database-*" -o -name "backup-info-*" | grep -E '[0-9]{8}_[0-9]{6}' | head -n -21 | xargs rm -f 2>/dev/null || true

if [ "$DELETED_COUNT" -gt 0 ]; then
    success "Удалено $DELETED_COUNT старых файлов"
else
    log "Старые файлы не найдены"
fi

# 6. Проверка места на диске
log "💾 Информация о месте на диске:"
df -h . | tail -1

success "🎉 Бэкап успешно завершен!"
echo ""
log "Для восстановления используйте команды из файла: backup-info-$DATE.txt"
