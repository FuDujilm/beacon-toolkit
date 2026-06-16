# 迁移说明 - Migration Notes

## 迁移信息

- **源项目**: MeowzExam/mobile
- **目标项目**: brecontookit (独立项目)
- **迁移日期**: 2026-06-16
- **迁移方式**: 完整复制 + 文档整理

---

## 迁移内容

### 1. 核心代码
- ✅ 完整的 Flutter 项目结构
- ✅ lib/ 目录下的所有源代码
  - core/ - 核心工具和 API 客户端
  - services/ - 业务服务层
  - models/ - 数据模型
  - pages/ - 页面组件
  - widgets/ - 可复用组件

### 2. 平台配置
- ✅ Android 配置 (android/)
- ✅ iOS 配置 (ios/)
- ✅ Web 配置 (web/)
- ✅ Windows 配置 (windows/)
- ✅ macOS 配置 (macos/)
- ✅ Linux 配置 (linux/)

### 3. 文档文件
- ✅ AGENTS.md - AI Agent 开发指南 (从父项目复制)
- ✅ MOBILE_SETUP.md - 原 mobile/README.md 的详细设置说明
- ✅ README.md - 全新编写的项目说明文档
- ✅ analysis_options.yaml - Dart 代码分析配置

### 4. 配置文件
- ✅ pubspec.yaml - Flutter 依赖配置
- ✅ .gitignore - Git 忽略规则
- ✅ .metadata - Flutter 元数据

### 5. 辅助目录
- ✅ .agents/ - Agent 配置目录
- ✅ .codex/ - Codex 配置目录
- ✅ test/ - 测试文件目录
- ✅ hook/ - 构建钩子配置

---

## 未迁移内容

以下内容属于 MeowzExam 主项目，与 mobile 项目无关，因此未迁移：

- ❌ Next.js Web 应用相关代码
- ❌ API_DOC_CN.md - API 文档（Web 后端相关）
- ❌ AI_PROVIDER_IMPLEMENTATION.md - AI 提供者实现（Web 后端相关）
- ❌ OAUTH-SETUP.md - OAuth 设置（Web 后端相关）
- ❌ PROGRESS.md - 项目进度（Web 项目相关）
- ❌ VERCEL_DEPLOYMENT.md - Vercel 部署（Web 项目相关）
- ❌ EXPLANATION_INTEGRATION.md - 解释集成（Web 项目相关）

---

## 迁移后的变更

### 新增文件
1. **README.md** - 专门为 brecontookit 编写的完整项目说明
2. **MIGRATION_NOTES.md** - 本文件，记录迁移过程

### 重命名文件
1. `mobile/README.md` → `MOBILE_SETUP.md` - 更清晰地表明是设置文档

### 保持不变
- 所有源代码保持原样
- 所有平台配置保持原样
- 依赖配置 (pubspec.yaml) 保持原样

---

## 下一步建议

### 1. 包名更新
建议将应用包名从 MeowzExam 相关改为 brecontookit 相关：

**Android**:
```gradle
// android/app/build.gradle.kts
applicationId = "com.brecontookit.app"  // 替换原有的 work.hamcy.exam
```

**iOS**:
在 Xcode 中修改 Bundle Identifier

**代码中**:
```dart
// lib/main.dart 或相关配置文件
// 搜索并替换包名引用
```

### 2. 应用名称更新
```yaml
# pubspec.yaml
name: brecontookit
description: Brecon Toolkit - Flutter Mobile Application
```

### 3. 图标和启动画面
替换以下位置的图标：
- android/app/src/main/res/mipmap-*/ic_launcher.png
- ios/Runner/Assets.xcassets/AppIcon.appiconset/
- web/icons/
- macos/Runner/Assets.xcassets/AppIcon.appiconset/

### 4. API 配置
更新 `lib/core/constants.dart` 中的 API 地址，指向你自己的后端服务

### 5. 依赖更新
```bash
flutter pub upgrade
```

### 6. 清理构建缓存
```bash
flutter clean
flutter pub get
```

---

## 技术债务

从原项目继承的技术债务：

1. **包名**: 仍然使用 `work.hamcy.exam`，需要更新
2. **API 配置**: 硬编码的 API 地址需要环境化配置
3. **测试覆盖**: test/ 目录中的测试需要补充
4. **文档**: 部分代码缺少注释

---

## Git 历史

- 初始提交: `d6f4b84` - 迁移自 MeowzExam/mobile
- 包含 191 个文件，22231 行代码

---

## 联系与支持

如有迁移相关问题，可以：
1. 查看原项目: /data/D/Project/MeowzExam/mobile
2. 参考原项目文档
3. 提交 Issue

---

**迁移完成日期**: 2026-06-16
**迁移状态**: ✅ 完成
