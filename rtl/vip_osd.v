/*************************************************************************
> File Name: vip_osd.v
> Description: Puts a logo on the final pipeline image
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * VIP - On Screen Display
 */

module vip_osd
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter OSD_RAM_ADDR_BITS = 9,
	parameter OSD_RAM_DATA_BITS = 32 //RAM总大小(即OSD图片最大像素数)为OSD_RAM_DATA_BITS*(1<<OSD_RAM_ADDR_BITS)
)
(
	input pclk,
	input rst_n,

	//osd位置(不能超过时序图像范围, 宽高乘积不能超过RAM总大小)
	input [clogb2(WIDTH)-1:0]  osd_x, //starting x of window
	input [clogb2(HEIGHT)-1:0] osd_y, //starting y of window
	input [clogb2(WIDTH)-1:0]  osd_w, //x + w => total width of window
	input [clogb2(HEIGHT)-1:0] osd_h, // y + h => total height of window
	//前景色,背景色
	input [BITS-1:0] fg_color_r,
	input [BITS-1:0] fg_color_g,
	input [BITS-1:0] fg_color_b,
	input [BITS-1:0] bg_color_r,
	input [BITS-1:0] bg_color_g,
	input [BITS-1:0] bg_color_b,
	
	input [7:0] alpha, //alpha parameter input for alpha blending

	input             in_href,
	input             in_vsync,
	input [BITS-1:0]  in_data_r,
	input [BITS-1:0]  in_data_g,
	input [BITS-1:0]  in_data_b,

	output            out_href,
	output            out_vsync,
	output [BITS-1:0] out_data_r,
	output [BITS-1:0] out_data_g,
	output [BITS-1:0] out_data_b,

	//单色位图RAM接口
	input                          osd_ram_clk,
	input                          osd_ram_wen,
	input                          osd_ram_ren,
	input  [OSD_RAM_ADDR_BITS-1:0] osd_ram_addr,
	input  [OSD_RAM_DATA_BITS-1:0] osd_ram_wdata,
	output [OSD_RAM_DATA_BITS-1:0] osd_ram_rdata
);

	reg href_t1, href_t2, href_t3, href_t4, href_t5, href_t6;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			href_t1 <= 0;
			href_t2 <= 0;
			href_t3 <= 0;
			href_t4 <= 0;
			href_t5 <= 0;
			href_t6 <= 0;
		end
		else begin
			href_t1 <= in_href;
			href_t2 <= href_t1;
			href_t3 <= href_t2;
			href_t4 <= href_t3;
			href_t5 <= href_t4;
			href_t6 <= href_t5;
		end
	end

	reg vsync_t1, vsync_t2, vsync_t3, vsync_t4, vsync_t5, vsync_t6;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			vsync_t1 <= 0;
			vsync_t2 <= 0;
			vsync_t3 <= 0;
			vsync_t4 <= 0;
			vsync_t5 <= 0;
			vsync_t6 <= 0;
		end
		else begin
			vsync_t1 <= in_vsync;
			vsync_t2 <= vsync_t1;
			vsync_t3 <= vsync_t2;
			vsync_t4 <= vsync_t3;
			vsync_t5 <= vsync_t4;
			vsync_t6 <= vsync_t5;
		end
	end

	reg [3*BITS-1:0] data_t1, data_t2, data_t3, data_t4, data_t5;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_t1 <= 0;
			data_t2 <= 0;
			data_t3 <= 0;
			data_t4 <= 0;
			data_t5 <= 0;
		end
		else begin
			data_t1 <= {in_data_r, in_data_g, in_data_b};
			data_t2 <= data_t1;
			data_t3 <= data_t2;
			data_t4 <= data_t3;
			data_t5 <= data_t4;
		end
	end

	reg [clogb2(WIDTH)-1:0] pix_x_t1;
	always @ (posedge pclk or negedge rst_n) begin // this always block is simply incrementing a count variable for each row that sets to zero at start of row
		if (!rst_n)
			pix_x_t1 <= 0;
		else if (in_href & ~href_t1) //posedge of in_href 
			pix_x_t1 <= 0;
		else if (in_href)
			pix_x_t1 <= pix_x_t1 + 1'b1;
		else
			pix_x_t1 <= pix_x_t1;
	end

	reg [clogb2(HEIGHT)-1:0] pix_y_t1;
	always @ (posedge pclk or negedge rst_n) begin // this always block is implementing a counter that sets to zero on every frame and increments on end of every row
		if (!rst_n)
			pix_y_t1 <= 0; 
		else if (vsync_t1 & ~in_vsync) //Negedge of in_vsync
			pix_y_t1 <= 0;
		else if (href_t1 & ~in_href) //Negedge of in_href
			pix_y_t1 <= pix_y_t1 + 1'b1;
		else
			pix_y_t1 <= pix_y_t1;
	end

	reg [clogb2(WIDTH)-1:0]  osd_x0_r, osd_x1_r;
	reg [clogb2(HEIGHT)-1:0] osd_y0_r, osd_y1_r;
	reg [3*BITS-1:0] color_fg_r, color_bg_r;
	always @ (posedge pclk or negedge rst_n) begin // This always block is making sure that osd window parameters are valid  or they will be set to zero
		if (!rst_n) begin                          // Also passing the foreground and background color values
			osd_x0_r <= 0; 
			osd_x1_r <= 0;
			osd_y0_r <= 0;
			osd_y1_r <= 0;
			color_fg_r <= 0;
			color_bg_r <= 0;
		end
		else if (vsync_t1 & ~in_vsync) begin
			osd_x0_r <= (osd_x < WIDTH) ? osd_x : 0;
			osd_x1_r <= (osd_x + osd_w <= WIDTH) ? (osd_x + osd_w) : 0;
			osd_y0_r <= (osd_y <= HEIGHT) ? osd_y : 0;
			osd_y1_r <= (osd_y + osd_h <= HEIGHT) ? (osd_y + osd_h) : 0;
			color_fg_r <= {fg_color_r, fg_color_g, fg_color_b};
			color_bg_r <= {bg_color_r, bg_color_g, bg_color_b};
		end
		else begin
			osd_x0_r <= osd_x0_r;
			osd_x1_r <= osd_x1_r;
			osd_y0_r <= osd_y0_r;
			osd_y1_r <= osd_y1_r;
			color_fg_r <= color_fg_r;
			color_bg_r <= color_bg_r;
		end
	end
	
	reg [BITS+7:0] alpha_blending_fg_r, alpha_blending_bg_r;
	reg [BITS+7:0] alpha_blending_fg_g, alpha_blending_bg_g;
	reg [BITS+7:0] alpha_blending_fg_b, alpha_blending_bg_b;
	always @ (posedge pclk or negedge rst_n) begin //Alpha Blending (Foreground and background colors are fixed 24 bit values (8 bits for each RGB channel))
		if (!rst_n) begin
			alpha_blending_fg_r <= 0;
			alpha_blending_bg_r <= 0;
			alpha_blending_fg_g <= 0;
			alpha_blending_bg_g <= 0;
			alpha_blending_fg_b <= 0;
			alpha_blending_bg_b <= 0;
		end
		else begin
			alpha_blending_fg_r <= color_fg_r[23:16] * alpha; //alpha * foreground (R channel)
			alpha_blending_bg_r <= color_bg_r[23:16] * alpha; //alpha * background (R channel)
			alpha_blending_fg_g <= color_fg_r[15:8] * alpha; //alpha * foreground (G channel)
			alpha_blending_bg_g <= color_bg_r[15:8] * alpha; //alpha * background (G channel)
			alpha_blending_fg_b <= color_fg_r[7:0] * alpha; //alpha * foreground (B channel)
			alpha_blending_bg_b <= color_bg_r[7:0] * alpha; //alpha * background (B channel)
		end
	end
	
	reg [BITS+7:0] alpha_blending_fg_r_1;
	reg [BITS+7:0] alpha_blending_fg_g_1;
	reg [BITS+7:0] alpha_blending_fg_b_1;
	always @ (posedge pclk or negedge rst_n) begin //As alpha is fix 8-bit number hence using hard coded 255 
		if (!rst_n) begin
			alpha_blending_fg_r_1 <= 0;
			alpha_blending_fg_g_1 <= 0;
			alpha_blending_fg_b_1 <= 0;
		end
		else begin
			alpha_blending_fg_r_1 <= in_data_r * (8'd255 - alpha); //(1-alpha) * pixel_value
			alpha_blending_fg_g_1 <= in_data_g * (8'd255 - alpha); //(1-alpha) * pixel_value
			alpha_blending_fg_b_1 <= in_data_b * (8'd255 - alpha); //(1-alpha) * pixel_value
		end
	end
	
	reg [BITS+7:0] alpha_blending_fg_r_2, alpha_blending_bg_r_2;
	reg [BITS+7:0] alpha_blending_fg_g_2, alpha_blending_bg_g_2;
	reg [BITS+7:0] alpha_blending_fg_b_2, alpha_blending_bg_b_2;
	always @ (posedge pclk or negedge rst_n) begin // Addition of above calculated intermediate results for alpha blending
		if (!rst_n) begin
			alpha_blending_fg_r_2 <= 0;
			alpha_blending_bg_r_2 <= 0;
			alpha_blending_fg_g_2 <= 0;
			alpha_blending_bg_g_2 <= 0;
			alpha_blending_fg_b_2 <= 0;
			alpha_blending_bg_b_2 <= 0;
		end
		else begin
			alpha_blending_fg_r_2 <= alpha_blending_fg_r + alpha_blending_fg_r_1;
			alpha_blending_bg_r_2 <= alpha_blending_bg_r + alpha_blending_fg_r_1;
			alpha_blending_fg_g_2 <= alpha_blending_fg_g + alpha_blending_fg_g_1;
			alpha_blending_bg_g_2 <= alpha_blending_bg_g + alpha_blending_fg_g_1;
			alpha_blending_fg_b_2 <= alpha_blending_fg_b + alpha_blending_fg_b_1;
			alpha_blending_bg_b_2 <= alpha_blending_bg_b + alpha_blending_fg_b_1;
		end
	end
	
	reg [BITS-1:0] alpha_blending_fg_r_3, alpha_blending_bg_r_3;
	reg [BITS-1:0] alpha_blending_fg_g_3, alpha_blending_bg_g_3;
	reg [BITS-1:0] alpha_blending_fg_b_3, alpha_blending_bg_b_3;
	always @ (posedge pclk or negedge rst_n) begin //As alpha is a 8 bit fix point number hence right shifting it by 8
		if (!rst_n) begin
			alpha_blending_fg_r_3 <= 0;
			alpha_blending_bg_r_3 <= 0;
			alpha_blending_fg_g_3 <= 0;
			alpha_blending_bg_g_3 <= 0;
			alpha_blending_fg_b_3 <= 0;
			alpha_blending_bg_b_3 <= 0;
		end
		else begin
			alpha_blending_fg_r_3 <= alpha_blending_fg_r_2 >> 8;
			alpha_blending_bg_r_3 <= alpha_blending_bg_r_2 >> 8;
			alpha_blending_fg_g_3 <= alpha_blending_fg_g_2 >> 8;
			alpha_blending_bg_g_3 <= alpha_blending_bg_g_2 >> 8;
			alpha_blending_fg_b_3 <= alpha_blending_fg_b_2 >> 8;
			alpha_blending_bg_b_3 <= alpha_blending_bg_b_2 >> 8;
		end
	end
	
	reg [3*BITS-1:0] alpha_blending_fg_4, alpha_blending_bg_4;
	always @ (posedge pclk or negedge rst_n) begin // Concatinating RGB channels (just to reduce signals and make operations simpler)
		if (!rst_n) begin
			alpha_blending_fg_4 <= 0;
			alpha_blending_bg_4 <= 0;
		end
		else begin
			alpha_blending_fg_4 <= {alpha_blending_fg_r_3, alpha_blending_fg_g_3, alpha_blending_fg_b_3};
			alpha_blending_bg_4 <= {alpha_blending_bg_r_3, alpha_blending_bg_g_3, alpha_blending_bg_b_3};
		end
	end
	
	reg [3*BITS-1:0] alpha_blending_fg_5, alpha_blending_bg_5;
	always @ (posedge pclk or negedge rst_n) begin //Had to add another pipeline stage for latency
		if (!rst_n) begin
			alpha_blending_fg_5 <= 0;
			alpha_blending_bg_5 <= 0;
		end
		else begin
			alpha_blending_fg_5 <= alpha_blending_fg_4;
			alpha_blending_bg_5 <= alpha_blending_bg_4;
		end
	end
	
	reg osd_on_t2, osd_on_t3, osd_on_t4, osd_on_t5;
	always @ (posedge pclk or negedge rst_n) begin // This always block is checking when OSD window is on by making osd_on_t2 valid 
		if (!rst_n) begin
			osd_on_t2 <= 0;
			osd_on_t3 <= 0;
			osd_on_t4 <= 0;
			osd_on_t5 <= 0;
		end
		else begin
			osd_on_t2 <= (pix_x_t1 >= osd_x0_r) && (pix_x_t1 < osd_x1_r) && (pix_y_t1 >= osd_y0_r) && (pix_y_t1 < osd_y1_r);
			osd_on_t3 <= osd_on_t2;
			osd_on_t4 <= osd_on_t3;
			osd_on_t5 <= osd_on_t4;
		end
	end

	reg [OSD_RAM_ADDR_BITS-1:0]         osd_raddr_t3;
	reg [clogb2(OSD_RAM_DATA_BITS-1)-1:0] osd_pix_idx_t3;
	always @ (posedge pclk or negedge rst_n) begin //This always block is an address generator for the logo bitmap data (stored in RAM)
		if (!rst_n) begin
			osd_raddr_t3   <= 0;
			osd_pix_idx_t3 <= 0;
		end
		else if (~vsync_t2 & vsync_t3) begin
			osd_raddr_t3   <= {OSD_RAM_ADDR_BITS{1'b1}}; //置最大值,以便在下一个osd_on变为初始值0
			osd_pix_idx_t3 <= OSD_RAM_DATA_BITS-1'b1;	 //置最大值,以便在下一个osd_on变为初始值0
		end
		else if (href_t2 & osd_on_t2) begin
			if (osd_pix_idx_t3 == OSD_RAM_DATA_BITS-1'b1) begin
				osd_raddr_t3   <= osd_raddr_t3 + 1'b1;
				osd_pix_idx_t3 <= 0;
			end
			else begin
				osd_raddr_t3   <= osd_raddr_t3;
				osd_pix_idx_t3 <= osd_pix_idx_t3 + 1'b1;
			end
		end
		else begin
			osd_raddr_t3   <= osd_raddr_t3;
			osd_pix_idx_t3 <= osd_pix_idx_t3;
		end
	end
	
	wire [OSD_RAM_DATA_BITS-1:0] osd_pix_buf_t4; //Storing logo bitmap data in RAM
	full_dp_ram #(OSD_RAM_DATA_BITS,OSD_RAM_ADDR_BITS) osd_ram (
			.clk_a(osd_ram_clk),
			.wen_a(osd_ram_wen),
			.ren_a(osd_ram_ren),
			.addr_a(osd_ram_addr),
			.wdata_a(osd_ram_wdata),
			.rdata_a(osd_ram_rdata),
			.clk_b(pclk),
			.wen_b(1'b0),
			.ren_b(href_t3),
			.addr_b(osd_raddr_t3),
			.wdata_b({OSD_RAM_DATA_BITS{1'b0}}),
			.rdata_b(osd_pix_buf_t4)
		);

	reg [clogb2(OSD_RAM_DATA_BITS)-1:0] osd_pix_idx_t4;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			osd_pix_idx_t4 <= 0;
		else
			osd_pix_idx_t4 <= osd_pix_idx_t3;
	end

	reg [OSD_RAM_DATA_BITS-1:0] osd_pix_buf_t5;
	always @ (posedge pclk or negedge rst_n) begin //shifting bit right to update adress for data reading from RAM 
		if (!rst_n)
			osd_pix_buf_t5 <= 0;
		else if (osd_pix_idx_t4 == 0)
			osd_pix_buf_t5 <= osd_pix_buf_t4;
		else if (osd_on_t4 & href_t4)
			osd_pix_buf_t5 <= {osd_pix_buf_t5[OSD_RAM_DATA_BITS-2:0], 1'b0};
		else
			osd_pix_buf_t5 <= osd_pix_buf_t5;
	end
	
	reg [3*BITS-1:0] data_t6;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			data_t6 <= 0;
		else if (href_t5) 
		    if ((osd_w > 256) || (osd_h > 128)) // Check on maximum width and height support for OSD (if condition is failed, no logo)
		        data_t6 <= data_t5; 
			else if (osd_on_t5) // When logo window region hits
				data_t6 <= osd_pix_buf_t5[OSD_RAM_DATA_BITS-1] ? alpha_blending_fg_5 : alpha_blending_bg_5; //selecting between foreground and backround colors depending upon bitmap data
			else
				data_t6 <= data_t5; //rest of the frame (simply pass input pixels to output
		else
			data_t6 <= 0;
	end

	assign out_href  = href_t6;
	assign out_vsync = vsync_t6;
	assign out_data_r  = data_t6[3*BITS-1:2*BITS];
	assign out_data_g  = data_t6[2*BITS-1:BITS];
	assign out_data_b  = data_t6[BITS-1:0];

	function integer clogb2;
	input integer depth;
	begin
		for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
			depth = depth >> 1;
	end
	endfunction
endmodule