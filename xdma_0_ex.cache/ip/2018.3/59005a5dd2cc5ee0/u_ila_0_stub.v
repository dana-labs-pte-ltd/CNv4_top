// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Mon Jul 15 12:51:04 2019
// Host        : ubuntu running 64-bit Ubuntu 18.04.2 LTS
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ u_ila_0_stub.v
// Design      : u_ila_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu9p-fsgd2104-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2018.3" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[16:0],probe1[127:0],probe2[127:0],probe3[9:0],probe4[31:0],probe5[31:0],probe6[31:0],probe7[8:0],probe8[8:0],probe9[1:0],probe10[0:0],probe11[0:0],probe12[0:0],probe13[0:0],probe14[0:0],probe15[0:0],probe16[0:0],probe17[0:0]" */;
  input clk;
  input [16:0]probe0;
  input [127:0]probe1;
  input [127:0]probe2;
  input [9:0]probe3;
  input [31:0]probe4;
  input [31:0]probe5;
  input [31:0]probe6;
  input [8:0]probe7;
  input [8:0]probe8;
  input [1:0]probe9;
  input [0:0]probe10;
  input [0:0]probe11;
  input [0:0]probe12;
  input [0:0]probe13;
  input [0:0]probe14;
  input [0:0]probe15;
  input [0:0]probe16;
  input [0:0]probe17;
endmodule
