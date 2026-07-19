# 智流（MindFlow）设计分析文档

# 智流（MindFlow）设计分析文档

---

## 1\. 文档定位

本文档是 ChronoFlow 设计分析文档的**增量补充**，仅描述 MindFlow 新增模块的设计规划。ChronoFlow 已有模块（Auth、Schedule、Group、User、管理后台）的设计保持不变，不在本文档中重复描述。

**三层文档关系**：

|文档|回答的问题|状态|
|---|---|---|
|MindFlow 需求说明文档|"用户要什么"|✅ 已完成|
|MindFlow 需求分析文档|"技术上需要实现什么"|✅ 已完成|
|**本文档（设计分析）**|**"新增部分怎么做、代码怎么搭"**|**📝 当前**|

**读者对象**：后端开发、前端开发、架构师

---

## 2\. 系统分层设计——MindFlow 新增部分

### 2\.1 新增模块在整体分层中的位置

MindFlow 作为独立 package 插入 ChronoFlow 现有分层中，已有层职责不变：

```Plaintext
ChronoFlow 已有分层                  MindFlow 新增
─────────────────                    ────────────
表示层 (Flutter)
  ├── 首页/共享/我的 Tab (不变)
  └── 发现 Tab ................... ★ 新增，承载全部AI功能
        ├── AI学习系统 卡片 → 对话界面
        └── 我的云盘 卡片   → 云盘界面

接口层 (Controller)                  
  ├── Auth/Schedule/Group/... (不变)
  └── mindflow/ ................. ★ 新增 ChatController、ProfileController
                                    ResourceController、CloudController

业务层 (Service)
  ├── AuthService/ScheduleService/... (不变)
  └── mindflow/ ................. ★ 新增 Agent 引擎层
        ├── OrchestratorAgent        ← P0 核心
        ├── ProfileAgent
        ├── ResourceOrchestrator     ← P0 核心
        │     ├── DocAgent
        │     ├── MindMapAgent
        │     ├── QuizAgent
        │     ├── ReadingAgent
        │     └── CodeAgent
        ├── PlanAgent (P1)
        ├── QAAgent (P1)
        ├── EvaluateAgent (P1)
        └── 工具层：WebSearchTool / KnowledgeSearchTool / CalendarSyncTool

数据层
  ├── MySQL / Redis / MinIO (不变)
  └── ★ 新增 6 张表 + Milvus Lite (嵌入式向量库)
      ★ schedule 表新增 1 个字段 (schedule_type)
```

### 2\.2 ChronoFlow 复用清单

|复用项|复用方式|
|---|---|
|SecurityConfig、JwtTokenProvider、RateLimitingFilter|原封不动，新增 API 挂载在 `/api/v1/` 下受同一 AuthFilter 保护|
|ContentModerationService|原封不动，新增调用入口：资源生成后审核|
|MySQL / Redis / MinIO / MyBatis\-Plus|原封不动，新增 6 张表不修改旧表|
|Docker Compose 部署|原封不动，仅新增环境变量|
|Flutter 登录/注册/主页框架|原封不动，仅 HomePage 新增发现 Tab|
|ScheduleService|`schedule` 表新增 `schedule_type` 字段（`LEARNING_TASK`），日历同步时使用|

---

## 3\. 后端模块设计——Agent 引擎

### 3\.1 Agent 引擎模块依赖关系

```Plaintext
┌─────────────────────────────────────────────────────────────┐
│              MindFlow 新增 Controller 层                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │ ChatController│ │ResourceController│ │ProfileController│ │
│  │ (SSE流式)    │ │ (生成+列表)    │ │ (画像CRUD)    │      │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘        │
│  ┌──────────────┐        │                │                 │
│  │CloudController│       │                │                 │
│  │ (云盘目录)   │        │                │                 │
│  └──────┬───────┘        │                │                 │
└─────────┼────────────────┼────────────────┼─────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│                MindFlow 新增 Agent 引擎层                    │
│                                                             │
│  OrchestratorAgent ──── 意图分类 + 路由调度 (P0 核心)        │
│       │                                                     │
│       ├── ProfileAgent ──── 六维画像构建/查看/更新            │
│       │                                                     │
│       ├── ResourceOrchestrator ──── 资源生成编排 (P0 核心)    │
│       │    ├── DocAgent        ├── MindMapAgent             │
│       │    ├── QuizAgent       ├── ReadingAgent             │
│       │    └── CodeAgent                                    │
│       │                                                     │
│       ├── PlanAgent (P1)  ├── QAAgent (P1)                 │
│       └── EvaluateAgent (P1)                                │
│                                                             │
│  ┌──────────────── 工具层 ─────────────────────┐            │
│  │ WebSearchTool │ KnowledgeSearchTool │ CalendarSyncTool │  │
│  └─────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
          │                │
          ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│              新增基础设施                                     │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ 星火 API Svc │  │ Milvus Lite  │   (已有 Redis/MinIO     │
│  │ (Spark 4.0)  │  │ (嵌入式向量库)│     直接复用)           │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### 3\.2 各 Agent 职责边界

#### OrchestratorAgent（编排智能体）—— P0 核心

|属性|说明|
|---|---|
|职责|意图分类、Agent 路由调度、结果流式汇总|
|输入|用户自然语言 \+ 当前会话上下文|
|处理|调用星火 API 意图分类 → 路由到对应 Agent → 收集 Flux → 流式转发|
|输出|SSE 流（Flux\<ServerSentEvent\>）|
|关键约束|意图识别准确率 ≥ 90%，路由失败回退通用对话|
|设计参考|类似 Claude Code harness 的 tool\-use 调度模式|

**Orchestrator 调度流程**：

```Plaintext
用户输入
    │
    ▼
┌─────────────────────────────────────────────┐
│         OrchestratorAgent.execute()          │
│                                              │
│  1. 构建分类 Prompt（含上下文 + 意图标签表）    │
│  2. 调用星火 API 进行意图分类                  │
│  3. 根据分类结果路由：                         │
│                                              │
│     "画像" ────────▶ ProfileAgent            │
│     "资源生成" ────▶ ResourceOrchestrator     │
│     "学习规划" ────▶ PlanAgent (P1)          │
│     "答疑" ────────▶ QAAgent (P1)            │
│     "评估报告" ────▶ EvaluateAgent (P1)     │
│     "日历同步" ────▶ CalendarSyncTool        │
│     "通用对话" ────▶ 星火通用 Chat            │
│                                              │
│  4. 订阅 Agent 返回的 Flux<AgentEvent>        │
│  5. 封装为 SSE 事件流返回 Controller           │
└─────────────────────────────────────────────┘
```

**意图标签分类体系**：

|意图标签|路由目标|触发关键词/场景|P0/P1|
|---|---|---|---|
|`PROFILE_BUILD`|ProfileAgent|"开始学情测评"|P0|
|`PROFILE_VIEW`|ProfileAgent\(查询\)|"查看画像"|P0|
|`PROFILE_UPDATE`|ProfileAgent\(重建\)|"更新画像"|P0|
|`RESOURCE_GEN`|ResourceOrchestrator|"生成XX学习资料"、描述知识点|P0|
|`PLAN_GEN`|PlanAgent|"帮我规划"、"X天学完Y"|P1|
|`QA`|QAAgent|提问句式、疑问词开头|P1|
|`REPORT_VIEW`|EvaluateAgent|"查看学习报告"|P1|
|`CALENDAR_SYNC`|CalendarSyncTool|"同步到日历"|P1|
|`GENERAL_CHAT`|星火通用 Chat|默认兜底|P0|

#### ResourceOrchestrator（资源生成编排）—— P0 核心

|属性|说明|
|---|---|
|职责|协调 5 个子 Agent 并行生成资源，管理生成进度|
|输入|知识点 \+ 用户画像 \+ 细化后的知识结构|
|处理|知识点细化 → WebSearch 联网检索 → 5 子 Agent 并行生成 → 审核 → 持久化|
|输出|5 类资源的 Flux 流（逐类推送，先完成先推送）|
|关键约束|单类资源生成 ≤ 30s，5 类完整 ≤ 3min，成功率 ≥ 90%|

**执行流程**：

```Plaintext
用户输入："帮我生成机器学习决策树的学习资料"
    │
    ▼
┌─────────────────────────────────────────────┐
│       ResourceOrchestrator.execute()         │
│                                              │
│  Phase 1: 知识点细化（~3s）                   │
│  ├─ 星火解析模糊描述 → 结构化知识点树          │
│  └─ 输出: {"topic":"决策树",                 │
│            "subtopics":["信息增益","剪枝"...]}│
│                                              │
│  Phase 2: 联网检索（~5s）← 开发重点           │
│  ├─ WebSearchTool.search("决策树 机器学习")   │
│  └─ 提取关键段落注入 Agent 上下文              │
│                                              │
│  Phase 3: 并行生成（~25s）                    │
│  ├─ DocAgent/MindMapAgent/QuizAgent          │
│  ├─ ReadingAgent/CodeAgent → 5个并行         │
│  └─ CompletableFuture.allOf()                │
│                                              │
│  Phase 4: 审核 + 持久化                       │
│  ├─ ContentModerationService 逐类审核          │
│  └─ 通过 → MySQL + MinIO 写入                │
│                                              │
│  全程 SSE 流式推送进度                         │
└─────────────────────────────────────────────┘
```

**5 个子 Agent 规格**：

|Agent|输出内容|输出格式|个性化参数|
|---|---|---|---|
|DocAgent|概念引入→核心讲解→示例→误区→小结|Markdown|认知风格决定举例方式|
|MindMapAgent|知识体系树状结构|JSON 树|易错点节点红色标记|
|QuizAgent|选择题\(4选项\)\+填空题\+简答题，含解析|JSON|知识基础决定难度|
|ReadingAgent|知识背景→进阶概念→应用→推荐资源|Markdown|兴趣方向决定举例场景|
|CodeAgent|场景→分步实现→完整代码→扩展挑战|Markdown\+代码块|知识基础决定注释密度|

#### 其余 Agent——P1

|Agent|职责|约束|
|---|---|---|
|ProfileAgent \(P0\)|多轮对话采集六维画像数据 → 可视化画像卡片 → 查看/更新，`profile_version` 自增并保留最近 10 版历史快照|采集完整率 ≥ 95%，≤ 2min|
|PlanAgent|画像 \+ 知识点依赖 → 阶梯式学习路径 \+ 每日任务清单|路径适配准确率 ≥ 85%|
|QAAgent|分步文字解析 \+ Mermaid 可视化图解生成|答疑有效解决率 ≥ 90%|
|EvaluateAgent|学习行为采集 → 周期性分析报告|实时采集全量行为|

**六维画像指标**（ProfileAgent 采集）：知识基础、认知风格、学习节奏、薄弱知识点、学习目标、易错类型。

#### 工具层

|工具|职责|技术实现|P0/P1|
|---|---|---|---|
|**WebSearchTool**|资源生成前联网检索最新资料，降低幻觉|讯飞星火 Web Search / SearXNG，结果缓存 1h|P0|
|**KnowledgeSearchTool**|向量语义检索 \+ 关键词混合检索课程知识库|Milvus Lite \+ 星火 Embedding API|P0|
|**CalendarSyncTool**|AI 学习任务 → ChronoFlow 标准日程写入 Schedule 表|确定性工具（非 LLM），复用 ScheduleService|P1|

---

## 4\. 前端模块设计——发现 Tab 及其子页面

### 4\.1 页面结构

**所有 MindFlow 新增功能统一挂在 HomePage 的「发现 Tab」之下，不新增独立的一级页面。**

```Plaintext
App
└── HomePage (主页)
    ├── 首页 Tab (已有，不变)
    ├── 发现 Tab ──────────────────────────── ★ 新增，承载全部 MindFlow 功能
    │   ├── 卡片入口层 (DiscoverPage)
    │   │   ├── 【AI学习系统】卡片 ──→ push 对话页面
    │   │   └── 【我的云盘】卡片   ──→ push 云盘页面
    │   │
    │   ├── 对话界面 (ChatPage) ← 从 AI学习系统 卡片进入
    │   │   ├── 对话流（SSE 流式渲染）
    │   │   ├── 输入框 + 发送按钮
    │   │   ├── 使用指导入口（右上角图标 → push 指导页）
    │   │   └── 内联展示：画像卡片 / 资源卡片 / Mermaid 图解
    │   │
    │   ├── 云盘界面 (CloudPage) ← 从 我的云盘 卡片进入
    │   │   ├── 5 个文件夹（讲解文档/思维导图/练习题/拓展材料/代码案例）
    │   │   └── 文件夹 → 资源列表 → 资源详情
    │   │
    │   └── 使用指导 (GuidePage) ← 从对话界面右上角图标进入
    │       └── 静态说明：各功能使用方法 + 示例指令
    │
    ├── 共享 Tab (已有，不变)
    └── 我的 Tab (已有，不变)
```

### 4\.2 页面职责

|页面|路由|职责|
|---|---|---|
|**DiscoverPage**|HomePage 发现 Tab 默认展示|两个卡片入口，点击跳转子页面|
|**ChatPage**|`/discover/chat`|统一对话界面：会话管理、SSE 流式渲染、Markdown\+代码高亮、画像/资源/图解卡片内联|
|**CloudPage**|`/discover/cloud`|按类型文件夹浏览已生成资源，点击进入资源详情|
|**ResourceDetailPage**|`/discover/cloud/resource/:id`|资源全文展示（Markdown 渲染）|
|**GuidePage**|`/discover/guide`|静态使用说明：各功能使用方法和示例指令|

### 4\.3 新增 Flutter 服务

|服务|职责|P0/P1|
|---|---|---|
|**ChatService**|会话创建、消息存储、SSE 连接管理、流式事件解析|P0|
|**CloudService**|云盘目录、资源列表、资源详情 API 调用|P0|
|**ProfileService**|画像数据缓存与状态管理|P0|

### 4\.4 SSE 流式渲染方案

```Plaintext
ChatPage
    │
    ├── StreamBuilder<List<ChatMessage>>
    │   └── ListView.builder
    │       ├── TextBubble (用户消息)
    │       ├── TextBubble (AI 文本，逐字追加)
    │       ├── ProfileCard (画像卡片，内联)
    │       ├── ResourceCard (资源卡片，内联)
    │       ├── DiagramCard (Mermaid 图解，内联)
    │       └── ProgressIndicator (生成中...)
    │
    └── InputBar (输入框 + 发送)
        └── 发送 → 创建用户消息 → 打开 SSE → StreamController 推送事件
```

---

## 5\. 数据流设计

### 5\.1 Agent 编排调度主流程

```Plaintext
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────┐
│  用户   │    │ ChatController│    │Orchestrator │    │  目标Agent  │    │  数据层  │
│  输入   │───▶│ 接收消息     │───▶│  意图分类   │───▶│  执行业务   │───▶│  持久化  │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────┘
     │              │                   │                   │               │
     │  "帮我生成   │  POST /api/v1/    │  1.构建分类Prompt│  执行业务逻辑  │  MySQL
     │   决策树的   │  chat/message    │  2.星火分类      │  ·知识点细化   │  /Redis
     │   学习资料"  │                  │  3.返回意图标签  │  ·WebSearch    │  /MinIO
     │              │  Body:{message,  │  4.路由到Agent   │  ·5Agent并行   │
     │              │   sessionId}     │                  │  ·结果汇总     │
     │              │                  │                  │               │
     │  ◀── SSE 流式渲染（逐字/逐卡片）────────────────────┼───────────────┘
     │                                │
     ▼                                ▼
  ChatPage                         ChatController
  StreamBuilder                    Flux<ServerSentEvent>
```

**数据流向步骤**：

1. 用户消息 → `POST /api/v1/chat/message` → 写入 `chat_message` 表

2. 构建 AgentContext（取最近 N 轮会话历史 \+ 用户画像；上下文累计超 \~8000 token 时自动摘要压缩前半部分，保留最近 4 轮完整对话）

3. OrchestratorAgent 调用星火分类 → 返回意图标签

4. 路由到目标 Agent 执行（需要时调用 Tool）

5. Agent 返回 `Flux<AgentEvent>` → 封装为 SSE → Controller 透传

6. Flutter StreamBuilder 逐事件解析渲染（用户可随时发送新消息，发送时自动 cancel 当前 SSE 连接并开始新一轮请求）

7. 生成的资源写入 `learning_resource` 表 \+ MinIO；AI 回复写入 `chat_message` 表

### 5\.2 资源生成并行流程

```Plaintext
┌──────────────────┐
│ResourceOrchestrator│
└────────┬─────────┘
         ▼
┌──────────────────┐     ┌──────────────────┐
│  Phase 1         │────▶│  Phase 2         │
│  知识点细化(~3s) │     │  联网检索(~5s)   │
└──────────────────┘     └────────┬─────────┘
                                  │
                                  ▼
         ┌────────────────────────────────────────┐
         │       Phase 3: 5 Agent 并行生成 (~25s)  │
         │  DocAgent │ MindMapAgent │ QuizAgent   │
         │  ReadingAgent │ CodeAgent              │
         │  CompletableFuture.allOf() + Flux.merge│
         └────────────────────────────────────────┘
                                  │
                                  ▼
         ┌──────────────────┐     ┌──────────────────┐
         │  Phase 4         │────▶│  SSE 推送至前端   │
         │  审核 + 持久化    │     │  逐类展示         │
         └──────────────────┘     └──────────────────┘
```

### 5\.3 意图分类与降级路由

```Plaintext
用户输入 ──▶ Orchestrator.classify() ──▶ 意图标签 + 置信度
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    ▼                          ▼                          ▼
              置信度 ≥ 0.8              置信度 0.5-0.8              置信度 < 0.5
                    │                          │                          │
                    ▼                          ▼                          ▼
             直接路由到                  追加追问确认                 回退通用对话
             目标 Agent              "你是想生成资料还是做题？"    "能换个说法吗？"
```

---

## 6\. 接口设计——新增 API

> ChronoFlow 已有接口的 RESTful 规范、统一响应格式、认证机制均保持不变。以下仅列出 MindFlow 新增接口。

### 6\.1 新增接口清单

|方法|路径|说明|SSE|P0/P1|
|---|---|---|---|---|
|POST|`/api/v1/chat/session`|创建新会话||P0|
|GET|`/api/v1/chat/sessions`|会话列表||P0|
|GET|`/api/v1/chat/session/{id}/messages`|获取会话消息历史||P0|
|POST|`/api/v1/chat/message`|发送消息（触发 Agent 调度）|✅|P0|
|GET|`/api/v1/profile`|获取当前画像||P0|
|POST|`/api/v1/profile/build`|开始/继续画像构建对话|✅|P0|
|POST|`/api/v1/profile/update`|更新画像|✅|P0|
|POST|`/api/v1/resources/generate`|生成资源（单类/全部）|✅|P0|
|GET|`/api/v1/resources`|资源列表（按类型筛选）||P0|
|GET|`/api/v1/resources/{id}`|资源详情||P0|
|POST|`/api/v1/resources/{id}/feedback`|资源质量反馈||P0|
|GET|`/api/v1/cloud/directory`|云盘目录（5 文件夹）||P0|
|GET|`/api/v1/cloud/folder/{type}`|文件夹内资源列表||P0|
|POST|`/api/v1/plan/generate`|生成学习规划|✅|P1|
|GET|`/api/v1/plan/active`|当前活跃规划||P1|
|POST|`/api/v1/plan/sync-calendar`|同步到日历||P1|
|POST|`/api/v1/qa/ask`|提问答疑|✅|P1|
|GET|`/api/v1/evaluate/report`|学习评估报告||P1|

所有新增接口均需 JWT 认证（Bearer Token），挂载在 `/api/v1/` 路径下，受 ChronoFlow 已有 AuthFilter 统一保护。

### 6\.2 SSE 事件类型定义

|事件|数据结构|
|---|---|
|`message`|`{"type":"TEXT","content":"..."}`|
|`progress`|`{"type":"PROGRESS","stage":"...","message":"...","percent":0.3}`|
|`content`|`{"type":"RESOURCE_CARD","agent":"DocAgent","title":"...","content":"..."}`|
|`profile`|`{"type":"PROFILE_CARD","profile":{...}}`|
|`diagram`|`{"type":"DIAGRAM","mermaid":"graph TD...","caption":"..."}`|
|`error`|`{"type":"ERROR","message":"...","retryable":true}`|
|`complete`|`{"type":"COMPLETE","summary":"...","resources":[...]}`|

---

## 7\. 关键设计决策

### 7\.1 多智能体框架：Spring AI \+ AgentRegistry

|决策|Spring AI ChatClient \+ 自定义 AgentRegistry 注册模式|
|---|---|
|**理由**|ChronoFlow 已是 Spring Boot 3，Spring AI 无缝集成；ChatClient 的 Function Calling 和 Flux 流式输出开箱即用；不需引入额外重框架|
|**权衡**|轻量快速适合 7 天交付，但多 Agent 编排逻辑需自行编写|

```Java
// Agent 统一接口
public interface MindFlowAgent {
    String getIntentLabel();
    Flux<AgentEvent> execute(AgentContext ctx);
}

// Spring 自动发现所有 Agent Bean
@Component
public class AgentRegistry {
    private final Map<String, MindFlowAgent> agentMap;
    public AgentRegistry(List<MindFlowAgent> agents) {
        this.agentMap = agents.stream()
            .collect(Collectors.toMap(MindFlowAgent::getIntentLabel, a -> a));
    }
    public Optional<MindFlowAgent> resolve(String intent) {
        return Optional.ofNullable(agentMap.get(intent));
    }
}
```

### 7\.2 Agent 调度模式：harness 风格

|决策|中心化 Orchestrator 调度 \+ 各 Agent 独立执行|
|---|---|
|**理由**|参考 Claude Code harness 模式：一个调度中心负责意图理解→路由→收集结果，各 Agent 独立执行互不通信。新增 Agent 只需实现接口并注册|

|harness 要素|MindFlow 映射|
|---|---|
|意图理解→路由|`OrchestratorAgent.classify()` → `AgentRegistry.resolve()`|
|工具调用|WebSearchTool、KnowledgeSearchTool、CalendarSyncTool|
|并行执行|`CompletableFuture.allOf()` 5 子 Agent|
|流式输出|`Flux<AgentEvent>` → `Flux<ServerSentEvent>` → Flutter StreamBuilder|
|降级兜底|置信度 \< 0\.5 → GENERAL\_CHAT；Agent 异常 → 友好提示|

### 7\.3 WebSearch 联网检索

|决策|ResourceOrchestrator 并行生成前统一调用 WebSearchTool|
|---|---|
|**理由**|赛题"融合前沿 AI 技术"的关键体现；最新资料降低幻觉；统一检索减少重复 API 调用|
|**实现**|讯飞星火 Web Search 能力 / SearXNG；结果结构化注入各子 Agent System Prompt；缓存 1 小时|

### 7\.4 意图识别策略

|决策|星火 Prompt 分类 \+ 关键词规则兜底|
|---|---|
|**理由**|星火分类准确率 ≥ 90%，支持上下文语义；关键词规则在 API 超时时快速降级|

### 7\.5 ChronoFlow 代码复用策略

|决策|新增 `com.chronoflow.backend.mindflow` 独立 package，零侵入旧系统|
|---|---|
|**具体策略**|① 后端新增 mindflow package；② `schedule` 表仅新增 1 个字段；③ Flutter 新增 `pages/discover/` 目录，HomePage 新增发现 Tab。旧 Controller/Service 一行不改|

### 7\.6 向量数据库选型

|决策|Milvus Lite（嵌入式）|
|---|---|
|**理由**|零运维、7 天内快速集成，与 Milvus 生态兼容可平滑升级|

### 7\.7 流式输出方案

|决策|Spring Boot SSE（Flux\<ServerSentEvent\>）\+ Flutter StreamBuilder|
|---|---|
|**理由**|Spring AI 原生支持 Flux；无需 WebSocket 额外依赖；SSE 单向推送满足对话场景|

---

## 8\. 安全设计——新增部分

### 8\.1 内容安全（防幻觉 \+ 审核）

ChronoFlow 已有的阿里云 Green 审核管线增加 MindFlow 调用入口，并新增以下机制：

|机制|实现|
|---|---|
|**联网检索校验**|资源生成前 WebSearchTool 获取最新权威资料作为事实参照|
|**知识库 RAG 校验**|生成内容与课程知识库语义相似度对比，偏差 \> 阈值标记"待核实"|
|**AI 生成标注**|所有 AI 生成内容在 UI 中明确标注"AI 生成"标识|
|**置信度标记**|低置信度（\< 0\.6）内容虚线下面标注"AI 生成，请核实"|
|**内容审核**|生成资源经阿里云 Green TextModerationPlus 审核后发布|
|**敏感信息过滤**|用户输入和 AI 输出双向过滤违规学术内容|

### 8\.2 数据安全新增

|机制|实现|
|---|---|
|用户画像|全程加密存储（数据库字段级加密）|
|学习记录|用户隔离存储，通过 userId 严格过滤|
|内容用途|AI 生成内容仅用于个人学习，不支持商用导出|

> 传输安全（HTTPS）、密码存储（BCrypt）、JWT 认证、接口防注入等已有安全机制不变。

---

## 9\. 性能设计——新增部分

### 9\.1 新增缓存项

ChronoFlow 已有 Redis 缓存（Token、验证码、限流计数）保持不变，以下为新增：

|缓存对象|过期策略|
|---|---|
|用户画像|1 小时，更新时主动失效|
|WebSearch 结果|1 小时（同知识点查询缓存）|
|知识库检索热点|6 小时|
|会话上下文|30 分钟（会话活跃期间续期）|

### 9\.2 新增并发处理

|场景|实现|超时|
|---|---|---|
|意图分类|CompletableFuture 异步调用星火 API|5s|
|5 子 Agent 并行|`CompletableFuture.allOf()` \+ `Flux.merge()`|每子 Agent 30s|
|WebSearch 检索|异步 HTTP，失败不阻塞生成|5s|
|知识库向量检索|Milvus Lite 本地同步调用|2s|
|SSE 连接|60s 无活动自动关闭，前端自动重连|—|

### 9\.3 性能指标预算

|指标|目标值|
|---|---|
|首 Token 响应|P95 ≤ 3s|
|单类资源生成|P95 ≤ 30s|
|5 类资源完整生成|P95 ≤ 3min|
|画像构建|≤ 2min|
|意图分类|P95 ≤ 1\.5s|
|云盘列表加载|P95 ≤ 2s|
|并发用户|≥ 50|

---

## 10\. 可维护性设计——新增部分

### 10\.1 新增日志

ChronoFlow 已有日志体系增加以下 MindFlow 相关日志：

|级别|内容|
|---|---|
|ERROR|Agent 执行异常、星火 API 调用失败、内容审核拒绝|
|WARN|意图分类置信度低、WebSearch 超时、画像维度缺失|
|INFO|会话创建、Agent 路由、资源生成完成、画像更新|
|DEBUG|请求参数、Agent 中间输出、SSE 事件详情|

### 10\.2 新增异常类型

在已有 GlobalExceptionHandler 中新增 3 个异常处理器：

|异常类型|HTTP 状态码|
|---|---|
|`AgentExecutionException`|500|
|`IntentClassifyException`|500|
|`ContentReviewException`|422|

**Agent 异常降级策略**：

|场景|降级策略|
|---|---|
|星火 API 超时/不可用|"AI 服务暂时繁忙，请稍后重试"，日程功能不受影响|
|意图分类失败|回退 GENERAL\_CHAT|
|单子 Agent 生成失败|展示已生成资源 \+ 标注失败项 \+ 单独重试按钮|
|WebSearch 超时|跳过检索，仅基于星火知识和知识库生成|

### 10\.3 新增环境变量

```Plaintext
# MindFlow 新增配置（追加到已有 .env 文件）
SPARK_API_KEY=
SPARK_API_BASE_URL=https://spark-api-open.xf-yun.com/v1
SPARK_MODEL=spark-4.0
SPARK_TEMPERATURE=0.7
WEBSEARCH_ENABLED=true
WEBSEARCH_TIMEOUT_MS=5000
MILVUS_DB_PATH=/app/data/milvus_lite.db
VECTOR_EMBEDDING_MODEL=text-embedding-v1
AGENT_EXECUTION_TIMEOUT_MS=30000
INTENT_CLASSIFY_TIMEOUT_MS=5000
MAX_RESOURCE_GEN_PER_DAY=30
RESOURCE_CACHE_HOURS=1
```

---

## 11\. 前端状态管理——新增部分

MindFlow 新增页面的状态管理与已有 setState 模式保持一致，不引入额外状态管理框架：

|状态类型|管理方式|
|---|---|
|会话状态|ChatService 实例变量：sessionId、消息列表|
|**SSE 流状态**|StreamController \+ StreamBuilder（流式消息实时追加）|
|云盘列表|CloudService \+ setState：资源列表、文件夹筛选|
|画像状态|ProfileService 实例变量：画像数据跨页面缓存|

---

## 12\. 部署架构——新增部分

### 12\.1 新增组件

MindFlow 复用 ChronoFlow 已有的阿里云 ECS \+ Docker Compose（MySQL/Redis/MinIO）部署环境，仅新增以下依赖：

```Plaintext
已有 ECS Docker Compose 环境 (不变)
    │
    └── Spring Boot :8080
        ├── 原有模块 (不变)
        └── ★ MindFlow Agent 引擎 (新增)
            └── ★ Milvus Lite (嵌入式，无独立端口)

外部依赖：
  ★ 讯飞星火 API (新增)    已有 阿里云 Green (复用)
                            已有 阿里云 SMS (复用)
```

### 12\.2 七天开发部署节奏

|天|开发内容|部署动作|
|---|---|---|
|Day 1\-2|Agent 框架 \+ 星火 API 集成 \+ 6 张表 DDL|本地 Docker 就绪|
|Day 3\-4|Orchestrator \+ ResourceOrchestrator \+ 5 子 Agent \+ WebSearch|本地调试通过|
|Day 5|ProfileAgent \+ Flutter 发现 Tab（含对话页/云盘页）|前后端联调|
|Day 6|知识库构建 \+ 内容审核集成 \+ 全流程联调|ECS 测试环境|
|Day 7|Bug 修复 \+ 性能优化 \+ 使用指导页|ECS 生产 \+ APK 打包|

---

## 附录 A：新增数据库表概要

|表名|说明|P0/P1|
|---|---|---|
|`student_profile`|六维学习画像（user\_id, knowledge\_base/JSON, cognitive\_style, weak\_points/JSON, pace\_preference, interests/JSON, peak\_hours/JSON, profile\_version）|P0|
|`chat_session`|对话会话（user\_id, session\_id, title, status）|P0|
|`chat_message`|对话消息（session\_id, role, content, message\_type, metadata/JSON）|P0|
|`learning_resource`|学习资源（user\_id, resource\_type, title, content/MEDIUMTEXT, metadata/JSON, confidence\_score, reviewed）|P0|
|`learning_plan`|学习规划（user\_id, title, target, total\_days, plan\_data/JSON, status）|P1|
|`learning_behavior_log`|行为日志（user\_id, behavior\_type, resource\_id, duration\_seconds, result/JSON）|P1|

**旧表改造**：仅 `schedule` 表新增 `schedule_type VARCHAR(20) DEFAULT 'NORMAL'`（`LEARNING_TASK` 枚举值用于日历同步）。

---

## 附录 B：P0/P1 功能分期

|功能|P0（7天）|P1（后续）|
|---|---|---|
|发现 Tab 双卡片入口|✅||
|统一对话界面 \+ SSE 流式|✅||
|意图识别与 Agent 路由|✅||
|六维学习画像（构建\+查看\+更新）|✅||
|多智能体资源生成（5 类）|✅||
|WebSearch 联网检索|✅||
|云盘（按类型文件夹浏览）|✅||
|使用指导页面|✅||
|知识库构建与检索|✅||
|内容审核集成|✅||
|AI 学习规划 \+ 日历同步||✅|
|多模态答疑（文字\+图解）||✅|
|学习效果评估与报告||✅|
|画像动态更新 \+ 资源自适应||✅|

