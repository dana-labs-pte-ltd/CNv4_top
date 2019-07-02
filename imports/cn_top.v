`timescale 1 ns / 1 ns // timescale for following modules


module cn_top (
   clk,
   reset_n,
   
   sts_ml_finished,
   //avalon mem slave interface
   mem_address,
   mem_write,
   mem_wrdata,
   mem_rddata,
   
   //avalon reg slave interface
   reg_address,
   reg_write,
   reg_wrdata,
   reg_rddata
   );

`include "cn.vh"

parameter ADDR_WIDTH = 15;
parameter UNROLL = 2;

initial $display("ADDR_WIDTH = %0d", ADDR_WIDTH);
initial $display("UNROLL = %0d", UNROLL);

input      clk;
input      reset_n;

// Buffer interface
// input          reg_cs;
input  [7:0]   reg_address;
input          reg_write;
input  [31:0] reg_wrdata;
output [31:0] reg_rddata;

input  [ADDR_WIDTH+1:0]   mem_address;
input          mem_write;
input  [127:0] mem_wrdata;
output [127:0] mem_rddata;
output         sts_ml_finished;

wire mode_speedup     = 1'b0;

reg   [127:0] initial_ax0;
reg   [127:0] initial_bx0;
reg   [127:0] initial_bx1;


wire [127:0] ml_cipher_StateIn ;
wire [127:0] ml_cipher_Roundkey;
wire [127:0] ml_cipher_StateOut;

wire [511:0]  ml_ram_wrdata;
wire [511:0]  ml_ram_rddata;
wire [ADDR_WIDTH-1:0]    ml_ram_addr;
wire          ml_ram_we;
wire          ml_ram_re;
reg           sm_ml_start;
wire [511:0]  ram_rddata;
wire          sts_ml_running;

reg  [127:0]  mem_rddata;

  always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    initial_ax0 <= 128'h0;
    initial_bx0 <= 128'h0;
    initial_bx1 <= 128'h0;
    sm_ml_start <= 0;
  end else begin
    if(reg_write && reg_address == 9'h0)
      initial_ax0[31:0] <= reg_wrdata;
    if(reg_write && reg_address == 9'h1)
      initial_ax0[63:32] <= reg_wrdata;
    if(reg_write && reg_address == 9'h2)
      initial_ax0[95:64] <= reg_wrdata;
    if(reg_write && reg_address == 9'h3)
      initial_ax0[127:96] <= reg_wrdata;
    if(reg_write && reg_address == 9'h4)
      initial_bx0[31:0] <= reg_wrdata;
    if(reg_write && reg_address == 9'h5)
      initial_bx0[63:32] <= reg_wrdata;
    if(reg_write && reg_address == 9'h6)
      initial_bx0[95:64] <= reg_wrdata;
    if(reg_write && reg_address == 9'h7)
      initial_bx0[127:96] <= reg_wrdata;
    if(reg_write && reg_address == 9'h8)
      initial_bx1[31:0] <= reg_wrdata;
    if(reg_write && reg_address == 9'h9)
      initial_bx1[63:32] <= reg_wrdata;
    if(reg_write && reg_address == 9'ha)
      initial_bx1[95:64] <= reg_wrdata;
    if(reg_write && reg_address == 9'hb)
      initial_bx1[127:96] <= reg_wrdata;
    if(reg_write && reg_address == 9'hc)
      sm_ml_start <= reg_wrdata[0];
    else begin
      sm_ml_start <= 1'b0;
    end
  end

//assign mem_rddata = ram_rddata;
//memory loop
cn_ml #(.ADDR_WIDTH(ADDR_WIDTH)) cn_ml_inst (
  .clk(clk),
  .reset_n(reset_n),
  // ctrl interface
  .ctrl_start(sm_ml_start),
  // sts interface
  .sts_running(sts_ml_running),
  .sts_finished(sts_ml_finished),
  // Table RAM
  .ram_rden(ml_ram_re),
  .ram_wren(ml_ram_we),
  .ram_wrdata(ml_ram_wrdata),
  .ram_addr(ml_ram_addr),
  .ram_rddata(ram_rddata),
  // AES cipher round
  .cipher_StateIn(ml_cipher_StateIn),
  .cipher_Roundkey(ml_cipher_Roundkey),
  .cipher_StateOut(ml_cipher_StateOut),
  // input signals
  .in_ax0(initial_ax0),
  .in_bx0(initial_bx0),
  .in_bx1(initial_bx1),
  // Test modes
  .mode_speedup(mode_speedup)
  );

// -----------------------------------------------------------------------------------
// AES combinatorial
// -----------------------------------------------------------------------------------
cipherRound_mod aes_inst_ml (
  .last_cipher_iteration(1'b0),
  .StateIn( ml_cipher_StateIn),
  .Roundkey(ml_cipher_Roundkey),
  .StateOut(ml_cipher_StateOut));

// -----------------------------------------------------------------------------------
// Table RAM dualport
// -----------------------------------------------------------------------------------
wire        mem_write_0;
wire        mem_write_1;
wire        mem_write_2;
wire        mem_write_3;
assign      mem_write_0 = (mem_address[1:0]==2'b00)?mem_write:1'b0;
assign      mem_write_1 = (mem_address[1:0]==2'b01)?mem_write:1'b0;
assign      mem_write_2 = (mem_address[1:0]==2'b10)?mem_write:1'b0;
assign      mem_write_3 = (mem_address[1:0]==2'b11)?mem_write:1'b0;

always@(*)
begin
    case(mem_address[1:0])
    2'b00:begin
        mem_rddata = ram_rddata[127:0];
    end

    2'b00:begin
        mem_rddata = ram_rddata[128+127:128];
    end

    2'b00:begin
        mem_rddata = ram_rddata[128*2+127:128*2];
    end

    2'b00:begin
        mem_rddata = ram_rddata[128*3+127:128*3];
    end

    default:mem_rddata = ram_rddata[127:0];
    endcase
end

blk_mem_32768D128W cryptonightR_ram_inst_0(
    .clka(clk), 
    .ena(1'b1),
    .wea(sts_ml_running ? ml_ram_we : mem_write_0), 
    .addra(sts_ml_running ? ml_ram_addr : mem_address[16:2]), 
    .dina(sts_ml_running ? ml_ram_wrdata[127:0] : mem_wrdata), 
    .douta(ram_rddata[127:0])
    );

blk_mem_32768D128W cryptonightR_ram_inst_1(
    .clka(clk), 
    .ena(1'b1),
    .wea(sts_ml_running ? ml_ram_we : mem_write_1), 
    .addra(sts_ml_running ? ml_ram_addr : mem_address[16:2]), 
    .dina(sts_ml_running ? ml_ram_wrdata[128+127:128] : mem_wrdata), 
    .douta(ram_rddata[128+127:128])
    );

blk_mem_32768D128W cryptonightR_ram_inst_2(
    .clka(clk), 
    .ena(1'b1),
    .wea(sts_ml_running ? ml_ram_we : mem_write_2), 
    .addra(sts_ml_running ? ml_ram_addr : mem_address[16:2]), 
    .dina(sts_ml_running ? ml_ram_wrdata[128*2+127:128*2] : mem_wrdata), 
    .douta(ram_rddata[128*2+127:128*2])
    );

blk_mem_32768D128W cryptonightR_ram_inst_3(
    .clka(clk), 
    .ena(1'b1),
    .wea(sts_ml_running ? ml_ram_we : mem_write_3), 
    .addra(sts_ml_running ? ml_ram_addr : mem_address[16:2]), 
    .dina(sts_ml_running ? ml_ram_wrdata[128*3+127:128*3] : mem_wrdata), 
    .douta(ram_rddata[128*3+127:128*3])
    );

endmodule // module cn_top
