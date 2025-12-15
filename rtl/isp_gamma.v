/*************************************************************************
> File Name: isp_gamma.v
> Description: Implements the gamma look up table
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Gamma (Look-up table)
 */

module isp_gamma
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter R_LUT_INIT = "R_LUT.txt",
	parameter G_LUT_INIT = "G_LUT.txt",
	parameter B_LUT_INIT = "B_LUT.txt"
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data_r,
	input [BITS-1:0] in_data_g,
	input [BITS-1:0] in_data_b,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data_r,
	output [BITS-1:0] out_data_g,
	output [BITS-1:0] out_data_b,

	//Gamma
	
	input               cfg_table_r_clk,
	input               cfg_table_r_wen,
	input               cfg_table_r_ren,
	input  [BITS-1:0] 	cfg_table_r_addr,
	input  [BITS-1:0] 	cfg_table_r_wdata,
	output [BITS-1:0] 	cfg_table_r_rdata,
	
	input               cfg_table_g_clk,
	input               cfg_table_g_wen,
	input               cfg_table_g_ren,
	input  [BITS-1:0] 	cfg_table_g_addr,
	input  [BITS-1:0] 	cfg_table_g_wdata,
	output [BITS-1:0] 	cfg_table_g_rdata,
	
	input               cfg_table_b_clk,
	input               cfg_table_b_wen,
	input               cfg_table_b_ren,
	input  [BITS-1:0] 	cfg_table_b_addr,
	input  [BITS-1:0] 	cfg_table_b_wdata,
	output [BITS-1:0] 	cfg_table_b_rdata
);

	wire [BITS-1:0] q_r;
	wire [BITS-1:0] q_g;
	wire [BITS-1:0] q_b;

	// gamma look up table for r channel
	full_dp_ram_init #(BITS,BITS,2**BITS,R_LUT_INIT) table_ram_r (
		.clk_a(cfg_table_r_clk),
		.wen_a(cfg_table_r_wen),
		.ren_a(cfg_table_r_ren),
		.addr_a(cfg_table_r_addr),
		.wdata_a(cfg_table_r_wdata),
		.rdata_a(cfg_table_r_rdata),
		.clk_b(pclk),
		.wen_b(1'b0),
		.ren_b(in_href),
		.addr_b(in_data_r),
		.wdata_b({BITS{1'b0}}),
		.rdata_b(q_r)
	);
	
	// gamma look up table for g channel
	full_dp_ram_init #(BITS,BITS,2**BITS,G_LUT_INIT) table_ram_g (
		.clk_a(cfg_table_g_clk),
		.wen_a(cfg_table_g_wen),
		.ren_a(cfg_table_g_ren),
		.addr_a(cfg_table_g_addr),
		.wdata_a(cfg_table_g_wdata),
		.rdata_a(cfg_table_g_rdata),
		.clk_b(pclk),
		.wen_b(1'b0),
		.ren_b(in_href),
		.addr_b(in_data_g),
		.wdata_b({BITS{1'b0}}),
		.rdata_b(q_g)
	);
	
	// gamma look up table for b channel
	full_dp_ram_init #(BITS,BITS,2**BITS,B_LUT_INIT) table_ram_b (
		.clk_a(cfg_table_b_clk),
		.wen_a(cfg_table_b_wen),
		.ren_a(cfg_table_b_ren),
		.addr_a(cfg_table_b_addr),
		.wdata_a(cfg_table_b_wdata),
		.rdata_a(cfg_table_b_rdata),
		.clk_b(pclk),
		.wen_b(1'b0),
		.ren_b(in_href),
		.addr_b(in_data_b),
		.wdata_b({BITS{1'b0}}),
		.rdata_b(q_b)
	);
	
	reg [BITS-1:0] data_r, data_g, data_b;

	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r <= 0;
			data_g <= 0;
			data_b <= 0;
		end
		else begin
			data_r <= q_r;
			data_g <= q_g;
			data_b <= q_b;
		end
	end

	reg [1:0] href_dly;
	reg [1:0] vsync_dly;

	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			href_dly  <= 0;
			vsync_dly <= 0;
		end
		else begin
			href_dly  <= {href_dly[0], in_href};
			vsync_dly <= {vsync_dly[0], in_vsync};
		end
	end

	assign out_href  = href_dly[1];
	assign out_vsync = vsync_dly[1];
	assign out_data_r  = out_href ? data_r : {BITS{1'b0}};
	assign out_data_g  = out_href ? data_g : {BITS{1'b0}};
	assign out_data_b  = out_href ? data_b : {BITS{1'b0}};
	
endmodule
