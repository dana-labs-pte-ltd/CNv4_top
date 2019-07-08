`timescale 1 ns / 1 ps // timescale for following modules


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
input  [9:0]    reg_address;
input           reg_write;
input  [31:0]   reg_wrdata;
output [31:0]   reg_rddata;

input  [ADDR_WIDTH+1:0]   mem_address;
input           mem_write;
input  [127:0]  mem_wrdata;
output [127:0]  mem_rddata;
output          sts_ml_finished;

wire mode_speedup     = 1'b0;

//reg   [127:0]   initial_ax0;
//reg   [127:0]   initial_bx0;
//reg   [127:0]   initial_bx1;

reg  [63:0]     h0  [0:13];

wire [127:0]    ml_cipher_StateIn ;
wire [127:0]    ml_cipher_Roundkey;
wire [127:0]    ml_cipher_StateOut;

wire [511:0]    ml_ram_wrdata;
wire [511:0]    ml_ram_rddata;
wire [ADDR_WIDTH-1:0]    ml_ram_addr;
wire            ml_ram_we;
wire            ml_ram_re;
reg             sm_ml_start;
wire [511:0]    ram_rddata;
wire            sts_ml_running;

reg  [127:0]  mem_rddata;

reg  [63:0]   random_rdata;
wire [6:0]    random_addr;

reg [63:0]    code0 [0:69];//save the op code 
reg [31:0]      reg_rdata;

parameter version = 32'h19070416;

//register output
always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    reg_rdata <= 0;
  end else begin
    if(reg_address == 10'h200) begin
        reg_rdata <= version;
    end else begin
        reg_rdata <= 32'h12345678;
    end
  end

//pc configuration
always @(posedge clk or negedge reset_n)
  if (!reset_n) begin
    sm_ml_start <= 0;
  end else begin
    if(reg_write && reg_address[9:8] == 2'b01 && reg_address[0] == 1'b0)
      h0[reg_address[4:1]][31:0] <= reg_wrdata;
    else if(reg_write && reg_address[9:8] == 2'b01 && reg_address[0] == 1'b1)
      h0[reg_address[4:1]][63:32] <= reg_wrdata;
    //start the crypto core
    if(reg_write && reg_address[9:8] == 2'b10 && reg_address[3:0] == 4'h0)
      sm_ml_start <= reg_wrdata[0];
    else begin
      sm_ml_start <= 1'b0;
    end
  end

//code save for test
always @(posedge clk)
  begin
    if(reg_write && reg_address[9:8] == 2'b00 && reg_address[0] == 1'b0)
      code0[reg_address[7:1]][31:0] <= reg_wrdata;
    else if(reg_write && reg_address[8:7] == 2'b00 && reg_address[0] == 1'b1)
      code0[reg_address[7:1]][63:32] <= reg_wrdata;
  end

//read the random reg
always @(posedge clk)
  begin
    random_rdata <= code0[random_addr];
  end

assign ml_ram_rddata = ram_rddata;
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
             .ram_rddata(ml_ram_rddata),
             // AES cipher round
             .cipher_StateIn(ml_cipher_StateIn),
             .cipher_Roundkey(ml_cipher_Roundkey),
             .cipher_StateOut(ml_cipher_StateOut),
             // input signals
            
             .h0_0(h0[0]),
             .h0_1(h0[1]),
             .h0_2(h0[2]),
             .h0_3(h0[3]),
             .h0_4(h0[4]),
             .h0_5(h0[5]),
             .h0_6(h0[6]),
             .h0_7(h0[7]),
             .h0_8(h0[8]),
             .h0_9(h0[9]),
             .h0_10(h0[10]),
             .h0_11(h0[11]),
             .h0_12(h0[12]),
             .h0_13(h0[13]),

             .random_addr(random_addr),
             .random_rdata(random_rdata),    
             //.in_ax0(initial_ax0),
             //.in_bx0(initial_bx0),
             //.in_bx1(initial_bx1),
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
