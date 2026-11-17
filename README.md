# K7 工程使用说明

仓库：<https://github.com/dooonk666/TCTM>。提交、上传、同步和换电脑克隆步骤见 [Git 操作指南](Git操作指南.md)。

Git 保留 `rtl/`、`sim/`、IP 配置（`.xci/.xcix`）、`constraints/`、`data/`、`scripts/`、MATLAB 参考源码和说明文件；不上传 `build/`、`temp/`、`reports/`、`MathWorks/` 及 IP 自动生成文件。本地文件仍保留。下文引用的历史迁移报告和日志不会随克隆下载，历史综合结论不代表当前版本已经重新验证。

首次克隆后先运行 `scripts/run_batch.bat create_project`，再运行 `open_vivado.bat`。DTTL 独立仿真前先运行 `scripts/run_batch.bat prepare_dttl_sim` 生成除法器网表。Vivado 安装路径不同时需调整启动脚本。

打开方式：双击根目录 open_vivado.bat，或在 Vivado 2020.2 中打开 build/k7_clean.xpr。

## 目录
- rtl/top：板级顶层。
- rtl/board：AD9361、板级接口、复位及跨时钟缓冲。
- rtl/rx/acq：捕获。
- rtl/rx/track：PLL/DDLL 跟踪。
- rtl/rx/dttl：DTTL。
- rtl/rx/rec_top.v：接收机顶层。
- constraints：约束，保持原有效版本。
- ip：27 个 IP 的配置。Vivado 生成的辅助元数据可由工具维护，不编辑生成的 HDL。vio_1 使用原生 .xcix 容器。
- data：ROM、FIR 系数和 AD9361 初始化数据。
- sim：原工程注册的测试平台。
- build：工程、IP 输出、缓存、综合和实现产物。
- scripts：相对根目录解析的创建和检查脚本。
- reports：来源映射、IP 状态和验证结果。
- temp：通过启动脚本启动时使用的 TEMP/TMP。

## 日常修改
只维护 rtl、constraints、ip、data 和 sim 中的源文件。不要再修改旧工程后期待新工程自动同步；新工程是一份独立副本。
不要把 rtl 再次复制进 build 的 imports 目录。新增文件通过 Vivado 添加现有文件，并将同一条引用同步到 scripts/files.tcl，以便重建。

## IP 配置
27 个 IP 在 Vivado 2020.2 下均为 Up-to-date，没有升级版本。ILA 的当前探针数量、宽度、VIO 默认值以及时钟和 FIFO 参数均保留；已有 ROM/FIR 系数已迁移到 data，相关路径指向新工程内部。
Vivado 会自动在 ip 目录旁维护少量元数据；主要输出由 IP_OUTPUT_DIR 指向 build/ip_generated。不要手工修改生成的 HDL。
本机 Vivado 路径写在 open_vivado.bat 和 scripts/run_batch.bat。如果另一台电脑安装位置不同，只修改这两个启动脚本。
使用 XSim 不需要旧工程的 C:/vivado_sim_lib_2020；若另用 ModelSim/Questa，需要在该机器上单独配置匹配 Vivado 2020.2 的仿真库。

## 重新创建和验证
- 已有工程直接打开，不要重复运行创建脚本。
- 需要从配置重建时，先保留现有 build，再在空的 build 下运行 scripts/run_batch.bat create_project。
- scripts/run_batch.bat check_project：重新生成 IP、检查依赖并综合。
- scripts/run_batch.bat synthesize：生成所需 IP 产物并综合。
- 综合后可在 GUI 继续 Run Implementation / Generate Bitstream。

## 验证范围和已有问题
- 迁移基线按原有效版本逐字节复制；旧工程 XPR 和迁移涉及的旧源文件哈希未变化。新副本中的后续修改单独记录在 validation_summary.json 的 concurrentChanges 字段。
- 新工程 XPR 不引用旧工程目录。原来源仅记录在 reports 的迁移清单中。
- IP 用户参数按值比较（忽略十六进制补零差异），不改变设计参数。
- 本次综合已通过；尚未进行完整实现、时序收敛验证和板上验证。
- 原有效 PLL_Loop_Filter.v 中 TEMP4 没有赋值逻辑。该问题随原代码保留，路径整理没有擅自恢复算法。即使综合通过，也不能据此认为 PLL 功能正常。请在后续功能修复中单独处理。

reports/source_mapping.csv 记录旧路径、新路径和 SHA-256；reports/validation_summary.json 记录本次验证结果。

## DTTL 独立仿真

运行 `./scripts/run_dttl_supervisor_sim.ps1`，包含监督器单元测试、真实 DTTL 复位链路测试、
半周期误锁闭环对照测试。只跑误锁场景可加 `-Tests tb_DTTL_HalfCycle`。
场景、判据和波形查看方式见 [sim/README_DTTL_HalfCycle.md](sim/README_DTTL_HalfCycle.md)。
当前测试从半周期偏差起步，要求最后 64 个符号相位误差小于 0.05T 且判决零错误。
PD 商改为饱和限幅后，交替序列的对照路也能自行恢复，不再要求对照路持续误锁；
监督路允许捕获阶段最多一次重启，稳定期不能重启。旧版 characterization 日志保留作失败基线。
PD 饱和限幅边界测试可用 `-Tests tb_DTTL_PD_Saturation` 单独运行。

长流混合数据测试：`./scripts/run_dttl_supervisor_sim.ps1 -Tests tb_DTTL_MixedStream`。
单条 4096 符号随机数据流中插入 4 段长 `0101…`，捕获后连续检查 3584 个符号。
数据组成、验收和波形说明见 [sim/README_DTTL_MixedStream.md](sim/README_DTTL_MixedStream.md)。

## 迁移期间观察到的后续修改
新副本 TMTC_Track_Top.v 已加入 DTTL_Supervisor 局部复位监督逻辑，并新增监督模块及测试平台。这些变化不属于路径迁移脚本，已保留；相关源码已注册到新工程和 scripts/files.tcl，成功综合日志中包含 DTTL_Supervisor。原工程保持原样。
