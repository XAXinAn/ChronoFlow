# ChronoFlow 开发指南

## 项目概述

时纪流 — 日程管理与通知解析应用。用户拍摄通知截图，AI 自动识别文字提取日程信息，支持个人日程和多层级群组协作。

- **后端**: Spring Boot 3 + Java 17 + MyBatis-Plus + MySQL + Redis
- **前端**: Flutter（Android + iOS）
- **AI**:  阿里云 DashScope 百炼（日程解析）、阿里云 Green（内容审核）
- **认证**: 阿里云 CloudAuth 金融级实人认证（注册时强制实名）
- **通知**: 阿里云短信、阿里云邮件推送

## 项目结构

```
ChronoFlow/
  CLAUDE.md                    ← 本文件
  README.md                    ← 对外说明
  .gitignore
  backend/
    .env.example               ← 环境变量模板
    docker-compose.yml         ← 本地 MySQL + Redis
    init.sql                   ← 建表 DDL（8张表）
    pom.xml                    ← Maven 配置（Java 17, MyBatis-Plus 3.5.9）
    start-prod.sh              ← 生产环境启动脚本（不入库）
    src/main/java/com/chronoflow/backend/
      BackendApplication.java
      config/                  ← Security, JWT, MyBatis-Plus, Redis, AI, Jackson
      controller/              ← REST 接口
        AppController          ← 版本更新检测
        AuthController         ← 登录/注册/刷新令牌/登出/风控验证
        UserController         ← 用户信息/绑定/修改/实人认证
        ScheduleController     ← 个人日程 + 群组日程 CRUD
        GroupController        ← 群组管理（多层级/子群组/审批）
        NotificationController ← AI 通知解析
      service/                 ← 业务逻辑
        AuthService            ← 认证（含风控登录、短信登录、邮箱登录）
        UserService            ← 用户管理
        ScheduleService        ← 日程 CRUD + 群组日程下发
        GroupService           ← 群组操作（层级树/子孙查询/权限）
        NotificationService    ← AI 解析调度
        NotificationAiService  ← DashScope AI 调用
        ContentModerationService ← 阿里云 Green 审核
        RealPersonVerificationService ← 阿里云实人认证
        EmailService           ← 邮件验证码
        SmsService             ← 短信验证码
        RiskControlService     ← 登录风控（Redis 计数 + 验证码挑战）
        RefreshTokenService    ← Refresh Token Redis 存储
        TokenBlacklistService  ← Token 黑名单
        RegisterService        ← 注册流程（两步：验证 → 人脸 → 确认）
      entity/                  ← MyBatis-Plus 实体
        User, Schedule, Group, GroupMember, JoinRequest
        SubgroupCreationRequest, SchedulePublishTarget
      dto/                     ← 请求/响应 DTO
      mapper/                  ← MyBatis-Plus Mapper 接口
      security/                ← JWT 生成/验证、认证过滤器、速率限制、实名拦截
      exception/               ← BusinessException、ContentModerationException、GlobalExceptionHandler
      util/                    ← CryptoUtil（AES-256-GCM 身份证加密）
      validation/              ← 自定义校验（密码强度）
    src/main/resources/
      application.yaml         ← Spring Boot 配置（全部用 ${ENV_VAR:default} 模式）
  frontend/
    lib/
      main.dart                ← 入口 + 路由表
      constants/               ← AppConstants（API 地址、主题色）
      model/                   ← auth_model, group_model, schedule_model
      service/                 ← API 调用
        api_client.dart        ← 统一 HTTP 客户端（自动 Token 刷新、401 处理）
        auth_service.dart      ← 认证
        group_service.dart     ← 群组
        schedule_service.dart  ← 日程
        calendar_service.dart  ← 系统日历同步
        secure_storage_service.dart ← Token 安全存储
        face_verify_bridge.dart ← 人脸SDK桥接
        real_person_service.dart ← 实名认证
      utils/                   ← MessageUtils（Toast/对话框）
      widgets/                 ← ChronoInputField（共享输入框组件）
      pages/
        home_page.dart         ← 主页（日历 + 日程列表 + 个人中心）
        login_page.dart        ← 登录（三栏：密码/短信/邮箱）
        auth/                  ← 注册（含实名认证）、启动页（含版本更新检测）
        schedule/              ← 创建/编辑日程、通知解析、下发范围选择
        group/                 ← 群组列表、详情、子群创建/审批、成员管理、加入
        profile/               ← 个人信息、修改密码/昵称/手机、绑定邮箱、实人认证、关于
    android/                   ← Android 工程（含人脸SDK AAR、ML Kit离线模型）
    ios/                       ← iOS 工程
```

## 本地运行

### 后端
```bash
cd backend
docker compose up -d          # 启动 MySQL + Redis（首次自动建表）
cp .env.example .env          # 编辑 DB_PASSWORD=root123, JWT_SECRET=至少32字符
```
IDEA 打开 `backend/` → Run `BackendApplication` → Environment Variables 导入 `.env` → http://localhost:8080

### 前端
```bash
cd frontend
flutter pub get
flutter run                    # 模拟器（默认连 10.0.2.2:8080）
flutter run --dart-define=BASE_URL=http://192.168.x.x:8080/api  # 真机
```

## 数据库

8 张表（见 `init.sql`）：
- **users** — 用户（含 real_name_verified, real_name, id_card_number, verified_at）
- **schedules** — 日程（user_id, group_id?, title, description, location, schedule_time）
- **groups** — 群组（name, description, invite_code, creator_id, parent_id, depth）
- **group_members** — 群组成员（group_id, user_id, nickname, is_admin）
- **join_requests** — 加群申请（group_id, user_id, status）
- **subgroup_creation_requests** — 子群组创建申请
- **schedule_publish_targets** — 日程下发目标

## 核心功能

### 多层级群组
- 无限层级（上限50），parent_id + depth 实现
- 任何成员可申请创建子群组 → 父群主/管理员审核 → 申请人成为子群主
- 群主/管理员权限仅限本群
- 日程可下发到任意子孙群组（树形多选器）

### 实人认证
- 注册时强制实名：姓名+身份证+人脸活体检测
- 两步注册：init（暂存Redis）→ 人脸SDK → confirm（写入DB）
- 阿里云 CloudAuth ID_PRO 方案，Android SDK v2.3.48
- 身份证号 AES-256-GCM 加密存储

### 版本更新检测
- GET /api/app/version 返回版本号和下载链接
- App 启动时自动检测，弹窗提示更新
- APK 通过静态文件服务直接下载

## API 设计

- 认证：JWT（access token 15min + refresh token 30d）
- 全部 API 前缀 `/api/`
- 公开端点：`/api/auth/*`、`/api/app/version`、`/actuator/health`、`/app.apk`
- 响应格式：`ApiResponse<T>`（code, message, data）

## 生产部署

### 后端
服务器 `8.136.20.182:8080`，通过 SSH 部署：
```bash
./mvnw clean package -DskipTests
scp target/backend-0.0.1-SNAPSHOT.jar chronoflow:/app/chronoflow.jar
ssh chronoflow "cd /app && bash start.sh > app.log 2>&1 &"
```
环境变量在 `/app/start.sh` 中配置。

### 前端签名构建
```bash
cd frontend/android/app
keytool -genkey -v -keystore chronoflow.keystore -alias chronoflow \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass chronoflow2026 -keypass chronoflow2026 \
  -dname "CN=XAXinAn, OU=ChronoFlow, O=ChronoFlow, L=Zhoushan, ST=Zhejiang, C=CN"
cd .. && flutter build apk --release
```

### 发版流程
1. `APP_VERSION_CODE` 递增（`/app/start.sh` 中修改）
2. 构建 APK → `scp` 到 `/app/static/app.apk`
3. 重启后端

## 待完成

- [ ] 分页 — 所有列表接口返回全量数据
- [ ] 前端状态管理 — 引入 Provider 或 Riverpod
- [ ] 单元测试 — 后端和前端都为 0
- [ ] Spring profiles — 目前只有默认配置
- [ ] CORS 生产配置 — 当前允许 localhost
- [ ] 群组成员昵称同步 — 用户改名后群内昵称不同步
- [ ] 密码修改后使现有 token 失效
- [ ] HTTPS — 当前使用 HTTP 明文

## 开发约定

- 异常消息用中文，服务层全部抛 `BusinessException`
- application.yaml 里所有值都用 `${ENV_VAR:default}` 模式
- .env 不提交（已在 .gitignore），.env.example 作为模板
- 分支策略：develop（日常） + production（稳定），功能分支命名 `feat/xxx`

## Commit 规范

```
feat: 功能描述        # 新功能
fix: 问题描述         # Bug 修复
refactor: 改动描述    # 重构
docs: 文档内容        # 文档
chore: 杂项描述       # 依赖、配置等
```
