`timescale 1 ns / 1 ns // timescale for following modules

module cn_ml (
   clk,
   reset_n,
   
   //start memory hard loop
   ctrl_start,
   sts_running,
   sts_finished,

   //Table RAM
   ram_rden,
   ram_wren,
   ram_wrdata,
   ram_addr,
   ram_rddata,

   //AES cipher round
   cipher_StateIn,
   cipher_Roundkey,
   cipher_StateOut,

   //Parameters from last stage
   in_ax0,
   in_bx0,
   in_bx1,

   //Test only speedup simulation
   mode_speedup
   );

`include "cn.vh"

parameter ADDR_WIDTH = 15;//memory size 2Mbyte 16byte allign

//  ctrl interface
input               clk	            ;
input               reset_n         ;
input               ctrl_start		;

//  sts interface
output              sts_running		;
output              sts_finished	;

// Table RAM
output  					  ram_rden      ;
output  					  ram_wren      ;
output  [511:0]     ram_wrdata    ;
output  [ADDR_WIDTH-1:0] 	ram_addr  ;
input   [511:0]     ram_rddata    ;

// AES cipher round
output 	[127:0]     cipher_StateIn	;
output 	[127:0]     cipher_Roundkey	;
input  	[127:0]     cipher_StateOut	;

// memory map interface from last stage
input   [127:0]     in_ax0	        ;
input   [127:0]     in_bx0         ;
input   [127:0]     in_bx1         ;

input               mode_speedup	;

//  specify the multiplier delay in clock cycles
localparam integer    MULTIPLIER_DELAY      = 1; // 1 or 2
localparam integer    ELIMINATE_WAIT_STATE 	= 1; // 0 or 1
initial $display("MULTIPLIER_DELAY = %0d", MULTIPLIER_DELAY);
initial $display("ELIMINATE_WAIT_STATE = %0d", ELIMINATE_WAIT_STATE);

//  RAM size definition
localparam integer BYTE_ADDRESS_BITS = ADDR_WIDTH + 4;

//  signals declaration
//  input signals
wire    [63:0]          idx0_stage1 ;
reg     [63:0]          al0  ;
reg     [63:0]          ah0  ;

reg     [127:0]         ax0  ;
reg     [127:0]         bx0  ;
reg     [127:0]         bx1  ;


reg     [63:0]        cl;
wire    [63:0]        ch          ;
reg     [127:0]       cx          ;
wire    [63:0]        hi,lo       ;

wire    [63:0]        idx0_stage2 ;

reg     [127:0]       chk1        ;
reg     [127:0]       chk2        ;
reg     [127:0]       chk3        ;

//data from ram
reg     [127:0]       cx_before_aes ;
wire     [127:0]       cx_after_aes  ;

reg     [127:0]       chk1_add_bx0_stage1;
reg     [127:0]       chk2_add_ax0_stage1;
reg     [127:0]       chk3_add_bx1_stage1;
reg     [127:0]       chk123_xor_cx_stage1;//update cx

reg     [127:0]       chk1_add_bx0_stage2;
reg     [127:0]       chk2_add_ax0_stage2;
reg     [127:0]       chk3_add_bx1_stage2;
reg     [127:0]       chk123_xor_cx_stage2;


//define the state parameter
parameter     phase_idle                  = 8'h1;
parameter     phase_0_read_stage_1        = 8'h2;
parameter     phase_1_aes_stage_1         = 8'h4;
parameter     phase_2_write_stage_1       = 8'h8;
parameter     phase_3_read_stage_2        = 8'h10;
parameter     phase_4_randommath_stage_2  = 8'h20;
parameter     phase_5_mul_stage_2         = 8'h40;
parameter     phase_6_write_stage_2       = 8'h80;

reg     [7:0]     cs_state          ;
reg     [7:0]     ns_state          ;


//  internal signals for ack
reg     					phase_0_read_ack	;
reg     					phase_3_read_ack	;
reg     					phase_2_write_ack	;
reg     					phase_6_write_ack	;
reg               phase_4_randommath_ack;
reg               phase_5_mul_ack   ;

reg     					phase_0_read_r0	;
reg     					phase_3_read_r0	;
reg     					phase_2_write_r0	;
reg     					phase_6_write_r0	;
reg               phase_4_randommath_r0;
reg               phase_5_mul_r0   ;

reg     					phase_0_read_r1	;
reg     					phase_3_read_r1	;
reg     					phase_2_write_r1	;
reg     					phase_6_write_r1	;
reg               phase_4_randommath_r1;
reg               phase_5_mul_r1   ;

reg     					phase_0_read_r2	;
reg     					phase_3_read_r2	;
reg     					phase_2_write_r2	;
reg     					phase_6_write_r2	;
reg               phase_4_randommath_r2;
reg               phase_5_mul_r2   ;

reg     					phase_0_read_r3	;
reg     					phase_3_read_r3	;
reg     					phase_2_write_r3	;
reg     					phase_6_write_r3	;
reg               phase_4_randommath_r3;
reg               phase_5_mul_r3   ;

reg     					phase_0_read_r4	;
reg     					phase_3_read_r4	;
reg     					phase_2_write_r4	;
reg     					phase_6_write_r4	;
reg               phase_4_randommath_r4;
reg               phase_5_mul_r4   ;


wire    [127:0] 			aes_async_v	;
reg     [127:0] 			aes				  ;//aes output
wire    [127:0] 			product			;
reg     [127:0] 			ram_2nd_wr_data	;
reg     [127:0] 			ram_1st_wr_data	;
reg     [ADDR_WIDTH - 1:0] 	ram_1st_wr_addr	;//1st write address
reg     [ADDR_WIDTH - 1:0] 	ram_2nd_wr_addr	;//2nd write address
reg     [ADDR_WIDTH - 1:0] 	ram_1st_rd_addr	;//1st read address
reg     [ADDR_WIDTH - 1:0] 	ram_2nd_rd_addr	;//2nd read address

//  on chip RAM signals
reg     [ADDR_WIDTH - 1:0] 	ram_addr		;//address bus to the internal ram
reg     [1:0]               ram_addr_lowbit ;

//  word addressing
reg      [511:0] 			ram_wrdata      ;
reg                   ram_wren        ;

//  iteration counter 524288 loop
reg     [19:0] 				iteration		    ;

//  control signals
reg    						    finished      ;
reg    						    sts_finished  ;
reg    						    sts_running	  ;
reg    						    start         ;
reg                   last_loop     ;

localparam  speedup_mask = (1 << (ADDR_WIDTH-CFG_SPEEDUP_IL_LOG2)) - 1;//地址mask

//byte address exchange,取17bit地址
function [ADDR_WIDTH-1:0] to_addr;
input   [127:0] data;
begin
  to_addr = data >> 6;
//  if (mode_speedup)
//    to_addr = to_addr & speedup_mask;
end
endfunction

//byte address exchange,取低位地址
function [1:0] to_addr_lowbit;
input   [127:0] data;
begin
  to_addr_lowbit = data >> 4;
//  if (mode_speedup)
//    to_addr = to_addr & speedup_mask;
end
endfunction

//字节变换
function [127:0] byteswap;
input [127:0] indata;
reg [127:0] data;
begin
  byteswap = 0; // eliminate warnings
  data = indata;
  repeat (16) begin
    byteswap = {byteswap, data[7:0]};
    data = data >> 8;
  end
end
endfunction

  //========================================================================================
  //Main state machine
  //========================================================================================
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    cs_state <= phase_idle;
  end else begin
    cs_state <= ns_state;
  end

  //state transfer
  always @ (*)
  begin
    ns_state = cs_state;
    case(cs_state)
      phase_idle:begin
        if(ctrl_start)begin
          ns_state = phase_0_read_stage_1;
        end
      end
      
      phase_0_read_stage_1:begin
        if(phase_0_read_ack)begin
          ns_state = phase_1_aes_stage_1;
        end
      end
      
      phase_1_aes_stage_1:begin
        ns_state = phase_2_write_stage_1;
      end
      
      phase_2_write_stage_1:begin
        if(phase_2_write_ack) begin
          ns_state = phase_3_read_stage_2;
        end
      end
      
      phase_3_read_stage_2:begin
        if(phase_3_read_ack)begin
          ns_state = phase_4_randommath_stage_2;
        end
      end
      
      phase_4_randommath_stage_2:begin
        if(phase_4_randommath_ack)begin
          ns_state = phase_5_mul_stage_2;
        end
      end
      
      phase_5_mul_stage_2:begin
        if(phase_5_mul_ack)begin
          ns_state = phase_6_write_stage_2;
        end
      end
      
      phase_6_write_stage_2:begin
        if(phase_6_write_ack)begin
          if(last_loop)begin
            ns_state = phase_idle;
          end else begin
            ns_state = phase_0_read_stage_1;
          end
        end
      end
      
    endcase
  end

  //status
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    sts_finished <= 1'b0;
    sts_running <= 1'b0;
  end else begin
    sts_finished <= finished;
    if(cs_state == phase_idle && ns_state == phase_idle )begin
      sts_running <= 1'b0;
    end else begin
      sts_running <= 1'b1;
    end
  end
  
  
  //ack
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    phase_0_read_ack <= 1'b0;
    phase_0_read_r0 <= 1'b0;
  end else begin
    phase_0_read_ack <= phase_0_read_r0;
    if(cs_state != phase_0_read_stage_1 && ns_state == phase_0_read_stage_1)begin
      phase_0_read_r0 <= 1'b1;
    end else begin
      phase_0_read_r0 <= 1'b0;
    end
  end

  //ack
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    phase_3_read_ack <= 1'b0;
    phase_3_read_r0 <= 1'b0;
  end else begin
    phase_3_read_ack <= phase_3_read_r0;
    if(cs_state != phase_3_read_stage_2 && ns_state == phase_3_read_stage_2)begin
      phase_3_read_r0 <= 1'b1;
    end else begin
      phase_3_read_r0 <= 1'b0;
    end
  end
  
    //ack
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    phase_2_write_ack <= 1'b0;
  end else begin
    phase_2_write_ack <= phase_2_write_r0;
    if(cs_state != phase_2_write_stage_1 && ns_state == phase_2_write_stage_1)begin
      phase_2_write_ack <= 1'b1;
    end else begin
      phase_2_write_ack <= 1'b0;
    end
  end
  
  //ack  
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    phase_4_randommath_ack <= 1'b0;
    phase_4_randommath_r0 <= 1'b0;
    phase_4_randommath_r1 <= 1'b0;
    phase_4_randommath_r2 <= 1'b0;
  end else begin
    phase_4_randommath_r1 <= phase_4_randommath_r0;
    phase_4_randommath_r2 <= phase_4_randommath_r1;
    phase_4_randommath_ack <= phase_4_randommath_r2;
    if(cs_state != phase_4_randommath_stage_2 && ns_state == phase_4_randommath_stage_2)begin
      phase_4_randommath_r0 <= 1'b1;
    end else begin
      phase_4_randommath_r0 <= 1'b0;
    end
  end

  //ack  
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
     phase_5_mul_ack <= 1'b0;
     phase_5_mul_r0 <= 1'b0;
  end else begin
    phase_5_mul_ack <= phase_5_mul_r0;
    if(cs_state !=  phase_5_mul_stage_2 && ns_state ==  phase_5_mul_stage_2)begin
       phase_5_mul_r0 <= 1'b1;
    end else begin
       phase_5_mul_r0 <= 1'b0;
    end
  end
  
    //ack  
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
     phase_6_write_ack <= 1'b0;
     // phase_6_write_r0 <= 1'b0;
  end else begin
     // phase_6_write_ack <=  phase_6_write_r0;
    if(cs_state !=  phase_6_write_stage_2 && ns_state ==  phase_6_write_stage_2)begin
       phase_6_write_ack <= 1'b1;
    end else begin
       phase_6_write_ack <= 1'b0;
    end
  end

  //========================================================================================
  //  Table RAM -- 128K words
  //========================================================================================
  //write enable
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    ram_wren <= 1'b0;
  end else begin
    if(cs_state == phase_1_aes_stage_1 && ns_state == phase_2_write_stage_1)begin
      ram_wren <= 1'b1;
    end else if(cs_state == phase_5_mul_stage_2 && ns_state == phase_6_write_stage_2) begin
      ram_wren <= 1'b1;
    end else begin 
      ram_wren <= 1'b0;
    end
  end
  
  //ram address
   always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    ram_addr <= 0;
    ram_addr_lowbit <= 0;
  end else begin
    if(cs_state == phase_idle && ns_state == phase_0_read_stage_1)begin//start iteration
        ram_addr <= to_addr(in_ax0[63:0]);
        ram_addr_lowbit <= to_addr_lowbit(in_ax0[63:0]);
    end else if(cs_state == phase_6_write_stage_2 && ns_state == phase_0_read_stage_1) begin
        ram_addr <= to_addr(al0 ^ cl);
        ram_addr_lowbit <= to_addr_lowbit(al0 ^ cl);
    end else if(ns_state == phase_3_read_stage_2) begin
        ram_addr <= to_addr(cx[63:0]);
        ram_addr_lowbit <= to_addr_lowbit(cx[63:0]);
    end
  end
  
  
  // ram address
  // always @(posedge clk or negedge reset_n)
  // if (!reset_n) begin
    // ram_addr <= 0;
  // end else begin
    // if(ns_state == phase_0_read_stage_1)begin
      // ram_addr <= to_addr(idx0_stage1);
    // end else if(ns_state == phase_3_read_stage_2) begin
      // ram_addr <= to_addr(idx0_stage2);
    // end
  // end
  
  //---------------------------------------------------------------------------
  //    chk12xorcx chk3xorb1 chk1xorb0 chk2xora0
  //addr   0x00       0x01     0x10       0x11
  //0x00   0x00       0x01     0x10       0x11
  //0x01   0x01       0x00     0x11       0x10 
  //0x10   0x10       0x11     0x00       0x01
  //0x11   0x11       0x10     0x01       0x00
  //---------------------------------------------------------------------------
  //write data
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    ram_wrdata <= 0;
  end else begin
    if(ns_state == phase_2_write_stage_1) begin
      case(ram_addr_lowbit[1:0])
        2'b00:begin
          ram_wrdata <= {chk2_add_ax0_stage1,chk1_add_bx0_stage1,chk3_add_bx1_stage1,chk123_xor_cx_stage1};
        end
        
        2'b01:begin
          ram_wrdata <= {chk1_add_bx0_stage1,chk2_add_ax0_stage1,chk123_xor_cx_stage1,chk3_add_bx1_stage1};
        end
        
        2'b10:begin
          ram_wrdata <= {chk3_add_bx1_stage1,chk123_xor_cx_stage1,chk2_add_ax0_stage1,chk1_add_bx0_stage1};
        end
        
        2'b11:begin
          ram_wrdata <= {chk123_xor_cx_stage1,chk3_add_bx1_stage1,chk1_add_bx0_stage1,chk2_add_ax0_stage1};
        end
      endcase
    end else begin
      case(ram_addr_lowbit[1:0])
        2'b00:begin
          ram_wrdata <= {chk2_add_ax0_stage2,chk1_add_bx0_stage2,chk3_add_bx1_stage2,chk123_xor_cx_stage2};
        end
        
        2'b01:begin
          ram_wrdata <= {chk1_add_bx0_stage2,chk2_add_ax0_stage2,chk123_xor_cx_stage2,chk3_add_bx1_stage2};
        end
        
        2'b10:begin
          ram_wrdata <= {chk3_add_bx1_stage2,chk123_xor_cx_stage2,chk2_add_ax0_stage2,chk1_add_bx0_stage2};
        end
        
        2'b11:begin
          ram_wrdata <= {chk123_xor_cx_stage2,chk3_add_bx1_stage2,chk1_add_bx0_stage2,chk2_add_ax0_stage2};
        end
      endcase
    end
  end
 
 
  //write back data
  always@(*)
  begin
    chk123_xor_cx_stage1 = cx_after_aes ^ chk1 ^ chk2 ^ chk3 ^ bx0;//cx xor chk1 xor ch2 xor ch3 xor bx0
    chk1_add_bx0_stage1 = {chk1[127:64] + bx0[127:64],chk1[63:0] + bx0[63:0]};
    chk2_add_ax0_stage1 = {chk2[127:64] + ax0[127:64],chk2[63:0] + ax0[63:0]};
    chk3_add_bx1_stage1 = {chk3[127:64] + bx1[127:64],chk3[63:0] + bx1[63:0]};
    chk123_xor_cx_stage2 = {ah0+lo,al0+hi};
    chk1_add_bx0_stage2 = chk1_add_bx0_stage1;
    chk2_add_ax0_stage2 = chk2_add_ax0_stage1;
    chk3_add_bx1_stage2 = chk3_add_bx1_stage1;
//    cx = cx_after_aes ^ chk1 ^ chk2 ^ chk3;
  end

  //---------------------------------------------------------------------------
  //   0x1 0x2 0x3
  //00 01  10  11
  //01 00  11  10 
  //10 11  00  01
  //11 10  01  00
  //---------------------------------------------------------------------------
  //update the ram output
    //chk1 chk2 chk3 cx and cl ch
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    chk1 <= 0;
    chk2 <= 0;
    chk3 <= 0;
    cx_before_aes <= 0;
  end else begin
    if(phase_0_read_ack | phase_3_read_ack)begin
      case(ram_addr_lowbit[1:0])
        2'b00:begin
          cx_before_aes <= ram_rddata[127:0];
          chk1 <= ram_rddata[255:128];
          chk2 <= ram_rddata[128*2+127:128*2];
          chk3 <= ram_rddata[128*3+127:128*3];   
        end
        
        2'b01:begin
          chk1 <= ram_rddata[127:0];
          cx_before_aes <= ram_rddata[128+127:128];
          chk3 <= ram_rddata[128*2+127:128*2];
          chk2 <= ram_rddata[128*3+127:128*3];   
        end
        
        2'b10:begin
          chk2 <= ram_rddata[127:0];
          chk3 <= ram_rddata[128+127:128];
          cx_before_aes <= ram_rddata[128*2+127:128*2];
          chk1 <= ram_rddata[128*3+127:128*3];   
        end
        
        2'b11:begin
          chk3 <= ram_rddata[127:0];
          chk2 <= ram_rddata[128+127:128];
          chk1 <= ram_rddata[128*2+127:128*2];
          cx_before_aes <= ram_rddata[128*3+127:128*3];
        end
        
      endcase
    end
  end
   
  //al0,ah0,ax0,bx0,bx1,bx1 update
  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    al0 <= 0;
    ah0 <= 0;
    ax0 <= 0;
    bx0 <= 0;
    bx1 <= 0;
  end else begin
    if(cs_state == phase_idle && ns_state == phase_0_read_stage_1)begin//start iteration
      al0 <= in_ax0[63:0];
      ah0 <= in_ax0[127:64];
      ax0 <= in_ax0;
      bx0 <= in_bx0;
      bx1 <= in_bx1;
    end else if(phase_4_randommath_ack) begin
      al0 <= al0 + 1;
      ah0 <= ah0 + 1;
    end else if(phase_5_mul_ack) begin
      al0 <= al0 + hi;
      ah0 <= ah0 + lo;
    end else if(cs_state == phase_6_write_stage_2 && ns_state == phase_0_read_stage_1) begin
      al0 <= al0 ^ cl;
      ah0 <= ah0 ^ ch;
      ax0 <= {ah0 ^ ch,al0 ^ cl};
      bx0 <= cx ^ chk1 ^ chk2 ^ chk3;
      bx1 <= bx0;
    end
  end
  
    always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    cl <= 0;
  end else begin
    if(phase_4_randommath_ack) begin
      cl <= cx_before_aes[63:0] + 1;
    end
  end
  
  // idx generation
  // assign idx0_stage1 = al0;
  // assign idx0_stage2 = cx[63:0];
  //idx update
   always @(posedge clk or negedge reset_n)
   if (!reset_n) begin
     cx <= 0;
   end else begin
     if(cs_state == phase_1_aes_stage_1) begin
       cx <= cx_after_aes ^ chk1 ^ chk2 ^ chk3 ;
     end
   end

  assign cipher_StateIn = cx_before_aes;
  assign cipher_Roundkey = byteswap(ax0);
  assign cx_after_aes = cipher_StateOut;


  //========================================================================================
  //  multiplier
  //========================================================================================
 // assign {hi,lo} = idx0_stage2[63:0] * cl;
  
  mult_64wx64w_unsigned mult_64wx64w_inst(
      .CLK(clk), 
      .A(cx[63:0]), 
      .B(cl), 
      .P({hi,lo})
      );
  
  assign ch = cx_before_aes[127:64];

  //  Iteration counter，524288计数器
  always @(negedge reset_n or posedge clk)
    if (!reset_n)
      iteration <= 0;
    else if (ns_state == phase_1_aes_stage_1 && cs_state == phase_0_read_stage_1) begin
      iteration <= iteration + 1;
    end else if (cs_state == phase_idle)begin
      iteration <= 0;
    end

  // Run/finish
  parameter last_iteration_full    = (20'b1 << 19) - 1;//524288 loop only for simulation
  parameter last_iteration_speedup = (20'b1 << (19 - CFG_SPEEDUP_ML_LOG2)) - 1;//speed loop only for simulation

  wire [19:0] last_iteration = mode_speedup ? last_iteration_speedup : last_iteration_full;

  always @(posedge clk or negedge reset_n)
     if (!reset_n) begin
        last_loop <= 0;
     end else begin
        if (iteration >= last_iteration) begin
           last_loop <= 1'b1;
        end else
           last_loop <= 1'b0;
     end
     
    always @(posedge clk or negedge reset_n)
     if (!reset_n) begin
        finished <= 0;
     end else begin
        if (last_loop && cs_state == phase_6_write_stage_2) begin
           finished <= 1'b1;
        end else
           finished <= 1'b0;
     end

endmodule // module cn_ml
