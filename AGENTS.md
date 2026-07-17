# Repository Guidelines

本文件约束 `beacon-toolkit` 项目中的 AI / 自动化开发行为。开发时优先遵循本文件，其次遵循用户当前消息。

## Project Structure & Module Organization

`lib/main.dart` 是 Flutter 入口。通用配置、Dio 初始化和常量放在 `lib/core/`；数据模型放在 `lib/models/`；网络请求、本地数据库、安全存储和业务流程放在 `lib/services/`；页面放在 `lib/pages/`，按 `discovery/`、`developer/`、`home/`、`library/`、`practice/`、`profile/`、`quiz/`、`radio/` 等模块组织；可复用组件放在 `lib/widgets/`。测试放在 `test/`。平台目录包括 `android/`、`ios/`、`web/`、`windows/`、`macos/`、`linux/`，跨平台改动必须确认对应平台差异。

需求规格文档放在 `docs/specs/`。每个需求使用独立目录 `docs/specs/<feature-slug>/`，至少包含 `requirements.md`、`design.md`、`tasks.md`。模板位于 `docs/specs/_template/`。

不要改动 `../beacon-api`、`../MeowzExam`、`../mp-oauth2`，除非用户明确要求。客户端改动不得擅自变更后端接口契约。

## Build, Test, and Development Commands

安装依赖：

```bash 
flutter pub get
```

本地运行：

```bash
flutter run
flutter run -d chrome
flutter run -d linux
flutter run -d android
```

基础检查：

```bash
dart format .
flutter analyze
flutter test
```

按改动范围选择构建：

```bash
flutter build apk
flutter build web
flutter build linux
```

iOS / macOS 构建需要对应 Apple 开发环境。无法运行检查或构建时，在交付说明中写清原因。

## Runtime Configuration & API Boundaries

默认配置在 `lib/core/constants.dart`。当前 MeowzExam API 为 `http://localhost:3001/api/`，OAuth 为 `http://localhost:8080`。开发者设置中的 `custom_base_url` 会由 `ApiClient` 规范化为 `/api/` 结尾。

题库、题目加载、练习记录、模拟考试、收藏题目、AI 解析和学习统计继续走 MeowzExam `/api/`，通过 `lib/core/api_client.dart` 和对应 `lib/services/*` 调用。

无线电资料、QSO 私有日志同步、频率表、声码表、Maidenhead 网格、天线计算等新增工具箱业务面向 `beacon-api`，默认边界为 `http://localhost:3002/api/v1/`。同时接入两个后端时必须显式区分 `examApiBaseUrl` 与 `beaconApiBaseUrl`，不得假设两者响应结构、认证方式或路径规范一致。

OAuth 只负责登录授权。客户端不得保存 OAuth client secret、服务端私钥或 AI provider key。认证请求使用 `Authorization: Bearer <token>`，日志、异常展示和错误上报不得输出完整 token、OAuth code 或 Authorization header。

OAuth 回调：

```text
移动端: com.beacontoolkit://oauth/callback
桌面端: http://localhost:8000/oauth/callback
```

修改 OAuth 配置时同步检查 Android intent filter、iOS URL scheme、桌面端回调端口和服务端 OAuth 应用配置。

## Coding Style & Naming Conventions

使用简体中文回复，技术术语可以保留英文。先读现有代码，再动手修改，优先沿用项目已有结构和写法。修改代码前根据范围阅读相关 `lib/pages`、`lib/services`、`lib/models` 和 `lib/core`。不要改无关文件，不要顺手重构；工作区已有用户改动时不要回滚、覆盖或格式化无关文件。

较完整的功能开发默认采用 spec 流程：先在 `docs/specs/<feature-slug>/requirements.md` 明确用户故事、范围和验收标准，再在 `design.md` 写架构、数据流、接口影响、UI/权限/存储影响，最后在 `tasks.md` 拆分可验证任务。小修小补可以直接实现，但涉及接口、认证、本地存储、权限、数据库、跨项目契约或复杂 UI 时必须先补 spec。

Dart 代码遵循 `analysis_options.yaml` 和 `flutter_lints`。文件名使用 `snake_case.dart`，类名和 Widget 名使用 `PascalCase`，变量和函数使用 `camelCase`，私有成员使用 `_` 前缀。页面以 `Page` 结尾，服务以 `Service` 结尾。保持 `dart format` 输出，不引入未使用依赖、未使用 import 或无原因的 ignore。

页面级 Widget 放在 `lib/pages/<module>/`，复用 Widget 放在 `lib/widgets/`，业务强绑定的小组件优先靠近所属页面。避免超大 `build` 方法，必要时拆分私有构建方法或小组件。复杂解析逻辑放在模型或服务层，不放在 Widget 中。

## State, Services, and Local Data

状态管理以 Provider 为主。新增全局状态前先确认是否确实跨页面共享、是否可由服务或页面局部状态承担、是否需要持久化。

`lib/services/` 负责业务请求、数据整理和本地数据操作。服务层返回明确模型或结果对象，网络异常要转化为页面可展示的信息。服务层不要持有 `BuildContext`，不要弹 Snackbar、Dialog 或做页面跳转，不要绕过 `ApiClient` 重复创建全局 Dio 配置，除非有明确平台原因。

`lib/models/` 中模型需要清晰的 `fromJson`，提交接口时提供 `toJson`，可空字段显式建模。对服务端字段兼容保持谨慎，避免无提示丢数据。

敏感数据使用 `flutter_secure_storage`。允许保存 access token、refresh token、自定义 API base URL 和必要登录状态；禁止保存 OAuth client secret、AI provider key、服务端私钥和未脱敏调试凭据。SQLite / 本地缓存逻辑放在 `lib/services/local_database_service.dart` 或明确的本地数据服务中；schema 变更必须考虑迁移，缓存不得覆盖服务端权威状态。

## UI, Permissions, and Radio Domain Rules

本项目是工具型 Flutter 客户端，界面应信息清晰、操作路径短、适配小屏触控并兼顾桌面和 Web 宽屏。避免营销式大 Hero 和无关装饰。联网或异步页面必须覆盖 loading、empty、error、permission denied 和 success 状态。服务端错误要展示给用户，不允许点击后无反馈。

涉及 UI 改动时至少考虑小屏手机、桌面或 Web 宽屏、深色/浅色主题、长文本和接口错误信息不溢出。表单必须校验必填项和格式。删除、覆盖备份、登出、清空本地数据等危险操作必须二次确认。

定位、传感器、文件选择等平台权限必须在使用前请求，并处理拒绝、永久拒绝和系统关闭状态；无权限时给出可理解提示，不要持续重试或阻塞主流程。

频率、卫星、QSO、工具计算页面必须保留必要免责声明：

```text
仅供参考，请遵守当地法规和主管部门要求。
```

客户端可以展示题库与考试学习内容、静态频率表、常用频点、CTCSS / DCS / DTCS 声码、Maidenhead 网格结果、天线计算结果、卫星追踪与可见性辅助信息和用户私有 QSO 日志。不得宣称用户具备发射权限、某频率在用户所在地一定合法、传播/卫星/定位结果是官方结论，或私有 QSO 可被公开分享或检索。

QSO 日志默认私有。涉及 QSO 的功能必须只查询当前用户自己的数据，同步时处理冲突和离线状态，导出前确认用户意图，不在日志中输出完整批量内容，不在公共页面展示他人私有日志。

## Testing Guidelines

提交前建议运行 `dart format .`、`flutter analyze`、`flutter test`。涉及平台能力时按范围运行 `flutter build apk`、`flutter build web` 或 `flutter build linux`，无法验证的平台要说明环境限制。

改动影响登录、接口配置、认证、本地存储、权限、定位、数据库结构或跨项目契约时，交付说明必须主动写清影响。重点验证登录成功/失败、401 或 token 过期、自定义 API 地址保存和恢复、题库列表与题目加载、练习/考试/收藏流程、AI 解析错误态、QSO 新增/编辑/同步/离线冲突、频率表和无线电工具页面、卫星追踪权限/定位拒绝/无数据状态、本地备份/恢复/迁移。

## Commit & Delivery Guidelines

最终交付说明包含：已完成的页面、服务或模型改动；是否影响 MeowzExam、beacon-api 或 OAuth 契约；是否新增本地存储字段、SQLite 表或迁移；是否调整平台配置；已运行的测试和检查命令；未运行检查的原因；未完成或待用户确认事项。

涉及 spec 的交付还要说明对应 `docs/specs/<feature-slug>/` 路径，以及 requirements、design、tasks 是否已同步更新。如果用户要求提交代码，先检查 `git status`，只提交本次相关文件。提交信息保持简洁，优先使用 `feat:`、`fix:`、`docs:`、`refactor:`、`test:` 等前缀。
