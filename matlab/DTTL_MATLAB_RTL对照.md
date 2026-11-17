# DTTL MATLAB 与当前 RTL 对照

## 1. 原文件中哪些属于 DTTL

- 第 693 行开始的 Symbol Track 是符号定时跟踪段。
- 第 695–699 行：从 chip_buff 估计残余载波相位并旋转，再取实部。这是 DTTL 前处理，不是定时环路自身。
- 第 702–776 行：模式、积分、NCO、鉴相、环路滤波和 FCW 更新，是本次抽取的核心。
- 第 778–782 行：结果绘图，不参与环路。
- 第 802–815 行：PD_process，已完整带入独立文件。
- 第 785–800 行：帧同步、误码统计及 mess_ref.dat 导出，没有带入本文件。

## 2. 怎样运行独立参考

在 MATLAB 将当前目录切换到本目录：

```matlab
r = dttl_reference(); % 自带确定性演示输入；不需要先运行原大脚本

% 你已有原工程的 chip_buff 时：
process_data = chip_buff(:).';
phase_esti = angle(sum(process_data.^2));
DTTL_input = real(process_data * exp(-1j*phase_esti/2));
r = dttl_reference(DTTL_input, MODE, struct('Plot',true));

% 你从 RTL 导出数据时：只取 chip_out_en=1 时的 chip_out_i。
% r = dttl_reference(chip_i_valid, MODE, struct('Plot',true));
```

一个输入元素对应一个有效码片，输入码片率为 3.069 MHz。125 MHz 是 FPGA 处理时钟；24.552 MHz 是此前的 ADC 采样率，都不是这里每个输入元素的时间单位。
若从 RTL 的 chip_out_i 取输入，已经是实数码片流，不要再做上面基于复数 chip_buff 的相位旋转。
演示只证明文件能单独运行，不代表真实信道或硬件已经锁定。

## 3. 逐项对应

| MATLAB 原行 / 独立文件行 | MATLAB 变量与计算 | RTL 文件与入口行 | 硬件对应信号 |
|---|---|---|---|
| 699 / 输入参数 | DTTL_input(i) | TMTC_Track_Top.v 中 DTTL 实例 | data_in=chip_out_i，update_en=chip_out_en && !dttl_rst |
| 702–708 / 57 | nominal_osr | DTTL_Top.v:68 | MODE、FCW_basic |
| 721 / 76 | round(nominal_osr/2) | DTTL_Integrator.v:56 | middle_delay=767/384/192 |
| 722–727、749–754 / 77、104 | NCO_width=2^32、NCO_init=1、NCO 溢出 | DTTL_NCO.v:51 | NCO_WIDTH=32、NCO、NCO_sum、trig |
| 745、752、772 / 100 | Entire_int、DTTL_out | DTTL_Integrator.v:98 | entire_acc、entire_sum、entire_out、entire_en |
| 746–747、753、773 / 101 | Middle_int、MID_out | DTTL_Integrator.v:60 | delay_mem、w_pos、r_pos、middle_acc、middle_out |
| 755–757 / 111 | ref_magnitute（原变量拼写保留） | DTTL_PD.v:100 | ref_magnitude、ref_next |
| 759、802–815 / 115、186 | Entire_int_last、PD_sign、ud、PD | DTTL_PD.v:108 | entire_last、have_last、sign_change、PD_out、PD_en |
| 730–741、761–763 / 85、117 | 一阶时 C1=0，lp_out=C2*PD | DTTL_Loop_Filter.v:48 | PD_last、PD_delta、Ceq、FCW_modifying、FCW_en |
| 763、769 / 119 | 累加每次 FCW 修正 | DTTL_NCO.v:57 | FCW_sum、FCW、FCW_out |
| 无原 MATLAB 对应 | 新增失锁监督和局部重启 | DTTL_Supervisor.v；TMTC_Track_Top.v | 32 符号幅度窗口、dttl_rst、restart_pulse |

顶层的 entire_out 接 symbol_out，middle_out 接 dttl_middle_out，PD_out 接 dttl_pd_out；FCW_update_en 接 dttl_fcw_update_en。raw entire_en 接 dttl_symbol_valid_raw，外部 symbol_out_valid 还经过 !dttl_rst 门控。
本次没有修改上述任何 RTL。

## 4. 三个模式的参数

默认 BL=50，wn=94.3，loop_order=1，C1=0，C2=23.575。

| MODE | 符号率 | nominal_osr | Middle 延迟 | FCW_init / RTL FCW_basic | Ceq 浮点近似 | RTL Ceq（Q4 整数） |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 2000 | 1534.5 | 767 | 2798936 | 6843.809438 | 109501 |
| 2 | 4000 | 767.25 | 384 | 5597872 | 27375.237752 | 438004 |
| 3 | 8000 | 383.625 | 192 | 11195744 | 109500.951009 | 1752015 |

推导：Ceq=C2*Kf/(2*pi)，Kf=FCW_init/nominal_osr；RTL 保存 round(Ceq*16)。
原 MATLAB 的 MODE 在 otherwise 时走 8 ksym/s，RTL 对非 2/3 的 MODE 默认走 2 ksym/s。因此独立文件只允许 MODE=1/2/3，避免无效模式悄悄不一致。

## 5. 最值得你检查的公式

### 积分和符号结束

MATLAB 每个有效码片先加入 Entire 和延迟后的 Middle，再累加 NCO；若达到 2^32，就输出当前两路积分并清零积分器。
RTL 用组合 NCO_sum 溢出产生 trig，在同一个有效输入边沿将当前样本的 entire_sum/middle_sum 写到输出。因此也包括触发溢出的当前样本。
Middle 延迟缓存跨符号保持历史；每个符号只清积分器，不清历史缓存。RTL 在复位时清写指针和 sample_count，用 sample_count 屏蔽未填满缓存，与 MATLAB 前 Middle_start_index 个输入不累加延迟数据相对应。

### 鉴相

```text
decision(x) = +1 (x>=0)，否则 -1
PD_sign(k) = (decision(Entire(k-1))-decision(Entire(k)))/2
PD(k)      = -PD_sign(k) * Middle(k)/ref(k)
ref(k)     = max(ref(k-1), abs(Entire(k)))
```

首个符号 PD=0；当前 Entire=0 时 PD=0。没有符号翻转时 PD_sign=0，误差也为 0。
RTL 的 ref_next 包含本次 Entire 的幅度，和 MATLAB 先更新参考再鉴相的顺序一致。两边都把零判为正。

原代码的这一段没有产生限幅，本次照录：

```matlab
if abs(PD_value)>0.5
    PD_value=sign(PD_value)*abs(PD_value);
end
```

因为 sign(x)*abs(x) 仍然等于 x。当前 RTL 也没有显式的 ±0.5 限幅。

### 一阶环路

当 C1=0 时，lp_temp 始终为 0，所以 MATLAB 等价于：

```text
lp_out(k) = C2 * PD(k)
delta_FCW(k) = round(Ceq * (PD(k)-PD(k-1)))
FCW(k+1) = FCW(k) + delta_FCW(k)
```

RTL 正是先算 PD_delta，再乘 Ceq，再四舍五入得到 FCW_modifying，最后由 NCO 中的 FCW 寄存器累加。
要保留每次差分后的舍入；不要直接替换为 FCW_basic+round(Ceq*PD)，否则会改变舍入误差的累积。
原 MATLAB 还保留二阶分支；当前 RTL 只有上述一阶实现。本文件默认一阶，修改 opts.LoopOrder=2 只是在检查原 MATLAB 分支，不会与当前 RTL 一阶环路直接对应。

## 6. 不能直接当作逐拍、逐位相同的地方

1. MATLAB 是 double；RTL 输入 11 位、积分 22 位。RTL 积分超出位宽时回绕，MATLAB 不截位。
2. MATLAB PD 为实数；RTL PD_out 是 17 位有符号、15 个小数位。观察 RTL 时用 double(PD_out)/2^15 还原。RTL 分子先按幅值加半个分母实现四舍五入，再通过有符号除法得到 Q15；最后截取 17 位，超范围会回绕。
3. MATLAB Ceq 是浮点值；RTL Ceq 有 4 个小数位。乘积共 19 个小数位，RTL 正负都按幅值加 2^18 再恢复符号进行四舍五入。结果再截到 26 位，FCW 累加到 25 位；MATLAB FCW 不做这些截位。
4. MATLAB 在符号结束后立刻算出下一次 FCW；RTL 有寄存器、除法和乘法器流水。当前 div_gen_0.xci 的 latency 配置为 42，外围仍有其他寄存器延迟。必须按 entire_en/PD_en/FCW_update_en 对齐事件，不能把同一 CSV 行的所有量直接配成同一个符号。
5. 原 MATLAB 无 DTTL_Supervisor。当前 RTL 每 32 个有效符号统计 abs(Entire) 和 abs(Middle)，在幅度非零且 2*Middle_sum>3*Entire_sum 时触发局部复位；复位会重新装载基础 FCW、清积分/PD/环路状态。检查重启附近的数据时应分段比较。本参考不会自动重启。
6. 原 MATLAB 在 DTTL 前做一次离线复相位旋转；RTL 的实数输入来自载波/码跟踪后的 chip_out_i。输入标度、相位及有效采样位置必须先一致，才有条件进一步比较输出。
7. 本函数每次调用按 MODE 重新初始化；RTL 的 FCW_basic 仅在 rst 时装载。当前 DTTL_Supervisor 的 mode 输入没有参与模式切换检测。硬件切换模式后应施加复位，再从对应的首个有效码片开始比较。

## 7. 输出字段

- DTTL_out/MID_out：每个有效符号的 Entire/Middle 积分。
- PD/lp_temp/lp_out：每个符号的鉴相及环路内部数值。
- FCW：长度 output_count+1，第一个元素为初始 FCW，其后每个元素为一次符号结束后得到的 FCW。
- NCO_buff：每个有效输入样本更新后的 NCO 相位。
- symbol_end_sample：每次 NCO 溢出对应的 MATLAB 输入下标（从 1 开始）。
- ref_magnitude：本次鉴相使用的更新后幅度峰值。
- symbol_decision：与原帧同步入口相同的硬判决，零判为 +1；未执行帧同步。
- params：初始化参数、环路系数及当前 RTL Q4 系数快照。

只裁掉原预分配数组的未使用尾零；有效样本中的计算顺序和默认算法不变。
每次函数调用从初始状态运行，连续数据应一次传入；不能把若干分块分别调用后直接当成一个连续环路。

## 8. 来源与验证

原文件 SHA-256：e741c48e30e7861d9169cb4a9569f5150bd6f811dc03d32c4677702252e3bfd7。
当前抽取基于原始源文件，不是从先前 ILA 数据反推的算法。
运行结果见 validation_report.txt。验证包含三个模式的原段数值对比、全零输入和解析可知的恒定输入边界；不等同于 FPGA 逐拍仿真或板上测试。
