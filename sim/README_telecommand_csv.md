# 遥控解帧 CSV 对照测试

## Vivado 波形直接看帧字段

TB新增用于显示的 `sync_word`、`saved_sync`、`saved_tail`、`saved_frame_id`、
`saved_frame_valid`、`direct_command_hex`、`oc_code_first`、`oc_code_repeat`。
`sync_word`直接连接DUT实际同步搜索寄存器；`saved_sync`等saved字段只在完整帧输出后更新，
它们属于 `saved_frame_id` 指示的最近完成帧，而 `active_id` 是当前正在发送的工作期。

修改TB后先关闭旧仿真并重新 Run Behavioral Simulation，再执行：

```tcl
restart
source E:/k7_clean/scripts/telecommand_fields_wave.tcl
run 10 us
```

脚本会创建只显示关键帧字段的新波形配置。第一条直接帧完成后应显示：
saved_frame_id=1、saved_sync=EB90、saved_address=B42E、saved_format=39、saved_length=9、
direct_command_hex=7C918C75D7C918C75D、saved_tail=C5C5C5C5C5C5C579。
实时同步头大约在4.1us出现，第一帧约5.7us完成。

直接指令在原始payload总线上以第一个字节放最低8位存储，因此直接把 `[71:0]` 当大数
显示会颠倒字节顺序。`direct_command_hex`已经显式按线上字节顺序拼接；两个36位辅助信号
分别显示首份和重复码字。它们只在最近完成帧是方式字39时有效，软件帧时显示为0。

未收到帧前的TB结果快照初始化为0，用saved_frame_valid区分“还没收到”和“已有结果”。
快照只复制DUT有效长度内的数据，未使用高位显示为0；有效字节若含X仍会保留并由比较检查报错。
解帧RTL没有因这次波形显示调整而改变。

## 当前完整覆盖：42 个 OC + 5 种软件方式字

当前默认发送 CSV 已改为 47 个工作期，每行均包含真实发送的完整序列：
`48字节55引导 + EB90 + B42E + 方式字 + 数据 + C5C5C5C5C5C5C579`。
`preamble_hex`、`frame_hex` 分别显示两部分，`wire_hex` 显示完整发送内容；
`preamble_bytes=48`、`preamble_bits=384` 显式标注长度。

OC 编码依据原始《卫星星地通信协议_20260707（修改遥测帧长度）》表2，
完整码表位于 `sim/data/telecommand_oc_codes.csv`，OC1 至 OC42 每条都发送一次。
每个36位码字是9个十六进制字符，重复后是18个字符/9字节；重复边界不按字节对齐。
软件方式字按协议表3使用 5A/69/96/A5/C9，对应32/64/128/256/512字节，数据不足用AA补齐。

默认示例为软件帧的外层解帧测试数据，不表示已实现协议中的软件CRC、解扰或应用语义。
512字节数据中还插入48个连续55，验证数据内部的同样图案不会触发第二次引导识别。

建议优先查看 `telecommand_summary.csv`：47行中逐条展示预期OC、解出OC、方式字、数据长度、
引导识别标志、引导字节/比特数和总比较结果。
`telecommand_comparison.csv` 完整并排显示发送与收到的引导序列、工作期原始字节和指令数据。

RTL 新增 `preamble_valid_o`、`preamble_bytes_o` 两个输出：仅在搜索状态下，
对实际输入握手完成的连续48字节55产生一次识别脉冲，计数饱和，避免长串55反复触发。
不在负载内部识别引导。引导识别为旁路状态报告，不强制改变原有帧接收准则。
同样长的空闲55序列与引导在字节图案上无法区分；真正的工作期开启仍需上游标识。

输出 `preamble_hex` 和 `received_wire_hex` 由 DUT 实际接收字节捕获，
`preamble_detected` 来自新增的 RTL 识别输出。没有把输入引导字符串直接复制为接收结果。
`decoded_oc_no` 由 DUT 实际输出的72位数据反查码表产生，`repeat36_match` 检查两份36位码字；
它们是仿真后处理结果，当前RTL仍输出原始payload，不产生物理OC控制脉冲。

原来的21行混合案例保留为 `sim/data/telecommand_tx_frames_legacy.csv`，可指定 `-InputCsv`
重新运行。下方原21行说明保留用于这些边界案例；当前默认数据已采用上述47个完整工作期。

## 文件与运行

- 输入：`sim/data/telecommand_tx_frames.csv`。
- 解帧输出：`temp/telecommand_csv_sim/telecommand_rx_commands.csv`。
- 并排比较：`temp/telecommand_csv_sim/telecommand_comparison.csv`。

修改输入 CSV 后运行：

```powershell
./scripts/run_telecommand_csv_sim.ps1
```

可指定其它文件和输出目录：

```powershell
./scripts/run_telecommand_csv_sim.ps1 -InputCsv E:/k7_clean/sim/data/telecommand_tx_frames.csv -OutputDir E:/k7_clean/temp/telecommand_csv_sim
```

脚本只读取输入 CSV，不会重新生成或覆盖它。`create_telecommand_csv.ps1` 用于明确需要
重建示例数据时运行，运行它会覆盖对应示例 CSV。

## 输入格式

每行一个完整帧，字段：

```csv
frame_id,case_name,expected_status,frame_hex
2,direct_example,OK,EB90B42E397C918C75D7C918C75DC5C5C5C5C5C5C579
```

- frame_id：唯一非负整数，用于关联输入与输出；不发送给 DUT。
- case_name：备注；不发送给 DUT。
- expected_status：`OK`、`ERR1`（地址错）、`ERR2`（格式错）、`ERR3`（帧尾错）、
  `NO_FRAME`（不应输出帧或错误）。它是验收预期，不发送给 DUT。
- frame_hex：完整十六进制字节序列；允许大小写和空格，必须为完整字节，不带 `0x`。

支持标准 CSV 引号。输入由 PowerShell Import-Csv 读取、校验并转换为临时激励文件，
TB 再将其中的十六进制文本解析成 8 位逻辑值。行与行之间不复位 DUT，
所以若自行加入截断帧，后续行仍会接着前一行的解析状态；CSV 换行不是线上的帧间隔。

## 十六进制到二进制的转换

当前 `telecommand_deframer` 的实际接口是已经组好字节的 `rx_data_i[7:0]`，不是 1 位串行口。
为明确验证发送位序，TB 使用下面的链路：

```text
CSV ASCII十六进制 → 8位数值 → MSB-first逐位发送 → TB移位组字节 → DUT ready/valid接口
```

例如 `EB90` 发送为 `11101011 10010000`，字节和字节之间按 CSV 从左到右，
每个字节从 bit7 到 bit0，每时钟一位。组字节适配器仅在 TB 内，不修改生产 RTL。

附加捕获：

- `telecommand_tx_bits.csv`：frame_id、字节序号、bit_index、实际发送 bit。
- `telecommand_rx_bytes.csv`：DUT 真正完成输入握手的字节，包含 hex 与 8 位 binary。

脚本将这两份捕获与原始 CSV 独立逐位、逐字节核对，包括 ready/valid 实际接收情况。

## 输出与比较

`telecommand_rx_commands.csv` 每行与输入 frame_id 对应：

```text
frame_id,status,error_code,address_hex,format_hex,payload_length,command_hex,sync_inverted
```

command_hex 完全来自 DUT 的 payload_data_o，只剥除了同步头、地址、格式字节与帧尾，
按接收字节顺序输出。DUT 总线最低 8 位是第一个数据字节，因此不能直接把整个 4096 位
总线按一个十六进制大数打印，否则会反转字节顺序并包含无效高位。

对直控格式 39，command_hex 是完整 9 字节/72 位直控数据，包含重复的 36 位指令；
本模块RTL不额外做36位指令的语义解析或重复一致性判决；本轮仿真后处理已增加重复检查和OC反查。
间接遥控则输出对应长度的全部数据。

`ERROR` 行记录实际错误码，`NO_FRAME` 行表示观察期间没有输出；两者指令栏为空，
不会用输入数据或 DUT 遗留的 payload 填充。输入和输出十六进制大小写不影响比较。

`telecommand_comparison.csv` 包含 expected_command_hex 与 decoded_command_hex，
统一为大写并排展示，同时给出 expected_status、actual_status、match。
脚本逐字节验证所有正常帧的地址、格式、长度、数据及同步头反相标志。

## 2026-11-18 验证结果

示例 CSV 共 21 行：6 种格式各测试正/反同步头，另有前导码、3 类错误帧、错误同步头，
每个错误案例后紧跟正常恢复帧。大负载中嵌入同步头与帧尾字节，验证它们不会提前截断数据。

```text
TB_TELECOMMAND_DEFRAMER_PASS cases=28 frames=29 expected_errors=10
TB_TELECOMMAND_CSV_PASS rows=21 frames=16 errors=3 no_frame=2
TELECOMMAND_CSV_ALL_PASS rows=21 bytes=2382 bits=19056
```

原有 TB 保留并继续验证握手反压、复位、错误恢复等场景。CSV TB 验证十六进制输入、
实际二进制发送、解帧输出与输入数据的一致性。初版没有修改解帧 RTL；当前版本已增加顶部说明的引导识别输出，
也没有实现实际接收链路的串行位同步、任意比特偏移找帧或位到字节硬件适配。
