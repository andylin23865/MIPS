`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/20 22:16:55
// Design Name: 
// Module Name: vga
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

//字符显示

//`define ASCII 'hff
//`define border 'hef

module vga(  iCLK_100,    //   clock   100MHZ 
             iCLRN,      // clear_N  connect to iSW[0]
             oVGA_R,  
             oVGA_G,
             oVGA_B,
             oVGA_HS,
             oVGA_VS,
             c_data,
             r_data,
             d_data,
             ready,
             en,
             clk_sent
             );
input iCLK_100;//,c_clk;
input iCLRN;
input ready,en;
input [7:0] r_data,c_data,d_data;
input clk_sent;

output [3:0] oVGA_R , oVGA_G , oVGA_B;
output oVGA_HS , oVGA_VS;

reg  vga_clk;
reg  mid_clk;
//reg  last_cclk, last_rclk;
//reg initial_clr;                //初始化使能
//reg  myclk;
reg [9:0] h_count ,  v_count;
reg video_out1, video_out2;
reg [2:0] h;
reg [3:0] v;
reg [4:0] v_begin, v_tail;
reg [6:0] h_begin, h_tail;
integer i = 0, j = 0, d_count = 0, r_count = 0, c_count = 0, cv_count = 0;

reg [7:0] c_show [1403:0];        //18*78  ascii - 0x20
reg [7:0] d_show [77:0];          //78  ascii - 0x20
reg [7:0] r_show [623:0];        //8*78  ascii - 0x20
reg [7:0] ascii_zk [1519:0];    //95*16
//reg [7:0] d_data = 8'h31;

/*always@(posedge iCLK_100) begin
if(initial_clr) begin
    if(initial_count == V_CODE_END)
        initial_clr = 1'b0;
    else begin
        c_show[initial_count]=8'h00;
        initial_count = initial_count+1;
    end
end
end*/


initial begin
    $readmemh("D:/cslab/ascii_zk_ram_data.txt", ascii_zk, 0, 1519);
end


/*-----------------------------------------------------------------
        常量定义
------------------------------------------------------------------*/ 
    //  Horizontal Parameter    ( Pixel ) 减去边框后
    parameter   H_SYNC_CYC  =   96;
    parameter   H_SYNC_BACK =   48;
    parameter   H_SYNC_ACT  =   624;    
    parameter   H_SYNC_FRONT=   24;
    parameter   H_SYNC_TOTAL=   800;    // 96+48+640+16=800
    //  Virtical Parameter      ( Line ) 减去边框和
    parameter   V_SYNC_CYC  =   2;
    parameter   V_SYNC_BACK =   33;  //32
    parameter   V_SYNC_ACT  =   448;    
    parameter   V_SYNC_FRONT=   26;  //11
    parameter   V_SYNC_TOTAL=   525;    // 2+32+480+11=525
    parameter   V_CODE_END = 1482; // 78*19
    parameter   V_REG_END = 624; //78*8
    //  Start Offset
    parameter   X_START     =   H_SYNC_CYC+H_SYNC_BACK+8;   //  96 + 48=144    before  640
    parameter   Y_START     =   V_SYNC_CYC+V_SYNC_BACK+16;   //  2  + 33=35    before  480
    
    //color of back ground
    parameter Color_R = 4'b1111;
    parameter Color_G = 4'b1111;
    parameter Color_B = 4'b1111;
/*----------------------------------------------------------------- */
//  oVGA_CLK  Generator,  100MHZ to 25MHZ
always @(posedge iCLK_100 or negedge iCLRN) begin
   if(iCLRN == 0)       mid_clk <= 1'b1; 
   else                 mid_clk <= ~mid_clk;
   end
always @(posedge mid_clk or negedge iCLRN) begin
      if(iCLRN == 0)    vga_clk <= 1'b0;
      else              vga_clk <= ~vga_clk;
      end
//  H_Sync Counter  
always @(posedge vga_clk or negedge iCLRN) begin 
   if(iCLRN==0)         h_count <= 10'd0;
   else if (h_count == H_SYNC_TOTAL)   h_count <= 10'd0;
      else              h_count = h_count + 10'd1;
      i = h_count < X_START ? 0 : (h_count-X_START)/8;
   end
//  V_Sync Counter    
always @(posedge vga_clk or negedge iCLRN) begin 
   if(iCLRN==0)         v_count <= 10'd0;
   else if (h_count == H_SYNC_TOTAL) begin
           if(v_count == V_SYNC_TOTAL)  
                        v_count <= 10'd0;
           else         v_count = v_count + 10'd1;
           j = (v_count < Y_START) ? 0 : ((v_count-Y_START)/16);
           end
end

wire c_clk = iCLK_100;

/*always@(negedge iCLK_100)begin
    last_cclk <= c_clk;
//    last_rclk <= r_clk;
end*/

//wire data_csign = !last_cclk && c_clk;
//wire data_rsign = !last_rclk && r_clk;


//接收要显示的字符的ASCII码


reg [2:0]neg_ready = 0;

always@(posedge iCLK_100)begin                          //代码接收
if(en) begin
    neg_ready <= {neg_ready[1:0],ready};
    if(neg_ready[1] && ~neg_ready[0])begin
        if(c_count == 24) begin
            c_count = 0;
            if(cv_count == 17)begin
                cv_count = 0;
            end
            else
                cv_count = cv_count + 1;
        end
        else begin
            c_show[cv_count*78+c_count] = c_data-8'h20;
            c_count = c_count + 1;
        end
        end
end
end

always@(negedge clk_sent)begin                          //数据接收
if(1) begin
        if(d_count == 16) begin
            d_count = 0;
        end
        else begin
            d_show[d_count] = d_data-8'h20;
            d_count = d_count + 1;
        end
end
end

reg [2:0] rv_count;

always@(negedge clk_sent)begin              //寄存器数据接收
if(1)  begin
    if(r_count == 15)begin
        r_show[rv_count*78+r_count] = r_data-8'h20;
        r_count = 0;
        rv_count = rv_count + 1;
    end
    else begin
        r_show[rv_count*78+r_count] = r_data-8'h20;
        r_count = r_count + 1;
    end
end
end

always@(*)begin
    v_begin = 0; v_tail = 17;
    h_begin = 0; h_tail = 23;
end
   
always @(posedge iCLK_100)begin                 //时钟需改动
if(h_count >= X_START && h_count <=  X_START+H_SYNC_ACT && v_count >= Y_START && v_count < Y_START+18*16)begin       //程序执行框1
    if(j >= v_begin && j <= v_tail && i >= h_begin && i <= h_tail)begin
        h=h_count-8*i-X_START; v=v_count-16*j-Y_START;
        video_out1 = ascii_zk[(c_show[j*78+i])*16+v][8-h];
        video_out2 = 1'b0;
    end
    else begin video_out1 = 1'b0; video_out2 = 1'b0;end
end
else if(h_count >= X_START && h_count <=  X_START+H_SYNC_ACT && v_count >= Y_START+18*16 && v_count <= Y_START+19*16)begin       //程序执行框2
    if(i >= h_begin && i <= 15)begin
        h=h_count-8*i-X_START; v=v_count-16*j-Y_START;
        video_out1 = ascii_zk[(d_show[j*78+i-V_CODE_END+78])*16+v][8-h];
        video_out2 = 1'b0;
    end
    else begin video_out1 = 1'b0; video_out2 = 1'b0;end
end
else if(h_count >= X_START && h_count <= X_START+H_SYNC_ACT && v_count >= Y_START+20*16 && v_count <= Y_START+V_SYNC_ACT)  begin         //调试框
    if(i >= 0 && i <= 15)begin
    h=h_count-8*i-X_START; v=v_count-16*j-Y_START;
    video_out1 = ascii_zk[(r_show[j*78+i-V_CODE_END-78])*16+v][8-h];
    video_out2 = 1'b0;
    end
    else begin video_out1 = 1'b0; video_out2 = 1'b0;end
end

else if( h_count >= X_START - 8 && h_count < X_START && v_count >= Y_START - 8           //边框
       || v_count >= Y_START - 8 && v_count < Y_START && h_count >= X_START && h_count <= X_START +  H_SYNC_ACT
       || v_count > Y_START+19*16 && v_count < Y_START+20*16 && h_count >= X_START && h_count <= X_START +  H_SYNC_ACT
       || h_count > X_START +  H_SYNC_ACT && h_count <= X_START +  H_SYNC_ACT + 8 && v_count >= Y_START-8
       || v_count > Y_START +  V_SYNC_ACT && v_count <= Y_START +  V_SYNC_ACT + 16 && h_count >= X_START && h_count <= X_START +  H_SYNC_ACT ) begin
        video_out2 = 1'b1;
        video_out1 = 1'b0;
end
else begin video_out1 = 1'b0; video_out2 = 1'b0;end
end

/*always@(*)begin
    video_out1 = (((h_count>=X_START-8)
                     &&(h_count<X_START+H_SYNC_ACT+8))
                    &&((v_count>=Y_START-16)
                     &&(v_count<Y_START+V_SYNC_ACT+16))); 
    video_out2 = 1'b0;
end*/


             
assign oVGA_HS = (h_count > H_SYNC_CYC);
assign oVGA_VS = (v_count > V_SYNC_CYC);
assign oVGA_R = (video_out2 || video_out1) ? Color_R:0;   
assign oVGA_G = (video_out1) ? Color_G:0;
assign oVGA_B = (video_out1) ? Color_B:0;   

endmodule

/*
//键盘接收
module ps2_keyboard(clk,clrn,ps2_clk,ps2_data,ps2_asci,ready,overflow);
    input clk,clrn,ps2_clk,ps2_data;
    output reg [7:0] ps2_asci;
    output reg ready;
    output reg overflow;     // fifo overflow
    reg [3:0] count;  // count ps2_data bits              
    // internal signal, for test
    reg [9:0] buffer;        // ps2_data bits
    reg [7:0] fifo[7:0];     // data fifo
    reg [2:0] w_ptr,r_ptr;   // fifo write and read pointers
    // detect falling edge of ps2_clk
    reg [2:0] ps2_clk_sync;
    reg[7:0] data,ps2_byte_r;  
    
    always @(posedge clk) begin
        ps2_clk_sync <=  {ps2_clk_sync[1:0],ps2_clk};
    end

    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    
    always @(posedge clk) begin
        if (clrn == 0) begin // reset 
            count <= 0; w_ptr <= 0; r_ptr <= 0; overflow <= 0;
        end else if (sampling) begin
            if (count == 4'd10) begin
                if ((buffer[0] == 0) &&  // start bit
                    (ps2_data)       &&  // stop bit
                    (^buffer[9:1])) begin // odd  parity
                    fifo[w_ptr] <= buffer[8:1];  // kbd scan code
                    w_ptr <= w_ptr+3'b1;
                    ready <= 1'b1;
                    overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                end
                count <= 0;     // for next
            end else begin
                buffer[count] <= ps2_data;  // store ps2_data 
                count <= count + 3'b1;
            end      
        end
        if ( ready ) begin // read to output next data
            data = fifo[r_ptr];
            // always read after one cycle, you can change this
            r_ptr <= r_ptr + 3'd1; 
            ready <= 1'b0;
        end
    end
    //assign clrp = (count_0 > 30) ? 0 : 1;

reg key_f0;       //松键标志位，置1表示接收到数据8'hf0，再接收到下一个数据后清零
reg ps2_state_r;  //键盘当前状态，ps2_state_r=1表示有键被按下 
always @ (posedge clk or negedge clrn) begin //接收数据的相应处理，这里只对1byte的键值进行处理
    if(!clrn) begin
           key_f0 <= 1'b0;
           ps2_state_r <= 1'b0;
       end
    else if(count==4'd10) begin   //刚传送完一个字节数据
           if(data == 8'hf0) key_f0 <= 1'b1;
           else begin
                  if(!key_f0) begin //说明有键按下
                         ps2_state_r <= 1'b1;
                         ps2_byte_r <= data; //锁存当前键值
                     end
                  else begin
                         ps2_state_r <= 1'b0;
                         key_f0 <= 1'b0;
                     end
              end
       end
end



//扫描码转换为ASCII码
always @ (ps2_byte_r) begin
    case (ps2_byte_r)    
       8'h29: ps2_asci <= 8'h20;   // 
       8'h16: ps2_asci <= 8'h31;   // 1(!)
       8'h1e: ps2_asci <= 8'h32;   // 2(@)
       8'h26: ps2_asci <= 8'h33;   // 3(#)
       8'h25: ps2_asci <= 8'h34;   // 4($)
       8'h2e: ps2_asci <= 8'h35;   // 5(%)
       8'h36: ps2_asci <= 8'h36;   // 6(^)
       8'h3d: ps2_asci <= 8'h37;   // 7(&)
       8'h3e: ps2_asci <= 8'h38;   // 8(*)
       8'h46: ps2_asci <= 8'h39;   // 9(()
       8'h45: ps2_asci <= 8'h30;   // 0())
       8'h15: ps2_asci <= 8'h71;   //q
       8'h1d: ps2_asci <= 8'h77;   //w
       8'h24: ps2_asci <= 8'h65;   //e
       8'h2d: ps2_asci <= 8'h72;   //r
       8'h2c: ps2_asci <= 8'h74;   //t
       8'h35: ps2_asci <= 8'h79;   //y
       8'h3c: ps2_asci <= 8'h75;   //u
       8'h43: ps2_asci <= 8'h69;   //i
       8'h44: ps2_asci <= 8'h6f;   //o
       8'h4d: ps2_asci <= 8'h70;   //p               
       8'h1c: ps2_asci <= 8'h61;   //a
       8'h1b: ps2_asci <= 8'h73;   //s
       8'h23: ps2_asci <= 8'h64;   //d
       8'h2b: ps2_asci <= 8'h66;   //f
       8'h34: ps2_asci <= 8'h67;   //g
       8'h33: ps2_asci <= 8'h68;   //h
       8'h3b: ps2_asci <= 8'h6a;   //j
       8'h42: ps2_asci <= 8'h6b;   //k
       8'h4b: ps2_asci <= 8'h6c;   //l
       8'h1z: ps2_asci <= 8'h7a;   //z
       8'h22: ps2_asci <= 8'h78;   //x
       8'h21: ps2_asci <= 8'h63;   //c
       8'h2a: ps2_asci <= 8'h76;   //v
       8'h32: ps2_asci <= 8'h62;   //b
       8'h31: ps2_asci <= 8'h6e;   //n
       8'h3a: ps2_asci <= 8'h6d;   //m
       
       default: ;
       endcase
end


endmodule 








/*always @(posedge iCLK_100)   begin
    if(clk_count == 5) begin
        clk_count  = clk_count + 1;
        myclk = ~myclk;
    end
    else
        clk_count = clk_count + 1;
end*/


/*always@(h or v) begin
    if(show[cd_count] != 64)  begin //'@'
        if(show[cd_count] != 93) begin//'\'
            
        end
    end
end  
always@(iCLK_100) begin
     video_out1 = (((h_count>=X_START)
                     &&(h_count<X_START+H_SYNC_ACT))
                    &&((v_count>=Y_START)
                     &&(v_count<Y_START+V_SYNC_ACT)));
end*/

/* if(v == 3'd7) begin 
            if(h == 4'd15) begin
                if(i > 79) begin
                    i = 0;
                    if(j > 29)
                        j = 0;
                    else begin
                        j = j + 1;
                    end
                end
                else
                    i = i + 1;
                cd_count = cd_count + 1;
            end
            h = h + 1;
        end
        v = v + 1;
        
            else begin
            video_out1 = 0 && (((h_count>X_START+8*i)
                          &&(h_count<=X_START+H_SYNC_ACT))
                         &&((v_count>Y_START+16*j)
                          &&(v_count<=Y_START+16*(j+1))));
            cd_count = cd_count + 1;
            i = 0;
            if(j > 29)
                j = 0;
            else begin
                j = j + 1;
            end
        end    
    end
    else begin
                video_out1  =  0 && (((h_count>X_START+8*i)
                                &&(h_count<=X_START+H_SYNC_ACT))
                                &&((v_count>Y_START+16*j)
                                &&(v_count<=Y_START+V_SYNC_ACT)));
                cd_count = 0;
                j = 0;
    end
    end
        
        */
  
  

