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
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
		SYSCLK,
		ENC, SNC, TRIG1, TRIG2,
		BUSY_IN, BUSY_OUT, CLEAR, LOCK,
		RESERVE_IN, RESERVE_OUT,
		BUSY_J0, WARN_J0, CLK_J0, TRIG_J0,
		STAG_J0, ETAG_J0,
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
	
	//FPGA <-> J0-bus
	input  BUSY_J0;         // Busy from J0 (C1)
	input  WARN_J0;         // Reserve from J0 (C2)
	output CLK_J0;          // Clock to J0 (S1)
	output TRIG_J0;         // Trigger to J0 (S2)
	output [1:0] STAG_J0;   // Spill Tag to J0 (S3,S4)   
	output [2:0] ETAG_J0;   // Event Tag to J0 (S5,S6,S7)
	
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
	reg  [31:0] vme_reg0 =32'd0;
	reg  [31:0] vme_reg1 =32'd0;
	reg  [31:0] vme_reg2 =32'd0;
	reg  [31:0] vme_reg3 =32'd0;

//==============================================================================
//          signal assign
//==============================================================================
	assign FOUT1       = TRIG1;
	assign FOUT2       = TRIG2;
   assign FOUT3       = CLEAR;
	assign FOUT4       = RESERVE_IN;

   assign RESERVE_OUT = FIN4;
	assign BUSY_OUT    = BUSY_IN | ~BUSY_J0;
	
	wire strig2;
	async_input_sync sync1(SYSCLK, TRIG2, strig2);

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
	
	//J0 bus
	assign CLK_J0      = SYSCLK;
	assign TRIG_J0     = TRIG2;
   assign STAG_J0     = SNC[1:0];
	assign ETAG_J0     = ENC[4:2];

//==============================================================================
//          VME cycle
//==============================================================================
	
	wire sfwsb, sfrsb;
	async_input_sync sync2(SYSCLK, FWS, sfwsb);
	async_input_sync sync3(SYSCLK, FRS, sfrsb);
	
	reg [4:0] fab=5'd0;
	reg [1:0] fwsb_e=2'd0;
	reg [1:0] frsb_e=2'd0;
	
	always @ (posedge SYSCLK) begin
		fab    <= FA;
		fwsb_e <= {fwsb_e[0],sfwsb};
		frsb_e <= {frsb_e[0],sfrsb};
	end
	
	//VME Write cycle
	always @ ( posedge SYSCLK ) begin
		if( fwsb_e==2'b01 ) begin
			if(fab==5'd3) vme_reg3 <= DATA;
		end
	end

	//VME Read cycle
	reg [31:0] out_data=32'd0;
	always @ ( posedge SYSCLK ) begin
		if( frsb_e==2'b01 ) begin
			case ( fab )
				5'd0  : out_data = vme_reg0;
				5'd1  : out_data = vme_reg1;
				5'd2  : begin
				        vme_reg2 = vme_reg2 + 32'd1;
				        out_data = vme_reg2;
						  end
				5'd3  : out_data = vme_reg3;
				default: out_data = 32'hFEFEFEFE;
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
			