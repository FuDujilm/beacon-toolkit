# QSO Logbook Architecture Tasks

## Implementation

- [ ] 新增日志架构 spec 文档，明确日志本、台站资料、QSO、外部状态查询与上传边界。
- [ ] 盘点现有 `QsoLog`、`RadioLogPage`、`QsoManagementService`、`LocalDatabaseService` 的职责，并整理迁移目标。
- [ ] 明确主页面 tab 与工具页独立日志管理入口的分工，避免完整日志功能继续堆在主导航。
- [ ] 设计 SQLite 新结构与迁移方案，包括默认日志本兼容旧数据。
- [ ] 设计台站资料模型与页面入口。
- [ ] 设计 ADIF 导入导出服务接口、重复判定规则和错误摘要结构。
- [ ] 设计快速录入解析服务接口、歧义处理和失败明细结构。
- [ ] 设计外部状态查询页面、凭据存储边界和状态回写策略。
- [ ] 设计证书与私钥安全边界，明确哪些平台允许本地签名、哪些平台仅支持查询与导入导出。
- [ ] 设计后续上传编排层，但将平台相关实现拆分为后续任务。
- [ ] 确认是否需要新增 `beacon-api` 辅助接口；若需要，单独补接口 spec，不在本次直接变更契约。

## First Phase Delivery

- [ ] 在工具页新增日志管理入口。
- [ ] 将主 tab 的日志能力收敛为最近预览 + 快速写入 + 快速录入入口。
- [ ] 新增日志本模型、SQLite 表与默认日志本迁移。
- [ ] 新增台站资料模型、SQLite 表与默认台站逻辑。
- [ ] 为 `qso_logs` 增加 `logbook_id`、`station_profile_id` 等关联字段。
- [ ] 新增完整日志管理页。
- [ ] 新增日志本详情页。
- [ ] 新增台站资料页。
- [ ] 新增 ADIF 导入预览与导出能力。
- [ ] 新增 LoTW 凭据页和查询页基础骨架。
- [ ] 增加对应单元测试、页面测试和迁移测试。

## Verification

- [ ] Review `docs/specs/qso-logbook-architecture/requirements.md`
- [ ] Review `docs/specs/qso-logbook-architecture/design.md`
- [ ] Review `docs/specs/qso-logbook-architecture/tasks.md`

## Notes

- 第一阶段优先完成信息架构、数据模型和导入导出边界，不强行同时落地所有外部服务能力。
- 若后续引入证书、签名或平台安全能力，需要补充独立 spec，明确 Android、iOS、桌面和 Web 的能力差异。
