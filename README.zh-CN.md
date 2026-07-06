# praetor

**Claude 当大脑，Codex 当双手。合不合并，由一个不吃人情的验收员说了算。**

*罗马执政官 praetor：兵权与裁判权集于一身——正如本插件：指挥军团出征，判决即是法律。*

一个 Claude Code 插件：让 Claude 把机械累活派给 [Codex CLI](https://github.com/openai/codex) 干——**只在你开口时才派**——派活前验收标准先冻结进 git，干完由一个独立的、没参与过的验收员判卷，FAIL 谁也推翻不了。

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE) [![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet)](https://claude.com/claude-code) [![English](https://img.shields.io/badge/docs-English-blue)](README.md)

---

<!-- HERO-GIF 槽位（发布前录制）：与英文版共用同一条真实终端录屏（终端输出本来就是英文，
     不造假的本地化演示）。GIF 下方配一行中文说明即可。 -->

## 为什么要它

- **Claude 的额度应该花在判断上，不是搬砖上。** 批量改代码、机械写测试、大面积读代码出报告——这些活烧上下文、烧额度。派给 Codex，用它自己的进程、它自己的额度跑。
- **没有验收的委派只是许愿。** 实测约 **1/3** 的无人值守执行结果过不了独立审查——那正是你本来会直接合进去的坏代码。所以这里没有验收员点头，什么都合不进去。
- **你说了算。** 本插件**绝不自动派活**。Claude 最多提一句"这活挺适合 Codex，要派吗？"——你不点头，活不动。

## 安装

```
/plugin marketplace add luoxianzi/praetor
/plugin install praetor@praetor
```

就这一步。**零配置。常驻仅 ~313 token**——在你真正派活之前，这就是它的全部开销。你机器上 `codex login` 能用，派活就能用。没有配置文件、没有向导、不需要把任何 API key 交给我们——插件只调用你本机已登录的 Codex CLI。

前置：[Claude Code](https://claude.com/claude-code) + [Codex CLI](https://github.com/openai/codex)（`npm i -g @openai/codex` 然后 `codex login`）。国内网络装 npm 包建议配镜像（如 npmmirror）；`codex login` 需要能访问 OpenAI，或直接用你已配好的中转站 config.toml。

## 中转站 / 自定义模型用户（先说你们最关心的）

已经在 `~/.codex/config.toml` 里把 Codex 指到中转站或别的模型（DeepSeek/GLM/Qwen…）？**开箱即用**——探测到自定义 provider 就自动尊重你的配置，不会强塞官方模型旗子。而且验收闸门不挑模型：苦力越弱只会"接管次数变多"，**绝不会坏代码悄悄混进去**。

官方推荐并实测认证的路线：**Codex `gpt-5.5` + `xhigh` 推理强度**。其他路线：支持，但不背书。

## 怎么用

说人话就行，或者用命令：

```
"这个交给codex"  ·  "派给codex干"  ·  "send this to codex"

/praetor:delegate 把 src/ 里所有 moment 日期格式化迁移到 dayjs
```

之后发生的事（生命周期）：

```
你开口
   → 探测（codex 装没装？登没登录？有没有 STOP 急停文件？）
   → 值不值得派——直接干更快的话 Claude 会先说
   → 开一次性分支 codex/<task>（主干永不碰）
   → 验收标准冻结提交进 git（在 Codex 动手之前）
   → 自包含派工单 → codex exec（沙盒里跑）
   → 全新验收员跑冻结检查 —— PASS / FAIL，判了就是判了
   → PASS：Claude 提交并汇报 · FAIL：最多重派 2 次，然后大声接管
   → 清理 + 记一行台账
```

**三条铁律，无例外：**

1. **验收标准不进 git，不许派。**
2. **验收员不点头，不许收。FAIL 谁也推翻不了**——Claude 不行，看起来再漂亮的 diff 也不行。
3. **重试最多 2 次，然后大声接管。** 每条失败路径的终点都是"Claude 自己把活干完，并明确告诉你委派失败了"。

静默失败是这类工具的头号死因——在这里它无路可走。

## 实测，不吹牛

README 里的数字全部来自本地反复实测。每行一类任务：派 vs 不派的耗时、token 对比，以及验收员首判通过率（数据以英文版为准，两版同步更新）：

| 任务类型 | Claude 单干 | 派给 Codex | 结论 |
|---|---|---|---|
| 批量机械改 —— 16 个文件的 API 改名 | ~1 分钟 | ~4 分钟（Codex 2.6 分 + 验收 1.4 分）| **验收员首判 PASS**（12 步核查）——diff 一眼没看就敢合 |
| 小活 —— 一行函数 | 几秒 | 1.7 分钟，而且第一次还撞上 4 分钟超时被杀 | **小活别派。** skill 会在你浪费时间之前直说 |
| 计划外彩蛋：一次真实挂起 | — | 29 分钟零写入的挂起 → 被超时法条击杀 → 重试 2.6 分钟即成 | **大声接管，绝不静默失败**——法条真的开过火 |

首批公布数据——每臂 n=1、合成样板、单机；随着重复次数积累将换成中位数。全盘托出：**4 次派活有 2 次卡死**被硬超时击杀，两次重试均成功，交付的活验收员首判全过。小样板上单干更快是事实——派活赚的是**额度转移和敢直接合并**，不是速度。

派活有固定开销（开分支+冻结+验收）。**小活派了反而慢**——skill 会直说，而不是硬派。

## 跟同类工具的区别

Claude↔Codex 桥不止我们一家，各有所长。摆事实：

| | 谁决定派活 | 谁验收结果 | 要配什么 |
|---|---|---|---|
| **praetor** | 你，明说才派——绝不自动 | 独立验收员，FAIL 不可推翻 | 零配置（常驻 ~313 token） |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | 你，敲 /codex 命令 | 你自己读结果 | Codex CLI 登录 |
| [skill-codex](https://github.com/skills-directory/skill-codex) | Claude，skill 触发就派 | 你自己读结果 | Codex CLI + 模型参数 |
| [architect-loop](https://github.com/DanMcInerney/architect-loop) | 流水线内自动 | 流水线内置闸门 | 安装器 + 编排配置 |

## 常见问题

**我的什么东西会离开我的机器？你们能看到什么？** 什么都不会到我们这。插件只调用你本机已登录的 Codex CLI——你的 key、你的中转站、你的额度，全在你手里。

**Codex 干砸了会怎样？** 对着冻结的验收标准最多重试 2 次，然后 Claude 大声接管自己干。不存在"悄悄失败装成功"这条路。

**我（或 Claude）能推翻 FAIL 吗？** 不能。这就是本产品。想要"可以商量的验收员"，请看 [docs/DESIGN.md](docs/DESIGN.md) 里我们为什么不做。

**它会不会没经我允许就派活？** 绝不会。Claude 最多提一句建议，你点头活才动。

**中转站接的模型比较弱会怎么样？** 苦力越弱只会"接管次数变多"，**绝不会坏代码悄悄混进去**——验收闸门不挑模型。

## 我们故意不做的

没有配置文件、没有模型选择器、没有并发旋钮、没有后台守护进程、没有仪表盘。重试次数焊死在 2——这是实测出的铁律，不是偏好。这些都是刻意砍掉的；提 issue 之前请先看 [docs/DESIGN.md](docs/DESIGN.md)。🙂

## 许可证

MIT
