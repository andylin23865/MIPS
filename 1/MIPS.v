`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/18 19:31:56
// Design Name: linwei
// Module Name: comfile
// Project Name: ICSC
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define CLK_MIPS_DIV 'd10416 //9600HZ
`define START_ADDRESS 'h400000
`define DATA_START_ADDRESS 'h10010000
`define DATA_STACK_START_ADDRESS 'd256

module top_mips(debug,en_code_load,en_data_load,en,data_bit,clk,clk_mip,fault,seg_s,seg_sel,mips_temp,con,oVGA_HS , oVGA_VS,oVGA_R , oVGA_G , oVGA_B);
output fault;//错误信息输出
input debug;//调试模式
input en_code_load;//载入代码使能
input en_data_load;//载入数据使能
input en;//使能端
input data_bit;//串口数据流
input clk;//系统时钟
input clk_mip;//按钮输入
wire [31:0]result = 0;//输出
output [6:0]seg_s;//数码管显示
output [7:0]seg_sel;//数码管显示
output mips_temp;
input [5:0]con;//数码管调试控制信号

wire clk_button;
wire clk_mp;

div_s s_mips(clk,`CLK_MIPS_DIV,clk_mp);

wire [7:0]reg_to_screen_data;
wire [7:0]result_to_screen_data;

debouncing t0(clk,clk_mip,clk_button);

reg clk_mips = 0;

always@(posedge clk)
begin
    if(debug) begin clk_mips = clk_button;end
    else begin  clk_mips = clk_mp;end
end

wire [7:0]mips_data;
wire mips_ready;

decode top0(en_code_load,en_data_load,en,data_bit,clk,clk_button,result,fault,seg_s,seg_sel,co,mips_data,reg_to_screen_data,result_to_screen,mips_ready);

output [3:0] oVGA_R , oVGA_G , oVGA_B;
output oVGA_HS , oVGA_VS;

vga vga_to_screen(  clk,en,oVGA_R,oVGA_G,oVGA_B,oVGA_HS,oVGA_VS,mips_data,reg_to_screen_data,result_to_screen_data,mips_ready,1);

endmodule

module debouncing(clk,in,out);
input clk,in;//clk系统时钟，in物理按键
output reg out;//消除抖动输出
reg [19:0] clk_count = 0;//计数
reg clk_20ms = 0;//20ms时钟
reg out_temp;
always@(posedge clk)
begin
clk_count = clk_count + 1;
if(clk_count == 1000000)//产生20ms时钟
    begin
    clk_20ms = ~clk_20ms;
    clk_count = 0;
    end
end
always@(posedge clk_20ms)
begin
out_temp <= in;//非阻塞型赋值延时消除抖动
out <= out_temp;
end
endmodule

module decode(en_code_load,en_data_load,en,data_bit,clk,clk_mips,result,fault,seg_s,seg_sel,con,reg_to_screen_data,result_to_screen_data,MIPS_DATA,MIPS_READY);
output fault;
input en_code_load;//载入代码使能
input en_data_load;//载入数据使能
input en;//使能端
input data_bit;//串口数据流
input clk;//系统时钟
input clk_mips;//统一时钟
output reg [31:0]result = 0;//输出
output reg [7:0]reg_to_screen_data;
output reg [7:0]result_to_screen_data;
output [7:0]MIPS_DATA;
output MIPS_READY;

reg fault1 = 0;
reg fault2 = 0;
reg fault3 = 0;

assign fault = (fault1)|fault2|fault3;

/*全模块需要的临时变量*/
reg [31:0]mips_reg[31:0] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};//MIPS_REGS

reg [7:0]stack[2*`DATA_STACK_START_ADDRESS:0];//MIPS栈空间

reg [31:0]data_op;//栈中取出的数据

reg [31:0]addr = `START_ADDRESS;//寻址地址

/*ALU模块临时变量*/
reg [31:0] in_x;//第一个操作数
reg [31:0] in_y;//第二个操作数
reg cin;//0位加法，1位减法
reg [31:0] ALU_result;//计算结果
reg carry;//无符号溢出位
reg zero;//0判断位
reg overflow;//溢出判断位
reg S_bit;//符号位

/*ALU 运算*/
    reg [31:0] in_y_t;
    always@(in_y or cin)   in_y_t = ({32{cin}}^in_y);
    always@(cin or in_x or in_y_t)
    begin
       {carry,ALU_result} = in_y_t + in_x + cin;
       zero = ~(|ALU_result);
       overflow = (in_x[31] == in_y_t[31])&&(ALU_result[31] != in_x[31]);
       S_bit = ALU_result[31];
    end
    
/*移位运算*/
reg s_start = 0;
reg [31:0]num;
reg [31:0]period = 2;
wire clk_out;
pulse pulse_0(s_sart,clk,num,period,clk_out);

reg [31:0]in_a;
reg [1:0]mode = 0;

always@(posedge clk_out)
begin
    in_a <= mips_reg[data_op[20:16]];
    case(mode)
    0:begin in_a <= {1'b0,in_a[31:1]}; end//逻辑右移
    1:begin in_a <= {in_a[30:0],1'b0}; end//逻辑左移
    2:begin in_a <= {in_a[31],in_a[31:1]}; end//算右移
    3:begin in_a <= {in_a[30:0],1'b0}; end//算数左移
    default:begin fault3 <= 1; end
    endcase
end


/*串口接收模块临时变量*/
wire ready;//接收完毕信号
wire [3:0]count;//接收计数器
wire [7:0]data;//接收数据

/*STACK 临时变量*/
reg [31:0]code_stack_addr = `START_ADDRESS - 1;//栈载入地址
reg [31:0]code_data_stack_addr = `DATA_START_ADDRESS - 1;//栈载入地址
reg write = 0;

re_me top_recomfile_receive(clk,data_bit,data,ready,count);//接收模块

reg [2:0]neg_ready = 0;
reg [1:0]pos_write = 0;

reg [31:0]write_stack_addr = 0;

always@(posedge clk)
begin
    if(en)
    begin
    neg_ready <= {neg_ready[1:0],ready};
    pos_write <= {pos_write[0],write}; 
    if(en_code_load && neg_ready[2] && ~neg_ready[1]) begin code_stack_addr <= code_stack_addr+1;stack[code_stack_addr - `START_ADDRESS] <= data;end
    //载入代码段
    else if(en_data_load && neg_ready[2] && ~neg_ready[1])begin code_data_stack_addr = code_data_stack_addr+1;stack[code_data_stack_addr - `DATA_START_ADDRESS +`DATA_STACK_START_ADDRESS] = data; end
    //载入数据段
    else if(~pos_write[1] && pos_write[0])
        begin
            stack[write_stack_addr] <= mips_reg[data_op[20:16]][31:24];
            stack[write_stack_addr+1] <= mips_reg[data_op[20:16]][23:16];
            stack[write_stack_addr+2] <= mips_reg[data_op[20:16]][15:8];
            stack[write_stack_addr+3] <= mips_reg[data_op[20:16]][7:0];
        end
    end//写入改变数据
end

reg [2:0]pos_clk_mips = 0;

reg [31:0]stack_addr_temp = 0;

reg stop = 0;

always@(posedge clk)//核心处理模块
begin
pos_clk_mips <= {pos_clk_mips[1:0],clk_mips};
if((!en_code_load && !en_data_load) && en)
begin
if(pos_clk_mips[0] && ~pos_clk_mips[1])
begin
    data_op <= {stack[addr -`START_ADDRESS],stack[addr+1-`START_ADDRESS],stack[addr+2-`START_ADDRESS],stack[addr+3-`START_ADDRESS]};/*debug*/
end
else if(pos_clk_mips[1] && ~pos_clk_mips[2])
    begin
    case(data_op[31:26])
    0 :
    begin 
        case(data_op[5:0])
        0 :begin num <= data_op[10:6];mode <= 1;s_start <= 1; end
        2 :begin num <= data_op[10:6];mode <= 0;s_start <= 1; end
        3 :begin num <= data_op[10:6];mode <= 2;s_start <= 1; end
        4 :begin num <= mips_reg[data_op[25:21]];mode <= 1;s_start <= 1; end
        6 :begin num <= mips_reg[data_op[25:21]];mode <= 0;s_start <= 1; end
        7 :begin num <= data_op[10:6];mode <= 2;s_start <= 1; end
        8 :begin end
        32:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 0; end
        33:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 0; end
        34:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
        35:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
        36:begin /* a&b */ end
        37:begin /* a|b */ end
        38:begin /* a^b */ end
        39:begin /* ~(a|b) */ end
        42:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
        43:begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
        default:begin fault1 <= 1; end
        endcase
    end
    2 :begin end
    3 :begin end
    4 :begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
    5 :begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
    7 :begin in_x <= mips_reg[data_op[25:21]];in_y <= mips_reg[data_op[20:16]]; cin <= 1; end
    8 :begin in_x <= mips_reg[data_op[25:21]];in_y <= (data_op[15] == 1)?(data_op[15:0] | 32'hffff0000):(data_op[15:0] | 0); cin <= 0; end
    9 :begin in_x <= mips_reg[data_op[25:21]];in_y <= (data_op[15:0] | 0); cin <= 0; end
    10:begin in_x <= mips_reg[data_op[25:21]];in_y <= (data_op[15:0] | ({{16{data_op[15]}},16'h0000}));cin <= 1;end
    11:begin end
    12:begin /*a&imm*/ end
    13:begin /*a|imm*/ end
    14:begin /*a^imm*/ end
    15:begin end
    35:begin stack_addr_temp <= mips_reg[data_op[25:21]] - `DATA_START_ADDRESS +`DATA_STACK_START_ADDRESS + (data_op[15:0] | ({{16{data_op[15]}},16'h0000})); end
    43:begin write_stack_addr <=  mips_reg[data_op[25:21]] - `DATA_START_ADDRESS +`DATA_STACK_START_ADDRESS + (data_op[15:0] | ({{16{data_op[15]}},16'h0000}));write <= 0; end
    63:begin end
    default:begin fault1 <= 1; end
    endcase
end
    else if(~pos_clk_mips[0] && pos_clk_mips[1])
    begin
        addr <= addr + 4;
        case(data_op[31:26])
        0 :
        begin 
            case(data_op[5:0])
            0 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            2 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            3 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            4 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            6 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            7 :begin mips_reg[data_op[15:11]] <= in_a;s_start <= 0; end
            8 :begin addr <= mips_reg[data_op[25:21]]; end
            32:begin mips_reg[data_op[15:11]] <= ALU_result; end 
            33:begin mips_reg[data_op[15:11]] <= ALU_result; end
            34:begin mips_reg[data_op[15:11]] <= ALU_result; end
            35:begin mips_reg[data_op[15:11]] <= ALU_result; end
            36:begin mips_reg[data_op[15:11]] <= mips_reg[data_op[25:21]] & mips_reg[data_op[20:16]]; end
            37:begin mips_reg[data_op[15:11]] <= mips_reg[data_op[25:21]] | mips_reg[data_op[20:16]]; end
            38:begin mips_reg[data_op[15:11]] <= mips_reg[data_op[25:21]] ^ mips_reg[data_op[20:16]]; end
            39:begin mips_reg[data_op[15:11]] <= ~(mips_reg[data_op[25:21]] | mips_reg[data_op[20:16]]); end
            42:begin mips_reg[data_op[15:11]] <= S_bit != overflow; end
            43:begin mips_reg[data_op[15:11]] <= carry; end
            default:begin fault2 <= 1; end
            endcase
        end
        2 :begin addr <= addr + 4;addr <= {addr[31:28],data_op[25:0],2'b00}; end
        3 :begin addr <= addr + 4;mips_reg[31] <= addr;addr <= {addr[31:28],data_op[25:0],2'b00}; end
        4 :begin if(zero) addr <= addr + 4 + (({data_op[15:0],2'b00}|({{14{data_op[15]}},18'h00000}))); end
        5 :begin if(!zero) addr <= addr + 4 +(({data_op[15:0],2'b00}|({{14{data_op[15]}},18'h00000}))); end
        7 :begin if(~S_bit && ~zero) addr <= addr + 4 + (({data_op[15:0],2'b00}|({{14{data_op[15]}},18'h00000}))); end
        8 :begin mips_reg[data_op[20:16]] <= ALU_result; end
        9 :begin mips_reg[data_op[20:16]] <= ALU_result; end
        10:begin mips_reg[data_op[15:11]] <= S_bit != overflow; end
        11:begin mips_reg[data_op[15:11]] <= carry; end
        12:begin mips_reg[data_op[20:16]] <= mips_reg[data_op[25:21]] & (data_op[15:0] | 0); end
        13:begin mips_reg[data_op[20:16]] <= mips_reg[data_op[25:21]] | (data_op[15:0] | 0); end
        14:begin mips_reg[data_op[20:16]] <= mips_reg[data_op[25:21]] ^ (data_op[15:0] | 0); end
        15:begin mips_reg[data_op[20:16]] <= {data_op[15:0],16'h0000}; end
        35:begin mips_reg[data_op[20:16]] <= {stack[stack_addr_temp],stack[stack_addr_temp+1],stack[stack_addr_temp + 2],stack[stack_addr_temp + 3]}; end
        43:begin write <= 1; end
        63:begin result <= mips_reg[data_op[4:0]]; end
        default:begin fault2 <= 1; end
        endcase
end
end
end

reg [7:0]reg_to_screen[127:0];

initial    
begin
   $readmemh("D:/cslab/reg_to_screen.txt", reg_to_screen, 0, 127);
end

initial    
begin
    $readmemh("D:/cslab/mips.txt", stack, 0, 63);
    $readmemh("D:/cslab/data.txt", stack, 256, 315);
end

reg [6:0]count_t = -1;

always@(posedge clk)
begin
    count_t <= count_t+1;
    reg_to_screen_data <= reg_to_screen[count_t];
end

reg [2:0]count_reg = -1;
reg [2:0]count_num = -1;

always@(posedge clk)
begin
    count_num = count_num + 1;
    if(count_num == 0)
        count_reg = count_reg + 1;
    case(count_num)
    0:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][31:28] > 10)?(mips_reg[count_reg+8][31:28] + 51):(mips_reg[count_reg+8][31:28] + 48);
    1:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][27:24] > 10)?(mips_reg[count_reg+8][27:24] + 51):(mips_reg[count_reg+8][27:24] + 48);
    2:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][23:20] > 10)?(mips_reg[count_reg+8][23:20] + 51):(mips_reg[count_reg+8][23:20] + 48);
    3:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][19:16] > 10)?(mips_reg[count_reg+8][19:16] + 51):(mips_reg[count_reg+8][19:16] + 48);
    4:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][15:12] > 10)?(mips_reg[count_reg+8][15:12] + 51):(mips_reg[count_reg+8][15:12] + 48);
    5:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][11:8] > 10)?(mips_reg[count_reg+8][11:8] + 51):(mips_reg[count_reg+8][11:8] + 48);
    6:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][7:4] > 10)?(mips_reg[count_reg+8][7:4] + 51):(mips_reg[count_reg+8][7:4] + 48);
    7:reg_to_screen[count_reg*16+count_num+5] = (mips_reg[count_reg+8][3:0] > 10)?(mips_reg[count_reg+8][3:0] + 51):(mips_reg[count_reg+8][3:0] + 48);
    default:begin end
    endcase
end

reg [7:0]result_to_screen[15:0];

reg [3:0]count_t_result = -1;

initial begin 
result_to_screen[0] = 'h3e;result_to_screen[1] = 'h20;result_to_screen[2] = 'h3e;result_to_screen[3] = 'h20;
result_to_screen[4] = 'h30;result_to_screen[5] = 'h78;result_to_screen[6] = 'h30;result_to_screen[7] = 'h30;
result_to_screen[8] = 'h30;result_to_screen[9] = 'h30;result_to_screen[10] = 'h30;result_to_screen[11] = 'h30;
result_to_screen[12] = 'h30;result_to_screen[13] = 'h30;result_to_screen[14] = 'h20;result_to_screen[15] = 'h0a;
  end

always@(posedge clk)
begin
    count_t_result <= count_t_result+1;
    result_to_screen_data <= result_to_screen[count_t];
end

reg [2:0]count_result_num = -1;

always@(posedge clk)
begin
    count_result_num = count_result_num + 1;
    case(count_result_num)
    0:result_to_screen[count_result_num+6] = (result[31:28] > 10)?(result[31:28] + 51):(result[31:28] + 48);
    1:result_to_screen[count_result_num+6] = (result[27:24] > 10)?(result[27:24] + 51):(result[27:24] + 48);
    2:result_to_screen[count_result_num+6] = (result[23:20] > 10)?(result[23:20] + 51):(result[23:20] + 48);
    3:result_to_screen[count_result_num+6] = (result[19:16] > 10)?(result[19:16] + 51):(result[19:16] + 48);
    4:result_to_screen[count_result_num+6] = (result[15:12] > 10)?(result[15:12] + 51):(result[15:12] + 48);
    5:result_to_screen[count_result_num+6] = (result[11:8] > 10)?(result[11:8] + 51):(result[11:8] + 48);
    6:result_to_screen[count_result_num+6] = (result[7:4] > 10)?(result[7:4] + 51):(result[7:4] + 48);
    7:result_to_screen[count_result_num+6] = (result[3:0] > 10)?(result[3:0] + 51):(result[3:0] + 48);
    default:begin end
    endcase
end

input [5:0]con;
reg [31:0]xianshi = 1;

reg [5:0]con_temp;

always@(posedge clk)
    con_temp <= con;

always@(con_temp)
begin
    case(con_temp)
    'b100000:begin xianshi = data_op; end//显示操作码
    'b100001:begin xianshi = addr; end//显示地址
    'b100010:begin xianshi = code_stack_addr; end//显示最大代码段地址
    'b100011:begin xianshi = code_data_stack_addr; end//显示最大数据段地址
    'b100100:begin xianshi = ALU_result; end//显示ALU运算结果
    'b100101:begin xianshi = result; end//显示外设输出运算结果
    'b100110:begin xianshi = data; end//显示串口接收数据
    default:begin 
    if(con_temp > 'b100110)xianshi = stack[con_temp - 'b100111];//显示部分栈空间
    else xianshi = mips_reg[con];//显示32个寄存器
    end
    endcase
end

assign MIPS_DATA = data;
assign MIPS_READY = ready;

output  [6:0]seg_s;
output  [7:0]seg_sel;
seg_all seg0(clk,xianshi[3:0],xianshi[7:4],xianshi[11:8],xianshi[15:12],xianshi[19:16],xianshi[23:20],xianshi[27:24],xianshi[31:28],8,seg_s,seg_sel);

endmodule

/*这是一个可以产生固定周期以及个数脉冲的模块，脉冲完成后恢复0信号*/
/*经测试，re信号持续时间最好多于一个clk周期*/
module pulse(re,clk,num,period,clk_out);
input re;//更新信号
input clk;//时钟
input [31:0]num;//脉冲次数
input [31:0]period;//period个clk为周期(1时有bug)
output reg clk_out = 0;//输出信号

reg [1:0]pos_re = 0;//检测复位信号的上升沿

reg [31:0]counter = 0;//周期计数器
reg [31:0]T_num = 0;//周期个数计数器

always@(clk)
begin
    pos_re = {pos_re[0],re};
end

always@(clk)
begin
if(period == 1)//解决1时候的bug
begin
if((!pos_re[1] && pos_re[0]) == 1)
    begin counter = 0;T_num = 0;end
else if(T_num < num)
    begin clk_out = ~clk_out; if(clk_out == 1)T_num = T_num + 1;end
else
    clk_out = 0;
end
else if(clk == 1)//不为1时的情况
begin
if((!pos_re[1] && pos_re[0]))
    begin counter = 0;T_num = 0;end
else if(counter >= period-1)//周期需要在num的一般反转信号
    begin counter<=0;T_num = T_num + 1;
    if(T_num > num) clk_out <= 0;
    else clk_out <= 1; 
    end//信号反转
else if(T_num <= num)
    begin counter<=counter+1; clk_out <= 0;end//累加
end
end
endmodule

module seg_all(clk,num_0,num_1,num_2,num_3,num_4,num_5,num_6,num_7,con,seg_it,seg_sel);
input clk;
input [3:0] num_0;
input [3:0] num_1;
input [3:0] num_2;
input [3:0] num_3;
input [3:0] num_4;
input [3:0] num_5;
input [3:0] num_6;
input [3:0] num_7;
input [2:0] con;
output reg [6:0]seg_it  = 7'b1000000;
output reg [7:0]seg_sel = 'b11111111;
reg [25:0]count_clk = 0;
wire [6:0] out_1;
wire [6:0] out_2;
wire [6:0] out_3;
wire [6:0] out_4;
wire [6:0] out_5;
wire [6:0] out_6;
wire [6:0] out_7;
wire [6:0] out_8;
seg s0(num_0,out_1);
seg s1(num_1,out_2);
seg s2(num_2,out_3);
seg s3(num_3,out_4);
seg s4(num_4,out_5);
seg s5(num_5,out_6);
seg s6(num_6,out_7);
seg s7(num_7,out_8);
reg [2:0]select = 0;

	always@(posedge clk)
    begin
    if(count_clk == 50000000)
    begin
        count_clk = 0;
    end
    else
        count_clk = count_clk+1;
    end

always@(posedge count_clk[17])
begin
case(select)
'd0:begin seg_it = out_1; seg_sel = 'b11111110; end
'd1:begin seg_it = out_2; seg_sel = 'b11111101; end
'd2:begin seg_it = out_3; seg_sel = 'b11111011; end
'd3:begin seg_it = out_4; seg_sel = 'b11110111; end
'd4:begin seg_it = out_5; seg_sel = 'b11101111; end
'd5:begin seg_it = out_6; seg_sel = 'b11011111; end
'd6:begin seg_it = out_7; seg_sel = 'b10111111; end
'd7:begin seg_it = out_8; seg_sel = 'b01111111; end
default: begin seg_it = 'b0111111; seg_sel = 'b11111111; end
endcase
select = select + 1;
if(select == con)
    select = 0;
end

endmodule

module seg(num,seg);
input [3:0] num;
output reg [6:0] seg = 7'b1000000;
     always@(num)
        begin
        case(num)
        4'd0 :begin seg = 7'b1000000; end
        4'd1 :begin seg = 7'b1111001; end
        4'd2 :begin seg = 7'b0100100; end
        4'd3 :begin seg = 7'b0110000; end
        4'd4 :begin seg = 7'b0011001; end
        4'd5 :begin seg = 7'b0010010; end
        4'd6 :begin seg = 7'b0000010; end
        4'd7 :begin seg = 7'b1111000; end
        4'd8 :begin seg = 7'b0000000; end
        4'd9 :begin seg = 7'b0010000; end
        4'd10:begin seg = 7'b0001000; end
        4'd11:begin seg = 7'b0000011; end
        4'd12:begin seg = 7'b1000110; end
        4'd13:begin seg = 7'b0100001; end
        4'd14:begin seg = 7'b0000110; end
        4'd15:begin seg = 7'b0001110; end
        default:begin seg = 7'b0111111; end
        endcase
        end
endmodule