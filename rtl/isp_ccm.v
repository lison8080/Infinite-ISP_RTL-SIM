/*************************************************************************
> File Name: isp_ccm.v
> Description: Applies the 3x3 color correction matrix on the image
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Color Correction Matrix
 */

module isp_ccm
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
)
(
	input pclk,
	input rst_n,

	input signed [15:0] m_rr, m_rg, m_rb, //format S8.8
	input signed [15:0] m_gr, m_gg, m_gb,
	input signed [15:0] m_br, m_bg, m_bb,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_r,
	input [BITS-1:0] in_g,
	input [BITS-1:0] in_b,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b
);

	// Correction operation is given as below:
	// [Rout]   [Mrr, Mrg, Mrb]   [Rin]
	// [Gout] = [Mgr, Mgg, Mgb] * [Gin]
	// [Bout]   [Mbr, Mbg, Mbb]   [Bin]

	//Registering correction matrix

	reg signed [15:0] m_rr_i, m_rg_i, m_rb_i; //format S8.8
	reg signed [15:0] m_gr_i, m_gg_i, m_gb_i;
	reg signed [15:0] m_br_i, m_bg_i, m_bb_i;
	
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			m_rr_i <= 0;
			m_rg_i <= 0;
			m_rb_i <= 0;
			m_gr_i <= 0;
			m_gg_i <= 0;
			m_gb_i <= 0;
			m_br_i <= 0;
			m_bg_i <= 0;
			m_bb_i <= 0;
		end
		else begin
			m_rr_i <= m_rr;
			m_rg_i <= m_rg;
			m_rb_i <= m_rb;
			m_gr_i <= m_gr;
			m_gg_i <= m_gg;
			m_gb_i <= m_gb;
			m_br_i <= m_br;
			m_bg_i <= m_bg;
			m_bb_i <= m_bb;
		end
	end

	//Registering input pixels

	reg signed [BITS:0] in_r_1, in_g_1, in_b_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			in_r_1 <= 0;
			in_g_1 <= 0;
			in_b_1 <= 0;
		end
		else begin
			in_r_1 <= {1'b0, in_r};
			in_g_1 <= {1'b0, in_g};
			in_b_1 <= {1'b0, in_b};
		end
	end
 
    // Multiplication of input pixel values with weights of the CCM

	reg signed [BITS+16:0] data_rr, data_rg, data_rb;
	reg signed [BITS+16:0] data_gr, data_gg, data_gb;
	reg signed [BITS+16:0] data_br, data_bg, data_bb;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_rr <= 0;
			data_rg <= 0;
			data_rb <= 0;
			data_gr <= 0;
			data_gg <= 0;
			data_gb <= 0;
			data_br <= 0;
			data_bg <= 0;
			data_bb <= 0;
		end
		else begin
			data_rr <= m_rr_i * in_r_1;
			data_rg <= m_rg_i * in_g_1;
			data_rb <= m_rb_i * in_b_1;
			data_gr <= m_gr_i * in_r_1;
			data_gg <= m_gg_i * in_g_1;
			data_gb <= m_gb_i * in_b_1;
			data_br <= m_br_i * in_r_1;
			data_bg <= m_bg_i * in_g_1;
			data_bb <= m_bb_i * in_b_1;
		end
	end

    // accumulation and normalization

	reg signed [BITS+16:0] data_r, data_g, data_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r <= 0;
			data_g <= 0;
			data_b <= 0;
		end
		else begin
			data_r <= (data_rr + data_rg + data_rb) >>> 10; // as we have to drop the decimal part,
			data_g <= (data_gr + data_gg + data_gb) >>> 10; // so signed shifting the values after addition
			data_b <= (data_br + data_bg + data_bb) >>> 10;
		end
	end

    //clipping the data to bring it within the range

	reg [BITS-1:0] data_r_1, data_g_1, data_b_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r_1 <= 0;
			data_g_1 <= 0;
			data_b_1 <= 0;
		end
		else begin
            data_r_1 <= data_r[BITS+16] ? {BITS{1'b0}} : ((data_r[BITS-1+16:BITS] || 1'b0) ? {BITS{1'b1}} : {data_r[BITS-1:0]});
			data_g_1 <= data_g[BITS+16] ? {BITS{1'b0}} : ((data_g[BITS-1+16:BITS] || 1'b0) ? {BITS{1'b1}} : {data_g[BITS-1:0]});
			data_b_1 <= data_b[BITS+16] ? {BITS{1'b0}} : ((data_b[BITS-1+16:BITS] || 1'b0) ? {BITS{1'b1}} : {data_b[BITS-1:0]});
		end
	end

    // Adjusting for computation delay

	localparam DLY_CLK = 4;
	reg [DLY_CLK-1:0] href_dly;
	reg [DLY_CLK-1:0] vsync_dly;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			href_dly <= 0;
			vsync_dly <= 0;
		end
		else begin
			href_dly <= {href_dly[DLY_CLK-2:0], in_href};
			vsync_dly <= {vsync_dly[DLY_CLK-2:0], in_vsync};
		end
	end

	assign out_href = href_dly[DLY_CLK-1];
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_r = out_href ? data_r_1 : {BITS{1'b0}};
	assign out_g = out_href ? data_g_1 : {BITS{1'b0}};
	assign out_b = out_href ? data_b_1 : {BITS{1'b0}};
endmodule