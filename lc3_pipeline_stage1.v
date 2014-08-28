module lc3_pipeline_stage1(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[15:0]	I_inst,
	input		[15:0]	I_npc,
	input		[15:0]	I_Forcast_pc,

	input		[19:0]	I_WBctl,
	input		[19:0]	fsm_regctl,

	output	reg	[15:0]	O_npc,
	output	reg	[19:0]	O_SR1,
	output	reg	[19:0]	O_SR2,
	output	reg	[19:0]	O_DR,			//in this O_DR a data was passed to the later stages ,it can be data to be written to memory or written back to regfile
	output	reg	[1:0]	O_WBtype,		//this indicate where the writeback data is from :passed data or pipeline result

	output	reg	[1:0]	O_ALUopr,
	output	reg		O_SetCC,

	output	reg	[4:0]	O_BRtype,
	output	reg	[15:0]	O_Forcast_pc,
	output	reg	[2:0]	O_Memtype,
	output	reg	[1:0]	O_Errtype,


	output		[15:0]	SP
);

	reg		[15:0]	REGin;
	reg		[2:0]	DR;
	reg			LD_REG;
	reg		[2:0]	SR1,SR2;

	wire		[15:0]	SR1out,SR2out,SR1out_tmp,SR2out_tmp;
	LC3_REGFILE	rf0(
			.clk(clk),
			.REGin(REGin),
			.DR(DR),
			.LD_REG(LD_REG),
			.SR1(SR1),
			.SR2(SR2),
			.SR1out(SR1out_tmp),
			.SR2out(SR2out_tmp),
			.SP(SP)
		);

	assign	SR1out= ( (LD_REG&(SR1==DR))?REGin:SR1out_tmp);
	assign	SR2out= ( (LD_REG&(SR2==DR))?REGin:SR2out_tmp);

	always@(*)	begin
		if(fsm_regctl[19])	begin
			{LD_REG,DR,REGin}=fsm_regctl;
		end else 	
			{LD_REG,DR,REGin}=I_WBctl;
	end

	reg		[15:0]	IR;

	always@(negedge clk or posedge reset)	begin
		if(reset)	begin
			//seems nothing to do
		end else begin
			if(!stall)	begin
				IR<=I_inst;
				O_npc<=I_npc;
				O_Forcast_pc<=I_Forcast_pc;
			end
		end
	end

	always@(*)	begin
		case(IR[15:12])
			4'h1:begin							//ADD
				SR1 = IR[8:6];
				SR2 = IR[2:0];
				O_SR1 = {1'b1,IR[8:6],SR1out};
				if(IR[5]==0)
					O_SR2 = {1'b1,IR[2:0],SR2out};
				else
					O_SR2 = {1'b0,IR[2:0],{11{IR[4]}},IR[4:0]};
				O_DR = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b00;
				O_SetCC	 = 1;

				O_BRtype = 5'b00xxx;
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'h5:begin							//AND
				SR1 = IR[8:6];
				SR2 = IR[2:0];
				O_SR1 = {1'b1,IR[8:6],SR1out};
				if(IR[5]==0)
					O_SR2 = {1'b1,IR[2:0],SR2out};
				else
					O_SR2 = {1'b0,IR[2:0],{11{IR[4]}},IR[4:0]};
				O_DR = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b01;
				O_SetCC	 = 1;

				O_BRtype = 5'b00xxx;
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'h9:begin							//NOT
				SR1 = IR[8:6];
				SR2 = 3'bxxx;
				O_SR1 = {1'b1,IR[8:6],SR1out};
				O_SR2 = {1'b0,18'bx};
				O_DR = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b10;
				O_SetCC	 = 1;

				O_BRtype = 5'b00xxx;
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'hd:begin							//UND
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,18'bx};
				O_SR2 = {1'b0,18'bx};
				O_DR  = {1'b0,18'bx};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'bxx;
				O_SetCC  = 0;

				O_BRtype = 5'b00xxx;
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b11;	//UND INST EXCEPTION
			end

			4'h0:begin							//BR
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b0,3'bxxx,16'bxxx};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b01,IR[11:9]};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;	
			end

			4'hc:begin							//JMP RET
				SR1 = IR[8:6];
				SR2 = 3'bxxx;
				O_SR1 = {1'b1,IR[8:6],SR1out};
				O_SR2 = {1'b0,3'bxxx,16'b0};
				O_DR  = {1'b0,19'bx};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b10,3'bxxx};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'h4:begin							//JSR JSRR
				SR1 = IR[8:6];
				SR2 = 3'bxxx;
				if(IR[11]==1)	begin	
					O_SR1 = {1'b0,3'bxxx,O_npc};
					O_SR2 = {1'b0,3'bxxx,{5{IR[10]}},IR[10:0]};
				end else begin
					O_SR1 = {1'b1,IR[8:6],SR1out};
					O_SR2 = {1'b0,3'bxxx,16'b0};
				end
				O_DR  = {1'b0,3'b111,O_npc};
				O_WBtype = 2'b11;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b10,3'bxxx};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'h8:begin							//RTI
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,19'bxxx};
				O_SR2 = {1'b0,19'bxxx};
				O_DR  = {1'b0,19'bxxx};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'bxx;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b10;
			end

			4'he:begin							//LEA
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b00;
				O_SetCC  = 1;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b00;
			end

			4'h2:begin							//LD
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b100;
				O_Errtype= 2'b00;
			end

			4'ha:begin							//LDI
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b110;
				O_Errtype= 2'b00;
			end

			4'h6:begin							//LDR
				SR1 = IR[8:6];
				SR2 = 3'bxxx;
				O_SR1 = {1'b1,IR[8:6],SR1out};
				O_SR2 = {1'b0,3'bxxx,{10{IR[5]}},IR[5:0]};
				O_DR  = {1'b0,IR[11:9],16'bx};
				O_WBtype = 2'b10;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b100;
				O_Errtype= 2'b00;
			end

			4'h3:begin							//ST
				SR1 = 3'bxxx;
				SR2 = IR[11:9];
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b1,IR[11:9],SR2out};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b101;
				O_Errtype= 2'b00;
			end

			4'hb:begin							//STI
				SR1 = 3'bxxx;
				SR2 = IR[11:9];
				O_SR1 = {1'b0,3'bxxx,O_npc};
				O_SR2 = {1'b0,3'bxxx,{7{IR[8]}},IR[8:0]};
				O_DR  = {1'b1,IR[11:9],SR2out};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b111;
				O_Errtype= 2'b00;
			end

			4'h7:begin							//STR
				SR1 = IR[8:6];
				SR2 = IR[11:9];
				O_SR1 = {1'b1,IR[8:6],SR1out};
				O_SR2 = {1'b0,3'bxxx,{10{IR[5]}},IR[5:0]};
				O_DR  = {1'b1,IR[11:9],SR2out};
				O_WBtype = 2'b0x;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b101;
				O_Errtype= 2'b00;
				
			end

			4'hf:begin							//TRAP
				SR1 = 3'bxxx;
				SR2 = 3'bxxx;
				O_SR1 = {1'b0,3'bxxx,8'b0,IR[7:0]};
				O_SR2 = {1'b0,3'bxxx,16'b0};
				O_DR  = {1'b0,3'b111,O_npc};
				O_WBtype = 2'b11;
				O_ALUopr = 2'b00;
				O_SetCC  = 0;

				O_BRtype = {2'b00,3'bxxx};
				O_Memtype= 3'b0xx;
				O_Errtype= 2'b01;
			end
		endcase
	end
		
endmodule
