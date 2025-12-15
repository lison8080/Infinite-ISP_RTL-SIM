/*************************************************************************
> File Name: isp_oecf.v
> Description: Implements the opto electronic conversion function as a LUT
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Opto Electronic Conversion Function
 */

module isp_oecf#
(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter R_LUT_INIT = "R_LUT.txt",
	parameter GR_LUT_INIT = "GR_LUT.txt",
	parameter GB_LUT_INIT = "GB_LUT.txt",
	parameter B_LUT_INIT = "B_LUT.txt"
	
)
(
	input pclk,
	input rst_n,

	//OECF R Tables tuning
	input               r_table_clk,
	input               r_table_wen,
	input               r_table_ren,
	input  [BITS-1:0] 	r_table_addr,
	input  [BITS-1:0] 	r_table_wdata,
	output [BITS-1:0] 	r_table_rdata,
	
	//OECF GR Tables tuning
	input               gr_table_clk,
	input               gr_table_wen,
	input               gr_table_ren,
	input  [BITS-1:0] 	gr_table_addr,
	input  [BITS-1:0] 	gr_table_wdata,
	output [BITS-1:0] 	gr_table_rdata,
	
	//OECF GB Tables tuning 
	input               gb_table_clk,
	input               gb_table_wen,
	input               gb_table_ren,
	input  [BITS-1:0] 	gb_table_addr,
	input  [BITS-1:0] 	gb_table_wdata,
	output [BITS-1:0] 	gb_table_rdata,
	
	//OECF B Tables tuning
	input               b_table_clk,
	input               b_table_wen,
	input               b_table_ren,
	input  [BITS-1:0] 	b_table_addr,
	input  [BITS-1:0] 	b_table_wdata,
	output [BITS-1:0] 	b_table_rdata,
	
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data
);

    // Tracking even/odd pixel for pixel's bayer detection
	reg odd_pix;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			odd_pix <= 0;
		else if (!in_href)
			odd_pix <= 0;
		else
			odd_pix <= ~odd_pix;
	end
	
	// Register the in_href value
	reg prev_href;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			prev_href <= 0;
		else
			prev_href <= in_href;
	end	
	
	// Tracking even/odd line for pixel's bayer detection
	reg odd_line;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			odd_line <= 0;
		else if (in_vsync)
			odd_line <= 0;
		else if (prev_href & (~in_href))
			odd_line <= ~odd_line;
		else
			odd_line <= odd_line;
	end

	wire [1:0] format = BAYER[1:0] ^ {odd_line, odd_pix}; //pixel format 0:[R]GGB 1:R[G]GB 2:RG[G]B 3:RGG[B]
	
	// Register the Bayer format
	reg  [1:0] format_reg;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			format_reg <=0;
		end
		else begin
			format_reg <= format;
		end
	end
	
	
		
   // R LUT 
	wire [BITS-1:0] r_table_out;
	full_dp_ram_init #(BITS,BITS,2**BITS,R_LUT_INIT) r_table_ram (
			.clk_a(r_table_clk),
			.wen_a(r_table_wen),
			.ren_a(r_table_ren),
			.addr_a(r_table_addr),
			.wdata_a(r_table_wdata),
			.rdata_a(r_table_rdata),
			.clk_b(pclk),
			.wen_b(1'b0),
			.ren_b(in_href),
			.addr_b(in_data),
			.wdata_b({BITS{1'b0}}),
			.rdata_b(r_table_out)
		);
	
	// GR LUT
	wire [BITS-1:0] gr_table_out;
	full_dp_ram_init #(BITS,BITS,2**BITS,GR_LUT_INIT) gr_table_ram (
			.clk_a(gr_table_clk),
			.wen_a(gr_table_wen),
			.ren_a(gr_table_ren),
			.addr_a(gr_table_addr),
			.wdata_a(gr_table_wdata),
			.rdata_a(gr_table_rdata),
			.clk_b(pclk),
			.wen_b(1'b0),
			.ren_b(in_href),
			.addr_b(in_data),
			.wdata_b({BITS{1'b0}}),
			.rdata_b(gr_table_out)
		);
	
   // GB LUT	
	wire [BITS-1:0] gb_table_out;
	full_dp_ram_init #(BITS,BITS,2**BITS,GB_LUT_INIT) gb_table_ram (
			.clk_a(gb_table_clk),
			.wen_a(gb_table_wen),
			.ren_a(gb_table_ren),
			.addr_a(gb_table_addr),
			.wdata_a(gb_table_wdata),
			.rdata_a(gb_table_rdata),
			.clk_b(pclk),
			.wen_b(1'b0),
			.ren_b(in_href),
			.addr_b(in_data),
			.wdata_b({BITS{1'b0}}),
			.rdata_b(gb_table_out)
		);
	
   // B LUT	
	wire [BITS-1:0] b_table_out;
	full_dp_ram_init #(BITS,BITS,2**BITS,B_LUT_INIT) b_table_ram (
			.clk_a(b_table_clk),
			.wen_a(b_table_wen),
			.ren_a(b_table_ren),
			.addr_a(b_table_addr),
			.wdata_a(b_table_wdata),
			.rdata_a(b_table_rdata),
			.clk_b(pclk),
			.wen_b(1'b0),
			.ren_b(in_href),
			.addr_b(in_data),
			.wdata_b({BITS{1'b0}}),
			.rdata_b(b_table_out)
		);

    // Apply Optical Electronic Conversion Function correction based on Bayer format
	reg [BITS-1:0] data_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_1 <= 0;
		end
		else begin
			case (format_reg)
			2'b00: begin data_1 <= r_table_out; end
			2'b01: begin data_1 <= gr_table_out; end
			2'b10: begin data_1 <= gb_table_out; end
			2'b11: begin data_1 <= b_table_out; end
			endcase
		end
	end
	
	// Adjusting for computation delay
	localparam DLY_CLK = 2;
	reg [DLY_CLK-1:0] href_dly;
	reg [DLY_CLK-1:0] vsync_dly;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			href_dly <= 0;
			vsync_dly <= 0;
		end
		else begin
			href_dly <= {href_dly[DLY_CLK-2:0], in_href};
			vsync_dly <= {vsync_dly[DLY_CLK-2:0], in_vsync};
		end
	end

	assign out_href = href_dly[DLY_CLK-1];
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_data = out_href ? data_1 : {BITS{1'b0}};		
		
endmodule
