# ChronoFlow 开发指南

## 项目概述

时纪流 — 日程管理与通知解析应用。用户拍摄通知截图，AI 自动识别文字提取日程信息，支持个人日程和多层级群组协作。

- **后端**: Spring Boot 3 + Java 17 + MyBatis-Plus + MySQL + Redis + MinIO
- **前端**: Flutter（Android + iOS）
- **管理后台**: React + Vite + TypeScript（`web/`）
- **AI**:  阿里云 DashScope 百炼（日程解析）、阿里云 Green（内容审核）
- **认证**: 阿里云 CloudAuth 金融级实人认证（注册时强制实名）
- **通知**: 阿里云短信、阿里云邮件推送
- **存储**: MinIO 对象存储（反馈图片）

## 项目结构

```
ChronoFlow/
  CLAUDE.md                    ← 本文件
  README.md                    ← 对外说明
  .gitignore
  backend/
    .env.example               ← 环境变量模板
    docker-compose.yml         ← MySQL + Redis + MinIO
    init.sql                   ← 建表 DDL（10张表）
    pom.xml                    ← Maven 配置
    XAXINAN.pem                ← 生产服务器 SSH 密钥（不入库）
    src/main/java/com/chronoflow/backend/
      BackendApplication.java
      config/                  ← Security, JWT, MyBatis-Plus, Redis, AI, Jackson
      controller/              ← REST 接口
        AdminController        ← 管理后台 API（反馈/群组/日程/用户 CRUD）
        AppController          ← 版本更新检测
        AuthController         ← 登录/注册/刷新令牌/登出/风控验证
        FeedbackController     ← 用户反馈提交/查看
        GroupController        ← 群组管理
        NotificationController ← AI 通知解析
        ScheduleController     ← 日程 CRUD
        UserController         ← 用户信息管理
      service/                 ← 业务逻辑
        AdminService           ← 管理后台数据查询
        AuthService            ← 认证
        ContentModerationService ← 阿里云 Green 审核
        EmailService           ← 邮件验证码
        FeedbackService        ← 反馈 CRUD + 图片上传
        GroupService           ← 群组操作
        MinioService           ← MinIO 对象存储上传
        NotificationAiService  ← DashScope AI 调用
        NotificationService    ← AI 解析调度
        RateLimiterService     ← Redis 限流
        RealPersonVerificationService ← 阿里云实人认证
        RefreshTokenService    ← Refresh Token Redis 存储
        RegisterService        ← 注册流程
        RiskControlService     ← 登录风控
        ScheduleService        ← 日程 CRUD
        SmsService             ← 短信验证码
        TokenBlacklistService  ← Token 黑名单
        UserService            ← 用户管理
      entity/                  ← MyBatis-Plus 实体
        User, Schedule, Group, GroupMember, JoinRequest,
        SubgroupCreationRequest, SchedulePublishTarget,
        Feedback, AdminUser
      dto/                     ← 请求/响应 DTO
        ApiResponse, PageResult, FeedbackResponse, ...
      mapper/                  ← MyBatis-Plus Mapper 接口
      security/                ← JWT, 认证过滤器, 速率限制
      exception/               ← GlobalExceptionHandler
      util/                    ← CryptoUtil（AES-256-GCM 身份证加密）
    src/main/resources/
      application.yaml         ← 全部用 ${ENV_VAR:default} 模式
      static/admin/            ← React 管理后台构建产物
  frontend/                    ← Flutter App
    lib/
      main.dart                ← 入口 + 路由表
      constants/               ← AppConstants（baseUrl 默认 8.136.20.182:8080）
      model/                   ← 数据模型（含 feedback_model）
      service/                 ← API 调用
      utils/                   ← 工具类
      widgets/                 ← 共享组件（含 image_gallery_widget）
      pages/
        home_page.dart         ← 主页
        login_page.dart        ← 登录
        auth/                  ← 注册、启动页
        schedule/              ← 日程
        group/                 ← 群组
        profile/               ← 个人信息 + 意见反馈 + 反馈详情
    android/                   ← Android 工程
    ios/                       ← iOS 工程
  web/                         ← React 管理后台
    src/
      api/client.ts            ← Axios 封装
      components/              ← Layout, Pagination, StatusBadge
      pages/                   ← Login, Feedbacks, FeedbackDetail, Users, Groups, Schedules
```

## 本地运行

### 后端
```bash
cd backend
docker compose up -d          # 启动 MySQL + Redis + MinIO
cp .env.example .env          # 编辑配置
```
IDEA 打开 `backend/` → Run `BackendApplication` → http://localhost:8080

### 前端
```bash
cd frontend
flutter pub get
flutter run                    # 默认连 8.136.20.182:8080
flutter run --dart-define=BASE_URL=http://localhost:8080/api  # 本地后端
```

### 管理后台
```bash
cd web
npm install
npm run dev                    # 开发模式
npm run build                  # 构建到 backend/static/admin/
```

## 数据库

10 张表（见 `init.sql`）：

| 表 | 说明 |
|----|------|
| **users** | 用户 |
| **schedules** | 日程 |
| **groups** | 群组（多层级的） |
| **group_members** | 群组成员 |
| **join_requests** | 加群申请 |
| **subgroup_creation_requests** | 子群组创建申请 |
| **schedule_publish_targets** | 日程下发目标 |
| **feedbacks** | 用户反馈 |
| **admin_users** | 管理后台账号（独立于 users 表） |

## 核心功能

### 多层级群组
- 无限层级（上限50），parent_id + depth 实现
- 任何成员可申请创建子群组 → 父群主/管理员审核 → 申请人成为子群主
- 日程可下发到任意子孙群组（树形多选器）
- 群主转让、群名修改、解散保护、注销保护

### 用户反馈系统
- Flutter App：意见反馈页面（文字 + 最多5张图片）
- 单步 Multipart 上传（图片直传 MinIO）
- 反馈详情页展示管理员回复
- 内容审核 + 限速保护

### 管理后台（React SPA）
- 独立账号体系（admin_users 表）
- 反馈管理：列表/详情/回复/状态管理
- 用户管理：列表/查看（表格视图）
- 群组管理：列表/编辑名称/删除（表格视图）
- 日程管理：新建/编辑/删除（表格视图）
- 分页 + 关键字搜索 + 自定义每页条数（10/20/50/100）

### 实人认证
- 注册时强制实名：姓名+身份证+人脸活体检测
- 身份证号 AES-256-GCM 加密（PBKDF2 密钥派生）
- 阿里云 CloudAuth ID_PRO 方案

### 图片识别
- 首页日历下方「拍照识别」+「相册上传」卡片
- 相册多选图片，逐张 OCR 识别后汇总确认
- AI 识别多日程逐条勾选导入系统日历

### 版本更新检测
- GET /api/app/version 返回版本号和下载链接
- App 启动时自动检测，弹窗提示更新

## API 设计

- 认证：JWT（access token 15min + refresh token 30d）
- 全部 API 前缀 `/api/`
- 响应格式：`ApiResponse<T>`（code, message, data）

### v1.1.0 新增

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/feedback` | POST | 提交反馈（Multipart） |
| `/api/feedback/{id}` | GET | 查看反馈详情 |
| `/api/feedback/image/{filename}` | GET | 获取反馈图片（已废弃，改 MinIO） |
| `/api/admin/login` | POST | 管理后台登录 |
| `/api/admin/feedbacks` | GET | 反馈列表（分页+筛选） |
| `/api/admin/feedbacks/{id}` | GET | 反馈详情 |
| `/api/admin/feedbacks/{id}/reply` | POST | 回复反馈 |
| `/api/admin/feedbacks/{id}/status` | POST | 更新状态 |
| `/api/admin/users` | GET | 用户列表 |
| `/api/admin/groups` | GET | 群组列表 |
| `/api/admin/schedules` | GET | 日程列表 |
| `/api/admin/groups/{id}` | PUT/DELETE | 编辑/删除群组 |
| `/api/admin/schedules` | POST | 新建日程 |
| `/api/admin/schedules/{id}` | PUT/DELETE | 编辑/删除日程 |

## 生产部署

### 服务器信息
- **IP**: `8.136.20.182`
- **系统**: Ubuntu 22.04, 3.4G RAM, 20G Disk
- **SSH**: `ssh -i backend/XAXINAN.pem root@8.136.20.182`
- **服务**: 全部 Docker 化（docker-compose）

### 部署命令
```bash
cd backend
./mvnw clean package -DskipTests
scp -i XAXINAN.pem target/backend-0.0.1-SNAPSHOT.jar root@8.136.20.182:/app/chronoflow.jar
ssh -i XAXINAN.pem root@8.136.20.182 '
  kill $(pgrep -f chronoflow.jar)
  sleep 2
  bash /app/start.sh &
'
```

### firewalls
- 8080: 应用
- 9000: MinIO API
- 9001: MinIO Console
- 3306: MySQL（仅 127.0.0.1）
- 6379: Redis（仅 127.0.0.1）

### 管理后台
- URL: `http://8.136.20.182:8080/admin/`
- 账号: `XAXINAN` / `2017@Build`

### MinIO
- Console: `http://8.136.20.182:9001`
- API: `http://8.136.20.182:9000`

## 安全

- 生产密钥全部通过环境变量注入（`/app/start.sh`）
- `.env`、`start-prod.sh`、`*.pem`、`.keystore` 已加入 `.gitignore`
- MySQL/Redis/MinIO 全部强随机密码
- CORS 限制生产域名 + localhost
- 管理员 JWT 独立于用户表验证
- 身份证 AES-256-GCM 加密（PBKDF2 60万次迭代）
- 反馈内容审核 + 限速保护

## 当前版本

**v1.1.0** (versionCode 3)

## 待完成

- [ ] HTTPS — 当前 HTTP 明文
- [ ] 单元测试 — 后端和前端都为 0
- [ ] 前端状态管理 — 引入 Provider 或 Riverpod
- [ ] iOS 适配 — 当前仅 Android
- [ ] 带宽升级 — 突发型 ECS 仅 ~1Mbps
- [ ] CDN — 静态资源加速

## 开发约定

- 异常消息用中文，服务层全部抛 `BusinessException`
- application.yaml 里所有值都用 `${ENV_VAR:default}` 模式
- .env 不提交（已在 .gitignore），.env.example 作为模板
- 分支策略：develop（日常） + production（稳定）
- `develop` 和 `production` 保持同步，仅 baseUrl 不同

## Commit 规范

```
feat: 功能描述        # 新功能
fix: 问题描述         # Bug 修复
refactor: 改动描述    # 重构
docs: 文档内容        # 文档
chore: 杂项描述       # 依赖、配置等
perf: 性能优化        # 性能
security: 安全相关    # 安全修复
```