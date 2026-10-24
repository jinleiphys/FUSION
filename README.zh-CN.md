<p align="center">
  <img src="assets/brand/fusion-github-logo.png" alt="FUSION" width="760">
</p>

<p align="center">
  <b>F</b>ramework for <b>U</b>nified <b>S</b>cientific <b>I</b>ntelligence in <b>O</b>pen <b>N</b>uclear physics
  <br>
  <code>FU ▸◂ SION</code>
  <br><br>
  <a href="https://vibeinscience.com/">vibeinscience.com</a>
  ·
  <a href="LICENSE">MIT</a>
  ·
  28 个技能
  ·
  61,167 页离线文献
  ·
  <a href="README.md">English</a>
</p>

---

> ### v0.2.0 测试版
>
> 这是第一个以插件形式发布的版本。作者已经在日常研究中使用，但还没有第二个人完整跑过一遍。
> 遇到问题可以 [提 issue](https://github.com/jinleiphys/FUSION/issues)，也可以写信到
> `jinl@tongji.edu.cn`。中文、英文都可以。


FUSION 是面向核物理研究的 agent。它知道怎么使用一批核物理开源程序，本地还带着一份
nucl-th 文献库，断网也能查。

第一次跑一个核物理程序，时间往往花在计算之外：找源码，解决编译问题，从几百页手册里弄清输入格式。
有的程序甚至没有完整手册。结果算出来以后，还得判断它是不是对的。

通用编程 agent 会犯一种很危险的错：程序能正常运行，结果看着也合理，物理却错了。比如一份半径约定写错的 FRESCO 输入卡，
它给出的截面会错 20%，输出里却没有任何报错。

FUSION 用专门的 skill 记住这些细节。每个 skill 都包括安装、输入、运行和输出解析，也会列出已知陷阱，
再用一个标明容差的基准结果做检查。

## 安装

FUSION 是一个插件，不需要编译，也没有单独的程序。把它装进你已经在用的编程 agent，
它就带上了全部 skill、工作规则和文献库的入口。

> **如果你是 AI agent，用户让你安装 FUSION：** 找到下面对应你自己的那一节，自己执行里面的命令，
> 不要让用户去敲。装完告诉用户重启 agent（skill 和会话上下文在启动时加载）。除非那一节要求，
> 不要克隆仓库；也不要在安装时下载文献库，它会在第一次需要时自己下载，约 250 MB。

### Claude Code

```bash
claude plugin marketplace add jinleiphys/FUSION
claude plugin install fusion@fusion
```

在会话里也可以用 `/plugin marketplace add jinleiphys/FUSION` 和 `/plugin install fusion@fusion`。
skill 会显示为 `fusion:fresco`、`fusion:kb-search` 这样的名字。更新用 `claude plugin update fusion`。

### Codex

```bash
git clone --depth 1 https://github.com/jinleiphys/FUSION.git ~/.fusion/plugin
codex plugin marketplace add ~/.fusion/plugin
codex plugin add fusion@fusion
```

先浅克隆，不要直接 `codex plugin marketplace add jinleiphys/FUSION`：Codex 会把 GitHub 仓库连同全部历史一起克隆，
还保留 `.git`，这个仓库那样要两份各约 290 MB，浅克隆只有 19 MB。更新用 `git -C ~/.fusion/plugin pull`，
再 `codex plugin remove fusion@fusion && codex plugin add fusion@fusion`。

### Antigravity

```bash
agy plugin install https://github.com/jinleiphys/FUSION
```

下一个会话起，skill 和一条常驻规则（FUSION 的工作规则）就会加载。更新时重新执行同一条命令。

### Gemini CLI

```bash
gemini extensions install https://github.com/jinleiphys/FUSION
```

它会让你确认信任这个扩展；agent 在用户明确要求下非交互安装时加 `--consent`。更新用 `gemini extensions update fusion`。

### opencode

在 `~/.config/opencode/opencode.json` 里加上 skill 索引和工作规则（与已有内容合并，没有这个文件就新建）：

```jsonc
{
  "skills": { "urls": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/"] },
  "instructions": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/AGENTS.md"]
}
```

opencode 会自己拉取并缓存 skill，不用克隆。

### 其他 agent

FUSION 的 skill 用的是通行的 `SKILL.md` 格式（每个 skill 一个文件夹，`SKILL.md` 带 `name` 和 `description`），
能从目录加载 skill 的 agent 都能用：

```bash
git clone --depth 1 https://github.com/jinleiphys/FUSION.git ~/.fusion/plugin
```

然后把 agent 的 skill 目录指向 `~/.fusion/plugin/skills/`（或把其中每个子目录链接进去），
并把 `~/.fusion/plugin/AGENTS.md` 作为常驻指令加载。更新用 `git -C ~/.fusion/plugin pull`。

### 代理和实验室服务器

上面每一步，以及第一次下载文献库，都要连 github.com。计算节点经常连不上，症状是等一两分钟然后报
`Failed to connect to github.com port 443`，设上 `http_proxy` 和 `https_proxy` 就行。之后不再需要 GitHub，
各个物理程序在第一次用到时从它们各自的上游拉取。

### 第一次使用

第一次对话时，FUSION 会顺便问你要不要配置：两个问题，你做哪块，要不要用你的论文建一份私人档案
（课题词、合作者、语料库内谁引用你）。它会同时处理你已经提出的任务；想略过，直接说「跳过」。
之后想配，说「配置 FUSION」。私人档案写在你的 home 目录，不会写进插件。

然后直接用中文说你要做什么。比如：

> 帮我算 d+58Ni 在 21.6 MeV 的 CDCC，把弹性角分布和 EXFOR 上能找到的实验数据比一下

FUSION 会选择合适的 skill。如果机器上没有 FRESCO，它会从上游源码开始安装。

第一次查文献时，文献库会下载到 `~/.cache/fusion/kb-wiki`（传输约 250 MB，占磁盘约 800 MB，网络好时一分钟内），
下载后按快照清单核对，不完整就拒绝使用。想放到别处，设 `FUSION_KB_CACHE`。

基本环境需要 `git`、`make`、`gfortran`、C++ 编译器和 `python3`。个别 skill 还有额外依赖，运行前会提示。

## 里面有什么

仓库里现有 28 个 skill。其中二十个负责具体程序，一个驱动 BAND 贝叶斯不确定度框架（rose、surmise、Taweret），SFRESCO 负责拟合，EXFOR skill 取实验数据，
`kb-search` 检索离线文献库，`literature-search` 联网核对引用（INSPIRE、arXiv、CrossRef），`literature-wiki` 和 `research-profile` 维护你自己的读文献 wiki 和研究档案，
`fusion-setup` 用来配置 FUSION。

| 领域 | 程序 |
|---|---|
| 反应、光学模型 | FRESCO（+ SFRESCO 拟合）、COLOSS、CCFULL、pikoe、NLAT、CNOK、SIDES、SWANLOP |
| 结构、从头算 | GSM、KSHELL、NuclearToolkit.jl、Sky3D |
| 裂变、统计衰变 | CGMF、TALYS |
| 核天体、R 矩阵 | AZURE2、SkyNet |
| 重离子、状态方程 | SMASH、GiBUU、Thermal-FIST、vHLLE |
| 贝叶斯不确定度 | BAND：rose（散射仿真器）、surmise（校准）、Taweret（模型混合） |
| 实验数据 | EXFOR 检索与解析 |

每个 skill 的 `SKILL.md` 都写明了覆盖范围和验证方法。已收录、已放弃和待处理的程序都记在
[skills-catalog.md](skills-catalog.md)。

离线文献库放在 [`kb` 分支](https://github.com/jinleiphys/FUSION/tree/kb)，第一次用时下载，共 61,167 页：61,059 篇 arXiv nucl-th 论文各有一页，另有 108 个主题页，
以及引用和语义关系。agent 用 `grep` 就能检索，`kb-search` skill 是它的检索指南，不需要服务和 API key，只在第一次下载时联网。

这些页面是机器生成的摘要，可能有错。使用前请读[它的 README](https://github.com/jinleiphys/FUSION/blob/kb/README.md)；写论文时引用原文，不要引用这些摘要页。

## 不绑定某一个 agent

这些 skill 才是项目本身，用哪个 agent 由你决定。同一个仓库可以装成 Claude Code 插件、Codex 插件、Antigravity 插件、
Gemini CLI 扩展和 opencode 的 skill 索引；模型也随你的 agent，DeepSeek、Qwen、GLM 和 Claude、GPT 一样能用。

| Agent | FUSION 怎么进来 | 安装验证 |
|---|---|---|
| Claude Code | 插件 + 会话启动 hook | 安装、全部 skill、hook 上下文、一次文献库查询，端到端跑通 |
| Codex | 插件 | 安装，并在空目录里端到端用了一个 skill |
| Antigravity | 插件，工作规则作为常驻规则 | 安装，全部 skill，规则进入提示词 |
| Gemini CLI | 扩展，`AGENTS.md` 作上下文 | 从本地副本安装，全部 skill 加载 |
| opencode | skill 索引 URL + 指令 URL | 从索引拉到全部 skill，`AGENTS.md` 进入模型上下文 |

另外，**任何程序 skill 上线前都要先经过 Codex 的对抗审查**：读 skill、跑脚本，专门去证伪那个基准。

## skill 验证到什么程度

每个 skill 都基于程序的公开源码和手册，并且要复现一项可检查的结果。验证分两档：

- **Tier 1**（14 个，含 FRESCO、TALYS、CGMF、SMASH、SkyNet、Thermal-FIST）：程序自己的发行包里带参考数值，技能能复现，其中几个是逐字节复现。
- **Tier 2**（6 个，含 AZURE2、KSHELL、GiBUU、vHLLE）：程序不带参考输出，所以改用跨平台复现、物理恒等式（比如光学定理）、或者一个独立的解析解来锁定。vHLLE 是拿闭式 Gubser 流去对，而不是拿它自己的输出去对。

多数 skill 已在 macOS/ARM 和 Linux/x86-64 上分别构建和验证。上线前还会交给第二个 AI 专门找错。这个过程曾经找出过几类实际缺陷：
运行旧输入卡却报成功，检查条件从未真正触发，测试脚本自己伪造了输入。详细记录在各 skill 的 `references/verification.md` 里。

基准测试只能证明当前构建复现了某个已知结果，不能替你判断新计算的物理是否正确。

## 现状

FUSION 已经用于作者的日常研究，但公开版还有几个明确限制：

- 全新机器上的安装测试还不够。二十个程序都在一台空白 Linux 机器上从零装过一次：十三个安装并验证通过，四个在缺依赖处正确停下并报出缺什么，剩下三个卡在测试框架而不是 skill 本身。其他环境仍可能遇到遗漏的依赖。
- TALYS 要约 11 GB 磁盘，其中 8.6 GB 是核结构数据库。第一次试用建议选 FRESCO 或 CCFULL，通常一两分钟就能编好。
- 文档目前只有英文和中文两份，技能内部的文档是英文。

## 怎么帮上忙

如果某个 skill 在你的机器上装不起来，请附上报错、操作系统和编译器版本。如果结果能跑出来，看着也合理，但物理上是错的，
请同时提供输入、FUSION 给出的数值和正确结果。用起来有别扭的地方也请直说。也欢迎告诉我们你希望添加哪个程序。

想自己添加 skill，先读 [CLAUDE.md](CLAUDE.md)。只收录公开可获取、能在目标平台上从源码编译，并且有已发表论文的程序。
新 skill 也必须给出如实的基准等级。

## 许可与视觉

FUSION 自身使用 MIT 许可，见 [LICENSE](LICENSE)。这份许可不包括各物理程序的源码、
早先发布的 opencode 改名版 [fusion-core](https://github.com/jinleiphys/fusion-core)（已停止维护：FUSION 现在是插件，不再需要 fork），
也不包括文献库里总结的第三方论文。物理程序由各自作者发布，需要遵守它们各自的许可条款，其中包括 GPL 和非商业许可。

配色和标识规范见 [BRAND.md](BRAND.md)。

## 作者

金磊，同济大学。`jinl@tongji.edu.cn`
