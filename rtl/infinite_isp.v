/*************************************************************************
    > File Name: infinite_isp.v
    > Author: 10xEngineers
    > Mail: 10xengineers.ai
    > Created Time: Tue 16 Jan 2024 15:12:37 PST
 ************************************************************************/
`timescale 1 ns / 1 ps

module infinite_isp
#(
/* ****** ISP parameters ******* */
	parameter BITS = 10,
	parameter SNS_WIDTH = 2048,
	parameter SNS_HEIGHT = 1536,
	parameter CROP_WIDTH = 2048,
	parameter CROP_HEIGHT = 1536,
	parameter BAYER = 1, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter OECF_R_LUT = "OECF_R_LUT_INIT.mem",
	parameter OECF_GR_LUT = "OECF_GR_LUT_INIT.mem",
	parameter OECF_GB_LUT = "OECF_GB_LUT_INIT.mem",
	parameter OECF_B_LUT = "OECF_B_LUT_INIT.mem",
	parameter BNR_WEIGHT_BITS = 8,
	parameter DGAIN_ARRAY_SIZE = 100,
	parameter DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE),
	parameter AWB_CROP_LEFT = 8,
	parameter AWB_CROP_RIGHT = 8,
	parameter AWB_CROP_TOP = 16,
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
	parameter USE_LSC = 0,
	parameter USE_BNR = 1,	
	parameter USE_WB = 1,
	parameter USE_DEMOSIC = 1,	
	parameter USE_CCM = 1,
	parameter USE_GAMMA = 1,
	parameter USE_CSC = 1,
	parameter USE_SHARP = 1,
	parameter USE_LDCI = 0,
	parameter USE_2DNR = 1,
	parameter USE_STAT_AE = 0,
	parameter USE_AWB = 1,
	parameter USE_AE = 1,
    
/* ****** VIP1 parameters ******* */
	parameter VIP1_BITS = 8,
	parameter VIP1_OSD_RAM_ADDR_BITS = 9,
	parameter VIP1_OSD_RAM_DATA_BITS = 32,
	parameter VIP1_USE_HIST_EQU = 0,
	parameter VIP1_USE_SOBEL = 0,
	parameter VIP1_USE_RGBC = 1,
	parameter VIP1_USE_IRC = 1,
	parameter VIP1_USE_SCALE = 1,
	parameter VIP1_USE_OSD = 1,
	parameter VIP1_USE_YUVConvFormat = 1,

/* ****** VIP2 parameters ******* */
	parameter VIP2_BITS = 8,
	parameter VIP2_OSD_RAM_ADDR_BITS = 9,
	parameter VIP2_OSD_RAM_DATA_BITS = 32,
	parameter VIP2_USE_HIST_EQU = 0,
	parameter VIP2_USE_SOBEL = 0,
	parameter VIP2_USE_RGBC = 0,
	parameter VIP2_USE_IRC = 0,
	parameter VIP2_USE_SCALE = 0,
	parameter VIP2_USE_OSD = 0,
	parameter VIP2_USE_YUVConvFormat = 0
)
(
    /* **************************** */
    /* ****** ISP I/O ports ******* */
    /* **************************** */
    
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
	
	output isp_out_href,
	output isp_out_vsync,
	
	output out_gamma_href,
	output out_gamma_vsync,
	output [BITS-1:0] out_gamma_r,
	output [BITS-1:0] out_gamma_g,
	output [BITS-1:0] out_gamma_b,

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
	input               gamma_table_r_clk, gamma_table_g_clk, gamma_table_b_clk,
	input               gamma_table_r_wen, gamma_table_g_wen, gamma_table_b_wen,
	input               gamma_table_r_ren, gamma_table_g_ren, gamma_table_b_ren,
	input  [BITS-1:0] 	gamma_table_r_addr, gamma_table_g_addr, gamma_table_b_addr,
	input  [BITS-1:0] 	gamma_table_r_wdata, gamma_table_g_wdata, gamma_table_b_wdata,
	output [BITS-1:0] 	gamma_table_r_rdata, gamma_table_g_rdata, gamma_table_b_rdata,
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
	output [11:0] final_r_gain, final_b_gain,

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
    
    /* **************************** */
    /* ****** VIP1 I/O ports ******* */
    /* **************************** */
	
	// Scale Clock
	input scale_pclk1,
    // VIP1 Output Signals
	output out_pclk,
	output out_href,
	output out_vsync,
	output [VIP1_BITS-1:0] out_r,	//out_y
	output [VIP1_BITS-1:0] out_g,	//out_u
	output [VIP1_BITS-1:0] out_b,	//out_b
	
	// Enables
	input hist_equ_en, sobel_en, rgbc_en, irc_en, dscale_en, osd_en, yuv444to422_en,
	// Hist Equal
	input [VIP1_BITS-1:0] equ_min, equ_max,
	// RGBC
	input [1:0] in_conv_standard_rgbc,
	// IRC
	input [15:0] crop_x, crop_y,
	input [1:0] irc_output, // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
	// SCALE
	input [11:0] s_in_crop_w,
	input [11:0] s_in_crop_h,
	input [11:0] s_out_crop_w,
	input [11:0] s_out_crop_h,
	input [2:0] dscale_w,
	input [2:0] dscale_h,
	// OSD
	input [15:0] osd_x, osd_y, osd_w, osd_h,
	input [23:0] osd_color_fg, osd_color_bg,	// {osd_r, osd_g, osd_b}
	input [7:0] osd_alpha,
	input                          osd_ram_clk,
	input                          osd_ram_wen,
	input                          osd_ram_ren,
	input  [VIP1_OSD_RAM_ADDR_BITS-1:0] osd_ram_addr,
	input  [VIP1_OSD_RAM_DATA_BITS-1:0] osd_ram_wdata,
	output [VIP1_OSD_RAM_DATA_BITS-1:0] osd_ram_rdata,
	// YUVConvFormat
	input YUV444TO422,
    
    /* ***************************** */
    /* ****** VIP2 I/O ports ******* */
    /* ***************************** */
    
    // Scale Clock
	input scale_pclk2,
    // VIP2 Output Signals
    output out_pclk2,
	output out_href2,
	output out_vsync2,
	output [VIP2_BITS-1:0] out_r2,	//out_y2
	output [VIP2_BITS-1:0] out_g2,	//out_u2
	output [VIP2_BITS-1:0] out_b2,	//out_v2
    
    // Enables
    input hist_equ_en2, sobel_en2, rgbc_en2, irc_en2, dscale_en2, osd_en2, yuv444to422_en2,
    // Hist Equal
	input [VIP2_BITS-1:0] equ_min2, equ_max2,
	// RGBC
	input [1:0] in_conv_standard_rgbc2,
	// IRC
	input [15:0] crop_x2, crop_y2,
	input [1:0] irc_output2, // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
	// SCALE
    input [11:0] s_in_crop_w2,
	input [11:0] s_in_crop_h2,
	input [11:0] s_out_crop_w2,
	input [11:0] s_out_crop_h2,
	input [2:0] dscale_w2,
	input [2:0] dscale_h2,
	// OSD
	input [15:0] osd_x2, osd_y2, osd_w2, osd_h2,
	input [23:0] osd_color_fg2, osd_color_bg2,	//	{osd_r, osd_g, osd_b}
	input [7:0] osd_alpha2,
	input                          osd_ram_clk2,
	input                          osd_ram_wen2,
	input                          osd_ram_ren2,
	input  [VIP2_OSD_RAM_ADDR_BITS-1:0] osd_ram_addr2,
	input  [VIP2_OSD_RAM_DATA_BITS-1:0] osd_ram_wdata2,
    output [VIP2_OSD_RAM_DATA_BITS-1:0] osd_ram_rdata2,
	// YUVConvFormat
	input YUV444TO4222
);

	wire [VIP1_BITS-1:0] out_y;
	wire [VIP1_BITS-1:0] out_u;
	wire [VIP1_BITS-1:0] out_v;
    
    // ISP Module Instantiation
    isp_top	#(
	  .BITS 				(BITS				),
	  .SNS_WIDTH 			(SNS_WIDTH			),
	  .SNS_HEIGHT 			(SNS_HEIGHT			),
	  .CROP_WIDTH 			(CROP_WIDTH			),
	  .CROP_HEIGHT 			(CROP_HEIGHT		),
	  .BAYER 				(BAYER				),
	  .OECF_R_LUT       	(OECF_R_LUT			),
	  .OECF_GR_LUT      	(OECF_GR_LUT		),
	  .OECF_GB_LUT      	(OECF_GB_LUT		),
	  .OECF_B_LUT       	(OECF_B_LUT			),
	  .BNR_WEIGHT_BITS  	(BNR_WEIGHT_BITS	),
	  .DGAIN_ARRAY_SIZE 	(DGAIN_ARRAY_SIZE	),
	  .DGAIN_ARRAY_BITS 	(DGAIN_ARRAY_BITS	),
	  .AWB_CROP_LEFT    	(AWB_CROP_LEFT		),
	  .AWB_CROP_RIGHT   	(AWB_CROP_RIGHT		),
	  .AWB_CROP_TOP     	(AWB_CROP_TOP		),
	  .AWB_CROP_BOTTOM  	(AWB_CROP_BOTTOM	),
	  .GAMMA_R_LUT      	(GAMMA_R_LUT		),
	  .GAMMA_G_LUT      	(GAMMA_G_LUT		),
	  .GAMMA_B_LUT      	(GAMMA_B_LUT		),
	  .SHARP_WEIGHT_BITS	(SHARP_WEIGHT_BITS	),
	  .NR2D_WEIGHT_BITS		(NR2D_WEIGHT_BITS	),
	  .STAT_OUT_BITS 		(STAT_OUT_BITS		),
	  .STAT_HIST_BITS 		(STAT_HIST_BITS		),
	  .USE_CROP				(USE_CROP			),
	  .USE_DPC				(USE_DPC			),
	  .USE_BLC				(USE_BLC			),
	  .USE_OECF				(USE_OECF			),	  
	  .USE_DGAIN			(USE_DGAIN			),
	  .USE_LSC    			(USE_LSC			),
	  .USE_BNR				(USE_BNR			),					
	  .USE_WB				(USE_WB				),
	  .USE_DEMOSIC			(USE_DEMOSIC		),
	  .USE_CCM				(USE_CCM			),
	  .USE_GAMMA			(USE_GAMMA			),
	  .USE_CSC				(USE_CSC			),
	  .USE_SHARP			(USE_SHARP			), 
	  .USE_LDCI				(USE_LDCI			),
	  .USE_2DNR				(USE_2DNR			),
	  .USE_STAT_AE			(USE_STAT_AE		),
	  .USE_AWB			    (USE_AWB			),
	  .USE_AE				(USE_AE				)
	 )
	isp_top_i0(
		// Clock and rest
		.pclk(pclk), 
		.rst_n(rst_n), 
		// DVP input
		.in_href(in_href),	.in_vsync(in_vsync), .in_raw(in_raw),
		// DVP 3 channel input
		.in_href_rgb(in_href_rgb),	.in_vsync_rgb(in_vsync_rgb), .in_r(in_r), .in_g(in_g), .in_b(in_b),  						 
		// DVP output
		.out_href(isp_out_href), .out_vsync(isp_out_vsync), .out_y(out_y), .out_u(out_u), .out_v(out_v), 	 
		// DVP Gamma output
		.out_gamma_href(out_gamma_href), .out_gamma_vsync(out_gamma_vsync), .out_gamma_b(out_gamma_b), .out_gamma_g(out_gamma_g), .out_gamma_r(out_gamma_r), 	 
		// Enable 3 channel input from outside
		.rgb_inp_en(rgb_inp_en),
		// Enable signals
		.crop_en(crop_en), .dpc_en(dpc_en), .blc_en(blc_en), .bnr_en(bnr_en), .dgain_en(dgain_en),                    
		.lsc_en(lsc_en), .demosic_en(demosic_en), .oecf_en(oecf_en), .wb_en(wb_en), 
		.ccm_en(ccm_en), .csc_en(csc_en), .gamma_en(gamma_en), 
		.nr2d_en(nr2d_en), .sharp_en(sharp_en), .ldci_en(ldci_en), .stat_ae_en(stat_ae_en), .awb_en(awb_en), .ae_en(ae_en),  
		// DPC
		.dpc_threshold(dpc_threshold),
		// BLC and Linearization
		.blc_r(blc_r), .blc_gr(blc_gr), .blc_gb(blc_gb), .blc_b(blc_b), .linear_en(linear_en),
		.linear_r(linear_r), .linear_gr(linear_gr), .linear_gb(linear_gb), .linear_b(linear_b),
		// OECF
		.r_table_clk(r_table_clk), .gr_table_clk(gr_table_clk), .gb_table_clk(gb_table_clk), .b_table_clk(b_table_clk),
		.r_table_wen(r_table_wen), .gr_table_wen(gr_table_wen), .gb_table_wen(gb_table_wen), .b_table_wen(b_table_wen),
		.r_table_ren(r_table_ren), .gr_table_ren(gr_table_ren), .gb_table_ren(gb_table_ren), .b_table_ren(b_table_ren),
		.r_table_addr(r_table_addr), .gr_table_addr(gr_table_addr), .gb_table_addr(gb_table_addr), .b_table_addr(b_table_addr),
		.r_table_wdata(r_table_wdata), .gr_table_wdata(gr_table_wdata), .gb_table_wdata(gb_table_wdata), .b_table_wdata(b_table_wdata),
		.r_table_rdata(r_table_rdata), .gr_table_rdata(gr_table_rdata), .gb_table_rdata(gb_table_rdata), .b_table_rdata(b_table_rdata),
		// BNR
		.bnr_space_kernel_r(bnr_space_kernel_r),.bnr_space_kernel_g(bnr_space_kernel_g), .bnr_space_kernel_b(bnr_space_kernel_b),
		.bnr_color_curve_x_r(bnr_color_curve_x_r), .bnr_color_curve_y_r(bnr_color_curve_y_r),
		.bnr_color_curve_x_g(bnr_color_curve_x_g), .bnr_color_curve_y_g(bnr_color_curve_y_g),
		.bnr_color_curve_x_b(bnr_color_curve_x_b), .bnr_color_curve_y_b(bnr_color_curve_y_b), 
		// DG
		.dgain_array(dgain_array),
		.dgain_isManual(dgain_isManual),
		.dgain_man_index(dgain_man_index),
		.dgain_index_out(dgain_index_out),
		// WB
		.wb_rgain(wb_rgain), .wb_bgain(wb_bgain), 
		// CCM
		.ccm_rr(ccm_rr), .ccm_rg(ccm_rg), .ccm_rb(ccm_rb), 
		.ccm_gr(ccm_gr), .ccm_gg(ccm_gg), .ccm_gb(ccm_gb), 
		.ccm_br(ccm_br), .ccm_bg(ccm_bg), .ccm_bb(ccm_bb),
		// GAMMA
		.gamma_table_r_clk(gamma_table_r_clk), .gamma_table_r_wen(gamma_table_r_wen), .gamma_table_r_ren(gamma_table_r_ren), .gamma_table_r_addr(gamma_table_r_addr), .gamma_table_r_wdata(gamma_table_r_wdata), .gamma_table_r_rdata(gamma_table_r_rdata),
		.gamma_table_g_clk(gamma_table_g_clk), .gamma_table_g_wen(gamma_table_g_wen), .gamma_table_g_ren(gamma_table_g_ren), .gamma_table_g_addr(gamma_table_g_addr), .gamma_table_g_wdata(gamma_table_g_wdata), .gamma_table_g_rdata(gamma_table_g_rdata),
		.gamma_table_b_clk(gamma_table_b_clk), .gamma_table_b_wen(gamma_table_b_wen), .gamma_table_b_ren(gamma_table_b_ren), .gamma_table_b_addr(gamma_table_b_addr), .gamma_table_b_wdata(gamma_table_b_wdata), .gamma_table_b_rdata(gamma_table_b_rdata),
		//CSC
		.in_conv_standard(in_conv_standard),
		// SHARP
		.luma_kernel(luma_kernel), .sharpen_strength(sharpen_strength),
		// 2DNR
		.nr2d_diff(nr2d_diff), .nr2d_weight(nr2d_weight), 
		// AE
		.center_illuminance(center_illuminance),
        .skewness(skewness),
		.ae_crop_left(ae_crop_left),
		.ae_crop_right(ae_crop_right),
		.ae_crop_top(ae_crop_top),
		.ae_crop_bottom(ae_crop_bottom),
        .ae_response(ae_response),
        .ae_result_skewness(ae_result_skewness),
        .ae_response_debug(ae_response_debug),
		.ae_done(ae_done),
		/*
		//===== AE debug ports =====//
		.cropped_size(ae_cropped_size),
		.sum_pix_square(sum_pix_square),
		.sum_pix_cube(sum_pix_cube),
		.div_out_m_2(div_out_m_2),
		.div_out_m_3(div_out_m_3),
		.div_out_sqrt_fsm(div_out_sqrt_fsm),
		.sqrt_fsm_out_sqrt(sqrt_fsm_out_sqrt),
		.div_out_ae_skewness(div_out_ae_skewness),
		.SQRT_FSM_EN(SQRT_FSM_EN),
		.SQRT_FSM_DIV_EN(SQRT_FSM_DIV_EN),
		.SQRT_FSM_DIV_DONE(SQRT_FSM_DIV_DONE),
		.SQRT_FSM_DONE(SQRT_FSM_DONE),
		//===== AE debug ports =====//
		*/
      	// AWB
		.awb_underexposed_limit(awb_underexposed_limit), .awb_overexposed_limit(awb_overexposed_limit), .awb_frames(awb_frames), .final_r_gain(final_r_gain), .final_b_gain(final_b_gain)
	);

    // VIP1 Module Instantiation
	vip_top	#(
	  .BITS 				(VIP1_BITS				),
	  .WIDTH 				(CROP_WIDTH				),
	  .HEIGHT 				(CROP_HEIGHT			),
      .OSD_RAM_ADDR_BITS    (VIP1_OSD_RAM_ADDR_BITS	),
	  .OSD_RAM_DATA_BITS    (VIP1_OSD_RAM_DATA_BITS	),
	  .USE_HIST_EQU			(VIP1_USE_HIST_EQU		),
	  .USE_SOBEL			(VIP1_USE_SOBEL			),
	  .USE_RGBC				(VIP1_USE_RGBC	  		),
	  .USE_IRC				(VIP1_USE_IRC			),
	  .USE_SCALE    		(VIP1_USE_SCALE			),
	  .USE_OSD				(VIP1_USE_OSD			),		
	  .USE_YUVConvFormat	(VIP1_USE_YUVConvFormat	)
	)
	vip_top_i0(
		// Clock and rest
		.pclk(pclk),
		.scale_pclk(scale_pclk1), 
		.rst_n(rst_n),
		// Input 
		.in_href(isp_out_href), .in_vsync(isp_out_vsync), .in_y(out_y), .in_u(out_u), .in_v(out_v),
		// Output
		.out_pclk(out_pclk), .out_href(out_href), .out_vsync(out_vsync), .out_r(out_r), .out_g(out_g), .out_b(out_b), 
		// Module Enables
		.hist_equ_en(hist_equ_en), .sobel_en(sobel_en), .rgbc_en(rgbc_en), .irc_en(irc_en), .dscale_en(dscale_en), .osd_en(osd_en), .yuv444to422_en(yuv444to422_en),
		// Hist_equ
		.equ_min(equ_min), .equ_max(equ_max),
		// RGBC
		.in_conv_standard(in_conv_standard_rgbc),
		// Crop
		.crop_x(crop_x), .crop_y(crop_y), .irc_output(irc_output),
		.s_in_crop_w(s_in_crop_w), .s_in_crop_h(s_in_crop_h), .s_out_crop_w(s_out_crop_w), .s_out_crop_h(s_out_crop_h),
		// SCALE
		.dscale_w(dscale_w), .dscale_h(dscale_h),
		// YUV444-422
		.YUV444TO422(YUV444TO422),
		// OSD 						 
		.osd_x(osd_x), .osd_y(osd_y), .osd_w(osd_w), .osd_h(osd_h),
		.fg_color(osd_color_fg), .bg_color(osd_color_bg), .alpha(osd_alpha),
		.osd_ram_clk(osd_ram_clk), .osd_ram_wen(osd_ram_wen), .osd_ram_ren(osd_ram_ren), .osd_ram_addr(osd_ram_addr), .osd_ram_wdata(osd_ram_wdata), .osd_ram_rdata(osd_ram_rdata)
	);
    
    // VIP2 Module Instantiation
	vip_top	#(
	  .BITS 				(VIP2_BITS				),
	  .WIDTH 				(CROP_WIDTH				),
	  .HEIGHT 				(CROP_HEIGHT			),
      .OSD_RAM_ADDR_BITS    (VIP2_OSD_RAM_ADDR_BITS	),
	  .OSD_RAM_DATA_BITS    (VIP2_OSD_RAM_DATA_BITS	),
	  .USE_HIST_EQU			(VIP2_USE_HIST_EQU		),
	  .USE_SOBEL			(VIP2_USE_SOBEL			),
	  .USE_RGBC				(VIP2_USE_RGBC	  		),
	  .USE_IRC				(VIP2_USE_IRC			),
	  .USE_SCALE    		(VIP2_USE_SCALE			),
	  .USE_OSD				(VIP2_USE_OSD			),		
	  .USE_YUVConvFormat	(VIP2_USE_YUVConvFormat	)
	)
	vip_top_i1(
		// Clock and rest
		.pclk(pclk),
		.scale_pclk(scale_pclk2), 
		.rst_n(rst_n),
		// Input 
		.in_href(isp_out_href), .in_vsync(isp_out_vsync), .in_y(out_y), .in_u(out_u), .in_v(out_v),
		// Output
		.out_pclk(out_pclk2), .out_href(out_href2), .out_vsync(out_vsync2), .out_r(out_r2), .out_g(out_g2), .out_b(out_b2), 
		// Module Enables
		.hist_equ_en(hist_equ_en2), .sobel_en(sobel_en2), .rgbc_en(rgbc_en2), .irc_en(irc_en2), .dscale_en(dscale_en2), .osd_en(osd_en2), .yuv444to422_en(yuv444to422_en2),
		// Hist_equ
		.equ_min(equ_min2), .equ_max(equ_max2),
		// RGBC
		.in_conv_standard(in_conv_standard_rgbc2),
		// IRC
		.crop_x(crop_x2), .crop_y(crop_y2), .irc_output(irc_output2),
		.s_in_crop_w(s_in_crop_w2), .s_in_crop_h(s_in_crop_h2), .s_out_crop_w(s_out_crop_w2), .s_out_crop_h(s_out_crop_h2),
		// SCALE
		.dscale_w(dscale_w2), .dscale_h(dscale_h2),
		// YUV444-422
		.YUV444TO422(YUV444TO4222),
		// OSD 						 
		.osd_x(osd_x2), .osd_y(osd_y2), .osd_w(osd_w2), .osd_h(osd_h2),
		.fg_color(osd_color_fg2), .bg_color(osd_color_bg2), .alpha(osd_alpha2),
		.osd_ram_clk(osd_ram_clk2), .osd_ram_wen(osd_ram_wen2), .osd_ram_ren(osd_ram_ren2), .osd_ram_addr(osd_ram_addr2), .osd_ram_wdata(osd_ram_wdata2), .osd_ram_rdata(osd_ram_rdata2)
	);
endmodule