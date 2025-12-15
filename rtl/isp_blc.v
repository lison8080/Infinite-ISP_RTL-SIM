/*************************************************************************
> File Name: isp_blc.v
> Description: Implements black level correction and image linearization
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Black Level Correction
 */

module isp_blc
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	
)
(
	input pclk,
	input rst_n,

	input [BITS-1:0] black_r,
	input [BITS-1:0] black_gr,
	input [BITS-1:0] black_gb,
	input [BITS-1:0] black_b,
	
	input linear_en,
	input [15:0] linear_r,
	input [15:0] linear_gr,
	input [15:0] linear_gb,
	input [15:0] linear_b,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_raw
);

	reg [15:0] linear_r_i, linear_gr_i, linear_gb_i, linear_b_i; 
	// Register the linearization factors 
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			linear_r_i <= 0;
			linear_gr_i <= 0;
			linear_gb_i <= 0;
			linear_b_i <= 0;
		end
		else begin
			linear_r_i <= linear_r;
			linear_gr_i <= linear_gr;
			linear_gb_i <= linear_gb;
			linear_b_i <= linear_b;
		end
	end
    
	// Tracking even/odd pixels for pixel's bayer detection
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
    
	// apply BLC
	reg [BITS-1:0] data_0;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			data_0 <= 0;
		else
			data_0 <= blc_sub(in_raw, format);
	end
	
	// apply linearization
	reg [BITS-1+16:0] data_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			data_1 <= 0;
		else
			data_1 <= linearize(data_0, format_reg);
	end
	
	// clipping
	reg [BITS-1:0] data_2;
	reg round;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_2 <= 0;
			round <= 0;
		end
		else begin
			data_2 <= data_1[BITS-1+16:14] > {BITS{1'b1}} ? {BITS{1'b1}} : data_1[BITS-1+14:14];
			round <= data_1[13];
		end
	end
	
	// rounding
	reg [BITS-1:0] data_3;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_3 <= 0;
		end
		else if (round == 1 & data_2 < {BITS{1'b1}}) begin
		        data_3 <= data_2 + 1'b1;
		end else begin
		        data_3 <= data_2;
		end
	end
	
	// Adjusting for computation delay
	 
	localparam DLY_CLK = 4;
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
	assign out_raw = out_href ? data_3 : {BITS{1'b0}};
	
	// BLC subtraction
	function [BITS-1:0] blc_sub;
		input [BITS-1:0] value;
		input [1:0] format;//0:R 1:Gr 2:Gb 3:B
		case (format)
			2'b00: blc_sub = value > black_r ? value - black_r : {BITS{1'b0}};
			2'b01: blc_sub = value > black_gr ? value - black_gr : {BITS{1'b0}};
			2'b10: blc_sub = value > black_gb ? value - black_gb : {BITS{1'b0}};
			2'b11: blc_sub = value > black_b ? value - black_b : {BITS{1'b0}};
			default: blc_sub = {BITS{1'b0}};
		endcase
	endfunction
	
	// Linearization by multiplication 
	function [BITS-1+16:0] linearize;
		input [BITS-1:0] value;
		input [1:0] format;//0:R 1:Gr 2:Gb 3:B
		case (format)
			2'b00: linearize = linear_en  ? value * linear_r_i : {{2{1'b0}},value,{14{1'b0}}};
			2'b01: linearize = linear_en  ? value * linear_gr_i : {{2{1'b0}},value,{14{1'b0}}};
			2'b10: linearize = linear_en  ? value * linear_gb_i : {{2{1'b0}},value,{14{1'b0}}};
			2'b11: linearize = linear_en  ? value * linear_b_i : {{2{1'b0}},value,{14{1'b0}}};
			default: linearize = {BITS{1'b0}};
		endcase
	endfunction
endmodule
