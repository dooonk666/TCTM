# DTTL 与解帧器连续码流联合测试

仿真顶层：`tb_DTTL_TelecommandStream`，文件 `sim/tb_DTTL_TelecommandStream.v`。
只新增 TB、发送数据和辅助脚本；本次没有修改设计 RTL，也没有启动仿真。

路径是实际 `DTTL_Top + DTTL_Supervisor -> telecommand_deframer`。
这里单独测试 DTTL 与解帧，不包含 PLL、DDLL、射频或扩频解扩；没有实例化整套 `TMTC_Track_Top`。
连接与接收顶层一致：`symbol_out` 为 Entire 积分，`symbol_out_valid` 为合格有效信号，解帧器也响应 DTTL 局部复位。
未把发送参考比特或提前组好的字节送给解帧器，未改写 DTTL 内部状态。

## 先运行快速档

TB 顶部默认 `parameter FULL_COVERAGE = 0;`。两档均为一条连续流，中途不暂停、不按帧复位，也不等解帧完成才发下一帧。

| 档位 | 帧覆盖 | 发送位数 | 仿真时间约值（100 MHz TB 时钟） |
| --- | --- | ---: | ---: |
| `FULL_COVERAGE=0` | OC1、OC42、软件 5A（32 字节） | 4,168 | 16 ms |
| `FULL_COVERAGE=1` | OC1～42、软件 5A/69/96/A5/C9 全部 5 种 | 48,616 | 187 ms |

这里的毫秒是仿真时间，不是电脑耗时。真实 Divider Generator + BRAM 功能模型的运行时间可能明显更长；全量档约为快速档的 11.7 倍符号数。先用快速档观察波形，确认后把 TB 参数改为 1 再运行全量。

快速档的发送顺序为：

```text
1024 位 0101 启动空闲
→ 48×55 引导 + EB90 B42E 39 + OC1 重复码（9 字节）+ 帧尾
→ 128 位 0101 空闲
→ 48×55 引导 + EB90 B42E 39 + OC42 重复码（9 字节）+ 帧尾
→ 1024 位 0101 空闲
→ 48×55 引导 + EB90 B42E 5A + 32 字节软件数据 + 帧尾
→ 128 位 0101 排空空闲
```

| 快速档区间 | 起始比特（含） | 结束比特（不含） |
| --- | ---: | ---: |
| 启动空闲 | 0 | 1024 |
| OC1 引导及完整帧 | 1024 | 1584 |
| 空闲 | 1584 | 1712 |
| OC42 引导及完整帧 | 1712 | 2272 |
| 长空闲 | 2272 | 3296 |
| 软件 5A 引导及完整帧 | 3296 | 4040 |
| 排空空闲 | 4040 | 4168 |

快速档的 `frame_id` 为本次发送顺序 1、2、3；实际 OC 序号看 `tx_oc_no/rx_oc_no`，分别为 1、42、0。`*_expected.csv` 的 `source_frame_id` 保留原 CSV 行号。

全量档每帧前同样包含 48 字节引导，一般帧间空闲 16 字节；OC14、OC28、OC42、软件69之后各插入 256 字节（2048 位）长空闲。
软件载荷沿用原 CSV 的帧层测试数据，并非完整应用层软件指令语义、CRC或扰码验证。

## 在现有 Vivado 工程中使用

在 Vivado Tcl Console 输入：

```tcl
source E:/k7_clean/scripts/prepare_dttl_telecommand_sim.tcl
```

它只刷新发送文件、加入仿真源、准备 `div_gen_0` 和 `dttl_delay_bram` 的仿真模型并设置仿真 top，不启动仿真、不切换综合 top。
如果自己手动加 TB，也只把 `tb_DTTL_TelecommandStream` 设置为 Simulation Top，并确保两个 IP 的仿真文件已经生成。
默认数据目录为 TB 中的 `E:/k7_clean/sim/data`。

打开 Run Behavioral Simulation，在开始运行之前输入：

```tcl
restart
source E:/k7_clean/scripts/dttl_telecommand_fields.tcl
run all
```

`restart` 回到仿真起点，避免 Vivado 自动运行的默认时间段没有记录到新波形配置中。
也可以先 `run 7 ms`，观察第一个完整 OC 帧，再继续。脚本只记录显示所需信号，避免把整个发送数组都记录进波形文件。
若已有其他工程级仿真 generic 覆盖参数，以 Vivado 设置中的实际参数为准。

## 波形如何看

| 信号 | 含义 |
| --- | --- |
| `tx_byte`、`tx_bit`、`tx_bit_index` | 当前真正送入 NRZ 采样源的十六进制字节、比特、高位先发的位置 |
| `tx_frame_id`、`tx_case_name`、`tx_oc_no` | 当前工作期序号、用例名和 OC 序号；空闲时 frame_id 为 0 |
| `tx_field_name`、`tx_field_byte_index` | ASCII 显示当前是 GUIDE、SYNC_EB90、ADDRESS、FORMAT、PAYLOAD、TAIL 或 IDLE，以及字段内字节位置 |
| `tx_recent_bytes` | 已实际发完的最近 16 字节，右侧为最新字节，可连续跟踪 55、EB90、帧内容 |
| `tx_workperiod_hex` | 当前工作期预先载入的完整引导及帧，按发送顺序显示；空闲时为 0 |
| `tx_frame_hex` | 当前待发帧，从 EB90 到帧尾；预期内容，并非接收结果 |
| `entire_accum`、`middle_accum` | 积分器内部正在累加的值 |
| `entire_out`、`middle_out`、`symbol_out` | 结束一个符号后保持的积分结果；entire_out 与 symbol_out 是同一结果 |
| `symbol_out_valid`、`symbol_bit` | 真实 DTTL 输出有效信号和符号位判决 |
| `decision_valid`、`reference_bit`、`decoded_bit` | 与接收消费时刻对齐的发送参考和判决；只在 decision_valid 时比较 |
| `decision_checked`、`decision_error`、`decision_phase_bad` | 是否在捕获后检查区、判决错误、相位偏差超过 0.05T |
| `restart`、`dttl_rst`、`phase_distance` | supervisor 重启及定时误差；恢复过程发生在启动区 |
| `rx_sync_found`、`rx_sync_word` | 解帧器真正找到的同步头脉冲及保存值，不是常量 EB90 |
| `rx_byte_valid`、`rx_byte`、`rx_state` | 解帧器真正接受的地址/方式字/数据/帧尾字节及状态 |
| `frame_valid`、`rx_frame_id`、`rx_frame_match` | 完整帧输出、本次接收序号、与发送帧逐字段逐字节比较结果 |
| `saved_*`、`saved_frame_hex` | 最近完整解出一帧的实际字段及帧字节，便于暂停查看 |
| `direct_command_hex`、`oc_code_first`、`oc_code_repeat`、`rx_oc_no` | 实际直接指令的 72 位码、两个 36 位副本、反查得到的 OC 序号 |

积分信号需要 Signed Decimal（波形脚本已设为 `dec`），不要用八进制或无符号数解释负数。
`saved_payload` 仍是第一个字节放低 8 位；`saved_frame_hex` 和 `direct_command_hex` 已按传输顺序排列。
未使用的显示填充位清零；有效载荷中的 X 不会被掩盖。

引导和空闲都采用 `55`，在物理比特流中不可区分。TX 字段标记来自发送清单，接收侧 `preamble_valid` 只说明观察到了 384 位连续交替数据，不能据此证明工作期边界。
闲置段与引导相接时，接收端允许在空闲段中就产生交替序列检测脉冲，不要求脉冲恰好落在 GUIDE 末尾。

## 数据文件与检查

源仍为 `sim/data/telecommand_tx_frames.csv` 和 `telecommand_oc_codes.csv`。
可运行 `scripts/create_dttl_telecommand_stream.ps1` 同时刷新两档。

`sim/data/dttl_telecommand[_quick]_sections.csv` 按连续发送顺序列出所有字段、空闲段、起始比特、长度和完整十六进制内容。
`*_expected.csv` 是发送帧的比较依据，`*.mem` 与 `*_cases.txt` 是 TB 输入。

仿真工作目录会写出：

- `dttl_tc_tx_bytes.csv`、`dttl_tc_tx_bits.csv`：实际走完发送路径的字节及逐位序列，包含全部引导与空闲。
- `dttl_tc_rx_symbols.csv`：DTTL 实际积分、参考比特、判决、相位误差。
- `dttl_tc_rx_bytes.csv`：解帧器实际找到的同步头和接受的帧字节。
- `dttl_tc_rx_commands.csv`：实际解出的帧字段、完整载荷、直接指令及完整帧十六进制内容。
- `dttl_tc_events.csv`：字段切换、重启、交替序列检测、同步头、解帧错误。
- `dttl_tc_summary.csv`：总统计。

验收包含：帧数及顺序正确，地址/方式字/长度/全部有效载荷/同步头/帧尾一致，实际 OC 反查正确，无解帧错误；启动 1024 位之后无判决错误、漏符号、重复符号、超过 0.05T 的相位误差或再次重启。
启动初始 TX 相位为 0x80000000，RX 正常复位相位为 0x00000001；不强制 supervisor 必须重启一次，因为 PD 自身也可能先恢复。
检查失败会先保留整条码流及比较结果，最后 `$fatal`，避免第一处错误就截断观察。
只有实际运行全部通过，控制台才输出 `DTTL_TELECOMMAND_STREAM_TEST_PASS`。
本次发送文件转换检查、Vivado xvlog 语法编译和快速档 xelab 静态展开已通过；没有启动 xsim 运行，尚无动态通过结果。
