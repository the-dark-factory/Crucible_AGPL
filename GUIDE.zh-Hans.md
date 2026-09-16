# 快速指南 —— 构建、证明与核验 CRUCIBLE

> **翻译说明：** 这是一份简短的中文指南。完整内容见 [`README.zh-Hans.md`](README.zh-Hans.md)；
> **以英文原文 [`README.md`](README.md) 为准。**

## 你需要什么

- GNAT 与 GNATprove（AdaCore 公开提供；Alire 可一并安装）。
- 不需要任何托管服务，也不需要任何账号。整套流程都在你自己的机器上运行。

## 三条命令

```sh
# 1. 构建 AGPL 版本
CRUCIBLE_EDITION=agpl gprbuild -P crucible.gpr -p

# 2. 证明整个工程（唯一通过标准：零个未证明项）
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0

# 3. 问问这个二进制它是哪个版本（MCP，走 stdio）
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"you","version":"0"}}}' | ./bin/crucible-agpl
```

第 3 步的回复中 `serverInfo.name` 会是 `crucible-agpl`。把命令中的 `agpl` 换成 `commercial`，
你会从同一份源码得到另一个版本。

## 该看什么

- `src/*.ads` —— 各个"判官"。每一个都是：事实进，一个判定出，没有 I/O。它们的契约就是可读的规格说明。
- `LICENSE` —— AGPL-3.0，自由软件基金会的未修改文本。
- `CLA.md` 与 `cla/` —— 未经修改的 Harmony 贡献者许可协议模板。

## 需要知道的前提

- **证明说明代码符合我们写下的契约，而不是说明该契约正确。** 这条区别很重要，我们不会含糊过去。
- 各个核心都在**另一台机器上重新证明**，并在那台机器上签署收据——不是在写代码的这台机器上自我认证。
- 这些代码由 AI 系统产出，发布前经人工阅读。

## 提问或指出错误

欢迎提 issue。**如果这里有任何东西是错的，我们宁愿被告知。**
