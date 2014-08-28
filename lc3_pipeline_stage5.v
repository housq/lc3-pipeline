module	lc3_pipeline_stage5(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[19:0]	I_DR,
	input		[1:0]	I_WBtype,
	input		[15:0]	I_Res,

	output		[19:0]	O_WBctl
);

	reg		[19:0]	DR;
	reg		[1:0]	WBtype;
	reg		[15:0]	Res;

	always@(negedge clk or posedge reset)	begin
		if(reset)	begin
			//nothing to do 
		end else if(~stall)	begin
			DR<=I_DR;
			WBtype<=I_WBtype;
			Res<=I_Res;
		end
	end

	wire			wben;
	assign			wben=WBtype[1]&state[5];
	wire		[15:0]	wbdata;
	assign			wbdata=( WBtype[0]?DR[15:0]:Res );
	wire		[2:0]	wbreg;
	assign			wbreg=DR[18:16];

	assign			O_WBctl={wben,wbreg,wbdata};
	
endmodule
	
