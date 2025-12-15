/*************************************************************************
> File Name: crop_awb_ae.v
> Description: Croping the border after AWB
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Crop AWB
 */

module isp_crop_awb_ae
#(
	parameter BITS = 8,
	parameter WIDTH = 4096,
	parameter HEIGHT = 4096
//	parameter CROP_LEFT = 0,
//	parameter CROP_RIGHT = 0,
//	parameter CROP_TOP = 0,
//	parameter CROP_BOTTOM = 0
	)
(
	input pclk,
	input rst_n,

	input [11:0] crop_left,
	input [11:0] crop_right,
	input [11:0] crop_top,
	input [11:0] crop_bottom,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data
);

    // Line start and line end detection 
	reg prev_href;
	wire line_start = (~prev_href) & in_href;
	wire line_end = prev_href & (~in_href);
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_href <= 0;
		else
			prev_href <= in_href;
	end
	
	// Count pixel in a line, to select required region for cropping
	reg [15:0] pix_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			pix_cnt <= 0;
		else if (line_start)
			pix_cnt <= 0;
		else if (pix_cnt < {16{1'b1}})
			pix_cnt <= pix_cnt + 1'b1;
		else
			pix_cnt <= pix_cnt;
	end
    
	// Frame start detection
	reg prev_vsync;
	wire frame_start = prev_vsync & (~in_vsync);
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_vsync <= 0;
		else
			prev_vsync <= in_vsync;
	end

    // Count lines, to select required region for cropping
	reg [15:0] line_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			line_cnt <= 0;
		else if (frame_start)
			line_cnt <= 0;
		else if (line_end)
			line_cnt <= line_cnt + 1'b1;
		else
			line_cnt <= line_cnt;
	end

    // Adding delay to the input data
	reg [BITS-1:0] data_r;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			data_r <= 0;
		else
			data_r <= in_data;
	end
	reg in_href_delayed;
	always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n)
            in_href_delayed <= 0;
        else
            in_href_delayed <= in_href;
    end
//	  wire [15:0] crop_x, crop_y;
//    assign crop_x = (WIDTH - crop_w) >> 1;
//    assign crop_y = (HEIGHT - crop_h) >> 1;

    // Cropping Logic, based on line count and pixel count
    wire out_href_crop;
	assign out_href_crop = (pix_cnt >= crop_left) && (pix_cnt < WIDTH - crop_right) && (line_cnt >= crop_top) && (line_cnt < HEIGHT - crop_bottom);

    assign out_href = ((crop_left != 0) || (crop_right != 0) || (crop_top != 0) || (crop_bottom != 0)) ? out_href_crop : in_href_delayed;
    
	assign out_vsync = in_vsync;

	// Assigning output
	assign out_data = out_href ? data_r : {BITS{1'b0}};

endmodule