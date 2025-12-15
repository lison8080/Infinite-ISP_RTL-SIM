/*************************************************************************
> File Name: tb_OSD.v
> Description: Test bench for on screen display
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

module tb_osd();

    // -------------------------------------------------------------------------
    // 功能说明
    // -------------------------------------------------------------------------
    // 本 testbench 用于验证 `vip_osd`（On-Screen Display 叠加显示）模块。
    //
    // 测试流程：
    // 1) 通过 `tb_file_to_dvp` 从输入二进制文件读取像素数据，生成 DVP 风格输入流：
    //      - `dvp_clk_out`  : 像素时钟
    //      - `dvp_href_out` : 行有效
    //      - `dvp_vsync_out`: 帧同步
    // 2) 向 `vip_osd` 提供 OSD 配置（位置/大小/颜色/透明度）以及 OSD RAM 内容。
    // 3) 将 `vip_osd` 输出的 3 通道数据打包后写入输出文件，用于离线观察或与参考结果对比。
    //
    // 说明：本文件中把 3 路输入/输出通道复用为 Y/U/V 或 R/G/B 都可以；
    //       对 `vip_osd` 而言仅是 3 路并行像素通道，testbench 通过连线决定其语义。
    // -------------------------------------------------------------------------

	reg xclk = 0;
	// 产生输入像素时钟：10ns 周期（#5 翻转）
	always #5 xclk <= ~xclk;
	
	reg rst_n = 0;
	// 复位：低有效，保持 100ns 后释放；仿真运行固定时间后停止
	initial begin
		rst_n <= 0;
		#100 rst_n <= 1;
		#(1480*740*10*7) $stop;
	end
	
	// -------------------------------------------------------------------------
	// 基本参数
	// -------------------------------------------------------------------------
	// BITS_FILE：文件存储位宽（通常 16bit 对齐）
	// BITS     ：实际参与叠加/输出的像素位宽（本 testbench 取 8bit）
	// WIDTH/HEIGHT：输入视频分辨率
	localparam BITS_FILE = 16;
	localparam BITS     = 8;
	localparam WIDTH    = 1920;//1280;
	localparam HEIGHT   = 1080;//720;
	localparam BAYER    = 3;
//	localparam IN_FILE  = "OSD.bin";
	// 输入文件：分别提供 3 路输入通道（这里使用 R/G/B 三个文件名；实际语义由连线决定）
	localparam IN_FILE_R  = "R_In_invalid_region_crop_ColorChecker_1920x1080_10bit_GRBG.bin";
	localparam IN_FILE_G  = "G_In_invalid_region_crop_ColorChecker_1920x1080_10bit_GRBG.bin";
	localparam IN_FILE_B  = "B_In_invalid_region_crop_ColorChecker_1920x1080_10bit_GRBG.bin";
	// 输出文件：打包后的 3 通道数据（每通道按 BITS_FILE 写出）
	localparam OUT_FILE = "out_OSD.bin";
	
	
	    // pclk and reset generation
	wire dvp_clk_out,dvp_href_out,dvp_vsync_out;
	wire [BITS_FILE-1:0] dvp_out_y;
	// -------------------------------------------------------------------------
	// 输入通道 0：产生 dvp_clk_out/href/vsync（其它通道只提供 data）
	// -------------------------------------------------------------------------
	// 注意：这里将 IN_FILE_B 作为 dvp_out_y 的来源，仅是命名习惯，并不代表它一定是亮度 Y。
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
	file2dvp_r(
		.xclk(xclk), .rst_n(rst_n), .pclk(dvp_clk_out), .href(dvp_href_out), .hsync(),	.vsync(dvp_vsync_out),
		.data(dvp_out_y)
	);
	
	wire [BITS_FILE-1:0] dvp_out_u;
	// 输入通道 1：与通道 0 共享同一套时序（href/vsync），这里只需要数据本身
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
		.xclk(xclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_u)
	);
	
	wire [BITS_FILE-1:0] dvp_out_v;
	// 输入通道 2：与通道 0 共享同一套时序（href/vsync），这里只需要数据本身
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
	file2dvp_v(
		.xclk(xclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_v)
	);
    wire in_href, in_vsync;
    wire [BITS-1:0] in_y, in_u, in_v;
    wire [BITS-1:0] out_y, out_u, out_v;
    assign in_href = dvp_href_out;
    assign in_vsync = dvp_vsync_out;
    assign in_y = dvp_out_y[BITS-1:0];
    assign in_u = dvp_out_u[BITS-1:0];
    assign in_v = dvp_out_v[BITS-1:0];

//	wire in_pclk, in_href, in_vsync;
//	wire [BITS-1:0] in_data;
//	tb_file_to_dvp
//		#(
//			.FILE(IN_FILE),
//			.BITS(BITS),
//			.H_DISP(WIDTH),
//			.V_DISP(HEIGHT)
//		)
//		dvp_gen
//		(
//			.xclk(xclk),
//			.rst_n(rst_n),
//			.pclk(in_pclk),
//			.href(in_href),
//			.hsync(),
//			.vsync(in_vsync),
//			.data(in_data)
//		);

	wire out_pclk = dvp_clk_out;
	wire out_href;
	wire out_vsync;
//	wire [3*BITS-1:0] out_data;

	localparam OSD_RAM_ADDR_BITS = 9;
	localparam OSD_RAM_DATA_BITS = 32;

	// -------------------------------------------------------------------------
	// OSD RAM 配置接口（用于写入 OSD 图案）
	// -------------------------------------------------------------------------
	// 这里用一个简单的写入时序模拟“CPU/总线写 RAM”：
	// - `osd_ram_clk` 周期性翻转
	// - 当 `osd_ram_wen==1` 时，`osd_ram_addr` 自增
	// - `osd_ram_wdata` 由 `osd_lut` 查表生成
	reg             osd_ram_clk = 0;
	reg             osd_ram_wen = 0;
	reg  [OSD_RAM_ADDR_BITS-1:0] osd_ram_addr = 0;
	wire [OSD_RAM_DATA_BITS-1:0] osd_ram_wdata;
	
	always #2 osd_ram_clk  <= ~osd_ram_clk;
	always #4 osd_ram_addr <= osd_ram_wen ? osd_ram_addr + 1'b1 : osd_ram_addr;
	initial begin
		#200      osd_ram_wen <= 1;
		#(8*129) osd_ram_wen <= 0;
	end
	
	// -------------------------------------------------------------------------
	// OSD 叠加窗口参数
	// -------------------------------------------------------------------------
	// `osd_x/osd_y`：左上角坐标
	// `osd_w/osd_h`：叠加区域宽高
	reg [11:0] osd_x = 50, osd_w = 32*4;
	reg [10:0]  osd_y = 50, osd_h = 32*2;
	initial begin
//		#100;
//		#(1480*740*10) osd_x <= WIDTH - 128;
//		#(1480*740*10) osd_y <= HEIGHT - 32;
//		#(1480*740*10) osd_x <= 0;
//		#(1480*740*10) osd_x <= 100; osd_y <= 100;
//		#(1480*740*10) osd_w <= 0;
//		#(1480*740*10) osd_h <= 0;
	end

	osd_lut #(OSD_RAM_ADDR_BITS,OSD_RAM_DATA_BITS) lut0(osd_ram_addr, osd_ram_wdata);
	vip_osd 
		#(
			BITS, WIDTH, HEIGHT, OSD_RAM_ADDR_BITS, OSD_RAM_DATA_BITS
		) 
		osd_i0
		(
			.pclk(dvp_clk_out),
			.rst_n(rst_n),
			.osd_x(osd_x),
			.osd_y(osd_y),
			.osd_w(osd_w),
			.osd_h(osd_h),
			// 前景色/背景色与透明度（alpha 越大越偏向前景）
			.fg_color_r(8'h00),
			.fg_color_g(8'hA0),
			.fg_color_b(8'h5A),
			.bg_color_r(8'hFF),
			.bg_color_g(8'hFF),
			.bg_color_b(8'hFF),
			.alpha(8'd50),
			.in_href(in_href),
			.in_vsync(in_vsync),
			// 3 通道输入/输出：此处把 r/g/b 端口复用为 v/y/u（仅 testbench 语义）
			.in_data_r(in_v),
			.in_data_g(in_y),
			.in_data_b(in_u),
			.out_href(out_href),
			.out_vsync(out_vsync),
			.out_data_r(out_v),
			.out_data_g(out_y),
			.out_data_b(out_u),
			.osd_ram_clk(osd_ram_clk),
			.osd_ram_wen(osd_ram_wen),
			.osd_ram_ren(1'b0),
			.osd_ram_addr(osd_ram_addr),
			.osd_ram_wdata(osd_ram_wdata),
			.osd_ram_rdata()
		);

	// -------------------------------------------------------------------------
	// 输出写文件：把 3 通道数据按 16bit 对齐打包输出
	// -------------------------------------------------------------------------
	tb_dvp_to_file
		#(
			.FILE(OUT_FILE),
			.BITS(3*BITS_FILE)
		)
		dvp_recv
		(
			.pclk(out_pclk),
			.rst_n(rst_n),
			.href(out_href),
			.vsync(out_vsync),
			.data({{8'd0,out_y}, {8'd0,out_u}, {8'd0,out_v}})
		);
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
	// `vip_osd` 通常通过一块 RAM/ROM 存放 OSD 图案。
	// 这里用 case-LUT 的方式“伪造”一块只读 RAM：
	// - index：模拟 RAM 地址
	// - value：对应地址的 32bit 数据
	//
	// 典型用法是将每个 bit 视作一个像素的“遮罩/使能”，从而在 OSD 区域内决定叠加前景还是背景。
	// 具体 bit 到像素的映射由 `vip_osd` 内部实现决定。
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
