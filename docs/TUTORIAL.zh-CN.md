# praetor 新手教程 — 10 分钟跑通第一次派活

下面所有素材都来自 praetor 自己基准测试的**真实产物**（就是 README 数据表背后那几次运行），没有一处是摆拍。

## 0. 你需要什么

- 装好并登录 [Claude Code](https://claude.com/claude-code)
- 装好 [Codex CLI](https://github.com/openai/codex)：`npm i -g @openai/codex`，然后 `codex login`（国内网络装 npm 包建议配镜像，如 npmmirror；登录需能访问 OpenAI，或直接用你配好的中转站）
- 验证：`claude --version` 和 `codex --version` 能出版本号

就这些。praetor 本身零配置。（Windows：一切走 Git Bash 或 WSL，和 Claude Code 本身一样。）

## 1. 安装

```
/plugin marketplace add luoxianzi/praetor
/plugin install praetor@praetor
```

验证装好了：`/plugin` 里 praetor 应显示全部 skill（`dispatching-to-codex`、`dispatching-legion`、`writing-codex-briefs`，外加 `delegate` 命令）+ 1 个验收员 agent（`codex-judge`）。装完常驻仅 ~313 token，不派活就没有别的开销。

## 2. 第一次派活，全程拆解

在**一个 git 仓库里**打开 Claude Code（整个流程靠分支隔离——那是你的后悔药）。共识模型是召唤制：你在对话里召唤过一次，praetor 才上任；上任后它自主分诊、动手前声明。下面这句明示请求，同时就是那次召唤：

> **你：** 这个交给 codex —— 把 src/ 里的 `formatDate` 全部改名为 `formatISODate`，新签名不带格式参数

praetor 接下来做的每一步（配真实产物）：

**① 探测** —— codex 装了吗？登录了吗？有没有 `STOP` 急停文件？是不是中转站配置？没就绪会大声说（"跑一次 `codex login` 我就能派了"），然后 Claude 自己把活干了，绝不硬派。

**② 值不值得派** —— 派活有 2-5 分钟固定开销（开分支+冻结+判卷）。小活 Claude 会直说："*我直接干比派活快——还要派吗？*"你说了算。

**③ 冻结验收标准** —— 开一次性分支 `codex/migrate-formatdate`，并在 **Codex 出场之前**把 `.codex/ACCEPTANCE.md` 提交进 git。我们那次运行的真实文件：

```markdown
GOAL: 把 src/ 里的 formatDate 改名为 formatISODate —— 新签名
formatISODate(date) 恒返回 YYYY-MM-DD；更新 utils.js 和所有调用点。

CHECKS（全部必须通过）:
- `node test.js` 恰好打印 "OK" 且退出码 0。

CONSTRAINTS:
- 只许改 src/ 下的文件。不许动 test.js 和本文件。不许提交。
```

整套产品的核心就这一招：**"怎么算干完"在活儿存在之前就写死了**，事后谁也没法悄悄挪标准去迁就结果。

**④ Codex 干活** —— `codex exec` 在沙盒里跑（最多 `workspace-write`，永不给全权），带硬超时，推理噪音全程不进 Claude 的上下文。Codex 只能改分支上的文件，没有提交权。我们那次：16 个文件，2.6 分钟。

**⑤ 验收员判卷** —— 一个**全新的**子代理（从没看过你们的对话）只拿到三样：分支、冻结的标准、diff。它亲自重跑每条检查，并审查 diff 有没有越界改动、被削弱的测试、糊弄的桩代码。真实判决书节选：

```
✓ 验收标准未被篡改          ✓ node test.js → "OK"，退出码 0
✓ 改动全部在 src/ 内         ✓ 旧函数彻底清除
✓ 15 个调用点全部更新        ✓ 无桩代码/糊弄/TODO
VERDICT: PASS
```

**⑥ 定案** —— PASS 后由 **Claude** 提交（Codex 永远不碰提交），并用白话向你汇报、附上凭据。你只用看一页摘要，不用读 16 个 diff。

## 3. 失败的时候——这才是它可信的原因

基准测试当天的真事：一次派活跑了 **29 分钟、一个文件都没写**——真挂起。超时法条把它击杀、记下 `A-TIMEOUT-KILLED`、复位工作区、自动重试。重试 2.6 分钟干完，验收通过。

失败的阶梯，按顺序：

1. **检查不过 →** 验收员给 FAIL 附证据。Claude **推翻不了**——"diff 看着挺好"没用，永远没用。
2. **重试（最多 2 次）**——Claude 对着**同一份**冻结标准重新交代 Codex，针对判决书里的原因修。
3. **大声接管**——重试用尽（或 codex 挂了/限流）：Claude 自己把活干完，并明明白白告诉你"委派失败了，原因是 XX"。

**不存在"失败被悄悄包装成成功"的路径。这就是产品本身。**

**急停开关：** 在仓库根目录建一个名为 `STOP` 的文件，每次派活前都会先看它。

## 4. 怎么写"真能保护你"的验收标准

验收员的强度 = 你冻结的标准的强度。经验法则（`writing-codex-briefs` skill 会强制执行）：

| 弱（假安心） | 强（真保护） |
|---|---|
| "代码应该能跑" | `node test.js` 恰好打印 "OK"，退出码 0 |
| 只写"类型检查过" | 类型检查 **加** 被改区域的指名测试 |
| 不限范围 | "只许改 src/。不许动 test.js 和本文件。" |

写不出一条具体的、可执行的检查？**那这活就别派。** 这不是妥协，这是设计。

## 5. 中转站 / 自定义模型用户

已经在 `~/.codex/config.toml` 把 Codex 指到中转站？**开箱即用**——探测到自定义 provider 后，praetor 自动收起默认的 `gpt-5.5`/`xhigh` 旗子，你的配置说了算。模型弱只会"接管变多"，绝不会坏代码悄悄混进主干。

```toml
# ~/.codex/config.toml —— 标准中转站配法，praetor 无需任何额外配置
model_provider = "myrelay"
[model_providers.myrelay]
base_url = "https://your-relay.example/v1"
env_key  = "MYRELAY_API_KEY"
```

不想碰配置文件的覆盖口：`PRAETOR_MODEL` 和 `PRAETOR_EFFORT` 两个环境变量。官方实测认证路线仍是 **gpt-5.5 + xhigh**；其余"支持，不背书"。

## 6. 日常控制——说人话，不用设置

召唤上任之后，praetor 凭自己的判断派活（永远先声明）——下面这些常驻刹车就是你的方向盘：

- "**这个别派给 codex**" → 这活钉死给 Claude
- "**这个交给 codex**" → 强制派（值不值得派的提醒照说）
- "**先别派活了**" → 本会话停派
- 仓库根目录 `STOP` 文件 → 一键全停

## 7. 排障速查

| 症状 | 原因 → 解法 |
|---|---|
| "codex CLI not found" | 不在 PATH → `npm i -g @openai/codex` |
| "codex not logged in" | 登录过期 → `codex login` 一次 |
| 派活被超时击杀 | 挂起（网络/中转站抖动）→ praetor 已自动重试；反复出现就查中转站/代理 |
| 验收员 FAIL："检查跑不起来" | 环境坏了（依赖没装）——按设计就是 FAIL；装好依赖重派 |
| 中转站报 400 模型名不对 | 你的中转站映射名不同 → praetor 检测到自定义配置本就不塞模型旗子；查 config.toml 里的 `model` |
| Codex 报 `.git` 只读 | 这是设计——沙盒（和 praetor 的法条）就是不让 Codex 碰 git 状态。任务本身是 git 操作（开分支/拉取/合并）？那就别派：那是 Claude 亲手干的活。**永远不要把 `.git` 加进可写目录** |
| 小活感觉更慢 | 正常——"值不值得派"已经提醒过你；小活单干更快 |

## 8. 把你的数据交回来

README 数据表要靠社区的报告从 n=1 长成中位数：[提交一份实测报告](https://github.com/luoxianzi/praetor/issues/new?template=benchmark-report.yml)，带耗时和判决结果。**失败和成功一样受欢迎——这是本店店风。**
