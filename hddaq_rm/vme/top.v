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
//          2.10 - Add Time Stamp
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
		SYSCLK,
		NIM_IN, NIM_OUT,
		ENC, SNC, SNINC, TRIG1, TRIG2,
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
	input SNINC;            // Spill Number Increment
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
//        Synchronization
//==============================================================================
   wire strig1;
	async_input_sync sync_trig1(SYSCLK, TRIG1, strig1);
	
	wire strig2;
	async_input_sync sync_trig2(SYSCLK, TRIG2, strig2);
	
	wire ssninc;
	async_input_sync sync_sninc(SYSCLK, SNINC, ssninc);

   wire sfws;
	async_input_sync sync_fws(SYSCLK, FWS, sfws);
	
	wire sfrs;
	async_input_sync sync_frs(SYSCLK, FRS, sfrs);
  
  
//==============================================================================
//          signal assign
//==============================================================================
	assign FOUT1       = TRIG1;
	assign FOUT2       = TRIG2;
   assign FOUT3       = CLEAR;
	assign FOUT4       = RESERVE_IN;

   assign RESERVE_OUT = FIN4;
	assign BUSY_OUT    = BUSY_IN;
	
	//wire
	wire rst;
	wire [31:0] ev_tag;
	wire [31:0] sp_tag;
	wire [31:0] in_reg;
	wire [31:0] tstamp;
	wire [31:0] LEVEL;
	wire [31:0] PULSE;
	
	//Time Stamp
	time_stamp time_stamp(SYSCLK, strig1, ssninc, tstamp);
	
   //Event tag
	event_tag event_tag(SYSCLK, strig2, LOCK, ENC, ev_tag);
	
	//Spill tag
	spill_tag spill_tag(SYSCLK, strig2, LOCK, SNC, sp_tag);
	
	//NIM input register
   input_register input_register(SYSCLK, NIM_IN, rst, in_reg);

   //NIM output (level or pulse)
	assign NIM_OUT = LEVEL[15:0] | PULSE[15:0];
	
	//VME cycle
	VME_cycle VME_cycle(SYSCLK, sfws, sfrs, FA, FDTACK, DATA, rst, ev_tag, sp_tag, in_reg, tstamp, LEVEL, PULSE);
	
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

module time_stamp(SYSCLK, TRIG1, SNINC, OREG);
	input SYSCLK, TRIG1, SNINC;
	output reg [31:0] OREG=32'd0;
	
	reg [1:0] trig1_e=2'd0;
	reg [1:0] sninc_e=2'd0;
	always @ (posedge SYSCLK) begin
		trig1_e <= {trig1_e[0],TRIG1};
		sninc_e <= {sninc_e[0],SNINC};
	end
	
	reg [31:0] counter=32'd0;
	always @ (posedge SYSCLK) begin
	   if( sninc_e==2'b01 ) counter <= 32'd0;
		else                 counter <= counter + 32'd1;
	end
	
	always @ (posedge SYSCLK) begin
		if( trig1_e==2'b01 ) OREG <= counter;
	end
endmodule

module event_tag(SYSCLK, TRIG2, LOCK, ENC, OREG);
	input SYSCLK, TRIG2, LOCK;
	input [13:0] ENC;
	output reg [31:0] OREG=32'd0;
	
	reg [1:0] trig2_e=2'd0;
	always @ (posedge SYSCLK) begin
		trig2_e <= {trig2_e[0],TRIG2};
	end
	
	always @ (posedge SYSCLK) begin
		if( trig2_e==2'b01 ) begin
			OREG <= {LOCK, 19'd0, ENC[13:2]};
		end
	end
endmodule

module spill_tag(SYSCLK, TRIG2, LOCK, SNC, OREG);
	input SYSCLK, TRIG2, LOCK;
	input [9:0] SNC;
	output reg [31:0] OREG=32'd0;
	
	reg [1:0] trig2_e=2'd0;
	always @ (posedge SYSCLK) begin
		trig2_e <= {trig2_e[0],TRIG2};
	end
	
	always @ (posedge SYSCLK) begin
		if( trig2_e==2'b01 ) begin
			OREG <= {LOCK, 23'd0, SNC[7:0]};
		end
	end
endmodule

module input_register(SYSCLK, IN, RST, OREG);
	input SYSCLK, RST;
	input [15:0] IN;
	output reg [31:0] OREG=32'd0;
	
   wire in1,in2,in3,in4,in5,in6,in7,in8,in9,in10,in11,in12,in13,in14,in15,in16;
	async_input_sync sync_in1(SYSCLK, IN[0], in1);
   async_input_sync sync_in2(SYSCLK, IN[1], in2);
	async_input_sync sync_in3(SYSCLK, IN[2], in3);
	async_input_sync sync_in4(SYSCLK, IN[3], in4);
	async_input_sync sync_in5(SYSCLK, IN[4], in5);
	async_input_sync sync_in6(SYSCLK, IN[5], in6);
	async_input_sync sync_in7(SYSCLK, IN[6], in7);
	async_input_sync sync_in8(SYSCLK, IN[7], in8);
	async_input_sync sync_in9(SYSCLK, IN[8], in9);
	async_input_sync sync_in10(SYSCLK, IN[9], in10);
	async_input_sync sync_in11(SYSCLK, IN[10], in11);
	async_input_sync sync_in12(SYSCLK, IN[11], in12);
	async_input_sync sync_in13(SYSCLK, IN[12], in13);
	async_input_sync sync_in14(SYSCLK, IN[13], in14);
	async_input_sync sync_in15(SYSCLK, IN[14], in15);
	async_input_sync sync_in16(SYSCLK, IN[15], in16);
	
	always @ (posedge SYSCLK) begin
	   if( RST ) OREG <= 32'd0;
		else OREG <= OREG | {16'd0,in16,in15,in14,in13,in12,in11,in10,in9,in8,in7,in6,in5,in4,in3,in2,in1};
	end
endmodule

module VME_cycle(SYSCLK, FWS, FRS, FA, DTACK, DATA, RST, ev_tag, sp_tag, in_reg, tstamp, LEVEL, PULSE);
	input SYSCLK, FWS, FRS;
	input [4:0] FA;
	inout [31:0] DATA;
	input [31:0] ev_tag;
	input [31:0] sp_tag;
	input [31:0] in_reg;
	input [31:0] tstamp;
	output reg [31:0] LEVEL=32'd0;
	output reg [31:0] PULSE=32'd0;
	output reg DTACK=1'b1;
	output reg RST=1'b0;

   reg [1:0] fws_e=2'd0;
	reg [1:0] frs_e=2'd0;
	always @ (posedge SYSCLK) begin
	   fws_e <= {fws_e[0],FWS};
		frs_e <= {frs_e[0],FRS};
	end

	//VME Write
	reg [31:0] dummy=32'd0;
	always @ ( posedge SYSCLK ) begin
		if( fws_e==2'b01 ) begin
			if(FA==5'd3) dummy <= DATA;
			else if(FA==5'd5) RST <= 1'b1;
			else if(FA==5'd6) LEVEL <= DATA;
			else if(FA==5'd7) PULSE <= DATA;
		end
		else begin
			RST   <= 1'b0;
			PULSE <= 32'd0;
		end
	end

	//VME Read
	reg [31:0] serial=32'd0;
   reg [31:0] bus_data=32'd0;
	always @ ( posedge SYSCLK ) begin
		if( frs_e==2'b01 ) begin
			case ( FA )
				5'd0  : bus_data <= ev_tag;
				5'd1  : bus_data <= sp_tag;
				5'd2  : begin
				        serial <= serial + 32'd1;
				        bus_data <= serial;
						  end
				5'd3  : bus_data <= dummy;
				5'd4  : bus_data <= in_reg;
				5'd6  : bus_data <= LEVEL;
				5'd8  : bus_data <= tstamp;
				default: bus_data <= 32'hFEFEFEFE;
			endcase
		end
	end
	assign DATA = (frs_e[1]==1'b1)? bus_data : 32'bz;
	
	//Data Acknowledgement
	always @ ( posedge SYSCLK ) begin
		if( frs_e[1]==1'b1 )      DTACK <= 1'b0;
		else if( fws_e[1]==1'b1 ) DTACK <= 1'b0;
		else               		  DTACK <= 1'b1;
	end
endmodule


