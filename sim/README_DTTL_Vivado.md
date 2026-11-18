# DTTL 混合长流：Vivado 波形查看

当前先验证 DTTL；解帧模块暂不接入。数据由 TB 自动生成，不需要 CSV 或 mem 激励文件。
当前版本使用已修正为饱和限幅的 DTTL_PD，supervisor 沿用现有版本。

## 你在 Vivado 中操作

1. 将 `E:/k7_clean/sim/tb_DTTL_MixedStream.v` 添加到 Simulation Sources，
   文件类型选择 SystemVerilog，并将 `tb_DTTL_MixedStream` 设置为仿真 Top。
2. 工程中需要现有的 DTTL_Top、DTTL_NCO、DTTL_Integrator、DTTL_PD、
   DTTL_Loop_Filter、DTTL_Supervisor，以及 div_gen_0 IP。
   如需统一补引用，可在已打开工程的 Tcl Console 执行
   `source E:/k7_clean/scripts/prepare_dttl_mixed_sim.tcl`；它不启动仿真。
3. Run Behavioral Simulation。
4. 在仿真的 Tcl Console 执行：

```tcl
restart
source E:/k7_clean/scripts/dttl_mixed_stream_fields.tcl
run all
```

数据共4096个发送符号，之后额外排空4个符号周期。TB时钟为100 MHz，
完整仿真覆盖约15.73 ms。按工程8 ksym/s计算，对应约0.512秒数据。
真实除法器功能仿真可能较慢。若分段运行，可用 `run 3 ms` 等命令逐段推进。
到最后才会输出总验收结果，单次默认的1000 ns远不足以结束本测试。

## 波形信号

| 信号 | 看什么 |
| --- | --- |
| tx_symbol | 正在发送的符号序号，从0开始 |
| tx_segment | 0=随机PRBS；1～4=对应长0101段 |
| tx_bit | 实际发送的0/1，按符号周期保持 |
| data_in | 实际送进DTTL的样本，1映射+500、0映射-500 |
| symbol_out_valid | DTTL实际输出有效脉冲，匹配接收机顶层接法 |
| entire_out | Entire完整符号积分输出 |
| middle_out | Middle延迟支路积分输出 |
| symbol_out | 接收机顶层的名字，实际就是同一个entire_out |
| symbol_bit | 按symbol_out符号判决的0/1；需配合symbol_out_valid看 |
| entire_accum / middle_accum | 两路积分器内部正在累加的值，便于看积分过程 |
| decision_valid | TB已更新这一笔的对齐参考和判决值 |
| reference_bit | 与本笔积分对应的发送参考比特，只用于TB评分 |
| decoded_bit | 本笔实际判决值；由symbol_out符号取得 |
| decision_checked | 1表示处于捕获完成后的正式验收区间 |
| decision_error | 正式验收区间内的单笔比特错误脉冲 |
| decision_phase_bad | 正式验收区间内边界偏差达到0.05T的脉冲 |
| expected_index / sid | 当前判决所对应的发送符号序号与数据段编号 |
| phase_difference / distance | 模相位差与到正确边界的距离，单位为2^32/T |
| restart / local_rst / pulses | supervisor重启脉冲、局部复位及累计次数 |
| bit_errors / sequence_errors | 累计判决错误及漏/重复符号错误计数 |

比较0/1时，在 `decision_valid=1` 处看 `reference_bit` 与 `decoded_bit`。
原始tx_bit属于“正在输入”的符号，输出积分属于已经积完的符号，两者有时序差；
不能直接把同一时刻的tx_bit和decoded_bit不同判成错误。
`reference_bit`不参与DTTL运算，也不用于生成decoded_bit。

积分已使用有符号十进制显示。Entire和symbol_out是同一条积分值，不是两次处理。
进入正确锁定后的0101段时，Entire/symbol_out应大致正负交替，
Middle幅度相对小；由于383/384个采样的离散边界，Middle不必精确等于0。

## 4段0101的位置

下面时间为100 MHz TB时钟下的近似值，定位以tx_segment、tx_symbol为准：

| 段 | 发送符号区间（结束位置不包含） | 长度 | 约仿真时间 |
| --- | --- | ---: | --- |
| 1 | [671,952) | 281 | 2.572～3.650 ms |
| 2 | [1120,1533) | 413 | 4.295～5.879 ms |
| 3 | [1737,2224) | 487 | 6.662～8.530 ms |
| 4 | [2364,2643) | 279 | 9.067～10.137 ms |

前512个符号是捕获区；随后3584个符号逐个验收，不只检查最后64个。
各段之间不复位、不强制相位跳变，保持同一条连续数据流。

## 成功结束与输出

完整运行应输出 `DTTL_MIXED_STREAM_TEST_PASS`，同时检查3584个符号、
判决错误0、相位越界0、漏/重复符号0、稳定阶段重启0。
本测试固定种子还检查初始捕获重启一次、两拍复位与两次首笔积分屏蔽。
若未达到PASS，应先检查MIXED_RESULT及错误时刻，不能把仿真停止当作通过。

CSV输出在本次Vivado仿真的工作目录：mixed_stream_bits.csv、mixed_stream_symbols.csv、
mixed_stream_events.csv。波形脚本保存mixed_stream.wcfg。

这次按用户要求仅准备代码和波形脚本。已检查编译、展开和波形命令能启动；
后台长流已按要求中止，未完成本次PD修正后的4096符号运行，不宣称最新长流已通过。
此前完整长流报告属于PD饱和修复前的版本。

## 后续接解帧

独立DTTL波形确认后，联合测试应按实际输出连接：

```text
协议帧十六进制 → MSB-first比特 → NRZ样本 → DTTL
→ symbol_out_valid + symbol_bit → 位/字节对齐 → telecommand_deframer
```

reference_bit仅是评分参考，不接入解帧模块。联合测试需要处理捕获期输出及位到字节对齐，
当前TB尚未实现此联合链路。
