# Breacon Toolkit - Flutter Mobile Application

一个基于 Flutter 的跨平台移动应用开发工具包，源自 MeowzExam 项目的 mobile 模块。

---

## 📱 项目简介

Breacon Toolkit 是一个功能完整的 Flutter 移动应用框架，提供了完善的架构和常用功能模块，适合快速开发各类移动应用。

### 核心特性
- **跨平台支持**：支持 iOS、Android、Web、Windows、macOS、Linux
- **清晰的架构**：采用服务层、模型层、核心工具层的分层架构
- **API 集成**：基于 Dio 的网络请求封装
- **安全存储**：使用 flutter_secure_storage 进行敏感数据存储
- **状态管理**：集成 Provider 进行状态管理

---

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### 1. 进入项目目录
```bash
cd /data/D/Project/breacon-toolkit
```

### 2. 安装依赖
```bash
flutter pub get
```

### 3. 配置
在 `lib/core/constants.dart` 中配置你的 API 地址：
- **Android 模拟器**: `http://10.0.2.2:3001/api`
- **iOS 模拟器**: `http://localhost:3001/api`
- **真机**: 使用电脑的局域网 IP (例: `http://192.168.1.x:3001/api`)

### 4. 运行应用
```bash
flutter run
```

---

## 📂 项目结构

```
breacon-toolkit/
├── lib/
│   ├── core/           # 核心工具类
│   │   ├── constants.dart    # 常量配置
│   │   └── api_client.dart   # API 客户端封装
│   ├── services/       # 业务逻辑服务层
│   │   ├── auth_service.dart       # 认证服务
│   │   └── questions_service.dart  # 业务服务示例
│   └── models/         # 数据模型层
├── android/            # Android 平台配置
├── ios/                # iOS 平台配置
├── web/                # Web 平台配置
├── windows/            # Windows 平台配置
├── macos/              # macOS 平台配置
├── linux/              # Linux 平台配置
├── test/               # 测试文件
├── pubspec.yaml        # 依赖配置
├── AGENTS.md           # AI Agent 开发指南
└── MOBILE_SETUP.md     # 详细设置说明
```

---

## 🧱 技术栈

| 模块 | 说明 |
| --- | --- |
| 框架 | Flutter 3.x |
| 语言 | Dart 3.x |
| 网络请求 | Dio |
| 安全存储 | flutter_secure_storage |
| 状态管理 | Provider |

---

## 📖 开发文档

- **MOBILE_SETUP.md** - 详细的设置和初始化说明
- **AGENTS.md** - AI Agent 集成和开发指南
- **analysis_options.yaml** - 代码分析和 lint 规则配置

---

## 🛠️ 常用命令

| 命令 | 说明 |
| --- | --- |
| `flutter pub get` | 安装依赖 |
| `flutter run` | 运行应用（开发模式） |
| `flutter build apk` | 构建 Android APK |
| `flutter build ios` | 构建 iOS 应用 |
| `flutter build web` | 构建 Web 应用 |
| `flutter test` | 运行测试 |
| `flutter analyze` | 代码静态分析 |
| `flutter clean` | 清理构建缓存 |

---

## 🔧 配置说明

### 依赖管理
主要依赖在 `pubspec.yaml` 中配置：
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  provider: ^6.1.1
```

### 包名配置
- Android: 修改 `android/app/build.gradle` 中的 `applicationId`
- iOS: 修改 `ios/Runner.xcodeproj` 中的 Bundle Identifier

---

## 📝 开发指南

### 添加新的服务
1. 在 `lib/services/` 创建新的服务文件
2. 使用 `lib/core/api_client.dart` 进行网络请求
3. 在对应的页面或组件中注入服务

### 添加新的数据模型
1. 在 `lib/models/` 创建模型文件
2. 定义 `fromJson` 和 `toJson` 方法
3. （可选）使用 `json_serializable` 自动生成序列化代码

---

## 🤝 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 📄 许可证

本项目采用 MIT License。

---

## 📮 联系方式

如有问题或建议，欢迎提交 Issue。

---

Made with ❤️ for Flutter developers
