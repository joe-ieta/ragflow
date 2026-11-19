# Agentic RAG 领域开发骨架

本目录从独立的业务接口契约开始。首个契约覆盖设备验收后付款的送审预核，由未来的领域服务生成，供工作台和 Agent 消费。

- [预核结果 JSON Schema](contracts/payment-readiness.schema.json)
- [待补签署件的合成样例](contracts/payment-readiness.example.json)

单个付款申请明细带里程碑、规则版本、求值时间、结论与逐项检查。检查的来源引用是业务系统或档案的逻辑标识，应用取得授权后方可解析到原始记录。后续以领域服务实现对象关联、权限核验和规则求值，再让 Agent 调用该服务并按结果解释。详细建模见[总体概要设计](../docs/agentic-rag/01-overview-design.md)。
