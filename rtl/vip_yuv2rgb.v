/*************************************************************************
> File Name: vip_yuv2rgb.v
> Description: Converts YUV to RGB
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * VIP - YUV convert RGB
 * BUG not support 10bit
 */

module RGBConversion
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
)
(
	input pclk,
	input rst_n,
    input [1:0] in_conv_standard,
    
	input in_href,
	input in_vsync, 
	input [BITS-1:0] in_y,
	input [BITS-1:0] in_u,
	input [BITS-1:0] in_v,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b
);

    //Subtracting offset from input YUV channels

	reg signed [BITS:0] data_y;
	reg signed [BITS:0] data_u;
	reg signed [BITS:0] data_v;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_y <= 0;
			data_u <= 0;
			data_v <= 0;
		end
		else begin
			data_y <= in_y - 16;
			data_u <= in_u - 128;
			data_v <= in_v - 128;
		end
	end

    //2 supported Conversion Matrices are given as:

	//R = (74 * Y + 0 * U + 114 * V)  >> 6
	//G = (74 * Y - 13  * U - 34 * V) >> 6
	//B = (74 * Y + 135 * U + 0 * V)  >> 6

	//R = (64 * Y + 0 * U + 87 * V)  >> 6
	//G = (64 * Y - 20 * U - 44 * V) >> 6
	//B = (61 * Y + 105 * U + 0 * V) >> 6

	//Step 1: Multiplying coefficients with corresponding input YUV pixels

	reg signed [BITS+9:0] r_y, r_u, r_v;
	reg signed [BITS+9:0] g_y, g_u, g_v;
	reg signed [BITS+9:0] b_y, b_u, b_v;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_y <= 0;
			r_u <= 0;
			r_v <= 0;
			g_y <= 0;
			g_u <= 0;
			g_v <= 0;
			b_y <= 0;
			b_u <= 0;
			b_v <= 0;
		end
		else if (in_conv_standard == 2'b1)begin
			r_y <= data_y * 74;
			r_u <= 0;
			r_v <= data_v * 114;
			g_y <= data_y * 74;
			g_u <= data_u * -13;
			g_v <= data_v * -34;
			b_y <= data_y * 74;
			b_u <= data_u * 135;
			b_v <= 0;
		end
		else begin
		    r_y <= data_y * 64;
			r_u <= 0;
			r_v <= data_v * 87;
			g_y <= data_y * 64;
			g_u <= data_u * -20;
			g_v <= data_v * -44;
			b_y <= data_y * 61;
			b_u <= data_u * 105;
			b_v <= 0;
        end    
	end

    //Step 2: //Summation of multiplications

	reg signed [BITS+10:0] data_r;
	reg signed [BITS+10:0] data_g;
	reg signed [BITS+10:0] data_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r <= 0;
			data_g <= 0;
			data_b <= 0;
		end
		else begin
			data_r <= r_y + r_u + r_v ;
			data_g <= g_y + g_u + g_v ;
			data_b <= b_y + b_u + b_v ;
		end
	end
    
	//Step 3: Division by 64

	reg  signed [BITS+4:0] data_r1;
	reg  signed [BITS+4:0] data_g1;
	reg  signed [BITS+4:0] data_b1;

	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r1 <= 0;
			data_g1 <= 0;
			data_b1 <= 0;
		end
		else begin
			data_r1 <= data_r >>> 6;
			data_g1 <= data_g >>> 6;
			data_b1 <= data_b >>> 6;
		end
	end

    //Clipping the result to bring it into bit range

	reg  [BITS-1:0] data_r2;
    reg  [BITS-1:0] data_g2;
    reg  [BITS-1:0] data_b2;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            data_r2 <= 0;
            data_g2 <= 0;
            data_b2 <= 0;
        end
        else begin
            data_r2 <= data_r1[BITS+4] ? {BITS{1'b0}} : ((data_r1[BITS+3:BITS] || 1'b0) ? {BITS{1'b1}} : data_r1[BITS-1:0]);
            data_g2 <= data_g1[BITS+4] ? {BITS{1'b0}} : ((data_g1[BITS+3:BITS] || 1'b0) ? {BITS{1'b1}} : data_g1[BITS-1:0]);
            data_b2 <= data_b1[BITS+4] ? {BITS{1'b0}} : ((data_b1[BITS+3:BITS] || 1'b0) ? {BITS{1'b1}} : data_b1[BITS-1:0]);
        end
    end

	// Adjusting for compuation delay

	localparam DLY_CLK = 5;
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
	assign out_r = out_href ? data_r2 : {BITS{1'b0}};
    assign out_g = out_href ? data_g2 : {BITS{1'b0}};
    assign out_b = out_href ? data_b2 : {BITS{1'b0}};
endmodule
