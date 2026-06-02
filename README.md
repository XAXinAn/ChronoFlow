# ChronoFlow 时纪流

一个日程管理与通知解析应用，拍摄通知截图即可自动识别并创建日程，支持个人日程和群组协作。

## 项目结构

```
ChronoFlow/
  backend/          Spring Boot 3 + Java 17 + MySQL + Redis
  frontend/         Flutter（Android + iOS）
```

## 后端运行

### 1. 环境准备

- JDK 17：命令行输入 `java -version` 确认
- Docker：命令行输入 `docker compose version` 确认

### 2. 启动 MySQL 和 Redis

```bash
cd backend
docker compose up -d
```

首次启动会自动建库建表（`init.sql`）。如果之前启动过，数据会保留在 Docker volume 里。

### 3. 配置环境变量

```bash
cp .env.example .env
```

编辑 `backend/.env`，需要修改的只有两项，其余保持默认即可：

```env
DB_PASSWORD=root123
JWT_SECRET=随便输入一个至少32个字符的字符串
```

`DB_PASSWORD` 要和 `docker-compose.yml` 里 MySQL 的密码一致（默认就是 `root123`）。

### 4. IDEA 启动

用 IntelliJ IDEA 打开 `backend/` 目录，它会自动识别为 Maven 项目。

配置 Run Configuration：

1. 打开 `BackendApplication.java`
2. 点行号旁边的绿色三角 → `Modify Run Configuration`
3. `Environment variables` 右侧点文件图标
4. 选择 `backend/.env`
5. OK → Run

启动后访问 `http://localhost:8080`。

### 5. 停止

```bash
docker compose down        # 停止容器，保留数据
docker compose down -v     # 停止容器，删除数据
```

---

## 前端运行

### 1. 环境准备

- Flutter SDK：命令行输入 `flutter doctor` 确认
- Android Studio 或 Xcode（用于模拟器/真机调试）

### 2. 安装依赖

```bash
cd frontend
flutter pub get
```

### 3. 选择设备

```bash
flutter devices    # 查看可用设备
```

会列出已连接的模拟器和真机，记下设备 ID。

### 4. 启动

**Android 模拟器**（默认连 `10.0.2.2:8080` 访问宿主机）：

```bash
flutter run
```

**iOS 模拟器**（需要改成 `localhost`）：

```bash
flutter run --dart-define=BASE_URL=http://localhost:8080/api
```

**真机**（需要改成电脑的局域网 IP）：

```bash
# 先查电脑 IP
# macOS: ifconfig | grep "inet "
# Windows: ipconfig

flutter run --dart-define=BASE_URL=http://192.168.x.x:8080/api
```

把 `192.168.x.x` 换成你电脑的实际 IP，手机和电脑需要在同一个 WiFi 下。

### 5. 构建安装包

```bash
flutter build apk --dart-define=BASE_URL=https://你的服务器地址/api    # Android
flutter build ios --dart-define=BASE_URL=https://你的服务器地址/api    # iOS
```
