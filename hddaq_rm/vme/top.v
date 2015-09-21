`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Kenji Hosomi
// 
// Create Date:    18:47:20 12/13/2013 
// Design Name: 
// Module Name:    fpga
// Project Name:   GPIO-RM
// Target Devices: Xilinx Virtex XCV150_PQG240AFP1009_4C
// Tool versions:  Xilinx ISE WebPACK 10.1.03
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
//          1.00 - First release (K.Hosomi)
//          1.01 - Add J0 bus (K.Hosomi) 2014/12/05
//          2.00 - Add NIM IO register function, and Remove J0 bus (K.Hosomi) 2015/09/14
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
		SYSCLK,
		NIM_IN, NIM_OUT,
		ENC, SNC, TRIG1, TRIG2,
		BUSY_IN, BUSY_OUT, CLEAR, LOCK,
		RESERVE_IN, RESERVE_OUT,
		FOUT1,FOUT2,FOUT3,FOUT4,
		FIN1, FIN2, FIN3,FIN4,
		FRS,FWS,FA,FDTACK,
		DATA
    );

//================================================================================
//      Define I/O signals	 
//================================================================================
	
	//SYSTEM
	output FOUT1, FOUT2, FOUT3, FOUT4;
	input FIN1, FIN2, FIN3, FIN4;
	
	//FPGA <-> RM
	input [13:0] ENC;       // Event Number Counter from MTM
	input [9:0]  SNC;       // Spill Number Counter from MTM
	input TRIG1;            // Trigger 1
	input TRIG2;            // Trigger 2
	input BUSY_IN;          // Busy input from RM
	input CLEAR;            // Clear from MTM
	input LOCK;             // Lock
	input RESERVE_IN;       // Reserve1
	output RESERVE_OUT;     // Reserve2
	output BUSY_OUT;        // Busy output to MTM
	
	//DB2
	input [15:0] NIM_IN;
	output [15:0] NIM_OUT;
	
	//CPLD <-> FPGA
	input SYSCLK;           //32MHz base clock
	input FRS;
	input FWS;
	input [4:0] FA;
	output FDTACK;

	//FPGA <-> VME
	inout [31:0] DATA;

//==============================================================================
//          VME registers
//==============================================================================
	reg  [31:0] vme_reg0 =32'd0;  // ro, event number 
	reg  [31:0] vme_reg1 =32'd0;  // ro, spill number
	reg  [31:0] vme_reg2 =32'd0;  // ro, serial
	reg  [31:0] vme_reg3 =32'd0;  // rw, dummy register
	reg  [31:0] vme_reg4 =32'd0;  // ro, input register
   //reg  [31:0] vme_reg5 =32'd0;  // wo, reset input register
   reg  [31:0] vme_reg6 =32'd0;  // rw, level output
	reg  [31:0] vme_reg7 =32'd0;  // wo, pulse

   //VME signals
   reg [4:0] fab=5'd0;
	reg [1:0] fwsb_e=2'd0;
	reg [1:0] frsb_e=2'd0; 
  
//==============================================================================
//          signal assign
//==============================================================================
	assign FOUT1       = TRIG1;
	assign FOUT2       = TRIG2;
   assign FOUT3       = CLEAR;
	assign FOUT4       = RESERVE_IN;

   assign RESERVE_OUT = FIN4;
	assign BUSY_OUT    = BUSY_IN;
	
	wire strig2;
	async_input_sync sync_trig2(SYSCLK, TRIG2, strig2);

   //Event and Spill tag
	reg [1:0] trig2_e=2'd0;
	always @ (posedge SYSCLK) begin
		trig2_e <= {trig2_e[0],strig2};
	end
	
	always @ (posedge SYSCLK) begin
		if( trig2_e==2'b01 ) begin
			vme_reg0 <= {LOCK, 19'd0, ENC[13:2]};
			vme_reg1 <= {LOCK, 23'd0, SNC[7:0]};
		end
	end
	
	// NIM input register
   wire in1,in2,in3,in4,in5,in6,in7,in8,in9,in10,in11,in12,in13,in14,in15,in16;
	async_input_sync sync_in1(SYSCLK, NIM_IN[0], in1);
   async_input_sync sync_in2(SYSCLK, NIM_IN[1], in2);
	async_input_sync sync_in3(SYSCLK, NIM_IN[2], in3);
	async_input_sync sync_in4(SYSCLK, NIM_IN[3], in4);
	async_input_sync sync_in5(SYSCLK, NIM_IN[4], in5);
	async_input_sync sync_in6(SYSCLK, NIM_IN[5], in6);
	async_input_sync sync_in7(SYSCLK, NIM_IN[6], in7);
	async_input_sync sync_in8(SYSCLK, NIM_IN[7], in8);
	async_input_sync sync_in9(SYSCLK, NIM_IN[8], in9);
	async_input_sync sync_in10(SYSCLK, NIM_IN[9], in10);
	async_input_sync sync_in11(SYSCLK, NIM_IN[10], in11);
	async_input_sync sync_in12(SYSCLK, NIM_IN[11], in12);
	async_input_sync sync_in13(SYSCLK, NIM_IN[12], in13);
	async_input_sync sync_in14(SYSCLK, NIM_IN[13], in14);
	async_input_sync sync_in15(SYSCLK, NIM_IN[14], in15);
	async_input_sync sync_in16(SYSCLK, NIM_IN[15], in16);
	
	always @ (posedge SYSCLK) begin
	   if( fwsb_e==2'b01 && fab==5'd5 ) vme_reg4 <= 32'd0;
		else vme_reg4 <= vme_reg4 | {16'd0,in16,in15,in14,in13,in12,in11,in10,in9,in8,in7,in6,in5,in4,in3,in2,in1};
	end

   // NIM output (level or pulse)
   assign NIM_OUT = vme_reg6[15:0] | vme_reg7[15:0];

//==============================================================================
//          VME cycle
//==============================================================================
	
	wire sfwsb, sfrsb;
	async_input_sync sync_fws(SYSCLK, FWS, sfwsb);
	async_input_sync sync_frs(SYSCLK, FRS, sfrsb);
	
	always @ (posedge SYSCLK) begin
		fab    <= FA;
		fwsb_e <= {fwsb_e[0],sfwsb};
		frsb_e <= {frsb_e[0],sfrsb};
	end
	
	//VME Write cycle
	always @ ( posedge SYSCLK ) begin
		if( fwsb_e==2'b01 ) begin
			if(fab==5'd3) vme_reg3 <= DATA;
			else if(fab==5'd6) vme_reg6 <= DATA;
			else if(fab==5'd7) vme_reg7 <= DATA;
		end
		else begin
			vme_reg7 <= 32'd0;
		end
	end

	//VME Read cycle
	reg [31:0] out_data=32'd0;
	always @ ( posedge SYSCLK ) begin
		if( frsb_e==2'b01 ) begin
			case ( fab )
				5'd0  : out_data <= vme_reg0;
				5'd1  : out_data <= vme_reg1;
				5'd2  : begin
				        vme_reg2 <= vme_reg2 + 32'd1;
				        out_data <= vme_reg2;
						  end
				5'd3  : out_data <= vme_reg3;
				5'd4  : out_data <= vme_reg4;
				5'd6  : out_data <= vme_reg6;
				default: out_data <= 32'hFEFEFEFE;
			endcase
		end
	end

	assign DATA = (frsb_e[1]==1'b1)? out_data : 32'bz;

	//Data Acknowledgement
	reg FDTACK=1'b1;
	always @ ( posedge SYSCLK ) begin
		if( frsb_e[1]==1'b1 )      FDTACK <= 1'b0;
		else if( fwsb_e[1]==1'b1 ) FDTACK <= 1'b0;
		else               			FDTACK <= 1'b1;
	end
	
endmodule

module async_input_sync(
   input clk,
   (* TIG="TRUE", IOB="FALSE" *) input async_in,
   output reg sync_out
);

   (* ASYNC_REG="TRUE", SHIFT_EXTRACT="NO", HBLKNM="sync_reg" *) reg [1:0] sreg;                                                                           
   always @(posedge clk) begin
     sync_out <= sreg[1];
     sreg <= {sreg[0], async_in};
   end

endmodule
			