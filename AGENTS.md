# AGENTS.md - beacon-toolkit

> 本文件用于约束 AI 编程助手在 `beacon-toolkit` 项目中的工作方式、代码规范、接口边界、移动端体验、无线电业务限制与本地开发环境。  
> 文档风格对齐 `../beacon-api/AGENTS.md`，但内容按当前 Flutter 客户端项目实际结构整理。

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 技术栈](#2-技术栈)
- [3. 本地开发环境](#3-本地开发环境)
- [4. AI 编程助手定位与响应规范](#4-ai-编程助手定位与响应规范)
- [5. 标准工作流](#5-标准工作流)
- [6. 客户端接口边界](#6-客户端接口边界)
- [7. Flutter 开发规范](#7-flutter-开发规范)
- [8. 状态管理与服务层规范](#8-状态管理与服务层规范)
- [9. 本地数据与安全存储规范](#9-本地数据与安全存储规范)
- [10. UI 与交互规范](#10-ui-与交互规范)
- [11. 业余无线电业务限制](#11-业余无线电业务限制)
- [12. 项目架构](#12-项目架构)
- [13. 外部项目边界](#13-外部项目边界)
- [14. 质量保障规范](#14-质量保障规范)
- [15. 最终交付清单](#15-最终交付清单)

---

## 1. 项目概览

### 1.1 项目名称

`beacon-toolkit`

### 1.2 项目定位

本项目是 Beacon 业余无线电工具箱的 Flutter 跨平台客户端，源自 `MeowzExam` mobile 模块，面向移动端与桌面端使用场景。

首版重点包含：

- OAuth 登录与本地 token 保存
- 题库、练习、模拟考试、收藏、学习记录
- AI 题目解析展示
- 无线电资料、频率表、常用工具入口
- QSO 日志客户端界面与同步能力
- 卫星发现、卫星详情、卫星追踪相关页面
- 主题设置、开发者设置、本地数据备份

### 1.3 明确不做

客户端不负责实现以下能力：

- 不在客户端内实现服务端业务规则绕过
- 不在客户端硬编码管理员权限或伪造权限状态
- 不在客户端保存 OAuth client secret、服务端私钥或 AI provider key
- 不把用户私有 QSO 日志做公开检索或公开排行
- 不把无线电频率、传播、卫星或计算结果表述为官方许可或法律建议

---

## 2. 技术栈

### 2.1 App

- Flutter
- Dart 3.x
- Material
- Provider
- Dio
- flutter_secure_storage
- sqflite / sqflite_common_ffi
- flutter_web_auth_2
- fl_chart
- flutter_map
- geolocator
- permission_handler
- sensors_plus

### 2.2 平台

当前仓库包含平台目录：

```text
android/
ios/
web/
windows/
macos/
linux/
```

跨平台改动必须确认目标平台差异，尤其是：

- Android 模拟器访问本机服务需要 `10.0.2.2`
- iOS 模拟器和桌面端通常使用 `localhost`
- Web 端默认使用同源或代理路径
- 桌面端 OAuth 回调依赖固定 localhost 端口

### 2.3 Build

常用构建命令：

```bash
flutter build apk
flutter build web
flutter build linux
```

iOS / macOS 构建需要对应 Apple 开发环境。

---

## 3. 本地开发环境

### 3.1 当前工作目录

```text
/data/D/Project/beacon-toolkit
```

### 3.2 安装依赖

```bash
flutter pub get
```

### 3.3 启动开发

```bash
flutter run
```

指定平台示例：

```bash
flutter run -d chrome
flutter run -d linux
flutter run -d android
```

### 3.4 接口配置

默认配置位于：

```text
lib/core/constants.dart
```

当前默认：

```text
MeowzExam API: http://localhost:3001/api/
OAuth:        http://localhost:8080
```

用户也可以通过应用内开发者设置写入 `custom_base_url`，`ApiClient` 会自动规范化为 `/api/` 结尾。

### 3.5 OAuth 回调

移动端：

```text
com.beacontoolkit://oauth/callback
```

桌面端：

```text
http://localhost:8000/oauth/callback
```

修改 OAuth 配置时必须同步检查 Android intent filter、iOS URL scheme、桌面端回调端口和服务端 OAuth 应用配置。

---

## 4. AI 编程助手定位与响应规范

### 4.1 核心定位

AI 编程助手在本项目中的定位：

```text
Flutter 客户端开发专家 x 移动端架构维护者 x 业余无线电工具体验设计助手
```

### 4.2 基本原则

- 使用简体中文回复
- 技术术语可以保留英文
- 优先给出可执行方案
- 修改代码前先阅读相关 `lib/pages`、`lib/services`、`lib/models` 和 `lib/core`
- 涉及接口路径、认证流程、本地存储、权限、定位权限或数据库结构时必须主动说明影响
- 涉及 UI 改动时必须考虑移动端小屏、桌面端宽屏和 Web 端差异
- 不确定的业务规则必须标注为待确认，不得擅自扩大范围
- 不得改动 `../beacon-api`、`../MeowzExam`、`../mp-oauth2`，除非用户明确要求

### 4.3 状态标签

较完整的过程回复建议使用：

```text
[分析]
[方案]
[执行]
[确认]
[完成]
```

---

## 5. 标准工作流

### 5.1 需求理解阶段

当用户提出开发需求时，必须先确认：

- 需求属于客户端、`beacon-api`、`MeowzExam` 还是 OAuth 服务
- 是否影响题库、练习、考试、AI 解析等旧业务
- 是否涉及无线电资料、QSO、卫星、定位或权限能力
- 是否需要新增模型、服务层、页面或本地数据库表
- 是否需要同步修改后端接口文档或跨项目契约

### 5.2 实施阶段

实施顺序：

1. 阅读现有页面、服务、模型和常量配置
2. 明确目标平台与接口来源
3. 修改模型和服务层
4. 修改页面、组件和状态管理
5. 处理错误态、加载态、空态和权限拒绝态
6. 运行格式化、静态分析、测试或说明未运行原因

### 5.3 禁止事项

- 禁止在 UI 中吞掉接口错误，只显示无意义失败
- 禁止把 access token、refresh token、OAuth code、Authorization header 输出到日志
- 禁止绕过 `ApiClient` 手写重复 Dio 配置，除非有明确平台原因
- 禁止在页面层直接堆叠复杂业务逻辑和数据解析
- 禁止把本地缓存当成权威服务端状态
- 禁止公开展示用户私有 QSO 明细

---

## 6. 客户端接口边界

### 6.1 MeowzExam API

题库与学习相关能力继续走 `MeowzExam`：

```text
http://localhost:3001/api/
```

包括：

- 题库列表
- 题目加载
- 练习记录
- 模拟考试
- 收藏题目
- AI 解析
- 学习统计

客户端中这类接口应通过 `lib/core/api_client.dart` 和对应 `lib/services/*` 调用。

### 6.2 beacon-api

无线电工具箱新增业务应面向 `beacon-api`：

```text
http://localhost:3002/api/v1/
```

包括：

- 用户无线电资料
- QSO 私有日志同步
- 频率表和常用频点
- 声码表
- Maidenhead 网格工具
- 天线计算工具
- 后续无线电工具类接口

如客户端需要同时接入两个后端，必须显式区分：

```text
examApiBaseUrl    -> MeowzExam /api/
beaconApiBaseUrl  -> beacon-api /api/v1/
```

不得假设两者响应结构、认证方式或路径规范一致。

### 6.3 OAuth

OAuth 服务只负责登录授权：

```text
http://localhost:8080
```

客户端不得直接持久化 OAuth client secret。普通业务接口应使用对应后端签发的业务 token。

### 6.4 请求头与 token

需要认证的请求使用：

```http
Authorization: Bearer <token>
Accept: application/json
Content-Type: application/json
```

禁止记录完整 token。错误上报、debugPrint 和异常展示都必须脱敏。

---

## 7. Flutter 开发规范

### 7.1 目录组织

当前推荐结构：

```text
lib/
  main.dart
  core/
    api_client.dart
    constants.dart
    configure_dio*.dart
  models/
  services/
  pages/
    discovery/
    developer/
    home/
    library/
    practice/
    profile/
    quiz/
    radio/
  widgets/
test/
```

### 7.2 命名规范

- 文件名使用 `snake_case.dart`
- 类名、Widget 名使用 `PascalCase`
- 变量和函数使用 `camelCase`
- 私有成员使用 `_` 前缀
- 页面以 `Page` 结尾，服务以 `Service` 结尾，模型名表达业务实体

### 7.3 Widget 规范

- 页面级 Widget 放在 `lib/pages/<module>/`
- 复用 Widget 放在 `lib/widgets/`
- 业务强绑定的小组件优先靠近所属页面
- 避免超大 `build` 方法，必要时拆分私有构建方法或小组件
- 异步 UI 必须覆盖 loading、error、empty、success 状态
- 使用 `const` 构造减少无意义重建

### 7.4 Dart 代码风格

- 遵循 `analysis_options.yaml` 和 `flutter_lints`
- 保持 `dart format` 输出
- 新增 ignore 必须有明确原因
- 不引入未使用依赖和未使用 import
- 复杂解析逻辑放在模型或服务层，不放在 Widget 中

---

## 8. 状态管理与服务层规范

### 8.1 Provider 使用

已有状态管理以 Provider 为主。新增全局状态前必须确认：

- 是否确实跨页面共享
- 是否可以由现有服务或页面局部状态承担
- 是否需要持久化

### 8.2 Service 规范

`lib/services/` 负责业务请求、数据整理和本地数据操作。

要求：

- 服务层返回明确的模型或结果对象
- 网络异常应转化为页面可展示的信息
- 不在服务层直接持有 BuildContext
- 不在服务层弹 Snackbar、Dialog 或做页面跳转
- 不重复创建全局 Dio 配置

### 8.3 Model 规范

`lib/models/` 中模型必须：

- 提供清晰的 `fromJson`
- 需要提交到接口时提供 `toJson`
- 对可空字段显式建模
- 对服务端字段兼容性保持谨慎，避免无提示丢数据

---

## 9. 本地数据与安全存储规范

### 9.1 Secure Storage

敏感数据使用：

```text
flutter_secure_storage
```

允许保存：

- access token
- refresh token
- 自定义 API base URL
- 必要的登录状态

禁止保存：

- OAuth client secret
- AI provider key
- 服务端私钥
- 未脱敏的调试凭据

### 9.2 SQLite / 本地缓存

本地数据库相关逻辑放在 `lib/services/local_database_service.dart` 或明确的本地数据服务中。

要求：

- schema 变更必须考虑迁移
- 缓存数据不得覆盖服务端权威状态
- 导入、备份和恢复必须处理版本兼容
- 用户私有数据导出前必须明确用户动作

### 9.3 权限

定位、传感器、文件选择等平台权限必须：

- 在使用前请求
- 处理拒绝、永久拒绝和系统关闭状态
- 给出可理解的错误提示
- 不在无权限时持续重试或阻塞主流程

---

## 10. UI 与交互规范

### 10.1 总体风格

本项目是工具型移动客户端，界面应：

- 信息清晰
- 操作路径短
- 适配小屏触控
- 兼顾桌面宽屏布局
- 避免营销式大 Hero 和无关装饰

### 10.2 页面状态

每个联网或异步页面必须明确：

- 加载中
- 空数据
- 错误
- 无权限
- 成功内容

### 10.3 表单和危险操作

- 表单必须校验必填项和格式
- 服务端错误必须展示给用户
- 删除、覆盖备份、登出、清空本地数据等危险操作必须二次确认
- 不允许点击后无反馈

### 10.4 无线电页面

频率、卫星、QSO、工具计算页面必须保留必要免责声明：

```text
仅供参考，请遵守当地法规和主管部门要求。
```

---

## 11. 业余无线电业务限制

### 11.1 合规边界

客户端可以展示：

- 题库与考试学习内容
- 静态频率表
- 常用频点
- CTCSS / DCS / DTCS 声码
- Maidenhead 网格结果
- 天线计算结果
- 卫星追踪与可见性辅助信息
- 用户私有 QSO 日志

客户端不得宣称：

- 用户具备发射权限
- 某频率在用户所在地一定合法
- 传播、卫星或定位结果是官方结论
- 私有 QSO 可被公开分享或检索

### 11.2 QSO 隐私

QSO 日志默认私有。

涉及 QSO 的功能必须注意：

- 查询当前用户自己的数据
- 同步时处理冲突和离线状态
- 导出前确认用户意图
- 不在日志中输出完整批量内容
- 不在公共页面展示他人私有日志

---

## 12. 项目架构

### 12.1 目录结构

```text
beacon-toolkit/
  AGENTS.md
  README.md
  pubspec.yaml
  analysis_options.yaml
  lib/
    main.dart
    core/
    models/
    services/
    pages/
    widgets/
  test/
  android/
  ios/
  web/
  windows/
  macos/
  linux/
```

### 12.2 客户端分层

```text
Pages / Widgets
  -> Services
    -> ApiClient / LocalDatabase / SecureStorage
      -> MeowzExam / beacon-api / OAuth
```

页面层负责展示和用户交互，服务层负责业务流程，模型层负责数据结构，核心层负责通用配置和底层客户端。

---

## 13. 外部项目边界

### 13.1 MeowzExam

`MeowzExam` 负责：

- 题库
- 练习
- 模拟考试
- 收藏题目
- 学习统计
- AI 解析

客户端必须兼容现有 `/api/...` 契约，不得擅自改服务端接口。

### 13.2 beacon-api

`beacon-api` 负责：

- 无线电资料
- 私有 QSO 同步
- 频率表、声码表、工具计算
- 业务 token
- 管理后台和审计

客户端接入时应遵循 `../beacon-api/AGENTS.md` 中的 API 规范。

### 13.3 mp-oauth2

`mp-oauth2` 负责：

- OAuth 登录
- 授权码
- access token
- userinfo

客户端只消费其登录能力，不把业务数据写入 OAuth 服务。

---

## 14. 质量保障规范

### 14.1 基础检查

提交前建议运行：

```bash
dart format .
flutter analyze
flutter test
```

如果无法运行，必须在交付说明中说明原因。

### 14.2 构建检查

按改动范围选择：

```bash
flutter build apk
flutter build web
flutter build linux
```

平台特定改动必须在对应平台验证或说明环境限制。

### 14.3 测试重点

必须覆盖或手动验证：

- 登录成功和失败
- token 过期或 401
- 自定义 API 地址保存和恢复
- 题库列表与题目加载
- 练习、考试、收藏流程
- AI 解析错误态
- QSO 新增、编辑、同步、离线冲突
- 频率表和无线电工具页面
- 卫星追踪权限、定位拒绝和无数据状态
- 本地备份、恢复和数据迁移

### 14.4 UI 验证

涉及 UI 时至少检查：

- 小屏手机布局
- 桌面或 Web 宽屏布局
- 加载态、空态、错误态
- 深色/浅色主题
- 长文本和接口错误信息不会溢出

---

## 15. 最终交付清单

较完整的交付必须说明：

- 已完成的页面、服务或模型改动
- 是否影响 MeowzExam、beacon-api 或 OAuth 契约
- 是否新增本地存储字段、SQLite 表或迁移
- 是否调整平台配置
- 已运行的测试和检查命令
- 未运行检查的原因
- 未完成或待用户确认的事项
