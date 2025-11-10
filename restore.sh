#!/bin/bash

# Скрипт восстановления HXK Backend из бэкапа
# Использование: ./restore.sh <backup_date>
# Пример: ./restore.sh 20250127_170530

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка аргументов
if [ $# -eq 0 ]; then
    error "Укажите дату бэкапа!"
    echo "Использование: $0 <backup_date>"
    echo "Пример: $0 20250127_170530"
    echo ""
    echo "Доступные бэкапы:"
    ls -1 backups/ 2>/dev/null | grep -E '[0-9]{8}_[0-9]{6}' | sed 's/.*-\([0-9_]*\)\..*/\1/' | sort | uniq
    exit 1
fi

BACKUP_DATE="$1"
BACKUP_DIR="./backups"
PROJECT_NAME="hxk-backend"

# Проверяем наличие файлов бэкапа
UPLOADS_BACKUP="$BACKUP_DIR/uploads-$BACKUP_DATE.tar.gz"
DB_BACKUP="$BACKUP_DIR/database-$BACKUP_DATE.sql.gz"
INFO_FILE="$BACKUP_DIR/backup-info-$BACKUP_DATE.txt"

if [ ! -f "$UPLOADS_BACKUP" ]; then
    error "Файл бэкапа изображений не найден: $UPLOADS_BACKUP"
    exit 1
fi

if [ ! -f "$DB_BACKUP" ]; then
    error "Файл бэкапа БД не найден: $DB_BACKUP"
    exit 1
fi

log "🔄 Начинаем восстановление HXK Backend из бэкапа $BACKUP_DATE..."

# Показываем информацию о бэкапе
if [ -f "$INFO_FILE" ]; then
    log "📋 Информация о бэкапе:"
    echo "─────────────────────────────────────"
    cat "$INFO_FILE"
    echo "─────────────────────────────────────"
fi

# Подтверждение
read -p "Продолжить восстановление? Это удалит текущие данные! (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Восстановление отменено"
    exit 0
fi

# Получаем настройки БД
if [ -f ".env" ]; then
    source .env
else
    warning "Файл .env не найден, используем значения по умолчанию"
    POSTGRES_DB=${POSTGRES_DB:-hxk_db}
    POSTGRES_USER=${POSTGRES_USER:-postgres}
fi

# 1. Останавливаем приложение
log "🛑 Останавливаем приложение..."
docker-compose down

# 2. Восстанавливаем изображения
log "📁 Восстанавливаем изображения..."
docker run --rm \
    -v ${PROJECT_NAME}_uploads:/data \
    -v "$(pwd)/$BACKUP_DIR":/backup \
    alpine sh -c "cd /data && rm -rf ./* && tar xzf /backup/uploads-$BACKUP_DATE.tar.gz"

success "Изображения восстановлены"

# 3. Запускаем только БД для восстановления
log "🗄️ Запускаем базу данных..."
docker-compose up -d postgres

# Ждем пока БД запустится
log "⏳ Ждем запуска базы данных..."
sleep 10

# Проверяем что БД доступна
until docker exec hxk-postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
    log "Ждем готовности БД..."
    sleep 2
done

# 4. Восстанавливаем базу данных
log "🗄️ Восстанавливаем базу данных..."

# Очищаем БД (удаляем все таблицы)
docker exec hxk-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO $POSTGRES_USER;
GRANT ALL ON SCHEMA public TO public;
"

# Восстанавливаем из дампа
gunzip -c "$DB_BACKUP" | docker exec -i hxk-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

success "База данных восстановлена"

# 5. Запускаем полное приложение
log "🚀 Запускаем приложение..."
docker-compose up -d

# Ждем запуска приложения
log "⏳ Ждем запуска приложения..."
sleep 15

# Проверяем статус
if docker ps | grep -q "hxk-backend"; then
    success "Приложение успешно запущено"
else
    error "Проблема с запуском приложения"
    docker-compose logs backend
    exit 1
fi

# 6. Показываем результат
log "✅ Восстановление завершено!"
echo ""
log "📊 Статус сервисов:"
docker-compose ps

echo ""
log "🔗 Приложение должно быть доступно на порту 5000"
log "📁 Восстановлены данные от $(date -d $BACKUP_DATE'+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo $BACKUP_DATE)"

success "🎉 Восстановление успешно завершено!"
