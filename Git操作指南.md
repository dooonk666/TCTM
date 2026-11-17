# TCTM Git 操作指南（Windows / PowerShell）

仓库：<https://github.com/dooonk666/TCTM>

本机工作目录：`E:\k7_clean`

独立 Git 安装位置：`E:\software\git`

官方完整安装包下载不稳定时，本机使用从 Codex 随附发行文件复制出的独立命令行 Git（含凭据管理器），按本指南在 PowerShell 操作，不包含完整 Git Bash 桌面安装体验。日后可从文末官方链接安装完整版。

## 1. 改了代码，怎么提交和上传？

在项目文件夹空白处右键打开终端，或打开 PowerShell，按顺序运行：

```powershell
cd E:\k7_clean
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "修复 DTTL 复位逻辑并更新仿真"
git push
```

把提交说明换成你这次真正做的修改。`git diff` 查看已跟踪文件的修改，新文件用编辑器检查；`git diff --cached` 查看本次将要提交的内容。确认没有大文件、密钥和临时产物后再提交。

- **保存文件**：代码保存到电脑硬盘。
- **git add**：把当前修改放进暂存区，准备本次提交。
- **git commit**：在本地保存一个有说明、能回溯的版本，此时尚未上传。
- **git push**：把已经提交的版本上传到 GitHub。

想只提交指定文件，可以把 `git add .` 换成：

```powershell
git add rtl/rx/dttl/DTTL_PD.v sim/tb_DTTL_PD_Saturation.v
```

暂存以后又修改了文件，需要再次 `git add`，新的修改才会进入这次提交。没有要提交的修改时，`git commit` 提示工作区干净是正常的。

## 2. 每次开始工作前同步

```powershell
cd E:\k7_clean
git status
git pull --ff-only
```

建议在工作区干净时拉取。若本地有未完成修改，可先提交，或暂存起来：

```powershell
git stash push -u -m "临时保存未完成修改"
git pull --ff-only
git stash pop
```

`stash pop` 若提示冲突，需要人工合并。`--ff-only` 若提示分支已经分叉，先检查 `git log --oneline --graph --all -15`，不要直接强制上传。

## 3. 哪些文件上传？

| 路径 | 用途 |
| --- | --- |
| `rtl/` | 板级顶层、接口、捕获、跟踪、DTTL 等 RTL 源码 |
| `sim/` | 测试平台及仿真说明 |
| `ip/**/*.xci`、`ip/**/*.xcix` | 27 个 Vivado IP 配置；其中 `vio_1` 是二进制 Core Container |
| `constraints/` | 引脚、时钟及时序约束 |
| `data/` | ROM / FIR 系数及 AD9361 初始化数据，不能漏传 |
| `scripts/`、`open_vivado.bat` | 工程重建、综合、仿真和启动脚本 |
| `matlab/` | DTTL 参考算法、绘图源码及对照说明；运行日志不上传 |
| 根目录说明与 Git 配置 | README、使用说明、本指南、`.gitignore`、`.gitattributes` |

`build/`、`temp/`、`reports/`、`MathWorks/`、波形、综合实现输出、日志以及 IP 自动生成 HDL 不上传；本地仍保留。工具可从配置重新生成 IP 产物。已有说明里提到的迁移报告、历史日志仅存在原电脑上，不随 Git 克隆。

新增普通 RTL、仿真文件会被 `git add .` 收录；新增 RTL/IP 后还需要同步维护 `scripts/files.tcl`，保证重建时能找到它们。`ip/` 当前只允许配置文件进入 Git；如果以后使用自定义 IP，还需要把其 HDL、`component.xml`、Tcl 等真实源文件加入规则，不能只传一个 XCI。

## 4. 换一台电脑如何下载和打开？

安装 Git 和 Vivado 2020.2，然后在尚不存在的目标文件夹执行克隆：

```powershell
cd E:\
git clone https://github.com/dooonk666/TCTM.git TCTM
cd E:\TCTM
.\scripts\run_batch.bat create_project
.\open_vivado.bat
```

新电脑若 Vivado 安装路径不同，先修改 `open_vivado.bat`、`scripts/run_batch.bat` 中的路径；独立仿真可用 `-VivadoBin` 指定 Vivado 的 `bin` 目录。

`build/k7_clean.xpr` 由脚本创建，不提交。已有本地工程直接打开，别反复运行 `create_project`。需要重建时先关闭 Vivado，再把现有 `build` 改名备份，保留空位置供脚本创建。

```powershell
# 已创建工程后，检查并综合（耗时较长）
.\scripts\run_batch.bat check_project

# 准备 DTTL 独立仿真使用的除法器功能网表
.\scripts\run_batch.bat prepare_dttl_sim

# DTTL 默认测试组
.\scripts\run_dttl_supervisor_sim.ps1

# 单独运行长流场景
.\scripts\run_dttl_supervisor_sim.ps1 -Tests tb_DTTL_MixedStream
```

测试范围和判据见 `sim/README_DTTL_HalfCycle.md`、`sim/README_DTTL_MixedStream.md`。若 PowerShell 阻止执行脚本，可在确认源码可信后在当前终端运行 `Set-ExecutionPolicy -Scope Process Bypass`，仅对当前终端生效。

## 5. 首次配置（当前仓库由整理工作初始化）

安装后重开终端，用 `git --version` 检查。如果仍找不到命令，可在当前 PowerShell 会话执行：

```powershell
$env:Path = "E:\software\git\cmd;" + $env:Path
git --version
```

提交姓名和邮箱只配置当前仓库，不影响其他项目：

```powershell
cd E:\k7_clean
git config user.name "lmy"
git config user.email "doooonk666@gmail.com"
git config --get user.name
git config --get user.email
git remote -v
```

邮箱会出现在公开提交记录中。日后要改成 GitHub 隐私邮箱，可在 GitHub Settings → Emails 中复制自己的 noreply 地址，再执行 `git config user.email "复制的地址"`，它只影响之后的新提交。

仅在**全新的、尚未初始化的目录**首次建仓时使用以下命令；已经整理过的本目录不需要重复执行：

```powershell
git init -b main
git remote add origin https://github.com/dooonk666/TCTM.git
git config user.name "lmy"
git config user.email "doooonk666@gmail.com"
git add .
git diff --cached --stat
git commit -m "整理 TCTM RTL、仿真和 IP 源文件"
git push -u origin main
```

第一次成功设置上游后，后续只需 `git push`。首次 HTTPS 上传通常会打开 Git Credential Manager 登录界面，使用有本仓库写权限的 GitHub 账号登录；不要在命令或文档里写密码或 Token。

## 6. 常用查询和处理

```powershell
git status                       # 当前修改 / 暂存 / 分支状态
git diff                         # 尚未暂存的修改
git diff --cached                # 已暂存、即将提交的修改
git log --oneline -10            # 最近 10 次本地提交
git log --oneline origin/main..HEAD  # 相对于上次 fetch/push 尚未上传的提交
git restore --staged rtl/rx/dttl/DTTL_PD.v  # 取消暂存，保留文件修改（首次提交之后）
git check-ignore -v build/k7_clean.xpr     # 查看某个文件为何被忽略
```

- `not a git repository`：先 `cd E:\k7_clean`，确认在仓库里。
- `Author identity unknown`：按第 5 节配置姓名和邮箱。
- `Everything up-to-date`，网页却没变化：检查是否只保存文件而没有 `git add` 和 `git commit`；`git push` 只上传提交。
- 上传提示 `403` 或权限不足：确认登录的是有 `dooonk666/TCTM` 写权限的账号。Windows 凭据管理器中若缓存了错误 GitHub 账号，可移除对应 GitHub 凭据后重新登录。
- `rejected / fetch first`：远端有新提交。先 `git fetch origin` 并查看历史；对已提交、未上传的本地修改可运行 `git rebase origin/main`，逐个处理冲突、`git add <冲突文件>`、`git rebase --continue`，完成后 `git push`。不确定时用 `git rebase --abort` 回到 rebase 前。
- 新文件没出现在 `git status`：用 `git check-ignore -v 文件路径` 检查规则，不要直接 `git add -f .` 把所有缓存强行加入。

普通提交不用 `--force`；不要运行会清空未提交文件的 `git clean -fdx`。先看 `git status` 再操作，能避免大部分误操作。

安装来源：[Git 官方 Windows 下载页](https://git-scm.com/install/windows)。
