module	lc3_pipeline_stage4(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[19:0]	I_DR,
	input		[1:0]	I_WBtype,
	input		[2:0]	I_Memtype,
	input		[15:0]	I_Res,

	output		[19:0]	O_DR,
	output	reg	[1:0]	O_WBtype,
	output		[15:0]	O_Res,

	input		[15:0]	memdata,
	output		[15:0]	memaddr,
	output			memtype,
	output		[15:0]	memdatawr,
	output			memapply,

	output	reg	[2:0]	CC,
	output			inst_ld
);
	
	reg		[15:0]	Res;
	reg		[19:0]	DR;
	reg		[2:0]	Memtype;
	assign			memdatawr=DR[15:0];
	assign			memaddr=Res;
	assign			memapply=Memtype[2]&state[4];
	assign			memtype=Memtype[0];
	assign			O_Res=( (memapply&~memtype)?memdata:Res );
	
	assign			O_DR=DR;

	always@(negedge clk or posedge reset)	begin
		if(reset) begin
			//nothing to do
		end else	begin
			if(~stall) begin
				DR<=I_DR;
				Res<=I_Res;
				Memtype<=I_Memtype;
				O_WBtype<=I_WBtype;
			end
		end
	end

	always@(*)	begin
		if(memdata==16'b0)
			CC=3'b010;
		else if(memdata[15]==1)
			CC=3'b100;
		else 
			CC=3'b001;
	end

	assign			inst_ld=Memtype[2]&~Memtype[0];

	

endmodule
