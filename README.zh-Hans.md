# CRUCIBLE

> **翻译说明：** 本文是 [`README.md`](README.md) 的简体中文译本。**以英文原文为准**；若两者有出入，以英文为准。

一座工厂：把写下来的规格说明变成带有机器可验证证明的 Ada/SPARK，并且拒绝交付任何它无法证明的东西。

CRUCIBLE 本身就是按它建造别人的方式建造的：其中做决定的部分都是经过证明的 SPARK 包，而且每一个都是
工厂从散文生成的，不是手写的。

---

## 两道守卫

**证明。** 模型可以提议。它永远不被相信。由 `gnatprove` 决定，并且有一道门会拒绝常见的伪造手法——
`SPARK_Mode Off`、`Warnings Off`、被假定的实现体、以及什么也没说的契约。

**确定性。** 一个你无法复现的判定不算判定。检查再跑一遍要给出同样的答案，否则不算数。

---

## 这里有什么

| 路径 | 内容 |
|---|---|
| `src/` | Ada 代码。各个"判官"都是表达式函数形式的规格说明：事实进，一个判定出，没有 I/O。 |
| `src/edition-agpl/`、`src/edition-commercial/` | 版本在编译期确定——绝不是运行时开关。 |
| `crucible.gpr` | 工程文件。用 `CRUCIBLE_EDITION` 选择版本。 |
| `cla/` | 未经修改的 Harmony CLA 模板与签署名单。 |

这些判官分别裁决：受理、分解、契约生成、证明器的判定、空洞性、接缝一致性、准入、溯源、唯一接口，
以及该版本的许可。每一个都在席位之外准入：在另一台机器上重新证明，并在那台机器上签署收据。

---

## 构建

两个版本由同一份源码构建：

```sh
CRUCIBLE_EDITION=agpl       gprbuild -P crucible.gpr -p     # bin/crucible-agpl
CRUCIBLE_EDITION=commercial gprbuild -P crucible.gpr -p     # bin/crucible-commercial
```

每个可执行文件都通过 stdio 应答 MCP，并在 `initialize` 的结果中报告自己的版本，因此你随时都能确认
自己在与哪一个对话。

## 证明

```sh
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0
```

只有"零个未证明项"才算通过。不必相信我们的说法：这个证明器是 AdaCore 的，公开可得，而且它不在乎
代码是谁写的。

---

## 许可与贡献

CRUCIBLE 采用 **AGPL-3.0-or-later**（见 `LICENSE`，自由软件基金会的未修改文本）。同一份源码的商业许可
可按需获取——见 `COMMERCIAL-LICENCE.md`。本仓库中没有任何法律文本是我们自己起草的。

欢迎在 Harmony 贡献者许可协议 v1.0（许可变体、对外许可 Option Five、适用英格兰与威尔士法律）下贡献。
它是一份许可，不是转让：你保留自己的著作权，而你的贡献始终保持 AGPL。见 `CLA.md` 与 `CONTRIBUTING.md`。

---

## 诚实的现状

- **由具备自主行动能力的 AI 系统产出**，由人把守闸门，并在发布前阅读。
- AGPL 版本拒绝以其他许可发射，这是**一项许可声明，而不是一把锁**。一份源码树，双重许可；任何人都可以
  构建任一版本。这项拒绝只是告诉诚实的使用者他有权得到什么。
- 证明确立的是代码符合我们所写的契约，却无法确立该契约就是正确的那一个。凡是我们发现自己契约有问题的地方，
  我们都说了出来。
