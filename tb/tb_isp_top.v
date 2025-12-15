/*************************************************************************
 * 文件名: tb_isp_top.v
 * 描述: ISP顶层模块测试平台 (Testbench for ISP Top Module)
 * 作者: 10xEngineers
 * 邮箱: isp@10xengineers.ai
 ************************************************************************/
`timescale 1ns / 1ps

/*
 * ============================================================================
 * ISP顶层模块测试平台 (ISP Top Module Testbench)
 * ============================================================================
 * 
 * 【测试平台功能】
 * 本测试平台用于验证ISP顶层模块(isp_top)的功能正确性。
 * 主要功能包括：
 * 1. 从二进制文件读取RAW图像数据，转换为DVP视频流
 * 2. 实例化并配置ISP顶层模块
 * 3. 将ISP处理后的输出保存为二进制文件，用于与Golden Model对比
 * 
 * 【测试平台结构】
 * ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
 * │  File2DVP   │───▶│   ISP Top   │───▶│  DVP2File   │
 * │ (文件转DVP)  │    │  (被测模块)  │    │ (DVP转文件)  │
 * └─────────────┘    └─────────────┘    └─────────────┘
 *       ↑                                      ↓
 *   输入RAW文件                           输出YUV/RGB文件
 * 
 * 【时序说明】
 * - 像素时钟周期: 20ns (50MHz)
 * - 复位信号: 低电平有效，持续20ns后释放
 * 
 * 【输出文件】
 * - 主输出: YUV或RGB格式图像数据
 * - AWB增益: R通道和B通道增益值
 * - AE响应: 曝光状态和偏度值
 * - 数字增益索引: DGain模块的增益索引
 */

module tb_isp_top;

// ============================================================================
// 输入输出文件路径配置
// ============================================================================
// 输入文件：RAW格式的Bayer图像数据（二进制格式）
// 输出文件：ISP处理后的图像数据
	localparam IN_FILE = "R_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";    // RAW输入文件
	localparam IN_FILE_R = "R_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";  // R通道输入（用于RGB直接输入模式）
	localparam IN_FILE_G = "G_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";  // G通道输入
	localparam IN_FILE_B = "B_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";  // B通道输入
	localparam OUT_FILE = "RTL_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin"; // 输出文件
	
// ============================================================================
// ISP顶层模块参数配置
// ============================================================================
// -------------------- 基本图像参数 --------------------
	localparam BITS_FILE = 16;                   // 文件中像素位宽（16位存储）
	localparam BITS = 10;                        // ISP内部像素位宽（10位处理）
	localparam BITS_DIFF = BITS_FILE - BITS;     // 位宽差值（用于数据对齐）
	localparam SNS_WIDTH = 2592;                 // 传感器图像宽度
	localparam SNS_HEIGHT = 1536;                // 传感器图像高度
	localparam CROP_WIDTH = 2592;                // 裁剪后图像宽度
	localparam CROP_HEIGHT = 1536;               // 裁剪后图像高度
	localparam BAYER = 1;                        // Bayer格式：0:RGGB 1:GRBG 2:GBRG 3:BGGR

// -------------------- OECF光电转换参数 --------------------
	localparam OECF_TABLE_BITS = BITS;           // OECF查找表位宽
	localparam OECF_R_LUT = "in/OECF_R_LUT_INIT.txt";   // OECF R通道LUT初始化文件
	localparam OECF_GR_LUT = "in/OECF_GR_LUT_INIT.txt"; // OECF Gr通道LUT初始化文件
	localparam OECF_GB_LUT = "in/OECF_GR_LUT_INIT.txt"; // OECF Gb通道LUT初始化文件
	localparam OECF_B_LUT = "in/OECF_B_LUT_INIT.txt";   // OECF B通道LUT初始化文件

// -------------------- BNR降噪参数 --------------------
	localparam BNR_WEIGHT_BITS = 8;              // BNR权重位宽

// -------------------- 数字增益参数 --------------------
	localparam DGAIN_ARRAY_SIZE = 100;           // 数字增益数组大小（100个等级）
	localparam DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE); // 增益索引位宽

// -------------------- AWB统计窗口裁剪参数 --------------------
// 说明：Golden Model裁剪参数为[8,8,8,8]
// RTL由于流水线延迟需要补偿：[8,8,8+yshift,8-yshift]
// 该参数在Bayer域进行裁剪，综合后不可更改
	localparam AWB_CROP_LEFT = 8;                // AWB左边界裁剪像素数
	localparam AWB_CROP_RIGHT = 8;               // AWB右边界裁剪像素数
	localparam AWB_CROP_TOP = 8+8;               // AWB上边界裁剪像素数（含延迟补偿）
	localparam AWB_CROP_BOTTOM = 8-8;            // AWB下边界裁剪像素数（含延迟补偿）

// -------------------- Gamma校正参数 --------------------
	localparam GAMMA_TABLE_BITS = BITS;          // Gamma查找表位宽
	localparam GAMMA_R_LUT = "in/GAMMA_R_LUT_INIT.txt"; // Gamma R通道LUT初始化文件
	localparam GAMMA_G_LUT = "in/GAMMA_G_LUT_INIT.txt"; // Gamma G通道LUT初始化文件
	localparam GAMMA_B_LUT = "in/GAMMA_B_LUT_INIT.txt"; // Gamma B通道LUT初始化文件

// -------------------- 其他模块参数 --------------------
	localparam SHARP_WEIGHT_BITS = 20;           // 锐化权重位宽
	localparam NR2D_LUT_SIZE = 32;               // 2D降噪LUT大小
	localparam NR2D_WEIGHT_BITS = 5;             // 2D降噪权重位宽
	localparam STAT_OUT_BITS = 32;               // 统计输出位宽
	localparam STAT_HIST_BITS = 16;              // 直方图统计位宽（用于调试）
// ============================================================================
// ISP模块实例化开关（编译时决定是否综合该模块）
// ============================================================================
// 1 = 综合该模块，0 = 不综合该模块
// 注意：这些是编译时宏定义，综合后无法更改
   	`define USE_CROP 1      // 使用图像裁剪模块
	`define USE_DPC 1       // 使用坏点校正模块
	`define USE_BLC 1       // 使用黑电平校正模块
	`define USE_OECF 1      // 使用光电转换模块
	`define USE_DGAIN 1     // 使用数字增益模块
	`define USE_LSC 0       // 使用镜头阴影校正模块（预留，未实现）
	`define USE_BNR 1       // 使用Bayer域降噪模块
	`define USE_WB 1        // 使用白平衡模块
	`define USE_DEMOSIC 1   // 使用去马赛克模块
	`define USE_CCM 1       // 使用色彩校正矩阵模块
	`define USE_GAMMA 1     // 使用Gamma校正模块
	`define USE_CSC 1       // 使用色彩空间转换模块
	`define USE_SHARP 0     // 使用锐化模块（当前禁用）
	`define USE_LDCI 0      // 使用局部对比度增强模块（预留，未实现）
	`define USE_2DNR 1      // 使用2D降噪模块
	`define USE_STAT_AE 0   // 使用AE统计模块（当前禁用）
	`define USE_AWB 1       // 使用自动白平衡模块
	`define USE_AE 1        // 使用自动曝光模块

// ============================================================================
// ISP模块运行时使能开关（运行时可动态控制）
// ============================================================================
// 1 = 使能该模块处理，0 = 旁路该模块（数据直通）
// 注意：这些参数可在仿真/运行时动态更改
	localparam CROP_EN = 0;      // 裁剪使能（0=禁用）
	localparam DPC_EN = 0;       // 坏点校正使能
	localparam BLC_EN = 0;       // 黑电平校正使能
	localparam OECF_EN = 0;      // 光电转换使能
	localparam DGAIN_EN = 0;     // 数字增益使能
	localparam BNR_EN = 0;       // Bayer降噪使能
	localparam WB_EN = 0;        // 白平衡使能
	localparam DEMOSAIC_EN = 0;  // 去马赛克使能
	localparam CCM_EN = 0;       // 色彩校正使能
	localparam GAMMA_EN = 1;     // Gamma校正使能（当前启用）
	localparam CSC_EN = 1;       // 色彩空间转换使能（当前启用）
	localparam SHARP_EN = 0;     // 锐化使能
	localparam NR2D_EN = 0;      // 2D降噪使能
	localparam STAT_AE_EN = 0;   // AE统计使能
	localparam AWB_EN = 0;       // 自动白平衡使能
	localparam AE_EN = 1;        // 自动曝光使能（当前启用）
	
// ============================================================================
// ISP各模块可调参数配置
// ============================================================================

// -------------------- DPC坏点校正参数 --------------------
	localparam DPC_THRESHOLD = 20;               // 坏点检测阈值（像素差值超过此值判定为坏点）

// -------------------- BLC黑电平校正和线性化参数 --------------------
	localparam BLC_R = 50;                       // R通道黑电平值
	localparam BLC_GR = 50;                      // Gr通道黑电平值
	localparam BLC_GB = 50;                      // Gb通道黑电平值
	localparam BLC_B = 50;                       // B通道黑电平值
	localparam LINEAR_EN = 1;                    // 线性化使能
	localparam LINEAR_R = 16'b0100001101001001;  // R通道线性化系数（Q1.15格式）
	localparam LINEAR_GR = 16'b0100001101001001; // Gr通道线性化系数
	localparam LINEAR_GB = 16'b0100001101001001; // Gb通道线性化系数
	localparam LINEAR_B = 16'b0100001101001001;  // B通道线性化系数

// -------------------- BNR Bayer域降噪参数 --------------------
// 5×5空间高斯核权重（用于空间域滤波）
// 核心为255，向边缘递减，呈高斯分布
	localparam BNR_SPACE_KERNEL_R = {{8'd0},{8'd3},{8'd7},{8'd3},{8'd0},      // R通道空间核
									{8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									{8'd7},{8'd105},{8'd255},{8'd105},{8'd7},
									{8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									{8'd0},{8'd3},{8'd7},{8'd3},{8'd0}};
	localparam BNR_SPACE_KERNEL_G = {{8'd0},{8'd5},{8'd11},{8'd5},{8'd0},     // G通道空间核
									{8'd5},{8'd53},{8'd117},{8'd53},{8'd5},
									{8'd11},{8'd117},{8'd255},{8'd117},{8'd11},
									{8'd5},{8'd53},{8'd117},{8'd53},{8'd5},
									{8'd0},{8'd5},{8'd11},{8'd5},{8'd0}};
	localparam BNR_SPACE_KERNEL_B = {{8'd0},{8'd3},{8'd7},{8'd3},{8'd0},      // B通道空间核
									{8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									{8'd7},{8'd105},{8'd255},{8'd105},{8'd7},
									{8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									{8'd0},{8'd3},{8'd7},{8'd3},{8'd0}};
// 颜色权重曲线（X为差值阈值，Y为对应权重）
// 差值越小权重越大，实现边缘保持
	localparam BNR_COLOR_CURVE_X_R = {{10'd294},{10'd261},{10'd229},{10'd196},{10'd163},{10'd130},{10'd98},{10'd65},{10'd32}};  // R通道差值阈值
	localparam BNR_COLOR_CURVE_Y_R = {{8'd51},{8'd72},{8'd96},{8'd125},{8'd155},{8'd186},{8'd213},{8'd236},{8'd250}};           // R通道权重值
	localparam BNR_COLOR_CURVE_X_G = {{10'd92},{10'd81},{10'd71},{10'd61},{10'd51},{10'd40},{10'd30},{10'd20},{10'd10}};        // G通道差值阈值
	localparam BNR_COLOR_CURVE_Y_G = {{8'd51},{8'd73},{8'd97},{8'd125},{8'd155},{8'd188},{8'd215},{8'd236},{8'd250}};           // G通道权重值
	localparam BNR_COLOR_CURVE_X_B = {{10'd294},{10'd261},{10'd229},{10'd196},{10'd163},{10'd130},{10'd98},{10'd65},{10'd32}};  // B通道差值阈值
	localparam BNR_COLOR_CURVE_Y_B = {{8'd51},{8'd72},{8'd96},{8'd125},{8'd155},{8'd186},{8'd213},{8'd236},{8'd250}};           // B通道权重值
// -------------------- 数字增益参数 --------------------
// 增益数组：100个等级，从100递减到1
// AE模块根据曝光状态选择合适的增益索引
	localparam DGAIN_ARRAY = {{8'd100},{8'd99},{8'd98},{8'd97},{8'd96},{8'd95},{8'd94},{8'd93},{8'd92},{8'd91},{8'd90},{8'd89},{8'd88},{8'd87},{8'd86},{8'd85},{8'd84},{8'd83},{8'd82},{8'd81},{8'd80},{8'd79},{8'd78},{8'd77},{8'd76},{8'd75},{8'd74},{8'd73},{8'd72},{8'd71},{8'd70},{8'd69},{8'd68},{8'd67},{8'd66},{8'd65},{8'd64},{8'd63},{8'd62},{8'd61},{8'd60},{8'd59},{8'd58},{8'd57},{8'd56},{8'd55},{8'd54},{8'd53},{8'd52},{8'd51},{8'd50},{8'd49},{8'd48},{8'd47},{8'd46},{8'd45},{8'd44},{8'd43},{8'd42},{8'd41},{8'd40},{8'd39},{8'd38},{8'd37},{8'd36},{8'd35},{8'd34},{8'd33},{8'd32},{8'd31},{8'd30},{8'd29},{8'd28},{8'd27},{8'd26},{8'd25},{8'd24},{8'd23},{8'd22},{8'd21},{8'd20},{8'd19},{8'd18},{8'd17},{8'd16},{8'd15},{8'd14},{8'd13},{8'd12},{8'd11},{8'd10},{8'd9},{8'd8},{8'd7},{8'd6},{8'd5},{8'd4},{8'd3},{8'd2},{8'd1}};
	localparam DGAIN_ISMANUAL = 1;               // 手动模式：1=使用手动索引，0=使用AE反馈索引
	localparam DGAIN_MAN_INDEX = 0;              // 手动模式下的增益索引

// -------------------- 白平衡参数 --------------------
// 增益格式：Q4.8定点数（4位整数 + 8位小数）
	localparam WB_RGAIN = 12'b000100111111;      // R通道增益 ≈ 1.246（Q4.8格式）
	localparam WB_BGAIN = 12'b001011001111;      // B通道增益 ≈ 2.81（Q4.8格式）

// -------------------- CCM色彩校正矩阵参数 --------------------
// 3×3色彩校正矩阵，S2.10有符号定点格式
// 矩阵作用：校正传感器色彩响应，使其接近标准色彩空间
	localparam CCM_RR = 16'd1700;                // R_out = RR×R + RG×G + RB×B
	localparam CCM_RG = -1*(16'd540);            // 负系数表示减去该通道分量
	localparam CCM_RB = -1*(16'd136);
	localparam CCM_GR =  -1*(16'd418);           // G_out = GR×R + GG×G + GB×B
	localparam CCM_GG = 16'd1526;                // 对角线元素通常最大
	localparam CCM_GB = -1*(16'd84);
	localparam CCM_BR =  -1*(16'd56);            // B_out = BR×R + BG×G + BB×B
	localparam CCM_BG = -1*(16'd1680);
	localparam CCM_BB = 16'd2760;

// -------------------- CSC色彩空间转换参数 --------------------
	localparam CSC_CONV_STD = 2'd2;              // 转换标准：0=BT.601，1=BT.709，2=自定义

// -------------------- 锐化参数 --------------------
// 9×9高斯模糊核（用于USM反锐化掩模算法）
// 核心权重最小，边缘权重最大（反高斯分布）
	localparam SHARPEN_STRENGTH = 12'b001110011001; // 锐化强度
	localparam LUMA_KERNEL = {{20'd12659},{20'd11005},{20'd9958},{20'd9378},{20'd9192},{20'd9378},{20'd9958},{20'd11005},{20'd12659},
							  {20'd11005},{20'd9568},{20'd8657},{20'd8153},{20'd7991},{20'd8153},{20'd8657},{20'd9568},{20'd11005},
							  {20'd9958},{20'd8657},{20'd7833},{20'd7377},{20'd7231},{20'd7377},{20'd7833},{20'd8657},{20'd9958},
							  {20'd9378},{20'd8153},{20'd7377},{20'd6947},{20'd6810},{20'd6947},{20'd7377},{20'd8153},{20'd9378},
							  {20'd9192},{20'd7991},{20'd7231},{20'd6810},{20'd6675},{20'd6810},{20'd7231},{20'd7991},{20'd9192},
							  {20'd9378},{20'd8153},{20'd7377},{20'd6947},{20'd6810},{20'd6947},{20'd7377},{20'd8153},{20'd9378},
							  {20'd9958},{20'd8657},{20'd7833},{20'd7377},{20'd7231},{20'd7377},{20'd7833},{20'd8657},{20'd9958},
							  {20'd11005},{20'd9568},{20'd8657},{20'd8153},{20'd7991},{20'd8153},{20'd8657},{20'd9568},{20'd11005},
							  {20'd12659},{20'd11005},{20'd9958},{20'd9378},{20'd9192},{20'd9378},{20'd9958},{20'd11005},{20'd12659}};

// -------------------- 2D降噪参数 --------------------
// 差值阈值数组：用于确定像素差值对应的权重
	localparam NR2D_DIFF = {{8'd255},{8'd246},{8'd238},{8'd230},{8'd222},{8'd213},{8'd205},{8'd197},{8'd189},{8'd180},{8'd172},{8'd164},{8'd156},{8'd148},{8'd139},{8'd131},{8'd123},{8'd115},{8'd106},{8'd98},{8'd90},{8'd82},{8'd74},{8'd65},{8'd57},{8'd49},{8'd41},{8'd32},{8'd24},{8'd16},{8'd8},{8'd0}};
// 权重数组：差值越小权重越大，实现边缘保持降噪
	localparam NR2D_WEIGHT = {{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd2},{5'd31}};

// -------------------- AE统计参数（预留） --------------------
	localparam STAT_AE_RECT_X = 0;               // AE统计区域X起始
	localparam STAT_AE_RECT_Y = 0;               // AE统计区域Y起始
	localparam STAT_AE_RECT_W = 0;               // AE统计区域宽度
	localparam STAT_AE_RECT_H = 0;               // AE统计区域高度

// -------------------- AWB自动白平衡参数 --------------------
    localparam AWB_UNDEREXPOSED_LIMIT = 51;      // 欠曝阈值：低于此值的像素不参与统计
    localparam AWB_OVEREXPOSED_LIMIT = 972;      // 过曝阈值：高于此值的像素不参与统计
    localparam AWB_FRAMES = 1;                   // 统计帧数：多少帧后更新增益

// -------------------- AE自动曝光参数 --------------------
// 说明：Golden Model裁剪参数为[12,12,12,12]
// RTL由于流水线延迟需要补偿，在RGB域进行裁剪，综合后可更改
	localparam AE_CROP_LEFT = 12;                // AE左边界裁剪像素数
	localparam AE_CROP_RIGHT = 12;               // AE右边界裁剪像素数
	localparam AE_CROP_TOP = 12;                 // AE上边界裁剪像素数
	localparam AE_CROP_BOTTOM = 12;              // AE下边界裁剪像素数
	localparam CENTRE_ILLUMINANCE = 90;          // 目标中心亮度值（0-255）
	localparam SKEWNESS = 230;                   // 偏度阈值：用于判断过曝/欠曝
   	
// ============================================================================
// File2DVP模块：将二进制文件转换为DVP视频流
// ============================================================================
// 该模块从文件读取RAW图像数据，生成符合DVP时序的视频信号
// 时序参数模拟典型的视频传感器输出时序
   
// -------------------- 时钟和复位信号 --------------------
	reg rst_n;                                   // 全局复位信号（低有效）
	reg pclk;                                    // 像素时钟（50MHz，周期20ns）
	wire dvp_clk_out,dvp_href_out,dvp_vsync_out; // DVP输出信号
	wire [BITS_FILE-1:0] dvp_out_raw;            // DVP输出RAW数据

// -------------------- RAW输入File2DVP实例 --------------------
// 将RAW文件转换为Bayer格式的DVP视频流
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE,              // 输入文件路径
		/*BITS 		*/	BITS_FILE,           // 像素位宽（16位存储）
		/*H_FRONT 	*/	5,                   // 行前沿消隐周期数
		/*H_PULSE 	*/	10,                  // 行同步脉冲周期数
		/*H_BACK 	*/	2,                   // 行后沿消隐周期数
		/*H_DISP 	*/	SNS_WIDTH,           // 行有效像素数（图像宽度）
		/*V_FRONT	*/	6,                   // 场前沿消隐行数
		/*V_PULSE	*/	20,                  // 场同步脉冲行数
		/*V_BACK 	*/	3,                   // 场后沿消隐行数
		/*V_DISP 	*/	SNS_HEIGHT,          // 场有效行数（图像高度）
		/*H_POL 	*/	0,                   // 行同步极性：0=低有效
		/*V_PO.   	*/	1                    // 场同步极性：1=高有效
		)
	file2dvp(
		.xclk(pclk),                             // 输入时钟
		.rst_n(rst_n),                           // 复位信号
		.pclk(dvp_clk_out),                      // 输出像素时钟
		.href(dvp_href_out),                     // 输出行有效信号
		.hsync(),                                // 行同步（未使用）
		.vsync(dvp_vsync_out),                   // 输出场同步信号
		.data(dvp_out_raw)                       // 输出RAW像素数据
	);
	
// -------------------- RGB三通道输入File2DVP实例 --------------------
// 用于直接输入RGB图像（跳过RAW处理阶段），可用于测试后半段ISP流水线
	wire dvp_href_rgb_out,dvp_vsync_rgb_out;     // RGB输入DVP信号
	wire [BITS_FILE-1:0] dvp_out_r;              // R通道数据
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_R,            // R通道输入文件
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	SNS_WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	SNS_HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_r(
		.xclk(pclk), .rst_n(rst_n), .pclk(), .href(dvp_href_rgb_out), .hsync(),	.vsync(dvp_vsync_rgb_out),
		.data(dvp_out_r)
	);
	
	wire [BITS_FILE-1:0] dvp_out_g;              // G通道数据
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_G,            // G通道输入文件
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	SNS_WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	SNS_HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_g(
		.xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_g)
	);
	
	wire [BITS_FILE-1:0] dvp_out_b;              // B通道数据
	tb_file_to_dvp
	#(
		/*FILE 		*/ IN_FILE_B,            // B通道输入文件
		/*BITS 		*/	BITS_FILE,   				
		/*H_FRONT 	*/	5,  				
		/*H_PULSE 	*/	10,  			   
		/*H_BACK 	*/	2,   			   
		/*H_DISP 	*/	SNS_WIDTH,    		
		/*V_FRONT	*/	6,   			
		/*V_PULSE	*/	20,			
		/*V_BACK 	*/	3,				
		/*V_DISP 	*/	SNS_HEIGHT,  	
		/*H_POL 	*/	0,           
		/*V_PO.   	*/	1				
		)
	file2dvp_b(
		.xclk(pclk), .rst_n(rst_n), .pclk(), .href(), .hsync(),	.vsync(),
		.data(dvp_out_b)
	);
	
// ============================================================================
// ISP模块输入信号寄存器声明
// ============================================================================
// 这些寄存器用于配置ISP各子模块的参数

// -------------------- 输入选择 --------------------
	reg rgb_inp_en;                              // RGB直接输入使能：1=使用RGB输入，0=使用RAW输入

// -------------------- 模块使能寄存器 --------------------
	reg crop_en, dpc_en, blc_en, linear_en, oecf_en, bnr_en, dgain_en, demosic_en, wb_en, ccm_en, csc_en, gamma_en, nr2d_en, sharp_en, stat_ae_en, awb_en, ae_en;

// -------------------- DPC坏点校正输入 --------------------
	reg [BITS-1:0] dpc_threshold;                // 坏点检测阈值

// -------------------- BLC黑电平校正和线性化输入 --------------------
	reg [BITS-1:0] blc_r, blc_gr, blc_gb, blc_b; // 四通道黑电平值
	reg [15:0] linear_r, linear_gr, linear_gb, linear_b; // 四通道线性化系数

// -------------------- OECF查找表配置接口 --------------------
// 用于运行时更新OECF查找表（双端口RAM接口）
	reg r_table_clk, gr_table_clk, gb_table_clk, b_table_clk;     // 表时钟
	reg r_table_wen, gr_table_wen, gb_table_wen, b_table_wen;     // 写使能
	reg r_table_ren, gr_table_ren, gb_table_ren, b_table_ren;     // 读使能
	reg [OECF_TABLE_BITS-1:0] r_table_addr, gr_table_addr, gb_table_addr, b_table_addr;     // 地址
	reg [OECF_TABLE_BITS-1:0] r_table_wdata, gr_table_wdata, gb_table_wdata, b_table_wdata; // 写数据

// -------------------- BNR降噪参数输入 --------------------
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_r;  // R通道5×5空间核
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_g;  // G通道5×5空间核
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_b;  // B通道5×5空间核
	reg [9*BITS-1:0]              bnr_color_curve_x_r; // R通道颜色曲线X（差值阈值）
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_r; // R通道颜色曲线Y（权重值）
	reg [9*BITS-1:0]              bnr_color_curve_x_g; // G通道颜色曲线X
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_g; // G通道颜色曲线Y
	reg [9*BITS-1:0]              bnr_color_curve_x_b; // B通道颜色曲线X
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_b; // B通道颜色曲线Y

// -------------------- 数字增益输入 --------------------
	reg [DGAIN_ARRAY_SIZE*8-1:0] dgain_array;    // 增益数组（100个8位增益值）
	reg dgain_isManual;                          // 手动模式选择
	reg [DGAIN_ARRAY_BITS-1:0] dgain_man_index;  // 手动模式增益索引

// -------------------- 白平衡输入 --------------------
	reg [11:0] wb_rgain, wb_bgain;               // R/B通道增益（Q4.8格式）

// -------------------- CCM色彩校正矩阵输入 --------------------
	reg [15:0] ccm_rr, ccm_rg, ccm_rb;           // CCM第一行（R输出系数）
	reg [15:0] ccm_gr, ccm_gg, ccm_gb;           // CCM第二行（G输出系数）
	reg [15:0] ccm_br, ccm_bg, ccm_bb;           // CCM第三行（B输出系数）

// -------------------- Gamma查找表配置接口 --------------------
	reg gamma_table_r_clk, gamma_table_g_clk, gamma_table_b_clk;  // 表时钟
	reg gamma_table_r_wen, gamma_table_g_wen, gamma_table_b_wen;  // 写使能
	reg gamma_table_r_ren, gamma_table_g_ren, gamma_table_b_ren;  // 读使能
	reg [GAMMA_TABLE_BITS-1:0] gamma_table_r_addr, gamma_table_g_addr, gamma_table_b_addr;     // 地址
	reg [GAMMA_TABLE_BITS-1:0] gamma_table_r_wdata, gamma_table_g_wdata, gamma_table_b_wdata;  // 写数据
	
// -------------------- CSC色彩空间转换输入 --------------------
	reg [1:0] in_conv_standard;                  // 转换标准选择

// -------------------- 锐化输入 --------------------
	reg [9*9*SHARP_WEIGHT_BITS-1:0] luma_kernel; // 9×9亮度核
    reg [11:0] sharpen_strength;                 // 锐化强度

// -------------------- 2D降噪输入 --------------------
	reg [NR2D_LUT_SIZE*8-1:0] nr2d_diff;         // 差值阈值LUT（32×8位）
	reg [NR2D_LUT_SIZE*NR2D_WEIGHT_BITS-1:0] nr2d_weight; // 权重LUT（32×5位）

// -------------------- AE统计输入（预留） --------------------
	reg [15:0] stat_ae_rect_x;                   // 统计区域X起始
	reg [15:0] stat_ae_rect_y;                   // 统计区域Y起始
	reg [15:0] stat_ae_rect_w;                   // 统计区域宽度
	reg [15:0] stat_ae_rect_h;                   // 统计区域高度

// -------------------- AE自动曝光输入 --------------------
	reg [7:0] center_illuminance;                // 目标中心亮度
	reg [15:0] skewness;                         // 偏度阈值
	reg [11:0] ae_crop_left;                     // AE裁剪左边界
	reg [11:0] ae_crop_right;                    // AE裁剪右边界
	reg [11:0] ae_crop_top;                      // AE裁剪上边界
	reg [11:0] ae_crop_bottom;                   // AE裁剪下边界

// -------------------- AWB自动白平衡输入 --------------------
	reg [BITS-1:0] awb_min_percentage;           // 最小百分比（预留）
	reg [BITS-1:0] awb_max_percentage;           // 最大百分比（预留）
	reg [BITS-1:0] awb_underexposed_limit;       // 欠曝阈值
	reg [BITS-1:0] awb_overexposed_limit;        // 过曝阈值
	reg [BITS-1:0] awb_frames;                   // 统计帧数
	reg stat_awb_hist_clk;                       // 直方图时钟
	reg stat_awb_hist_out;                       // 直方图输出使能
	reg [STAT_HIST_BITS+1:0] stat_awb_hist_addr; // 直方图地址
// ============================================================================
// ISP模块输出信号声明
// ============================================================================

// -------------------- 主输出（YUV格式） --------------------
	wire out_href, out_vsync;                    // 输出行有效和场同步
	wire [7:0] out_y, out_u, out_v;              // YUV输出（8位）

// -------------------- Gamma输出（RGB格式，用于调试） --------------------
	wire out_gamma_href, out_gamma_vsync;        // Gamma模块输出同步信号
	wire [BITS-1:0] out_gamma_r, out_gamma_g, out_gamma_b; // Gamma后RGB输出

// -------------------- OECF查找表读数据输出 --------------------
	wire [OECF_TABLE_BITS-1:0] r_table_rdata, gr_table_rdata, gb_table_rdata, b_table_rdata;

// -------------------- 数字增益输出 --------------------
	wire [DGAIN_ARRAY_BITS-1:0] dgain_index_out; // 当前使用的增益索引

// -------------------- Gamma查找表读数据输出 --------------------
	wire [GAMMA_TABLE_BITS-1:0] gamma_table_r_rdata, gamma_table_g_rdata, gamma_table_b_rdata;

// -------------------- AE自动曝光输出 --------------------
	wire [1:0] ae_response;                      // AE响应：00=正常，01=过曝，11=欠曝
	wire [1:0] ae_response_debug;                // AE调试响应
	wire [15:0] ae_result_skewness;              // 计算得到的偏度值
	wire ae_done;                                // AE计算完成标志
	/*
	//===== AE调试端口（注释状态） ======//
	wire [23:0] ae_cropped_size;                 // 裁剪后像素数量
	wire [40:0] sum_pix_square;                  // 像素差值平方和
	wire [50:0] sum_pix_cube;                    // 像素差值立方和
	wire [63:0] div_out_m_2;                     // M2除法输出
	wire [63:0] div_out_m_3;                     // M3除法输出
	wire [63:0] div_out_sqrt_fsm;                // 平方根FSM除法输出
	wire [62:0] sqrt_fsm_out_sqrt;               // 平方根输出
	wire [63:0] div_out_ae_skewness;             // 偏度除法输出
	wire SQRT_FSM_EN;                            // 平方根FSM使能
	wire SQRT_FSM_DIV_EN;                        // 平方根FSM除法使能
	wire SQRT_FSM_DIV_DONE;                      // 平方根FSM除法完成
	wire SQRT_FSM_DONE;                          // 平方根FSM完成
	//===== AE调试端口 ======//
	*/

// -------------------- AWB自动白平衡输出 --------------------
	wire [11:0] final_r_gain,final_b_gain;       // 最终使用的R/B增益（Q4.8格式）
// ============================================================================
// ISP顶层模块实例化（被测单元 UUT）
// ============================================================================
	isp_top	#(
	  /*BITS 					*/  BITS,
	  /*SNS_WIDTH 				*/  SNS_WIDTH,
	  /*SNS_HEIGHT 				*/  SNS_HEIGHT,
	  /*CROP_WIDTH 				*/  CROP_WIDTH,
	  /*CROP_HEIGHT 			*/  CROP_HEIGHT,
	  /*BAYER 					*/  BAYER,
	  /*OECF_TABLE_BITS         */  BITS,
	  /*OECF_R_LUT              */  OECF_R_LUT,
	  /*OECF_GR_LUT             */  OECF_GR_LUT,
	  /*OECF_GB_LUT             */  OECF_GB_LUT,
	  /*OECF_B_LUT              */  OECF_B_LUT,
	  /*BNR_WEIGHT_BITS         */  BNR_WEIGHT_BITS,
	  /*DGAIN_ARRAY_SIZE        */  DGAIN_ARRAY_SIZE,
	  /*DGAIN_ARRAY_BITS        */  DGAIN_ARRAY_BITS,
	  /*AWB_CROP LEFT           */  AWB_CROP_LEFT,
	  /*AWB_CROP RIGHT          */  AWB_CROP_RIGHT,
	  /*AWB_CROP TOP            */  AWB_CROP_TOP,
	  /*AWB_CROP BOTTOM         */  AWB_CROP_BOTTOM,
	  /*AE_CROP LEFT              	AE_CROP_LEFT,
	  /*AE_CROP RIGHT             	AE_CROP_RIGHT,
	  /*AE_CROP TOP               	AE_CROP_TOP,
	  /*AE_CROP BOTTOM            	AE_CROP_BOTTOM,*/
	  /*GAMMA_TABLE_BITS 	    */  GAMMA_TABLE_BITS,
	  /*GAMMA_R_LUT             */  GAMMA_R_LUT,
	  /*GAMMA_G_LUT             */  GAMMA_G_LUT,
	  /*GAMMA_B_LUT             */  GAMMA_B_LUT,
	  /*SHARP_WEIGHT_BITS       */  SHARP_WEIGHT_BITS,
	  /*NR2d_WEIGHTS_BITS       */  NR2D_WEIGHT_BITS,
	  /*STAT_OUT_BITS 		    */  STAT_OUT_BITS,
	  /*STAT_HIST_BITS 		    */  STAT_HIST_BITS,
	  /*USE_CROP				*/  `USE_CROP,
	  /*USE_DPC					*/  `USE_DPC,
	  /*USE_BLC					*/	`USE_BLC,
	  /*USE_OECF				*/	`USE_OECF,	  
	  /*USE_DGAIN				*/  `USE_DGAIN,
	  /*USE_LSC    				*/  `USE_LSC,
	  /*USE_BNR					*/	`USE_BNR,					
	  /*USE_WB					*/  `USE_WB,
	  /*USE_DEMOSIC			    */  `USE_DEMOSIC,
	  /*USE_CCM					*/  `USE_CCM,
	  /*USE_GAMMA				*/  `USE_GAMMA,
	  /*USE_CSC					*/  `USE_CSC, 
	  /*USE_SHARP               */  `USE_SHARP,
	  /*USE_LDCI				*/  `USE_LDCI,
	  /*USE_2DNR				*/  `USE_2DNR,
	  /*USE_STAT_AE			    */  `USE_STAT_AE,
	  /*USE_STAT_AWB			*/  `USE_AWB,
	  /*USE_AE					*/	`USE_AE
	 )
	isp_top_i0(
		// Clock and rest
		.pclk(dvp_clk_out), 
		.rst_n(rst_n), 
		// DVP input
		.in_href(dvp_href_out),	.in_vsync(dvp_vsync_out), .in_raw(dvp_out_raw[BITS-1:0]),
		// DVP 3 channel input
		.in_href_rgb(dvp_href_rgb_out),	.in_vsync_rgb(dvp_vsync_rgb_out), .in_r(dvp_out_r), .in_g(dvp_out_g), .in_b(dvp_out_b),  						 
		// DVP output
		.out_href(out_href), .out_vsync(out_vsync), .out_y(out_y), .out_u(out_u), .out_v(out_v), 	 
		// DVP Gamma output
		.out_gamma_href(out_gamma_href), .out_gamma_vsync(out_gamma_vsync), .out_gamma_b(out_gamma_b), .out_gamma_g(out_gamma_g), .out_gamma_r(out_gamma_r), 	 
		// Enable 3 channel input from outside
		.rgb_inp_en(rgb_inp_en),
		// Enable signals
		.crop_en(crop_en), .dpc_en(dpc_en), .blc_en(blc_en), .bnr_en(bnr_en), .dgain_en(dgain_en),                    
		.demosic_en(demosic_en), .oecf_en(oecf_en), .wb_en(wb_en), 
		.ccm_en(ccm_en), .csc_en(csc_en), .gamma_en(gamma_en), 
		.nr2d_en(nr2d_en), .sharp_en(sharp_en), .stat_ae_en(stat_ae_en), .awb_en(awb_en), .ae_en(ae_en),  
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
		.luma_kernel(luma_kernel),
        .sharpen_strength(sharpen_strength),
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
   
// ============================================================================
// DVP2File模块：将ISP输出转换为二进制文件
// ============================================================================
// 该模块将ISP处理后的图像数据保存为二进制文件，用于与Golden Model对比验证
    generate
	// 如果CSC或2DNR使能，输出YUV格式
	if (CSC_EN | NR2D_EN) begin :csc_onwards
	tb_dvp_to_file
	   #(
		  /*FILE 		*/ OUT_FILE,         // 输出文件路径
		  /*BITS 		*/	16*3             // 3通道 × 16位 = 48位
	    )
	   dvp2file
	   (
		  .pclk(dvp_clk_out),                // 像素时钟
		  .rst_n(rst_n),                     // 复位信号
		  .href(out_href),                   // 行有效
		  .vsync(out_vsync),                 // 场同步
		  .data({{8'd0,out_v}, {8'd0,out_u}, {8'd0,out_y}}) // YUV数据（高8位补0）
		);	
	end
	// 否则输出RGB格式（Gamma后输出）
	else begin :before_csc
	if (BITS_DIFF == 0) begin              // 文件位宽等于ISP位宽
	tb_dvp_to_file
	#(
		/*FILE 		*/ OUT_FILE,
		/*BITS 		*/	BITS*3               // 3通道 × BITS位
	 )
	dvp2file
	(
		.pclk(dvp_clk_out), 
		.rst_n(rst_n),
		.href(out_gamma_href),
		.vsync(out_gamma_vsync),
		.data({out_gamma_b,out_gamma_g,out_gamma_r}) // RGB数据
	);
	end else begin                           // 文件位宽大于ISP位宽，需要补0
	   tb_dvp_to_file
	   #(
		  /*FILE 		*/ OUT_FILE,
		  /*BITS 		*/	BITS_FILE*3      // 3通道 × 文件位宽
	    )
	   dvp2file
	   (
		  .pclk(dvp_clk_out), 
		  .rst_n(rst_n),
		  .href(out_gamma_href),
		  .vsync(out_gamma_vsync),
		  .data({ {BITS_DIFF{1'b0}},out_gamma_b, {BITS_DIFF{1'b0}},out_gamma_g, {BITS_DIFF{1'b0}},out_gamma_r}) // 高位补0
	   );
	  end
	 end
endgenerate

// ============================================================================
// AWB增益输出文件保存
// ============================================================================
// 将每帧计算的AWB增益保存到文件，用于验证AWB算法正确性
localparam OUT_FILE_rgain = "rgain_RTL_In_crop_Outdoor1-10bit-GRBG.bin";  // R增益输出文件
localparam OUT_FILE_bgain = "bgain_RTL_In_crop_Outdoor1-10bit-GRBG.bin";  // B增益输出文件

// VSYNC边沿检测寄存器
reg prev_v_sync;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_v_sync <= 0;
       else
            prev_v_sync <= out_vsync;
    end

// 增益数据扩展为16位（便于文件写入）
wire [BITS+3:0] writer;
wire [BITS+3:0] writeb;
assign writer = {4'd0,final_r_gain};             // R增益扩展
assign writeb = {4'd0,final_b_gain};             // B增益扩展

// R增益文件写入（在VSYNC下降沿写入）
integer fd, c;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			fd = $fopen(OUT_FILE_rgain, "wb");   // 复位时打开文件
		else if (prev_v_sync & (~out_vsync))     // VSYNC下降沿（帧结束）
			for (c = 0; c < 16/8; c = c + 1)     // 按字节写入16位数据
				$fwrite(fd, "%c", writer[(c*8)+:8]);
		else if (out_vsync)
			$fflush(fd);                         // VSYNC高电平时刷新缓冲区
	end

// B增益文件写入
integer fd1, c1;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n)
            fd1 = $fopen(OUT_FILE_bgain, "wb");
        else if (prev_v_sync & (~out_vsync))     // VSYNC下降沿
            for (c1 = 0; c1 < 16/8; c1 = c1 + 1)
                $fwrite(fd1, "%c", writeb[(c1*8)+:8]);
        else if (out_vsync)
            $fflush(fd1);
    end

// ============================================================================
// AE响应和数字增益索引输出文件保存
// ============================================================================
// 多级VSYNC延迟寄存器（用于时序对齐）
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
	
// AE完成信号延迟（用于DGain索引写入时序对齐）
	reg ae_done_delay;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			ae_done_delay <= 1'b0;
		end
		else begin
			ae_done_delay <= ae_done;
		end
	end

// AE输出文件路径
localparam OUT_FILE_AE = "AE_RESPONSE_RTL_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";          // AE响应
localparam OUT_FILE_AE_SKEWNESS= "AE_SKEWNESS_RTL_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";  // AE偏度
localparam OUT_FILE_DG = "DGAIN_INDEX_RTL_In_color_correction_matrix_Indoor1_2592x1536_10bit_GRBG_0.bin";          // 数字增益索引

// AE和DGain数据扩展
    wire [15:0] ae, dg_index;
    assign dg_index = {12'd0,dgain_index_out};   // 增益索引扩展为16位
    assign ae = {14'd0,ae_response_debug};       // AE响应扩展为16位

// AE响应文件写入（在ae_done时写入）
integer fd11, c11;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                fd11 = $fopen(OUT_FILE_AE, "wb");
            else if (ae_done)                    // AE计算完成时写入
                for (c11 = 0; c11 < 16/8; c11 = c11 + 1)
                    $fwrite(fd11, "%c", ae[(c11*8)+:8]);
            else if (out_vsync)
                $fflush(fd11);
        end

// AE偏度值文件写入
integer fd_ae, c_ae;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                fd_ae = $fopen(OUT_FILE_AE_SKEWNESS, "wb");
            else if (ae_done)                    // AE计算完成时写入偏度值
                for (c_ae = 0; c_ae < 16/8; c_ae = c_ae + 1)
                    $fwrite(fd_ae, "%c", ae_result_skewness[(c_ae*8)+:8]);
            else if (out_vsync)
                $fflush(fd_ae);
        end

// 数字增益索引文件写入（延迟一拍，等待DGain更新）
integer f_dg, c_dg;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n)
                f_dg = $fopen(OUT_FILE_DG, "wb");
            else if (ae_done_delay)              // AE完成后延迟一拍写入
                for (c_dg = 0; c_dg < 16/8; c_dg = c_dg + 1)
                    $fwrite(f_dg, "%c", dg_index[(c_dg*8)+:8]);
            else if (out_vsync)
                $fflush(f_dg);
        end
// ============================================================================
// 激励信号初始化块（Stimulus）
// ============================================================================
// 在仿真开始时初始化所有ISP配置参数
initial begin
		// -------------------- 输入模式选择 --------------------
		rgb_inp_en = 1;                          // 使能RGB直接输入模式
		
		// -------------------- 模块使能初始化 --------------------
		crop_en = CROP_EN;                       // 裁剪使能
		dpc_en = DPC_EN;                         // 坏点校正使能
		blc_en = BLC_EN;                         // 黑电平校正使能
		linear_en = LINEAR_EN;                   // 线性化使能
		oecf_en = OECF_EN;                       // OECF使能
		bnr_en = BNR_EN;                         // BNR使能
		dgain_en = DGAIN_EN;                     // 数字增益使能
		demosic_en = DEMOSAIC_EN;                // 去马赛克使能
		wb_en = WB_EN;                           // 白平衡使能
		ccm_en = CCM_EN;                         // CCM使能
		csc_en = CSC_EN;                         // CSC使能
		sharp_en = SHARP_EN;                     // 锐化使能
		gamma_en = GAMMA_EN;                     // Gamma使能
		nr2d_en = NR2D_EN;                       // 2D降噪使能
		stat_ae_en = STAT_AE_EN;                 // AE统计使能
		awb_en = AWB_EN;                         // AWB使能
		ae_en = AE_EN;                           // AE使能

		// -------------------- DPC参数初始化 --------------------
		dpc_threshold = DPC_THRESHOLD;           // 坏点阈值

		// -------------------- BLC参数初始化 --------------------
		blc_r = BLC_R;                           // R通道黑电平
		blc_gr = BLC_GR;                         // Gr通道黑电平
		blc_gb = BLC_GB;                         // Gb通道黑电平
		blc_b = BLC_B;                           // B通道黑电平
		linear_r = LINEAR_R;                     // R通道线性化系数
		linear_gr = LINEAR_GR;                   // Gr通道线性化系数
		linear_gb = LINEAR_GB;                   // Gb通道线性化系数
		linear_b = LINEAR_B;                     // B通道线性化系数

		// -------------------- OECF接口初始化 --------------------
		// 默认设置为只读模式，不更新LUT
		r_table_clk = 0; gr_table_clk = 0; gb_table_clk = 0; b_table_clk = 0;
		r_table_wen = 0; gr_table_wen = 0; gb_table_wen = 0; b_table_wen = 0;     // 禁用写入
		r_table_ren = 1; gr_table_ren = 1; gb_table_ren = 1; b_table_ren = 1;     // 使能读取
		r_table_addr = 0; gr_table_addr = 0; gb_table_addr = 0; b_table_addr = 0;
		r_table_wdata = 0; gr_table_wdata =0; gb_table_wdata = 0; b_table_wdata = 0;

		// -------------------- BNR参数初始化 --------------------
		bnr_space_kernel_r = BNR_SPACE_KERNEL_R; // R通道空间核
		bnr_space_kernel_g = BNR_SPACE_KERNEL_G; // G通道空间核
		bnr_space_kernel_b = BNR_SPACE_KERNEL_B; // B通道空间核
		bnr_color_curve_x_r = BNR_COLOR_CURVE_X_R; // R通道颜色曲线
		bnr_color_curve_y_r = BNR_COLOR_CURVE_Y_R;
		bnr_color_curve_x_g = BNR_COLOR_CURVE_X_G; // G通道颜色曲线
		bnr_color_curve_y_g = BNR_COLOR_CURVE_Y_G;
		bnr_color_curve_x_b = BNR_COLOR_CURVE_X_B; // B通道颜色曲线
		bnr_color_curve_y_b = BNR_COLOR_CURVE_Y_B;

		// -------------------- 数字增益参数初始化 --------------------
		dgain_array = DGAIN_ARRAY;               // 增益数组
		dgain_isManual = DGAIN_ISMANUAL;         // 手动模式标志
		dgain_man_index = DGAIN_MAN_INDEX;       // 手动模式增益索引

		// -------------------- 白平衡参数初始化 --------------------
		wb_rgain = WB_RGAIN;                     // R增益
		wb_bgain = WB_BGAIN;                     // B增益

		// -------------------- CCM参数初始化 --------------------
		ccm_rr = CCM_RR; ccm_rg = CCM_RG; ccm_rb = CCM_RB; // 第一行
		ccm_gr = CCM_GR; ccm_gg = CCM_GG; ccm_gb = CCM_GB; // 第二行
		ccm_br = CCM_BR; ccm_bg = CCM_BG; ccm_bb = CCM_BB; // 第三行

		// -------------------- Gamma接口初始化 --------------------
		gamma_table_r_clk = 0; gamma_table_g_clk = 0; gamma_table_b_clk = 0;
		gamma_table_r_wen = 0; gamma_table_g_wen = 0; gamma_table_b_wen = 0;       // 禁用写入
		gamma_table_r_ren = 1; gamma_table_g_ren = 1; gamma_table_b_ren = 1;       // 使能读取
		gamma_table_r_addr = 0; gamma_table_r_addr = 0; gamma_table_r_addr = 0;
		gamma_table_r_wdata = 0; gamma_table_r_wdata = 0; gamma_table_r_wdata = 0;

		// -------------------- CSC参数初始化 --------------------
		in_conv_standard = CSC_CONV_STD;         // 转换标准

		// -------------------- 锐化参数初始化 --------------------
		luma_kernel = LUMA_KERNEL;               // 9×9亮度核
		sharpen_strength = SHARPEN_STRENGTH;     // 锐化强度

		// -------------------- 2D降噪参数初始化 --------------------
		nr2d_diff = NR2D_DIFF;                   // 差值阈值LUT
		nr2d_weight = NR2D_WEIGHT;               // 权重LUT

		// -------------------- AE参数初始化 --------------------
		center_illuminance = CENTRE_ILLUMINANCE; // 目标亮度
		skewness = SKEWNESS;                     // 偏度阈值
		ae_crop_left = AE_CROP_LEFT;             // AE裁剪参数
		ae_crop_right = AE_CROP_RIGHT;
		ae_crop_top = AE_CROP_TOP;
		ae_crop_bottom = AE_CROP_BOTTOM;

		// -------------------- AWB参数初始化 --------------------
        awb_frames = AWB_FRAMES;                 // 统计帧数
        awb_underexposed_limit = AWB_UNDEREXPOSED_LIMIT; // 欠曝阈值
        awb_overexposed_limit = AWB_OVEREXPOSED_LIMIT;   // 过曝阈值

		// -------------------- AWB统计接口初始化 --------------------
		stat_awb_hist_clk = 0;
		stat_awb_hist_out = 0;
		stat_awb_hist_addr = 0;

		// -------------------- 复位和时钟初始化 --------------------
		rst_n = 0;                               // 初始复位状态
		pclk = 0;                                // 初始时钟状态
		#20                                      // 等待20ns
		rst_n = 1;                               // 释放复位

		// 注意：此处注释掉了$finish，以支持AE/AWB等帧后处理
		// 仿真将持续运行直到手动停止或所有数据处理完成
		//#83000000
		//$finish;
      end
      
// ============================================================================
// 时钟生成
// ============================================================================
// 像素时钟周期 = 20ns（10ns高电平 + 10ns低电平）= 50MHz
// OECF LUT时钟与像素时钟同步
always #10 begin
	pclk = ~pclk;                                // 像素时钟翻转
	r_table_clk = ~r_table_clk;                  // OECF R表时钟
	gr_table_clk = ~gr_table_clk;                // OECF Gr表时钟
	gb_table_clk = ~gb_table_clk;                // OECF Gb表时钟
	b_table_clk = ~b_table_clk;                  // OECF B表时钟
end

endmodule