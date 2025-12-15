/*************************************************************************
> File Name: isp_top.v
> Description: Instantiation of all isp modules
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Top Module
 */

module isp_top
#(
	parameter BITS = 10,
	parameter SNS_WIDTH = 2048,
	parameter SNS_HEIGHT = 1536,
	parameter CROP_WIDTH = 1920,
	parameter CROP_HEIGHT = 1080,
	parameter BAYER = 1, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter OECF_R_LUT = "OECF_R_LUT_INIT.mem",
	parameter OECF_GR_LUT = "OECF_GR_LUT_INIT.mem",
	parameter OECF_GB_LUT = "OECF_GB_LUT_INIT.mem",
	parameter OECF_B_LUT = "OECF_B_LUT_INIT.mem",
	parameter BNR_WEIGHT_BITS = 8,
	parameter DGAIN_ARRAY_SIZE = 100,
	parameter DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE),
	parameter AWB_CROP_LEFT = 0,
	parameter AWB_CROP_RIGHT = 0,
	parameter AWB_CROP_TOP = 0,
	parameter AWB_CROP_BOTTOM = 0,
	parameter GAMMA_R_LUT = "GAMMA_R_LUT_INIT.mem",
	parameter GAMMA_G_LUT = "GAMMA_G_LUT_INIT.mem",
	parameter GAMMA_B_LUT = "GAMMA_B_LUT_INIT.mem",
	parameter SHARP_WEIGHT_BITS = 20,
	parameter NR2D_WEIGHT_BITS = 5,
	parameter STAT_OUT_BITS = 32,
	parameter STAT_HIST_BITS = BITS, //??-????? ???(???? ??)
	parameter USE_CROP = 1,
	parameter USE_DPC = 1,
	parameter USE_BLC = 1,
	parameter USE_OECF = 1,
	parameter USE_DGAIN = 1,
	parameter USE_LSC = 1,
	parameter USE_BNR = 1,	
	parameter USE_WB = 1,
	parameter USE_DEMOSIC = 1,	
	parameter USE_CCM = 1,
	parameter USE_GAMMA = 1,
	parameter USE_CSC = 1,
	parameter USE_SHARP = 1,
	parameter USE_LDCI = 1,
	parameter USE_2DNR = 1,
	parameter USE_STAT_AE = 1,
	parameter USE_AWB = 1,
	parameter USE_AE = 1
)
(
	input pclk,
	input rst_n,
	
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	
	input in_href_rgb,
	input in_vsync_rgb,
	input [BITS-1:0] in_r,
	input [BITS-1:0] in_g,
	input [BITS-1:0] in_b,
	
	output out_gamma_href,
	output out_gamma_vsync,
	output [BITS-1:0] out_gamma_r,
	output [BITS-1:0] out_gamma_g,
	output [BITS-1:0] out_gamma_b,
	
	output out_href,
	output out_vsync,
	output [7:0] out_y,
	output [7:0] out_u,
	output [7:0] out_v,

	// selecting between inputs
	input rgb_inp_en,
	
    // Module enables
	input crop_en, dpc_en, blc_en, linear_en, oecf_en, bnr_en, dgain_en, lsc_en, demosic_en, wb_en, ccm_en, csc_en, gamma_en, ldci_en, nr2d_en, sharp_en, stat_ae_en, awb_en, ae_en,
    // DPC
	input [BITS-1:0] dpc_threshold,
	// BLC and Linearization
	input [BITS-1:0] blc_r, blc_gr, blc_gb, blc_b,
	input [15:0] linear_r, linear_gr, linear_gb, linear_b, 
	// OECF
	input               r_table_clk, gr_table_clk, gb_table_clk, b_table_clk,
	input               r_table_wen, gr_table_wen, gb_table_wen, b_table_wen,
	input               r_table_ren, gr_table_ren, gb_table_ren, b_table_ren,
	input  [BITS-1:0] 	r_table_addr, gr_table_addr, gb_table_addr, b_table_addr,
	input  [BITS-1:0] 	r_table_wdata, gr_table_wdata, gb_table_wdata, b_table_wdata,
	output [BITS-1:0] 	r_table_rdata, gr_table_rdata, gb_table_rdata, b_table_rdata,
	// BNR
	input [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_r,	
	input [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_g,
	input [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_b,  
	input [9*BITS-1:0]              bnr_color_curve_x_r,   
	input [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_r,
	input [9*BITS-1:0]              bnr_color_curve_x_g,   
	input [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_g,
	input [9*BITS-1:0]              bnr_color_curve_x_b,   
	input [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_b,   
	// Digital Gain
	input dgain_isManual,
	input [DGAIN_ARRAY_BITS-1:0] dgain_man_index,
	input [DGAIN_ARRAY_SIZE*8-1:0] dgain_array,
	output [DGAIN_ARRAY_BITS-1:0] dgain_index_out,
	// White Balance
	input [11:0] wb_rgain, wb_bgain,
	// Color correction matrix
	input [15:0] ccm_rr, ccm_rg, ccm_rb,
	input [15:0] ccm_gr, ccm_gg, ccm_gb, 
	input [15:0] ccm_br, ccm_bg, ccm_bb,
    // Gamma Table
	input                         gamma_table_r_clk, gamma_table_g_clk, gamma_table_b_clk,
	input                         gamma_table_r_wen, gamma_table_g_wen, gamma_table_b_wen,
	input                         gamma_table_r_ren, gamma_table_g_ren, gamma_table_b_ren,
	input  [BITS-1:0] gamma_table_r_addr, gamma_table_g_addr, gamma_table_b_addr,
	input  [BITS-1:0] gamma_table_r_wdata, gamma_table_g_wdata, gamma_table_b_wdata,
	output [BITS-1:0] gamma_table_r_rdata, gamma_table_g_rdata, gamma_table_b_rdata,
    // CSC
	input [1:0]                   in_conv_standard,
	// SHARP
	input [9*9*SHARP_WEIGHT_BITS-1:0] luma_kernel,
	input [11:0] sharpen_strength,
    // 2DNR 
	input [32*8-1:0]                  nr2d_diff,//????? ???????? ?(9??? ??)
	input [32*NR2D_WEIGHT_BITS-1:0]   nr2d_weight,//????? ???????? ?(9??? ??)
    // AE inputs and memory port
	input [7:0] center_illuminance,
    input [15:0] skewness,
	input [11:0] ae_crop_left,
	input [11:0] ae_crop_right,
	input [11:0] ae_crop_top,
	input [11:0] ae_crop_bottom,
    output [1:0] ae_response,
    output [15:0] ae_result_skewness,
    output [1:0] ae_response_debug,
	output ae_done,

	//===== AE debug ports ======//
	/*output [23:0] cropped_size,
	output [40:0] sum_pix_square,
	output [50:0] sum_pix_cube,
	output [63:0] div_out_m_2,
	output [63:0] div_out_m_3,
	output [63:0] div_out_sqrt_fsm,
	output [62:0] sqrt_fsm_out_sqrt,
	output [63:0] div_out_ae_skewness,
	output SQRT_FSM_EN,
	output SQRT_FSM_DIV_EN,
	output SQRT_FSM_DIV_DONE,
	output SQRT_FSM_DONE,
	output [31:0] SQRT_FSM_COUNT,*/
	//===== AE debug ports ======//

    
    // AWB input ports and memory port 
	input [BITS-1:0] awb_underexposed_limit, awb_overexposed_limit, awb_frames,
    // selected gains that are input to WB block
	output reg [11:0] final_r_gain, final_b_gain

	//===== AWB debug ports =====//
    /*,
	output [23:0] awb_cropped_size,
	output [BITS-1:0] awb_overexposed_pix_limit,
	output [BITS-1:0] awb_underexposed_pix_limit,
    output [37:0] div_Rgain_num_meanG,
    output [37:0] div_Rgain_den_sumR,
    output [37:0] div_Rgain_quo_Rgain,
    output [37:0] div_Bgain_num_meanG,
    output [37:0] div_Bgain_den_sumB,
    output [37:0] div_Bgain_quo_Bgain,
    output div_gains_sampled*/
    //===== AWB debug ports =====//

);

localparam CROP_COND = ((SNS_WIDTH - CROP_WIDTH) % 4 == 0 ) && ((SNS_HEIGHT - CROP_HEIGHT) % 4 == 0);
localparam CROP_INST_WIDTH = CROP_COND ? CROP_WIDTH : SNS_WIDTH;
localparam CROP_INST_HEIGHT = CROP_COND ? CROP_HEIGHT : SNS_HEIGHT;
localparam WIDTH = USE_CROP ? CROP_INST_WIDTH : SNS_WIDTH;
localparam HEIGHT = USE_CROP ? CROP_INST_HEIGHT : SNS_HEIGHT;

wire [11:0] crop_width;
wire [11:0] crop_height;
assign crop_width = CROP_WIDTH;
assign crop_height = CROP_HEIGHT;
	
wire in_href_o, in_vsync_o;
wire [BITS-1:0] in_raw_o;
vid_mux #(BITS) mux_in(pclk, rst_n, 1'b0, in_href, in_vsync, in_raw, 1'b0, 1'b0, {BITS{1'b0}}, in_href_o, in_vsync_o, in_raw_o);

generate
begin:d_top_gen_inside
// Crop
wire crop_href_o, crop_vsync_o;
wire [BITS-1:0] crop_raw_o;
if (USE_CROP) begin : _CROP
   wire crop_href, crop_vsync;
   wire [BITS-1:0] crop_raw;
   isp_crop #(BITS, SNS_WIDTH, SNS_HEIGHT) crop_i0(pclk, rst_n&crop_en, crop_width, crop_height, in_href_o, in_vsync_o, in_raw_o, crop_href, crop_vsync, crop_raw);
   vid_mux #(BITS) mux_crop_i0(pclk, rst_n, crop_en, in_href_o, in_vsync_o, in_raw_o, crop_href, crop_vsync, crop_raw, crop_href_o, crop_vsync_o, crop_raw_o);
end
else begin : _N_CROP 
   assign crop_href_o = in_href_o;
   assign crop_vsync_o = in_vsync_o;
   assign crop_raw_o = in_raw_o;
end
 
// Dead Pixel Correction
wire dpc_href_o, dpc_vsync_o;
wire [BITS-1:0] dpc_raw_o;
if (USE_DPC) begin : _DPC 
   wire dpc_href, dpc_vsync;
   wire [BITS-1:0] dpc_raw;
   isp_dpc #(BITS, WIDTH, HEIGHT, BAYER) dpc_i0(pclk, rst_n&dpc_en, dpc_threshold, crop_href_o, crop_vsync_o, crop_raw_o, dpc_href, dpc_vsync, dpc_raw);
   vid_mux #(BITS) mux_dpc_i0(pclk, rst_n, dpc_en, crop_href_o, crop_vsync_o, crop_raw_o, dpc_href, dpc_vsync, dpc_raw, dpc_href_o, dpc_vsync_o, dpc_raw_o);
end
else begin : _N_DPC 
   assign dpc_href_o = crop_href_o;
   assign dpc_vsync_o = crop_vsync_o;
   assign dpc_raw_o = crop_raw_o;
end
// Black Level Correction	
wire blc_href_o, blc_vsync_o;
wire [BITS-1:0] blc_raw_o;
if (USE_BLC) begin : _BLC
   wire blc_href, blc_vsync;
   wire [BITS-1:0] blc_raw;
   isp_blc #(BITS, WIDTH, HEIGHT, BAYER) blc_i0(pclk, rst_n&blc_en, blc_r, blc_gr, blc_gb, blc_b, linear_en, linear_r, linear_gr, linear_gb, linear_b, dpc_href_o, dpc_vsync_o, dpc_raw_o, blc_href, blc_vsync, blc_raw);
   vid_mux #(BITS) mux_blc_i0(pclk, rst_n, blc_en, dpc_href_o, dpc_vsync_o, dpc_raw_o, blc_href, blc_vsync, blc_raw, blc_href_o, blc_vsync_o, blc_raw_o);
end
else begin: _N_BLC 
    assign blc_href_o = dpc_href_o;
    assign blc_vsync_o = dpc_vsync_o;
    assign blc_raw_o = dpc_raw_o;
end
// OECF
wire oecf_href_o, oecf_vsync_o;
wire [BITS-1:0] oecf_raw_o;
if (USE_OECF) begin : _OECF
   wire oecf_href, oecf_vsync;
   wire [BITS-1:0] oecf_raw;
   isp_oecf #(BITS, WIDTH, HEIGHT, BAYER, OECF_R_LUT, OECF_GR_LUT, OECF_GB_LUT, OECF_B_LUT) oecf_i0(pclk, rst_n&oecf_en,
																	  r_table_clk,	r_table_wen, r_table_ren, r_table_addr, r_table_wdata, r_table_rdata,
																	  gr_table_clk, gr_table_wen, gr_table_ren, gr_table_addr, gr_table_wdata, gr_table_rdata,
																	  gb_table_clk, gb_table_wen, gb_table_ren, gb_table_addr, gb_table_wdata, gb_table_rdata,
																	  b_table_clk,	b_table_wen, b_table_ren, b_table_addr, b_table_wdata, b_table_rdata,
																	  blc_href_o, blc_vsync_o, blc_raw_o, oecf_href, oecf_vsync, oecf_raw);
   vid_mux #(BITS) mux_oecf_i0(pclk, rst_n, oecf_en, blc_href_o, blc_vsync_o, blc_raw_o, oecf_href, oecf_vsync, oecf_raw, oecf_href_o, oecf_vsync_o, oecf_raw_o);
end
else begin: _N_OECF
   assign oecf_href_o = blc_href_o;
   assign oecf_vsync_o = blc_vsync_o;
   assign oecf_raw_o = blc_raw_o;
end
// Digital Gain
wire [DGAIN_ARRAY_BITS-1:0] ae_feedback; // ae_feedback is the DG index
wire [DGAIN_ARRAY_BITS-1:0] dgain_index;
wire [DGAIN_ARRAY_BITS-1:0] applied_dg_index;
wire dgain_href_o, dgain_vsync_o;
wire [BITS-1:0] dgain_raw_o;
assign dgain_index_out = applied_dg_index;
if ( USE_DGAIN ) begin : _DG
   wire dgain_href, dgain_vsync;
   wire [BITS-1:0] dgain_raw;
   isp_dgain #(BITS, WIDTH, HEIGHT, DGAIN_ARRAY_SIZE, DGAIN_ARRAY_BITS) dgain_i0(pclk, rst_n&dgain_en, dgain_isManual, dgain_man_index, ae_feedback, dgain_array, oecf_href_o, oecf_vsync_o, oecf_raw_o, dgain_href, dgain_vsync, applied_dg_index, dgain_raw);
   vid_mux #(BITS) mux_dgain_i0(pclk, rst_n, dgain_en, oecf_href_o, oecf_vsync_o, oecf_raw_o, dgain_href, dgain_vsync, dgain_raw, dgain_href_o, dgain_vsync_o, dgain_raw_o);
end
else begin : _N_DG
   assign dgain_href_o = oecf_href_o;
   assign dgain_vsync_o = oecf_vsync_o;
   assign dgain_raw_o = oecf_raw_o;
end
// Lens Shading Correction
wire lsc_href_o, lsc_vsync_o;
wire [BITS-1:0] lsc_raw_o;
if ( USE_LSC) begin : _LSC
   wire lsc_href, lsc_vsync;
   wire [BITS-1:0] lsc_raw;
  // LSC module to be instantiated here
   assign lsc_href = dgain_href_o;
   assign lsc_vsync = dgain_vsync_o;
   assign lsc_raw = dgain_raw_o;
   // LSC module ends here
   vid_mux #(BITS) mux_lsc_i0(pclk, rst_n, lsc_en, dgain_href_o, dgain_vsync_o, dgain_raw_o, lsc_href, lsc_vsync, lsc_raw, lsc_href_o, lsc_vsync_o, lsc_raw_o);
end
else begin : _N_LSC
   assign lsc_href_o = dgain_href_o;
   assign lsc_vsync_o = dgain_vsync_o;
   assign lsc_raw_o = dgain_raw_o;
end
// Bayer Noise Reduction 
wire bnr_href_o, bnr_vsync_o;
wire [BITS-1:0] bnr_raw_o;
if ( USE_BNR) begin : BNR
   wire bnr_href, bnr_vsync;
   wire [BITS-1:0] bnr_raw;
   isp_bnr #(BITS, WIDTH, HEIGHT, BAYER, BNR_WEIGHT_BITS) bnr_i0(pclk, rst_n&bnr_en,
                                      bnr_space_kernel_r ,bnr_space_kernel_g, bnr_space_kernel_b,
                                      bnr_color_curve_x_r, bnr_color_curve_y_r,
                                      bnr_color_curve_x_g, bnr_color_curve_y_g,
                                      bnr_color_curve_x_b, bnr_color_curve_y_b, 
                                      lsc_href_o, lsc_vsync_o, lsc_raw_o, bnr_href, bnr_vsync, bnr_raw);
   vid_mux #(BITS) mux_bnr_i0(pclk, rst_n, bnr_en, lsc_href_o, lsc_vsync_o, lsc_raw_o, bnr_href, bnr_vsync, bnr_raw, bnr_href_o, bnr_vsync_o, bnr_raw_o);
end else begin : _N_BNR
   assign bnr_href_o = lsc_href_o;
   assign bnr_vsync_o = lsc_vsync_o;
   assign bnr_raw_o = lsc_raw_o;
end
// Auto White Balance
wire [11:0] awb_out_r_gain, awb_out_b_gain;
wire high;
if ( USE_AWB) begin : _AWB
   isp_awb #(BITS, WIDTH, HEIGHT, BAYER, AWB_CROP_LEFT, AWB_CROP_RIGHT, AWB_CROP_TOP, AWB_CROP_BOTTOM) isp_awb_i0(pclk, rst_n&awb_en, awb_underexposed_limit, awb_overexposed_limit, awb_frames, bnr_href_o, bnr_vsync_o, bnr_raw_o, awb_out_r_gain, awb_out_b_gain, high 
   																													/*,awb_cropped_size,
																													awb_overexposed_pix_limit,
																													awb_underexposed_pix_limit,
																													div_Rgain_num_meanG,
    																												div_Rgain_den_sumR,
    																												div_Rgain_quo_Rgain,
    																												div_Bgain_num_meanG,
   																													div_Bgain_den_sumB,
    																												div_Bgain_quo_Bgain,
    																												div_gains_sampled*/																								
																													);
end
//================== Circuit for Selecting WB gains ==================//
reg prev_bnr_vsync_o;
always @(posedge pclk or negedge rst_n)
begin
	if (!rst_n)
		prev_bnr_vsync_o <= 1'b0;
	else
		prev_bnr_vsync_o <= bnr_vsync_o;
end
reg reset_sequence;				//from reset to end of first VSYNC pulse _|-----|_
always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        reset_sequence <= 1'b1;
    end
    else if(prev_bnr_vsync_o & ~bnr_vsync_o)	//falling edge of VSYNC
		reset_sequence <= 1'b0;
	else
		reset_sequence <= reset_sequence;		//low for all clocks after first falling edge of VSYNC
end
//Selection of Gains
always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        final_r_gain <= 0;
        final_b_gain <= 0;
    end
	else if(reset_sequence)begin
        final_r_gain <= wb_rgain;
        final_b_gain <= wb_bgain;
	end
	else if(~awb_en & ~reset_sequence & (prev_bnr_vsync_o & ~bnr_vsync_o)) begin
	    final_r_gain <= wb_rgain;
        final_b_gain <= wb_bgain;
	end
    else if(high & ~reset_sequence)begin
        final_r_gain <= awb_out_r_gain;
        final_b_gain <= awb_out_b_gain; 
    end
    else begin
        final_r_gain <= final_r_gain;
        final_b_gain <= final_b_gain;
    end
end
//================== Circuit for Selecting WB gains ==================//
// White Balance	
wire wb_href_o, wb_vsync_o;
wire [BITS-1:0] wb_raw_o;
if ( USE_WB) begin : _WB
   wire wb_href, wb_vsync;
   wire [BITS-1:0] wb_raw;
   isp_wb #(BITS, WIDTH, HEIGHT, BAYER) wb_i0(pclk, rst_n&wb_en, final_r_gain, final_b_gain, bnr_href_o, bnr_vsync_o, bnr_raw_o, wb_href, wb_vsync, wb_raw);
   vid_mux #(BITS) mux_wb_i0(pclk, rst_n, wb_en, bnr_href_o, bnr_vsync_o, bnr_raw_o, wb_href, wb_vsync, wb_raw, wb_href_o, wb_vsync_o, wb_raw_o);
end
   else begin : _N_WB
   assign wb_href_o = bnr_href_o;
   assign wb_vsync_o = bnr_vsync_o;
   assign wb_raw_o = bnr_raw_o;
end


// Demosaicing 
wire dm_href_o, dm_vsync_o;
wire [BITS-1:0] dm_r_o, dm_g_o, dm_b_o;
if ( USE_DEMOSIC) begin : _CFA
   wire dm_href, dm_vsync;
   wire [BITS-1:0] dm_r, dm_g, dm_b;
   isp_demosaic #(BITS, WIDTH, HEIGHT, BAYER) demosaic_i0(pclk, rst_n&demosic_en, wb_href_o, wb_vsync_o, wb_raw_o, dm_href, dm_vsync, dm_r, dm_g, dm_b);
   vid_mux #(BITS*3) mux_demosaic_i0(pclk, rst_n, demosic_en, wb_href_o, wb_vsync_o, {3{wb_raw_o}}, dm_href, dm_vsync, {dm_r,dm_g,dm_b}, dm_href_o, dm_vsync_o, {dm_r_o,dm_g_o,dm_b_o});
end
else begin : _N_CFA
   assign dm_href_o = wb_href_o;
   assign dm_vsync_o = wb_vsync_o;
   assign dm_r_o = wb_raw_o;
   assign dm_g_o = wb_raw_o;
   assign dm_b_o = wb_raw_o;
end

// Selecting between direct RGB and RGB from CFA moduele
wire ci_href_o, ci_vsync_o;
wire [BITS-1:0] ci_r_o, ci_g_o, ci_b_o;
vid_mux #(BITS*3) mux_ccm_inp_i0(pclk, rst_n, rgb_inp_en, dm_href_o, dm_vsync_o, {dm_r_o,dm_g_o,dm_b_o}, in_href_rgb, in_vsync_rgb, {in_r,in_g,in_b}, ci_href_o, ci_vsync_o, {ci_r_o,ci_g_o,ci_b_o});
// Color Correction Matrix	
wire ccm_href_o, ccm_vsync_o;
wire [BITS-1:0] ccm_r_o, ccm_g_o, ccm_b_o;
if ( USE_CCM ) begin : _CCM
    wire ccm_href, ccm_vsync;
    wire [BITS-1:0] ccm_r, ccm_g, ccm_b;
   isp_ccm #(BITS, WIDTH, HEIGHT) ccm_i0(pclk, rst_n&ccm_en, ccm_rr, ccm_rg, ccm_rb, ccm_gr, ccm_gg, ccm_gb, ccm_br, ccm_bg, ccm_bb,
	                                     ci_href_o, ci_vsync_o, ci_r_o, ci_g_o, ci_b_o, ccm_href, ccm_vsync, ccm_r, ccm_g, ccm_b);
   vid_mux #(BITS*3) mux_ccm_i0(pclk, rst_n, ccm_en, ci_href_o, ci_vsync_o, {ci_r_o,ci_g_o,ci_b_o}, ccm_href, ccm_vsync, {ccm_r,ccm_g,ccm_b}, ccm_href_o, ccm_vsync_o, {ccm_r_o,ccm_g_o,ccm_b_o});
end
else begin : _N_CCM 
   assign ccm_href_o = ci_href_o;
   assign ccm_vsync_o = ci_vsync_o;
   assign ccm_r_o = ci_r_o;
   assign ccm_g_o = ci_g_o;
   assign ccm_b_o = ci_b_o;
end
// Gamma Correction
wire gamma_href_o, gamma_vsync_o;
wire [BITS-1:0] gamma_r_o, gamma_g_o, gamma_b_o;
if ( USE_GAMMA) begin : _GAMMA
   wire gamma_href, gamma_vsync;
   wire [BITS-1:0] gamma_r, gamma_g, gamma_b;
   isp_gamma #(BITS, WIDTH, HEIGHT, GAMMA_R_LUT, GAMMA_G_LUT, GAMMA_B_LUT) gamma_i0(pclk, rst_n&gamma_en, ccm_href_o, ccm_vsync_o, ccm_r_o, ccm_g_o, ccm_b_o, gamma_href, gamma_vsync, gamma_r, gamma_g, gamma_b, 
	  													     gamma_table_r_clk, gamma_table_r_wen, gamma_table_r_ren, gamma_table_r_addr, gamma_table_r_wdata, gamma_table_r_rdata,
														     gamma_table_g_clk, gamma_table_g_wen, gamma_table_g_ren, gamma_table_g_addr, gamma_table_g_wdata, gamma_table_g_rdata,
														     gamma_table_b_clk, gamma_table_b_wen, gamma_table_b_ren, gamma_table_b_addr, gamma_table_b_wdata, gamma_table_b_rdata);
   vid_mux #(BITS*3) mux_gamma_i0(pclk, rst_n, gamma_en, ccm_href_o, ccm_vsync_o, {ccm_r_o,ccm_g_o,ccm_b_o}, gamma_href, gamma_vsync, {gamma_r,gamma_g,gamma_b}, gamma_href_o, gamma_vsync_o, {gamma_r_o,gamma_g_o,gamma_b_o});
end
else begin : _N_GAMMA
   assign gamma_href_o = ccm_href_o;
   assign gamma_vsync_o = ccm_vsync_o;
   assign gamma_r_o = ccm_r_o;
   assign gamma_g_o = ccm_g_o;
   assign gamma_b_o = ccm_b_o;
end

// Auto Exposure
if ( USE_AE) begin : _AE
   isp_ae #(BITS, WIDTH, HEIGHT) isp_ae_i0(pclk, rst_n&ae_en, gamma_href_o, gamma_vsync_o, gamma_r_o, gamma_g_o, gamma_b_o, center_illuminance, skewness, ae_crop_left, ae_crop_right, ae_crop_top, ae_crop_bottom, ae_response, ae_result_skewness, ae_response_debug, ae_done
																										/*,cropped_size,
																										sum_pix_square,
																										sum_pix_cube,
																										div_out_m_2,
																										div_out_m_3,
																										div_out_sqrt_fsm,
																										sqrt_fsm_out_sqrt,
																										div_out_ae_skewness,
																										SQRT_FSM_EN,
																										SQRT_FSM_DIV_EN,
																										SQRT_FSM_DIV_DONE,
																										SQRT_FSM_DONE,
																										SQRT_FSM_COUNT*/
																										);
   isp_dgain_update  #(DGAIN_ARRAY_SIZE, DGAIN_ARRAY_BITS) isp_dgain_update_i0(pclk, rst_n&ae_en, ae_response, applied_dg_index, ae_feedback);
end
else begin
assign ae_feedback = 0; // first gain from the Dgain Array
end

// Color Space Conversion
wire csc_href_o, csc_vsync_o;
wire [BITS-1:0] csc_y_o, csc_u_o, csc_v_o;
if ( USE_CSC ) begin : _CSC
   wire csc_href, csc_vsync;
   wire [BITS-1:0] csc_y, csc_u, csc_v;
   isp_csc #(BITS, WIDTH, HEIGHT) csc_i0(pclk, rst_n&csc_en, gamma_href_o, gamma_vsync_o, in_conv_standard, gamma_r_o, gamma_g_o, gamma_b_o, csc_href, csc_vsync, csc_y, csc_u, csc_v);
   vid_mux #(BITS*3) mux_csc_i0(pclk, rst_n, csc_en, gamma_href_o, gamma_vsync_o, {gamma_r_o, gamma_g_o, gamma_b_o}, csc_href, csc_vsync, {csc_y, csc_u, csc_v}, csc_href_o, csc_vsync_o, {csc_y_o,csc_u_o,csc_v_o});
end
else begin : _N_CSC
   assign csc_href_o = gamma_href_o;
   assign csc_vsync_o = gamma_vsync_o;
   assign csc_y_o = {{(BITS-8){1'b0}}, gamma_r_o[BITS-1:BITS-8]};    // output of CSC is in 8 bits effectively
   assign csc_u_o = {{(BITS-8){1'b0}}, gamma_g_o[BITS-1:BITS-8]};
   assign csc_v_o = {{(BITS-8){1'b0}}, gamma_b_o[BITS-1:BITS-8]};
end
// Local Dynamic Contrast Enhancement
wire ldci_href_o, ldci_vsync_o;
wire [7:0] ldci_y_o, ldci_u_o, ldci_v_o;
if (USE_LDCI) begin : _LDCI
    wire ldci_href, ldci_vsync;
    wire [7:0] ldci_y, ldci_u, ldci_v;
    assign ldci_href = csc_href_o;
    assign ldci_vsync = csc_vsync_o;
    assign ldci_y = csc_y_o[7:0];
    assign ldci_u = csc_u_o[7:0];
    assign ldci_v = csc_v_o[7:0];
    vid_mux #(8*3) mux_csc_i0(pclk, rst_n, ldci_en, csc_href_o, csc_vsync_o, {csc_y_o[7:0], csc_u_o[7:0], csc_v_o[7:0]}, ldci_href, ldci_vsync, {ldci_y, ldci_u, ldci_v}, ldci_href_o, ldci_vsync_o, {ldci_y_o, ldci_u_o,ldci_v_o});
end 
else begin : _N_LDCI
    assign ldci_href_o = csc_href_o;
    assign ldci_vsync_o = csc_vsync_o;
    assign ldci_v_o = csc_v_o[7:0];   // output of CSC is in 8 bits effectively
    assign ldci_u_o = csc_u_o[7:0];
    assign ldci_y_o = csc_y_o[7:0];
end

// Sharpening
wire sharp_href_o, sharp_vsync_o;
wire [7:0] sharp_y_o, sharp_u_o, sharp_v_o;
if (USE_SHARP) begin : _SHARP
    wire sharp_href, sharp_vsync;
    wire [7:0] sharp_y, sharp_u, sharp_v;
	isp_sharpen #(8, WIDTH, HEIGHT, SHARP_WEIGHT_BITS) sharp_i0(pclk, rst_n&sharp_en, luma_kernel, sharpen_strength, ldci_href_o, ldci_vsync_o, ldci_y_o, ldci_u_o, ldci_v_o, sharp_href, sharp_vsync, sharp_y, sharp_u, sharp_v);
    vid_mux #(8*3) mux_sharp_i0(pclk, rst_n, sharp_en, ldci_href_o, ldci_vsync_o, {ldci_y_o, ldci_u_o, ldci_v_o}, sharp_href, sharp_vsync, {sharp_y, sharp_u, sharp_v}, sharp_href_o, sharp_vsync_o, {sharp_y_o, sharp_u_o, sharp_v_o});
end

else begin : _N_SHARP
    assign sharp_href_o = ldci_href_o;
    assign sharp_vsync_o = ldci_vsync_o;
    assign sharp_v_o = ldci_v_o;
    assign sharp_u_o = ldci_u_o;
    assign sharp_y_o = ldci_y_o;
end

// 2D Noise Reduction
wire nr2d_href_o, nr2d_vsync_o;
wire [7:0] nr2d_y_o, nr2d_u_o, nr2d_v_o;  
if ( USE_2DNR) begin : _2DNR
   wire nr2d_href, nr2d_vsync;
   wire [7:0] nr2d_y, nr2d_u, nr2d_v, nr2d_u_tmp, nr2d_v_tmp;
   isp_2dnr #(8, WIDTH, HEIGHT, 5, 32) nr2d_y0(pclk, rst_n&nr2d_en, nr2d_diff, nr2d_weight,
   										sharp_href_o, sharp_vsync_o, sharp_y_o, sharp_u_o, sharp_v_o, nr2d_href, nr2d_vsync, nr2d_y, nr2d_u, nr2d_v);
  vid_mux #(8*3) mux_2dnr_i0(pclk, rst_n, nr2d_en, sharp_href_o, sharp_vsync_o, {sharp_y_o, sharp_u_o, sharp_v_o}, nr2d_href, nr2d_vsync, {nr2d_y,nr2d_u,nr2d_v}, nr2d_href_o, nr2d_vsync_o, {nr2d_y_o,nr2d_u_o,nr2d_v_o});

end	
else begin : _N_2DNR
   assign nr2d_href_o = sharp_href_o;
   assign nr2d_vsync_o = sharp_vsync_o;
   assign nr2d_y_o = sharp_y_o;
   assign nr2d_u_o = sharp_u_o;
   assign nr2d_v_o = sharp_v_o;
end
end
endgenerate 

assign out_gamma_href = d_top_gen_inside.gamma_href_o;
assign out_gamma_vsync = d_top_gen_inside.gamma_vsync_o;
assign out_gamma_r = d_top_gen_inside.gamma_r_o;    // output of CSC is in 8 bits effectively
assign out_gamma_g = d_top_gen_inside.gamma_g_o;
assign out_gamma_b = d_top_gen_inside.gamma_b_o;


assign out_href = d_top_gen_inside.nr2d_href_o;
assign out_vsync = d_top_gen_inside.nr2d_vsync_o;
assign out_y = d_top_gen_inside.nr2d_y_o;
assign out_u = d_top_gen_inside.nr2d_u_o;
assign out_v = d_top_gen_inside.nr2d_v_o;
endmodule



module data_delay
#(
	parameter BITS = 8,
	parameter DELAY = 5
)
(
	input clk,
	input rst_n,

	input  [BITS-1:0] in_data,
	output [BITS-1:0] out_data
);

	reg [BITS-1:0] data_buff [DELAY-1:0];
	always @ (posedge clk or negedge rst_n) begin : _blk_delay
		integer i;
		if (!rst_n) begin
			for (i = 0; i < DELAY; i = i + 1)
				data_buff[i] <= 0;
		end
		else begin
			data_buff[0] <= in_data;
			for (i = 1; i < DELAY; i = i + 1)
				data_buff[i] <= data_buff[i-1];
		end
	end

	assign out_data = data_buff[DELAY-1];
endmodule

module vid_mux
#(
	parameter BITS = 8
)
(
	input pclk,
	input rst_n,

	input sel,

	input in_href_0,
	input in_vsync_0,
	input [BITS-1:0] in_data_0,

	input in_href_1,
	input in_vsync_1,
	input [BITS-1:0] in_data_1,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data
);

	wire in_href = sel ? in_href_1 : in_href_0;
	wire in_vsync = sel ? in_vsync_1 : in_vsync_0;
	wire [BITS-1:0] in_data = sel ? in_data_1 : in_data_0;

	reg href_reg, vsync_reg;
	reg [BITS-1:0] data_reg;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			href_reg <= 0;
			vsync_reg <= 0;
			data_reg <= 0;
		end
		else begin
			href_reg <= in_href;
			vsync_reg <= in_vsync;
			data_reg <= in_data;
		end
	end
	
	assign out_href = href_reg;
	assign out_vsync = vsync_reg;
	assign out_data = data_reg;
endmodule
