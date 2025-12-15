/*************************************************************************
> File Name: isp_wb.v
> Description: Adjust the white balance of raw images by applying appropriate gains
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - White Balance Gain
 */

module isp_wb
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
(
	input pclk,
	input rst_n,

	input [11:0] gain_r,
	input [11:0] gain_b,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_raw
	
);
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
	reg  [1:0] format_reg;
	
	// Register the Bayer format
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			format_reg <=0;
		end
		else begin
			format_reg <= format;
		end
	end
	
	// Register the input raw for appyling gain values
	reg [BITS-1:0] data_0;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_0 <= 0;
		end
		else begin
			data_0 <= in_raw;
		end
	end

    // Applying rgain and bgain values 
	reg [BITS-1+12:0] data_1;
	wire [BITS-1+12:0] mult_r, mult_g, mult_b;
	assign mult_r = data_0*gain_r;
	assign mult_b = data_0*gain_b;
	assign mult_g = {4'd0,data_0,8'd0};
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_1 <= 0;
		end
		else begin
		   case (format_reg) 
			2'b00: begin data_1 <= mult_r; end
			2'b01: begin data_1 <= mult_g; end
			2'b10: begin data_1 <= mult_g; end
			2'b11: begin data_1 <= mult_b; end
			endcase
		end
	end

    // Clipping the output in (0 - 2^BITS) range
	reg [BITS-1:0] data_2;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_2 <= 0;
		end
		else begin
			data_2 <= data_1[BITS-1+12:8] > {BITS{1'b1}} ? {BITS{1'b1}} : data_1[BITS-1+8:8];
		end
	end
	
	// Adjusting for computation delay
	localparam DLY_CLK = 3;
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
	assign out_raw = out_href ? data_2 : {BITS{1'b0}};
	
endmodule
