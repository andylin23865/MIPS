`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/04 17:58:46
// Design Name: 
// Module Name: re_me
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


module re_me(clk_re,data_bit,data_out,ready,count);
    input clk_re,data_bit;//clkΪϵͳʱ��
    output reg [7:0] data_out = 0;
    output reg ready = 0;
    output reg [3:0] count = 0;
    
    reg [7:0]data = 0;
    
    reg [2:0] sync = 0;
    
    wire clk;
    
    always@(posedge ready)
    begin data_out <= data; end
    
    wire begin_signal;
    assign  begin_signal = sync[1] && ~(sync[0]);
    
   // seg_all temp_t(clk_re,data[3:0],data[7:4],data_out[3:0],data[7:4],count,sync,0,1,6,seg_s,seg_sel);
    div_s top_div(clk_re,10416,clk);
    
    always @(negedge clk) begin
        if(begin_signal && (count <= 7))
        begin
            data <= {data_bit,data[7:1]};
            count <= count+1;
        end
        else if(count <= 8 && count > 7)
        begin count <= count + 1;end
        else if(count > 8)
             begin count <= 0;ready <= 1;sync = {sync[1:0],data_bit};end
        else sync = {sync[1:0],data_bit};
        if(ready == 1)
            ready <= 0;
    end
endmodule

module div(clk,num,clk_div);
    input clk;//ϵͳʱ��
    input [31:0]num;//��Ƶ����
    output clk_div;//�ź����
    reg [31:0]counter = 0;//������
    reg clk_out = 0;//����źŻ���
    always@(posedge clk)
    begin
    if(counter>=num)//������Ҫ��num��һ�㷴ת�ź�
        begin counter<=0;clk_out <= 1;end//�źŷ�ת
    else
        begin counter<=counter+1; clk_out <= 0;end//�ۼ�
    end
    assign clk_div = clk_out;//�ź����
endmodule

module div_s(clk,num,clk_div);//�ߵ�ƽ����������
    input clk;//ϵͳʱ��
    input [31:0]num;//��Ƶ����
    output clk_div;//�ź����
    reg [31:0]counter = 0;//������
    reg clk_out = 1;//����źŻ���
    always@(posedge clk)
    begin
    if(counter>=(num/2))//������Ҫ��num��һ�뷴ת�ź�
        begin counter<=1;clk_out <= ~clk_out;end//�źŷ�ת
    else
        begin counter<=counter+1;end//�ۼ�
    end
    assign clk_div = clk_out;//�ź����
endmodule
