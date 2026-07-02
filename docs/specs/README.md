# Specs

本目录用于保存 beacon-toolkit 的需求规格。较完整的功能开发先写 spec，再实现。

## 目录约定

每个需求使用独立目录：

```text
docs/specs/<feature-slug>/
  requirements.md
  design.md
  tasks.md
```

`<feature-slug>` 使用英文小写短横线命名，例如 `qso-sync`、`satellite-tracking-permissions`。

## 文档职责

- `requirements.md`：用户故事、范围边界、验收标准。
- `design.md`：架构、数据流、接口影响、UI/权限/存储影响、错误处理。
- `tasks.md`：可执行任务列表、验证方式、完成状态。

## 何时必须写 spec

- 涉及 MeowzExam、beacon-api 或 OAuth 契约。
- 涉及认证、本地存储、SQLite schema、权限、定位或平台配置。
- 涉及 QSO、频率、卫星、无线电计算等业务边界。
- 涉及多页面流程、复杂 UI 状态或跨模块状态管理。

小范围文案、样式或明显 bug 修复可以不新增 spec，但交付时要说明原因。
