`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/19 18:08:23
// Design Name: 
// Module Name: test_regs
// Project Name: 
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


module test_regs();
wire fault;
reg en_code_load;//载入使能
reg en_data_load;//载入使能
reg en;//使能端
reg data_bit;//串口数据流
reg clk;//系统时钟
reg clk_mips;//统一时钟
wire [31:0]result;//输出
reg [7:0]data;
reg ready;
wire [7:0]screen;
reg [5:0]con = 3;
wire [6:0]seg_s;
wire [7:0]seg_sel;
reg clk_sent;
decode test(clk_sent,en_code_load,en_data_load,en,data_bit,clk,clk_mips,result,fault,seg_s,seg_sel,con,screen,,,);

always
#2 clk = ~clk;

always
#10 clk_mips = ~clk_mips;

always
#20 clk_sent = ~clk_sent;

initial begin
en_code_load = 0;en_data_load = 0;en = 1;data_bit = 1;clk = 0;clk_mips = 0;clk_sent = 0;

end

endmodule
