<p align="center"><img src="docs/assets/banner.png" alt="praetor — 执兵权，掌裁判" width="100%"></p>

# praetor

**Claude 当大脑，Codex 当双手。合不合并，由一个不吃人情的验收员说了算。**

*罗马执政官 praetor：兵权与裁判权集于一身——正如本插件：指挥军团出征，判决即是法律。*

一个 Claude Code 插件：让 Claude 把机械累活派给 [Codex CLI](https://github.com/openai/codex) 干——**召唤一次，之后它自主分诊、每次动手前声明一句**——派活前验收标准先冻结进 git，干完由一个独立的、没参与过的验收员判卷，FAIL 谁也推翻不了。

**为什么非要验收员？** 实测约 **1/3** 的无人值守执行结果过不了独立审查——每一份，都是你本来会直接合进去的代码。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE) [![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet)](https://claude.com/claude-code) [![validate](https://github.com/luoxianzi/praetor/actions/workflows/validate.yml/badge.svg)](https://github.com/luoxianzi/praetor/actions/workflows/validate.yml) [![English](https://img.shields.io/badge/docs-English-blue)](README.md)

[新手教程](docs/TUTORIAL.zh-CN.md) · [安装](#安装) · [快速上手](#快速上手) · [里面有什么](#里面有什么) · [实测，不吹牛](#实测不吹牛) · [跟同类工具的区别](#跟同类工具的区别) · [常见问题](#常见问题)

---

![praetor 实战回放](docs/assets/demo.gif)

*一次派活全过程的真实回放（数字全部来自下方实测表）：冻结标准 → Codex 干活 → 验收员判卷 → 超时法条开火 → FAIL 不可推翻。*

## 为什么要它

- **Claude 的额度应该花在判断上，不是搬砖上。** 批量改代码、机械写测试、大面积读代码出报告——这些活烧上下文、烧额度。派给 Codex，用它自己的进程、它自己的额度跑。
- **没有验收的委派只是许愿。** 上面那个 1/3，就是你本来会直接合进主干的代码——所以这里没有验收员点头，什么都合不进去。
- **不召唤就蛰伏，召唤了就自主。** 在你没召唤过它的对话里，praetor 一根手指都不动——Claude Code 用起来跟没装一样。说一句（"用codex"）它就上任，整场对话自己分诊、自己拆军团、每次派发前声明一句。"这个别派"钉死单个任务，"先别派活了"直接卸任，`STOP` 文件全线停火。

## 安装

```
/plugin marketplace add luoxianzi/praetor
/plugin install praetor@praetor
```

就这一步。**零配置。常驻仅 ~313 token**——在你真正派活之前，这就是它的全部开销。你机器上 `codex login` 能用，派活就能用。没有配置文件、没有向导、不需要把任何 API key 交给我们——插件只调用你本机已登录的 Codex CLI。

前置：[Claude Code](https://claude.com/claude-code) + [Codex CLI](https://github.com/openai/codex)（`npm i -g @openai/codex` 然后 `codex login`）。国内网络装 npm 包建议配镜像（如 npmmirror）；`codex login` 需要能访问 OpenAI，或直接用你已配好的中转站 config.toml。Windows：在 Git Bash 或 WSL 下可用（Claude Code 本身也走它们）。

第一次用？**[10 分钟新手教程](docs/TUTORIAL.zh-CN.md)** 带你完整走一遍真实派活——冻结的标准、判决书原文、还有一次真实失败。

以后更新：`claude plugin update praetor@praetor`——装好的插件会停在安装时的版本（这是插件机制的设计），要主动更新才能拿到修复。

## 中转站 / 自定义模型用户（先说你们最关心的）

已经在 `~/.codex/config.toml` 里把 Codex 指到中转站或别的模型（DeepSeek/GLM/Qwen…）？**开箱即用**——探测到自定义 provider 就自动尊重你的配置，不会强塞官方模型旗子。而且验收闸门不挑模型：苦力越弱只会"接管次数变多"，**绝不会坏代码悄悄混进去**。

官方推荐并实测认证的路线：**Codex `gpt-5.5` + `xhigh` 推理强度**。其他路线：支持，但不背书。

## 快速上手

在任何 git 仓库里打开 Claude Code，**任命执政官**——每个对话一次，说人话就行：

```
"今天的累活交给codex"  ·  "用codex"  ·  /praetor:delegate <任务>
```

从这一句起，它就任整场对话的指挥。真正的机械累活——16 个文件的批量改名、机械写测试、大面积读代码出报告——praetor 自己分诊、动手前声明一句：

> *这活我派给 Codex：迁移 src/ 的日期格式化——标准已冻结进 git，约 4 分钟。想拦就说一声。*

Codex 在沙盒里用它自己的额度苦干。一个全新上下文的验收员亲自重跑冻结检查、审查 diff。PASS 则 Claude 提交并附上凭据；FAIL 最多重试 2 次，然后 Claude 自己干并明说。活能拆成独立几块时，praetor 自己看出来、直接开军团并行——不用再问。**你要做的特殊动作只有那一句召唤。** 而在你没召唤过的对话里？praetor 完全蛰伏。

之后发生的事：

<p align="center"><img src="docs/assets/lifecycle.svg" alt="派活生命周期——你开口、标准冻结进git、codex执行、验收员判卷，PASS则提交、FAIL则重试直至大声接管" width="100%"></p>

*每一步的真实产物（冻结文件、判决书原文、一次真实失败）：见[新手教程](docs/TUTORIAL.zh-CN.md)。*

**三条铁律，无例外：**

1. **验收标准不进 git，不许派。**
2. **验收员不点头，不许收。FAIL 谁也推翻不了**——Claude 不行，看起来再漂亮的 diff 也不行。
3. **重试最多 2 次，然后大声接管。** 每条失败路径的终点都是"Claude 自己把活干完，并明确告诉你委派失败了"。

静默失败是这类工具的头号死因——在这里它无路可走。

## 里面有什么

**流水线**
- **dispatching-to-codex** —— 完整闭环：自动分诊 → 冻结标准 → 沙盒执行 → 判卷定案 → 提交或大声接管
- **dispatching-legion** —— 2–5 路工人并行（git 工作树隔离、可碰清单、按序合并、强制集成验收，**实测 2.84×**）
- **writing-codex-briefs** —— 自包含派工单 + 真能保护你的验收标准（红→绿检查、退出码、清单）
- **codex-judge** —— 全新上下文验收员：没看过计划、亲自跑命令、判决不可推翻

**硬保证**
- **召唤制指挥权** —— 不召唤就蛰伏；召唤后整场对话自主分诊、每次动手前必声明；"这个别派"钉死任务、"先别派活了"卸任、`STOP` 全线停火
- **标准冻结进 git** —— "怎么算干完"在 Codex 出场前就写死，且防篡改
- **大声接管** —— 不存在静默失败这条路
- **git 状态边界** —— Codex 只改文件、永不碰 git；`.git` 只读是设计
- **零配置** —— 常驻 ~313 token；中转站自动尊重；实在要调只有两个环境变量

## 军团模式（Legion Mode）—— 多路并行

执政官指挥的本就是"军团"，复数。当一个活能拆成 **2–5 个真正互不干扰、机械的块**时，praetor **自己看出拆分**、先亮出花名册（几路、各碰哪些文件、各自验收、预计提速多少），然后给每一路配一个独立 git 工作树、独立冻结标准、独立验收员，跑完按顺序合并，最后再过一道**强制集成验收**（专抓"各自都过、合起来坏"的语义冲突）。（明说 *"派几路 codex 一起干"* 当然也行。）

法条逐路照旧。零新配置：并行几路由任务拆分决定（硬上限 5，更多就分波），没有旋钮。文件范围必须严格互不相交，否则直接拒绝、改串行——**拿不准就一个一个来**。跟 [superpowers](https://github.com/obra/superpowers) 是绝配：它的 `writing-plans` 把活切成互不冲突的块，praetor 负责执行和判卷。

只有拆分是真的，提速才是真的。不是真拆分，那就不是军团——就是一次普通派活，praetor 会直说。

设计理念 + 实战战报（实测 2.84 倍提速，以及验收员亲手拦下的那次越界）：**[docs/LEGION.zh-CN.md](docs/LEGION.zh-CN.md)**。

## 实测，不吹牛

README 里的数字全部来自本地反复实测。每行一类任务：派 vs 不派的耗时、token 对比，以及验收员首判通过率（数据以英文版为准，两版同步更新）：

| 任务类型 | Claude 单干 | 派给 Codex | 结论 |
|---|---|---|---|
| 批量机械改 —— 16 个文件的 API 改名 | ~1 分钟 | ~4 分钟（Codex 2.6 分 + 验收 1.4 分）| **验收员首判 PASS**（12 步核查）——diff 一眼没看就敢合 |
| 小活 —— 一行函数 | 几秒 | 1.7 分钟，而且第一次还撞上 4 分钟超时被杀 | **小活别派。** skill 会在你浪费时间之前直说 |
| 计划外彩蛋：一次真实挂起 | — | 29 分钟零写入的挂起 → 被超时法条击杀 → 重试 2.6 分钟即成 | **大声接管，绝不静默失败**——法条真的开过火 |
| **军团（v0.2）：3 路并行实现** | 串行估算 ~6 分钟 | **实测 2 分 08 秒——提速 2.84 倍** | 3/3 首判 PASS · 零冲突合并 · **集成验收 PASS** |
| **军团陷阱局：派工单诱导工人越界** | — | 工人照办了，测试还全绿 | **验收员对"全绿"照样开铡**，点名越界文件——[完整战报](docs/LEGION.zh-CN.md) |

首批公布数据——每臂 n=1、合成样板、单机；随着重复次数积累将换成中位数。全盘托出：**4 次派活有 2 次卡死**被硬超时击杀，两次重试均成功，交付的活验收员首判全过。小样板上单干更快是事实——派活赚的是**额度转移和敢直接合并**，不是速度。

派活有固定开销（开分支+冻结+验收）。**小活派了反而慢**——skill 会直说，而不是硬派。

## 跟同类工具的区别

Claude↔Codex 桥不止我们一家，各有所长。摆事实：

| | 谁决定派活 | 谁验收结果 | 要配什么 |
|---|---|---|---|
| **praetor** | 每对话召唤一次 → 之后自主分诊、动手前必声明 | 独立验收员，FAIL 不可推翻 | 零配置（常驻 ~313 token） |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | 你，敲 /codex 命令 | 你自己读结果 | Codex CLI 登录 |
| [skill-codex](https://github.com/skills-directory/skill-codex) | Claude，skill 触发就派 | 你自己读结果 | Codex CLI + 模型参数 |
| [architect-loop](https://github.com/DanMcInerney/architect-loop) | 流水线内自动 | 流水线内置闸门 | 安装器 + 编排配置 |

## 常见问题

**我的什么东西会离开我的机器？你们能看到什么？** 什么都不会到我们这。插件只调用你本机已登录的 Codex CLI——你的 key、你的中转站、你的额度，全在你手里。

**Codex 干砸了会怎样？** 对着冻结的验收标准最多重试 2 次，然后 Claude 大声接管自己干。不存在"悄悄失败装成功"这条路。

**我（或 Claude）能推翻 FAIL 吗？** 不能。这就是本产品。想要"可以商量的验收员"，请看 [docs/DESIGN.md](docs/DESIGN.md) 里我们为什么不做。

**它会不会没经我允许就派活？** 你在这个对话里没召唤过它，就绝不会——蛰伏状态下 Claude Code 用起来跟没装一样。召唤一次之后（"用codex"/"交给codex"/`/praetor:delegate`），会：它凭自己的判断派活（包括自主拆军团），**但动手前必先声明一句**。刹车常驻："这个别派"钉死本任务、"先别派活了"直接卸任、`STOP` 文件全线停火。它永远不会做的是：不吭声偷偷派、跳过验收员合并、碰 git 状态。

**中转站接的模型比较弱会怎么样？** 苦力越弱只会"接管次数变多"，**绝不会坏代码悄悄混进去**——验收闸门不挑模型。

## 我们故意不做的

没有配置文件、没有模型选择器、没有并发旋钮、没有后台守护进程、没有仪表盘。重试次数焊死在 2——这是实测出的铁律，不是偏好。这些都是刻意砍掉的；提 issue 之前请先看 [docs/DESIGN.md](docs/DESIGN.md)。🙂

## 致谢

praetor 的纪律范式——带"无例外条款"的铁律、借口对照的红旗表、"Use when…"触发式 skill 写法——师承 [obra/superpowers](https://github.com/obra/superpowers) 的手艺。学的是招式，没有复制任何代码或文本。

## 许可证

MIT
