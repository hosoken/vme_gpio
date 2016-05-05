`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Kenji Hosomi
// 
// Create Date:    18:15:04 12/09/2013 
// Design Name: 
// Module Name:    top 
// Project Name:   cpld
// Target Devices: XC95288XL-7TQ144
// Tool versions:  Xilinx ISE WebPACK 14.7
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
//          2.00 - 20160328 - Asynchronous circuit for low latency (K.Hosomi)
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
	 input WRITE;			       //VME Write
	 input DS0, DS1;		       //VME Data strobe
	 input AS;			       //VME Address strobe
	 input IACK;			       //VME IACK
	 input LWORD;			       //VME LWORD
	 input [5:0] AM;		       //VME AM code
	 input [15:1] A;		       //VME Address
	 input EQ1, EQ2;		       //Board Address (on-board dip switch)
	 output BERR;                          //VME BERR
	 output DTACK;                         //VME DTACK

         //CPLD <-> FPGA
	 input FDTACK;                         //DTACK from FPGA
	 output FSYSCLK;                       //SYSCLK going to FPGA
	 output FWS, FRS;                      //Write or Read strobe going to FPGA
	 output [4:0] FA;                      //Address going to FPGA
	 

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
//   VME bus error is not implemented.
//   Irregular access may result in VME bus timeout.
//================================================================================

	//VME Address
	wire adrdec;
	vme_address_decode vme_address_decode(AS, IACK, EQ1, EQ2, adrdec);
	
	//Address Modifier
	wire amdec;
	address_modifier_decode address_modifier_decode(AM, amdec); 
	
	//Data Word
	wire d32;
	data_word_decode data_word_decode(LWORD, A[1], DS0, DS1, d32);
	
	//Access Check
	wire enable;
	access_check access_check(adrdec, amdec, d32, enable);
 
	//VME bus error
	assign BERR = 1'b1;
	
	//Strobe
	wire read_str;
	assign read_str = ((enable==1'b1) && (WRITE==1'b1));
	
	wire write_str;
	assign write_str = ((enable==1'b1) && (WRITE==1'b0));
	
	//Tranciever Enable & Direction
	assign RWD8  = ~enable;
	assign RWD16 = ~enable;
	assign RWD32 = ~enable;
	
	assign UHDIR = ~WRITE;
	assign ULDIR = ~WRITE;
	assign LHDIR = ~WRITE;
	assign LLDIR = ~WRITE;
		
//================================================================================
//   Signal assignement CPLD <-> FPGA
//================================================================================	
	assign FSYSCLK = SYSCLK;	
	assign DTACK = FDTACK;
        assign FRS = read_str;
	assign FWS = write_str;
	assign FA = A[6:2];
	
endmodule

module vme_address_decode(AS, IACK, EQ1, EQ2, OUT);
	input AS, IACK, EQ1, EQ2;
	output OUT;
	assign OUT = ((AS==1'b0) && (IACK==1'b1) && (EQ1==1'b0) && (EQ2==1'b0)); 
endmodule

module address_modifier_decode(AM, OUT);
	input [5:0] AM;
	output OUT;
	assign OUT = ((AM==6'h09) || (AM==6'h0A) || (AM==6'h0D) || (AM==6'h0E));
endmodule

module data_word_decode(LWORD, A01, DS0, DS1, OUT);
	input LWORD, A01, DS0, DS1;
	output OUT;
	assign OUT = ((LWORD==1'b0) && (A01==1'b0) && (DS0==1'b0) && (DS1==1'b0));
endmodule

module access_check(ADDR, AM, DWORD, OK);
	input ADDR, AM, DWORD;
	output OK;
	assign OK = ((ADDR==1'b1) && (AM==1'b1) && (DWORD==1'b1));
endmodule
