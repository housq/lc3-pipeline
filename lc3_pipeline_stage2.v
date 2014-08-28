module lc3_pipeline_stage2(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[15:0]	I_npc,
	input		[19:0]	I_SR1,
	input		[19:0]	I_SR2,
	input		[19:0]	I_DR,
	input		[1:0]	I_WBtype,

	input		[1:0]	I_ALUopr,
	input			I_SetCC,

	input		[4:0]	I_BRtype,
	input		[15:0]	I_Forcast_pc,
	input		[2:0]	I_Memtype,
	input		[1:0]	I_Errtype,

	output	reg	[19:0]	O_DR,
	output		[1:0]	O_WBtype,
	output		[2:0]	O_Memtype,
	output		[15:0]	O_aluout,

	input		[15:0]	PSR,
	output	reg		SetCC,
	output			NeedCC,
	output	reg	[2:0]	CC,
	output	reg	[1:0]	Errtype,
	output	reg	[15:0]	Checked_pc,
	output	reg		Forcast_fail,
	output	reg	[15:0]	IntINTvec,

	output		[19:0]	sr1,
	output		[19:0]	sr2,
	input		[19:0]	dr3,
	input		[19:0]	dr4,
	input		[19:0]	dr5

);
	reg		[15:0]	NUMA,NUMB;
	LC3_ALU		alu0(
			.NUMA(NUMA),
			.NUMB(NUMB),
			.ALUK(ALUopr),
			.ALUout(O_aluout)
		);

	reg		[19:0]	SR1;
	reg		[19:0]	SR2;
	assign			sr1=SR1;
	assign			sr2=SR2;
	reg		[19:0]	DR;
	reg		[1:0]	WBtype;
	reg		[1:0]	ALUopr;
	reg		[4:0]	BRtype;
	reg		[15:0]	Forcast_pc;
	reg		[2:0]	Memtype;

	assign			O_Memtype=Memtype;
	assign			O_WBtype=WBtype;
	
	always@(negedge clk or posedge reset)	begin
		if(reset)	begin
			//seems nothing to do
		end else begin	
			if(~stall)	begin
				SR1<=I_SR1;
				SR2<=I_SR2;
				DR <=I_DR;
				WBtype<=I_WBtype;
				ALUopr<=I_ALUopr;
				SetCC <=I_SetCC;
				BRtype<=I_BRtype;
				Forcast_pc<=I_Forcast_pc;
				Memtype<=I_Memtype;
				Errtype<=I_Errtype;
			end else begin
				DR <=O_DR;
				SR1[15:0]<=NUMA;
				SR2[15:0]<=NUMB;
			end
		end
	end

	/*branch detect*/
	always@(*)	begin
		case	(BRtype[4:3])
			2'b00:
				{Forcast_fail,Checked_pc}={1'b0,Forcast_pc};
			2'b01:
				{Forcast_fail,Checked_pc}={state[2]&~stall&( (BRtype[2:0]&PSR[2:0])!=3'b000 )& (O_aluout!=Forcast_pc),Forcast_fail?O_aluout:Forcast_pc};
			2'b10:
				{Forcast_fail,Checked_pc}={state[2]&~stall&(O_aluout!=Forcast_pc),O_aluout};
			2'b11:
				{Forcast_fail,Checked_pc}={1'b0,Forcast_pc};
		endcase
	end


	/*TODO data forward*/
	assign		NeedCC=(BRtype[4:3]==2'b01);

	always@(*)	begin
		if(state[3]&dr3[19]&SR1[19]&(SR1[18:16]==dr3[18:16]))
			NUMA=dr3[15:0];
		else if(state[4]&dr4[19]&SR1[19]&(SR1[18:16]==dr4[18:16]))
			NUMA=dr4[15:0];
		else if(state[5]&dr5[19]&SR1[19]&(SR1[18:16]==dr5[18:16]))
			NUMA=dr5[15:0];
		else 
			NUMA=SR1[15:0];
	end

	always@(*)	begin
		if(state[3]&dr3[19]&SR2[19]&(SR2[18:16]==dr3[18:16]))
			NUMB=dr3[15:0];
		else if(state[4]&dr4[19]&SR2[19]&(SR2[18:16]==dr4[18:16]))
			NUMB=dr4[15:0];
		else if(state[5]&dr5[19]&SR2[19]&(SR2[18:16]==dr5[18:16]))
			NUMB=dr5[15:0];
		else 
			NUMB=SR2[15:0];
	end

	always@(*)	begin
		if(state[3]&dr3[19]&DR[19]&(DR[18:16]==dr3[18:16]))
			O_DR={DR[19:16],dr3[15:0]};
		else if(state[4]&dr4[19]&DR[19]&(DR[18:16]==dr4[18:16]))
			O_DR={DR[19:16],dr4[15:0]};
		else if(state[5]&dr5[19]&DR[19]&(DR[18:16]==dr5[18:16]))
			O_DR={DR[19:16],dr5[15:0]};
		else if(~WBtype[1]|WBtype[0])
			O_DR={DR[19:0]};
		else 
			O_DR={DR[19:16],O_aluout};
	end

	always@(*)	begin
		if(O_aluout==16'b0)
			CC=3'b010;
		else if(O_aluout[15]==1)
			CC=3'b100;
		else 
			CC=3'b001;
	end
	
	always@(*)	begin
		case(Errtype)
			2'b00:
				IntINTvec=16'bx;
			2'b01:
				IntINTvec=O_aluout;
			2'b10:
				IntINTvec=16'h0044;
			2'b11:
				IntINTvec=16'h0044;
		endcase
	end
	


endmodule
