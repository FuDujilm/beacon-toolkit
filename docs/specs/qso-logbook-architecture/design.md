# QSO Logbook Architecture Design

## Architecture

日志子系统按“页面层、业务服务层、参考数据层、本地存储层、远端集成层”拆分，避免页面直接承担解析、导入导出、状态查询和存储迁移职责。

### 第一阶段目标

第一阶段聚焦“结构重组和本地能力补齐”，不追求一次性完成所有外部日志高级能力。

- 保持主 tab 轻量化，能完成最近日志预览和快速写入。
- 在工具页新增完整日志管理入口和基础管理页面。
- 建立日志本、台站资料和 ADIF 导入导出的模型与服务边界。
- 建立 LoTW 凭据管理和查询入口，但不强制在第一阶段落地完整上传签名链路。
- 完成 SQLite 迁移，为后续批量录入、状态同步和上传流程留出扩展位。

### 页面层

- `RadioLogPage` 不再承担完整日志管理职责，后续调整为主页面 tab 内的轻量日志卡片或轻量页面，负责：
  - 最近通联预览
  - 快速新增单条 QSO
  - 快速批量录入入口
  - 最近一次同步或外部状态摘要
- `RadioToolsPage` 新增独立的日志管理工具入口，例如 `LoTW 日志管理` 或等价命名，作为完整日志能力承载页。
- 新增完整日志管理页，负责展示日志本列表、日志本切换、批量操作、导入导出、外部状态查询与上传入口。
- 新增日志本详情页，负责展示某个日志本下的 QSO 列表、筛选、批量操作和导入导出入口。
- 新增台站资料页，负责维护本台呼号、网格、DXCC、州省县、市、CQ/ITU 分区、IOTA、备注等资料。
- 新增外部日志服务页，第一阶段至少承载 LoTW 查询入口、凭据设置入口和状态说明。
- 快速录入保持独立录入体验，不与完整表单混在同一个弹窗中。

### 第一阶段页面清单

- 主 tab / 主页面日志区域
  - 最近通联列表
  - 快速新增按钮
  - 快速批量录入入口
  - 进入完整日志管理页的入口
- 工具页新增入口
  - `日志管理`
  - 命名可在实现时再定，但不建议直接挂过长标题
- `LogbookManagerPage`
  - 日志本列表
  - 默认日志本标记
  - 新建 / 重命名 / 删除日志本
  - 最近导入导出摘要
  - 进入日志本详情页
  - 进入台站资料页
  - 进入 LoTW 页面
- `LogbookDetailPage`
  - QSO 列表
  - 筛选与搜索
  - 新增 / 编辑 / 删除
  - 批量导入 ADIF
  - 批量导出 ADIF
  - 批量状态同步入口
- `StationProfilesPage`
  - 台站资料列表
  - 默认台站切换
  - 新增 / 编辑 / 删除
- `LotwManagerPage`
  - 凭据设置
  - 查询条件
  - 查询结果列表
  - 本地状态同步入口
  - 平台能力提示
- `QuickQsoEntryPage`
  - 多行文本输入
  - 歧义提示
  - 解析结果确认
  - 批量写入目标日志本选择

### 入口策略

- 主导航中的日志相关 tab 面向高频场景，要求：
  - 单屏快速查看
  - 少步骤写入
  - 不承载复杂配置和低频管理操作
- 工具页中的独立日志管理入口面向低频但复杂场景，要求：
  - 能访问完整日志本体系
  - 能执行 ADIF 导入导出
  - 能进入 LoTW 查询、状态同步和后续上传流程
  - 能管理台站资料和高级设置
- 两类入口共享同一套底层模型和服务，但 UI 层级与交互复杂度明确分离。

### 业务服务层

- `QsoLogbookService`
  - 管理日志本创建、重命名、删除、默认日志本选择、日志本与 QSO 的关联。
- `QsoEntryService`
  - 管理单条 QSO 的新增、编辑、删除、校验和字段补全。
- `StationProfileService`
  - 管理台站资料的增删改查和默认台站切换。
- `AdifService`
  - 负责 ADIF 导入、导出、字段映射、基础校验和重复记录判定。
- `QuickQsoParserService`
  - 负责批量文本录入、歧义识别、字段推断和错误明细输出。
- `LotwQueryService`
  - 负责查询外部状态、解析响应、映射到本地展示模型。
- `LotwWorkflowService`
  - 负责“待上传集合校验、状态过滤、生成摘要、调用上传实现”的编排。
- `RadioReferenceRepository`
  - 统一提供频段、模式、传播方式、卫星别名、行政区映射等参考数据。

### 第一阶段服务接口草案

- `QsoLogbookService`
  - `Future<List<QsoLogbook>> getLogbooks()`
  - `Future<QsoLogbook> createLogbook(...)`
  - `Future<QsoLogbook> updateLogbook(...)`
  - `Future<void> deleteLogbook(String id)`
  - `Future<void> setDefaultLogbook(String id)`
- `StationProfileService`
  - `Future<List<StationProfile>> getProfiles()`
  - `Future<StationProfile> saveProfile(...)`
  - `Future<void> deleteProfile(String id)`
  - `Future<void> setDefaultProfile(String id)`
- `QsoEntryService`
  - `Future<List<QsoLog>> getLogs({String? logbookId, ...filters})`
  - `Future<QsoLog> saveLog(QsoLogDraft draft)`
  - `Future<void> deleteLog(String id)`
  - `Future<QsoValidationResult> validateDraft(QsoLogDraft draft)`
- `AdifService`
  - `Future<AdifImportPreview> previewImport(...)`
  - `Future<AdifImportResult> importToLogbook(...)`
  - `Future<AdifExportResult> exportLogs(...)`
- `QuickQsoParserService`
  - `Future<QuickParsePreview> parseLines(...)`
  - `Future<QuickParseCommitResult> commitParsedLogs(...)`
- `LotwQueryService`
  - `Future<LotwQueryResult> query(LotwQueryInput input)`
  - `Future<void> saveCredentials(...)`
  - `Future<void> clearCredentials()`
- `LotwWorkflowService`
  - 第一阶段只保留接口定义和状态摘要能力，不要求完整实现上传

### 存储层

- SQLite 负责持久化：
  - 日志本
  - 台站资料
  - QSO 记录
  - 导入来源元数据
  - 外部状态缓存与同步时间
  - 快速录入草稿或最近输入上下文（如有必要）
- Secure Storage 负责持久化：
  - LoTW 用户名和密码
  - 未来如需支持证书或平台安全存储引用，只保存安全引用或加密后的必要元数据
- 不允许进入本地 SQLite 的敏感内容：
  - OAuth client secret
  - 私钥明文
  - 服务端私钥
  - 未加密的第三方凭据备份

### 第一阶段 SQLite 结构草案

- `qso_logbooks`
  - `id TEXT PRIMARY KEY`
  - `name TEXT NOT NULL`
  - `description TEXT NOT NULL DEFAULT ''`
  - `is_default INTEGER NOT NULL DEFAULT 0`
  - `created_at TEXT NOT NULL`
  - `updated_at TEXT`
- `station_profiles`
  - `id TEXT PRIMARY KEY`
  - `name TEXT NOT NULL`
  - `station_callsign TEXT NOT NULL`
  - `operator_callsign TEXT NOT NULL DEFAULT ''`
  - `grid_square TEXT NOT NULL DEFAULT ''`
  - `dxcc_entity TEXT NOT NULL DEFAULT ''`
  - `cq_zone TEXT NOT NULL DEFAULT ''`
  - `itu_zone TEXT NOT NULL DEFAULT ''`
  - `state TEXT NOT NULL DEFAULT ''`
  - `county TEXT NOT NULL DEFAULT ''`
  - `iota TEXT NOT NULL DEFAULT ''`
  - `notes TEXT NOT NULL DEFAULT ''`
  - `is_default INTEGER NOT NULL DEFAULT 0`
  - `created_at TEXT NOT NULL`
  - `updated_at TEXT`
- `qso_logs`
  - 保留现有字段
  - 新增 `logbook_id TEXT`
  - 新增 `station_profile_id TEXT`
  - 预留后续扩展字段时优先采用可空迁移
- `qso_import_jobs`
  - `id TEXT PRIMARY KEY`
  - `logbook_id TEXT NOT NULL`
  - `source_name TEXT NOT NULL`
  - `source_type TEXT NOT NULL`
  - `total_count INTEGER NOT NULL DEFAULT 0`
  - `inserted_count INTEGER NOT NULL DEFAULT 0`
  - `skipped_count INTEGER NOT NULL DEFAULT 0`
  - `error_count INTEGER NOT NULL DEFAULT 0`
  - `created_at TEXT NOT NULL`

### 证书与私钥安全边界

- 私钥、`.p12` 原始内容和证书导入密码不得上传到 `beacon-api`、MeowzExam API、OAuth 服务或其他自有后端。
- 私钥不得明文落到 SQLite，也不得作为普通字符串写入 `flutter_secure_storage`。
- 客户端导入证书后，优先写入平台安全存储：
  - Android 使用 `Android Keystore`
  - iOS 后续如支持，使用 `Keychain` 或系统等价安全容器
- Flutter 层仅保存必要元数据：
  - 证书别名
  - callsign / 台站绑定关系
  - 指纹摘要
  - 有效期
  - 平台密钥引用标识
- 桌面和 Web 第一阶段不承诺支持本地私钥签名；若平台不具备可靠安全存储，则仅提供 ADIF 导入导出、日志管理和外部状态查询。
- 所有签名动作必须在客户端本地完成。Flutter 业务层向平台层传递待签名数据和密钥引用，不传递可复用的私钥明文。
- 若未来提供备份能力，只允许用户主动导出并显式二次确认，不允许默认自动云备份私钥材料。
- 错误日志、调试输出和异常提示中不得包含：
  - 私钥内容
  - `.p12` 原文
  - 导入密码
  - 完整证书内容
  - 第三方服务完整 Authorization header

### 远端集成层

- MeowzExam API 不参与日志架构演进。
- `beacon-api` 继续负责用户私有 QSO 云同步、QSL 公开确认、频率表等无线电业务。
- 外部日志服务查询优先由客户端直连，以减少敏感凭据中转。
- 如后续需要 `beacon-api` 辅助，只允许承载非敏感能力，例如状态回写、公共映射表下发、非凭据型同步摘要。

## Data Flow

### 1. 本地 QSO 录入

1. 用户在主 tab 的快速写入区、日志本详情页或快速录入页输入通联信息。
2. `QsoEntryService` 或 `QuickQsoParserService` 负责校验和结构化。
3. 若用户选择台站资料，则 `StationProfileService` 提供默认字段补全。
4. 结果写入 SQLite，并记录所属日志本、更新时间和外部状态初始值。
5. 主 tab 只回显最近记录和轻量提示；复杂错误明细在完整日志管理页中可进一步查看。

### 1.1 第一阶段录入规则

- 若用户未显式选择日志本，则写入默认日志本。
- 若用户未显式选择台站资料，则优先使用默认台站；没有默认台站时允许为空，但要在导出或上传前补齐必要字段。
- 主 tab 的快速写入只暴露高频字段：
  - 日期时间
  - 对方呼号
  - 频段
  - 模式
  - 频率
  - 信号报告
  - 备注
- 卫星、传播方式、网格等低频字段保留在完整编辑页或快速解析结果确认页中。

### 2. ADIF 导入

1. 用户选择本地文件并指定目标日志本。
2. `AdifService` 解析文件、映射字段、标记缺失字段、执行重复判定。
3. 可导入记录批量写入 SQLite，并保存导入来源、导入时间和导入摘要。
4. UI 显示总数、成功数、跳过数、错误数，并允许用户查看失败原因。

### 3. ADIF 导出

1. 用户从日志本详情页选择全部或部分记录导出。
2. `AdifService` 根据 QSO、台站资料和导出选项生成 ADIF 文本。
3. 文件保存到用户选择的位置或平台默认下载目录。
4. UI 显示导出路径或失败信息。

### 3.1 第一阶段 ADIF 处理边界

- 先支持常见字段的稳定导入导出，不追求一次覆盖全部 ADIF 扩展字段。
- 对无法映射的字段：
  - 导入时记录为“忽略字段摘要”
  - 不因未知字段直接中断整个导入流程
- 重复判定优先使用组合指纹：
  - `callsign`
  - `station_callsign`
  - `date_time`
  - `band`
  - `mode`
  - `frequency`

### 4. LoTW 查询

1. 用户在设置或外部日志服务页填写凭据。
2. 凭据写入 Secure Storage，不进入 SQLite。
3. 用户发起查询后，`LotwQueryService` 直接请求外部服务并解析结果。
4. 查询结果映射为页面展示对象，必要时可将摘要状态回写本地缓存。
5. 若用户选择同步状态，则仅更新本地 `lotw_status`、最近查询时间和必要摘要字段。
6. 主 tab 最多展示最近查询摘要或待处理数量，不承载完整查询列表和高级筛选。

### 5. 后续上传流程

1. 用户从日志本详情页选择待处理记录和台站资料。
2. `LotwWorkflowService` 执行校验、过滤、重复状态检查和摘要生成。
3. 平台支持上传时再调用具体实现；平台不支持时，保留导出中间产物或提示能力受限。
4. 上传结果只回写必要状态，不保存不必要的敏感响应内容。

## API Contract

本 spec 当前不要求新增或修改既有接口契约。

预期涉及的远端边界如下：

- MeowzExam API：无接口改动。
- `beacon-api`：
  - 现有 `/api/v1/` QSO 日志同步和 QSL 确认接口继续保持兼容。
  - 如未来新增日志辅助接口，应使用独立路径并明确标注是否需要鉴权。
- 外部日志服务：
  - 由客户端直接请求。
  - 认证凭据仅在客户端内存和 Secure Storage 中短时使用。

错误处理原则：

- 网络错误、认证失败、响应格式错误和字段校验错误分别转译成用户可理解的信息。
- 不在日志、异常提示或埋点中输出完整 token、密码、Authorization header 或证书内容。

## UI States

- Loading:
  - 主 tab 最近日志加载中
  - 日志本列表加载中
  - ADIF 导入解析中
  - 外部状态查询中
- Empty:
  - 主 tab 暂无最近通联
  - 无日志本
  - 日志本下暂无 QSO
  - 查询结果为空
- Error:
  - 文件读取失败
  - 解析失败
  - 鉴权失败
  - 远端服务不可用
- Permission denied:
  - 文件访问被拒绝
  - 平台不支持相关能力
- Success:
  - 主 tab 快速写入成功
  - 日志本创建成功
  - QSO 保存成功
  - ADIF 导入或导出成功
  - 外部状态查询成功

## Storage & Permissions

- SQLite 需要新增或演进以下结构：
  - `qso_logbooks`
  - `station_profiles`
  - `qso_logs` 增补 `logbook_id`、`station_profile_id` 及后续导出/状态追踪所需字段
  - `qso_import_jobs` 或等价导入元数据表
- 迁移策略：
  - 旧有 `qso_logs` 默认归入“默认日志本”
  - 如旧记录存在 `station_callsign`，允许后续通过批处理或首次编辑时补建台站资料映射，不要求迁移时一次性完全归类
  - 旧记录缺失的新字段采用可空或有明确默认值的迁移方案
  - 升级时不得丢失既有 QSO 和 QSL 状态
- 文件权限：
  - 使用前请求文件选择权限或走平台文件选择器
  - 被拒绝时提示用户，不阻塞其他日志功能
- Secure Storage：
  - 保存 LoTW 凭据和必要设置项
  - 未来若引入平台安全能力，应优先保存引用而不是原始密钥材料
- 证书导入：
  - 使用文件选择器让用户主动选择文件
  - 导入后尽快清理内存中的原始二进制内容
  - 不在临时目录长期保留未清理的导入文件副本

## Radio Compliance

- 所有频率、传播、卫星和位置相关结果页面继续保留免责声明：

```text
仅供参考，请遵守当地法规和主管部门要求。
```

- 日志功能仅记录和管理用户私有通联，不得默认公开展示他人或其他账号的日志内容。
- 查询或同步外部日志状态时，不得暗示用户已自动取得发射资格、频率合法性结论或官方确认结论。
- 导入导出和上传能力应强调“用户自行核对内容正确性”。

## Testing

### 第一阶段重点验证

- 旧数据库升级后自动创建默认日志本。
- 主 tab 可查看最近通联并快速写入默认日志本。
- 工具页可进入完整日志管理页。
- 日志本创建、重命名、删除和默认切换可用。
- 台站资料创建、编辑、删除和默认切换可用。
- ADIF 导入预览、导入结果摘要、导出文件生成可用。
- LoTW 凭据可安全保存、读取和清除。
- 不支持私钥签名的平台不会暴露误导性入口。

- 单元测试：
  - `AdifService`
  - `QuickQsoParserService`
  - `QsoLogbookService`
  - `StationProfileService`
  - LoTW 查询结果解析
- Widget / 页面测试：
  - 主 tab 日志预览与快速写入区域
  - 工具页日志管理入口
  - 完整日志管理页
  - 日志本列表页
  - 日志本详情页
  - 台站资料页
  - 外部状态查询页
- 数据迁移测试：
  - 旧版 `qso_logs` 升级到新结构
  - 默认日志本补建逻辑
- 手动验证：
  - 小屏手机
  - 桌面宽屏
  - Web 文件导入导出兼容性
  - 凭据保存、恢复、删除
  - 旧数据升级后日志与 QSL 状态不丢失
