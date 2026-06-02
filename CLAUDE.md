# ChronoFlow 开发指南

## 项目概述

时纪流 — 日程管理与通知解析应用。用户拍摄通知截图，AI 自动识别文字提取日程信息，支持个人日程和群组协作。

- **后端**: Spring Boot 3 + Java 17 + MyBatis-Plus + MySQL + Redis
- **前端**: Flutter（Android + iOS）
- **AI**:  阿里云 DashScope 百炼（日程解析）、阿里云 Green（内容审核）
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
    init.sql                   ← 建表 DDL
    pom.xml                    ← Maven 配置（Java 17, MyBatis-Plus 3.5.9）
    src/main/java/com/chronoflow/backend/
      BackendApplication.java
      config/                  ← Security, JWT, MyBatis-Plus, Redis, AI, Jackson
      controller/              ← REST 接口
        AuthController         ← 登录/注册/刷新令牌/登出/风控验证
        UserController         ← 用户信息/绑定/修改
        ScheduleController     ← 个人日程 CRUD
        GroupController        ← 群组管理（创建/加入/成员/审批/设置）
        NotificationController ← AI 通知解析
      service/                 ← 业务逻辑
        AuthService            ← 认证（含风控登录、短信登录、邮箱登录）
        UserService            ← 用户管理
        ScheduleService        ← 日程 CRUD + 群组日程
        GroupService           ← 群组操作
        NotificationService    ← AI 解析调度
        NotificationAiService  ← DashScope AI 调用
        ContentModerationService ← 阿里云 Green 审核
        EmailService           ← 邮件验证码
        SmsService             ← 短信验证码
        RiskControlService     ← 登录风控（Redis 计数 + 验证码挑战）
        RefreshTokenService    ← Refresh Token Redis 存储
        TokenBlacklistService  ← Token 黑名单
        RegisterService        ← 注册流程
      entity/                  ← MyBatis-Plus 实体
        User, Schedule, Group, GroupMember, JoinRequest, JoinRequestStatus
      dto/                     ← 请求/响应 DTO
      mapper/                  ← MyBatis-Plus Mapper 接口
      security/                ← JWT 生成/验证、认证过滤器、速率限制
      exception/               ← BusinessException（基类）、ContentModerationException、GlobalExceptionHandler
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
      utils/                   ← MessageUtils（Toast/对话框）
      widgets/                 ← ChronoInputField（共享输入框组件）
      pages/
        home_page.dart         ← 主页（日历 + 日程列表 + 个人中心）
        login_page.dart        ← 登录（三栏：密码/短信/邮箱）
        auth/                  ← 注册、启动页
        schedule/              ← 创建/编辑日程、通知解析、搜索、选择发布目标
        group/                 ← 群组列表、详情、成员管理、审批、创建/加入、扫码
        profile/               ← 个人信息、修改密码/昵称/手机、绑定邮箱、关于
    ios/                       ← iOS 工程
    android/                   ← Android 工程
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

7 张表（见 `init.sql`）：
- **users** — 用户（username, password, nickname, email, phone, nickname_updated_at）
- **schedules** — 日程（user_id, group_id?, title, description, location, schedule_time）
- **groups** — 群组（name, description, invite_code, creator_id, require_approval）
- **group_members** — 群组成员（group_id, user_id, nickname, is_admin）
- **join_requests** — 加群申请（group_id, user_id, status）

索引：schedules 有 user_id、group_id、schedule_time、复合 (user_id, group_id, schedule_time)、(group_id, schedule_time)

## API 设计

- 认证：JWT（access token 15min + refresh token 30d），access token 含 `typ=access` claim
- 全部 API 前缀 `/api/`，公开端点：`/api/auth/*`、`/api/auth/risk-verify`、`/actuator/health`
- 响应格式：`ApiResponse<T>`（code, message, data），控制器用 `ResponseEntity<ApiResponse<T>>`
- 用户ID 从 JWT filter 注入 `request.setAttribute("userId", userId)`

## 关键设计决策

### 异常处理
- `BusinessException` — 业务错误，消息透传给前端（HTTP 400）
- `ContentModerationException extends BusinessException` — 审核不通过
- 所有 Service 层抛 `BusinessException`，不抛纯 `RuntimeException`
- 未知 `RuntimeException` → GlobalExceptionHandler → 通用 "服务器内部错误"（HTTP 500）

### 群组权限
- 群主（creatorId）有全部权限
- 管理员（isAdmin=true）可创建群组日程、审批申请、移出成员
- 操作前检查 `isCreatorOrAdmin(userId, group)`

### Token 管理
- Access Token 15 分钟，用于 API 访问
- Refresh Token 30 天，仅用于 `/auth/refresh`
- JWT filter 拒绝 refresh token 访问 API（检查 `typ` claim）
- 登出时 access + refresh 都加入黑名单（Redis）
- Refresh 轮换：旧 refresh token 进入黑名单
- 单用户只保留最新一个 refresh token

### 风控
- `RiskControlService` — Redis 计数器 + 验证码挑战
- 登录频率过高或密码错误过多 → 要求短信/邮箱验证
- `RateLimitingFilter` — 内存速率限制（SMS 5次/分、登录 20次/分）
- 风控 token 存 Redis，10 分钟有效，不泄露 PII

### 内容审核
- 阿里云 Green `ugc_moderation_byllm` 服务
- `moderate(String text)` → null 通过 / 返回拒绝原因
- 服务不可用 → 抛异常（fail-closed）
- 审核点：用户名注册、昵称修改、群组名称/描述、日程标题/描述/地点

### 前端
- 无状态管理库，认证状态存 `ApiClient._currentUser`（静态字段）
- 统一 HTTP 客户端 `ApiClient` 自动附 Token、401 刷新、互斥锁防并发刷新
- 页面按功能分子目录：`auth/` `schedule/` `group/` `profile/`
- 共享输入框 `ChronoInputField` 替代各页面重复的 `_buildInput`
- 颜色系统统一在 `AppConstants`，页面不再定义本地 Color 常量

## 安全措施（已实施）

- [x] JWT `typ` claim 区分 access/refresh
- [x] 密码 BCrypt 加密，`@JsonIgnore` 防泄露
- [x] 速率限制（auth 端点）
- [x] 安全响应头（XSS、Content-Type、HSTS、Frame Options）
- [x] 内容审核 fail-closed
- [x] Token 黑名单 + 刷新轮换
- [x] bindEmail/bindPhone 唯一性检查
- [x] 风控登录挑战
- [x] 无 SQL 注入（MyBatis-Plus BaseMapper）
- [x] 敏感配置无硬编码默认值（需通过 .env 注入）

## 待完成

- [ ] 分页 — 所有列表接口当前返回全量数据
- [ ] 前端状态管理 — 引入 Provider 或 Riverpod
- [ ] 单元测试 — 后端和前端都为 0
- [ ] `PaginationInnerInterceptor` — MyBatis-Plus 3.5.9 不支持，需升级到 3.5.10+
- [ ] Spring profiles — 目前只有默认配置
- [ ] CORS 生产配置 — 当前允许所有 localhost
- [ ] 群组成员昵称同步 — 用户改名后群内昵称不同步
- [ ] 密码修改后使现有 token 失效
- [ ] `RefreshTokenService` 中 `(User) userDetails` 强制转型风险
- [ ] Docker 部署配置 — deploy/ 已删除，待重写

## 开发约定

- Java 包名保持小写 `com.chronoflow.backend`
- 项目名显示时用 `ChronoFlow`（C 和 F 大写）
- 异常消息用中文，服务层全部抛 `BusinessException`
- application.yaml 里所有值都用 `${ENV_VAR:default}` 模式
- .env 不提交（已在 .gitignore），.env.example 作为模板
- 后端 IDE 启动需在 Run Config 的 Environment Variables 导入 .env

## 协作流程

### 分支策略

**永远不要在 develop 分支上直接开发。** 每次开发新功能或修复 bug 都从 develop 拉一个新分支。

```bash
# 1. 确保本地 develop 是最新的
git checkout develop
git pull origin develop

# 2. 创建功能分支（命名：feat/功能描述 或 fix/问题描述）
git checkout -b feat/some-feature
```

分支命名规范：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `feat/` | 新功能 | `feat/user-avatar` |
| `fix/` | Bug 修复 | `fix/login-timeout` |
| `refactor/` | 重构 | `refactor/cache-layer` |
| `docs/` | 文档 | `docs/api-guide` |

### 开发流程

```
production ─────●──────────────●────  （只合并稳定版本）
               /              /
develop ─────●────●────●────●──────  （日常开发集成分支）
              \        /
feat/xxx       ●──●──●               （完成后合并到 develop 并删除）
```

1. 在分支上开发和自测
2. 确认无误后提交并推送到远端
3. 在 GitHub 上创建 Pull Request
4. 至少一人 Review 通过后合并到 develop
5. 合并后删除功能分支

```bash
# 在分支上开发
git checkout -b feat/my-feature
# ... 写代码、自测 ...

# 提交
git add -A
git commit -m "feat: 做了什么改动"
git push origin feat/my-feature

# 去 GitHub 创建 Pull Request
# Review → Merge → 删除分支
```

### Commit 规范

```
feat: 功能描述        # 新功能
fix: 问题描述         # Bug 修复
refactor: 改动描述    # 重构
docs: 文档内容        # 文档
chore: 杂项描述       # 依赖、配置等
```
