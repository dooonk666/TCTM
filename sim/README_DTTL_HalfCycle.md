# DTTL 半周期误锁独立仿真

运行（Vivado 2020.2 XSim）：

```powershell
./scripts/run_dttl_supervisor_sim.ps1 -Tests tb_DTTL_HalfCycle
```

不指定 `-Tests` 时同时运行原有 supervisor 单元测试和 DTTL 复位链路测试。

`tb_DTTL_HalfCycle.v` 使用完整 DTTL RTL、真实 Divider Generator 功能网表和
MULT_MACRO，输入为幅度 ±500 的无噪声 NRZ 样本。MODE=3，发送端 FCW=11195744，
符号周期约 383.625 个输入样本；每个时钟提供一个有效输入样本。发送相位初值为
0x80000000，接收 NCO 按原 RTL 复位到 1，构成半周期初始偏差。

两路 DTTL 接收相同输入：loop=0 只接全局复位，loop=1 接 supervisor 的局部复位。
loop=0 的 restart_half_phase 固定为 0；loop=1 按顶层接法连接为
`local_rst && !rst && enable`。本次使用用户修改后的 RTL：局部重启加载半周期初相，
两路都屏蔽复位后的第一笔积分。不注入 Entire/Middle，不强制 NCO、PD、FCW。

两个场景分别从全局复位开始：

1. scenario=0：持续交替 `1010…`，观察 192 个监督支路输出符号。两路都从半周期附近起步，
   最后 64 个符号都要求到正确边界的距离小于 0.05T，且符号判决错误为 0。
   监督支路至多重启一次，稳定观察期间不能重启。PD 输出改为饱和限幅后，
   对照路也可能自行恢复，因此不再要求它始终误锁，也不强制监督支路必须触发重启。
2. scenario=1：16 位 LFSR PRBS，观察 512 个监督支路输出符号。检查发生过重启，
   要求只重启一次，最后 64 个符号到正确边界的距离小于 0.05T，且积分符号判决与发送符号一致。
   对照支路用于识别环路自行收敛，避免把这类恢复都归因于 supervisor。

两个场景还检查：每次局部重启占用两个时钟边沿，且两个边沿都加载 0x80000001；
每次复位只屏蔽第一笔积分。判决参考使用积分区间名义中点所在的发送符号，
同时支持收敛到边界之前和之后。日志中的 `DTTL_HALFCYCLE_TEST_PASS`
表示两个恢复场景及这些时序检查全部通过；旧版 characterization 日志保留作失败基线。

PD 数值边界测试：

```powershell
./scripts/run_dttl_supervisor_sim.ps1 -Tests tb_DTTL_PD_Saturation
```

通过真实除法器检查 26 个输出：正常值、正负边界、边界外一步、Q15 的 ±3/±4、
±2^36 宽商、零 PD 和复位后流水线清除。

输出位于 `temp/dttl_supervisor_sim/`：

可用 `-OutputDir E:/k7_clean/temp/dttl_halfphase_sim` 单独保存新方案结果，
与旧版 `temp/dttl_supervisor_sim/` 的失败基线区分。本次新方案实测使用此独立输出目录。

- `tb_DTTL_HalfCycle.log`：每 32 个符号的积分幅度和边界相位、重启次数、检查结果。
  `RESTART` 行在清窗之后采样，E/M 为 0；触发判定的完整积分幅度见该支路前一条 `WINDOW` 行。
- `halfcycle_symbols.csv`：两个场景、两路环路逐符号数据。phase_error 是发送相位减接收
  相位的无符号 32 位模差；到正确边界的距离为 `min(p,1-p)`，其中 `p=phase_error/2^32`。
  restart/reset 列在符号有效时采样，完整脉冲应查看波形或日志。
- `halfcycle.wdb` / `halfcycle.wcfg`：XSim 波形数据和显示配置。

绘图：MATLAB 中运行 `addpath('matlab'); plot_dttl_halfcycle`，输出
`reports/dttl_halfcycle.png`。自定义输出目录时可运行
`plot_dttl_halfcycle('E:/k7_clean','E:/k7_clean/temp/dttl_halfphase_sim')`。
本次环境中 MATLAB 批处理启动失败，因此未生成或验证 PNG；
实际仿真结果请查看已经生成的 CSV、日志和 XSim 波形。
仿真时钟只用于加快测试时间标尺，符号速率名称对应工程
3.069 MHz 采样率；测试不覆盖噪声、频偏、MODE1/2 和完整接收机链路。
