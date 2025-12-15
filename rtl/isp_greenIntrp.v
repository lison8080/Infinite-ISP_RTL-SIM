/*************************************************************************
> File Name: isp_greenintrp.v
> Description: Apply Green interpolation filter
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Greeen Interpolation
 */

module isp_greenIntrp
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_raw
);
    
	// Tracking even/odd pixels for pixel's bayer detection
    reg odd_pix;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			odd_pix <= 0;
		else if (!in_href)
			odd_pix <= 0;
		else
			odd_pix <= ~odd_pix;
	end
	
	// Register the in_href value
	reg prev_href;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			prev_href <= 0;
		else
			prev_href <= in_href;
	end	
	
	// Tracking even/odd line for pixel's bayer detection
	reg odd_line;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			odd_line <= 0;
		else if (in_vsync)
			odd_line <= 0;
		else if (prev_href & (~in_href))
			odd_line <= ~odd_line;
		else
			odd_line <= odd_line;
	end

	wire [1:0] format = BAYER[1:0] ^ {odd_line, odd_pix}; //pixel format 0:[R]GGB 1:R[G]GB 2:RG[G]B 3:RGG[B]
	
	// As we have window size of 5x5 so need to save first four rows and current input row is realized with shift registers p5x
	wire [BITS-1:0] shiftout;
	wire [BITS-1:0] tap3x, tap2x, tap1x, tap0x;
	shift_register #(BITS, WIDTH, 4) linebuffer(pclk, in_href, in_raw, shiftout, {tap3x, tap2x, tap1x, tap0x});
	
	reg [BITS-1:0] in_raw_r;
	reg [BITS-1:0] p11,p12,p13,p14,p15;
	reg [BITS-1:0] p21,p22,p23,p24,p25;
	reg [BITS-1:0] p31,p32,p33,p34,p35;
	reg [BITS-1:0] p41,p42,p43,p44,p45;
	reg [BITS-1:0] p51,p52,p53,p54,p55;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			in_raw_r <= 0;
			p11 <= 0; p12 <= 0; p13 <= 0; p14 <= 0; p15 <= 0;
			p21 <= 0; p22 <= 0; p23 <= 0; p24 <= 0; p25 <= 0;
			p31 <= 0; p32 <= 0; p33 <= 0; p34 <= 0; p35 <= 0;
			p41 <= 0; p42 <= 0; p43 <= 0; p44 <= 0; p45 <= 0;
			p51 <= 0; p52 <= 0; p53 <= 0; p54 <= 0; p55 <= 0;
		end
		else begin
			in_raw_r <= in_raw;
			p11 <= p12; p12 <= p13; p13 <= p14; p14 <= p15; p15 <= tap3x;
			p21 <= p22; p22 <= p23; p23 <= p24; p24 <= p25; p25 <= tap2x;
			p31 <= p32; p32 <= p33; p33 <= p34; p34 <= p35; p35 <= tap1x;
			p41 <= p42; p42 <= p43; p43 <= p44; p44 <= p45; p45 <= tap0x;
			p51 <= p52; p52 <= p53; p53 <= p54; p54 <= p55; p55 <= in_raw_r;
		end
	end

	
	
	//Stage 1: Selecting the corresponding pixels of raw image for green extraction
	reg [1:0] fmt_0;
	reg signed [BITS+6:0] g_t1_p13, g_t1_p23, g_t1_p31;
	reg signed [BITS+6:0] g_t1_p32, g_t1_p33, g_t1_p34;
	reg signed [BITS+6:0] g_t1_p35, g_t1_p43, g_t1_p53;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			fmt_0 <= 0;
			g_t1_p13 <= 0; g_t1_p23 <= 0; g_t1_p31 <= 0;
			g_t1_p32 <= 0; g_t1_p33 <= 0; g_t1_p34 <= 0;
			g_t1_p35 <= 0; g_t1_p43 <= 0; g_t1_p53 <= 0;
		end
		else begin
			fmt_0 <= format;
			g_t1_p13 <= {7'b0,p13}; g_t1_p23 <= {7'b0,p23}; g_t1_p31 <= {7'b0,p31};
			g_t1_p32 <= {7'b0,p32}; g_t1_p33 <= {7'b0,p33}; g_t1_p34 <= {7'b0,p34};
			g_t1_p35 <= {7'b0,p35}; g_t1_p43 <= {7'b0,p43}; g_t1_p53 <= {7'b0,p53};
		end
	end

	//Stage 2: Applying filter 
	reg [1:0] fmt_1;
	reg [BITS-1:0] original;
	reg signed [BITS+6:0] g_t2_p13, g_t2_p23, g_t2_p31;
	reg signed [BITS+6:0] g_t2_p32, g_t2_p33, g_t2_p34;
	reg signed [BITS+6:0] g_t2_p35, g_t2_p43, g_t2_p53;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original <= 0;
            fmt_1 <= 0;
			g_t2_p13 <= 0; g_t2_p23 <= 0; g_t2_p31 <= 0;
			g_t2_p32 <= 0; g_t2_p33 <= 0; g_t2_p34 <= 0;
			g_t2_p35 <= 0; g_t2_p43 <= 0; g_t2_p53 <= 0;
		end
		else begin
			original <= g_t1_p33[BITS-1:0];
            fmt_1 <= fmt_0;
			g_t2_p13 <= g_t1_p13 * -1;
			g_t2_p23 <= g_t1_p23 * 2 ;
			g_t2_p31 <= g_t1_p31 * -1;
			g_t2_p32 <= g_t1_p32 * 2;
			g_t2_p33 <= g_t1_p33 * 4;
			g_t2_p34 <= g_t1_p34 * 2;
			g_t2_p35 <= g_t1_p35 * -1;
			g_t2_p43 <= g_t1_p43 * 2;
			g_t2_p53 <= g_t1_p53 * -1;
		end
	end

	//stage 3 Accumulation
	reg [1:0] fmt_2;
	reg [BITS-1:0] original_1;
	reg signed [BITS+6:0] g_t3_p33, g_t3_p33_i;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original_1 <= 0;
			g_t3_p33_i <= 0;
			fmt_2 <= 0;
		end
		else begin
			original_1 <= original;
			fmt_2 <= fmt_1;
			g_t3_p33_i <= (g_t2_p13 + g_t2_p23 + g_t2_p31 + g_t2_p32 + g_t2_p33 + g_t2_p34 + g_t2_p35 + g_t2_p43 + g_t2_p53);
		end
		
		
	end

	//stage 4 Division
	reg [BITS-1:0] original_2;
	reg [1:0] fmt_3 ;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original_2 <= 0;
			fmt_3 <= 0;
			g_t3_p33 <= 0;
		end
		else begin
			original_2 <= original_1;
			fmt_3 <= fmt_2;
			g_t3_p33 = g_t3_p33_i >>> 3;
		end
	end
	
	// clipping
	wire [BITS-1:0] g_t4_p33i;
    assign g_t4_p33i = g_t3_p33[BITS+6] ? {BITS{1'b0}} : ((g_t3_p33[BITS-1+6:BITS] || 1'b0) ? {BITS{1'b1}} : g_t3_p33[BITS-1:0]) ;
	
	//stage 5 selecting orignal value for GR and GB pixels and interplated values otherwise
	reg [BITS-1:0] g_t4_p33;
	reg [BITS-1:0] raw;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			g_t4_p33 <= 0;
			raw <= 0;
		end
		else if((fmt_3 == 1) || fmt_3 == 2)begin  // this needs modification
			g_t4_p33 <= original_2;
			raw <= original_2;
			
		end
		else begin
		    g_t4_p33 <= g_t4_p33i ;
			raw <= original_2;
			end
	end
        
   
	// Adjusting for computation delay
	localparam DLY_CLK = 9;
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
	assign out_g = out_href ? g_t4_p33 : {BITS{1'b0}};
	assign out_raw = out_href ? raw : {BITS{1'b0}};

endmodule