//=====================================================================
//
// Designer   : Yili Gong
//
// Description:
// As part of the project of Computer Organization Experiments, Wuhan University
// In spring 2021
// The instruction memory and data memory.
//
// ====================================================================

`include "xgriscv_defines.v"

module imem(input  [`ADDR_SIZE-1:0]   a,    
            output [`INSTR_SIZE-1:0]  rd);  //read-data

  reg  [`INSTR_SIZE-1:0] RAM[`IMEM_SIZE-1:0];

  initial
    begin
      //$readmemh("riscv32_sim1.dat", RAM);
    end

  assign rd = RAM[a[11:2]]; // instruction size aligned
endmodule


module dmem(input                      clk, we, //write-enable
            input  [`XLEN-1:0]        a, wd,    
            input  [`ADDR_SIZE-1:0]    pc,
            input [1:0] whbM,
            input lunsigned,
            output [`XLEN-1:0]        rd);      //read-data

  reg  [31:0] RAM[1023:0];

  assign rd = RAM[a[11:2]]; // word aligned
  wire[3:0] amp;
  ampattern ampat(a[1:0], whbM, amp);
  wire [`XLEN-1:0] temp;
  assign temp = RAM[a[11:2]];
  always @(posedge clk)
    if (we)
      begin
        //RAM[a[11:2]] <= wd;             // sw
        if(amp == 4'b0001) RAM[a[11:2]] = {temp[31:8], wd[7:0]};
        if(amp == 4'b0010) RAM[a[11:2]] = {temp[31:16],wd[7:0],temp[7:0]};
        if(amp == 4'b0100) RAM[a[11:2]] = {temp[31:24],wd[7:0],temp[15:0]};
        if(amp == 4'b1000) RAM[a[11:2]] = {wd[7:0],temp[23:0]};
        if(amp == 4'b0011) RAM[a[11:2]] = {temp[31:16],wd[15:0]};
        if(amp == 4'b1100) RAM[a[11:2]] = {wd[15:0],temp[15:0]};
        if(amp == 4'b1111) RAM[a[11:2]] = wd;
        // DO NOT CHANGE THIS display LINE!!!
        /**********************************************************************/
        //$display("pc = %h: dataaddr = %h, memdata = %h", pc, {a[31:2],2'b00}, RAM[a[11:2]]);
        /**********************************************************************/
      end
    
endmodule
