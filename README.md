# Beacon Toolkit

Beacon Toolkit 是一个面向业余无线电爱好者的 Flutter 跨平台工具箱，覆盖考试训练、呼号查询、QSO 日志、QSL/QSO 确认、卫星追踪、传播预测、频率划分和网格定位等常用工作流。

项目源自 `MeowzExam` mobile 模块，目前已扩展为独立的无线电工具客户端，支持 Android、iOS、Web、Linux、Windows 和 macOS。

> 所有频率、传播、卫星和定位结果仅供参考，请遵守当地法规和主管部门要求。

## 功能概览

| 模块 | 能力 |
| --- | --- |
| 首页 | 用户呼号状态、实时频率、太阳活动、常用工具入口、考试训练摘要 |
| 考试训练 | CRAC 题库、练习、模拟考试、收藏、学习记录、AI 题目解析 |
| 呼号查询 | Beacon API 呼号信息、QRZ XML API、DXCC、Biography HTML 自渲染 |
| QSO 日志 | 新增/编辑/删除、快速记录、多行解析、模板记录、本地缓存、云端同步 |
| QSL/QSO 确认 | 静态/动态二维码、验证码、链接确认、平台用户确认、手动确认策略 |
| 卫星工具 | 卫星订阅、卫星详情、AMSAT 状态、TLE 更新、对星辅助、多普勒频移预测 |
| 传播预测 | HAMQSL、SEPC 数据源、Kp、Ap、F10.7、TEC、foF2、太阳图像、趋势图 |
| 地图与定位 | OpenStreetMap、天地图配置、Maidenhead Grid 查询、设备定位获取 QTH/Grid |
| 频率划分 | 中国大陆、中国香港、中国澳门等地区频率表，本地同步与缓存 |
| 开发者设置 | API 地址、QRZ、LLM、SMTP、天地图 Token 等高级配置 |

## 技术栈

| 类型 | 技术 |
| --- | --- |
| 应用框架 | Flutter / Dart |
| 状态管理 | Provider |
| 网络请求 | Dio / http |
| 本地存储 | sqflite / sqflite_common_ffi / flutter_secure_storage |
| 地图 | flutter_map / OpenStreetMap / 天地图 |
| 定位与传感器 | geolocator / permission_handler / sensors_plus |
| 图表与可视化 | fl_chart |
| 二维码 | qr_flutter / mobile_scanner |
| 解析 | xml / html / charset |

## 快速开始

### 环境要求

- Flutter SDK 3.x
- Dart SDK 3.2+
- 已启用目标平台开发环境

Linux 桌面构建通常还需要安装 GTK、WebKit、libsoup、libsecret 等系统依赖。

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run
```

常用平台示例：

```bash
flutter run -d chrome
flutter run -d linux
flutter run -d android
```

## API 配置

默认接口配置位于：

```text
lib/core/constants.dart
```

应用内也支持通过“多次点击标题进入 API 配置页”修改常用后端地址和第三方服务配置。

| 服务 | 默认用途 | 默认地址 |
| --- | --- | --- |
| MeowzExam API | 题库、练习、考试、学习记录 | `http://localhost:3001/api/` |
| beacon-api | 无线电资料、QSO、QSL、频率表、在线工具 | `http://localhost:3002/api/v1/` |
| OAuth / OpenOIDC | 登录授权与用户信息 | `https://id-api.hamcy.work` |

平台访问本机服务时请注意：

| 平台 | 本机地址 |
| --- | --- |
| Android 模拟器 | `10.0.2.2` |
| iOS 模拟器 | `localhost` |
| 桌面端 | `localhost` |
| 真机 | 电脑局域网 IP |

## 项目结构

```text
beacon-toolkit/
├── android/                  # Android 平台工程
├── ios/                      # iOS 平台工程
├── linux/                    # Linux 平台工程
├── macos/                    # macOS 平台工程
├── web/                      # Web 平台工程
├── windows/                  # Windows 平台工程
├── lib/
│   ├── core/                 # API Client、常量、平台配置
│   ├── models/               # 数据模型
│   ├── pages/                # 页面
│   │   ├── discovery/        # 发现、资讯、卫星详情
│   │   ├── developer/        # 开发者配置
│   │   ├── home/             # 首页与学习日历
│   │   ├── library/          # 题库预览
│   │   ├── practice/         # 练习、考试、收藏、历史
│   │   ├── profile/          # 我的、主题、工具设置、QRZ 配置
│   │   ├── quiz/             # 答题页
│   │   └── radio/            # 无线电工具、QSO、卫星、传播、频率表
│   ├── services/             # 网络、本地数据库、第三方 API、业务流程
│   └── widgets/              # 通用组件
├── test/                     # 测试
├── .github/workflows/        # GitHub Actions 打包发布
├── AGENTS.md                 # AI 编程助手项目约束
├── pubspec.yaml              # Flutter 依赖与版本
└── README.md
```

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `flutter pub get` | 安装依赖 |
| `dart format .` | 格式化 Dart 代码 |
| `flutter analyze` | 静态分析 |
| `flutter test` | 运行测试 |
| `flutter run` | 开发模式运行 |
| `flutter build apk --release` | 构建 Android APK |
| `flutter build appbundle --release` | 构建 Android AAB |
| `flutter build web --release` | 构建 Web |
| `flutter build linux --release` | 构建 Linux |
| `flutter build windows --release` | 构建 Windows |
| `flutter build macos --release` | 构建 macOS |
| `flutter build ios --release --no-codesign` | 构建 iOS 未签名产物 |

## 发布

仓库包含 GitHub Actions release workflow：

```text
.github/workflows/release.yml
```

默认通过 tag 触发，tag 需要匹配：

```text
v*
```

推荐发布 tag 示例：

```bash
git tag v0.0.2-alpha
git push origin v0.0.2-alpha
```

也可以在 GitHub Actions 页面手动运行 `Build and Release`，并填写 `release_tag`。

## 本地数据与隐私

- QSO 日志默认是用户私有数据。
- Access Token、Refresh Token、自定义 API 地址等敏感配置通过安全存储保存。
- 频率表、卫星数据、传播预测等支持本地缓存，但缓存不应被视为权威数据。
- 调试日志不应输出完整 token、Authorization Header 或用户批量 QSO 明细。

## 相关项目

| 项目 | 说明 |
| --- | --- |
| `../beacon-api` | Beacon 无线电工具后端、管理端和在线业务接口 |
| `../OpenOIDC` | OAuth / OIDC 登录与用户信息 |
| `MeowzExam` | 原考试训练能力来源 |

## 贡献

欢迎通过 Issue 或 Pull Request 提交问题与改进。提交前建议运行：

```bash
dart format .
flutter analyze
flutter test
```

## License

MIT License
