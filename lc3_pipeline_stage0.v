module lc3_pipeline_stage0(
	input			reset,
	input			clk,
	input			stall,
	input		[5:0]	state,

	input		[15:0]	memdata,
	input			memload,
	output			memapply,

	input		[1:0]	ld_pc,
	input		[15:0]	alu_out,
	output		[15:0]	forcast_pc,
	
	output	reg	[15:0]	pc,
	output		[15:0]	npc,
	output		[15:0]	inst
);



	reg			finished;
	reg			finished_next;
	reg		[15:0]	pc_next;
	reg		[15:0]	inst_tmp;

	assign			inst=(finished?inst_tmp:memdata);
	assign			npc=pc+1;

	always@(negedge clk or posedge reset)	begin
		if(reset)	begin
			inst_tmp<=16'b0;
			pc<=16'h0060;
			finished<=0;
		end else begin
			finished <= finished_next; 
			if(memload)
				inst_tmp<=memdata;
			pc <= pc_next;
		end
	end

	assign	memapply=state[0] & ~finished;


	always@(*)	begin
		case(ld_pc)	
			2'b00:
			begin
				pc_next = forcast_pc;
			end
			2'b01:
			begin
				pc_next = alu_out;
			end
			2'b10:
			begin
				pc_next = memdata;
			end
			2'b11:
			begin
				pc_next = pc;
			end
		endcase
	end

	always@(*)	begin
		if(state[0] & memload &stall)
			finished_next=1;
		else
			finished_next=0;
	end


	/*TODO branch detect & forcast*/
	assign			forcast_pc=pc+1;
endmodule
