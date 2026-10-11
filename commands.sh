#!/bin/bash
# ==============================================================================
# Script: commands.sh
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Thư mục: homework/session_10/ex04
# ==============================================================================

set -e

echo "=================================================================="
echo ">>> [BÀI 4] BẮT ĐẦU THIẾT LẬP CUSTOM NETWORK & NAMED VOLUME <<<"
echo "=================================================================="

# 0. Dọn dẹp môi trường cũ nếu tồn tại
echo ""
echo "[Bước 0] Dọn dẹp container, network và volume cũ..."
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true
echo ">>> Dọn dẹp hoàn tất."

# 1. Tạo Custom Bridge Network tên app-net
echo ""
echo "[Bước 1] Tạo Custom Bridge Network 'app-net'..."
docker network create --driver bridge app-net
echo ">>> Network 'app-net' đã được tạo thành công."

# 2. Tạo Named Volume tên db-data
echo ""
echo "[Bước 2] Tạo Named Volume 'db-data'..."
docker volume create db-data
echo ">>> Named Volume 'db-data' đã được tạo thành công."

# 3. Khởi chạy Database Container (postgres:15-alpine) tên db-server
echo ""
echo "[Bước 3] Khởi chạy Database Container 'db-server' tham gia 'app-net' và mount volume 'db-data'..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine

echo ">>> Container 'db-server' đã khởi chạy. Đang chờ PostgreSQL sẵn sàng..."
until docker exec db-server pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ">>> PostgreSQL đã sẵn sàng nhận kết nối!"

# 4. Khởi chạy Backend Container (app-container) tham gia app-net
echo ""
echo "[Bước 4] Khởi chạy Backend Container 'app-container' tham gia 'app-net'..."
# Tự động phát hiện image backend từ EX3 hoặc sử dụng node:18-alpine
if docker image inspect hw-backend:multistage >/dev/null 2>&1; then
  BACKEND_IMAGE="hw-backend:multistage"
  RUN_CMD=""
else
  BACKEND_IMAGE="node:18-alpine"
  RUN_CMD="sleep infinity"
fi

echo ">>> Sử dụng image: $BACKEND_IMAGE"
docker run -d \
  --name app-container \
  --network app-net \
  -p 3000:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=app_db \
  $BACKEND_IMAGE $RUN_CMD

echo ">>> Backend container 'app-container' đã khởi chạy thành công."

# 5. Kiểm tra Network, Volume và DNS Resolution
echo ""
echo "=================================================================="
echo ">>> [KIỂM TRA 1] KIỂM TRA NETWORK & NAMED VOLUME <<<"
echo "=================================================================="
echo ""
echo "1. Kiểm tra danh sách Network:"
docker network ls | grep app-net || true

echo ""
echo "2. Kiểm tra danh sách Volume:"
docker volume ls | grep db-data || true

echo ""
echo "3. Kiểm tra chi tiết Network 'app-net':"
docker network inspect app-net

echo ""
echo "4. Kiểm tra DNS Resolution nội bộ (Ping từ app-container sang db-server):"
docker exec app-container ping -c 2 db-server

# 6. Thực hiện test Data Persistence
echo ""
echo "=================================================================="
echo ">>> [KIỂM TRA 2] THỰC HIỆN TEST DATA PERSISTENCE <<<"
echo "=================================================================="

echo ""
echo "[Bước 6.1] Tạo bảng 'products' và thêm dữ liệu mẫu vào database 'app_db'..."
docker exec -i db-server psql -U postgres -d app_db -c "
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price NUMERIC NOT NULL
);
INSERT INTO products (name, price) VALUES
    ('Laptop Dell XPS', 1500),
    ('Mechanical Keyboard', 120),
    ('Wireless Mouse', 45);
"

echo ""
echo ">>> Dữ liệu trong db-server TRƯỚC KHI XÓA CONTAINER:"
docker exec -i db-server psql -U postgres -d app_db -c "SELECT * FROM products;"

echo ""
echo "[Bước 6.2] XÓA CỨNG CONTAINER DB (docker rm -f db-server)..."
docker rm -f db-server
echo ">>> Container db-server đã bị xóa hoàn toàn khỏi Docker engine."

echo ""
echo "[Bước 6.3] Khởi chạy container DB MỚI gắn cùng Named Volume 'db-data'..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine

echo ">>> Đang chờ DB container mới khởi động..."
until docker exec db-server pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done
echo ">>> DB container mới đã sẵn sàng!"

echo ""
echo "[Bước 6.4] XÁC MINH DỮ LIỆU SAU KHI TÁI TẠO CONTAINER:"
docker exec -i db-server psql -U postgres -d app_db -c "SELECT * FROM products;"

echo ""
echo ">>> Kiểm tra lại kết nối mạng từ app-container tới container db-server mới:"
docker exec app-container ping -c 2 db-server

echo ""
echo "=================================================================="
echo ">>> HOÀN THÀNH TOÀN BỘ CÁC BƯỚC VÀ KIỂM TRA THÀNH CÔNG! <<<"
echo "=================================================================="
