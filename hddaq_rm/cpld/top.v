`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Kenji Hosomi
// 
// Create Date:    18:15:04 12/09/2013 
// Design Name: 
// Module Name:    top 
// Project Name:   GPIO
// Target Devices: Xilinx XC95288XL_TQG144AWN1021_D4091979A_7C
// Tool versions:  Xilinx ISE WebPACK 10.1.03
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
//          1.00 - First release (K.Hosomi)
//          1.01 - 16 VME registers are added. (K.Hosomi)
//          1.02 - Remove Front panel reset switch from CPLD to FPGA (K.Hosomi)
//          1.03 - 20140930 - Change timing of VME Strobe (K.Hosomi)
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
    SYSCLK,
	 WRITE,DS0,DS1,AS,IACK,LWORD,AM,A,BERR,DTACK,
	 EQ1,EQ2,RWD8,RWD16,RWD32,UHDIR,ULDIR,LHDIR,LLDIR,
	 FDTACK,FSYSCLK,FWS,FRS,FA
    );
    
//================================================================================
//      Define I/O signals	 
//================================================================================
	 
	 //SYSTEM
	 input SYSCLK;                         //Internal clock (on-board, 32MHz)
	 output RWD8, RWD16, RWD32;            //Enable for data bus transceiver 
	 output UHDIR, ULDIR, LHDIR, LLDIR;    //Direction for data bus trasceiver
	 
	 //CPLD <-> VME
	 input WRITE;									//VME Write
	 input DS0, DS1;								//VME Data strobe
	 input AS;										//VME Address strobe
	 input IACK;									//VME IACK
	 input LWORD;									//VME LWORD
	 input [5:0] AM;							   //VME AM code
	 input [15:1] A;								//VME Address
	 input EQ1, EQ2;								//Board Address (on-board dip switch)
	 output BERR;                          //VME BERR
	 output DTACK;                         //VME DTACK

    //CPLD <-> FPGA
	 input FDTACK;                         //DTACK from FPGA
	 output FSYSCLK;                       //SYSCLK going to FPGA
	 output FWS, FRS;                      //Write or Read strobe going to FPGA
	 output [4:0] FA;                      //Address going to FPGA
	 
//================================================================================
//   Syncronazation of VME Input signals with SYSCLOCK
//================================================================================
	
	reg swrite;
	reg sas;
   reg sds0, sds1;
	reg siack;
	reg slword;
	reg [5:0] sam;
	reg [15:1] sa;
	reg seq1, seq2;
	
	always @ (posedge SYSCLK) begin
		    swrite <= WRITE;
			 sas    <= AS;
			 sds0   <= DS0;
			 sds1   <= DS1;
			 siack  <= IACK;
			 slword <= LWORD;
			 sam    <= AM;
			 sa     <= A;
			 seq1   <= EQ1;
			 seq2   <= EQ2;
	end

//================================================================================
//   VME Access
//
//   <Allowed AM code>
//   AM = 09 : Extended Nonpriviledged Data Access
//   AM = 0A : Extended Nonpriviledged Program Access
//   AM = 0D : Extended Supervisory Data Access
//   AM = 0E : Extended Supervisory Program Access
//
//   <Allowed Access Mode>
//   A32/D32 only 
//
//   <Register Address Space>
//   4 x 32 = 128(0x80) Byte
//
//   VME address   FA[4:0]
//   -----------------------
//   Base + 0x00         0 
//        + 0x04         1
//        + 0x08         2
//           :           :
//        + 0x7C        31
//      
//   <Comment>
//   VME bus error is not equipped. 
//   Irregular access may result in VME bus timeout.
//================================================================================

	//Board Address Decode
	wire adrdec;
	assign adrdec = ((sas==1'b0) && (siack==1'b1) && (seq1==1'b0) && (seq2==1'b0)); 
	
	//Address Modifier Decode
	wire amdec;
	assign amdec = ((sam==6'h09) || (sam==6'h0A) || (sam==6'h0D) || (sam==6'h0E));
	
	//Data word Decode 
	wire d32;
	assign d32 = ((slword==1'b0) && (sa[1]==1'b0) && (sds0==1'b0) && (sds1==1'b0)); 
	
	//Strobe
	wire str = ((adrdec==1'b1) && (amdec==1'b1) && (d32==1'b1));
	
	reg read_str;
	reg write_str;
	always @ (posedge SYSCLK) begin
			read_str  <= ((str==1'b1) && (swrite==1'b1));
			write_str <= ((str==1'b1) && (swrite==1'b0));
	end
	
	//Tranciever Enable & Direction
	assign RWD8  = ~str;
	assign RWD16 = ~str;
	assign RWD32 = ~str;
	
	assign UHDIR = ~swrite;
	assign ULDIR = ~swrite;
	assign LHDIR = ~swrite;
	assign LLDIR = ~swrite;
	
	//VME bus error
	assign BERR = 1'b1;
	
//================================================================================
//   Signal assignement CPLD <-> FPGA
//================================================================================	
	assign FSYSCLK = SYSCLK;	
	assign DTACK = FDTACK;
   assign FRS = read_str;
	assign FWS = write_str;
	assign FA = sa[6:2];
	
endmodule
