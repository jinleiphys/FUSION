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
  23 个技能
  ·
  61,167 页离线文献
  ·
  <a href="README.md">English</a>
</p>

---

> ### 这是测试版,公开测试中
>
> v0.1.0 是第一个公开构建。它能用,作者每天在用,但**没有第二个人用过**。
> 在你手上坏掉的地方,正是我们要的东西。
>
> **大概率会遇到的三件事**
>
> - **macOS 第一次运行会被拦。** 二进制没签名,执行
>   `xattr -d com.apple.quarantine fusion` 就能开。
> - **别一上来就试 TALYS**,它要下约 11 GB。先试 FRESCO 或 CCFULL,一两分钟就编好。
> - **冷启动装机是测得最少的部分。** 二十个程序里只有 FRESCO 真正从空缓存装过。
>   某个程序在你机器上编不出来,是你能提供的最有价值的反馈。
>
> **最想收到什么,按价值排序**
>
> 1. **看起来对、其实错的结果。** 这个项目存在的理由就是:通用 agent 会写出一份
>    半径约定错了的 FRESCO 输入卡,跑得通,截面错 20%,没有提示。如果 FUSION 也干了
>    这种事,请把输入卡、算出的数、以及正确的数发给我们。这是我们最怕的失败,
>    也是用户最不会主动报的一种。
> 2. **装不上的程序**,附上报错、你的系统和编译器版本。
> 3. **任何让你觉得傻的地方。** 首次配置流程里那些别扭的设计,全是一个人真的去用、
>    然后直说"这太傻了"找出来的。这个办法有效。
> 4. **你希望哪个程序有技能。**
>
> [提 issue](https://github.com/jinleiphys/FUSION/issues),或写信到
> `jinl@tongji.edu.cn`。中文英文都行。


一个已经会用核物理开源程序的 agent，而且把 nucl-th 的文献库随身带着，离线可查。

第一次跑一个核物理程序，大部分时间花的不是物理。是找源码、让它在你的机器上编译过去、学一份三百页手册里的输入格式，或者干脆没有手册；等算出来了，你还不知道这个数对不对。

通用的编程 agent 在这件事上会以一种很危险的方式失败。你让它写一份 FRESCO 输入卡，它给你一份看起来没问题的文件，半径约定是错的。卡片跑得通。截面错了 20%。没有任何提示。

FUSION 给每个程序配一个专家技能。每个技能教 agent 怎么从这个程序自己的上游装它、怎么正确写输入、怎么跑、怎么解析输出、它有哪些坑，以及怎么拿一个有明确容差的基准去核对结果。

## 快速开始

```bash
# 1. 把 FUSION 下载到本地
git clone https://github.com/jinleiphys/FUSION.git && cd FUSION

# 2. 下载 fusion 命令行程序，就下到这个目录里
#    这条是 Apple 芯片 Mac；Intel Mac 换 darwin-x64，Linux 换 linux-x64
curl -fsSL https://github.com/jinleiphys/FUSION/releases/latest/download/fusion-darwin-arm64.tar.gz | tar -xz
xattr -d com.apple.quarantine fusion          # 只有 macOS 需要这一行

# 3. 打开
./fusion
```

就这些。`./fusion` 在这个目录里运行，23 个技能和整个文献库都会自动就位，**不需要写任何配置文件**。

**你说第一句话时**它会问要不要帮你配置：模型、你的研究方向、配色，以及用你自己的论文建一个私人档案（你的课题词、合作者、语料库里谁引用了你）。问题跟着你的第一条消息出现，不是在启动画面上，而且不会挡着你问的事，它会一边问一边把活干了。配置过一次以后就不再问。想直接干活，说「跳过」。

想在任何目录都能直接敲 `fusion`，把它移到 PATH 上：

```bash
mkdir -p ~/.local/bin && mv fusion ~/.local/bin/

# 如果之后提示 command not found，说明 ~/.local/bin 不在你的 PATH 里。
# macOS 默认不会把它加进去：
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```

macOS 和 Linux、x64 和 arm64 的构建都在 [releases 页](https://github.com/jinleiphys/FUSION/releases)。这些二进制没有做签名和公证，所以 macOS 第一次运行会拦，需要上面那行清掉隔离标记。如果你不愿意跑未签名的程序，`fusion` 本质上是换了品牌的 [opencode](https://github.com/anomalyco/opencode)，这里的一切在原版 opencode 下同样能用。

然后用中文提要求就行：

> 帮我算 d+58Ni 在 21.6 MeV 的 CDCC，把弹性角分布和 EXFOR 上能找到的实验数据比一下

剩下的它自己处理，包括在你机器上没有 FRESCO 时从源码把它编出来。

**克隆下来大约 229 MB**，绝大部分是文献库。只想要技能、不想要文献库的话，可以不克隆，直接让 agent 从索引拉取：

```jsonc
// ~/.config/opencode/opencode.json
{ "skills": { "urls": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/"] } }
```

这条路验证过：一台没有克隆仓库的干净机器，23 个技能全部拉取并缓存成功。

环境要求：`git`、`make`、`gfortran`、一个 C++ 编译器、`python3`。个别技能还需要别的依赖，它会在动手之前告诉你。

## 里面有什么

**23 个技能。** 二十个驱动某个具体程序，一个是拟合前端，一个取实验数据，一个负责配置 FUSION 自己。

| 领域 | 程序 |
|---|---|
| 反应、光学模型 | FRESCO（+ SFRESCO 拟合）、COLOSS、CCFULL、pikoe、NLAT、CNOK、SIDES、SWANLOP |
| 结构、从头算 | GSM、KSHELL、NuclearToolkit.jl、Sky3D |
| 裂变、统计衰变 | CGMF、TALYS |
| 核天体、R 矩阵 | AZURE2、SkyNet |
| 重离子、状态方程 | SMASH、GiBUU、Thermal-FIST、vHLLE |
| 实验数据 | EXFOR 检索与解析 |

每个技能的 `SKILL.md` 会写明它覆盖什么、怎么验证的。哪些进来了、哪些被拒了、为什么：[skills-catalog.md](skills-catalog.md)。

**61,167 页文献**，离线，在 [`kb-wiki/`](kb-wiki/)：61,059 篇 arXiv nucl-th 论文各一页，108 个主题页，外加连接它们的引用层和语义关系层。agent 用普通的 grep 就能读。不需要服务、不需要 key、不需要联网。

这些页面是机器生成的摘要，**会出错**。依赖任何一页之前先读 [kb-wiki/README.md](kb-wiki/README.md)，并且永远引用论文本身，不要引用页面。

## 不绑定某一个 agent

技能就是一堆 markdown 和 shell 脚本组成的目录，而且每个技能同时带了两种入口文件，所以三个常见的 agent 都能加载。

| Agent | 入口 | 怎么装 | 验证程度 |
|---|---|---|---|
| opencode | `SKILL.md` | 不用装，在克隆目录里自动发现 | **已验证**，23 个零配置全部加载 |
| Claude Code | `SKILL.md` | `ln -s "$PWD"/skills/* ~/.claude/skills/` | **已验证**，与它已在加载的技能逐字节一致 |
| Codex | `AGENTS.md` | `ln -s "$PWD"/skills/* ~/.codex/skills/` | 仅格式，**未**端到端验证 |

Codex 的入口文件是**自动生成的指针**，不是手写的精简镜像。每个文件写明这是哪个技能、什么时候用，然后要求 Codex 用文件读取工具去读 `SKILL.md`，它必须这么做，因为 Codex 不支持 markdown 内联导入。能用，但比手写镜像弱，每个文件开头都如实标注了这一点。

## 一个技能能信到什么程度

每个技能都是从这个程序的公开源码和它自己的手册里搭出来的，然后被要求复现某个东西。证据是明说的，不是暗示的：

- **Tier 1**（14 个，含 FRESCO、TALYS、CGMF、SMASH、SkyNet、Thermal-FIST）：程序的发行包里带参考数值，技能能复现，其中几个是逐字节复现。
- **Tier 2**（6 个，含 AZURE2、KSHELL、GiBUU、vHLLE）：程序不带参考输出，所以改用跨平台复现、物理恒等式（比如光学定理）、或者一个独立的解析解来锁定。vHLLE 是拿闭式 Gubser 流去对，而不是拿它自己的输出去对。

大部分技能在**两个平台**上构建并验证过，macOS/ARM 和 Linux/x86-64；每个技能上线前都要过一遍第二个 AI 的对抗性审查。那个环节不是走过场：它抓到过跑着旧输入卡还报成功的技能、抓到过从来没被证明会触发的守卫、还抓到过一个自己伪造输入的测试。每次审查发现了什么，都写在各技能的 `references/verification.md` 里。

**基准测试证明的是「这个构建复现了一个已知结果」，不是「你这次的计算是对的」。** 物理判断仍然是你的。

## 现状

一个在作者自己日常研究里天天用的平台，提前公开，是为了知道别人真正需要什么。你可能会遇到：

- macOS 和 Linux 的二进制没有签名，第一次运行需要清掉隔离标记。Windows 没有构建。
- **冷启动安装测试不足。** 每个技能的安装路径在「机器上已经有这个程序」的情况下都能工作，但只有 FRESCO 的路径真正从一个空缓存跑过。某个地方缺依赖是很可能的。
- TALYS 要约 11 GB 磁盘，其中 8.6 GB 是核结构数据库。
- 文档目前只有英文和中文两份，技能内部的文档是英文。

## 怎么帮上忙

现在最有价值的是一个真实的 bug 报告：某个技能在你机器上装不起来，或者它给了一个**看起来合理其实是错的**结果。第二有价值的是告诉我们你希望哪个程序有技能。

想自己加一个技能，先读 [CLAUDE.md](CLAUDE.md)。一个程序要够格，必须是公开可获取的、能在目标平台上从源码编译的、并且有已发表的论文；而一个技能只有带着诚实的基准分级才能上线。

## 许可与视觉

MIT，见 [LICENSE](LICENSE)。那份文件同时写明了它**不能**覆盖的三样东西：那些物理程序本身（你是从各自作者那里拿的，遵守他们自己的条款，其中几个是 GPL，一个是非商业授权）、[fusion-core](https://github.com/jinleiphys/fusion-core) 里的 opencode fork、以及 `kb-wiki/` 里被总结的第三方论文。

基于 [opencode](https://github.com/anomalyco/opencode)（MIT）构建，所以你能连上哪个模型就用哪个：DeepSeek、Qwen、GLM 和 Claude、GPT 一样好使。与 opencode 项目没有隶属关系。

配色、标识、各处怎么用：[BRAND.md](BRAND.md)。

## 作者

金磊，同济大学。`jinl@tongji.edu.cn`
