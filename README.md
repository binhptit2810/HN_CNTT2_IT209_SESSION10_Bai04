# Báo Cáo Bài Tập 4: Thiết Lập Custom Network & Named Volume Bằng Docker CLI

## 1. Thông Tin Chung
- **Môn học:** IT209 - DevOps & Cloud Computing
- **Chủ đề:** Custom Bridge Network, DNS Resolution & Named Volume Data Persistence
- **Thư mục bài làm:** `homework/session_10/ex04/` (đồng thời đồng bộ sang `homework/session_10/ex4/`)

---

## 2. Mục Tiêu & Yêu Cầu
- **Mục tiêu:**
  - Thiết lập **Custom Bridge Network** (`app-net`) để các Container trong cùng hệ thống có thể giao tiếp nội bộ thông qua tên service/hostname (tự động phân giải DNS).
  - Thiết lập **Named Volume** (`db-data`) gắn kết vào cơ sở dữ liệu PostgreSQL để đảm bảo tính toàn vẹn và bền vững của dữ liệu (**Data Persistence**) khi vòng đời container kết thúc.
  - Tự động hóa toàn bộ quy trình thông qua script Bash [`commands.sh`](file:///c:/Users/Dell/OneDrive/Documents/DuLieuCaNhan/IT209/homework/session_10/ex04/commands.sh).
- **Yêu cầu kết quả:**
  - Lệnh `ping db-server` từ container `app-container` phân giải thành công IP nội bộ của `db-server`.
  - Dữ liệu trong cơ sở dữ liệu hoàn toàn nguyên vẹn sau khi xóa cứng container (`docker rm -f db-server`) và khởi chạy lại container mới trỏ cùng Volume.

---

## 3. Cấu Trúc Thư Mục
```text
ex04/
├── commands.sh           # Script bash tự động hóa toàn bộ quy trình thiết lập và kiểm thử
└── README.md             # Báo cáo kỹ thuật chi tiết, giải thích cơ chế và kết quả thực nghiệm
```

---

## 4. Phân Tích Kỹ Thuật & Cơ Chế Hoạt Động

### 4.1. Custom Bridge Network vs Default Bridge Network
- **Default Bridge (`bridge`):**
  - Mạng mặc định khi container khởi chạy không có cờ `--network`.
  - **Không hỗ trợ tự động phân giải DNS theo tên container**: Nếu muốn giao tiếp phải dùng IP tĩnh (rất dễ thay đổi) hoặc dùng flag cũ `--link` đã bị Docker gắn nhãn deprecated.
- **Custom Bridge Network (`app-net`):**
  - Được tạo chủ động bằng lệnh `docker network create --driver bridge app-net`.
  - **Tích hợp sẵn Docker Embedded DNS Server (127.0.0.11):** Mọi container cùng tham gia `app-net` đều tự động phân giải tên container (`db-server`, `app-container`) thành IP nội bộ mà không cần cấu hình file `/etc/hosts` thủ công.
  - **Cách ly mạng (Network Isolation):** Chỉ các container trong cùng mạng mới giao tiếp được với nhau, ngăn chặn truy cập trái phép từ các container khác trên cùng máy host.

---

### 4.2. Named Volume vs Ephemeral Container Layer
- **Container Writable Layer (Mặc định):**
  - Mọi thay đổi dữ liệu ghi trực tiếp lên tầng ghi (writable layer) của container dựa trên Overlay2/UnionFS.
  - Khi container bị xóa (`docker rm -f`), toàn bộ tầng ghi bị hủy, dữ liệu database biến mất hoàn toàn.
- **Named Volume (`db-data`):**
  - Được quản lý độc lập bởi Docker Engine (lưu tại thư mục chuyên dụng trên máy host, ví dụ `/var/lib/docker/volumes/db-data/_data`).
  - Tồn tại độc lập với vòng đời (lifecycle) của container.
  - Khi mount với cú pháp `-v db-data:/var/lib/postgresql/data`, dữ liệu bảng, index và WAL log của PostgreSQL được ghi thẳng vào volume trên host.
  - Khi container cũ bị xóa và một container mới được dựng lên gắn cùng volume, container mới sẽ kế thừa toàn bộ cấu trúc dữ liệu trước đó.

---

## 5. Chi Tiết Các Bước Thực Hiện

### Bước 1: Tạo Custom Bridge Network
```bash
docker network create --driver bridge app-net
```

### Bước 2: Tạo Named Volume cho Database
```bash
docker volume create db-data
```

### Bước 3: Khởi Chạy Database Container (`postgres:15-alpine`)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine
```

### Bước 4: Khởi Chạy Backend Container (`app-container`)
Khởi chạy Backend Container tham gia mạng `app-net`, truyền các biến môi trường kết nối trỏ tới hostname `db-server`:
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -p 3000:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_NAME=app_db \
  hw-backend:multistage
```

---

## 6. Kết Quả Kiểm Tra & Thực Nghiệm Thực Tế

Toàn bộ các bước kiểm tra dưới đây được trích xuất trực tiếp từ quá trình chạy [`commands.sh`](file:///c:/Users/Dell/OneDrive/Documents/DuLieuCaNhan/IT209/homework/session_10/ex04/commands.sh).

### 6.1. Kiểm Tra Danh Sách Network & Volume
```bash
docker network ls | grep app-net
```
**Output:**
```text
31d9750e10ac   app-net               bridge    local
```

```bash
docker volume ls | grep db-data
```
**Output:**
```text
local     db-data
```

---

### 6.2. Kiểm Tra Cấu Hình Network (`docker network inspect app-net`)
```json
[
    {
        "Name": "app-net",
        "Id": "31d9750e10acca8b5dd7f8ae3efc2e31b07eed107fe1dd71a886e2e7db9f75d0",
        "Driver": "bridge",
        "IPAM": {
            "Config": [
                {
                    "Subnet": "172.20.0.0/16",
                    "Gateway": "172.20.0.1"
                }
            ]
        },
        "Containers": {
            "150e15365761c0e369cbc561d4a5a04acca59703f645b073e89784d0d3c2e78d": {
                "Name": "db-server",
                "IPv4Address": "172.20.0.2/16"
            },
            "4a122cfd90b72bf09a8b606fcc5cf2376de4b2738add37ee4d8e011e9718999c": {
                "Name": "app-container",
                "IPv4Address": "172.20.0.3/16"
            }
        }
    }
]
```
> **Đánh giá:** Cả 2 container `db-server` (172.20.0.2) và `app-container` (172.20.0.3) đều được cấp phát IP hợp lệ thuộc dải mạng `172.20.0.0/16` của `app-net`.

---

### 6.3. Kiểm Tra DNS Resolution Nội Bộ (Ping Qua Service Name)
Thực thi lệnh kiểm tra phân giải tên từ bên trong `app-container`:
```bash
docker exec -it app-container ping -c 2 db-server
```
**Output thực tế:**
```text
PING db-server (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.481 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.101 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.101/0.291/0.481 ms
```
> **Kết luận:** Lệnh `ping` đã phân giải thành công hostname `db-server` sang địa chỉ IP `172.20.0.2`, tỷ lệ mất gói 0%, chứng minh Docker Embedded DNS hoạt động chính xác.

---

### 6.4. Kiểm Tra Tính Bền Vững Của Dữ Liệu (Data Persistence Test)

#### Bước 6.4.1: Tạo bảng và chèn dữ liệu mẫu vào `db-server`
```bash
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
```
Truy vấn kiểm tra dữ liệu trước khi xóa container:
```text
 id |        name         | price 
----+---------------------+-------
  1 | Laptop Dell XPS     |  1500
  2 | Mechanical Keyboard |   120
  3 | Wireless Mouse      |    45
(3 rows)
```

#### Bước 6.4.2: Xóa cứng Container DB
```bash
docker rm -f db-server
```
Sau lệnh trên, container `db-server` đã bị hủy bỏ hoàn toàn khỏi Docker.

#### Bước 6.4.3: Khởi chạy Container DB Mới sử dụng cùng Named Volume `db-data`
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=app_db \
  postgres:15-alpine
```

#### Bước 6.4.4: Xác minh dữ liệu trong Container mới
```bash
docker exec -i db-server psql -U postgres -d app_db -c "SELECT * FROM products;"
```
**Kết quả hiển thị:**
```text
 id |        name         | price 
----+---------------------+-------
  1 | Laptop Dell XPS     |  1500
  2 | Mechanical Keyboard |   120
  3 | Wireless Mouse      |    45
(3 rows)
```
> **Kết luận:** Cả 3 bản ghi dữ liệu vẫn tồn tại nguyên vẹn 100% trong database `app_db` trên container mới. Tính năng lưu trữ dữ liệu bền vững qua **Named Volume** đã hoạt động hoàn hảo.

---

## 7. Hướng Dẫn Chạy Script Tự Động
Để chạy toàn bộ kịch bản tự động hóa từ đầu đến cuối:
```bash
cd homework/session_10/ex04
bash commands.sh
```
Script sẽ tự động dọn dẹp, tạo network, volume, chạy container, test ping DNS, insert data, xóa cứng container, dựng lại và kiểm chứng dữ liệu.
