module lc3_pipeline_stage3(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[19:0]	I_DR,
	input		[1:0]	I_WBtype,
	input		[2:0]	I_Memtype,
	input		[15:0]	I_aluout,
	input			I_setCC,

	output	reg	[19:0]	O_DR,
	output	reg	[1:0]	O_WBtype,
	output	reg	[2:0]	O_Memtype,
	output		[15:0]	O_Res,

	input		[15:0]	memdata,
	output		[15:0]	memaddr,
	output			memapply,
	output	reg		setCC,
	output			inst_ld
);

	reg		[15:0]	aluout;
	assign			memaddr=aluout;

	always@(negedge clk or posedge reset)	begin
		if(reset)	begin
			//seems nothing to do
		end else if(~stall)	begin
			O_DR <= {I_WBtype[1],I_DR[18:0]};
			O_WBtype <= I_WBtype;
			O_Memtype <= I_Memtype;
			aluout	<= I_aluout;
			setCC  <= I_setCC;
		end
	end

	assign			memapply = (state[3] &( O_Memtype[2:1]==2'b11) );
	assign			O_Res	 = (memapply?memdata:aluout);
	assign			inst_ld  = (O_Memtype[2]&~O_Memtype[0]);
endmodule
	
