/*************************************************************************
> File Name: tb_isp_dgain_update.v
> Description: Test bench for digital gain update logic
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

module tb_isp_dgain_update;

// -----------------------------------------------------------------------------
// 功能说明
// -----------------------------------------------------------------------------
// 本测试平台用于验证 `isp_dgain_update`（数字增益索引更新模块）的行为。
//
// 核心思路：
// 1) 从文本文件 `ae_response_vector.txt` 读取一组 2-bit 的 AE 反馈序列（ae_response）。
// 2) 每个像素时钟 `pclk` 周期给 DUT 喂入一个 `ae_response`。
// 3) 观测 DUT 输出的 `dgain_index`（数字增益索引），并以二进制形式写入文件，便于与参考模型对比。
//
// 输出文件：
// - `ae_feedback.bin`        : 记录每次更新后的 `dgain_index`（扩展到 16bit 写文件）。
// - `ae_response_input.bin`  : 记录输入的 `ae_response`（此处按 counter-1 取“上一拍”输入，亦扩展到 16bit）。
// -----------------------------------------------------------------------------

localparam DGAIN_ARRAY_SIZE = 100;
localparam DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE);

// inputs
reg pclk;
reg rst_n;
reg [1:0] ae_response;

// outputs	
wire [DGAIN_ARRAY_BITS-1:0] dgain_index;

// DUT instanstiation
isp_dgain_update #(DGAIN_ARRAY_SIZE, DGAIN_ARRAY_BITS) isp_dgain_update_i0(pclk, rst_n, ae_response, dgain_index);

// Number of inputs for which output is to be tested
localparam NoOfInputs = 47;
reg [1:0] ae_response_vector[NoOfInputs-1:0];

// -----------------------------------------------------------------------------
// 输入向量读取
// -----------------------------------------------------------------------------
// 使用 `$readmemb` 从文本文件读取二进制数据到数组。
// 文件 `ae_response_vector.txt` 需要位于仿真工作目录（仿真器运行路径）下。
initial begin
  $readmemb("ae_response_vector.txt", ae_response_vector);    
  end

// -----------------------------------------------------------------------------
// 输入驱动：计数器在每个 `pclk` 上升沿推进
// -----------------------------------------------------------------------------
// `counter` 用于从 `ae_response_vector[]` 中依次取样。
// 计数范围：0 ~ NoOfInputs，然后回到 0 循环。
reg[7:0] counter; 
always @ (posedge pclk) begin
if (rst_n == 0) begin
    counter <= 0;
    end 
else begin
    if (counter < NoOfInputs)
        counter <= counter +1;
    else 
        counter <= 0;
end  
end

// 组合逻辑：根据当前计数器值选择输入。
// 注：这里的写法是 testbench 常用的“持续驱动”方式，等效于给 DUT 的 `ae_response` 绑到向量数组。
always @(*)  
ae_response = ae_response_vector[counter];

// -----------------------------------------------------------------------------
// 输出导出：写 `dgain_index`
// -----------------------------------------------------------------------------
// 为了便于用通用脚本/工具读取，这里把 `dgain_index` 扩展到 16bit 再写文件。
wire [15:0] _dg_index_out;
reg dump0;
assign _dg_index_out = {14'd0,dgain_index};	//reg reset value = 0 from inside 'isp_dgain_update'
integer fd, c;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			fd = $fopen("ae_feedback.bin", "wb");
			dump0 <= 1;
			end
		else if (counter <NoOfInputs && dump0 == 1)
			for (c = 0; c < 16/8; c = c + 1)
				$fwrite(fd, "%c", _dg_index_out[(c*8)+:8]);
		else if (dump0 == 1) begin
		         dump0 <= 0;
			     $fflush(fd);
			     $fclose(fd);
			     end
			 else begin
			     dump0 <= dump0;
			 end
						
	end

// -----------------------------------------------------------------------------
// 输入导出：写“上一拍”的 `ae_response`
// -----------------------------------------------------------------------------
// 说明：这里用 `ae_response_vector[counter-1]` 记录输入序列的前一个元素，
// 用途是和 `dgain_index` 做时序对齐分析。
// 注意：当 counter==0 时，`counter-1` 会发生下溢（数组索引非法），仿真结果可能为 X；
// 这属于 testbench 的边界行为，通常只用于从第 1 个有效周期开始对齐分析。
reg [15:0] _prev_ae_response;
reg dump1;
always @(*)
_prev_ae_response = {14'd0,ae_response_vector[counter-1]};

integer fd1,c2;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			fd1 = $fopen("ae_response_input.bin", "wb");
			dump1 <= 1;
			end
		else if (counter <NoOfInputs && dump1 == 1)
			for (c2 = 0; c2 < 16/8; c2 = c2 + 1)
				$fwrite(fd1, "%c", _prev_ae_response[(c2*8)+:8]);
		else if (dump1 == 1) begin
		    dump1 <= 0;
			$fflush(fd1);
			$fclose(fd1);
			end
			else begin
			dump1 <= dump1;
			end 			
	end

initial begin
	// ---------------------------------------------------------------------------
	// 时钟/复位产生
	// ---------------------------------------------------------------------------
	// `pclk`：20ns 周期（50MHz）
	// `rst_n`：低有效复位，保持 20ns 后释放
	rst_n = 0;
	pclk = 0; 
	#20
	rst_n = 1;
end

always #10 begin
pclk = ~pclk;
end
endmodule