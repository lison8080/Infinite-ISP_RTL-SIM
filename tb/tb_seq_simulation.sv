/*************************************************************************
> File Name: tb_seq_simulation.v
> Description: Test bench for testing multiple consecutive frames 
passing through both ISP and VIP modules
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

module tb_seq_top;

  // ---------------------------------------------------------------------------
  // 功能说明
  // ---------------------------------------------------------------------------
  // 本 testbench 用于验证“连续多帧”的系统级流水线行为：
  // - 前端 ISP（裁剪/坏点/黑电平/OECF/BNR/WB/DEMO/CCM/GAMMA/CSC/2DNR/SHARP/AWB/AE 等）
  // - 后级 VIP1 + VIP2（RGBC/IRC/SCALE/OSD/YUV444->422 等，可组合开关）
  //
  // 与 `tb_isp_top.v` / `tb_vip_top.v` 的区别：
  // - 这里强调“连续帧”的输入/输出组织方式，便于观察 AE/AWB 等跨帧统计逻辑。
  // - 通过 `NUM_SEQ_FRAMES` 设定连续仿真的帧数，并为每一帧生成独立的输入/输出文件。
  //
  // 重要提示（文件命名）：
  // - 代码中用 `$sformatf(IN_FILE, "_%0d", i, ".bin")` 生成每帧文件名。
  // - 标准 SystemVerilog 的 `$sformatf` 需要“格式串”，若你发现仿真没有拼接后缀，
  //   可能需要将该表达式改为 `$sformatf("%s_%0d.bin", IN_FILE, i)`（本文件当前不做逻辑修改）。
  // ---------------------------------------------------------------------------

  // Input and Output file names ( in the current directory)
  // Input file names should be of format XYZ_0.bin XYZ_1.bin ... placed in xsim Directory (Frame numbering should start from 0)
  // However below in parameters (IN_FILE, IN_FILE_R, IN_FILE_G, IN_FILE_B) we only need to pass XYZ (If we are running simulation manually, otherwise script will handle it automatically)

  // ---------------------------------------------------------------------------
  // 输入/输出文件前缀（多帧）
  // ---------------------------------------------------------------------------
  // - `IN_FILE*` 仅填写“前缀/基础名”（不带 _0.bin 等后缀）。
  // - testbench 会按帧号拼出 `*_0.bin, *_1.bin ...`。
  // - `OUT_FILE` 同理，会输出为 `OUT_FILE_0.bin ...`。
  //
  // 注意：若你只跑单帧（NUM_SEQ_FRAMES=1），通常只需要准备 *_0.bin。
    localparam NUM_SEQ_FRAMES = 1; //Number of frames you want to sequentially simulate (Equal number of frames should be present in xsim directory)
	localparam IN_FILE = "in/In_crop_Indoor1_2592x1536_10bit_GRBG";  // Name shoud be like this "In_crop_Indoor1_2592x1536_10bit_GRBG" without file extension
	localparam IN_FILE_R = "in/In_crop_Indoor1_2592x1536_10bit_GRBG";
	localparam IN_FILE_G = "in/In_crop_Indoor1_2592x1536_10bit_GRBG";
	localparam IN_FILE_B = "in/In_crop_Indoor1_2592x1536_10bit_GRBG";
	localparam OUT_FILE = "out/RTL_In_crop_Indoor1_2592x1536_10bit_GRBG";
	
	
	// ISP top module parameters
	localparam BITS_FILE = 16;
	localparam BITS = 10;
	localparam BITS_DIFF = BITS_FILE - BITS;
	localparam SNS_WIDTH = 2592;
	localparam SNS_HEIGHT = 1536;
	localparam CROP_WIDTH = 2592;
	localparam CROP_HEIGHT = 1536;
	localparam BAYER = 1; //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	localparam OECF_R_LUT = "in/OECF_R_LUT_INIT.txt";
	localparam OECF_GR_LUT = "in/OECF_GR_LUT_INIT.txt";
	localparam OECF_GB_LUT = "in/OECF_GB_LUT_INIT.txt";
	localparam OECF_B_LUT = "in/OECF_B_LUT_INIT.txt";
	localparam BNR_WEIGHT_BITS = 8;
	// AWB Crop setting: for GM crop = [8,8,8,8], RTL crop = [8,8,8+yshift,8-yshift]
	// crop in bayer domain, cannot be changed after synthesis
	localparam AWB_CROP_LEFT = 8;
	localparam AWB_CROP_RIGHT = 8;
	localparam AWB_CROP_TOP = 16;
	localparam AWB_CROP_BOTTOM = 0;
	localparam GAMMA_R_LUT = "in/GAMMA_R_LUT_INIT.txt";
	localparam GAMMA_G_LUT = "in/GAMMA_G_LUT_INIT.txt";
	localparam GAMMA_B_LUT = "in/GAMMA_B_LUT_INIT.txt";
	localparam SHARP_WEIGHT_BITS = 20;
	localparam NR2D_LUT_SIZE = 32;
	localparam NR2D_WEIGHT_BITS = 5;
	localparam DGAIN_ARRAY_SIZE = 100;
	localparam DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE);
	localparam STAT_OUT_BITS = 32;
	localparam STAT_HIST_BITS = 16; //????????(??????)
	
	// VIP1 parameters
	localparam VIP1_BITS = 8;
	localparam VIP1_OSD_RAM_ADDR_BITS = 9;
	localparam VIP1_OSD_RAM_DATA_BITS = 32;
	// VIP2 parameters
	localparam VIP2_BITS = 8;
	localparam VIP2_OSD_RAM_ADDR_BITS = 9;
	localparam VIP2_OSD_RAM_DATA_BITS = 32;
   	// ISP instantiation of modules
   	`define USE_CROP        1
	`define USE_DPC         1
	`define USE_BLC         1
	`define USE_OECF        1
	`define USE_DGAIN       1
	`define USE_LSC         0
	`define USE_BNR         1
	`define USE_WB          1
	`define USE_DEMOSIC     1
	`define USE_CCM         1
	`define USE_GAMMA       1
	`define USE_CSC         1
	`define USE_SHARP       1
	`define USE_LDCI        0
	`define USE_2DNR        1
	`define USE_STAT_AE     0
	`define USE_AWB         1
	`define USE_AE          1
	
	// Instantiation of VIP1 blocks
    `define VIP1_USE_HIST_EQU 	    0
    `define VIP1_USE_SOBEL   	    0
    `define VIP1_USE_RGBC     	    1
    `define VIP1_USE_IRC   		    1
    `define VIP1_USE_SCALE   	    1
    `define VIP1_USE_OSD			1
    `define VIP1_USE_YUVConvFormat  1
    // Instantiation of VIP1 blocks
    `define VIP2_USE_HIST_EQU 	    0
    `define VIP2_USE_SOBEL   	    0
    `define VIP2_USE_RGBC     	    1
    `define VIP2_USE_IRC   		    1
    `define VIP2_USE_SCALE   	    1
    `define VIP2_USE_OSD			1
    `define VIP2_USE_YUVConvFormat  1

	// ISP Modules' Enables
	localparam CROP_EN = 1;
	localparam DPC_EN = 1;
	localparam BLC_EN = 1;
	localparam OECF_EN = 1;
	localparam DGAIN_EN = 1;
	localparam LSC_EN = 0;
	localparam BNR_EN = 1;
	localparam WB_EN = 1;
	localparam DEMOSAIC_EN = 1;	
	localparam CCM_EN = 1;
	localparam GAMMA_EN = 1;
	localparam LDCI_EN = 0;
	localparam CSC_EN = 1;
	localparam SHARP_EN = 1;
	localparam NR2D_EN = 1;
	localparam STAT_AE_EN  = 0;
	localparam AWB_EN = 1;
	localparam AE_EN = 1;
	
    // Enability of VIP blocks 
    localparam HIST_EQU_EN = 0;
    localparam SOBEL_EN = 0;
    localparam RGBC_EN = 1;
    localparam IRC_EN = 1;
    localparam SCALE_EN = 0;
    localparam OSD_EN = 1;
    localparam YUVConvFormat_EN = 0;
	
	// ISP Parameters
	
	// Tunabale parameters of the ISP ( as inputs to the module)
	localparam DPC_THRESHOLD = 20;
	// BLC and linearization
	localparam BLC_R = 50;
	localparam BLC_GR = 50;
	localparam BLC_GB = 50;
	localparam BLC_B = 50;
	localparam LINEAR_EN = 1;
	localparam LINEAR_R = 16'b0100001101001001;
	localparam LINEAR_GR = 16'b0100001101001001;
	localparam LINEAR_GB = 16'b0100001101001001;
	localparam LINEAR_B = 16'b0100001101001001;
	// BNR
	localparam BNR_SPACE_KERNEL_R = {{8'd0},{8'd0},{8'd0},{8'd0},{8'd0},
									{8'd0},{8'd5},{8'd35},{8'd5},{8'd0},
									{8'd0},{8'd35},{8'd255},{8'd35},{8'd0},
									{8'd0},{8'd5},{8'd35},{8'd5},{8'd0},
									{8'd0},{8'd0},{8'd0},{8'd0},{8'd0}};
	localparam BNR_SPACE_KERNEL_G = {{8'd5},{8'd21},{8'd35},{8'd21},{8'd5},
									{8'd21},{8'd94},{8'd155},{8'd94},{8'd21},
									{8'd35},{8'd155},{8'd255},{8'd155},{8'd35},
									{8'd21},{8'd94},{8'd155},{8'd94},{8'd21},
									{8'd5},{8'd21},{8'd35},{8'd21},{8'd5}};
	localparam BNR_SPACE_KERNEL_B = {{8'd0},{8'd0},{8'd0},{8'd0},{8'd0},
									{8'd0},{8'd5},{8'd35},{8'd5},{8'd0},
									{8'd0},{8'd35},{8'd255},{8'd35},{8'd0},
									{8'd0},{8'd5},{8'd35},{8'd5},{8'd0},
									{8'd0},{8'd0},{8'd0},{8'd0},{8'd0}};
	localparam BNR_COLOR_CURVE_X_R = {{10'd184},{10'd163},{10'd143},{10'd122},{10'd102},{10'd81},{10'd61},{10'd40},{10'd20}};
	localparam BNR_COLOR_CURVE_Y_R = {{8'd51},{8'd72},{8'd96},{8'd125},{8'd155},{8'd186},{8'd213},{8'd236},{8'd250}};
	localparam BNR_COLOR_CURVE_X_G = {{10'd184},{10'd163},{10'd143},{10'd122},{10'd102},{10'd81},{10'd61},{10'd40},{10'd20}};
	localparam BNR_COLOR_CURVE_Y_G = {{8'd51},{8'd72},{8'd96},{8'd125},{8'd155},{8'd186},{8'd213},{8'd236},{8'd250}};
	localparam BNR_COLOR_CURVE_X_B = {{10'd184},{10'd163},{10'd143},{10'd122},{10'd102},{10'd81},{10'd61},{10'd40},{10'd20}};
	localparam BNR_COLOR_CURVE_Y_B = {{8'd51},{8'd72},{8'd96},{8'd125},{8'd155},{8'd186},{8'd213},{8'd236},{8'd250}};
	// Digital gain
	localparam DGAIN_ARRAY = {{8'd100},{8'd99},{8'd98},{8'd97},{8'd96},{8'd95},{8'd94},{8'd93},{8'd92},{8'd91},{8'd90},{8'd89},{8'd88},{8'd87},{8'd86},{8'd85},{8'd84},{8'd83},{8'd82},{8'd81},{8'd80},{8'd79},{8'd78},{8'd77},{8'd76},{8'd75},{8'd74},{8'd73},{8'd72},{8'd71},{8'd70},{8'd69},{8'd68},{8'd67},{8'd66},{8'd65},{8'd64},{8'd63},{8'd62},{8'd61},{8'd60},{8'd59},{8'd58},{8'd57},{8'd56},{8'd55},{8'd54},{8'd53},{8'd52},{8'd51},{8'd50},{8'd49},{8'd48},{8'd47},{8'd46},{8'd45},{8'd44},{8'd43},{8'd42},{8'd41},{8'd40},{8'd39},{8'd38},{8'd37},{8'd36},{8'd35},{8'd34},{8'd33},{8'd32},{8'd31},{8'd30},{8'd29},{8'd28},{8'd27},{8'd26},{8'd25},{8'd24},{8'd23},{8'd22},{8'd21},{8'd20},{8'd19},{8'd18},{8'd17},{8'd16},{8'd15},{8'd14},{8'd13},{8'd12},{8'd11},{8'd10},{8'd9},{8'd8},{8'd7},{8'd6},{8'd5},{8'd4},{8'd3},{8'd2},{8'd1}}; // [1, 2, 4, 6, 8, 10, 12, 16, 32, 64]
	localparam DGAIN_ISMANUAL = 0;
	localparam DGAIN_MAN_INDEX = 0;
	// White Balance
	localparam WB_RGAIN = 12'b000100111111; // 1.24609375 in 4.8 format
	localparam WB_BGAIN = 12'b001011001111;
	// CCM
	localparam CCM_RR = 16'd2053;	   
	localparam CCM_RG = -1*(16'd37); 	
	localparam CCM_RB = -1*(16'd991);
	localparam CCM_GR = -1*(16'd390); 	
	localparam CCM_GG = 16'd1700; 	    
	localparam CCM_GB = -1*(16'd287);
	localparam CCM_BR = 16'd30;	
	localparam CCM_BG = -1*(16'd1353);    
	localparam CCM_BB = 16'd2338;
	// CSC
	localparam CSC_CONV_STD = 2'd2;
	// SHARP
	localparam SHARPEN_STRENGTH = 12'b001110011001;
	localparam LUMA_KERNEL = {{20'd764},{20'd1833},{20'd3424},{20'd4982},{20'd5646},{20'd4982},{20'd3424},{20'd1833},{20'd764},
									{20'd1833},{20'd4397},{20'd8215},{20'd11953},{20'd13544},{20'd11953},{20'd8215},{20'd4397},{20'd1833},
									{20'd3424},{20'd8215},{20'd15348},{20'd22331},{20'd25305},{20'd22331},{20'd15348},{20'd8215},{20'd3424},
									{20'd4982},{20'd11953},{20'd22331},{20'd32492},{20'd36819},{20'd32492},{20'd22331},{20'd11953},{20'd4982},
									{20'd5646},{20'd13544},{20'd25305},{20'd36819},{20'd41721},{20'd36819},{20'd25305},{20'd13544},{20'd5646},
									{20'd4982},{20'd11953},{20'd22331},{20'd32492},{20'd36819},{20'd32492},{20'd22331},{20'd11953},{20'd4982},
									{20'd3424},{20'd8215},{20'd15348},{20'd22331},{20'd25305},{20'd22331},{20'd15348},{20'd8215},{20'd3424},
									{20'd1833},{20'd4397},{20'd8215},{20'd11953},{20'd13544},{20'd11953},{20'd8215},{20'd4397},{20'd1833},
									{20'd764},{20'd1833},{20'd3424},{20'd4982},{20'd5646},{20'd4982},{20'd3424},{20'd1833},{20'd764}};
	// 2DNR
	localparam NR2D_DIFF = {{8'd255},{8'd246},{8'd238},{8'd230},{8'd222},{8'd213},{8'd205},{8'd197},{8'd189},{8'd180},{8'd172},{8'd164},{8'd156},{8'd148},{8'd139},{8'd131},{8'd123},{8'd115},{8'd106},{8'd98},{8'd90},{8'd82},{8'd74},{8'd65},{8'd57},{8'd49},{8'd41},{8'd32},{8'd24},{8'd16},{8'd8},{8'd0}};
	localparam NR2D_WEIGHT = {{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd2},{5'd31}};

	// Auto White Balance
	localparam AWB_UNDEREXPOSED_LIMIT = 51;
    localparam AWB_OVEREXPOSED_LIMIT = 972;
    localparam AWB_FRAMES = 1;
    // Auto Exposure
	// AE Crop setting: for GM crop = [12,12,12,12], RTL crop = [12,12,12+yshift,12-yshift]
	// crop in RGB domain, can be changed after synthesis
	localparam AE_CROP_LEFT = 12;
	localparam AE_CROP_RIGHT = 12;
	localparam AE_CROP_TOP = 22;
	localparam AE_CROP_BOTTOM = 2;
	localparam CENTRE_ILLUMINANCE = 90;
	localparam SKEWNESS = 230;
	
	
	//VIP Parameters


    // Tunable parameters of VIP
    // HIST EQU
    localparam EQU_MIN = 0;
    localparam EQU_MAX = 255;
    // YUV-RGB
    localparam IN_CONV_STANDARD = 2;
    // IRC
    localparam IRC_OUTPUT = 1;  // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
    localparam CROP_X = 336;	// row no. = [0 INPUT_WIDTH]
    localparam CROP_Y = 228;	// column no. = [0 INPUT_HEIGHT]
    // SCALE
    // stage-1: downscale factor
    localparam SCALE_W = 1;
    localparam SCALE_H = 1;
    // stage-2: internal crop parameters
    localparam S_IN_CROP_W = 1920;
    localparam S_IN_CROP_H = 1080;
    localparam S_OUT_CROP_W = 1920;
    localparam S_OUT_CROP_H = 1080;
    // OSD
    localparam X_OFFSET = 50;
    localparam Y_OFFSET = 50;
    localparam OSD_WIDTH = 128;
    localparam OSD_HEIGHT = 64;
    localparam OSD_COLOR_FG = 24'h005aa0; //24'h005AA0 (10x logo Blue color)  RGB format
    localparam OSD_COLOR_BG = 24'hffffff; // 24'hFFFFFF (White Background)
    localparam OSD_RAM_ADDR_BITS = 9;
    localparam OSD_RAM_DATA_BITS = 32;
    localparam ALPHA = 50;
    // YUV444TO422
    localparam YUV444TO422_Value = 0; // 0 = Output as 444, 1 = Output as 422
		
	
	//VIP1 Parameters

    // Tunable parameters
    // Module Enables
    localparam VIP1_HIST_EQU_EN = HIST_EQU_EN;
    localparam VIP1_SOBEL_EN = SOBEL_EN;
    localparam VIP1_RGBC_EN = RGBC_EN;
    localparam VIP1_IRC_EN = IRC_EN;
    localparam VIP1_SCALE_EN = SCALE_EN;
    localparam VIP1_OSD_EN = OSD_EN;
    localparam VIP1_YUVConvFormat_EN = YUVConvFormat_EN;
    // HIST EQU
    localparam VIP1_EQU_MIN = EQU_MIN;
    localparam VIP1_EQU_MAX = EQU_MAX;
    // YUV-RGB
    localparam VIP1_IN_CONV_STANDARD = IN_CONV_STANDARD;
    // IRC
    localparam VIP1_IRC_OUTPUT = IRC_OUTPUT;  // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
    localparam VIP1_CROP_X = CROP_X;	// row no. = [0 INPUT_WIDTH]
    localparam VIP1_CROP_Y = CROP_Y;	// column no. = [0 INPUT_HEIGHT]
    // SCALE
    // stage-1: downscale factor
    localparam VIP1_SCALE_W = SCALE_W;
    localparam VIP1_SCALE_H = SCALE_H;
    // stage-2: internal crop parameters
    localparam VIP1_S_IN_CROP_W = S_IN_CROP_W;
    localparam VIP1_S_IN_CROP_H = S_IN_CROP_H;
    localparam VIP1_S_OUT_CROP_W = S_OUT_CROP_W;
    localparam VIP1_S_OUT_CROP_H = S_OUT_CROP_H;
    // OSD
    localparam VIP1_OSD_X = X_OFFSET;
    localparam VIP1_OSD_Y = Y_OFFSET;
    localparam VIP1_OSD_W = OSD_WIDTH;
    localparam VIP1_OSD_H = OSD_HEIGHT;
    localparam VIP1_OSD_COLOR_FG = OSD_COLOR_FG;
    localparam VIP1_OSD_COLOR_BG = OSD_COLOR_BG;
	localparam VIP1_OSD_ALPHA = ALPHA;
    // YUV444TO422
    localparam VIP1_YUV444TO422_Value = YUV444TO422_Value; // 0 = Output as 444, 1 = Output as 422
    
	//VIP2 Parameters

    // Tunable parameters
    // Module Enables
    localparam VIP2_HIST_EQU_EN = HIST_EQU_EN;
    localparam VIP2_SOBEL_EN = SOBEL_EN;
    localparam VIP2_RGBC_EN = RGBC_EN;
    localparam VIP2_IRC_EN = IRC_EN;
    localparam VIP2_SCALE_EN = SCALE_EN;
    localparam VIP2_OSD_EN = OSD_EN;
    localparam VIP2_YUVConvFormat_EN = YUVConvFormat_EN;
    // HIST EQU
    localparam VIP2_EQU_MIN = EQU_MIN;
    localparam VIP2_EQU_MAX = EQU_MAX;
    // YUV-RGB
    localparam VIP2_IN_CONV_STANDARD = IN_CONV_STANDARD;
    // IRC
    localparam VIP2_IRC_OUTPUT = IRC_OUTPUT;  // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
    localparam VIP2_CROP_X = CROP_X;	// row no. = [0 INPUT_WIDTH]
    localparam VIP2_CROP_Y = CROP_Y;	// column no. = [0 INPUT_HEIGHT]
    // SCALE
    // stage-1: downscale factor
    localparam VIP2_SCALE_W = SCALE_W;
    localparam VIP2_SCALE_H = SCALE_H;
    // stage-2: internal crop parameters
    localparam VIP2_S_IN_CROP_W = S_IN_CROP_W;
    localparam VIP2_S_IN_CROP_H = S_IN_CROP_H;
    localparam VIP2_S_OUT_CROP_W = S_OUT_CROP_W;
    localparam VIP2_S_OUT_CROP_H = S_OUT_CROP_H;
    // OSD
    localparam VIP2_OSD_X = X_OFFSET;
    localparam VIP2_OSD_Y = Y_OFFSET;
    localparam VIP2_OSD_W = OSD_WIDTH;
    localparam VIP2_OSD_H = OSD_HEIGHT;
    localparam VIP2_OSD_COLOR_FG = OSD_COLOR_FG;
    localparam VIP2_OSD_COLOR_BG = OSD_COLOR_BG;
	localparam VIP2_OSD_ALPHA = ALPHA;
    // YUV444TO422
    localparam VIP2_YUV444TO422_Value = YUV444TO422_Value; // 0 = Output as 444, 1 = Output as 422
   	
	//****************************************************
	//********************** File2DVP *********************
	// ---------------------------------------------------------------------------
	// File2DVP：多帧输入文件 -> DVP 风格视频流
	// ---------------------------------------------------------------------------
	// 这里采用“并行读入、多帧选择”的方式：
	// - 为每帧 i 实例化一个 `tb_file_to_dvp`，分别读入 `IN_FILE_i.bin` 到 `dvp_out_raw[i]`。
	// - 所有实例共享相同的时序（pclk/href/vsync 一致），因此 href/vsync 多驱动但值相同。
	// - 通过 `counter` 在帧边界切换索引，使 DUT 每一帧使用 `dvp_out_*[counter-1]`。
	//
	// 说明：
	// - `counter` 在 VSYNC 的下降沿递增，用于指示“上一帧已经结束，下一帧开始时切换输入索引”。
	// - 选择 `counter-1` 是为了让输入像素数据与 VSYNC/HRREF 时序对齐。
	//   （也能避免复位后 counter 从 0 开始时，第一帧索引出现负数的问题。）
	//
	// pclk and reset generation
	reg rst_n;
	reg pclk;
	wire dvp_clk_out,dvp_href_out,dvp_vsync_out;
	wire [BITS_FILE-1:0] dvp_out_raw[NUM_SEQ_FRAMES-1:0];
	reg [BITS_FILE-1:0] out_data;
	reg prev_vsync;
	reg [BITS_FILE-1:0] counter;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_vsync <= 0;
       else
            prev_vsync <= dvp_vsync_out;
    end
	always @(posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
               out_data <= 0;
               counter <= 0;
           end
           else if((~prev_vsync) && dvp_vsync_out)begin // +ve edge
               out_data <= dvp_out_raw[counter];
               counter <= counter;
           end
           else if(prev_vsync && ~dvp_vsync_out)begin // -ve edge
               out_data <= out_data;
               counter <= counter + 1;
           end
           else begin
              out_data <= out_data;
              counter <= counter;
           end
       end
	genvar i;
	generate
	for(i=0; i<NUM_SEQ_FRAMES; i=i+1) begin: INSTANCE_GEN
	   // 每帧一个 file2dvp：读入 `IN_FILE_i.bin` 形成 dvp_out_raw[i]
	   tb_file_to_dvp
	   #(
		  .FILE_BASE(IN_FILE),
		  .FRAME_IDX(i),
		  .BITS(BITS_FILE),
		  .H_FRONT(5),
		  .H_PULSE(10),
		  .H_BACK(2),
		  .H_DISP(SNS_WIDTH),
		  .V_FRONT(6),
		  .V_PULSE(20),
		  .V_BACK(3),
		  .V_DISP(SNS_HEIGHT),
		  .H_POL(0),
		  .V_POL(1)
	   )
	   file2dvp(
		  .xclk(pclk),
		  .rst_n(rst_n), 
		  .pclk(dvp_clk_out),
		  .href(dvp_href_out), 
		  .hsync(),
		  .vsync(dvp_vsync_out),
		  .data(dvp_out_raw[i])
	   );
	  end
	 endgenerate
	
	wire dvp_href_rgb_out,dvp_vsync_rgb_out;
	wire [BITS_FILE-1:0] dvp_out_r[NUM_SEQ_FRAMES-1:0];
	genvar j;
	generate
	for(j=0; j<NUM_SEQ_FRAMES; j=j+1) begin: INSTANCE_GEN_R
	   // RGB 三通道输入（RAW bypass 模式）对应的 R 通道文件
	   tb_file_to_dvp
	   #(
		  .FILE_BASE(IN_FILE_R),
		  .FRAME_IDX(j),
		  .BITS(BITS_FILE),
		  .H_FRONT(5),
		  .H_PULSE(10),
		  .H_BACK(2),
		  .H_DISP(SNS_WIDTH),
		  .V_FRONT(6),
		  .V_PULSE(20),
		  .V_BACK(3),
		  .V_DISP(SNS_HEIGHT),
		  .H_POL(0),
		  .V_POL(1)
	   )
	   file2dvp_r(
		  .xclk(pclk), .rst_n(rst_n), .pclk(), .href(dvp_href_rgb_out), .hsync(),	.vsync(dvp_vsync_rgb_out),
		  .data(dvp_out_r[j])
	   );
	  end
    endgenerate
	
	wire [BITS_FILE-1:0] dvp_out_g[NUM_SEQ_FRAMES-1:0];
	genvar k;
	generate
	for(k=0; k<NUM_SEQ_FRAMES; k=k+1) begin: INSTANCE_GEN_G
	   // RGB 三通道输入对应的 G 通道文件
	   tb_file_to_dvp
	   #(
		  .FILE_BASE(IN_FILE_G),
		  .FRAME_IDX(k),
		  .BITS(BITS_FILE),
		  .H_FRONT(5),
		  .H_PULSE(10),
		  .H_BACK(2),
		  .H_DISP(SNS_WIDTH),
		  .V_FRONT(6),
		  .V_PULSE(20),
		  .V_BACK(3),
		  .V_DISP(SNS_HEIGHT),
		  .H_POL(0),
		  .V_POL(1)
	   )
	   file2dvp_g(
		  .xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		  .data(dvp_out_g[k])
	   );
	  end
    endgenerate
	
	wire [BITS_FILE-1:0] dvp_out_b[NUM_SEQ_FRAMES-1:0];
	genvar l;
	generate
	for(l=0; l<NUM_SEQ_FRAMES; l=l+1) begin: INSTANCE_GEN_B
	   // RGB 三通道输入对应的 B 通道文件
	   tb_file_to_dvp
	   #(
		  .FILE_BASE(IN_FILE_B),
		  .FRAME_IDX(l),
		  .BITS(BITS_FILE),
		  .H_FRONT(5),
		  .H_PULSE(10),
		  .H_BACK(2),
		  .H_DISP(SNS_WIDTH),
		  .V_FRONT(6),
		  .V_PULSE(20),
		  .V_BACK(3),
		  .V_DISP(SNS_HEIGHT),
		  .H_POL(0),
		  .V_POL(1)
	   )
	   file2dvp_b(
		  .xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		  .data(dvp_out_b[l])
	   );
	  end
    endgenerate	
    //****************************************************
    //********************** ISP *************************
    //********************** Inputs **********************
	// ---------------------------------------------------------------------------
	// ISP 运行时控制寄存器
	// ---------------------------------------------------------------------------
	// 这些寄存器用于在仿真时动态配置 ISP 各子模块的使能和参数。
	// 与编译时宏 `USE_*` 不同，这些是运行时开关，可在仿真过程中改变。

	// RGB input select（RGB直接输入模式使能，旁路 Bayer 处理）
	reg rgb_inp_en;
	// Module Enable Registers（各子模块运行时使能寄存器）
	reg crop_en, dpc_en, blc_en, linear_en, oecf_en, bnr_en, dgain_en, lsc_en, demosic_en, wb_en, ccm_en, csc_en, gamma_en, ldci_en, nr2d_en, sharp_en, stat_ae_en, awb_en, ae_en;
	// Registers for inputs of DPC（坏点校正阈值）
	reg [BITS-1:0] dpc_threshold;
	// Registers for BLC and Linearization（黑电平校正值与线性化系数）
	reg [BITS-1:0] blc_r, blc_gr, blc_gb, blc_b;
	reg [15:0] linear_r, linear_gr, linear_gb, linear_b;
	// Registers for updating OECF LUTs（OECF 查找表接口：时钟/写使能/读使能/地址/数据）
	reg r_table_clk, gr_table_clk, gb_table_clk, b_table_clk;
	reg r_table_wen, gr_table_wen, gb_table_wen, b_table_wen;
	reg r_table_ren, gr_table_ren, gb_table_ren, b_table_ren;
	reg [BITS-1:0] r_table_addr, gr_table_addr, gb_table_addr, b_table_addr;
	reg [BITS-1:0] r_table_wdata, gr_table_wdata, gb_table_wdata, b_table_wdata;
	// Register for BNR level（Bayer 域降噪：空间核与色彩曲线）
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_r;
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_g;
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_b;
	reg [9*BITS-1:0]              bnr_color_curve_x_r;
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_r;
	reg [9*BITS-1:0]              bnr_color_curve_x_g;
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_g;
	reg [9*BITS-1:0]              bnr_color_curve_x_b;
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_b;
	// Register for DG（数字增益：增益数组、手动/自动模式、手动索引）
	reg [DGAIN_ARRAY_SIZE*8-1:0] dgain_array;
	reg dgain_isManual;
	reg [DGAIN_ARRAY_BITS-1:0] dgain_man_index;
	// Registers for White Balance（白平衡 R/B 增益）
	reg [11:0] wb_rgain, wb_bgain;
	// Registers for CCM（色彩校正矩阵 3x3）
	reg [15:0] ccm_rr, ccm_rg, ccm_rb;
	reg [15:0] ccm_gr, ccm_gg, ccm_gb;
	reg [15:0] ccm_br, ccm_bg, ccm_bb;
	// Registers for GAMMA（Gamma 查找表接口）
	reg gamma_table_r_clk, gamma_table_g_clk, gamma_table_b_clk;
	reg gamma_table_r_wen, gamma_table_g_wen, gamma_table_b_wen;
	reg gamma_table_r_ren, gamma_table_g_ren, gamma_table_b_ren;
	reg [BITS-1:0] gamma_table_r_addr, gamma_table_g_addr, gamma_table_b_addr;
	reg [BITS-1:0] gamma_table_r_wdata, gamma_table_g_wdata, gamma_table_b_wdata;
	// Registers for CSC（色彩空间转换标准选择：BT601/BT709 等）
	reg [1:0] in_conv_standard;
	// Registers for Sharpen（锐化卷积核与强度）
	reg [9*9*SHARP_WEIGHT_BITS-1:0] luma_kernel;
    reg [11:0] sharpen_strength;
	// Registers for 2DNR module（2D 降噪 LUT：差值阈值与权重）
	reg [NR2D_LUT_SIZE*8-1:0] nr2d_diff;
	reg [NR2D_LUT_SIZE*NR2D_WEIGHT_BITS-1:0] nr2d_weight;
	// Registers for STAT_AE（AE 统计窗口：起始坐标与尺寸）
	reg [15:0] stat_ae_rect_x;
	reg [15:0] stat_ae_rect_y;
	reg [15:0] stat_ae_rect_w;
	reg [15:0] stat_ae_rect_h;
	// Registers for AE（自动曝光：目标亮度、偏度、裁剪边界）
	reg [7:0] center_illuminance;
	reg [15:0] skewness;
	reg [11:0] ae_crop_left;
	reg [11:0] ae_crop_right;
	reg [11:0] ae_crop_top;
	reg [11:0] ae_crop_bottom;
	// Registers for AWB（自动白平衡：曝光限制与帧数）
	reg [BITS-1:0] awb_underexposed_limit;
	reg [BITS-1:0] awb_overexposed_limit;
	reg [BITS-1:0] awb_frames;
	// Registers for STAT AWB（AWB 直方图统计接口）
	reg stat_awb_hist_clk;
	reg stat_awb_hist_out;
	reg [STAT_HIST_BITS+1:0] stat_awb_hist_addr;

	// ---------------------------------------------------------------------------
	// ISP 输出信号
	// ---------------------------------------------------------------------------
	//****************************************************
	//********************** Outputs *********************
	// Main output of the ISP module（ISP 主输出同步信号）
	wire out_href, out_vsync;
	//wire [7:0] out_y, out_u, out_v;	// 已弃用
	// Output till Gamma Module of the ISP（Gamma 模块调试输出，用于旁路 VIP 时直接导出）
	wire out_gamma_href, out_gamma_vsync;
	wire [BITS-1:0] out_gamma_r, out_gamma_g, out_gamma_b;
	// OECF LUTs ports for reading the table values（OECF LUT 读端口）
	wire [BITS-1:0] r_table_rdata, gr_table_rdata, gb_table_rdata, b_table_rdata;
	// DG（数字增益输出索引，由 AE 自动更新或手动设置）
	wire [DGAIN_ARRAY_BITS-1:0] dgain_index_out; 
	// GAMMA LUT port for reading the table（Gamma LUT 读端口）
	wire [BITS-1:0] gamma_table_r_rdata, gamma_table_g_rdata, gamma_table_b_rdata;
	// AE（自动曝光输出：响应状态、偏度、完成标志）
	wire [1:0] ae_response;           // AE 响应：0=正常 1=过曝 2=欠曝
	wire [1:0] ae_response_debug;     // AE 调试响应
	wire [15:0] ae_result_skewness;   // AE 计算的偏度值
	wire ae_done;                     // AE 计算完成标志（每帧一次）
	
	//===== AE debug ports（AE 调试端口，已注释）======//
	/*wire [23:0] ae_cropped_size;
	wire [40:0] sum_pix_square;
	wire [50:0] sum_pix_cube;
	wire [63:0] div_out_m_2;
	wire [63:0] div_out_m_3;
	wire [63:0] div_out_sqrt_fsm;
	wire [62:0] sqrt_fsm_out_sqrt;
	wire [63:0] div_out_ae_skewness;
	wire SQRT_FSM_EN;
	wire SQRT_FSM_DIV_EN;
	wire SQRT_FSM_DIV_DONE;
	wire SQRT_FSM_DONE;
	wire [31:0] SQRT_FSM_COUNT;*/
	//===== AE debug ports ======//
	
	// AWB outputs（自动白平衡输出：最终 R/B 通道增益）
	wire [11:0] final_r_gain,final_b_gain;
	//===== AWB debug ports（AWB 调试端口，已注释）=====//
	/*wire [23:0] awb_cropped_size;
    wire [BITS-1:0] awb_overexposed_pix_limit;
	wire [BITS-1:0] awb_underexposed_pix_limit;
	wire [37:0] div_Rgain_num_meanG;
    wire [37:0] div_Rgain_den_sumR;
    wire [37:0] div_Rgain_quo_Rgain;
    wire [37:0] div_Bgain_num_meanG;
    wire [37:0] div_Bgain_den_sumB;
    wire [37:0] div_Bgain_quo_Bgain;
    wire div_gains_sampled;*/
    //===== AWB debug ports =====//

	//****************************************************
	// *******Instantiate the Unit Under Test (UUT)*******
//	isp_top	#(
//	  /*BITS 					*/  BITS,
//	  /*SNS_WIDTH 				*/  SNS_WIDTH,
//	  /*SNS_HEIGHT 				*/  SNS_HEIGHT,
//	  /*CROP_WIDTH 				*/  CROP_WIDTH,
//	  /*CROP_HEIGHT 			*/  CROP_HEIGHT,
//	  /*BAYER 					*/  BAYER,
//	  /*OECF_R_LUT              */  OECF_R_LUT,
//	  /*OECF_GR_LUT             */  OECF_GR_LUT,
//	  /*OECF_GB_LUT             */  OECF_GB_LUT,
//	  /*OECF_B_LUT              */  OECF_B_LUT,
//	  /*BNR_WEIGHT_BITS         */  BNR_WEIGHT_BITS,
//	  /*DGAIN_ARRAY_SIZE        */  DGAIN_ARRAY_SIZE,
//	  /*DGAIN_ARRAY_BITS        */  DGAIN_ARRAY_BITS,
//	  /*AWB_CROP LEFT           */  AWB_CROP_LEFT,
//	  /*AWB_CROP RIGHT          */  AWB_CROP_RIGHT,
//	  /*AWB_CROP TOP            */  AWB_CROP_TOP,
//	  /*AWB_CROP BOTTOM         */  AWB_CROP_BOTTOM,
//	  /*GAMMA_R_LUT             */  GAMMA_R_LUT,
//	  /*GAMMA_G_LUT             */  GAMMA_G_LUT,
//	  /*GAMMA_B_LUT             */  GAMMA_B_LUT,
//	  /*NR2d_WEIGHTS_BITS       */  NR2D_WEIGHT_BITS,
//	  /*STAT_OUT_BITS 		    */  STAT_OUT_BITS,
//	  /*STAT_HIST_BITS 		    */  STAT_HIST_BITS,
//	  /*USE_CROP				*/  `USE_CROP,
//	  /*USE_DPC					*/  `USE_DPC,
//	  /*USE_BLC					*/	`USE_BLC,
//	  /*USE_OECF				*/	`USE_OECF,	  
//	  /*USE_DGAIN				*/  `USE_DGAIN,
//	  /*USE_LSC    				*/  `USE_LSC,
//	  /*USE_BNR					*/	`USE_BNR,					
//	  /*USE_WB					*/  `USE_WB,
//	  /*USE_DEMOSIC			    */  `USE_DEMOSIC,
//	  /*USE_CCM					*/  `USE_CCM,
//	  /*USE_GAMMA				*/  `USE_GAMMA,
//	  /*USE_CSC					*/  `USE_CSC, 
//	  /*USE_LDCI				*/  `USE_LDCI,
//	  /*USE_2DNR				*/  `USE_2DNR,
//	  /*USE_EE					*/	`USE_EE,
//	  /*USE_STAT_AE			    */  `USE_STAT_AE,
//	  /*USE_STAT_AWB			*/  `USE_AWB,
//	  /*USE_AE					*/	`USE_AE
//	 )
//	isp_top_i0(
//		// Clock and rest
//		.pclk(dvp_clk_out), 
//		.rst_n(rst_n), 
//		// DVP input
//		.in_href(dvp_href_out),	.in_vsync(dvp_vsync_out), .in_raw(dvp_out_raw[counter-1][BITS-1:0]),
//		// DVP 3 channel input
//		.in_href_rgb(dvp_href_rgb_out),	.in_vsync_rgb(dvp_vsync_rgb_out), .in_r(dvp_out_r[counter-1][BITS-1:0]), .in_g(dvp_out_g[counter-1][BITS-1:0]), .in_b(dvp_out_b[counter-1][BITS-1:0]),  						 
//		// DVP output
//		.out_href(out_href), .out_vsync(out_vsync), .out_y(out_y), .out_u(out_u), .out_v(out_v), 	 
//		// DVP Gamma output
//		.out_gamma_href(out_gamma_href), .out_gamma_vsync(out_gamma_vsync), .out_gamma_b(out_gamma_b), .out_gamma_g(out_gamma_g), .out_gamma_r(out_gamma_r), 	 
//		// Enable 3 channel input from outside
//		.rgb_inp_en(rgb_inp_en),
//		// Enable signals
//		.crop_en(crop_en), .dpc_en(dpc_en), .blc_en(blc_en), .bnr_en(bnr_en), .dgain_en(dgain_en),                    
//		.demosic_en(demosic_en), .oecf_en(oecf_en), .wb_en(wb_en), 
//		.ccm_en(ccm_en), .csc_en(csc_en), .gamma_en(gamma_en), 
//		.nr2d_en(nr2d_en), .ee_en(ee_en), .stat_ae_en(stat_ae_en), .awb_en(awb_en), .ae_en(ae_en),  
//		// DPC
//		.dpc_threshold(dpc_threshold),
//		// BLC and Linearization
//		.blc_r(blc_r), .blc_gr(blc_gr), .blc_gb(blc_gb), .blc_b(blc_b), .linear_en(linear_en),
//		.linear_r(linear_r), .linear_gr(linear_gr), .linear_gb(linear_gb), .linear_b(linear_b),
//		// OECF
//		.r_table_clk(r_table_clk), .gr_table_clk(gr_table_clk), .gb_table_clk(gb_table_clk), .b_table_clk(b_table_clk),
//		.r_table_wen(r_table_wen), .gr_table_wen(gr_table_wen), .gb_table_wen(gb_table_wen), .b_table_wen(b_table_wen),
//		.r_table_ren(r_table_ren), .gr_table_ren(gr_table_ren), .gb_table_ren(gb_table_ren), .b_table_ren(b_table_ren),
//		.r_table_addr(r_table_addr), .gr_table_addr(gr_table_addr), .gb_table_addr(gb_table_addr), .b_table_addr(b_table_addr),
//		.r_table_wdata(r_table_wdata), .gr_table_wdata(gr_table_wdata), .gb_table_wdata(gb_table_wdata), .b_table_wdata(b_table_wdata),
//		.r_table_rdata(r_table_rdata), .gr_table_rdata(gr_table_rdata), .gb_table_rdata(gb_table_rdata), .b_table_rdata(b_table_rdata),
//		// BNR
//		.bnr_space_kernel_r(bnr_space_kernel_r),.bnr_space_kernel_g(bnr_space_kernel_g), .bnr_space_kernel_b(bnr_space_kernel_b),
//		.bnr_color_curve_x_r(bnr_color_curve_x_r), .bnr_color_curve_y_r(bnr_color_curve_y_r),
//		.bnr_color_curve_x_g(bnr_color_curve_x_g), .bnr_color_curve_y_g(bnr_color_curve_y_g),
//		.bnr_color_curve_x_b(bnr_color_curve_x_b), .bnr_color_curve_y_b(bnr_color_curve_y_b), 
//		// DG
//		.dgain_array(dgain_array),
//		.dgain_isManual(dgain_isManual),
//		.dgain_man_index(dgain_man_index),
//		.dgain_index_out(dgain_index_out),
//		// WB
//		.wb_rgain(wb_rgain), .wb_bgain(wb_bgain), 
//		// CCM
//		.ccm_rr(ccm_rr), .ccm_rg(ccm_rg), .ccm_rb(ccm_rb), 
//		.ccm_gr(ccm_gr), .ccm_gg(ccm_gg), .ccm_gb(ccm_gb), 
//		.ccm_br(ccm_br), .ccm_bg(ccm_bg), .ccm_bb(ccm_bb),
//		// GAMMA
//		.gamma_table_r_clk(gamma_table_r_clk), .gamma_table_r_wen(gamma_table_r_wen), .gamma_table_r_ren(gamma_table_r_ren), .gamma_table_r_addr(gamma_table_r_addr), .gamma_table_r_wdata(gamma_table_r_wdata), .gamma_table_r_rdata(gamma_table_r_rdata),
//		.gamma_table_g_clk(gamma_table_g_clk), .gamma_table_g_wen(gamma_table_g_wen), .gamma_table_g_ren(gamma_table_g_ren), .gamma_table_g_addr(gamma_table_g_addr), .gamma_table_g_wdata(gamma_table_g_wdata), .gamma_table_g_rdata(gamma_table_g_rdata),
//		.gamma_table_b_clk(gamma_table_b_clk), .gamma_table_b_wen(gamma_table_b_wen), .gamma_table_b_ren(gamma_table_b_ren), .gamma_table_b_addr(gamma_table_b_addr), .gamma_table_b_wdata(gamma_table_b_wdata), .gamma_table_b_rdata(gamma_table_b_rdata),
//		//CSC
//		.in_conv_standard(in_conv_standard),
//		// 2DNR
//		.nr2d_diff(nr2d_diff), .nr2d_weight(nr2d_weight), 
//		// AE
//		.center_illuminance(center_illuminance),
//        .skewness(skewness),
//		.ae_crop_left(ae_crop_left),
//		.ae_crop_right(ae_crop_right),
//		.ae_crop_top(ae_crop_top),
//		.ae_crop_bottom(ae_crop_bottom),
//        .ae_response(ae_response),
//        .ae_result_skewness(ae_result_skewness),
//        .ae_response_debug(ae_response_debug),
//		.ae_done(ae_done),
		
//		//===== AE debug ports =====//
//		/*.cropped_size(ae_cropped_size),
//		.sum_pix_square(sum_pix_square),
//		.sum_pix_cube(sum_pix_cube),
//		.div_out_m_2(div_out_m_2),
//		.div_out_m_3(div_out_m_3),
//		.div_out_sqrt_fsm(div_out_sqrt_fsm),
//		.sqrt_fsm_out_sqrt(sqrt_fsm_out_sqrt),
//		.div_out_ae_skewness(div_out_ae_skewness),
//		.SQRT_FSM_EN(SQRT_FSM_EN),
//		.SQRT_FSM_DIV_EN(SQRT_FSM_DIV_EN),
//		.SQRT_FSM_DIV_DONE(SQRT_FSM_DIV_DONE),
//		.SQRT_FSM_DONE(SQRT_FSM_DONE),
//		.SQRT_FSM_COUNT(SQRT_FSM_COUNT),*/
//		//===== AE debug ports =====//
		
//      	// AWB
//		.awb_underexposed_limit(awb_underexposed_limit),
//		.awb_overexposed_limit(awb_overexposed_limit),
//		.awb_frames(awb_frames),
//		.final_r_gain(final_r_gain),
//		.final_b_gain(final_b_gain)

//		//===== AWB debug ports =====//
//    	/*,
//		.awb_cropped_size(awb_cropped_size),
//    	.awb_overexposed_pix_limit(awb_overexposed_pix_limit),
//		.awb_underexposed_pix_limit(awb_underexposed_pix_limit),
//		.div_Rgain_num_meanG(div_Rgain_num_meanG),
//    	.div_Rgain_den_sumR(div_Rgain_den_sumR),
//    	.div_Rgain_quo_Rgain(div_Rgain_quo_Rgain),
//    	.div_Bgain_num_meanG(div_Bgain_num_meanG),
//    	.div_Bgain_den_sumB(div_Bgain_den_sumB),
//    	.div_Bgain_quo_Bgain(div_Bgain_quo_Bgain),
//    	.div_gains_sampled(div_gains_sampled)*/
//    	//===== AWB debug ports =====//
//	);
    //*****************************************************
    //********************** VIP1 *************************
    //********************** Inputs ***********************
	// ---------------------------------------------------------------------------
	// VIP1 运行时控制寄存器
	// ---------------------------------------------------------------------------
	// VIP1 是第一级视频后处理模块，支持直方图均衡、Sobel、RGBC、IRC、缩放、OSD、YUV 格式转换等。

    // Module Enables（VIP1 各子模块运行时使能）
    reg vip1_hist_equ_en, vip1_sobel_en, vip1_rgbc_en, vip1_irc_en, vip1_dscale_en, vip1_osd_en, vip1_yuv444to422_en;
    // Hist Equ（直方图均衡：亮度范围限制）
    reg [VIP1_BITS-1:0] vip1_equ_min, vip1_equ_max;
    // YUV-RGB（色彩空间转换标准）
    reg [1:0] vip1_in_conv_standard;
    // Crop（IRC 裁剪起始坐标与输出模式）
    reg [15:0] vip1_crop_x, vip1_crop_y;
    reg [1:0] vip1_irc_output;
    // SCALE（缩放参数：输入/输出尺寸、下采样因子）
    reg [11:0] vip1_s_in_crop_w;
    reg [11:0] vip1_s_in_crop_h;
	reg [11:0] vip1_s_out_crop_w;
	reg [11:0] vip1_s_out_crop_h;
	reg [2:0] vip1_dscale_w;
	reg [2:0] vip1_dscale_h;
	// OSD（字幕叠加：位置、尺寸、前景/背景色、透明度）
	reg [15:0] vip1_osd_x, vip1_osd_y, vip1_osd_w, vip1_osd_h; 
	reg [23:0] vip1_osd_color_fg, vip1_osd_color_bg ; // 每通道 8 位
	reg [7:0] vip1_osd_alpha;
	// OSD RAM（OSD 图案存储 RAM 接口）
	reg                                vip1_osd_ram_clk;
	reg                                vip1_osd_ram_wen;
	reg                                vip1_osd_ram_ren;
	reg  [VIP1_OSD_RAM_ADDR_BITS-1:0]  vip1_osd_ram_addr;
	wire [VIP1_OSD_RAM_DATA_BITS-1:0]  vip1_osd_ram_wdata;
    wire [VIP1_OSD_RAM_DATA_BITS-1:0]  vip1_osd_ram_rdata;           // 读出数据
    // YUV444-422（YUV 格式转换：0=保持444 1=转为422）
    reg vip1_YUV444TO422;
    
	// VIP1 输出信号（DVP 格式 RGB）
    wire vip1_out_pclk;
    wire vip1_out_href;
	wire vip1_out_vsync;
	wire [VIP1_BITS-1:0] vip1_out_g;
	wire [VIP1_BITS-1:0] vip1_out_b;
	wire [VIP1_BITS-1:0] vip1_out_r;
	
    //*****************************************************
    //********************** VIP2 *************************
    //********************** Inputs ***********************
	// ---------------------------------------------------------------------------
	// VIP2 运行时控制寄存器
	// ---------------------------------------------------------------------------
	// VIP2 是第二级视频后处理模块，结构与 VIP1 相同，可级联使用。

    // Module Enables（VIP2 各子模块运行时使能）
    reg vip2_hist_equ_en, vip2_sobel_en, vip2_rgbc_en, vip2_irc_en, vip2_dscale_en, vip2_osd_en, vip2_yuv444to422_en;
    // Hist Equ（直方图均衡：亮度范围限制）
    reg [VIP2_BITS-1:0] vip2_equ_min, vip2_equ_max;
    // YUV-RGB（色彩空间转换标准）
    reg [1:0] vip2_in_conv_standard;
    // Crop（IRC 裁剪起始坐标与输出模式）
    reg [15:0] vip2_crop_x, vip2_crop_y;
    reg [1:0] vip2_irc_output;
    // SCALE（缩放参数：输入/输出尺寸、下采样因子）
    reg [11:0] vip2_s_in_crop_w;
    reg [11:0] vip2_s_in_crop_h;
	reg [11:0] vip2_s_out_crop_w;
	reg [11:0] vip2_s_out_crop_h;
	reg [2:0] vip2_dscale_w;
	reg [2:0] vip2_dscale_h;
	// OSD（字幕叠加：位置、尺寸、前景/背景色、透明度）
	reg [15:0] vip2_osd_x, vip2_osd_y, vip2_osd_w, vip2_osd_h; 
	reg [23:0] vip2_osd_color_fg, vip2_osd_color_bg ; // 每通道 8 位
	reg [7:0] vip2_osd_alpha;
	// OSD RAM（OSD 图案存储 RAM 接口）
	reg                                vip2_osd_ram_clk;
	reg                                vip2_osd_ram_wen;
	reg                                vip2_osd_ram_ren;
	reg  [VIP2_OSD_RAM_ADDR_BITS-1:0]  vip2_osd_ram_addr;
	wire [VIP2_OSD_RAM_DATA_BITS-1:0]  vip2_osd_ram_wdata;
    wire [VIP2_OSD_RAM_DATA_BITS-1:0]  vip2_osd_ram_rdata;           // 读出数据
    // YUV（YUV 格式转换：0=保持444 1=转为422）
    reg vip2_YUV444TO422;
    
	// VIP2 输出信号（DVP 格式 RGB）
    wire vip2_out_pclk;
    wire vip2_out_href;
	wire vip2_out_vsync;
	wire [VIP2_BITS-1:0] vip2_out_g;
	wire [VIP2_BITS-1:0] vip2_out_b;
	wire [VIP2_BITS-1:0] vip2_out_r;
	
	// ---------------------------------------------------------------------------
	// 辅助模块实例化
	// ---------------------------------------------------------------------------
	wire scale_clk;
	// Clock Divider instantiation（时钟分频器：为 SCALE 模块生成低速时钟）
	Clock_divider 
    #(
         ((SCALE_EN == 1) ? SCALE_W : 1)
    )
    clk_divider ( pclk, scale_clk);
	

	// OSD LUT instantiation（OSD 图案 LUT：为 VIP1/VIP2 的 OSD RAM 提供测试数据）
	osd_lut #(OSD_RAM_ADDR_BITS,OSD_RAM_DATA_BITS) lut0(vip1_osd_ram_addr, vip1_osd_ram_wdata);
	osd_lut #(OSD_RAM_ADDR_BITS,OSD_RAM_DATA_BITS) lut1(vip2_osd_ram_addr, vip2_osd_ram_wdata);
	

	// VIP Module Instantiation
//	vip_top	#(
////	  /*BITS 					*/  VIP_BITS,
////	  /*WIDTH 					*/  SNS_WIDTH,
////	  /*HEIGHT 					*/  SNS_HEIGHT,
////      /*OSD_RAM_ADDR_BITS       */  OSD_RAM_ADDR_BITS,
////	  /*OSD_RAM_DATA_BITS       */  OSD_RAM_DATA_BITS,
////	  /*USE_HIST_EQU			*/  `USE_HIST_EQU,
////	  /*USE_SOBEL				*/	`USE_SOBEL,
////	  /*USE_YUV2RGB				*/	`USE_RGBC,	  
////	  /*USE_CROP				*/  `USE_IRC,
////	  /*USE_DSCALE    			*/  `USE_SCALE,
////	  /*USE_OSD					*/	`USE_OSD,					
////	  /*USE_YUV444TO422			*/  `USE_YUVConvFormat
////	  //*YUV_OUTPUT_FORMAT       */   YUV444TO422
//	  )
//	  vip_top_i0(
//		// Clock and rest
//		.pclk(dvp_clk_out), 
//		.scale_pclk(scale_clk),
//		.rst_n(rst_n),
//		// Input 
//		.in_href( out_href ), .in_vsync(out_vsync), .in_y(out_y), .in_u(out_u), .in_v(out_v),
//		// Output
//		.out_pclk(out_pclk), .out_href(vip_out_href), .out_vsync(vip_out_vsync), .out_b(out_b), .out_g(out_g), .out_r(out_r), 
//		// Module Enables
//		.hist_equ_en(hist_equ_en), .sobel_en(sobel_en), .yuv2rgb_en(yuv2rgb_en), .irc_en(irc_en), .dscale_en(dscale_en), .osd_en(osd_en), .yuv444to422_en(yuv444to422_en),
//		// Hist_equ
//		.equ_min(equ_min), .equ_max(equ_max),
//		//YUV-RGB
//		.in_conv_standard(in_conv_standard),
//		// Crop
//		.crop_x(crop_x), .crop_y(crop_y),
//		.irc_output(irc_output),
//		//scale
//		.s_in_crop_w(s_in_crop_w),
//		.s_in_crop_h(s_in_crop_h),
//		.s_out_crop_w(s_out_crop_w),
//		.s_out_crop_h(s_out_crop_h),
//		.dscale_w(dscale_w),
//		.dscale_h(dscale_h),
//		//YUV
//		.YUV444TO422(YUV444TO422),
//		// OSD 						 
//		.osd_x(osd_x), .osd_y(osd_y), .osd_w(osd_w), .osd_h(osd_h),
//		.osd_color_fg(osd_color_fg), .osd_color_bg(osd_color_bg),
//		.osd_ram_clk(osd_ram_clk), .osd_ram_wen(osd_ram_wen), .osd_ram_ren(osd_ram_ren), .osd_ram_addr(osd_ram_addr), .osd_ram_wdata(osd_ram_wdata), .osd_ram_rdata(osd_ram_rdata)
//		);
	
	// ---------------------------------------------------------------------------
	// DUT：infinite_isp（系统级顶层）
	// ---------------------------------------------------------------------------
	// 该模块内部包含 ISP 与 VIP1/VIP2 的流水线连接。
	// 通过大量参数与使能信号控制：
	// - 编译时 USE_*：决定哪些子模块被实例化
	// - 运行时 *_en：决定数据是否经过该子模块或旁路
	infinite_isp #(
		.BITS					(BITS),
		.SNS_WIDTH				(SNS_WIDTH),
		.SNS_HEIGHT				(SNS_HEIGHT),
		.CROP_WIDTH				(CROP_WIDTH),
		.CROP_HEIGHT			(CROP_HEIGHT),
		.BAYER					(BAYER),
		.OECF_R_LUT				(OECF_R_LUT),
		.OECF_GR_LUT			(OECF_GR_LUT),
		.OECF_GB_LUT			(OECF_GB_LUT),
		.OECF_B_LUT				(OECF_B_LUT),
		.BNR_WEIGHT_BITS		(BNR_WEIGHT_BITS),
		.DGAIN_ARRAY_SIZE		(DGAIN_ARRAY_SIZE),
		.DGAIN_ARRAY_BITS		(DGAIN_ARRAY_BITS),
		.AWB_CROP_LEFT			(AWB_CROP_LEFT),
		.AWB_CROP_RIGHT			(AWB_CROP_RIGHT),
		.AWB_CROP_TOP			(AWB_CROP_TOP),
		.AWB_CROP_BOTTOM		(AWB_CROP_BOTTOM),
		.GAMMA_R_LUT			(GAMMA_R_LUT),
		.GAMMA_G_LUT			(GAMMA_G_LUT),
		.GAMMA_B_LUT			(GAMMA_B_LUT),
		.SHARP_WEIGHT_BITS		(SHARP_WEIGHT_BITS),
		.NR2D_WEIGHT_BITS		(NR2D_WEIGHT_BITS),
		.STAT_OUT_BITS			(STAT_OUT_BITS),
		.STAT_HIST_BITS			(STAT_HIST_BITS),
		.USE_CROP				(`USE_CROP),
		.USE_DPC				(`USE_DPC),
		.USE_BLC				(`USE_BLC),
		.USE_OECF				(`USE_OECF),
		.USE_DGAIN				(`USE_DGAIN),
		.USE_LSC				(`USE_LSC),
		.USE_BNR				(`USE_BNR),
		.USE_WB					(`USE_WB),
		.USE_DEMOSIC			(`USE_DEMOSIC),
		.USE_CCM				(`USE_CCM),
		.USE_GAMMA				(`USE_GAMMA),
		.USE_CSC				(`USE_CSC),
		.USE_SHARP				(`USE_SHARP),
		.USE_LDCI				(`USE_LDCI),
		.USE_2DNR				(`USE_2DNR),
		.USE_STAT_AE			(`USE_STAT_AE),
		.USE_AWB				(`USE_AWB),
		.USE_AE					(`USE_AE),

		// VIP1 Parameters //
		.VIP1_BITS						(VIP1_BITS),
		.VIP1_OSD_RAM_ADDR_BITS			(VIP1_OSD_RAM_ADDR_BITS),
		.VIP1_OSD_RAM_DATA_BITS			(VIP1_OSD_RAM_DATA_BITS),
		.VIP1_USE_HIST_EQU				(`VIP1_USE_HIST_EQU),
		.VIP1_USE_SOBEL					(`VIP1_USE_SOBEL),
		.VIP1_USE_RGBC					(`VIP1_USE_RGBC),
		.VIP1_USE_IRC					(`VIP1_USE_IRC),
		.VIP1_USE_SCALE					(`VIP1_USE_SCALE),
		.VIP1_USE_OSD					(`VIP1_USE_OSD),
		.VIP1_USE_YUVConvFormat			(`VIP1_USE_YUVConvFormat),

		// VIP2 Parameters //
		.VIP2_BITS						(VIP2_BITS),
		.VIP2_OSD_RAM_ADDR_BITS			(VIP2_OSD_RAM_ADDR_BITS),
		.VIP2_OSD_RAM_DATA_BITS			(VIP2_OSD_RAM_DATA_BITS),
		.VIP2_USE_HIST_EQU				(`VIP2_USE_HIST_EQU),
		.VIP2_USE_SOBEL					(`VIP2_USE_SOBEL),
		.VIP2_USE_RGBC					(`VIP2_USE_RGBC),
		.VIP2_USE_IRC					(`VIP2_USE_IRC),
		.VIP2_USE_SCALE					(`VIP2_USE_SCALE),
		.VIP2_USE_OSD					(`VIP2_USE_OSD),
		.VIP2_USE_YUVConvFormat			(`VIP2_USE_YUVConvFormat)

	) inst_infinite_isp(
		// Video Input interface - RAW
		.pclk				(dvp_clk_out),
		.rst_n				(rst_n),
		.in_href			(dvp_href_out),
		.in_vsync			(dvp_vsync_out),
		// 注意：按 counter-1 选择“当前帧”的像素数据源
		.in_raw				(dvp_out_raw[counter-1][BITS-1:0]),

		// Video Input interface - RGB (RAW bypass)
		.in_href_rgb		(dvp_href_rgb_out),
		.in_vsync_rgb		(dvp_vsync_rgb_out),
		// RGB bypass 模式下同样按 counter-1 选择每帧输入
		.in_r				(dvp_out_r[counter-1][BITS-1:0]),
		.in_g				(dvp_out_g[counter-1][BITS-1:0]),
		.in_b				(dvp_out_b[counter-1][BITS-1:0]),
		
		// Debug Output Interface - Gamma (Debug)
		.out_gamma_href		(out_gamma_href),
		.out_gamma_vsync	(out_gamma_vsync),
		.out_gamma_r		(out_gamma_r),
		.out_gamma_g		(out_gamma_g),
		.out_gamma_b		(out_gamma_b),

		// Input Interface Selection
		.rgb_inp_en			(rgb_inp_en),

		// ISP blocks' Enable Signals
		.crop_en			(crop_en),
		.dpc_en				(dpc_en),
		.blc_en				(blc_en),
		.linear_en			(linear_en),
		.oecf_en			(oecf_en),
		.bnr_en				(bnr_en),
		.dgain_en			(dgain_en),
		.lsc_en				(lsc_en),
		.demosic_en			(demosic_en),
		.wb_en				(wb_en),
		.ccm_en				(ccm_en),
		.csc_en				(csc_en),
		.gamma_en			(gamma_en),
		.ldci_en			(ldci_en),
		.nr2d_en			(nr2d_en),
		.sharp_en			(sharp_en),
		.stat_ae_en			(stat_ae_en),
		.awb_en				(awb_en),
		.ae_en				(ae_en),

		// ISP blocks' I/O ports for tunable pipeline parameters
		
		// DPC
		.dpc_threshold			(dpc_threshold),

		// BLC and Linearization
		.blc_r					(blc_r),
		.blc_gr					(blc_gr),
		.blc_gb					(blc_gb),
		.blc_b					(blc_b),
		.linear_r				(linear_r),
		.linear_gr				(linear_gr),
		.linear_gb				(linear_gb),
		.linear_b				(linear_b),
		
		// OECF
		.r_table_clk(r_table_clk), .gr_table_clk(gr_table_clk), .gb_table_clk(gb_table_clk), .b_table_clk(b_table_clk),
		.r_table_wen(r_table_wen), .gr_table_wen(gr_table_wen), .gb_table_wen(gb_table_wen), .b_table_wen(b_table_wen),
		.r_table_ren(r_table_ren), .gr_table_ren(gr_table_ren), .gb_table_ren(gb_table_ren), .b_table_ren(b_table_ren),
		.r_table_addr(r_table_addr), .gr_table_addr(gr_table_addr), .gb_table_addr(gb_table_addr), .b_table_addr(b_table_addr),
		.r_table_wdata(r_table_wdata), .gr_table_wdata(gr_table_wdata), .gb_table_wdata(gb_table_wdata), .b_table_wdata(b_table_wdata),
		.r_table_rdata(r_table_rdata), .gr_table_rdata(gr_table_rdata), .gb_table_rdata(gb_table_rdata), .b_table_rdata(b_table_rdata),

		// BNR
		.bnr_space_kernel_r		(bnr_space_kernel_r),
		.bnr_space_kernel_g		(bnr_space_kernel_g),
		.bnr_space_kernel_b		(bnr_space_kernel_b),
		.bnr_color_curve_x_r   	(bnr_color_curve_x_r),
		.bnr_color_curve_y_r	(bnr_color_curve_y_r),
		.bnr_color_curve_x_g	(bnr_color_curve_x_g),   
		.bnr_color_curve_y_g	(bnr_color_curve_y_g),
		.bnr_color_curve_x_b   	(bnr_color_curve_x_b),
		.bnr_color_curve_y_b	(bnr_color_curve_y_b),

		// DGvid_data
		.dgain_isManual			(dgain_isManual),
		.dgain_man_index		(dgain_man_index),
		.dgain_array			(dgain_array),
		.dgain_index_out		(dgain_index_out),						// output 

		// WB
		.wb_rgain				(wb_rgain),
		.wb_bgain				(wb_bgain),

		// CCM
		.ccm_rr					(ccm_rr),
		.ccm_rg					(ccm_rg),
		.ccm_rb					(ccm_rb),
		.ccm_gr					(ccm_gr),
		.ccm_gg					(ccm_gg),
		.ccm_gb					(ccm_gb),
		.ccm_br					(ccm_br),
		.ccm_bg					(ccm_bg),
		.ccm_bb					(ccm_bb),

		// GAMMA
		.gamma_table_r_clk		(gamma_table_r_clk),
		.gamma_table_g_clk		(gamma_table_g_clk),
		.gamma_table_b_clk		(gamma_table_b_clk),	
		.gamma_table_r_wen		(gamma_table_r_wen),
		.gamma_table_g_wen		(gamma_table_g_wen),
		.gamma_table_b_wen		(gamma_table_b_wen),
		.gamma_table_r_ren		(gamma_table_r_ren),
		.gamma_table_g_ren		(gamma_table_g_ren),
		.gamma_table_b_ren		(gamma_table_b_ren),
		.gamma_table_r_addr		(gamma_table_r_addr),
		.gamma_table_g_addr		(gamma_table_g_addr),
		.gamma_table_b_addr		(gamma_table_b_addr),
		.gamma_table_r_wdata	(gamma_table_r_wdata),
		.gamma_table_g_wdata	(gamma_table_g_wdata),
		.gamma_table_b_wdata	(gamma_table_b_wdata),
		.gamma_table_r_rdata	(gamma_table_r_rdata),		//output
		.gamma_table_g_rdata	(gamma_table_g_rdata),		//output
		.gamma_table_b_rdata	(gamma_table_b_rdata),		//output

		// CSC
		.in_conv_standard		(in_conv_standard),

		// SHARP
		.luma_kernel			(luma_kernel),
        .sharpen_strength		(sharpen_strength),

		// 2DNR
		.nr2d_diff				(nr2d_diff),
		.nr2d_weight			(nr2d_weight),

		// AE
		.center_illuminance		(center_illuminance),
        .skewness				(skewness),
		.ae_crop_left			(ae_crop_left),
		.ae_crop_right			(ae_crop_right),
		.ae_crop_top			(ae_crop_top),
		.ae_crop_bottom			(ae_crop_bottom),
        .ae_response			(ae_response),				//output
        .ae_result_skewness		(ae_result_skewness),		//output
        .ae_response_debug		(ae_response_debug),		//output
		.ae_done				(ae_done),					//output
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
		.awb_underexposed_limit	(awb_underexposed_limit),
		.awb_overexposed_limit	(awb_overexposed_limit),
		.awb_frames				(awb_frames),
    	// selected gains that are input to WB block
		.final_r_gain			(final_r_gain),           //output
		.final_b_gain			(final_b_gain),           //output

		//===== AWB debug ports =====//
    	/*,
		awb_cropped_size,
		awb_overexposed_pix_limit,
		awb_underexposed_pix_limit,
    	div_Rgain_num_meanG,
    	div_Rgain_den_sumR,
    	div_Rgain_quo_Rgain,
    	div_Bgain_num_meanG,
    	div_Bgain_den_sumB,
    	div_Bgain_quo_Bgain,
    	div_gains_sampled
		*/
    	//===== AWB debug ports =====//

		// VIP1 Scaler clock
		.scale_pclk1			(scale_clk),

		// Video Output Interface - VIP1		
		.out_pclk				(vip1_out_pclk),
		.out_href				(vip1_out_href),
		.out_vsync				(vip1_out_vsync),
		.out_r					(vip1_out_r),
		.out_g					(vip1_out_g),
		.out_b					(vip1_out_b),

		// VIP1 blocks' Enable Signals
		.hist_equ_en			(vip1_hist_equ_en),
		.sobel_en				(vip1_sobel_en),
		.rgbc_en				(vip1_rgbc_en),
		.irc_en					(vip1_irc_en),
		.dscale_en				(vip1_dscale_en),
		.osd_en					(vip1_osd_en),
		.yuv444to422_en			(vip1_yuv444to422_en),

		// VIP1 blocks' I/O ports for tunable pipeline parameters
		// HIST EQU
		.equ_min				(vip1_equ_min),
		.equ_max				(vip1_equ_max),
		// RGBC
		.in_conv_standard_rgbc	(vip1_in_conv_standard),
		// IRC
		.crop_x					(vip1_crop_x),
		.crop_y					(vip1_crop_y),
		.irc_output             (vip1_irc_output),
		// SCALE
		.s_in_crop_w            (vip1_s_in_crop_w),
		.s_in_crop_h            (vip1_s_in_crop_h),
		.s_out_crop_w           (vip1_s_out_crop_w),
		.s_out_crop_h           (vip1_s_out_crop_h),
		.dscale_w               (vip1_dscale_w),
		.dscale_h               (vip1_dscale_h),
		// OSD
		.osd_x                  (vip1_osd_x),
		.osd_y                  (vip1_osd_y),
		.osd_w                  (vip1_osd_w),
		.osd_h                  (vip1_osd_h),
		.osd_color_fg           (vip1_osd_color_fg),
		.osd_color_bg           (vip1_osd_color_bg),
		.osd_alpha				(vip1_osd_alpha),
		.osd_ram_clk            (vip1_osd_ram_clk),
		.osd_ram_wen            (vip1_osd_ram_wen),
		.osd_ram_ren            (vip1_osd_ram_ren),
		.osd_ram_addr           (vip1_osd_ram_addr),
		.osd_ram_wdata          (vip1_osd_ram_wdata),
		.osd_ram_rdata          (vip1_osd_ram_rdata),
		// YUV444-422
		.YUV444TO422			(vip1_YUV444TO422),

		// VIP2 Scaler clock
		.scale_pclk2			(scale_clk),

		// Video Output Interface - VIP2		
		.out_pclk2				(vip2_out_pclk),
		.out_href2				(vip2_out_href),
		.out_vsync2				(vip2_out_vsync),
		.out_r2					(vip2_out_r),
		.out_g2					(vip2_out_g),
		.out_b2					(vip2_out_b),

		// VIP2 blocks' Enable Signals
		.hist_equ_en2			(vip2_hist_equ_en),
		.sobel_en2				(vip2_sobel_en),
		.rgbc_en2				(vip2_rgbc_en),
		.irc_en2				(vip2_irc_en),
		.dscale_en2				(vip2_dscale_en),
		.osd_en2				(vip2_osd_en),
		.yuv444to422_en2		(vip2_yuv444to422_en),

		// VIP2 blocks' I/O ports for tunable pipeline parameters
		// HIST EQU
		.equ_min2				(vip2_equ_min),
		.equ_max2				(vip2_equ_max),
		// RGBC
		.in_conv_standard_rgbc2	(vip2_in_conv_standard),
		// IRC
		.crop_x2				(vip2_crop_x),
		.crop_y2				(vip2_crop_y),
		.irc_output2            (vip2_irc_output),
		// SCALE
		.s_in_crop_w2           (vip2_s_in_crop_w),
		.s_in_crop_h2           (vip2_s_in_crop_h),
		.s_out_crop_w2          (vip2_s_out_crop_w),
		.s_out_crop_h2          (vip2_s_out_crop_h),
		.dscale_w2              (vip2_dscale_w),
		.dscale_h2              (vip2_dscale_h),
		// OSD
		.osd_x2                 (vip2_osd_x),
		.osd_y2                 (vip2_osd_y),
		.osd_w2                 (vip2_osd_w),
		.osd_h2                 (vip2_osd_h),
		.osd_color_fg2          (vip2_osd_color_fg),
		.osd_color_bg2          (vip2_osd_color_bg),
		.osd_alpha2				(vip2_osd_alpha),
		.osd_ram_clk2           (vip2_osd_ram_clk),
		.osd_ram_wen2           (vip2_osd_ram_wen),
		.osd_ram_ren2           (vip2_osd_ram_ren),
		.osd_ram_addr2          (vip2_osd_ram_addr),
		.osd_ram_wdata2         (vip2_osd_ram_wdata),
		.osd_ram_rdata2         (vip2_osd_ram_rdata),
		// YUV444-422
		.YUV444TO4222			(vip2_YUV444TO422)

	);
	
	//*****************************************************
	//********************** DVP2File *********************
	// ---------------------------------------------------------------------------
	// 输出写文件（逐帧分文件）
	// ---------------------------------------------------------------------------
	// 关键点：shift_out 是一个 one-hot 移位寄存器，用于“指示当前属于第几帧”。
	// - 在每帧 VSYNC 上升沿时 shift_out 左移，使得第 m 位与第 m 帧对齐。
	// - 在 `tb_dvp_to_file` 侧用 `vip1_out_href && shift_out[m]` 做门控：
	//   只有当前帧对应的那个实例才会写入自己的输出文件。
	//
	// Take outputs from the ISP and convert it to Binary file
    reg [9:0] shift_out;
    always @(posedge pclk or negedge rst_n) begin
    if (!rst_n)
      shift_out <= 8'b0;
    else if(counter == 0) //
        if((~prev_vsync) && dvp_vsync_out)
            shift_out <= {shift_out[8:0], 1'b1};
        else
            shift_out <= shift_out;
    else if((~prev_vsync) && dvp_vsync_out)
        shift_out <= shift_out << 1;
    else
        shift_out <= shift_out;
    end
	genvar m;
	generate
	for(m=0; m<NUM_SEQ_FRAMES; m=m+1) begin: INSTANCE_GEN_OUT
		// 每帧一个输出文件实例：OUT_FILE_m.bin
		// 根据 CSC/VIP 使能状态选择输出源：
		// - csc_onwards：从 VIP1 输出（经过 CSC/NR2D/RGBC/IRC/OSD/SCALE 等处理）
		// - before_csc ：从 Gamma 输出（ISP 处理完但未经 VIP）
	   	if ( CSC_EN | NR2D_EN | RGBC_EN | IRC_EN | OSD_EN | SCALE_EN | YUVConvFormat_EN ) begin :csc_onwards
	       tb_dvp_to_file
	       #(
		      .FILE_BASE(OUT_FILE),
		      .FRAME_IDX(m),
		      .BITS(16*3)  // 3 通道 x 16bit（高 8 位补 0）
	        )
	       dvp2file
	       (
		      .pclk(vip1_out_pclk), 
		      .rst_n(rst_n),
		      .href(vip1_out_href && shift_out[m]),  // 仅当前帧写入
		      .vsync(vip1_out_vsync),
		      .data({{8'd0,vip1_out_b}, {8'd0,vip1_out_g}, {8'd0,vip1_out_r}})
		   );	
	    end
	    else begin :before_csc
	    if (BITS_DIFF == 0) begin 
	    tb_dvp_to_file
	    #(
		      .FILE_BASE(OUT_FILE),
		      .FRAME_IDX(m),
		      .BITS(BITS*3)  // 3 x BITS  for three channels       
	      )
	      dvp2file
	      (
		      .pclk(dvp_clk_out), 
		      .rst_n(rst_n),
		      .href(out_gamma_href && shift_out[m]),
		      .vsync(out_gamma_vsync),
		      .data({out_gamma_b,out_gamma_g,out_gamma_r})
	       );
	       end else begin
	       tb_dvp_to_file
	           #(
		          .FILE_BASE(OUT_FILE),
		          .FRAME_IDX(m),
		          .BITS(BITS_FILE*3)  // 3 x BITS  for three channels       
	             )
	       dvp2file
	       (
		      .pclk(dvp_clk_out), 
		      .rst_n(rst_n),
		      .href(out_gamma_href && shift_out[m]),
		      .vsync(out_gamma_vsync),
		      .data({ {BITS_DIFF{1'b0}},out_gamma_b, {BITS_DIFF{1'b0}},out_gamma_g, {BITS_DIFF{1'b0}},out_gamma_r})
	       );
	       end
	    end
	   end
    endgenerate
//    generate
//	if ( CSC_EN | NR2D_EN | RGBC_EN | IRC_EN | SCALE_EN | YUVConvFormat_EN ) begin :csc_onwards
//	tb_dvp_to_file
//	   #(
//		  /*FILE 		*/ OUT_FILE,
//		  /*BITS 		*/	16*3  // 3 x BITS  for three channels       
//	    )
//	   dvp2file
//	   (
//		  .pclk(out_pclk), 
//		  .rst_n(rst_n),
//		  .href(vip_out_href),
//		  .vsync(vip_out_vsync),
//		  .data({{8'd0,out_b}, {8'd0,out_g}, {8'd0,out_r}})
//		);	
//	end
//	else begin :before_csc
//	if (BITS_DIFF == 0) begin 
//	tb_dvp_to_file
//	#(
//		/*FILE 		*/ OUT_FILE,
//		/*BITS 		*/	BITS*3  // 3 x BITS  for three channels       
//	 )
//	dvp2file
//	(
//		.pclk(dvp_clk_out), 
//		.rst_n(rst_n),
//		.href(out_gamma_href),
//		.vsync(out_gamma_vsync),
//		.data({out_gamma_b,out_gamma_g,out_gamma_r})
//	);
//	end else begin
//	   tb_dvp_to_file
//	   #(
//		  /*FILE 		*/ OUT_FILE,
//		  /*BITS 		*/	BITS_FILE*3  // 3 x BITS  for three channels       
//	    )
//	   dvp2file
//	   (
//		  .pclk(dvp_clk_out), 
//		  .rst_n(rst_n),
//		  .href(out_gamma_href),
//		  .vsync(out_gamma_vsync),
//		  .data({ {BITS_DIFF{1'b0}},out_gamma_b, {BITS_DIFF{1'b0}},out_gamma_g, {BITS_DIFF{1'b0}},out_gamma_r})
//	   );
//	  end
//	 end
//endgenerate

//===== SAVE AWB GAINS TO FILE =====//
	// ---------------------------------------------------------------------------
	// AWB/AE/DGain 辅助结果写文件
	// ---------------------------------------------------------------------------
	// 这些文件通常用于与 Golden Model 的统计输出对比：
	// - AWB：每帧输出一次最终增益（final_r_gain/final_b_gain）
	// - AE ：在 ae_done 时输出响应与 skewness
	// - DG ：在 ae_done 后延迟一拍输出更新后的 DGain 索引
localparam OUT_FILE_rgain = "out/rgain_In_crop_Indoor1_2592x1536_10bit_GRBG.bin";
localparam OUT_FILE_bgain = "out/bgain_In_crop_Indoor1_2592x1536_10bit_GRBG.bin";

assign out_href = vip1_out_href;
assign out_vsync = vip1_out_vsync;

// ---------------------------------------------------------------------------
// AWB 增益写文件逻辑
// ---------------------------------------------------------------------------
// 在每帧 VSYNC 下降沿时（prev_v_sync & ~out_vsync）写出当前帧的 AWB 增益。
// writer/writeb：将 12 位增益扩展为 16 位以便按字节写入。
reg prev_v_sync;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_v_sync <= 0;
       else
            prev_v_sync <= out_vsync;
    end
wire [15:0] writer;
wire [15:0] writeb;
assign writer = {4'd0,final_r_gain};  // R 增益（12 位 -> 16 位）
assign writeb = {4'd0,final_b_gain};  // B 增益（12 位 -> 16 位）
		
integer fd, c;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			fd = $fopen(OUT_FILE_rgain, "wb");
		else if (prev_v_sync & (~out_vsync))  // VSYNC 下降沿
			for (c = 0; c < 16/8; c = c + 1)
				$fwrite(fd, "%c", writer[(c*8)+:8]);
		else if (out_vsync)
			$fflush(fd);
	end
integer fd1, c1;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n)
            fd1 = $fopen(OUT_FILE_bgain, "wb");
        else if (prev_v_sync & (~out_vsync))  // VSYNC 下降沿
            for (c1 = 0; c1 < 16/8; c1 = c1 + 1)
                $fwrite(fd1, "%c", writeb[(c1*8)+:8]);
        else if (out_vsync)
            $fflush(fd1);
    end

// ---------------------------------------------------------------------------
// AE 响应与 DGain 索引写文件逻辑
// ---------------------------------------------------------------------------
// AE 在 ae_done 时写出响应值；DGain 在 ae_done 延迟一拍后写出更新后的索引。
reg pprev_v_sync, v_sync_3rdLast;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            pprev_v_sync <= 0;
            v_sync_3rdLast <= 0;
            end
       else begin
            pprev_v_sync <= prev_v_sync;
            v_sync_3rdLast <= pprev_v_sync;
            end
    end

	reg ae_done_delay;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			ae_done_delay <= 1'b0;
		end
		else begin
			ae_done_delay <= ae_done;
		end
	end
localparam OUT_FILE_AE = "out/AE_RESPONSE_RTL_In_crop_Indoor1_2592x1536_10bit_GRBG.bin";
localparam OUT_FILE_AE_SKEWNESS= "out/AE_SKEWNESS_RTL_In_crop_Indoor1_2592x1536_10bit_GRBG.bin";
localparam OUT_FILE_DG= "out/DGAIN_INDEX_RTL_In_crop_Indoor1_2592x1536_10bit_GRBG.bin";
    wire [15:0] ae, dg_index;
    assign dg_index = {12'd0,dgain_index_out};  // DGain 索引扩展为 16 位
    assign ae = {14'd0,ae_response_debug};      // AE 响应扩展为 16 位

// AE 响应写文件：在 ae_done 时写入
integer fd11, c11;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                fd11 = $fopen(OUT_FILE_AE, "wb");
            else if (ae_done)						// ae_done 时写入 AE 响应
                for (c11 = 0; c11 < 16/8; c11 = c11 + 1)
                    $fwrite(fd11, "%c", ae[(c11*8)+:8]);
            else if (out_vsync)
                $fflush(fd11);
        end

// AE 偏度写文件：在 ae_done 时写入        
integer fd_ae, c_ae;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                fd_ae = $fopen(OUT_FILE_AE_SKEWNESS, "wb");
            else if (ae_done)						// ae_done 时写入偏度值
                for (c_ae = 0; c_ae < 16/8; c_ae = c_ae + 1)
                    $fwrite(fd_ae, "%c", ae_result_skewness[(c_ae*8)+:8]);
            else if (out_vsync)
                $fflush(fd_ae);
        end

// DGain 索引写文件：在 ae_done 延迟一拍后写入（等待 DGain 更新完成）
integer f_dg, c_dg;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                f_dg = $fopen(OUT_FILE_DG, "wb");
            else if (ae_done_delay)					// ae_done 延迟一拍后写入
                for (c_dg = 0; c_dg < 16/8; c_dg = c_dg + 1)
                    $fwrite(f_dg, "%c", dg_index[(c_dg*8)+:8]);
            else if (out_vsync)
                $fflush(f_dg);
        end
  //****************************************************
  //********************** Stimulus ********************
initial begin
	// ---------------------------------------------------------------------------
	// ISP 运行时配置初始化
	// ---------------------------------------------------------------------------
	// rgb input enable
	rgb_inp_en = 0;
		
	// Enabling modules

	crop_en = CROP_EN;
	dpc_en = DPC_EN;
	blc_en = BLC_EN;
	linear_en = LINEAR_EN;
	oecf_en = OECF_EN;
	bnr_en = BNR_EN;
	dgain_en = DGAIN_EN;
	lsc_en = LSC_EN;
	demosic_en = DEMOSAIC_EN;
	wb_en = WB_EN; 
	ccm_en = CCM_EN;
	csc_en = CSC_EN;
	gamma_en = GAMMA_EN;
	ldci_en = LDCI_EN;
	nr2d_en = NR2D_EN;
	sharp_en = SHARP_EN;
	stat_ae_en = STAT_AE_EN;
	awb_en = AWB_EN;
	ae_en = AE_EN;
	// ---------------------------------------------------------------------------
	// ISP 各模块参数赋值（从 localparam 常量加载到运行时寄存器）
	// ---------------------------------------------------------------------------
	// DPC（坏点校正阈值）
	dpc_threshold = DPC_THRESHOLD;
	// BLC（黑电平校正与线性化）
	blc_r = BLC_R;
	blc_gr = BLC_GR;
	blc_gb = BLC_GB;
	blc_b = BLC_B;
	linear_r = LINEAR_R;
	linear_gr = LINEAR_GR;
	linear_gb = LINEAR_GB;
	linear_b = LINEAR_B;
	// OECF（光电转换 LUT 接口初始化：仅读模式）
	r_table_clk = 0; gr_table_clk = 0; gb_table_clk = 0; b_table_clk = 0;
	r_table_wen = 0; gr_table_wen = 0; gb_table_wen = 0; b_table_wen = 0;
	r_table_ren = 1; gr_table_ren = 1; gb_table_ren = 1; b_table_ren = 1;
	r_table_addr = 0; gr_table_addr = 0; gb_table_addr = 0; b_table_addr = 0;
	r_table_wdata = 0; gr_table_wdata =0; gb_table_wdata = 0; b_table_wdata = 0;
	// BNR（Bayer 域降噪：空间核与色彩曲线）
	bnr_space_kernel_r = BNR_SPACE_KERNEL_R;
	bnr_space_kernel_g = BNR_SPACE_KERNEL_G;
	bnr_space_kernel_b = BNR_SPACE_KERNEL_B;
	bnr_color_curve_x_r = BNR_COLOR_CURVE_X_R;
	bnr_color_curve_y_r = BNR_COLOR_CURVE_Y_R;
	bnr_color_curve_x_g = BNR_COLOR_CURVE_X_G;
	bnr_color_curve_y_g = BNR_COLOR_CURVE_Y_G;
	bnr_color_curve_x_b = BNR_COLOR_CURVE_X_B;
	bnr_color_curve_y_b = BNR_COLOR_CURVE_Y_B;
	// DG（数字增益：增益数组、手动/自动模式、手动索引）
	dgain_array = DGAIN_ARRAY;
	dgain_isManual = DGAIN_ISMANUAL;
	dgain_man_index = DGAIN_MAN_INDEX;
	// WB（白平衡 R/B 增益）
	wb_rgain = WB_RGAIN;
	wb_bgain = WB_BGAIN;
	// CCM（色彩校正矩阵 3x3）
	ccm_rr = CCM_RR; ccm_rg = CCM_RG; ccm_rb = CCM_RB;
	ccm_gr = CCM_GR; ccm_gg = CCM_GG; ccm_gb = CCM_GB;
	ccm_br = CCM_BR; ccm_bg = CCM_BG; ccm_bb = CCM_BB;
	// GAMMA（Gamma LUT 接口初始化：仅读模式）
	gamma_table_r_clk = 0; gamma_table_g_clk = 0; gamma_table_b_clk = 0;
	gamma_table_r_wen = 0; gamma_table_g_wen = 0; gamma_table_b_wen = 0;
	gamma_table_r_ren = 1; gamma_table_g_ren = 1; gamma_table_b_ren = 1;
	gamma_table_r_addr = 0; gamma_table_r_addr = 0; gamma_table_r_addr = 0;
	gamma_table_r_wdata = 0; gamma_table_r_wdata = 0; gamma_table_r_wdata = 0;

	// CSC（色彩空间转换标准）
	in_conv_standard = CSC_CONV_STD;
	// SHARP（锐化卷积核与强度）
	luma_kernel = LUMA_KERNEL;
	sharpen_strength = SHARPEN_STRENGTH;
	// 2DNR（2D 降噪 LUT）
	nr2d_diff = NR2D_DIFF;
	nr2d_weight = NR2D_WEIGHT;
	// AE（自动曝光：目标亮度、偏度、裁剪边界）
	center_illuminance = CENTRE_ILLUMINANCE;
	skewness = SKEWNESS;
	ae_crop_left = AE_CROP_LEFT;
	ae_crop_right = AE_CROP_RIGHT;
	ae_crop_top = AE_CROP_TOP;
	ae_crop_bottom = AE_CROP_BOTTOM;
	// AWB（自动白平衡：曝光限制与帧数）
	awb_underexposed_limit = AWB_UNDEREXPOSED_LIMIT;
    awb_overexposed_limit = AWB_OVEREXPOSED_LIMIT;
    awb_frames = AWB_FRAMES;
	// STAT_AWB（AWB 直方图统计接口初始化）
	stat_awb_hist_clk = 0;
	stat_awb_hist_out = 0;
	stat_awb_hist_addr = 0;

	// ---------------------------------------------------------------------------
	// 复位与时钟初始化
	// ---------------------------------------------------------------------------
	rst_n = 0;
	pclk = 0;
	#20               // 20ns 后释放复位
	rst_n = 1;
	// commented out to enable post-frame processing while VSYNC is high, as in AE, AWB
	#83000000
	$finish;
end

// ---------------------------------------------------------------------------
// FSDB 波形 dump（用于 Verdi 查看）
// ---------------------------------------------------------------------------
initial begin
	$fsdbDumpfile("tb_seq_top.fsdb");
	$fsdbDumpvars(0, tb_seq_top);
	$fsdbDumpMDA();  // dump 多维数组
end
      
initial begin
	// ---------------------------------------------------------------------------
	// VIP1/VIP2 运行时配置初始化
	// ---------------------------------------------------------------------------
    // VIP1 使能信号
    vip1_hist_equ_en = VIP1_HIST_EQU_EN;
    vip1_sobel_en = VIP1_SOBEL_EN;
    vip1_rgbc_en = VIP1_RGBC_EN;
    vip1_irc_en =  VIP1_IRC_EN;
    vip1_dscale_en = VIP1_SCALE_EN;
    vip1_osd_en = VIP1_OSD_EN;
    vip1_yuv444to422_en = VIP1_YUVConvFormat_EN;
    
    // VIP1 参数赋值
    // Hist Equ（直方图均衡范围）
    vip1_equ_min = VIP1_EQU_MIN;
    vip1_equ_max = VIP1_EQU_MAX;   
    // YUV-RGB（色彩空间转换标准）
    vip1_in_conv_standard = VIP1_IN_CONV_STANDARD;    
    // IRC（裁剪起始坐标与输出模式）
    vip1_crop_x = VIP1_CROP_X;
    vip1_crop_y = VIP1_CROP_Y;
    vip1_irc_output = VIP1_IRC_OUTPUT;    
    // Scale（缩放参数）
    vip1_s_in_crop_w = VIP1_S_IN_CROP_W;
    vip1_s_in_crop_h = VIP1_S_IN_CROP_H;
    vip1_s_out_crop_w = VIP1_S_OUT_CROP_W;
    vip1_s_out_crop_h = VIP1_S_OUT_CROP_H;
    vip1_dscale_w = VIP1_SCALE_W;
    vip1_dscale_h = VIP1_SCALE_H;    
    // OSD（字幕叠加参数）
    vip1_osd_x = VIP1_OSD_X;
    vip1_osd_y = VIP1_OSD_Y;
    vip1_osd_w = VIP1_OSD_W;
    vip1_osd_h = VIP1_OSD_H;
    vip1_osd_color_fg = VIP1_OSD_COLOR_FG;
    vip1_osd_color_bg = VIP1_OSD_COLOR_BG;
	vip1_osd_alpha = VIP1_OSD_ALPHA;
    vip1_osd_ram_clk = 0;
	vip1_osd_ram_wen = 0; 
	vip1_osd_ram_ren = 0;
	vip1_osd_ram_addr = 0;
	// YUV（YUV 格式转换）
    vip1_YUV444TO422 = VIP1_YUV444TO422_Value;
    
    // VIP2 使能信号
    vip2_hist_equ_en = VIP2_HIST_EQU_EN;
    vip2_sobel_en = VIP2_SOBEL_EN;
    vip2_rgbc_en = VIP2_RGBC_EN;
    vip2_irc_en =  VIP2_IRC_EN;
    vip2_dscale_en = VIP2_SCALE_EN;
    vip2_osd_en = VIP2_OSD_EN;
    vip2_yuv444to422_en = VIP2_YUVConvFormat_EN;
       
    // VIP2 参数赋值
    // Hist Equ（直方图均衡范围）
    vip2_equ_min = VIP2_EQU_MIN;
    vip2_equ_max = VIP2_EQU_MAX;   
    // YUV-RGB（色彩空间转换标准）
    vip2_in_conv_standard = VIP2_IN_CONV_STANDARD;    
    // IRC（裁剪起始坐标与输出模式）
    vip2_crop_x = VIP2_CROP_X;
    vip2_crop_y = VIP2_CROP_Y;
    vip2_irc_output = VIP2_IRC_OUTPUT;    
    // Scale（缩放参数）
    vip2_s_in_crop_w = VIP2_S_IN_CROP_W;
    vip2_s_in_crop_h = VIP2_S_IN_CROP_H;
    vip2_s_out_crop_w = VIP2_S_OUT_CROP_W;
    vip2_s_out_crop_h = VIP2_S_OUT_CROP_H;
    vip2_dscale_w = VIP2_SCALE_W;
    vip2_dscale_h = VIP2_SCALE_H;    
    // OSD（字幕叠加参数）
    vip2_osd_x = VIP2_OSD_X;
    vip2_osd_y = VIP2_OSD_Y;
    vip2_osd_w = VIP2_OSD_W;
    vip2_osd_h = VIP2_OSD_H;
    vip2_osd_color_fg = VIP2_OSD_COLOR_FG;
    vip2_osd_color_bg = VIP2_OSD_COLOR_BG;
	vip2_osd_alpha = VIP2_OSD_ALPHA;
    vip2_osd_ram_clk = 0;
	vip2_osd_ram_wen = 0; 
	vip2_osd_ram_ren = 0;
	vip2_osd_ram_addr = 0;
	// YUV（YUV 格式转换）
    vip2_YUV444TO422 = VIP2_YUV444TO422_Value;
	
end

// ---------------------------------------------------------------------------
// OSD RAM 时钟与地址自增逻辑
// ---------------------------------------------------------------------------
// 用于在仿真开始时自动向 OSD RAM 写入 LUT 数据
always #2 		vip1_osd_ram_clk	<= ~vip1_osd_ram_clk;  // 4ns 周期 OSD RAM 时钟
always #4 		vip1_osd_ram_addr	<= vip1_osd_ram_wen ? vip1_osd_ram_addr + 1'b1 : vip1_osd_ram_addr;
always #2 		vip2_osd_ram_clk	<= ~vip2_osd_ram_clk;
always #4 		vip2_osd_ram_addr	<= vip2_osd_ram_wen ? vip2_osd_ram_addr + 1'b1 : vip2_osd_ram_addr;

initial begin
	// VIP1 OSD RAM：仿真开始后写入一段 LUT 数据
	#200		vip1_osd_ram_wen 	<= 1;
	#(8*128)	vip1_osd_ram_wen 	<= 0;
end

initial begin
	// VIP2 OSD RAM：仿真开始后写入一段 LUT 数据
	#200		vip2_osd_ram_wen 	<= 1;
	#(8*128)	vip2_osd_ram_wen 	<= 0;
end
      
// ********************* Clock generation*************
	// ---------------------------------------------------------------------------
	// 时钟产生
	// ---------------------------------------------------------------------------
	// pclk：20ns 周期（50MHz）
	// 同时也把 OECF 表时钟与像素时钟同步翻转
always #10 begin
pclk = ~pclk;	
r_table_clk = ~r_table_clk;
gr_table_clk = ~gr_table_clk;
gb_table_clk = ~gb_table_clk; 
b_table_clk = ~b_table_clk;
end

// ---------------------------------------------------------------------------
// 仿真进度显示
// ---------------------------------------------------------------------------
// 每隔一定时间打印仿真进度，便于观察仿真状态
localparam TOTAL_PIXELS = SNS_WIDTH * SNS_HEIGHT;
localparam FRAME_TIME_NS = TOTAL_PIXELS * 20; // 每帧时间（ns），50MHz时钟

reg [63:0] pixel_count;
reg [31:0] line_count;
reg [31:0] frame_count;
real progress_percent;

initial begin
    pixel_count = 0;
    line_count = 0;
    frame_count = 0;
    $display("============================================");
    $display("  Infinite-ISP RTL Simulation Started");
    $display("  Image: %0d x %0d pixels", SNS_WIDTH, SNS_HEIGHT);
    $display("  Total pixels per frame: %0d", TOTAL_PIXELS);
    $display("  Estimated frame time: %0d ms", FRAME_TIME_NS/1000000);
    $display("============================================");
end

// 像素和行计数
always @(posedge pclk) begin
    if (dvp_href_out) begin
        pixel_count <= pixel_count + 1;
    end
end

// 行计数（href下降沿）
reg href_d;
always @(posedge pclk) begin
    href_d <= dvp_href_out;
    if (href_d && !dvp_href_out) begin
        line_count <= line_count + 1;
    end
end

// 帧计数（vsync上升沿）
reg vsync_d;
always @(posedge pclk) begin
    vsync_d <= dvp_vsync_out;
    if (!vsync_d && dvp_vsync_out) begin
        frame_count <= frame_count + 1;
        $display("[%0t] Frame %0d completed, Total lines: %0d", $time, frame_count, line_count);
    end
end

// 每1ms打印一次进度
always begin
    #1000000; // 1ms
    if (TOTAL_PIXELS > 0) begin
        progress_percent = (pixel_count * 100.0) / (TOTAL_PIXELS * NUM_SEQ_FRAMES);
        if (progress_percent > 100.0) progress_percent = 100.0;
        $display("[%0t] Progress: %0.1f%% | Pixels: %0d | Lines: %0d | Frames: %0d", 
                 $time, progress_percent, pixel_count, line_count, frame_count);
    end
end

endmodule

module osd_lut
#(
	parameter INDEX_BITS = 8,
	parameter DATA_BITS = 32
)
(
	input [INDEX_BITS-1:0] index,
	output [DATA_BITS-1:0] value
);
	// -------------------------------------------------------------------------
	// LUT 说明
	// -------------------------------------------------------------------------
	// 该 LUT 用 case 语句描述一个“只读 ROM”，用于给 VIP1/VIP2 的 OSD RAM 写口提供测试数据。
	reg [DATA_BITS-1:0] v;
	assign value = v;
	
	always @ (*) begin
		case (index)
			0:   v = 32'h0;
			1:   v = 32'h0;
			2:   v = 32'h0;
			3:   v = 32'hc;
			4:   v = 32'h0;
			5:   v = 32'h0;
			6:   v = 32'h0;
			7:   v = 32'h18;
			8:   v = 32'h0;
			9:   v = 32'h1fe;
			10:  v = 32'h0;
			11:  v = 32'h70;
			12:  v = 32'h0;
			13:  v = 32'h3fe;
			14:  v = 32'h0;
			15:  v = 32'he0;
			16:  v = 32'h1f;
			17:  v = 32'hfc0003fe;
			18:  v = 32'h0;
			19:  v = 32'h3c0;
			20:  v = 32'hff;
			21:  v = 32'hfc0007ff;
			22:  v = 32'h0;
			23:  v = 32'h7c0;
			24:  v = 32'h3ff;
			25:  v = 32'hfc003fff;
			26:  v = 32'he0000000;
			27:  v = 32'h1f80;
			28:  v = 32'hfff;
			29:  v = 32'hfc01ffff;
			30:  v = 32'hfc700000;
			31:  v = 32'h3f00;
			32:  v = 32'h7fff;
			33:  v = 32'hf8e7ffff;
			34:  v = 32'hfffc0000;
			35:  v = 32'h7e00;
			36:  v = 32'h1ffff;
			37:  v = 32'hf8fff800;
			38:  v = 32'hfffe0000;
			39:  v = 32'hfc00;
			40:  v = 32'h7ffff;
			41:  v = 32'hf87fc000;
			42:  v = 32'h1fff0000;
			43:  v = 32'h1f800;
			44:  v = 32'h1fffff;
			45:  v = 32'hf8ff0000;
			46:  v = 32'h7ff0000;
			47:  v = 32'h3f800;
			48:  v = 32'h1fffff;
			49:  v = 32'hf87c1fff;
			50:  v = 32'h81fe0000;
			51:  v = 32'h7f000;
			52:  v = 32'h1fffff;
			53:  v = 32'hf0387fff;
			54:  v = 32'he0fe0000;
			55:  v = 32'hfe000;
			56:  v = 32'h1fffff;
			57:  v = 32'hf001ffff;
			58:  v = 32'hf87e0000;
			59:  v = 32'h1fc000;
			60:  v = 32'h3ffcff;
			61:  v = 32'hf007ffff;
			62:  v = 32'hfe3e0000;
			63:  v = 32'h3f8000;
			64:  v = 32'h3fe0ff;
			65:  v = 32'hf00fffff;
			66:  v = 32'hff1f0000;
			67:  v = 32'h3f0000;
			68:  v = 32'h3f81ff;
			69:  v = 32'hf01fffff;
			70:  v = 32'hff9f00f0;
			71:  v = 32'h67e0000;
			72:  v = 32'h3c01ff;
			73:  v = 32'he03fffff;
			74:  v = 32'hff8f87fc;
			75:  v = 32'hcfc0000;
			76:  v = 32'h3001ff;
			77:  v = 32'he07fffff;
			78:  v = 32'hffcf87ff;
			79:  v = 32'hb9fc0000;
			80:  v = 32'h1ff;
			81:  v = 32'he0fffc07;
			82:  v = 32'hffe7c1ff;
			83:  v = 32'hf3f80000;
			84:  v = 32'h1ff;
			85:  v = 32'he1fff001;
			86:  v = 32'hffe7f87f;
			87:  v = 32'hf7f00000;
			88:  v = 32'h1ff;
			89:  v = 32'hc1ffe000;
			90:  v = 32'hffe7fc1f;
			91:  v = 32'he7e00000;
			92:  v = 32'h3ff;
			93:  v = 32'hc3ffc000;
			94:  v = 32'hffe3fc0f;
			95:  v = 32'hcfc00000;
			96:  v = 32'h3ff;
			97:  v = 32'hc3ff8000;
			98:  v = 32'h7fe3fc1f;
			99:  v = 32'h9fc00000;
			100: v = 32'h3ff;
			101: v = 32'hc3ff8000;
			102: v = 32'h7fe3fc3f;
			103: v = 32'h3f800000;
			104: v = 32'h3ff;
			105: v = 32'hc3ff0000;
			106: v = 32'h7fe3fc7e;
			107: v = 32'h7f000000;
			108: v = 32'h3ff;
			109: v = 32'h83ff0000;
			110: v = 32'hffe7fcfc;
			111: v = 32'hfe000000;
			112: v = 32'h7ff;
			113: v = 32'h83ff0000;
			114: v = 32'hffe7f0fd;
			115: v = 32'hfc000000;
			116: v = 32'h7ff;
			117: v = 32'h87ff0000;
			118: v = 32'hffe7c1f9;
			119: v = 32'hfe000000;
			120: v = 32'h7ff;
			121: v = 32'h83ff0001;
			122: v = 32'hffe783f3;
			123: v = 32'hff000000;
			124: v = 32'h7ff;
			125: v = 32'h83ff8003;
			126: v = 32'hffcf87e7;
			127: v = 32'hff000000;
			128: v = 32'hfff;
			129: v = 32'h3ff8007;
			130: v = 32'hffcf0fcf;
			131: v = 32'hff800000;
			132: v = 32'hfff;
			133: v = 32'h3ffe00f;
			134: v = 32'hff9f1f9f;
			135: v = 32'hffc00000;
			136: v = 32'hfff;
			137: v = 32'h1fff87f;
			138: v = 32'hff0e1f3f;
			139: v = 32'hffc00000;
			140: v = 32'hfff;
			141: v = 32'h1ffffff;
			142: v = 32'hff043f71;
			143: v = 32'hffe00000;
			144: v = 32'hfff;
			145: v = 32'hffffff;
			146: v = 32'hfc007e41;
			147: v = 32'hfff00000;
			148: v = 32'h1ffe;
			149: v = 32'h7fffff;
			150: v = 32'hf800fc00;
			151: v = 32'hfff00000;
			152: v = 32'h1ffe;
			153: v = 32'h3fffff;
			154: v = 32'hf001f800;
			155: v = 32'h7ff80000;
			156: v = 32'h1ffe;
			157: v = 32'h1fffff;
			158: v = 32'he003f000;
			159: v = 32'h3ffc0000;
			160: v = 32'h1ffe;
			161: v = 32'hfffff;
			162: v = 32'h8007e000;
			163: v = 32'h3ffe0000;
			164: v = 32'h1ffe;
			165: v = 32'h1fffe;
			166: v = 32'h7c000;
			167: v = 32'h1ffe0000;
			168: v = 32'h0;
			169: v = 32'h1fe0;
			170: v = 32'h0;
			171: v = 32'h0;
			172: v = 32'h0;
			173: v = 32'h0;
			174: v = 32'h0;
			175: v = 32'h0;
			176: v = 32'h0;
			177: v = 32'h0;
			178: v = 32'h0;
			179: v = 32'h0;
			180: v = 32'h0;
			181: v = 32'h0;
			182: v = 32'h0;
			183: v = 32'h0;
			184: v = 32'h1188;
			185: v = 32'h4030042;
			186: v = 32'h1038501;
			187: v = 32'h1c0000;
			188: v = 32'h3f9e;
			189: v = 32'he1fe0e7;
			190: v = 32'h79feff3;
			191: v = 32'hf87f0000;
			192: v = 32'h7f9e;
			193: v = 32'he3ff1ef;
			194: v = 32'h87bfcff7;
			195: v = 32'hfcff0000;
			196: v = 32'h701f;
			197: v = 32'he7879cf;
			198: v = 32'hc7380e07;
			199: v = 32'h3ce20000;
			200: v = 32'h701f;
			201: v = 32'h9ef011cf;
			202: v = 32'hc7381e07;
			203: v = 32'h1ce00000;
			204: v = 32'h7f3f;
			205: v = 32'h9ce001cf;
			206: v = 32'he73f9fc7;
			207: v = 32'h3cf00000;
			208: v = 32'h7f39;
			209: v = 32'hdde1f9ce;
			210: v = 32'he73f9fe7;
			211: v = 32'hfc7c0000;
			212: v = 32'h7f39;
			213: v = 32'hdde1f9ce;
			214: v = 32'h7f3f9fc7;
			215: v = 32'hf83e0000;
			216: v = 32'hf038;
			217: v = 32'hfce1fbde;
			218: v = 32'h7e781c0f;
			219: v = 32'he00f0000;
			220: v = 32'he038;
			221: v = 32'hfcf07b9e;
			222: v = 32'h3e703c0e;
			223: v = 32'hf0070000;
			224: v = 32'hfe78;
			225: v = 32'h7c7ff39c;
			226: v = 32'h3e7f3f8e;
			227: v = 32'h71ff0000;
			228: v = 32'hff70;
			229: v = 32'h787fe39c;
			230: v = 32'h1e7fbfce;
			231: v = 32'h39fe0000;
			232: v = 32'hfe70;
			233: v = 32'h381f839c;
			234: v = 32'hc7f3fce;
			235: v = 32'h38f80000;
			236: v = 32'h0;
			237: v = 32'h0;
			238: v = 32'h0;
			239: v = 32'h0;
			240: v = 32'h0;
			241: v = 32'h0;
			242: v = 32'h0;
			243: v = 32'h0;
			244: v = 32'h0;
			245: v = 32'h0;
			246: v = 32'h0;
			247: v = 32'h0;
			248: v = 32'h0;
			249: v = 32'h0;
			250: v = 32'h00000000;
			251: v = 32'h00000000;
			252: v = 32'h00000000;
			253: v = 32'h00000000;
			254: v = 32'h00000000;
			255: v = 32'h00000000;
			default: v = 32'h00000000;
		endcase
	end
endmodule
