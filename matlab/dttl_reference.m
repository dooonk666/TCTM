function out = dttl_reference(DTTL_input, MODE, opts)
%DTTL_REFERENCE 独立的 DTTL 浮点算法参考，默认计算保留原 MATLAB 行为。
% 来源：TCTM_TOP_new4_fixed.m 的 Symbol Track 段与 PD_process 函数。
% 原核心行号：702-776；原鉴相函数行号：802-815。
%
% 用法：
%   out = dttl_reference();           % 64 个无噪声演示符号，并绘图
%   out = dttl_reference(x, 1);       % x：每个有效码片一个实数样本
%   out = dttl_reference(x, 2, struct('Plot', true));
%
% MODE：1=2 ksym/s，2=4 ksym/s，3=8 ksym/s；输入码片率为 3.069 MHz。
% 对应 RTL：TMTC_Track_Top 中 chip_out_en 有效时的 chip_out_i。
% 不要直接传入 125 MHz 逐时钟序列或 24.552 MHz ADC 序列。
%
% opts.BL        默认 50，原 MATLAB 的带宽参数。
% opts.LoopOrder 默认 1；2 保留原 MATLAB 二阶分支，当前 RTL 仅实现一阶。
% opts.Plot      默认仅无参数演示时为 true。
%
% 本文件不依赖原工程工作区、MAT 文件或第三方 Toolbox。
% 不模拟 RTL 的 Q15/Q4 量化、位宽回绕、流水延时和 DTTL_Supervisor。
% 原 PD_process 中 abs(PD_value)>0.5 的分支不产生限幅；这里保持原样。

is_demo = nargin < 1;
if nargin < 2 || isempty(MODE), MODE = 1; end
if nargin < 3 || isempty(opts), opts = struct; end
validateattributes(MODE, {'numeric'}, {'real','finite','scalar','integer','>=',1,'<=',3});
if ~isstruct(opts) || ~isscalar(opts)
    error('dttl_reference:Options', 'opts 必须是标量 struct。');
end
if ~isfield(opts,'BL'), opts.BL = 50; end
if ~isfield(opts,'LoopOrder'), opts.LoopOrder = 1; end
if ~isfield(opts,'Plot'), opts.Plot = is_demo; end
validateattributes(opts.BL, {'numeric'}, {'real','finite','scalar','nonnegative'});
validateattributes(opts.LoopOrder, {'numeric'}, {'real','finite','scalar','integer','>=',1,'<=',2});
validateattributes(opts.Plot, {'numeric','logical'}, {'scalar','binary'});

if is_demo
    % 仅产生演示激励，不包含捕获、载波跟踪或帧同步。
    rates = [2000 4000 8000];
    demo_osr = 3.069e6/rates(MODE);
    demo_symbols = repmat([1 1 -1 1 -1 -1 1 -1],1,8);
    sample_symbol = floor((0:ceil(numel(demo_symbols)*demo_osr)-1)/demo_osr)+1;
    sample_symbol = min(sample_symbol,numel(demo_symbols));
    DTTL_input = 128*demo_symbols(sample_symbol);
end
validateattributes(DTTL_input, {'numeric'}, {'real','finite'});
if ~(isvector(DTTL_input) || isempty(DTTL_input))
    error('dttl_reference:InputShape', '输入必须是一维实数有效码片序列。');
end
DTTL_input = double(reshape(DTTL_input,1,[]));
input_length = length(DTTL_input);
Entire_int_last = 0; % 首个符号不鉴相；初始化不改变原计算结果。
symbol_end_sample = zeros(1,ceil(input_length/(3.069e6/8000))+1);
ref_history = symbol_end_sample;

%% 原 MATLAB 核心：NCO -> Entire/Middle 积分 -> PD -> 环路滤波 -> FCW
switch MODE
    case 1
        nominal_osr=3.069e6/2e3;
    case 2
        nominal_osr=3.069e6/4e3;
    otherwise
        nominal_osr=3.069e6/8e3;
end
Entire_int=0;
Middle_int=0;
DTTL_out=zeros(1,ceil(input_length/nominal_osr));
MID_out=DTTL_out;
PD=DTTL_out;
lp_temp=DTTL_out;
lp_out=DTTL_out;
FCW=zeros(1,ceil(input_length/nominal_osr)+1);
NCO_buff=zeros(1,input_length);


Middle_start_index=round(nominal_osr/2);
NCO_width=2^32;
FCW_init=round(NCO_width/nominal_osr);
NCO_init=1;
output_index=0;
FCW(1)=FCW_init;
NCO=NCO_init;


Kf=FCW_init/nominal_osr; % FCW transfering index
BL=opts.BL;  % noise bandwith
wn=1.886*BL;
Ts=1/nominal_osr;
loop_order=opts.LoopOrder;
if loop_order==1
    C1=0;
    C2=0.25*wn;
else
    C1=wn^2*Ts;
    C2=1.414*wn;
end

ref_magnitute=0;
for i=1:input_length
    Entire_int=Entire_int+DTTL_input(i);
    if i>Middle_start_index
        Middle_int=Middle_int+DTTL_input(i-Middle_start_index);
    end
    NCO=NCO+FCW(output_index+1);
    if NCO>=NCO_width
        output_index=output_index+1;
        symbol_end_sample(output_index)=i; % 观测记录，不改变环路计算
        DTTL_out(output_index)=Entire_int;
        MID_out(output_index)=Middle_int;
        NCO=NCO-NCO_width;
        if ref_magnitute<abs(Entire_int)
            ref_magnitute=abs(Entire_int);
        end
        if output_index>=2
            ud=PD_process(Entire_int,Entire_int_last,Middle_int,ref_magnitute);
            PD(output_index)=ud;
            lp_temp(output_index)=ud*C1+lp_temp(output_index-1);
            lp_out(output_index)=lp_temp(output_index)+lp_temp(output_index-1)+ud*C2;
            FCW(output_index+1)=FCW(output_index)+round((lp_out(output_index)-lp_out(output_index-1))/2/pi*Kf);
        else
            ud=0;
            PD(output_index)=ud;
            lp_temp(output_index)=ud*C1;
            lp_out(output_index)=lp_temp(output_index)+ud*C2;
            FCW(output_index+1)=FCW(output_index)+round(lp_out(output_index)/2/pi*Kf);
        end
        ref_history(output_index)=ref_magnitute; % 本次 PD 使用的峰值参考
        Entire_int_last=Entire_int;
        Entire_int=0;
        Middle_int=0;
    end
    NCO_buff(i)=NCO;
end

%% 仅打包有效输出，不保留原预分配数组尾部未使用的零
out.DTTL_out = DTTL_out(1:output_index);
out.MID_out = MID_out(1:output_index);
out.PD = PD(1:output_index);
out.lp_temp = lp_temp(1:output_index);
out.lp_out = lp_out(1:output_index);
out.FCW = FCW(1:output_index+1);
out.NCO_buff = NCO_buff;
out.symbol_end_sample = symbol_end_sample(1:output_index);
out.ref_magnitude = ref_history(1:output_index);
out.symbol_decision = sign(sign(out.DTTL_out)+0.5);
out.input_count = input_length;
out.output_count = output_index;
out.is_demo = is_demo;
out.params.MODE = MODE;
out.params.chip_rate = 3.069e6;
out.params.nominal_osr = nominal_osr;
out.params.middle_delay = Middle_start_index;
out.params.NCO_bits = 32;
out.params.NCO_modulus = NCO_width;
out.params.NCO_init = NCO_init;
out.params.FCW_init = FCW_init;
out.params.BL = BL;
out.params.wn = wn;
out.params.Ts = Ts;
out.params.loop_order = loop_order;
out.params.C1 = C1;
out.params.C2 = C2;
out.params.Kf = Kf;
out.params.Ceq_float = C2*Kf/(2*pi);
out.params.Ceq_Q4_reference = round(out.params.Ceq_float*2^4);
rtl_ceq_q4 = [109501 438004 1752015];
out.params.Ceq_Q4_rtl_snapshot = rtl_ceq_q4(MODE);
out.params.default_rtl_coefficient_match = ...
    loop_order == 1 && out.params.Ceq_Q4_reference == rtl_ceq_q4(MODE);

if opts.Plot
    figure('Name','DTTL integral reference');
    subplot(2,1,1); plot(out.DTTL_out,'.-'); grid on;
    title('Entire integral'); xlabel('Symbol index');
    subplot(2,1,2); plot(out.MID_out,'.-'); grid on;
    title('Middle integral'); xlabel('Symbol index');
    figure('Name','DTTL loop reference');
    subplot(2,1,1); plot(0:output_index,out.FCW,'.-'); grid on;
    title('FCW: initial value + one value after each symbol'); xlabel('Update index');
    subplot(2,1,2); plot(out.PD,'.-'); grid on;
    title('Normalized phase detector output'); xlabel('Symbol index');
end
end

%% 原 PD_process：照录，保持零值判决及不产生限幅的分支
function PD_result=PD_process(Entire_current,Entire_previous,Middle_current,ref)
    Entire_current_sign=sign(sign(Entire_current)+0.5);
    Entire_previous_sign=sign(sign(Entire_previous)+0.5);
    PD_sign=(Entire_previous_sign-Entire_current_sign)/2;
    if Entire_current==0
        PD_value=0;
    else
        PD_value=Middle_current/ref;
    end
    if abs(PD_value)>0.5
        PD_value=sign(PD_value)*abs(PD_value);
    end
    PD_result=-PD_sign*PD_value;
end
