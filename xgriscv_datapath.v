//=====================================================================
//
// Designer   : Yili Gong
//
// Description:
// As part of the project of Computer Organization Experiments, Wuhan University
// In spring 2021
// The datapath of the pipeline.
// ====================================================================

`include "xgriscv_defines.v"

module datapath(
	input                    clk, reset,

	input [`INSTR_SIZE-1:0]  instrF, 	 // from instructon memory
	output[`ADDR_SIZE-1:0] 	 pcF, 		   // to instruction memory

	input [`XLEN-1:0]	       readdataM, // from data memory: read data
  output[`XLEN-1:0]        aluoutM, 	 // to data memory: address
 	output[`XLEN-1:0]	       writedataM,// to data memory: write data
  output			                memwriteM,	// to data memory: write enable
 	output [`ADDR_SIZE-1:0]  pcM,       // to data memory: pc of the write instruction
 	
 	output [`ADDR_SIZE-1:0]  pcW,       // to testbench
  
	
	// from controller
	input [4:0]		            immctrlD,
	input			                 itypeD, jalD, jalrD, bunsignedD, pcsrcD,
	input [3:0]		            aluctrlD,
	input [1:0]		            alusrcaD,
	input			                 alusrcbD,
	input			                 memwriteD, lunsignedD,
	input [1:0]		          	 lwhbD, swhbD,  
	input          		        memtoregD, regwriteD,
	input                    btypeD,
	
  	// to controller
 	output [1:0]		           whbM,
 	output      		           lunsignedM,
	output [6:0]		           opD,
	output [2:0]		           funct3D,
	output [6:0]		           funct7D,
	output [4:0] 		          rdD, rs1D,
	output [11:0]  		        immD,
	output 	       		        zeroD, ltD,
    input [4:0] reg_sel,
    output[31:0] reg_data
	);
	wire pcsrcE;
	// next PC logic (operates in fetch and decode)
	wire [`ADDR_SIZE-1:0]	 pcplus4F, nextpcF, pcbranchD, pcadder2aD, pcadder2bD, pcbranch0D;
	mux2 #(`ADDR_SIZE)	    pcsrcmux(pcplus4F, pcbranchD, pcsrcE, nextpcF);
	wire unStalled;	

	// Fetch stage logic
	pcenr      	 pcreg(clk, reset, unStalled, nextpcF, pcF);
	addr_adder  	pcadder1(pcF, `ADDR_SIZE'b100, pcplus4F);

	///////////////////////////////////////////////////////////////////////////////////
	// IF/ID pipeline registers
	wire [`RFIDX_WIDTH-1:0] rdE;
	wire[4:0]	rdM;
	wire [`INSTR_SIZE-1:0]	instrD;
	wire [`ADDR_SIZE-1:0]	pcD, pcplus4D;
	wire [1:0] whbD = swhbD | lwhbD;
	wire flushD = pcsrcE;
	
	flopenrc #(`INSTR_SIZE) 	pr1D(clk, reset, unStalled ,flushD, instrF, instrD);     // instruction
	flopenrc #(`ADDR_SIZE)	  pr2D(clk, reset, unStalled, flushD, pcF, pcD);           // pc
	flopenrc #(`ADDR_SIZE)	  pr3D(clk, reset, unStalled, flushD, pcplus4F, pcplus4D); // pc+4

	// Decode stage logic
	wire [`RFIDX_WIDTH-1:0] rs2D;
	wire memtoregE;	
	wire memtoregM;
	wire regwriteE; 
	assign  opD 	= instrD[6:0];
	assign  rdD     = instrD[11:7];
	assign  funct3D = instrD[14:12];
	assign  rs1D    = instrD[19:15];
	assign  rs2D   	= instrD[24:20];
	assign  funct7D = instrD[31:25];
	assign  immD    = instrD[31:20];
	
	hazard hzd(rdE, rdM, rs1D, rs2D, memtoregE, memtoregM, regwriteE, memwriteD, btypeD, unStalled);

	// immediate generate
	wire [11:0]  iimmD = instrD[31:20];
	wire [11:0]		simmD	= {instrD[31:25], instrD[11:7]};
	wire [11:0]  bimmD	= {instrD[31],instrD[7],instrD[30:25],instrD[11:8]};
	wire [19:0]		uimmD	= instrD[31:12];
	wire [19:0]  jimmD	= {instrD[31], instrD[19:12], instrD[20], instrD[30:21]};
	wire [`XLEN-1:0]	immoutD, shftimmD;
	wire [`XLEN-1:0]	rdata1D, rdata2D, wdataW;
	wire [`RFIDX_WIDTH-1:0]	waddrW;

	imm 	im(iimmD, simmD, bimmD, uimmD, jimmD, immctrlD, immoutD);

	// register file (operates in decode and writeback)
	wire[31:0] regdatafw1D;
	wire[31:0] regdatafw2D;
	wire cmpsrc1;
	wire cmpsrc2;
	regfile rf(clk, rs1D, rs2D, rdata1D, rdata2D, regwriteW, waddrW, wdataW, pcW, reg_sel, reg_data);
	mux2 #(`XLEN) cmp1(rdata1D, aluoutM, cmpsrc1, regdatafw1D);
	mux2 #(`XLEN) cmp2(rdata2D, aluoutM, cmpsrc2, regdatafw2D);
	cmp cmp(regdatafw1D, regdatafw2D, bunsignedD, zeroD, ltD);
	///////////////////////////////////////////////////////////////////////////////////
	// ID/EX pipeline registers

	// for control signals
	wire       memwriteE, alusrcbE;
	
	wire [1:0] alusrcaE;
	wire [3:0] aluctrlE;
	wire 	     flushE = pcsrcE | !unStalled;
	wire [1:0] whbE;
	wire lunsignedE;
	wire jalrE;
	wire [4:0] rs1E;
	wire [4:0] rs2E;
	wire [4:0] rs2M;
	floprc #(9) regE(clk, reset, flushE,
                  {regwriteD, memwriteD, alusrcaD, alusrcbD, aluctrlD}, 
                  {regwriteE, memwriteE, alusrcaE, alusrcbE, aluctrlE});
	floprc #(1) reg2E(clk, reset, flushE, memtoregD, memtoregE);
	floprc #(1) reg3E(clk, reset, flushE, pcsrcD, pcsrcE);
	floprc #(5) reg4E(clk, reset, flushE, rs1D, rs1E);
	floprc #(5) reg5E(clk, reset, flushE, rs2D, rs2E);
 	// for data
	wire [`XLEN-1:0]	srcaEp, srcbEp, immoutE, srcaE, srcbE, aluoutE;
	wire [`ADDR_SIZE-1:0] 	pcE, pcplus4E;
	
	floprc #(`XLEN) 	pr1E(clk, reset, flushE, rdata1D, srcaEp);        	// data from rs1
	floprc #(`XLEN) 	pr2E(clk, reset, flushE, rdata2D, srcbEp);         // data from rs2
	floprc #(`XLEN) 	pr3E(clk, reset, flushE, immoutD, immoutE);        // imm output
 	floprc #(`RFIDX_WIDTH)  pr6E(clk, reset, flushE, rdD, rdE);         // rd
 	floprc #(`ADDR_SIZE)	pr8E(clk, reset, flushE, pcD, pcE);            // pc
 	floprc #(`ADDR_SIZE)	pr9E(clk, reset, flushE, pcplus4D, pcplus4E);  // pc+4
	floprc #(2) pr10E(clk, reset, flushE, whbD, whbE);
	floprc #(1) pr11E(clk, reset, flushE, lunsignedD, lunsignedE);
	floprc #(1) pr12E(clk, reset, flushE, jalrD, jalrE);
	// execute stage logic
	wire 		regwriteM;
	wire[4:0]	rdW;
	wire[1:0] fwdAE;
	wire[1:0] fwdBE;
	wire wdataMsrc;
	wire[31:0] srcafwE;
	wire[31:0] srcbfwE;
	forwarding fwd(regwriteM,regwriteW,rdM,rdW,rs1E,rs2E,rs2M,memwriteM,btypeD,rs1D,rs2D,fwdAE,fwdBE,wdataMsrc,cmpsrc1,cmpsrc2);
	
	mux3 #(`XLEN)  fwamux(srcaEp,wdataW,aluoutM,fwdAE,srcafwE);
	mux3 #(`XLEN)  fwbmux(srcbEp,wdataW,aluoutM,fwdBE,srcbfwE);
 	mux4 #(`XLEN)  srcamux(srcafwE, 0, pcE, pcplus4E, alusrcaE, srcaE);     // alu src a mux
	mux2 #(`XLEN)  srcbmux(srcbfwE, immoutE, alusrcbE, srcbE);			 // alu src b mux
	
	
	mux2 #(`XLEN) pcaddmux(pcE, srcafwE, jalrE, pcadder2aD);
    addr_adder pcadder2(pcadder2aD, immoutE, pcbranch0D);
	mux2 #(`XLEN) pcbranchmux(pcbranch0D, (pcbranch0D & ~1), jalrE, pcbranchD);
	


	alu alu(srcaE, srcbE, 5'b0, aluctrlE, aluoutE, overflowE, zeroE, ltE, geE);

	///////////////////////////////////////////////////////////////////////////////////
	// EX/MEM pipeline registers
	// for control signals
	wire [`XLEN-1:0] srcbMp;
	wire 		flushM = 0;
	floprc #(2) 	regM(clk, reset, flushM,
                  	{regwriteE, memwriteE},
                  	{regwriteM, memwriteM});
	floprc #(1) 	reg2M(clk, reset, flushM, memtoregE, memtoregM);
	floprc #(5)		reg3M(clk, reset, flushM, rs2E, rs2M);
	// for data
	floprc #(`XLEN) 	        pr1M(clk, reset, flushM, aluoutE, aluoutM);
	floprc #(`RFIDX_WIDTH) 	 pr2M(clk, reset, flushM, rdE, rdM);
	floprc #(`ADDR_SIZE)	    pr3M(clk, reset, flushM, pcE, pcM);            // pc
	floprc #(2) pr5M(clk, reset, flushE, whbE, whbM);
	floprc #(1) pr6M(clk, reset, flushE, lunsignedE, lunsignedM);
	floprc #(`XLEN)	pr4M(clk, reset, flushM, srcbEp, srcbMp);
	
	// mem stage logic
	wire[3:0] amp;
	wire[`XLEN-1:0] prodata;
  	ampattern ampat(aluoutM[1:0], whbM, amp);
	getamp getprodata(amp,readdataM,lunsignedM,prodata);
	mux2 #(`XLEN) writedatasrc(wdataW,srcbMp,wdataMsrc,writedataM);
  ///////////////////////////////////////////////////////////////////////////////////
  // MEM/WB pipeline registers
  // for control signals
  wire flushW = 0;
  wire memtoregW;
	floprc #(1) regW(clk, reset, flushW, {regwriteM}, {regwriteW});
	floprc #(1) reg2W(clk, reset, flushW, memtoregM, memtoregW);
  // for data
  wire[`XLEN-1:0]		       aluoutW;
  wire[`XLEN-1:0]	readdataW;

  floprc #(`XLEN) 	       pr1W(clk, reset, flushW, aluoutM, aluoutW);
  floprc #(`RFIDX_WIDTH)  pr2W(clk, reset, flushW, rdM, rdW);
  floprc #(`ADDR_SIZE)	   pr3W(clk, reset, flushW, pcM, pcW);            // pc
  floprc #(`XLEN) pr4W(clk, reset, flushW, prodata, readdataW);

	// write-back stage logic
	mux2 #(`XLEN) srcToReg(aluoutW, readdataW, memtoregW, wdataW);
	assign waddrW = rdW;

endmodule

