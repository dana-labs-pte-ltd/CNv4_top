// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Wed Jun 12 16:07:58 2019
// Host        : IT-20181130VVYG running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               e:/work/fpga_prj/cryptonight/test_prj/test.srcs/sources_1/ip/mult_64wx64w_unsigned/mult_64wx64w_unsigned_stub.v
// Design      : mult_64wx64w_unsigned
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu9p-fsgd2104-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_14,Vivado 2018.3" *)
module mult_64wx64w_unsigned(CLK, A, B, P)
/* synthesis syn_black_box black_box_pad_pin="CLK,A[63:0],B[63:0],P[127:0]" */;
  input CLK;
  input [63:0]A;
  input [63:0]B;
  output [127:0]P;
endmodule
