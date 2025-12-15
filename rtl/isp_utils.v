/*************************************************************************
> File Name: isp_utils.v
> Description: utils
> Author: https://github.com/bxinquan
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Utils Library
 */

/* Simple Dual-Port RAM */
module simple_dp_ram
#(
	parameter DW = 8,
	parameter AW = 4,
	parameter SZ = 2**AW
)
(
	input           clk,
	input           wen,
	input  [AW-1:0] waddr,
	input  [DW-1:0] wdata,
	input           ren,
	input  [AW-1:0] raddr,
	output [DW-1:0] rdata
);
	integer i;
	reg [DW-1:0] mem [SZ-1:0];
	
	initial begin
	for ( i =0 ; i<SZ ; i=i+1)
	     mem[i]=2**DW-1-i;
	end
	
	always @ (posedge clk) begin
		if (wen) begin
			mem[waddr] <= wdata;
		end
	end
	reg [DW-1:0] q;
	always @ (posedge clk) begin
		if (ren) begin
			q <= mem[raddr];
		end
	end
	assign rdata = q;
endmodule

/* Full/True Dual-Port RAM */
module full_dp_ram
#(
	parameter DW = 8,
	parameter AW = 4,
	parameter SZ = 2**AW
)
(
	input           clk_a,
	input           wen_a,
	input           ren_a,
	input  [AW-1:0] addr_a,
	input  [DW-1:0] wdata_a,
	output [DW-1:0] rdata_a,
	input           clk_b,
	input           wen_b,
	input           ren_b,
	input  [AW-1:0] addr_b,
	input  [DW-1:0] wdata_b,
	output [DW-1:0] rdata_b
);
	reg [DW-1:0] mem [SZ-1:0];
	reg [DW-1:0] q_a;
	always @ (posedge clk_a) begin
		if (wen_a) begin
			mem[addr_a] <= wdata_a;
		end
		if (ren_a) begin
			q_a <= mem[addr_a];
		end
	end
	reg [DW-1:0] q_b;
	always @ (posedge clk_b) begin
		if (wen_b) begin
			mem[addr_b] <= wdata_b;
		end
		if (ren_b) begin
			q_b <= mem[addr_b];
		end
	end
	assign rdata_a = q_a;
	assign rdata_b = q_b;
endmodule

/* Full/True Dual-Port RAM with initialization */
module full_dp_ram_init
#(
	parameter DW = 8,
	parameter AW = 4,
	parameter SZ = 2**AW,
	parameter INIT_FILE = "memory_data.txt" // infinite-isp has a python notebook for this
	
)
(
	input           clk_a,
	input           wen_a,
	input           ren_a,
	input  [AW-1:0] addr_a,
	input  [DW-1:0] wdata_a,
	output [DW-1:0] rdata_a,
	input           clk_b,
	input           wen_b,
	input           ren_b,
	input  [AW-1:0] addr_b,
	input  [DW-1:0] wdata_b,
	output [DW-1:0] rdata_b
);
	
	
	reg [DW-1:0] mem [SZ-1:0];
	
	initial begin
	 $readmemb(INIT_FILE, mem);
	 end
	
	reg [DW-1:0] q_a;
	always @ (posedge clk_a) begin
		if (wen_a) begin
			mem[addr_a] <= wdata_a;
		end
		if (ren_a) begin
			q_a <= mem[addr_a];
		end
	end
	reg [DW-1:0] q_b;
	always @ (posedge clk_b) begin
		if (wen_b) begin
			mem[addr_b] <= wdata_b;
		end
		if (ren_b) begin
			q_b <= mem[addr_b];
		end
	end
	assign rdata_a = q_a;
	assign rdata_b = q_b;
endmodule

/* Shift Register based on Simple Dual-Port RAM */
module shift_register
#(
	parameter BITS = 8,
	parameter WIDTH = 10,
	parameter LINES = 3
)
(
	input                clock,
	input                clken,
	input  [BITS-1:0]    shiftin,
	output [BITS-1:0]    shiftout,
	output [BITS*LINES-1:0] tapsx
);

	localparam RAM_SZ = WIDTH - 1;
	localparam RAM_AW = clogb2(RAM_SZ);

	reg [RAM_AW-1:0] pos_r;
	
	wire [RAM_AW-1:0] pos = pos_r < RAM_SZ ? pos_r : (RAM_SZ[RAM_AW-1:0] - 1'b1);
	always @ (posedge clock) begin
		if (clken) begin
			if (pos_r < RAM_SZ - 1)
				pos_r <= pos_r + 1'b1;
			else
				pos_r <= 0;
		end
	end

	reg [BITS-1:0] in_r;
	always @ (posedge clock) begin
		if (clken) begin
			in_r <= shiftin;
		end
	end
	wire [BITS-1:0] line_out[LINES-1:0];
	generate
		genvar i;
		for (i = 0; i < LINES; i = i + 1) begin : gen_ram_inst
			if (i == 0) begin
				simple_dp_ram #(BITS, RAM_AW, RAM_SZ) u_ram(clock, clken, pos, in_r, clken, pos, line_out[i]);
			end else begin
				simple_dp_ram #(BITS, RAM_AW, RAM_SZ) u_ram(clock, clken, pos, line_out[i-1], clken, pos, line_out[i]);
			end
		end
	endgenerate

	assign shiftout = line_out[LINES-1];
	generate
		genvar j;
		for (j = 0; j < LINES; j = j + 1) begin : gen_taps_assign
			assign tapsx[(BITS*j)+:BITS] = line_out[j];
		end
	endgenerate

	function integer clogb2;
	input integer depth;
	begin
		for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
			depth = depth >> 1;
	end
	endfunction
endmodule


/* Common clock FIFO */
module sync_fifo
#(
	parameter DW = 8,
	parameter AW = 4
)
(
	input           clk,
	input           rst_n,
	input           wen,
	input  [DW-1:0] wdata,
	output          wfull,
	input           ren,
	output [DW-1:0] rdata,
	output          rempty
);

	reg [AW:0] waddr;
	reg [AW:0] raddr;

	assign rempty = (waddr == raddr);
	assign wfull  = (waddr[AW] != raddr[AW]) && (waddr[AW-1:0] == raddr[AW-1:0]);

	wire wr_flag = !wfull & wen;
	wire rd_flag = !rempty & ren;

	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n)
			waddr <= 0;
		else if (wr_flag)
			waddr <= waddr + 1'b1;
		else
			waddr <= waddr;
	end

	always @ (posedge clk or negedge rst_n) begin
		if (!rst_n)
			raddr <= 0;
		else if (rd_flag)
			raddr <= raddr + 1'b1;
		else
			raddr <= raddr;
	end

	simple_dp_ram #(
			.DW       (DW),
			.AW       (AW)
		) ram (
			.clk      (clk),
			.wen      (wr_flag),
			.waddr    (waddr[AW-1:0]),
			.wdata    (wdata),
			.ren      (rd_flag),
			.raddr    (raddr[AW-1:0]),
			.rdata    (rdata)
		);

endmodule


/* Independent clock FIFO */
module async_fifo
#(
	parameter DW = 8,
	parameter AW = 4
)
(
	input           wclk,
	input           rclk,
	input           wrstn,
	input           rrstn,
	input           wen,
	input [DW-1:0]  wdata,
	output          wfull,
	input           ren,
	output [DW-1:0] rdata,
	output          rempty
);

	reg [AW:0] waddr;
	reg [AW:0] raddr;

	//sync_w2r
	reg [AW:0] wptr ; //= waddr ^ {1'b0, waddr[AW:1]}; //Gray Code
	(* ASYNC_REG="true" *) reg  [AW:0] w2r_wptr1, w2r_wptr2;
	always @ (posedge rclk or negedge rrstn) begin
		if (!rrstn) begin
			w2r_wptr1 <= 0;
			w2r_wptr2 <= 0;
		end
		else begin
			w2r_wptr1 <= wptr;
			w2r_wptr2 <= w2r_wptr1;
		end
	end
	

	//sync_r2w
	reg [AW:0] rptr ; //= raddr ^ {1'b0, raddr[AW:1]}; //Gray Code
	(* ASYNC_REG="true" *) reg  [AW:0] r2w_rptr1, r2w_rptr2;
	always @ (posedge wclk or negedge wrstn) begin
		if (!wrstn) begin
			r2w_rptr1 <= 0;
			r2w_rptr2 <= 0;
		end
		else begin
			r2w_rptr1 <= rptr;
			r2w_rptr2 <= r2w_rptr1;
		end
	end
	

	//status
	assign rempty = (w2r_wptr2 == rptr);
	reg w_full_r;
	assign wfull  = w_full_r; //(wptr == {~r2w_rptr2[AW:AW-1], r2w_rptr2[AW-2:0]});

	wire wr_flag = !wfull & wen;
	wire rd_flag = !rempty & ren;
    wire [AW:0] waddr_inc = waddr + 1;
    
    always @ (posedge wclk or negedge wrstn) begin
		if (!wrstn) begin
			waddr <= 0;
			wptr <= 0;
			w_full_r <= 0;
			end
		else if (wr_flag) begin
			waddr <= waddr + 1'b1;
			wptr <= waddr_inc ^ {1'b0, waddr_inc[AW:1]};
			w_full_r <=  ((waddr_inc ^ {1'b0, waddr_inc[AW:1]}) == {~r2w_rptr2[AW:AW-1], r2w_rptr2[AW-2:0]});
			end
		else begin
			waddr <= waddr;
			wptr <= waddr ^ {1'b0, waddr[AW:1]};
			w_full_r <=  ((waddr ^ {1'b0, waddr[AW:1]}) == {~r2w_rptr2[AW:AW-1], r2w_rptr2[AW-2:0]});
			end
	end

    wire [AW:0] raddr_inc = raddr + 1;
	always @ (posedge rclk or negedge rrstn) begin
		if (!rrstn) begin
			raddr <= 0;
			rptr <= 0;
		    end
		else if (rd_flag) begin
			raddr <= raddr + 1'b1;
			rptr <= raddr_inc ^ {1'b0, raddr_inc[AW:1]}; 
			end 
		else begin
			raddr <= raddr;
			rptr <= raddr ^ {1'b0, raddr[AW:1]};
			end
	end

	full_dp_ram #(
			.DW          (DW),
			.AW          (AW)
		) ram (
			.clk_a       (wclk),
			.wen_a       (wr_flag),
			.ren_a       (1'b0),
			.addr_a      (waddr[AW-1:0]),
			.wdata_a     (wdata),
			.rdata_a     (),
			.clk_b       (rclk),
			.wen_b       (1'b0),
			.ren_b       (rd_flag),
			.addr_b      (raddr[AW-1:0]),
			.wdata_b     (8'b0),
			.rdata_b     (rdata)
		);

endmodule


// c = a / b
// d = a % b
module shift_div
#(
	parameter BITS = 32
)
(
	input clk,
	input rst_n,

	input enable,
	input [BITS-1:0] a, 
	input [BITS-1:0] b,

	output [BITS-1:0] c,
	output [BITS-1:0] d,
	output reg done
);

	reg[BITS-1:0] tempa;
	reg[BITS-1:0] tempb;
	reg[BITS*2-1:0] temp_a;
	reg[BITS*2-1:0] temp_b;

	reg [4:0] status /* synthesis syn_encoding="safe,onehot" */;
	localparam s_idle  = 5'b00001;
	localparam s_init  = 5'b00010;
	localparam s_calc1 = 5'b00100;
	localparam s_calc2 = 5'b01000;
	localparam s_done  = 5'b10000;

	reg[BITS-1:0] yshang;	//meet
	reg[BITS-1:0] yyushu;	//remainder
	assign c = yshang;
	assign d = yyushu;

	reg [BITS-1:0] i;
 
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			i <= 0;
			tempa <= 1;
			tempb <= 1;
			yshang <= 1;
			yyushu <= 1;
			done <= 0;
			status <= s_idle;
			temp_a <= 1;
			temp_b <= 1;
		end
		else begin
			case (status)
				s_idle: begin
					if (enable) begin
						i <= 0;
						tempa <= a;
						tempb <= b;
						yshang <= 1;
						yyushu <= 1;
						done <= 0;
						status <= s_init;
					end
					else begin
						i <= 0;
						tempa <= 1;
						tempb <= 1;
						yshang <= 1;
						yyushu <= 1;
						done <= 0;
						status <= s_idle;
					end
				end

				s_init: begin
					temp_a <= {{BITS{1'b0}},tempa};
					temp_b <= {tempb,{BITS{1'b0}}};
					status <= s_calc1;
				end

				s_calc1: begin
					if(i < BITS) begin
						temp_a <= {temp_a[BITS*2-2:0],1'b0};
						status <= s_calc2;
					end
					else begin
						status <= s_done;
					end
				end

				s_calc2: begin
					if(temp_a[BITS*2-1:BITS] >= tempb) begin
						temp_a <= temp_a - temp_b + 1'b1;
					end
					else begin
						temp_a <= temp_a;
					end
					i <= i + 1'b1;	
					status <= s_calc1;
				end

				s_done: begin
					yshang <= temp_a[BITS-1:0];
					yyushu <= temp_a[BITS*2-1:BITS];
					done <= 1'b1;
					status <= s_idle;
				end
				
				default: begin
					status <= s_idle;
				end
			endcase
		end
	end
endmodule

/*
def div32(a, b):
    a = a & 0xffffffff
    b = b << 32
    for i in range(32) :
        a = (a << 1) & 0xffffffffffffffff
        if a >= b :
            a = a - b + 1
    return (a & 0xffffffff, (a >> 32) & 0xffffffff)
*/

//???????????????????BITS
//quo = num // den;  rem = num % den;
module shift_div_uint
#(
	parameter BITS = 32
)
(
	input clk,
	input rst_n,

	input [BITS-1:0] num, //???
	input [BITS-1:0] den, //??
	
	output [BITS-1:0] quo, //?
	output [BITS-1:0] rem  //??
);

	//???&??buffer  ???BITS???? ???BITS????
	reg  [BITS*2-1:0] num_tmp [BITS-1:0];
	reg  [BITS*2-1:0] den_tmp [BITS-1:0];
	wire [BITS*2-1:0] num_tmp_in = {{BITS{1'b0}}, num};
	wire [BITS*2-1:0] den_tmp_in = {den, {BITS{1'b0}}};
	always @ (posedge clk or negedge rst_n) begin : _blk_run
		integer i;
		if (!rst_n) begin
			for (i = 0; i < BITS; i = i + 1) begin
				num_tmp[i] <= 0;
				den_tmp[i] <= 0;
			end
		end
		else begin
			if ({num_tmp_in[BITS*2-2:0],1'b0} >= den_tmp_in) begin
				num_tmp[0] <= {num_tmp_in[BITS*2-2:0],1'b1} - den_tmp_in;
				den_tmp[0] <= den_tmp_in;
			end
			else begin
				num_tmp[0] <= {num_tmp_in[BITS*2-2:0],1'b0};
				den_tmp[0] <= den_tmp_in;
			end
				
			for (i = 0; i < BITS - 1; i = i + 1) begin
				if ({num_tmp[i][BITS*2-2:0],1'b0} >= den_tmp[i]) begin
					num_tmp[i+1] <= {num_tmp[i][BITS*2-2:0],1'b1} - den_tmp[i];
					den_tmp[i+1] <= den_tmp[i];
				end
				else begin
					num_tmp[i+1] <= {num_tmp[i][BITS*2-2:0],1'b0};
					den_tmp[i+1] <= den_tmp[i];
				end
			end
		end
	end

	assign quo = num_tmp[BITS-1][BITS-1:0];
	assign rem = num_tmp[BITS-1][BITS*2-1:BITS];
endmodule

//histogram statistics(?????)
//ping&pong?RAM??,??????,???????
//?:in_vsync?????????(2**ADDR_BITS)?????????(in_valid??),????????????RAM??
module hist_stat
#(
	parameter ADDR_BITS = 8,
	parameter DATA_BITS = 24
)
(
	input in_clk,
	input in_rst_n,
	input in_valid, 
	input in_vsync, //????????????,?????????????
	input [ADDR_BITS-1:0] in_addr,

	input out_clk,
	input out_en,
	input [ADDR_BITS-1:0] out_addr,
	output [DATA_BITS-1:0] out_data
);

	//ping ram
	wire ping_clk, ping_wen, ping_ren;
	wire [ADDR_BITS-1:0] ping_waddr, ping_raddr;
	wire [DATA_BITS-1:0] ping_wdata, ping_rdata;
	simple_dp_ram #(DATA_BITS, ADDR_BITS) ping_ram(ping_clk, ping_wen, ping_waddr, ping_wdata, ping_ren, ping_raddr, ping_rdata);

	//ping ram
	wire pong_clk, pong_wen, pong_ren;
	wire [ADDR_BITS-1:0] pong_waddr, pong_raddr;
	wire [DATA_BITS-1:0] pong_wdata, pong_rdata;
	simple_dp_ram #(DATA_BITS, ADDR_BITS) pong_ram(pong_clk, pong_wen, pong_waddr, pong_wdata, pong_ren, pong_raddr, pong_rdata);
	
	//????RAM
	reg cur_ram; //0-????ping,????pong 1-????pong,????ping
	//??RAM???
	wire cur_clk, cur_wen, cur_ren;
	wire [ADDR_BITS-1:0] cur_waddr, cur_raddr;
	wire [DATA_BITS-1:0] cur_wdata, cur_rdata;
	//??RAM???
	wire bak_clk, bak_wen, bak_ren;
	wire [ADDR_BITS-1:0] bak_waddr, bak_raddr;
	wire [DATA_BITS-1:0] bak_wdata, bak_rdata;
	//??ping_ram?????
	assign {ping_clk,ping_wen,ping_ren,ping_waddr,ping_raddr,ping_wdata} = cur_ram
				? {bak_clk,bak_wen,bak_ren,bak_waddr,bak_raddr,bak_wdata}  /*????pong, ping????RAM*/
				: {cur_clk,cur_wen,cur_ren,cur_waddr,cur_raddr,cur_wdata}; /*????ping, ping????RAM*/
	//??pong_ram?????
	assign {pong_clk,pong_wen,pong_ren,pong_waddr,pong_raddr,pong_wdata} = cur_ram
				? {cur_clk,cur_wen,cur_ren,cur_waddr,cur_raddr,cur_wdata}  /*????pong, pong????RAM*/
				: {bak_clk,bak_wen,bak_ren,bak_waddr,bak_raddr,bak_wdata}; /*????pong, pong????RAM*/
	assign cur_rdata = cur_ram ? pong_rdata : ping_rdata; //????RAM???
	assign bak_rdata = cur_ram ? ping_rdata : pong_rdata; //????RAM???

	//?vsync??
	reg prev_vsync;
	always @ (posedge in_clk or negedge in_rst_n)
		if (!in_rst_n)
			prev_vsync <= 0;
		else
			prev_vsync <= in_vsync;

	//?????,????RAM,????RAM????
	reg cur_clr_done;
	reg [ADDR_BITS-1:0] cur_clr_addr;
	always @ (posedge in_clk or negedge in_rst_n) begin
		if (!in_rst_n) begin
			cur_ram <= 0;
			cur_clr_done <= 0;
			cur_clr_addr <= 0;
		end
		else if (in_vsync & ~prev_vsync) begin
			//??????
			cur_ram <= ~cur_ram; //????RAM
			cur_clr_done <= 0; //????RAM??
			cur_clr_addr <= 0; //???????
		end
		else if (!cur_clr_done) begin
			//???
			cur_ram <= cur_ram;
			cur_clr_addr <= cur_clr_addr + 1'b1;  //??????
			if (cur_clr_addr == {ADDR_BITS{1'b1}})
				cur_clr_done <= 1'b1; //?????????,??????
			else
				cur_clr_done <= cur_clr_done;
		end
		else begin
			//???
			cur_ram <= cur_ram;
			cur_clr_done <= cur_clr_done;
			cur_clr_addr <= cur_clr_addr;
		end
	end

    //??????(?????,??????+1??)

	//?????????RAM??(????)
	assign cur_clk = in_clk;
	assign cur_ren = in_valid;
	assign cur_raddr = in_addr;

	//???????
	reg cur_ren_r;
	always @ (posedge in_clk or negedge in_rst_n) begin
		if (!in_rst_n)
			cur_ren_r <= 0;
		else
			cur_ren_r <= cur_ren;
	end
	assign cur_wen = cur_clr_done ? cur_ren_r : 1'b1; //???????????, ????1

	//???????
	reg [ADDR_BITS-1:0] cur_raddr_r;
	always @ (posedge in_clk or negedge in_rst_n) begin
		if (!in_rst_n)
			cur_raddr_r <= 0;
		else
			cur_raddr_r <= cur_raddr;
	end
	assign cur_waddr = cur_clr_done ? cur_raddr_r : cur_clr_addr; //???????????, ??????????

	//???????
	reg                 cur_wen_r;   //?????
	reg [ADDR_BITS-1:0] cur_waddr_r; //?????
	reg [DATA_BITS-1:0] cur_wdata_r; //?????
	always @ (posedge in_clk or negedge in_rst_n) begin
		if (!in_rst_n) begin
			cur_wen_r   <= 0;
			cur_waddr_r <= 0;
			cur_wdata_r <= 0;
		end
		else begin
			cur_wen_r   <= cur_wen;
			cur_waddr_r <= cur_waddr;
			cur_wdata_r <= cur_wdata;
		end
	end
	assign cur_wdata = cur_clr_done ? (cur_wen_r && cur_raddr_r/*???????????*/ == cur_waddr_r/*??????*/
                                        ? cur_wdata_r + 1'b1 /*??????????+1(??RAM?first_read?????????,??????????????)*/
                                        : cur_rdata + 1'b1) /*????????????+1(?????????????????)*/
                                    : {DATA_BITS{1'b0}}; /*??????0*/  //???????????????

	//?????????RAM
	assign bak_clk = out_clk;
	assign bak_ren = out_en;
	assign bak_raddr = out_addr;
	assign out_data = bak_rdata;
	assign bak_wen = 1'b0;
	assign bak_waddr = 0;
	assign bak_wdata = 0;
endmodule
