/*************************************************************************
> File Name: vip_top.v
> Description: Instantiation of all isp modules
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * VIP - Top Module
 */

module vip_top
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter OSD_RAM_ADDR_BITS = 9,
	parameter OSD_RAM_DATA_BITS = 32,
	parameter USE_HIST_EQU = 1,
	parameter USE_SOBEL = 1,
	parameter USE_RGBC = 1,
	parameter USE_IRC = 1,
	parameter USE_SCALE = 1,
	parameter USE_OSD = 1,
	parameter USE_YUVConvFormat = 1
	
)
(
	input pclk,
	input scale_pclk,
	input rst_n,
	
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_y,
	input [BITS-1:0] in_u,
	input [BITS-1:0] in_v,
	
	output out_pclk,
	output out_href,
	output out_vsync,
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b,
	
	input hist_equ_en, sobel_en, rgbc_en, irc_en, dscale_en, osd_en, yuv444to422_en,
	input [BITS-1:0] equ_min, equ_max,
	input [1:0] in_conv_standard,
	input [15:0] crop_x, crop_y,
	input [1:0] irc_output, // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
	input [11:0] s_in_crop_w,
	input [11:0] s_in_crop_h,
	input [11:0] s_out_crop_w,
	input [11:0] s_out_crop_h,
	input [2:0] dscale_w,
	input [2:0] dscale_h,
	input YUV444TO422,

	input [15:0] osd_x, osd_y, osd_w, osd_h,//osd�?置(�?能超过�-��?图�?范围, 宽高乘积�?能超过RAM总大�?)
	input [3*BITS-1:0] fg_color, bg_color, //�?景色,背景色
	input [7:0] alpha, //Alpha blending input argument for OSD
	//�?�色�?图RAM接�?�(最大�"��?32*(1<<9)=16394�?� ,典型128x16)
	input                          osd_ram_clk,
	input                          osd_ram_wen,
	input                          osd_ram_ren,
	input  [OSD_RAM_ADDR_BITS-1:0] osd_ram_addr,
	input  [OSD_RAM_DATA_BITS-1:0] osd_ram_wdata,
	output [OSD_RAM_DATA_BITS-1:0] osd_ram_rdata
);

wire [15:0] crop_w, crop_h;
assign crop_w = 1920;
assign crop_h = (irc_output == 2) ? 1440 : 1080;
 


generate
	begin:d_vip_top_inside
	//�"入�"�?(�?�'�"入逻�'延迟)
	wire in_href_o, in_vsync_o;
	wire [BITS-1:0] in_y_o, in_u_o, in_v_o;
	vid_mux #(BITS*3) mux_in(pclk, rst_n, 1'b0, in_href, in_vsync, {in_y,in_u,in_v}, 1'b0, 1'b0, {BITS*3{1'b0}}, in_href_o, in_vsync_o, {in_y_o,in_u_o,in_v_o});

	wire hist_equ_href_o, hist_equ_vsync_o;
	wire [BITS-1:0] hist_equ_y_o, hist_equ_u_o, hist_equ_v_o;
if ( USE_HIST_EQU ) begin : _HIST_EQU
	wire hist_equ_href, hist_equ_vsync;
	wire [BITS-1:0] hist_equ_y, hist_equ_u, hist_equ_v;
	vip_hist_equ #(BITS, WIDTH, HEIGHT) hist_equ_i0(pclk, rst_n&hist_equ_en, equ_min, equ_max, in_href_o, in_vsync_o, in_y_o, hist_equ_href, hist_equ_vsync, hist_equ_y);
	reg [BITS-1:0] hist_equ_u_r, hist_equ_v_r;
	always @ (posedge pclk) {hist_equ_u_r,hist_equ_v_r} <= {in_u_o, in_v_o};
	assign {hist_equ_u, hist_equ_v} = {hist_equ_u_r, hist_equ_v_r};
	vid_mux #(BITS*3) mux_hist_equ_i0(pclk, rst_n, hist_equ_en, in_href_o, in_vsync_o, {in_y_o,in_u_o,in_v_o}, hist_equ_href, hist_equ_vsync, {hist_equ_y,hist_equ_u,hist_equ_v}, hist_equ_href_o, hist_equ_vsync_o, {hist_equ_y_o,hist_equ_u_o,hist_equ_v_o});
end
else begin : N_HIST_EQU
	assign hist_equ_href_o = in_href_o;
	assign hist_equ_vsync_o = in_vsync_o;
	assign hist_equ_y_o = in_y_o;
	assign hist_equ_u_o = in_u_o;
	assign hist_equ_v_o = in_v_o;
end

	wire sobel_href_o, sobel_vsync_o;
	wire [BITS-1:0] sobel_y_o, sobel_u_o, sobel_v_o;
if ( USE_SOBEL) begin : _SOBEL
	wire sobel_href, sobel_vsync;
	wire [BITS-1:0] sobel_y, sobel_u, sobel_v;
	vip_sobel #(BITS, WIDTH, HEIGHT) sobel_i0(pclk, rst_n&sobel_en, hist_equ_href_o, hist_equ_vsync_o, hist_equ_y_o, sobel_href, sobel_vsync, sobel_y);
	assign sobel_u = 1'b1 << (BITS-1);
	assign sobel_v = 1'b1 << (BITS-1);
	vid_mux #(BITS*3) mux_sobel_i0(pclk, rst_n, sobel_en, hist_equ_href_o, hist_equ_vsync_o, {hist_equ_y_o,hist_equ_u_o,hist_equ_v_o}, sobel_href, sobel_vsync, {sobel_y,sobel_u,sobel_v}, sobel_href_o, sobel_vsync_o, {sobel_y_o,sobel_u_o,sobel_v_o});
end
else begin : _N_SOBEL
	assign sobel_href_o = hist_equ_href_o;
	assign sobel_vsync_o = hist_equ_vsync_o;
	assign sobel_y_o = hist_equ_y_o;
	assign sobel_u_o = hist_equ_u_o;
	assign sobel_v_o = hist_equ_v_o;
end

	wire yuv2rgb_href_o, yuv2rgb_vsync_o;
	wire [BITS-1:0] yuv2rgb_r_o, yuv2rgb_g_o, yuv2rgb_b_o;
if (USE_RGBC) begin : _RGBC
	wire yuv2rgb_href, yuv2rgb_vsync;
	wire [BITS-1:0] yuv2rgb_r, yuv2rgb_g, yuv2rgb_b;
	RGBConversion #(BITS, WIDTH, HEIGHT) RGBConversion_i0(pclk, rst_n&rgbc_en, in_conv_standard, sobel_href_o, sobel_vsync_o, sobel_y_o, sobel_u_o, sobel_v_o, yuv2rgb_href, yuv2rgb_vsync, yuv2rgb_r, yuv2rgb_g, yuv2rgb_b);
	vid_mux #(BITS*3) mux_yuv2rgb_i0(pclk, rst_n, rgbc_en, sobel_href_o, sobel_vsync_o, {sobel_y_o,sobel_u_o,sobel_v_o}, yuv2rgb_href, yuv2rgb_vsync, {yuv2rgb_r,yuv2rgb_g,yuv2rgb_b}, yuv2rgb_href_o, yuv2rgb_vsync_o, {yuv2rgb_r_o,yuv2rgb_g_o,yuv2rgb_b_o});
end
else begin : _N_RGBC
	assign yuv2rgb_href_o = sobel_href_o;
	assign yuv2rgb_vsync_o = sobel_vsync_o;
	assign yuv2rgb_r_o = sobel_y_o;
	assign yuv2rgb_g_o = sobel_u_o;	
	assign yuv2rgb_b_o = sobel_v_o;
end

	wire crop_href_o, crop_vsync_o;
	wire [BITS-1:0] crop_r_o, crop_g_o, crop_b_o;
if (USE_IRC) begin : _IRC
	wire crop_href, crop_vsync;
	wire [BITS-1:0] crop_r, crop_g, crop_b;
	InvalidRegionCrop #(BITS*3, WIDTH, HEIGHT) InvalidRegionCrop_i0(pclk, rst_n&irc_en, crop_x, crop_y, crop_w, crop_h, yuv2rgb_href_o, yuv2rgb_vsync_o, {yuv2rgb_r_o, yuv2rgb_g_o, yuv2rgb_b_o}, crop_href, crop_vsync, {crop_r, crop_g, crop_b});
	vid_mux #(BITS*3) mux_crop_i0(pclk, rst_n, irc_en, yuv2rgb_href_o, yuv2rgb_vsync_o, {yuv2rgb_r_o, yuv2rgb_g_o, yuv2rgb_b_o}, crop_href, crop_vsync, {crop_r, crop_g, crop_b}, crop_href_o, crop_vsync_o, {crop_r_o,crop_g_o,crop_b_o});
end
else begin : _N_IRC
	assign crop_href_o = yuv2rgb_href_o;
	assign crop_vsync_o = yuv2rgb_vsync_o;
	assign crop_r_o = yuv2rgb_r_o;
	assign crop_g_o = yuv2rgb_g_o;
	assign crop_b_o = yuv2rgb_b_o;
end

	wire osd_href_o, osd_vsync_o;
	wire [BITS-1:0] osd_r_o, osd_g_o, osd_b_o;
if ( USE_OSD) begin : _OSD
	wire osd_pclk, osd_href, osd_vsync;
	wire [BITS-1:0] osd_r, osd_g, osd_b;
	vip_osd
		#(
			BITS, WIDTH, HEIGHT, OSD_RAM_ADDR_BITS, OSD_RAM_DATA_BITS
		)
		osd_i0
		(
			pclk, rst_n&osd_en,
			osd_x, osd_y, osd_w, osd_h, fg_color[3*BITS-1:2*BITS], fg_color[2*BITS-1:BITS], fg_color[BITS-1:0], 
			bg_color[3*BITS-1:2*BITS], bg_color[2*BITS-1:BITS], bg_color[BITS-1:0], alpha,
			crop_href_o, crop_vsync_o, crop_r_o, crop_g_o, crop_b_o,
			osd_href, osd_vsync, osd_r, osd_g, osd_b,
			osd_ram_clk, osd_ram_wen, osd_ram_ren, osd_ram_addr, osd_ram_wdata, osd_ram_rdata
		);
	vid_mux #(BITS*3) mux_osd_i0(pclk, rst_n, osd_en, crop_href_o, crop_vsync_o, {crop_r_o, crop_g_o, crop_b_o}, osd_href, osd_vsync, {osd_r, osd_g, osd_b}, osd_href_o, osd_vsync_o, {osd_r_o,osd_g_o,osd_b_o});
end
else begin : _N_OSD
	assign osd_href_o = crop_href_o;
	assign osd_vsync_o = crop_vsync_o;
	assign osd_r_o = crop_r_o;
	assign osd_g_o = crop_g_o;
	assign osd_b_o = crop_b_o;
end

	wire dscale_pclk_o, dscale_href_o, dscale_vsync_o;
	wire [BITS-1:0] dscale_r_o, dscale_g_o, dscale_b_o;
if ( USE_SCALE )begin : _SCALE
	wire dscale_pclk, dscale_href, dscale_vsync;
	wire [BITS-1:0] dscale_r, dscale_g, dscale_b;
	Scale #(BITS) Scale_i0(pclk, scale_pclk, rst_n&dscale_en, osd_href_o, osd_vsync_o, osd_r_o, osd_g_o, osd_b_o, s_in_crop_w, s_in_crop_h, s_out_crop_w, s_out_crop_h, dscale_w, dscale_h, dscale_pclk, dscale_href, dscale_vsync, dscale_r, dscale_g, dscale_b);
	assign dscale_pclk_o = scale_pclk;
	vid_mux #(BITS*3) mux_dscale_i0(dscale_pclk_o, rst_n, dscale_en, osd_href_o, osd_vsync_o, {osd_r_o, osd_g_o, osd_b_o}, dscale_href, dscale_vsync, {dscale_r, dscale_g, dscale_b}, dscale_href_o, dscale_vsync_o, {dscale_r_o,dscale_g_o,dscale_b_o});
end
else begin : _N_SCALE
	assign dscale_pclk_o = scale_pclk;
	assign dscale_href_o = osd_href_o;
	assign dscale_vsync_o = osd_vsync_o;
	assign dscale_r_o = osd_r_o;
	assign dscale_g_o = osd_g_o;
	assign dscale_b_o = osd_b_o;
end



	wire yuv444to422_pclk_o, yuv444to422_href_o, yuv444to422_vsync_o;
	wire [BITS-1:0] yuv444to422_y_o, yuv444to422_u_o, yuv444to422_v_o;
if (USE_YUVConvFormat) begin :_YUVConvFormat
	wire yuv444to422_href, yuv444to422_vsync;
	wire [BITS-1:0] yuv444to422_y, yuv444to422_c, yuv444to422_v;
	YUVConvFormat #(BITS) YUVConvFormat_i0(dscale_pclk_o, rst_n&yuv444to422_en, dscale_href_o, dscale_vsync_o, YUV444TO422, dscale_r_o, dscale_g_o, dscale_b_o, yuv444to422_href, yuv444to422_vsync, yuv444to422_y, yuv444to422_c, yuv444to422_v);
	vid_mux #(BITS*3) mux_yuv444to422_i0(dscale_pclk_o, rst_n, yuv444to422_en, dscale_href_o, dscale_vsync_o, {dscale_r_o,dscale_g_o,dscale_b_o}, yuv444to422_href, yuv444to422_vsync, {yuv444to422_y,yuv444to422_c,yuv444to422_v}, yuv444to422_href_o, yuv444to422_vsync_o, {yuv444to422_y_o,yuv444to422_u_o,yuv444to422_v_o});
	assign yuv444to422_pclk_o = dscale_pclk_o;
end
else begin : N_YUVConvFormat
	assign yuv444to422_pclk_o = dscale_pclk_o;
	assign yuv444to422_href_o = dscale_href_o;
	assign yuv444to422_vsync_o = dscale_vsync_o;
	assign yuv444to422_y_o = dscale_r_o;
	assign yuv444to422_u_o = dscale_g_o;
	assign yuv444to422_v_o = dscale_b_o;
end

	assign out_pclk = yuv444to422_pclk_o;
	assign out_href = yuv444to422_href_o;
	assign out_vsync = yuv444to422_vsync_o;
	assign out_r = yuv444to422_y_o;
	assign out_g = yuv444to422_u_o;
	assign out_b = yuv444to422_v_o;
	end
endgenerate

endmodule

/***************************************************
******* Module already declared in isp top *********
****************************************************/
// module vid_mux
// #(
// 	parameter BITS = 8
// )
// (
// 	input pclk,
// 	input rst_n,

// 	input sel,

// 	input in_href_0,
// 	input in_vsync_0,
// 	input [BITS-1:0] in_data_0,

// 	input in_href_1,
// 	input in_vsync_1,
// 	input [BITS-1:0] in_data_1,

// 	output out_href,
// 	output out_vsync,
// 	output [BITS-1:0] out_data
// );

// 	wire in_href = sel ? in_href_1 : in_href_0;
// 	wire in_vsync = sel ? in_vsync_1 : in_vsync_0;
// 	wire [BITS-1:0] in_data = sel ? in_data_1 : in_data_0;

// 	reg href_reg, vsync_reg;
// 	reg [BITS-1:0] data_reg;
// 	always @ (posedge pclk or negedge rst_n) begin
// 		if (!rst_n) begin
// 			href_reg <= 0;
// 			vsync_reg <= 0;
// 			data_reg <= 0;
// 		end
// 		else begin
// 			href_reg <= in_href;
// 			vsync_reg <= in_vsync;
// 			data_reg <= in_data;
// 		end
// 	end

// 	assign out_href = href_reg;
// 	assign out_vsync = vsync_reg;
// 	assign out_data = data_reg;
// endmodule