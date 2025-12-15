/*************************************************************************
> File Name: tb_shift_div.v
> Description: Test bench for shift divider
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps


module tb_shift_div;

// -----------------------------------------------------------------------------
// 功能说明
// -----------------------------------------------------------------------------
// 本测试平台用于验证 `shift_div`（移位除法器 / 逐步迭代除法）模块的功能与时序。
//
// 测试方法：
// 1) 从文本文件 `test_vector.txt` 读取多组被除数(dividend)与除数(divisor)。
// 2) 当 DUT 输出 `done` 表示一次除法完成时，在下一个 `done` 上升沿：
//    - 记录上一次运算输出的商 `c`、余数 `d`
//    - 同时装载下一组输入 `a`、`b`
// 3) 在仿真过程中额外将输入/输出按 `done==1` 时刻写入二进制文件，便于离线对比。
//
// 输出文件：
// - `fsm_dividend.bin`  : 每次 done 时写入一次被除数（扩展到 64bit 便于写文件）
// - `fsm_divisor.bin`   : 每次 done 时写入一次除数（扩展到 64bit）
// - `fsm_quotient.bin`  : 每次 done 时写入一次商（扩展到 64bit）
// - `fsm_remainder.bin` : 每次 done 时写入一次余数（扩展到 64bit）
// -----------------------------------------------------------------------------
localparam BITS = 48;

reg clk;
reg rst_n;
reg enable;
reg [BITS-1:0] a; 
reg [BITS-1:0] b;

wire [BITS-1:0] c;
wire [BITS-1:0] d;
wire done;

// -----------------------------------------------------------------------------
// DUT 实例化
// -----------------------------------------------------------------------------
// 端口使用位置连接：
//   (clk, rst_n, enable, a, b, c, d, done)
shift_div #(BITS) shift_div_i0 (clk, rst_n, enable , a, b, c , d, done);  

// Number of inputs for which output is to be tested
localparam NoOfInputs = 11;
reg [BITS-1:0] dividend[NoOfInputs-1:0];
reg [BITS-1:0] divisor[NoOfInputs-1:0];
reg [BITS-1:0] quotient[NoOfInputs-1:0];
reg [BITS-1:0] remainder[NoOfInputs-1:0];

  // ---------------------------------------------------------------------------
  // 从文本文件读取测试向量
  // ---------------------------------------------------------------------------
  // 文件格式：每行两个十进制整数（被除数、除数），使用空格分隔。
  // 注意：这里先用 64bit 临时变量读入，再截断赋值到 BITS(=48) 位数组。
  reg [63:0] number1;
  reg [63:0] number2;
  integer file;
  integer result;
  integer i;  
  
  initial begin
    i = 0;
    file = $fopen("test_vector.txt", "r"); // Open the file for reading
    if (file == 0) begin
      $display("Error opening file");
      $finish;
    end
    while (!$feof(file)) begin
      result = $fscanf(file, "%d %d", number1, number2); // Read two numbers separated by a space
      if (result == 2) begin
        dividend[i] = number1;
        divisor[i] = number2;
        i = i + 1;
      end else begin
        $display("Error reading numbers from file");
      end
    end
    $fclose(file); // Close the file
    end




initial begin

// -----------------------------------------------------------------------------
// 时钟/复位产生
// -----------------------------------------------------------------------------
// `clk`：20ns 周期（always #10 翻转）
// `rst_n`：低有效复位，保持 20ns 后释放
clk = 0;
rst_n = 0;
#20 
rst_n = 1;
end 

reg [11:0] count;
always @ (posedge done or negedge rst_n ) begin
if (!rst_n) begin
    // 复位时初始化：
    // - count=0：指向第 0 组输入
    // - a/b：给一个非 0 的初值，避免除数为 0
    // - enable=1：启动除法器
    count <= 0;
    a <= 0;
    b <= 1;
    enable <= 1;
    end 
else if (count < NoOfInputs) begin // giving a new input to the divider when done
    // done 上升沿：说明上一组输入已经计算完成
    // - 将本次输出 c/d 存入数组（与当前 count 对应）
    // - 装载下一组输入 a/b
    count <= count + 1;
    a <= dividend[count];
    b <= divisor[count];
    quotient[count] <= c;
    remainder[count] <= d;
    end
else begin
    count <= 0;
    end 
end

// -----------------------------------------------------------------------------
// 导出计数器：控制文件写入的时间窗口
// -----------------------------------------------------------------------------
// 该计数器用于估算/限制写入次数，避免仿真无限写文件。
reg [11:0] clk_counter;
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_counter <= 0;
        end
    else if (clk_counter < (NoOfInputs+1)*(BITS*2+4)) begin
        clk_counter <= clk_counter + 1;
        end
    else begin
        clk_counter <= 0;
        end
end
    
    
// -----------------------------------------------------------------------------
// dumping logic：将输入/输出在 done 时刻写入文件
// -----------------------------------------------------------------------------
// 为便于外部脚本按字节读取，这里把 48bit 扩展为 64bit，再按字节写入二进制文件。
wire [63:0] _quotient, _dividend, _divisor,_remiander;
reg dump0;
assign _dividend = {32'd0,a};
assign _divisor = {32'd0,b};	
assign _quotient = {32'd0,c};
assign _remiander = {32'd0,d};
integer fd1, c1, fd2, c2, fd3, c3, fd4,c4;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			fd1 = $fopen("fsm_dividend.bin", "wb");
			fd2 = $fopen("fsm_divisor.bin", "wb");
			fd3 = $fopen("fsm_quotient.bin", "wb");
			fd4 = $fopen("fsm_remainder.bin", "wb");
			dump0 <= 1;
			end
		else if (clk_counter < ((NoOfInputs+1)*(BITS*2+4)  ) && dump0 == 1 && done == 1) begin
			// 当 done==1 时写入一次当前 a/b/c/d（按 64bit 逐字节写出）
			for (c1 = 0; c1 < 64/8; c1 = c1 + 1)
				$fwrite(fd1, "%c", _dividend[(c1*8)+:8]);
			for (c2 = 0; c2 < 64/8; c2 = c2 + 1)
				$fwrite(fd2, "%c", _divisor[(c2*8)+:8]);
			for (c3 = 0; c3 < 64/8; c3 = c3 + 1)
				$fwrite(fd3, "%c", _quotient[(c3*8)+:8]);
			for (c4 = 0; c4 < 64/8; c4 = c4 + 1)
				$fwrite(fd4, "%c", _remiander[(c4*8)+:8]);
			end
		else if (dump0 == 1 && clk_counter == ((NoOfInputs+1)*(BITS*2+4)) && done == 1) begin
			// 达到预设写入次数后关闭文件
		         dump0 <= 0;
			     $fflush(fd1);
			     $fclose(fd1);
			     $fflush(fd2);
			     $fclose(fd2);
			     $fflush(fd3);
			     $fclose(fd3);
			     $fflush(fd4);
			     $fclose(fd4);
			     end
			 else begin
			     dump0 <= dump0;
			 end
						
	end



always 
#10 clk = ~clk;

endmodule
