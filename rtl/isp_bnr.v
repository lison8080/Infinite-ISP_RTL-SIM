/*************************************************************************
> File Name: isp_bnr.v
> Description: Reduce the noise from the image in Bayer domain
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Bayer Noise Reduction
 */

module isp_bnr
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter WEIGHT_BITS = 5
)
(
	input pclk,
	input rst_n,

    input [5*5*WEIGHT_BITS-1:0] space_kernel_r,
	input [5*5*WEIGHT_BITS-1:0] space_kernel_g,
	input [5*5*WEIGHT_BITS-1:0] space_kernel_b,
	
	input [9*BITS-1:0]          color_curve_x_r,
	input [9*WEIGHT_BITS-1:0]   color_curve_y_r,
	input [9*BITS-1:0]          color_curve_x_g,
	input [9*WEIGHT_BITS-1:0]   color_curve_y_g,
	input [9*BITS-1:0]          color_curve_x_b,
	input [9*WEIGHT_BITS-1:0]   color_curve_y_b,
	

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_raw
);

// Apply green interpolation on raw image
wire gi_href, gi_vsync;
wire [BITS-1:0] gi_out_green, gi_out_raw;
isp_greenIntrp #(BITS, WIDTH, HEIGHT, BAYER) isp_greenIntrp_i0(pclk, rst_n, in_href, in_vsync, in_raw, gi_href, gi_vsync, gi_out_green, gi_out_raw);

localparam DEBUG = 0;
generate 
if (DEBUG) begin
  tb_dvp_to_file
	#(
		 "greenInterpolation.bin",  //FILE
		  16                      // 3 x BITS  for three channels       
	 )
	dvp2file_green
	(
		.pclk(pclk), 
		.rst_n(rst_n),
		.href(gi_href),
		.vsync(gi_vsync),
		.data({4'd0,gi_out_green})
	);
	
	tb_dvp_to_file
	#(
	 "raw_propagation.bin",
	 16  // 3 x BITS  for three channels       
	 )
	dvp2file_raw
	(
		.pclk(pclk), 
		.rst_n(rst_n),
		.href(gi_href),
		.vsync(gi_vsync),
		.data({4'd0,gi_out_raw})
	);
end
endgenerate
// Joint Bilateral filter on interpolated green channel
wire jbf_href, jbf_vsync;
wire [BITS-1:0] jbf_out_raw;
isp_jbf #(BITS, WIDTH, HEIGHT, BAYER, WEIGHT_BITS) isp_jbf_i0(pclk, rst_n,
                                                    space_kernel_r, space_kernel_g, space_kernel_b,
                                                    color_curve_x_r, color_curve_y_r,
                                                    color_curve_x_g, color_curve_y_g,
                                                    color_curve_x_b, color_curve_y_b,
                                                    gi_href, gi_vsync, gi_out_raw, gi_out_green, jbf_href, jbf_vsync, jbf_out_raw);

assign out_href = jbf_href;
assign out_vsync = jbf_vsync;
assign out_raw = jbf_out_raw;

endmodule