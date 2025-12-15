/*************************************************************************
> File Name: isp_top_wrapper.v
> Description: wrapper module for isp top
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Top Wrapper
 */

module isp_top_wrapper
#(
	parameter BITS = 12,
	parameter WIDTH = 2592,
	parameter HEIGHT = 1536,
	parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter OECF_TABLE_BITS = BITS,
	parameter OECF_R_LUT = "OECF_R_LUT_INIT.mem",
	parameter OECF_GR_LUT = "OECF_GR_LUT_INIT.mem",
	parameter OECF_GB_LUT = "OECF_GB_LUT_INIT.mem",
	parameter OECF_B_LUT = "OECF_B_LUT_INIT.mem",
	parameter BNR_WEIGHT_BITS = 5,
	parameter GAMMA_TABLE_BITS = BITS,
	parameter GAMMA_R_LUT = "GAMMA_R_LUT_INIT.mem",
	parameter GAMMA_G_LUT = "GAMMA_G_LUT_INIT.mem",
	parameter GAMMA_B_LUT = "GAMMA_B_LUT_INIT.mem",
	parameter NR2D_WEIGHT_BITS = 5,
	parameter STAT_OUT_BITS = 32,
	parameter STAT_HIST_BITS = BITS, //??-????? ???(???? ??)
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
	parameter USE_LDCI = 0,
	parameter USE_2DNR = 0,
	parameter USE_EE = 0,
	parameter USE_STAT_AE = 0,
	parameter USE_AWB = 1
)
(
    input pclk,
	input rst_n,
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	
	output out_href,
	output out_vsync,
	output [BITS-1:0] out_y,
	output [BITS-1:0] out_u,
	output [BITS-1:0] out_v,
	output reg [31:0] out_mux
);

    // Tunabale parameters of the ISP ( as inputs to the module)
    localparam DPC_THRESHOLD = 80; 
	// BLC and linearization
	localparam BLC_R = 25;
	localparam BLC_GR = 25;
	localparam BLC_GB = 25;
	localparam BLC_B = 25;
	localparam LINEAR_R = 16'b0100010011110011;  
	localparam LINEAR_GR = 16'b0100010010110010; //
	localparam LINEAR_GB = 16'b0100010010110010; // 
	localparam LINEAR_B = 16'b0100010100000101;  //  	
	// BNR
	localparam BNR_SPACE_KERNEL_R = {{5'd0},{5'd0},{5'd1},{5'd0},{5'd0},
									 {5'd0},{5'd5},{5'd13},{5'd5},{5'd0},
									 {5'd1},{5'd13},{5'd31},{5'd13},{5'd1},
									 {5'd0},{5'd5},{5'd13},{5'd5},{5'd0},
									 {5'd0},{5'd0},{5'd1},{5'd0},{5'd0}};
	localparam BNR_SPACE_KERNEL_G = {{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd0},{5'd1},{5'd1},{5'd1},{5'd0},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd1},{5'd6},{5'd14},{5'd6},{5'd1},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd1},{5'd14},{5'd31},{5'd14},{5'd1},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd1},{5'd6},{5'd14},{5'd6},{5'd1},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd0},{5'd1},{5'd1},{5'd1},{5'd0},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},
									 {5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0}};
	localparam BNR_SPACE_KERNEL_B = {{5'd0},{5'd0},{5'd1},{5'd0},{5'd0},
									 {5'd0},{5'd5},{5'd13},{5'd5},{5'd0},
									 {5'd1},{5'd13},{5'd31},{5'd13},{5'd1},
									 {5'd0},{5'd5},{5'd13},{5'd5},{5'd0},
									 {5'd0},{5'd0},{5'd1},{5'd0},{5'd0}};
	localparam BNR_COLOR_CURVE_X_R = {{12'd1179},{12'd1048},{12'd917},{12'd786},{12'd655},{12'd524},{12'd393},{12'd262},{12'd131}};
	localparam BNR_COLOR_CURVE_Y_R = {{5'd6},{5'd9},{5'd12},{5'd15},{5'd19},{5'd23},{5'd26},{5'd29},{5'd30}};
	localparam BNR_COLOR_CURVE_X_G = {{12'd368},{12'd327},{12'd286},{12'd245},{12'd204},{12'd163},{12'd122},{12'd81},{12'd40}};
	localparam BNR_COLOR_CURVE_Y_G = {{5'd6},{5'd9},{5'd12},{5'd15},{5'd19},{5'd23},{5'd26},{5'd29},{5'd30}};
	localparam BNR_COLOR_CURVE_X_B = {{12'd1179},{12'd1048},{12'd917},{12'd786},{12'd655},{12'd524},{12'd393},{12'd262},{12'd131}};
	localparam BNR_COLOR_CURVE_Y_B = {{5'd6},{5'd9},{5'd12},{5'd15},{5'd19},{5'd23},{5'd26},{5'd29},{5'd30}};
	// Digital gain
	localparam DGAIN = 1;
	// White Balance
	localparam WB_RGAIN = 12'b000100100010; // 1.24609375 in 4.8 format
	localparam WB_BGAIN = 12'b000110000010;
	// CCM
	localparam CCM_RR = 16'd2053;	   localparam CCM_RG = -1*(16'd37); 	localparam CCM_RB = -1*(16'd991);
	localparam CCM_GR =  -1*(16'd390); 	localparam CCM_GG = 16'd1700; 	    localparam CCM_GB = -1*(16'd287);
	localparam CCM_BR =  (16'd30);	localparam CCM_BG = -1*(16'd1146);    localparam CCM_BB = 16'd2200;
	// CSC
	localparam CSC_CONV_STD = 2'd2;
	// 2DNR
	localparam NR2D_SPACE_KERNEL = {{5'd28}, {5'd29}, {5'd29}, {5'd30}, {5'd29}, {5'd29}, {5'd28},
	                                {5'd29}, {5'd30}, {5'd30}, {5'd30}, {5'd30}, {5'd30}, {5'd29},
	                                {5'd29}, {5'd30}, {5'd31}, {5'd31}, {5'd31}, {5'd30}, {5'd29},
	                                {5'd30}, {5'd30}, {5'd31}, {5'd31}, {5'd31}, {5'd30}, {5'd30},
	                                {5'd29}, {5'd30}, {5'd31}, {5'd31}, {5'd31}, {5'd30}, {5'd29},
	                                {5'd29}, {5'd30}, {5'd30}, {5'd30}, {5'd30}, {5'd30}, {5'd29},
	                                {5'd28}, {5'd29}, {5'd29}, {5'd30}, {5'd29}, {5'd29}, {5'd28}};
	localparam NR2D_COLOR_CURVE_X = {{8'd3}, {8'd6}, {8'd10}, {8'd13}, {8'd17}, {8'd20}, {8'd23}, {8'd27}, {8'd30}};
	localparam NR2D_COLOR_CURVE_Y = {{5'd30}, {5'd26}, {5'd19}, {5'd13}, {5'd7}, {5'd4}, {5'd2}, {5'd2}, {5'd0}};
	// Auto Exposure
	localparam STAT_AE_RECT_X = 0;
	localparam STAT_AE_RECT_Y = 0;
	localparam STAT_AE_RECT_W = 0;
	localparam STAT_AE_RECT_H = 0;
	// Auto White Balance
	localparam AWB_MIN = 5;
    localparam AWB_MAX = 5;
    localparam AWB_FRAMES = 1;

    (* dont_touch = "yes" *) reg in_href_rgb;
	(* dont_touch = "yes" *) reg in_vsync_rgb;
	(* dont_touch = "yes" *) reg [BITS-1:0] in_r;
	(* dont_touch = "yes" *) reg [BITS-1:0] in_g;
	(* dont_touch = "yes" *) reg [BITS-1:0] in_b;

    (* dont_touch = "yes" *) reg rgb_inp_en;
	
	(* dont_touch = "yes" *) reg dpc_en, blc_en, linear_en, oecf_en, bnr_en, dgain_en, lsc_en, demosic_en, wb_en, ccm_en, csc_en, gamma_en, nr2d_en, ee_en, stat_ae_en, awb_en;
	(* dont_touch = "yes" *) reg [BITS-1:0] dpc_threshold;
	// BLC and Linearization
	(* dont_touch = "yes" *) reg [BITS-1:0] blc_r, blc_gr, blc_gb, blc_b;
	(* dont_touch = "yes" *) reg [15:0] linear_r, linear_gr, linear_gb, linear_b; 
	// OECF
	(* dont_touch = "yes" *) reg                        r_table_wen, gr_table_wen, gb_table_wen, b_table_wen;
	(* dont_touch = "yes" *) reg                        r_table_ren, gr_table_ren, gb_table_ren, b_table_ren;
	(* dont_touch = "yes" *) reg  [OECF_TABLE_BITS-1:0] r_table_addr, gr_table_addr, gb_table_addr, b_table_addr;
	(* dont_touch = "yes" *) reg  [OECF_TABLE_BITS-1:0] r_table_wdata, gr_table_wdata, gb_table_wdata, b_table_wdata;
	wire [OECF_TABLE_BITS-1:0] r_table_rdata, gr_table_rdata, gb_table_rdata, b_table_rdata;
	// BNR	
	(* dont_touch = "yes" *) reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_r;	
	(* dont_touch = "yes" *) reg [9*9*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_g;
	(* dont_touch = "yes" *) reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_b;  
	(* dont_touch = "yes" *) reg [9*BITS-1:0]              bnr_color_curve_x_r;   
	(* dont_touch = "yes" *) reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_r;
	(* dont_touch = "yes" *) reg [9*BITS-1:0]              bnr_color_curve_x_g;   
	(* dont_touch = "yes" *) reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_g;
	(* dont_touch = "yes" *) reg [9*BITS-1:0]              bnr_color_curve_x_b;   
	(* dont_touch = "yes" *) reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_b;   
	// Digital Gain
	(* dont_touch = "yes" *) reg [7:0] dgain_gain;
	(* dont_touch = "yes" *) reg [BITS-1:0] dgain_offset;
	// White Balance
	(* dont_touch = "yes" *) reg [11:0] wb_rgain, wb_bgain;
	// Color correction matrix
	(* dont_touch = "yes" *) reg [15:0] ccm_rr, ccm_rg, ccm_rb;
	(* dont_touch = "yes" *) reg [15:0] ccm_gr, ccm_gg, ccm_gb; 
	(* dont_touch = "yes" *) reg [15:0] ccm_br, ccm_bg, ccm_bb;
    // Gamma Table
	(* dont_touch = "yes" *) reg                         gamma_table_r_wen, gamma_table_g_wen, gamma_table_b_wen;
	(* dont_touch = "yes" *) reg                         gamma_table_r_ren, gamma_table_g_ren, gamma_table_b_ren;
	(* dont_touch = "yes" *) reg  [GAMMA_TABLE_BITS-1:0] gamma_table_r_addr, gamma_table_g_addr, gamma_table_b_addr;
	(* dont_touch = "yes" *) reg  [GAMMA_TABLE_BITS-1:0] gamma_table_r_wdata, gamma_table_g_wdata, gamma_table_b_wdata;
	wire [GAMMA_TABLE_BITS-1:0] gamma_table_r_rdata, gamma_table_g_rdata, gamma_table_b_rdata;
    //CSC
	(* dont_touch = "yes" *) reg [1:0]                   in_conv_standard;
    // 2DNR 
	(* dont_touch = "yes" *) reg [7*7*NR2D_WEIGHT_BITS-1:0] nr2d_space_kernel; //????? ?(7x7)
	(* dont_touch = "yes" *) reg [9*BITS-1:0]               nr2d_color_curve_x;//????? ???????? ?(9??? ??)
	(* dont_touch = "yes" *) reg [9*NR2D_WEIGHT_BITS-1:0]   nr2d_color_curve_y;//????? ???????? ?(9??? ??)
    // AE inputs and memory port
	(* dont_touch = "yes" *) reg [15:0] stat_ae_rect_x, stat_ae_rect_y, stat_ae_rect_w, stat_ae_rect_h;
	wire stat_ae_done;
	wire [STAT_OUT_BITS-1:0] stat_ae_pix_cnt, stat_ae_sum;
	(* dont_touch = "yes" *) reg stat_ae_hist_out;
	(* dont_touch = "yes" *) reg [STAT_HIST_BITS+1:0] stat_ae_hist_addr; //R,Gr,Gb,B
	wire [STAT_OUT_BITS-1:0] stat_ae_hist_data;
    // AWB input ports and memory port
	(* dont_touch = "yes" *) reg [BITS-1:0] awb_min, awb_max, awb_frames;
	wire [BITS-1:0] final_r_gain, final_b_gain;
	
	always @ (posedge pclk)
	begin
	    if(!rst_n)
	    begin
	        in_href_rgb <= 0;
	        in_vsync_rgb <= 0;
	        in_r <= 0;
            in_g <= 0;
	        in_b <= 0;
            // selecting between inputs
            rgb_inp_en <= 0;
            // Module enables
            dpc_en <= 0;
            blc_en <= 0;
            linear_en <= 0;
            oecf_en <= 0;
            bnr_en <= 0;
            dgain_en <= 0;
            lsc_en <= 0;
            demosic_en <= 0;
            wb_en <= 0;
            ccm_en <= 0;
            csc_en <= 0;
            gamma_en <= 0;
            nr2d_en <= 0;
            ee_en <= 0;
            stat_ae_en <= 0;
            awb_en <= 0;
            // DPC
            dpc_threshold <= 0; 
            // BLC and Linearization
	        blc_r <= 0; blc_gr <= 0; blc_gb <= 0; blc_b <= 0;
	        linear_r <= 0; linear_gr <= 0; linear_gb <= 0; linear_b <= 0; 
	        // OECF
	        r_table_wen <= 0; gr_table_wen <= 0; gb_table_wen <= 0; b_table_wen <= 0;
	        r_table_ren <= 0; gr_table_ren <= 0; gb_table_ren <= 0; b_table_ren <= 0;
	        r_table_addr <= 0; gr_table_addr <= 0; gb_table_addr <= 0; b_table_addr <= 0;
	        r_table_wdata <= 0; gr_table_wdata <= 0; gb_table_wdata <= 0; b_table_wdata <= 0;
	        // BNR	
	        bnr_space_kernel_r <= 0;
            bnr_space_kernel_g <= 0;
            bnr_space_kernel_b <= 0;
            bnr_color_curve_x_r <= 0;
            bnr_color_curve_y_r <= 0;
            bnr_color_curve_x_g <= 0;
            bnr_color_curve_y_g <= 0;
            bnr_color_curve_x_b <= 0;
            bnr_color_curve_y_b <= 0;
	        // Digital Gain
	        dgain_gain <= 0;
	        dgain_offset <= 0;
	        // White Balance
	        wb_rgain <= 0; wb_bgain <= 0;
	        // Color correction matrix
	        ccm_rr <= 0; ccm_rg <= 0; ccm_rb <= 0;
	        ccm_gr <= 0; ccm_gg <= 0; ccm_gb <= 0; 
	        ccm_br <= 0; ccm_bg <= 0; ccm_bb <= 0;
            // Gamma Table
	        gamma_table_r_wen <= 0; gamma_table_g_wen <= 0; gamma_table_b_wen <= 0;
	        gamma_table_r_ren <= 0; gamma_table_g_ren <= 0; gamma_table_b_ren <= 0;
	        gamma_table_r_addr <= 0; gamma_table_g_addr <= 0; gamma_table_b_addr <= 0;
	        gamma_table_r_wdata <= 0; gamma_table_g_wdata <= 0; gamma_table_b_wdata <= 0;
            //CSC
	        in_conv_standard <= 0;
            // 2DNR 
	        nr2d_space_kernel <= 0; //????? ?(7x7)
	        nr2d_color_curve_x <= 0;//????? ???????? ?(9??? ??)
	        nr2d_color_curve_y <= 0;//????? ???????? ?(9??? ??)
            // AE inputs and memory port
	        stat_ae_rect_x <= 0; stat_ae_rect_y <= 0; stat_ae_rect_w <= 0; stat_ae_rect_h <= 0;
	        stat_ae_hist_out <= 0;
	        stat_ae_hist_addr <= 0; //R,Gr,Gb,B
            // AWB input ports and memory port
            awb_min <= 0; awb_max <= 0; awb_frames <= 0;
	    end
	    else
	    begin
	        in_href_rgb <= 1;
	        in_vsync_rgb <= 1;
	        in_r <= 1;
            in_g <= 1;
	        in_b <= 1;
            // selecting between inputs
            rgb_inp_en <= rgb_inp_en;
            // Module enables
            dpc_en <= USE_DPC;
            blc_en <= USE_BLC;
            linear_en <= 1;
            oecf_en <= USE_OECF;
            bnr_en <= USE_BNR;
            dgain_en <= USE_DGAIN;
            lsc_en <= USE_LSC;
            demosic_en <= USE_DEMOSIC;
            wb_en <= USE_WB;
            ccm_en <= USE_CCM;
            csc_en <= USE_CSC;
            gamma_en <= USE_GAMMA;
            nr2d_en <= USE_2DNR;
            ee_en <= USE_EE;
            stat_ae_en <= USE_STAT_AE;
            awb_en <= USE_AWB;
            // DPC
		    dpc_threshold <= DPC_THRESHOLD;
		    // BLC
		    blc_r <= BLC_R;
		    blc_gr <= BLC_GR;
		    blc_gb <= BLC_GB;
		    blc_b <= BLC_B;
		    linear_r <= LINEAR_R;
		    linear_gr <= LINEAR_GR;
		    linear_gb <= LINEAR_GB;
		    linear_b <= LINEAR_B;
		    // OECF
		    r_table_wen <= 0; gr_table_wen <= 0; gb_table_wen <= 0; b_table_wen <= 0;
		    r_table_ren <= 1; gr_table_ren <= 1; gb_table_ren <= 1; b_table_ren <= 1;
		    r_table_addr <= 0; gr_table_addr <= 0; gb_table_addr <= 0; b_table_addr <= 0;
		    r_table_wdata <= 0; gr_table_wdata <= 0; gb_table_wdata <= 0; b_table_wdata <= 0;
		    // BNR
		    bnr_space_kernel_r <= BNR_SPACE_KERNEL_R;
            bnr_space_kernel_g <= BNR_SPACE_KERNEL_G;
            bnr_space_kernel_b <= BNR_SPACE_KERNEL_B;
            bnr_color_curve_x_r <= BNR_COLOR_CURVE_X_R;
            bnr_color_curve_y_r <= BNR_COLOR_CURVE_Y_R;
            bnr_color_curve_x_g <= BNR_COLOR_CURVE_X_G;
            bnr_color_curve_y_g <= BNR_COLOR_CURVE_Y_G;
            bnr_color_curve_x_b <= BNR_COLOR_CURVE_X_B;
            bnr_color_curve_y_b <= BNR_COLOR_CURVE_Y_B;
		    // DG
		    dgain_gain <= DGAIN;
		    dgain_offset <= 0;
		    // WB
		    wb_rgain <= WB_RGAIN;
		    wb_bgain <= WB_BGAIN;
		    // CCM
		    ccm_rr <= CCM_RR; ccm_rg <= CCM_RG; ccm_rb <= CCM_RB;
		    ccm_gr <= CCM_GR; ccm_gg <= CCM_GG; ccm_gb <= CCM_GB;
		    ccm_br <= CCM_BR; ccm_bg <= CCM_BG; ccm_bb <= CCM_BB;
		    // GAMMA
		    gamma_table_r_wen <= 0; gamma_table_g_wen <= 0; gamma_table_b_wen <= 0;
		    gamma_table_r_ren <= 1; gamma_table_g_ren <= 1; gamma_table_b_ren <= 1;
		    gamma_table_r_addr <= 0; gamma_table_r_addr <= 0; gamma_table_r_addr <= 0;
		    gamma_table_r_wdata <= 0; gamma_table_r_wdata <= 0; gamma_table_r_wdata <= 0;
		    // CSC
		    in_conv_standard <= CSC_CONV_STD;
		    // 2DNR
		    nr2d_space_kernel <= NR2D_SPACE_KERNEL;
		    nr2d_color_curve_x <= NR2D_COLOR_CURVE_X;
		    nr2d_color_curve_y <= NR2D_COLOR_CURVE_Y;
		    // AE inputs and memory port
		    stat_ae_rect_x <= STAT_AE_RECT_X;
		    stat_ae_rect_y <= STAT_AE_RECT_Y;
		    stat_ae_rect_w <= STAT_AE_RECT_W;
		    stat_ae_rect_h <= STAT_AE_RECT_H;
		    stat_ae_hist_out <= 0;
		    stat_ae_hist_addr <= 0;
		    // AWB input ports and memory port
            awb_min <= AWB_MIN; awb_max <= AWB_MAX; awb_frames <= AWB_FRAMES;
	    end
	end
	
	isp_top	#(
	  /*BITS 					*/  BITS,
	  /*WIDTH 					*/  WIDTH,
	  /*HEIGHT 					*/  HEIGHT,
	  /*BAYER 					*/  BAYER,
	  /*OECF_TABLE_BITS         */  BITS,
	  /*OECF_R_LUT              */  OECF_R_LUT,
	  /*OECF_GR_LUT             */  OECF_GR_LUT,
	  /*OECF_GB_LUT             */  OECF_GB_LUT,
	  /*OECF_B_LUT              */  OECF_B_LUT,
	  /*BNR_WEIGHT_BITS         */  BNR_WEIGHT_BITS,
	  /*GAMMA_TABLE_BITS 	    */  GAMMA_TABLE_BITS,
	  /*GAMMA_R_LUT             */  GAMMA_R_LUT,
	  /*GAMMA_G_LUT             */  GAMMA_G_LUT,
	  /*GAMMA_B_LUT             */  GAMMA_B_LUT,
	  /*NR2d_WEIGHTS_BITS       */  NR2D_WEIGHT_BITS,
	  /*STAT_OUT_BITS 		    */  STAT_OUT_BITS,
	  /*STAT_HIST_BITS 		    */  STAT_HIST_BITS,
	  /*USE_DPC					*/  USE_DPC,
	  /*USE_BLC					*/	USE_BLC,
	  /*USE_OECF				*/	USE_OECF,	  
	  /*USE_DGAIN				*/  USE_DGAIN,
	  /*USE_LSC    				*/  USE_LSC,
	  /*USE_BNR					*/	USE_BNR,					
	  /*USE_WB					*/  USE_WB,
	  /*USE_DEMOSIC			    */  USE_DEMOSIC,
	  /*USE_CCM					*/  USE_CCM,
	  /*USE_GAMMA				*/  USE_GAMMA,
	  /*USE_CSC					*/  USE_CSC, 
	  /*USE_LDCI				*/  USE_LDCI,
	  /*USE_2DNR				*/  USE_2DNR,
	  /*USE_EE					*/	USE_EE,
	  /*USE_STAT_AE			    */  USE_STAT_AE,
	  /*USE_STAT_AWB			*/  USE_AWB
	 )
	isp_top_i0(
		// Clock and rest
		.pclk(pclk), 
		.rst_n(rst_n), 
		// DVP input
		.in_href(in_href),	.in_vsync(in_vsync), .in_raw(in_raw[BITS-1:0]),
		// DVP input
		.in_href_rgb(in_href_rgb),	.in_vsync_rgb(in_vsync_rgb), .in_r(in_r), .in_g(in_g), .in_b(in_b),  						 
		// DVP output
		.out_href(out_href), .out_vsync(out_vsync), .out_y(out_y), .out_u(out_u), .out_v(out_v), 	 
		// Enable 3 channel input from outside
		.rgb_inp_en(rgb_inp_en),
		// Enable signals
		.dpc_en(dpc_en), .blc_en(blc_en), .bnr_en(bnr_en), .dgain_en(dgain_en),                   
		.demosic_en(demosic_en), .oecf_en(oecf_en), .wb_en(wb_en), 
		.ccm_en(ccm_en), .csc_en(csc_en), .gamma_en(gamma_en), 
		.nr2d_en(nr2d_en), .ee_en(ee_en), .stat_ae_en(stat_ae_en), .awb_en(awb_en),
		// DPC
		.dpc_threshold(dpc_threshold),
		// BLC and Linearization
		.blc_r(blc_r), .blc_gr(blc_gr), .blc_gb(blc_gb), .blc_b(blc_b), .linear_en(linear_en),
		.linear_r(linear_r), .linear_gr(linear_gr), .linear_gb(linear_gb), .linear_b(linear_b),
		// OECF
		.r_table_clk(pclk), .gr_table_clk(pclk), .gb_table_clk(pclk), .b_table_clk(pclk),
		.r_table_wen(r_table_wen), .gr_table_wen(gr_table_wen), .gb_table_wen(gb_table_wen), .b_table_wen(b_table_wen),
		.r_table_ren(r_table_ren), .gr_table_ren(gr_table_ren), .gb_table_ren(gb_table_ren), .b_table_ren(b_table_ren),
		.r_table_addr(r_table_addr), .gr_table_addr(gr_table_addr), .gb_table_addr(gb_table_addr), .b_table_addr(b_table_addr),
		.r_table_wdata(r_table_wdata), .gr_table_wdata(gr_table_wdata), .gb_table_wdata(gb_table_wdata), .b_table_wdata(b_table_wdata),
		.r_table_rdata(r_table_rdata), .gr_table_rdata(gr_table_rdata), .gb_table_rdata(gb_table_rdata), .b_table_rdata(b_table_rdata),
		// BNR
		.bnr_space_kernel_r(bnr_space_kernel_r), .bnr_space_kernel_g(bnr_space_kernel_g), .bnr_space_kernel_b(bnr_space_kernel_b),
		.bnr_color_curve_x_r(bnr_color_curve_x_r), .bnr_color_curve_y_r(bnr_color_curve_y_r),
		.bnr_color_curve_x_g(bnr_color_curve_x_g), .bnr_color_curve_y_g(bnr_color_curve_y_g),
		.bnr_color_curve_x_b(bnr_color_curve_x_b), .bnr_color_curve_y_b(bnr_color_curve_y_b),
		// DG
		.dgain_gain(dgain_gain), .dgain_offset(dgain_offset),
		// WB
		.wb_rgain(wb_rgain), .wb_bgain(wb_bgain), 
		// CCM
		.ccm_rr(ccm_rr), .ccm_rg(ccm_rg), .ccm_rb(ccm_rb), 
		.ccm_gr(ccm_gr), .ccm_gg(ccm_gg), .ccm_gb(ccm_gb), 
		.ccm_br(ccm_br), .ccm_bg(ccm_bg), .ccm_bb(ccm_bb),
		// GAMMA
		.gamma_table_r_clk(pclk), .gamma_table_r_wen(gamma_table_r_wen), .gamma_table_r_ren(gamma_table_r_ren), .gamma_table_r_addr(gamma_table_r_addr), .gamma_table_r_wdata(gamma_table_r_wdata), .gamma_table_r_rdata(gamma_table_r_rdata),
		.gamma_table_g_clk(pclk), .gamma_table_g_wen(gamma_table_g_wen), .gamma_table_g_ren(gamma_table_g_ren), .gamma_table_g_addr(gamma_table_g_addr), .gamma_table_g_wdata(gamma_table_g_wdata), .gamma_table_g_rdata(gamma_table_g_rdata),
		.gamma_table_b_clk(pclk), .gamma_table_b_wen(gamma_table_b_wen), .gamma_table_b_ren(gamma_table_b_ren), .gamma_table_b_addr(gamma_table_b_addr), .gamma_table_b_wdata(gamma_table_b_wdata), .gamma_table_b_rdata(gamma_table_b_rdata),
		//CSC
		.in_conv_standard(in_conv_standard),
		// 2DNR
		.nr2d_space_kernel(nr2d_space_kernel), .nr2d_color_curve_x(nr2d_color_curve_x), .nr2d_color_curve_y(nr2d_color_curve_y), 
		// STAT_AE
		.stat_ae_rect_x(stat_ae_rect_x), .stat_ae_rect_y(stat_ae_rect_y), .stat_ae_rect_w(stat_ae_rect_w), .stat_ae_rect_h(stat_ae_rect_h), 
		.stat_ae_done(stat_ae_done), .stat_ae_pix_cnt(stat_ae_pix_cnt), .stat_ae_sum(stat_ae_sum),
		.stat_ae_hist_clk(pclk), .stat_ae_hist_out(stat_ae_hist_out), .stat_ae_hist_addr(stat_ae_hist_addr), .stat_ae_hist_data(stat_ae_hist_data), 
		// AWB
		.awb_min(awb_min), .awb_max(awb_max), .awb_frames(awb_frames),
		.final_r_gain(final_r_gain), .final_b_gain(final_b_gain)
	);
	
	reg [3:0] Counter = 0;
	
	always @ (posedge pclk)
	begin
	    if(Counter == 13)
	        Counter <= 0;
	    else
	        Counter <= Counter + 1;
	end
	
	always @ (posedge pclk)
	begin
	    case(Counter)
	    0:  out_mux <= r_table_rdata;
	    1:  out_mux <= gr_table_rdata;
	    2:  out_mux <= gb_table_rdata;
	    3:  out_mux <= b_table_rdata;
	    4:  out_mux <= gamma_table_r_rdata;
	    5:  out_mux <= gamma_table_g_rdata;
	    6:  out_mux <= gamma_table_b_rdata;
	    7:  out_mux <= stat_ae_done;
	    8:  out_mux <= stat_ae_pix_cnt;
	    9:  out_mux <= stat_ae_sum;
	    10: out_mux <= stat_ae_hist_data;
	    11: out_mux <= final_r_gain;
	    12: out_mux <= final_b_gain;
	    default: out_mux <= 0;
	    endcase
	end
endmodule