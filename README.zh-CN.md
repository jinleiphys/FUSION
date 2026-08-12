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
  24 个技能
  ·
  61,167 页离线文献
  ·
  <a href="README.md">English</a>
</p>

---

> ### v0.1.0 测试版
>
> 这是第一个公开版本。作者已经在日常研究中使用，但还没有第二个人完整跑过一遍。
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

## 快速开始

```bash
# 1. 下载 FUSION
git clone https://github.com/jinleiphys/FUSION.git && cd FUSION

# 2. 下载 fusion 命令行程序到当前目录
#    这里以 Apple 芯片 Mac 为例；Intel Mac 换成 darwin-x64，Linux 换成 linux-x64
curl -fsSL https://github.com/jinleiphys/FUSION/releases/latest/download/fusion-darwin-arm64.tar.gz | tar -xz
xattr -d com.apple.quarantine fusion          # 只有 macOS 需要这一行

# 3. 启动
./fusion
```

在仓库目录里运行 `./fusion`，24 个 skill 和文献库都会自动加载，不需要另写配置文件。

第一次对话时，FUSION 会顺便问你是否要配置模型、研究方向和配色，也可以用你的论文建一份私人档案，记下课题词、合作者和语料库内的引用。
它会同时处理你已经提出的任务。配置完以后不会再问；想略过，直接说「跳过」。

想在任何目录都能直接敲 `fusion`，把它移到 PATH 上：

```bash
mkdir -p ~/.local/bin && mv fusion ~/.local/bin/

# 如果之后提示 command not found，说明 ~/.local/bin 不在 PATH 里。
# macOS 默认不会把它加进去：
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```

macOS、Linux、x64 和 arm64 的构建都在 [releases 页](https://github.com/jinleiphys/FUSION/releases)。这些二进制还没有签名和公证，macOS 第一次运行时需要用上面的命令清掉隔离标记。
不想运行未签名的二进制，也可以直接用原版 [opencode](https://github.com/anomalyco/opencode) 加载这个仓库的内容。

然后直接用中文说你要做什么。比如：

> 帮我算 d+58Ni 在 21.6 MeV 的 CDCC，把弹性角分布和 EXFOR 上能找到的实验数据比一下

FUSION 会选择合适的 skill。如果机器上没有 FRESCO，它会从上游源码开始安装。

**克隆下来大约 229 MB**，绝大部分是文献库。只想要技能、不想要文献库的话，可以不克隆，直接让 agent 从索引拉取：

```jsonc
// ~/.config/opencode/opencode.json
{ "skills": { "urls": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/"] } }
```

这种安装方式已在一台没有克隆仓库的机器上测过，所有 skill 都能正常拉取和缓存。

基本环境需要 `git`、`make`、`gfortran`、C++ 编译器和 `python3`。个别 skill 还有额外依赖，运行前会提示。

## 里面有什么

仓库里现有 24 个 skill。其中二十个负责具体程序，SFRESCO 负责拟合，EXFOR skill 取实验数据，
`kb-search` 检索离线文献库，`fusion-setup` 用来配置 FUSION。

| 领域 | 程序 |
|---|---|
| 反应、光学模型 | FRESCO（+ SFRESCO 拟合）、COLOSS、CCFULL、pikoe、NLAT、CNOK、SIDES、SWANLOP |
| 结构、从头算 | GSM、KSHELL、NuclearToolkit.jl、Sky3D |
| 裂变、统计衰变 | CGMF、TALYS |
| 核天体、R 矩阵 | AZURE2、SkyNet |
| 重离子、状态方程 | SMASH、GiBUU、Thermal-FIST、vHLLE |
| 实验数据 | EXFOR 检索与解析 |

每个 skill 的 `SKILL.md` 都写明了覆盖范围和验证方法。已收录、已放弃和待处理的程序都记在
[skills-catalog.md](skills-catalog.md)。

离线文献库在 [`kb-wiki/`](kb-wiki/)，共 61,167 页：61,059 篇 arXiv nucl-th 论文各有一页，另有 108 个主题页，
以及引用和语义关系。agent 用 `grep` 就能检索，`kb-search` skill 是它的检索指南，不需要服务、API key 或网络。

这些页面是机器生成的摘要，可能有错。使用前请读 [kb-wiki/README.md](kb-wiki/README.md)；写论文时引用原文，不要引用这些摘要页。

## 可在三个 agent 中使用

skill 是由 Markdown 和 shell 脚本组成的目录。每个 skill 同时提供两种入口文件，opencode、Claude Code 和 Codex 都能加载。

| Agent | 入口 | 怎么装 | 验证程度 |
|---|---|---|---|
| opencode | `SKILL.md` | 不用装，在克隆目录里自动发现 | **已验证**，零配置全部加载 |
| Claude Code | `SKILL.md` | `ln -s "$PWD"/skills/* ~/.claude/skills/` | **已验证**，与它已在加载的技能逐字节一致 |
| Codex | `AGENTS.md` | `ln -s "$PWD"/skills/* ~/.codex/skills/` | 仅格式，**未**端到端验证 |

Codex 的入口是自动生成的指针文件。它会告诉 Codex 什么时候使用该 skill，并让 Codex 读取完整的 `SKILL.md`。
这种方式还没有端到端验证，所以每个入口文件都明确写了这一限制。

## skill 验证到什么程度

每个 skill 都基于程序的公开源码和手册，并且要复现一项可检查的结果。验证分两档：

- **Tier 1**（14 个，含 FRESCO、TALYS、CGMF、SMASH、SkyNet、Thermal-FIST）：程序自己的发行包里带参考数值，技能能复现，其中几个是逐字节复现。
- **Tier 2**（6 个，含 AZURE2、KSHELL、GiBUU、vHLLE）：程序不带参考输出，所以改用跨平台复现、物理恒等式（比如光学定理）、或者一个独立的解析解来锁定。vHLLE 是拿闭式 Gubser 流去对，而不是拿它自己的输出去对。

多数 skill 已在 macOS/ARM 和 Linux/x86-64 上分别构建和验证。上线前还会交给第二个 AI 专门找错。这个过程曾经找出过几类实际缺陷：
运行旧输入卡却报成功，检查条件从未真正触发，测试脚本自己伪造了输入。详细记录在各 skill 的 `references/verification.md` 里。

基准测试只能证明当前构建复现了某个已知结果，不能替你判断新计算的物理是否正确。

## 现状

FUSION 已经用于作者的日常研究，但公开版还有几个明确限制：

- macOS 和 Linux 的二进制没有签名，第一次运行需要清掉隔离标记。Windows 没有构建。
- 全新机器上的安装测试还不够。每个 skill 都测过已安装程序时的路径，只有 FRESCO 真正从空缓存安装过。其他程序可能遇到遗漏的依赖。
- TALYS 要约 11 GB 磁盘，其中 8.6 GB 是核结构数据库。第一次试用建议选 FRESCO 或 CCFULL，通常一两分钟就能编好。
- 文档目前只有英文和中文两份，技能内部的文档是英文。

## 怎么帮上忙

如果某个 skill 在你的机器上装不起来，请附上报错、操作系统和编译器版本。如果结果能跑出来，看着也合理，但物理上是错的，
请同时提供输入、FUSION 给出的数值和正确结果。用起来有别扭的地方也请直说。也欢迎告诉我们你希望添加哪个程序。

想自己添加 skill，先读 [CLAUDE.md](CLAUDE.md)。只收录公开可获取、能在目标平台上从源码编译，并且有已发表论文的程序。
新 skill 也必须给出如实的基准等级。

## 许可与视觉

FUSION 自身使用 MIT 许可，见 [LICENSE](LICENSE)。这份许可不包括各物理程序的源码、
[fusion-core](https://github.com/jinleiphys/fusion-core) 中的 opencode fork，也不包括 `kb-wiki/` 总结的第三方论文。物理程序由各自作者发布，
需要遵守它们各自的许可条款，其中包括 GPL 和非商业许可。

FUSION 基于 [opencode](https://github.com/anomalyco/opencode)（MIT）构建，可以连接 DeepSeek、Qwen、GLM、Claude 和 GPT 等模型。
本项目与 opencode 项目没有隶属关系。

配色和标识规范见 [BRAND.md](BRAND.md)。

## 作者

金磊，同济大学。`jinl@tongji.edu.cn`
