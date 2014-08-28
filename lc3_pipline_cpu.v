module lc3_pipeline_cpu(
	input			clk,
	input			reset,
	input			INT,
	
	output		[15:0]	pc,
	output		[15:0]	PSR,
	output				EXC,
	output		[5:0]	state,
	
	output		[5:0]	stall,

	output		[15:0]	memA,
	inout		[15:0]	memD,
	output			rc,
	output			wc,
	output		[5:0]	state_next,
	output		[15:0]	aluout,
	output		[19:0]	dr2,
	output		[19:0]	dr3,
	output		[19:0]	dr4,
	output		[19:0]	dr5
);

	wire	[15:0]		memdata;
	assign			memdata=memD;
	
	wire		[15:0]	ExtINTvec;
	wire		[15:0]	IntINTvec;
	
		assign		ExtINTvec=16'h0040;
	
	wire		[2:0]	memapply;
	wire			memtype;
	wire		[2:0]	memload;
	wire		[15:0]	memaddrin0;
	wire		[15:0]	memaddrin1;
	wire		[15:0]	memaddrin2;
	wire			mem_rw;
	wire		[15:0]	memdatain;

	assign			rc=~mem_rw;
	assign			wc=mem_rw;

	wire		[3:2]	setCC;
	wire			NeedCC;
	wire		[2:0]	CCin;
	wire		[2:0]	CCinM;
	wire		[1:0]	Errtype;
	wire		[4:3]	inst_ld;

	wire		[19:0]	sr1;
	wire		[19:0]	sr2;
//	wire		[19:0]	dr2;
//	wire		[19:0]	dr3;
//	wire		[19:0]	dr4;
//	wire		[19:0]	dr5;
	

	wire			Forcast_fail;
	wire		[15:0]	Checked_pc;

	wire		[1:0]	ld_pc;

	wire		[19:0]	fsm_regctl;

	wire		[15:0]	SP;

	lc3_pipeline_fsm	fsm0(
		.clk		(clk),
		.reset		(reset),
		.INT		(INT),
		.ExtINTvec	(ExtINTvec),
		.IntINTvec	(IntINTvec),
		.stall		(stall),
		.state		(state),
		.state_next	(state_next),
		.pc		(pc),
		
		.memapply	(memapply),
		.memtype	(memtype),
		.memload	(memload),
		.memaddrin0	(memaddrin0),
		.memaddrin1	(memaddrin1),
		.memaddrin2	(memaddrin2),
		.memaddrout	(memA),
		.mem_rw		(mem_rw),
		.memdatain	(memdatain),
		.memdataout	(memD),

		.PSR		(PSR),
		.SP		(SP),
		.setCC		(setCC),
		.NeedCC		(NeedCC),
		.CCin		(CCin),
		.CCinM		(CCinM),
		.Errtype	(Errtype),
		.inst_ld	(inst_ld),
		
		.aluout		(aluout),
		.sr1		(sr1),
		.sr2		(sr2),
		.dr2		(dr2),
		.dr3		(dr3),
		.dr4		(dr4),

		.Forcast_fail	(Forcast_fail),
		.Checked_pc	(Checked_pc),

		.ld_pc		(ld_pc),

		.fsm_regctl	(fsm_regctl)
	);

	
	wire		[15:0]	forcast_pc0;
	wire		[15:0]	npc0;
	wire		[15:0]	inst;

	lc3_pipeline_stage0	stage0(
		.reset		(reset),
		.clk		(clk),
		.stall		(stall[0]),
		.state		(state),
		
		.memdata	(memdata),
		.memload	(memload[0]),
		.memapply	(memapply[0]),

		.ld_pc		(ld_pc),
		.alu_out	(aluout),
		.forcast_pc	(forcast_pc0),

		.pc			(memaddrin0),
		.npc		(npc0),
		.inst		(inst)
	);

	wire		[15:0]	npc1;
	wire		[19:0]	SR11;
	wire		[19:0]	SR21;
	wire		[19:0]	DR1;
	wire		[1:0]	WBtype1;
	
	wire		[1:0]	ALUopr1;
	wire			SetCC1;
	
	wire		[4:0]	BRtype1;
	wire		[15:0]	Forcast_pc1;
	wire		[2:0]	Memtype1;
	wire		[1:0]	Errtype1;

	

	lc3_pipeline_stage1	stage1(
		.reset		(reset),
		.clk		(clk),
		.stall		(stall[1]),
		.state		(state),

		.I_inst		(inst),
		.I_npc		(npc0),
		.I_Forcast_pc	(forcast_pc0),

		.I_WBctl	(dr5),
		.fsm_regctl	(fsm_regctl),
		
		.O_npc		(npc1),
		.O_SR1		(SR11),
		.O_SR2		(SR21),
		.O_DR		(DR1),
		.O_WBtype	(WBtype1),

		.O_ALUopr	(ALUopr1),
		.O_SetCC	(SetCC1),

		.O_BRtype	(BRtype1),
		.O_Forcast_pc	(Forcast_pc1),
		.O_Memtype	(Memtype1),
		.O_Errtype	(Errtype1),

		.SP		(SP)
	);

	wire		[1:0]	WBtype2;
	wire		[2:0]	Memtype2;

	

	lc3_pipeline_stage2	stage2(
		.reset		(reset),
		.clk		(clk),
		.stall		(stall[2]),
		.state		(state),
		
		.I_npc		(npc1),
		.I_SR1		(SR11),
		.I_SR2		(SR21),
		.I_DR		(DR1),
		.I_WBtype		(WBtype1),

		.I_ALUopr		(ALUopr1),
		.I_SetCC		(SetCC1),

		.I_BRtype		(BRtype1),
		.I_Forcast_pc		(Forcast_pc1),
		.I_Memtype		(Memtype1),
		.I_Errtype		(Errtype1),

		.O_DR			(dr2),
		.O_WBtype		(WBtype2),
		.O_Memtype		(Memtype2),
		.O_aluout		(aluout),

		.PSR			(PSR),
		.SetCC			(setCC[2]),
		.NeedCC			(NeedCC),
		.CC			(CCin),
		.Errtype		(Errtype),
		.Checked_pc		(Checked_pc),
		.Forcast_fail		(Forcast_fail),
		.IntINTvec		(IntINTvec),

		.sr1			(sr1),
		.sr2			(sr2),
		.dr3			(dr3),
		.dr4			(dr4),
		.dr5			(dr5)
	);

	wire		[1:0]	WBtype3;
	wire		[2:0]	Memtype3;
	wire		[15:0]	Res3;

	lc3_pipeline_stage3	stage3(
		.reset			(reset),
		.clk			(clk),
		.stall			(stall[3]),
		.state			(state),

		.I_DR			(dr2),
		.I_WBtype		(WBtype2),
		.I_Memtype		(Memtype2),
		.I_aluout		(aluout),
		.I_setCC		(setCC[2]),
		
		.O_DR			(dr3),
		.O_WBtype		(WBtype3),
		.O_Memtype		(Memtype3),
		.O_Res			(Res3),

		.memdata		(memdata),
		.memaddr		(memaddrin1),
		.memapply		(memapply[1]),
		.setCC			(setCC[3]),
		.inst_ld		(inst_ld[3])
	);


	wire		[1:0]	WBtype4;
	wire		[15:0]	Res4;

	lc3_pipeline_stage4	stage4(
		.reset		(reset),
		.clk		(clk),
		.stall		(stall[4]),
		.state		(state),
		
		.I_DR		(dr3),
		.I_WBtype	(WBtype3),
		.I_Memtype	(Memtype3),
		.I_Res		(Res3),

		.O_DR		(dr4),
		.O_WBtype	(WBtype4),
		.O_Res		(Res4),

		.memdata	(memdata),
		.memaddr	(memaddrin2),
		.memtype	(memtype),
		.memdatawr	(memdatain),
		.memapply	(memapply[2]),

		.CC		(CCinM),
		.inst_ld	(inst_ld[4])
	);

	lc3_pipeline_stage5	stage5(
		.reset		(reset),
		.clk		(clk),
		.stall		(stall[5]),
		.state		(state),

		.I_DR		(dr4),
		.I_WBtype	(WBtype4),
		.I_Res		(Res4),

		.O_WBctl	(dr5)
	);

endmodule