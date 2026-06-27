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

#### 生成签名（仅首次）

```bash
cd frontend/android/app
keytool -genkey -v -keystore chronoflow.keystore -alias chronoflow \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass chronoflow2026 -keypass chronoflow2026 \
  -dname "CN=XAXinAn, OU=ChronoFlow, O=ChronoFlow, L=Zhoushan, ST=Zhejiang, C=CN"
```

#### 构建

```bash
cd frontend
flutter build apk --release      # 签名 APK → build/app/outputs/flutter-apk/app-release.apk
```

#### 部署到服务器

```bash
scp build/app/outputs/flutter-apk/app-release.apk chronoflow:/app/static/app.apk
ssh chronoflow "sed -i 's/APP_VERSION_CODE=.*/APP_VERSION_CODE=<新版本号>/' /app/start.sh && /app/start.sh重启"
```

---

## 连接本地后端调试（重要）

> 默认 `baseUrl` 现在是生产服务器 `https://chronocloud.top/api`（见 `frontend/lib/constants/app_constants.dart`）。
> 也就是说，直接 `flutter run` 连的是**线上后端**，不是你本机起的那个。
> 想连本地后端调试，必须用 `--dart-define=BASE_URL=...` 在启动时覆盖。

前置条件：本地后端已按上面「后端运行」启动，监听在 `localhost:8080`。

### iOS 模拟器 / iOS 真机走 USB

iOS 模拟器和宿主机共享网络，直接用 `localhost`：

```bash
cd frontend
flutter run --dart-define=BASE_URL=http://localhost:8080/api
```

### Android 模拟器

Android 模拟器里 `localhost` 指模拟器自己，访问宿主机要用 `10.0.2.2`：

```bash
flutter run --dart-define=BASE_URL=http://10.0.2.2:8080/api
```

### 真机（iOS / Android）

真机访问不到电脑的 `localhost`，要用电脑的局域网 IP，且手机与电脑在同一 WiFi：

```bash
# 先查电脑 IP
# macOS: ipconfig getifaddr en0
# Windows: ipconfig

flutter run --dart-define=BASE_URL=http://192.168.x.x:8080/api
```

把 `192.168.x.x` 换成实际 IP。

> ⚠️ iOS HTTP 明文限制：当前 `ios/Runner/Info.plist` **未配置 ATS 例外**，iOS 默认禁止 HTTP 明文请求。
> 因此 iOS（模拟器或真机）连本地 `http://...` 后端会被 App Transport Security 拦截、请求失败。
> 临时调试可在 `ios/Runner/Info.plist` 加入以下例外（**仅本地调试用，勿提交到生产**）：
>
> ```xml
> <key>NSAppTransportSecurity</key>
> <dict>
>   <key>NSAllowsLocalNetworking</key>
>   <true/>
> </dict>
> ```
>
> 线上 `chronocloud.top` 是 HTTPS，不受此限制，正式构建无需加这个例外。
