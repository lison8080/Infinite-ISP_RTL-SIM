/*************************************************************************
> File Name: tb_vip_top.v
> Description: Test bench for vip top
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps


module tb_vip_top;

// -----------------------------------------------------------------------------
// 功能说明
// -----------------------------------------------------------------------------
// 本 testbench 用于验证 `vip_top`（VIP 顶层视频处理流水线）的功能正确性。
//
// 核心流程：
// 1) 使用 `tb_file_to_dvp` 从二进制文件读取图像数据并生成 DVP 风格输入流：
//      - `dvp_clk_out`  : 像素时钟
//      - `dvp_href_out` : 行有效
//      - `dvp_vsync_out`: 帧同步
// 2) 将输入流送入 `vip_top`，并通过运行时使能信号控制各子模块旁路/使能。
// 3) 使用 `tb_dvp_to_file` 把 `vip_top` 的 3 通道输出打包写回文件，便于离线对比。
//
// 注意：本文件同时存在两类“开关”：
// - 编译时 `define USE_*`：决定 RTL 中是否实例化某个模块（综合/仿真结构级开关）。
// - 运行时 `*_EN`         ：决定该模块在运行时是否处理数据或旁路（数据通路级开关）。
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 输入/输出文件
// -----------------------------------------------------------------------------
// 该 testbench 使用 3 个输入文件分别驱动 3 路并行像素通道（这里以 Y/U/V 命名）。
// 具体哪路代表 Y/U/V 或 R/G/B 完全取决于 `vip_top` 的接口语义与 testbench 的连线。
// 当前注释标注：
// - IN_FILE_B 作为 Y
// - IN_FILE_G 作为 U
// - IN_FILE_R 作为 V
//
// 文件格式：二进制 RAW 数据，按像素顺序存放，每像素占 BITS_FILE/8 字节。
// File names 
localparam IN_FILE_R = "R_In_scale_Indoor1_2592x1536_10bit_GRBG_0.bin"; // V
localparam IN_FILE_G = "G_In_scale_Indoor1_2592x1536_10bit_GRBG_0.bin"; // U
localparam IN_FILE_B = "B_In_scale_Indoor1_2592x1536_10bit_GRBG_0.bin"; // Y
localparam OUT_FILE = "RTL_In_scale_Indoor1_2592x1536_10bit_GRBG_0.bin";

// VIP top module parameters
localparam BITS_FILE = 16;
localparam BITS = 8;
localparam WIDTH = 2592;
localparam HEIGHT = 1536;


// -----------------------------------------------------------------------------
// VIP 子模块实例化开关（编译时）
// -----------------------------------------------------------------------------
// 说明：`define USE_*` 在综合/编译阶段决定是否实例化对应子模块。
// 若某子模块未被实例化，即使运行时 `*_EN` 拉高也不会生效。
// Instantiation of VIP blocks
`define USE_HIST_EQU 	    0
`define USE_SOBEL   	    0
`define USE_RGBC     	    1
`define USE_IRC   		    1
`define USE_OSD			    1
`define USE_SCALE   	    1
`define USE_YUVConvFormat   1
// -----------------------------------------------------------------------------
// VIP 子模块运行时使能（可动态配置）
// -----------------------------------------------------------------------------
// 说明：这些 `*_EN` 在仿真运行时控制数据是否经过对应模块处理。
// 典型实现方式是：EN=0 时旁路输入到输出，EN=1 时启用该模块运算。
// Enability of VIP blocks 
localparam HIST_EQU_EN = 0;
localparam SOBEL_EN = 0;
localparam RGBC_EN = 0;
localparam IRC_EN = 0;
localparam OSD_EN = 0;
localparam SCALE_EN = 0;
localparam YUVConvFormat_EN = 1;
// Tunable parameters of VIP
// HIST EQU
localparam EQU_MIN = 0;
localparam EQU_MAX = 255;
// YUV-RGB
localparam IN_CONV_STANDARD = 2;
// IRC
localparam IRC_OUTPUT = 1;  // 1 = 1920*1080, 2 = 1920*1440 else 1920*1080
localparam CROP_X = 40;	// row no. = [0 INPUT_WIDTH]
localparam CROP_Y = 40;	// column no. = [0 INPUT_HEIGHT]
// SCALE
// stage-1: downscale factor
localparam SCALE_W = 1;
localparam SCALE_H = 1;
// stage-2: internal crop parameters
localparam S_IN_CROP_W = 640;
localparam S_IN_CROP_H = 360;
localparam S_OUT_CROP_W = 640;
localparam S_OUT_CROP_H = 360;
// OSD
localparam OSD_X = 50;
localparam OSD_Y = 50;
localparam OSD_W = 128;
localparam OSD_H = 64;
localparam OSD_COLOR_FG = 24'h05aa0; //24'h00A05A (10x logo Blue color)  rbg format
localparam OSD_COLOR_BG = 24'hffffff; // 24'hFFFFFF (White Background)
localparam ALPHA = 50;
localparam OSD_RAM_ADDR_BITS = 9;
localparam OSD_RAM_DATA_BITS = 32;
// YUV444TO422
localparam YUV444TO422_Value = 1; // 0 = Output as 444, 1 = Output as 422

    //****************************************************
	//********************** File2DVP *********************
    // -------------------------------------------------------------------------
    // File2DVP：将文件内容转换为 DVP 输入时序
    // -------------------------------------------------------------------------
    // 说明：
    // - 第一路 `tb_file_to_dvp` 负责输出 pclk/href/vsync（其它两路只需要 data）。
    // - 三路 `data` 在同一时钟域下对齐，用于模拟并行三通道视频输入。
    // pclk and reset generation
	reg rst_n;
	reg pclk;
	wire dvp_clk_out,dvp_href_out,dvp_vsync_out;
	wire [BITS_FILE-1:0] dvp_out_y;
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_R,
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_r(
		.xclk(pclk), .rst_n(rst_n), .pclk(dvp_clk_out), .href(dvp_href_out), .hsync(),	.vsync(dvp_vsync_out),
		.data(dvp_out_y)
	);
	
	wire [BITS_FILE-1:0] dvp_out_u;
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_G,
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_u(
		.xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_u)
	);
	
	wire [BITS_FILE-1:0] dvp_out_v;
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_B,
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_v(
		.xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_v)
	);
    wire in_href, in_vsync;
    wire [BITS-1:0] in_y, in_u, in_v;
    assign in_href = dvp_href_out;
    assign in_vsync = dvp_vsync_out;
    assign in_y = dvp_out_y[BITS-1:0];
    assign in_u = dvp_out_u[BITS-1:0];
    assign in_v = dvp_out_v[BITS-1:0];
    
    //****************************************************
    //********************** ISP *************************
    //********************** Inputs **********************
    // Module Enables
    reg hist_equ_en, sobel_en, yuv2rgb_en, crop_en, dscale_en, osd_en, yuv444to422_en;
    // Hist Equ
    reg [BITS-1:0] equ_min, equ_max;
    //YUV-RGB
    reg [1:0] in_conv_standard;
    // Crop
    reg [15:0] crop_x, crop_y;
    reg [1:0] irc_output;
    // SCALE
    reg [11:0] s_in_crop_w;
    reg [11:0] s_in_crop_h;
	reg [11:0] s_out_crop_w;
	reg [11:0] s_out_crop_h;
	reg [2:0] dscale_w;
	reg [2:0] dscale_h;
    //YUV
    reg YUV444TO422;
	// OSD
	reg [15:0] osd_x, osd_y, osd_w, osd_h; 
	reg [23:0] osd_color_fg, osd_color_bg ; // 10 bits for each color 
	reg [7:0] alpha;
	// OSD RAM
	reg                          osd_ram_clk;
	reg                          osd_ram_wen;
	reg                          osd_ram_ren;
	reg  [OSD_RAM_ADDR_BITS-1:0] osd_ram_addr;
	wire  [OSD_RAM_DATA_BITS-1:0] osd_ram_wdata;
	 
    // Outputs
    wire  [OSD_RAM_DATA_BITS-1:0] osd_ram_rdata;
    
    wire out_pclk;
    wire out_href;
	wire out_vsync;
	wire [BITS-1:0] out_g;
	wire [BITS-1:0] out_b;
	wire [BITS-1:0] out_r;
	
	//Clock Divider Instantiation
	// -------------------------------------------------------------------------
	// 缩放模块（SCALE）时钟分频
	// -------------------------------------------------------------------------
	// `vip_top` 中的缩放可能需要更低速的处理时钟，这里使用 `Clock_divider` 产生 `scale_clk`。
	// 分频系数使用 `SCALE_W`（通常与水平缩放因子相关）。
	
	wire scale_clk;
	Clock_divider 
    #(
         SCALE_W
    )
    clk_divider ( pclk, scale_clk);
    
    osd_lut #(OSD_RAM_ADDR_BITS,OSD_RAM_DATA_BITS) lut0(osd_ram_addr, osd_ram_wdata);
	
	// -------------------------------------------------------------------------
	// VIP 顶层实例化
	// -------------------------------------------------------------------------
	// 输入：DVP 风格 `href/vsync` + 三通道 `in_y/in_u/in_v`
	// 输出：三通道 `out_r/out_g/out_b`（具体含义由模块定义决定）
	// 另：OSD 通过独立的 RAM 端口写入 OSD 图案数据。
	
	// VIP Module Instantiation
	vip_top	#(
	  /*BITS 					*/  BITS,
	  /*WIDTH 					*/  WIDTH,
	  /*HEIGHT 					*/  HEIGHT,
      /*OSD_RAM_ADDR_BITS       */  OSD_RAM_ADDR_BITS,
	  /*OSD_RAM_DATA_BITS       */  OSD_RAM_DATA_BITS,
	  /*USE_HIST_EQU			*/  `USE_HIST_EQU,
	  /*USE_SOBEL				*/	`USE_SOBEL,
	  /*USE_YUV2RGB				*/	`USE_RGBC,	  
	  /*USE_CROP				*/  `USE_IRC,
	  /*USE_DSCALE    			*/  `USE_SCALE,
	  /*USE_OSD					*/	`USE_OSD,					
	  /*USE_YUV444TO422			*/  `USE_YUVConvFormat
	  )
	  vip_top_i0(
		// Clock and rest
		.pclk(dvp_clk_out),
		.scale_pclk(scale_clk), 
		.rst_n(rst_n),
		// Input 
		.in_href( in_href ), .in_vsync(in_vsync), .in_y(in_y), .in_u(in_u), .in_v(in_v),
		// Output
		.out_pclk(out_pclk), .out_href(out_href), .out_vsync(out_vsync), .out_r(out_r), .out_g(out_g), .out_b(out_b), 
		// Module Enables
		.hist_equ_en(hist_equ_en), .sobel_en(sobel_en), .yuv2rgb_en(yuv2rgb_en), .irc_en(crop_en), .dscale_en(dscale_en), .osd_en(osd_en), .yuv444to422_en(yuv444to422_en),
		// Hist_equ
		.equ_min(equ_min), .equ_max(equ_max),
		//YUV-RGB
		.in_conv_standard(in_conv_standard),
		// Crop
		.crop_x(crop_x), .crop_y(crop_y),
		.irc_output(irc_output),
		//scale
		.s_in_crop_w(s_in_crop_w),
		.s_in_crop_h(s_in_crop_h),
		.s_out_crop_w(s_out_crop_w),
		.s_out_crop_h(s_out_crop_h),
		.dscale_w(dscale_w),
		.dscale_h(dscale_h),
		//YUV
		.YUV444TO422(YUV444TO422),
		// OSD 						 
		.osd_x(osd_x), .osd_y(osd_y), .osd_w(osd_w), .osd_h(osd_h),
		.fg_color(osd_color_fg), .bg_color(osd_color_bg), .alpha(alpha),
		.osd_ram_clk(osd_ram_clk), .osd_ram_wen(osd_ram_wen), .osd_ram_ren(osd_ram_ren), .osd_ram_addr(osd_ram_addr), .osd_ram_wdata(osd_ram_wdata), .osd_ram_rdata(osd_ram_rdata)
		);

	// -------------------------------------------------------------------------
	// 输出写文件
	// -------------------------------------------------------------------------
	// `tb_dvp_to_file` 会在 `href==1` 时将 `data` 逐字节写入 `OUT_FILE`。
	// 此处把三通道数据按 16bit 对齐打包：{B,G,R}，每通道高 8bit 补 0。
tb_dvp_to_file
	#(
		/*FILE 		*/ OUT_FILE,
		/*BITS 		*/	BITS_FILE*3  // 3 x BITS  for three channels       
	 )
	dvp2file
	(
		.pclk(out_pclk), 
		.rst_n(rst_n),
		.href(out_href),
		.vsync(out_vsync),
		.data({{8'd0,out_b}, {8'd0,out_g}, {8'd0,out_r}})
	);


initial begin
	// -------------------------------------------------------------------------
	// 运行时参数/使能初始化
	// -------------------------------------------------------------------------
    // enable signals
    hist_equ_en = HIST_EQU_EN;
    sobel_en = SOBEL_EN;
    yuv2rgb_en = RGBC_EN;
    crop_en =  IRC_EN;
    dscale_en = SCALE_EN;
    osd_en = OSD_EN ;
    yuv444to422_en = YUVConvFormat_EN;
    
    // Parameter values
    // Hist Equ
    equ_min = EQU_MIN;
    equ_max = EQU_MAX;
    //YUV-RGB
    in_conv_standard = IN_CONV_STANDARD;
    // Crop
    crop_x = CROP_X;
    crop_y = CROP_Y;
    irc_output = IRC_OUTPUT;
    
    //Scale
    s_in_crop_w = S_IN_CROP_W;
    s_in_crop_h = S_IN_CROP_H;
    s_out_crop_w = S_OUT_CROP_W;
    s_out_crop_h = S_OUT_CROP_H;
    dscale_w = SCALE_W;
    dscale_h = SCALE_H;
    
    //YUV 
    YUV444TO422 = YUV444TO422_Value;
    // OSD
    osd_ram_clk = 0;
	osd_ram_wen = 0; 
	osd_ram_ren = 0;
	osd_ram_addr = 0;
//	osd_ram_wdata = 0;
    osd_x = OSD_X;
    osd_y = OSD_Y;
    osd_w = OSD_W;
    osd_h = OSD_H;
    osd_color_fg = OSD_COLOR_FG;
    osd_color_bg = OSD_COLOR_BG;
    alpha = ALPHA;
    
	// Reset and clock generation
	// 复位：低有效，保持 20ns 后释放
	rst_n = 0;
	pclk = 0;
	#20
	rst_n = 1;
	end
	
always #2 osd_ram_clk  <= ~osd_ram_clk;
always #4 osd_ram_addr <= osd_ram_wen ? osd_ram_addr + 1'b1 : osd_ram_addr;
initial begin
	// -------------------------------------------------------------------------
	// OSD RAM 写入时序
	// -------------------------------------------------------------------------
	// 通过 `osd_ram_wen` 在仿真开始后短暂拉高，模拟把 OSD 图案写入 RAM。
	// 写入数据 `osd_ram_wdata` 由 `osd_lut` 根据地址产生。
	#200      osd_ram_wen <= 1;
	#(8*128) osd_ram_wen <= 0;
end

always #10 begin
pclk = ~pclk;
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
	// 该 LUT 用 case 语句描述一个“只读 ROM”，用于给 OSD RAM 写口提供测试数据。
	// 具体每一位如何映射为 OSD 图案像素，由 `vip_top` 内部的 OSD 模块定义。
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