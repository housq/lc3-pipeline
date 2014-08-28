module lc3_pipeline_fsm(
	input			clk,
	input			reset,
	input			INT,
	input		[15:0]	ExtINTvec,
	input		[15:0]	IntINTvec,
	output	reg	[5:0]	stall,
	output	reg	[5:0]	state,
	output	reg	[5:0]	state_next,

	output	reg	[15:0]	pc,
/*memory control input output*/
	input		[2:0]	memapply,
	input			memtype,
	output	reg	[2:0]	memload,
	input		[15:0]	memaddrin0,
	input		[15:0]	memaddrin1,
	input		[15:0]	memaddrin2,
	output	reg	[15:0]	memaddrout,
	output	reg		mem_rw,
	input		[15:0]	memdatain,
	inout	reg	[15:0]	memdataout,

/*PSR*/
	output		[15:0]	PSR,
	input		[15:0]	SP,
	input		[3:2]	setCC,
	input			NeedCC,
	input		[2:0]	CCin,
	input		[2:0]	CCinM,
	input		[1:0]	Errtype,
	input		[4:3]	inst_ld,

	input		[15:0]	aluout,
	input		[19:0]	sr1,
	input		[19:0]	sr2,
	input		[19:0]	dr2,
	input		[19:0]	dr3,
	input		[19:0]	dr4,

/*branch control*/
	input			Forcast_fail,
	input		[15:0]	Checked_pc,

/*fetch control*/
	output	reg	[1:0]	ld_pc,

/*reg control*/
	output	reg	[19:0]	fsm_regctl,

	output	reg		EXC
	
);

	reg	[15:0]	saved_USP;
	reg	[15:0]	saved_SSP;
	reg		Priv;
	reg	[2:0]	Priority,Priority_tmp;
	reg	[2:0]	CC;


	assign		PSR={Priv,4'b0,Priority,5'b0,CC};
//TODO ld_PSR
	wire			ld_PSR;
	assign			ld_PSR=(process==2'b11)&(process_step==3'b001);

	reg	[1:0]	process,process_next;
	reg	[2:0]	process_step,process_step_next;
	
	wire			INTvalid;
	assign		INTvalid=INT&(Priority==3'b000);

	wire		pipeline_empty;
	assign 		pipeline_empty = ~(state[0]|state[1]|state[2]|state[3]|state[4]|state[5]);

	wire		inst_checked;
	assign		inst_checked=(state[2] & ~stall[2]);

	wire	[15:0]		memdata;
	assign		memdata=memdataout;

	reg	[15:0]	IntVec;
	reg	[1:0]	ld_vec;

	always@(negedge clk or posedge reset)begin
		if(reset)begin
			process<=2'b00;
			process_step<=2'b00;
			state<=6'b0;
			pc<=15'h0060;
			saved_USP<=16'b0;
			saved_SSP<=16'h3000;
			Priv<=1;
			Priority<=3'b000;
			CC<=3'b000;
			EXC<=0;
		end else begin
			process<=process_next;
			process_step<=process_step_next;
			state<=state_next;

/*			if(ld_pc==2'b01)
				pc<=aluout;
			else */if(ld_pc==2'b10)
				pc<=memdata;
			else if( (inst_checked) ) 
				pc<=Checked_pc;

			if(ld_vec[1])
				{IntVec,Priority_tmp}<={ExtINTvec,3'b001};
			else if(ld_vec[0])
				{IntVec,Priority_tmp}<={IntINTvec,3'b010};

			if(ld_PSR)	begin
				CC<=memdata[2:0];
				Priv<=memdata[15];
				Priority<=memdata[10:8];
			end else if (setCC[2]&inst_checked)begin
				CC<=CCin;
			end else if (~setCC[3]&inst_ld[4]&state[4]) begin
				CC<=CCinM;
			end

			if(process==2'b10)
				EXC<=1;
			
			if( (process==2'b10)&&(process_step==3'b010) )
				Priority<=Priority_tmp;
		end
	end


	/*pipeline state*/


	reg	TRAPvalid,UND_RTIEvalid,RTIvalid;


	
	always@(*)begin
		if(inst_checked)	begin
			case (Errtype)
				2'b01:begin
					{TRAPvalid,UND_RTIEvalid,RTIvalid}=3'b100;
					ld_vec=2'b01;
				end
				2'b10:begin
					{TRAPvalid,UND_RTIEvalid,RTIvalid}={1'b0,~Priv,Priv};
					ld_vec=2'b01;
				end
				2'b11:begin
					{TRAPvalid,UND_RTIEvalid,RTIvalid}=3'b010;
					ld_vec=2'b01;
				end
				default:begin
					{TRAPvalid,UND_RTIEvalid,RTIvalid}=3'b000;
					ld_vec={INTvalid&(process==2'b00),1'b0};
				end
			endcase
		end else begin
			{TRAPvalid,UND_RTIEvalid,RTIvalid}=3'b000;
			ld_vec={INTvalid&(process==2'b00),1'b0};
		end
	end

	always@(*)begin
		case(process)
			2'b00:
				begin
					state_next[5]=(state[4]&~stall[4])|(state[5]&stall[5]);	//never stalled
					state_next[4]=(state[3]&~stall[3])|(state[4]&stall[4]);	//never stalled
					if(TRAPvalid) 	begin
						state_next[3]=(state[2]&~stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=state[2]& stall[2];
						state_next[1:0]=2'b0;
						process_next=2'b01;	//TRAP
						process_step_next=3'b0;
					end
					else if(UND_RTIEvalid)	begin
						state_next[3]=(state[2]&~stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=state[2]&stall[2];
						state_next[1:0]=2'b0;
						process_next=2'b10;
						process_step_next=3'b0;
					end
					else if(RTIvalid)	begin
						state_next[3]=(state[2]&~stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=state[2]&stall[2];
						state_next[1:0]=2'b0;
						process_next=2'b11;	//RTI
						process_step_next=3'b0;
					end
					else if(Forcast_fail)	begin
						state_next[3]=(state[2]&~stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=state[2]&stall[2];
						state_next[1:0]=2'b01;
						process_next=2'b00;
						process_step_next=3'b0;
					end
					else if(INTvalid)	begin
						state_next[3]=(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=state[2]&stall[2];
						state_next[1:0]=2'b0;	//punish
						process_next=2'b10;	//INT,UND,RTIerr
						process_step_next=3'b0;
					end
					else begin
						state_next[3]=(state[2]&~stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=(state[1]&!stall[1])|(state[2]&stall[2]);	//stalled when waiting data or pipeline3 stalled
						state_next[1]=(state[0]&!stall[0])|(state[1]&stall[1]);	//stalled when pipeline2 stalled
						state_next[0]=1;					//stalled or new inst
						process_next=2'b00;
						process_step_next=3'b0;
					end
				end
			2'b01:
				begin
					if(pipeline_empty)	begin
						process_next=2'b00;
						process_step_next=3'b000;
						state_next=6'b000001;
					end else begin
						state_next[5]=(state[4]&!stall[4])|(state[5]&stall[5]);	//never stalled
						state_next[4]=(state[3]&!stall[3])|(state[4]&stall[4]);	//never stalled
						state_next[3]=(state[2]&!stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=(state[1]&!stall[1])|(state[2]&stall[2]);	//stalled when waiting data or pipeline3 stalled
						state_next[1:0]=2'b00;
						process_next=2'b01;
						process_step_next=3'b0;
					end
				end
			2'b10:
				begin
					if(pipeline_empty) begin
						case(process_step)
							3'b000:
								begin
									process_next=2'b10;
									process_step_next=3'b001;
									state_next=6'b000000;
								end
							3'b001:
								begin
									process_next=2'b10;
									process_step_next=3'b010;
									state_next=6'b000000;
								end
							3'b010:
								begin
									process_next=2'b00;
									process_step_next=3'b000;
									state_next=6'b000001;
								end
							default:
								begin
									process_next=2'b00;
									process_step_next=3'b000;
									state_next=6'b000001;
								end
						endcase
					end else begin
						state_next[5]=(state[4]&!stall[4])|(state[5]&stall[5]);	//never stalled
						state_next[4]=(state[3]&!stall[3])|(state[4]&stall[4]);	//never stalled
						state_next[3]=(state[2]&!stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=(state[1]&!stall[1])|(state[2]&stall[2]);	//stalled when waiting data or pipeline3 stalled
						state_next[1:0]=2'b00;
						process_next=2'b10;
						process_step_next=3'b0;
					end
				end
			2'b11:
				begin
					if(pipeline_empty) begin
						case(process_step)
							3'b000:
								begin
									process_next=2'b11;
									process_step_next=3'b001;
									state_next=6'b000000;
								end
							3'b001:
								begin
									process_next=2'b11;
									process_step_next=3'b010;
									state_next=6'b000000;
								end
							3'b010:
								begin
									process_next=2'b00;
									process_step_next=3'b000;
									state_next=6'b000001;
								end
							default:
								begin
									process_next=2'b00;
									process_step_next=3'b000;
									state_next=6'b000001;
								end
								
						endcase
					end else begin
						state_next[5]=(state[4]&!stall[4])|(state[5]&stall[5]);	//never stalled
						state_next[4]=(state[3]&!stall[3])|(state[4]&stall[4]);	//never stalled
						state_next[3]=(state[2]&!stall[2])|(state[3]&stall[3]);	//stalled when waiting memory
						state_next[2]=(state[1]&!stall[1])|(state[2]&stall[2]);	//stalled when waiting data or pipeline3 stalled
						state_next[1:0]=2'b00;
						process_next=2'b11;
						process_step_next=3'b0;
					end
				end
		endcase
	end


	reg			int_memapply;
	reg	[15:0]	int_memaddr;
	reg			int_mem_rw;
	reg	[15:0]	int_mem_data;
	/*datapath control signal ld_pc fsm_regwr int_mem*/

	always@(*)begin
		case(process)
			2'b00:	
				begin
					int_memapply=0;
					fsm_regctl={1'b0,19'bx};
					if(Forcast_fail)	
						ld_pc=2'b01;
					else if(stall[0])
						ld_pc=2'b11;
					else if(pipeline_empty)
						ld_pc=2'b11;
					else
						ld_pc=2'b00;
				end
			2'b01:
				begin
					if(pipeline_empty) begin
							int_memapply=1;
								int_memaddr=IntVec;
								int_mem_rw=0;
								int_mem_data=16'bx;
							fsm_regctl={1'b1,3'b111,pc};
							ld_pc=2'b10;				//pipeline0 ld pc from memory
					end else begin
							int_memapply=0;
							fsm_regctl={1'b0,19'bx};
							ld_pc=2'b11;
					end
							
				end

				
			2'b10:
				begin
					if(pipeline_empty) begin
						case(process_step)
							3'b000:
								begin
									int_memapply=1;
										int_memaddr=SP-1;
										int_mem_rw=1;
										int_mem_data=PSR;
									fsm_regctl[19:16]={1'b1,3'b110};
									fsm_regctl[15:0] =SP-1;
									ld_pc=2'b11;
								end
							3'b001:
								begin
									int_memapply=1;
										int_memaddr=SP-1;
										int_mem_rw=1;
										int_mem_data=pc;
									fsm_regctl[19:16]={1'b1,3'b110};
									fsm_regctl[15:0] =SP-1;
									ld_pc=2'b11;			//PC not changed
								end
							3'b010:
								begin
									int_memapply=1;
										int_memaddr=IntVec;
										int_mem_rw=0;
										int_mem_data=16'bx;
									fsm_regctl={1'b0,19'bx}; 
									ld_pc=2'b10;			//pipeline0 ld pc from memory	
								end
							default:
								begin
									int_memapply=0;
									fsm_regctl={1'b0,19'bx};
									ld_pc=2'b11;
								end
						endcase
					end else begin
						int_memapply=0;
						fsm_regctl={1'b0,19'bx};
						ld_pc=2'b11;
					end
				end
			2'b11:
				begin
					if(pipeline_empty) begin
						case(process_step)
							3'b000:
								begin
									int_memapply=1;
										int_memaddr=SP;
										int_mem_rw=0;
										int_mem_data=16'bz;
									fsm_regctl[19:16]={1'b1,3'b110};
									fsm_regctl[15:0] =SP+1;
									ld_pc=2'b10;
								end
							3'b001:
								begin
									int_memapply=1;
										int_memaddr=SP;
										int_mem_rw=0;
										int_mem_data=16'bz;
									fsm_regctl[19:16]={1'b1,3'b110};
									fsm_regctl[15:0] =SP+1;
									ld_pc=2'b11;			
								end
							3'b010:
								begin
									int_memapply=0;
									fsm_regctl={1'b0,19'bx};
									ld_pc=2'b11;			//pc not changed	
								end
							default:
								begin
									int_memapply=0;
									fsm_regctl={1'b0,19'bx};
									ld_pc=2'b11;
								end
						endcase
					end else begin
						int_memapply=0;
						fsm_regctl={1'b0,19'bx};
						ld_pc=2'b00;
					end
				end
		endcase

	end

	/*mem ctl*/

	always@(*) begin 
		if(memapply[2] & state[4])	begin
			memload=3'b100;
			mem_rw=memtype;
			memaddrout=memaddrin2;
			memdataout=(memtype?memdatain:16'bz);
		end else if (memapply[1] & state[3]) begin
			memload=3'b010;
			mem_rw=0;
			memaddrout=memaddrin1;
			memdataout=16'bz;
		end else if (memapply[0] & state[0]) begin
			memload=3'b001;
			mem_rw=0;
			memaddrout=memaddrin0;
			memdataout=16'bz;
		end else if (int_memapply) begin
			memload=3'b000;
			mem_rw=int_mem_rw;
			memaddrout=int_memaddr;
			memdataout=(int_mem_rw?int_mem_data:16'bz);
		end else begin
			memload=3'b000;
			mem_rw=0;
			memaddrout=16'bx;
			memdataout=16'bz;
		end
	end

	/*stall*/
	
	wire	waitdata;

	always@(*)begin
		stall[5]=0;		//never stalled
		stall[4]=0;		//never stalled
		if (memapply[1] & memapply[2] ) 
			stall[3]=1;	//wait memory
		else 
			stall[3]=0;

		if (waitdata | stall[3])
			stall[2]=1;
		else
			stall[2]=0;

		if (stall[2])
			stall[1]=1;
		else
			stall[1]=0;

		if (stall[1] | (memapply[0] & (memload!=3'b001) ) )
			stall[0]=1;
		else
			stall[0]=0;

	end

	/*waitdata*/
	wire	[4:3]	loading;
	assign		loading[4]=state[4] & inst_ld[4];
	assign		loading[3]=state[3] & inst_ld[3];
	reg		waitSR;
	reg		waitCC;
	assign		waitdata=waitSR|waitCC;

	always@(*)begin
		if(!state[2])	begin
			waitSR=0;
		end
		else	begin
			if(loading==2'b00)
				waitSR=0;
			else if(loading[4]) begin
				if(sr1[19]&& (dr4[18:16]==sr1[18:16]) )
					waitSR=1;
				else if(sr2[19] && (dr4[18:16]==sr2[18:16]) )
					waitSR=1;
				else if(dr2[19] && (dr4[18:16]==dr2[18:16]) )
					waitSR=1;
				else 
					waitSR=0;
			end
			else if(loading[3]) begin
				if(sr1[19]&& (dr3[18:16]==sr1[18:16]) )
					waitSR=1;
				else if(sr2[19] && (dr3[18:16]==sr2[18:16]) )
					waitSR=1;
				else if(dr2[19] && (dr3[18:16]==dr2[18:16]) )
					waitSR=1;
				else 
					waitSR=0;
			end else
				waitSR=0;
		end

	end

	always@(*)begin
		if(!state[2])	begin
			waitCC=0;
		end
		else if(!NeedCC)	begin
			waitCC=0;
		end
		else	begin
			if(loading==2'b00)
				waitCC=0;
			else 
				waitCC=1;
		end
	end



endmodule
