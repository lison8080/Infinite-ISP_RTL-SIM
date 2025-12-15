/*************************************************************************
> File Name: vip_hist_equ.v
> Description: Histogram equalization
> Author: https://github.com/bxinquan
************************************************************************/
`timescale 1ns / 1ps

/*
 * VIP - Histogram Equalization
 */ 

module vip_hist_equ
#(
	parameter BITS = 8,
	parameter WIDTH = 640,
	parameter HEIGHT = 480
)
(
	input pclk,
	input rst_n,

	input [BITS-1:0] equ_min,
	input [BITS-1:0] equ_max,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data
);

	localparam PIX_TOTAL = WIDTH * HEIGHT;
	localparam HIST_BITS = clogb2(PIX_TOTAL);
    
	// Register to hold the previous value of vsync signal for edge detection
	reg prev_vsync;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_vsync <= 0;
		else
			prev_vsync <= in_vsync;
	end
     
	// Registers for tracking the state of the histogram summation process
	reg hist_sum_done;
	reg [BITS-1:0] hist_addr;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			hist_sum_done <= 0;
			hist_addr <= 0;
		end
		else if (in_vsync & ~prev_vsync) begin
			hist_sum_done <= 0;
			hist_addr <= 0;
		end
		else if (!hist_sum_done) begin
			hist_addr <= hist_addr + 1'b1;
			if (hist_addr == {BITS{1'b1}})
				hist_sum_done <= 1'b1;
			else
				hist_sum_done <= hist_sum_done;
		end
		else begin
			hist_sum_done <= hist_sum_done;
			hist_addr <= hist_addr;
		end
	end
 
    // Histogram data output from the histogram statistic module
	wire [HIST_BITS-1:0] hist_data;
	hist_stat #(BITS, HIST_BITS) hist_ram_data (
			.in_clk(pclk),
			.in_rst_n(rst_n),
			.in_valid(in_href),
			.in_vsync(in_vsync),
			.in_addr(in_data),
			.out_clk(pclk),
			.out_en(~hist_sum_done),
			.out_addr(hist_addr),
			.out_data(hist_data)
		);

    // Pipeline stage 0 for histogram
	reg hist_sum_runn_0;
	reg [BITS-1:0] hist_sum_addr_0;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			hist_sum_runn_0 <= 0;
			hist_sum_addr_0 <= 0;
		end
		else if (hist_sum_done) begin
			hist_sum_runn_0 <= 0;
			hist_sum_addr_0 <= 0;
		end
		else begin
			hist_sum_runn_0 <= 1;
			hist_sum_addr_0 <= hist_addr;
		end
	end
    
	// Pipeline stage 1 for histogram summation process
	reg hist_sum_runn_1;
	reg [BITS-1:0] hist_sum_addr_1;
	reg [HIST_BITS-1:0] hist_sum_data_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			hist_sum_runn_1 <= 0;
			hist_sum_addr_1 <= 0;
			hist_sum_data_1 <= 0;
		end
		else begin
			hist_sum_runn_1 <= hist_sum_runn_0;
			hist_sum_addr_1 <= hist_sum_addr_0;
			if (hist_sum_runn_0)
				hist_sum_data_1 <= hist_sum_data_1 + hist_data;
			else
				hist_sum_data_1 <= 0;
		end
	end
    
	// Pipeline stage 2 for histogram, calculation of range
	reg hist_sum_runn_2;
	reg [BITS-1:0] hist_sum_addr_2;
	reg [HIST_BITS+BITS-1:0] hist_sum_data_2;
	reg [BITS-1:0] equ_range_r;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			hist_sum_runn_2 <= 0;
			hist_sum_addr_2 <= 0;
			hist_sum_data_2 <= 0;
			equ_range_r     <= 0;
		end
		else begin
			hist_sum_runn_2 <= hist_sum_runn_1;
			hist_sum_addr_2 <= hist_sum_addr_1;
			hist_sum_data_2 <= hist_sum_data_1 * equ_range_r;
			equ_range_r     <= equ_max - equ_min;
		end
	end

    // Pipeline stage 3 for histogram, division
	reg            hist_sum_runn_3 [HIST_BITS+BITS-1:0];//div_hist_sum_3会延迟HIST_BITS+BITS拍, 这里同步打拍
	reg [BITS-1:0] hist_sum_addr_3 [HIST_BITS+BITS-1:0];//div_hist_sum_3会延迟HIST_BITS+BITS拍, 这里同步打拍
	wire [HIST_BITS+BITS-1:0] hist_sum_data_3;
	always @ (posedge pclk or negedge rst_n) begin : _blk_hist_sum_3
		integer i;
		if (!rst_n) begin
			for (i = 0; i < HIST_BITS+BITS; i = i + 1) begin
				hist_sum_runn_3[i] <= 0;
				hist_sum_addr_3[i] <= 0;
			end
		end
		else begin
			hist_sum_runn_3[0] <= hist_sum_runn_2;
			hist_sum_addr_3[0] <= hist_sum_addr_2;
			for (i = 1; i < HIST_BITS+BITS; i = i + 1) begin
				hist_sum_runn_3[i] <= hist_sum_runn_3[i-1];
				hist_sum_addr_3[i] <= hist_sum_addr_3[i-1];
			end
		end
	end

	// Division module for histogram data
	shift_div_uint #(HIST_BITS+BITS) div_hist_sum_3 (
						.clk(pclk), .rst_n(rst_n),
						.num(hist_sum_data_2), .den(PIX_TOTAL),
						.quo(hist_sum_data_3), .rem());

	// Register to hold write enable, address, and data for histogram RAM
	reg hist_ram_wen;
	reg [BITS-1:0] hist_ram_waddr;
	reg [BITS-1:0] hist_ram_wdata;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			hist_ram_wen <= 0;
			hist_ram_waddr <= 0;
			hist_ram_wdata <= 0;
		end
		else begin
			hist_ram_wen <= hist_sum_runn_3[HIST_BITS+BITS-1];
			hist_ram_waddr <= hist_sum_addr_3[HIST_BITS+BITS-1];
			hist_ram_wdata <= hist_sum_data_3[BITS-1:0] + equ_min;
		end
	end

    // Dual-port RAM for histogram mapping
	wire [BITS-1:0] hist_q;
	simple_dp_ram #(BITS, BITS) hist_map_ram (
			.clk(pclk),
			.wen(hist_ram_wen),
			.waddr(hist_ram_waddr),
			.wdata(hist_ram_wdata),
			.ren(in_href),
			.raddr(in_data),
			.rdata(hist_q)
		);

    // Assigning output
	reg href_r, vsync_r;
	always @ (posedge pclk) {href_r, vsync_r} <= {in_href, in_vsync};
	assign {out_href, out_vsync} = {href_r, vsync_r};
	assign out_data = out_href ? hist_q : {BITS{1'b0}};
 
    // Function to calculate the number of bits required to represent a given depth
	function integer clogb2;
	input integer depth;
	begin
		for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
			depth = depth >> 1;
	end
	endfunction
endmodule
