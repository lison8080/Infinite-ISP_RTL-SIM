/*************************************************************************
> File Name: isp_demosaic.v
> Description: Implements the cfa interpolation (RAW -> RGB)
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Demosaic (RAW -> RGB)
 */

module isp_demosaic
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
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b
);
  
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

    //Keeping track if current pixel is even or odd

	reg odd_pix;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			odd_pix <= 0;
		else if (!in_href)
			odd_pix <= 0;
		else
			odd_pix <= ~odd_pix;
	end
	
	reg prev_href;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			prev_href <= 0;
		else
			prev_href <= in_href;
	end	
	
	//Keeping track if current row is even or odd

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

	// compuational pipeline delay t1

	reg odd_pix_1, odd_line_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			odd_pix_1 <= 0;
			odd_line_1 <= 0;
		end
		else begin
			odd_pix_1 <= odd_pix;
			odd_line_1 <= odd_line;
		end
	end

    // compuational pipeline delay t2

	reg odd_pix_2, odd_line_2;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			odd_pix_2 <= 0;
			odd_line_2 <= 0;
		end
		else begin
			odd_pix_2 <= odd_pix_1;
			odd_line_2 <= odd_line_1;
		end
	end

    // compuational pipeline delay t3

	reg odd_pix_3, odd_line_3;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			odd_pix_3 <= 0;
			odd_line_3 <= 0;
		end
		else begin
			odd_pix_3 <= odd_pix_2;
			odd_line_3 <= odd_line_2;
		end	
	end

    // compuational pipeline delay t4

	reg odd_pix_4, odd_line_4;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			odd_pix_4 <= 0;
			odd_line_4 <= 0;
		end
		else begin
			odd_pix_4 <= odd_pix_3;
			odd_line_4 <= odd_line_3;
		end
	end
	
	// compuational pipeline delay t5

	reg odd_pix_5, odd_line_5;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            odd_pix_5 <= 0;
            odd_line_5 <= 0;
        end
        else begin
            odd_pix_5 <= odd_pix_4;
            odd_line_5 <= odd_line_4;
        end
    end

    // compuational pipeline delay t6

    reg odd_pix_6, odd_line_6;
    always @(posedge pclk or negedge rst_n) begin
         if (!rst_n) begin
              odd_pix_6 <= 0;
              odd_line_6 <= 0;
         end
         else begin
             odd_pix_6 <= odd_pix_5;
             odd_line_6 <= odd_line_5;
         end
     end

	//Red

	//Stage 1: Selecting the corresponding pixels of raw image for red extraction
	reg signed [BITS+6:0] r_t1_p13;
	reg signed [BITS+6:0] r_t1_p22, r_t1_p23, r_t1_p24;
	reg signed [BITS+6:0] r_t1_p31, r_t1_p32, r_t1_p33, r_t1_p34, r_t1_p35;
	reg signed [BITS+6:0] r_t1_p42, r_t1_p43, r_t1_p44;
	reg signed [BITS+6:0] r_t1_p53;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t1_p13 <= 0;
			r_t1_p22 <= 0; r_t1_p23 <= 0; r_t1_p24 <= 0;
			r_t1_p31 <= 0; r_t1_p32 <= 0; r_t1_p33 <= 0; r_t1_p34 <= 0; r_t1_p35 <= 0;
			r_t1_p42 <= 0; r_t1_p43 <= 0; r_t1_p44 <= 0;
			r_t1_p53 <= 0;
		end
		else begin
			r_t1_p13 <= {7'd0,p13};
			r_t1_p22 <= {7'd0,p22}; r_t1_p23 <= {7'd0,p23}; r_t1_p24 <= {7'd0,p24};
			r_t1_p31 <= {7'd0,p31}; r_t1_p32 <= {7'd0,p32}; r_t1_p33 <= {7'd0,p33}; r_t1_p34 <= {7'd0,p34}; r_t1_p35 <= {7'd0,p35};
			r_t1_p42 <= {7'd0,p42}; r_t1_p43 <= {7'd0,p43}; r_t1_p44 <= {7'd0,p44};
			r_t1_p53 <= {7'd0,p53};
		end
	end

	//Stage 2: Applying filter for RB 
	reg [BITS-1:0] r_original_rb;
	reg signed [BITS+6:0] r_t2_p13_rb;
	reg signed [BITS+6:0] r_t2_p22_rb, r_t2_p24_rb;
	reg signed [BITS+6:0] r_t2_p31_rb, r_t2_p32_rb, r_t2_p33_rb, r_t2_p34_rb, r_t2_p35_rb;
	reg signed [BITS+6:0] r_t2_p42_rb, r_t2_p44_rb;
	reg signed [BITS+6:0] r_t2_p53_rb;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_original_rb <= 0;
			r_t2_p13_rb <= 0;
			r_t2_p22_rb <= 0; r_t2_p24_rb <= 0;
			r_t2_p31_rb <= 0; r_t2_p32_rb <= 0; r_t2_p33_rb <= 0; r_t2_p34_rb <= 0; r_t2_p35_rb <= 0;
			r_t2_p42_rb <= 0; r_t2_p44_rb <= 0;
			r_t2_p53_rb <= 0;
		end
		else begin
			r_original_rb <= r_t1_p33[BITS-1:0];
			r_t2_p13_rb <= r_t1_p13;
			r_t2_p22_rb <= r_t1_p22 * -2 ;
			r_t2_p24_rb <= r_t1_p24 * -2;
			r_t2_p31_rb <= r_t1_p31 * -2;
			r_t2_p32_rb <= r_t1_p32 * 8;
			r_t2_p33_rb <= r_t1_p33 * 10;
			r_t2_p34_rb <= r_t1_p34 * 8;
			r_t2_p35_rb <= r_t1_p35 * -2;
			r_t2_p42_rb <= r_t1_p42 * -2;
			r_t2_p44_rb <= r_t1_p44 * -2;
			r_t2_p53_rb <= r_t1_p53;
		end
	end

	//Stage 2: Applying filter for BR 
	reg signed [BITS+6:0] r_t2_p13_br;
	reg signed [BITS+6:0] r_t2_p22_br, r_t2_p23_br, r_t2_p24_br;
	reg signed [BITS+6:0] r_t2_p31_br, r_t2_p33_br, r_t2_p35_br;
	reg signed [BITS+6:0] r_t2_p42_br, r_t2_p43_br, r_t2_p44_br;
	reg signed [BITS+6:0] r_t2_p53_br;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t2_p13_br <= 0;
			r_t2_p22_br <= 0; r_t2_p23_br <= 0; r_t2_p24_br <= 0;
			r_t2_p31_br <= 0; r_t2_p33_br <= 0; r_t2_p35_br <= 0; 
			r_t2_p42_br <= 0; r_t2_p43_br <= 0; r_t2_p44_br <= 0;
			r_t2_p53_br <= 0;
		end
		else begin
			r_t2_p13_br <= r_t1_p13 * -2;
			r_t2_p22_br <= r_t1_p22 * -2;
			r_t2_p23_br <= r_t1_p23 * 8;
			r_t2_p24_br <= r_t1_p24 * -2;
			r_t2_p31_br <= r_t1_p31;
			r_t2_p33_br <= r_t1_p33 * 10;
			r_t2_p35_br <= r_t1_p35;
			r_t2_p42_br <= r_t1_p42 * -2;
			r_t2_p43_br <= r_t1_p43 * 8;
			r_t2_p44_br <= r_t1_p44 * -2;
			r_t2_p53_br <= r_t1_p53 * -2;
		end
	end
	//Stage 2: Applying filter for BB 
	reg signed [BITS+6:0] r_t2_p13_bb;
	reg signed [BITS+6:0] r_t2_p22_bb, r_t2_p24_bb;
	reg signed [BITS+6:0] r_t2_p31_bb, r_t2_p33_bb, r_t2_p35_bb;
	reg signed [BITS+6:0] r_t2_p42_bb, r_t2_p44_bb;
	reg signed [BITS+6:0] r_t2_p53_bb;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t2_p13_bb <= 0;
			r_t2_p22_bb <= 0; r_t2_p24_bb <= 0;
			r_t2_p31_bb <= 0; r_t2_p33_bb <= 0; r_t2_p35_bb <= 0; 
			r_t2_p42_bb <= 0; r_t2_p44_bb <= 0;
			r_t2_p53_bb <= 0;
		end
		else begin
			r_t2_p13_bb <= r_t1_p13 * -3;
			r_t2_p22_bb <= r_t1_p22 * 4;
			r_t2_p24_bb <= r_t1_p24 * 4;
			r_t2_p31_bb <= r_t1_p31 * -3;
			r_t2_p33_bb <= r_t1_p33 * 12;
			r_t2_p35_bb <= r_t1_p35 * -3;
			r_t2_p42_bb <= r_t1_p42 * 4;
			r_t2_p44_bb <= r_t1_p44 * 4;
			r_t2_p53_bb <= r_t1_p53 * -3;
		end
	end

	//stage 3 Accumulation RB
	reg [BITS-1:0] r_original_rb_1;
	reg signed [BITS+9:0] r_t3_p33_rb;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_original_rb_1 <= 0;
			r_t3_p33_rb <= 0;
		end
		else begin
			r_original_rb_1 <= r_original_rb;
			r_t3_p33_rb <= (r_t2_p13_rb + r_t2_p22_rb + r_t2_p24_rb + r_t2_p31_rb + r_t2_p32_rb + r_t2_p33_rb + r_t2_p34_rb + r_t2_p35_rb + r_t2_p42_rb + r_t2_p44_rb + r_t2_p53_rb);
		end
		
		
	end

		//stage 3 Accumulation BR
	reg signed [BITS+6:0] r_t3_p33_br;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t3_p33_br <= 0;
		end
		else begin
			r_t3_p33_br <= (r_t2_p13_br + r_t2_p22_br + r_t2_p23_br + r_t2_p24_br + r_t2_p31_br + r_t2_p33_br + r_t2_p35_br + r_t2_p42_br + r_t2_p43_br + r_t2_p44_br + r_t2_p53_br);
		end
		
		
	end

		//stage 3 Accumulation BB
	reg signed [BITS+6:0] r_t3_p33_bb;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t3_p33_bb <= 0;
		end
		else begin
			r_t3_p33_bb <= (r_t2_p13_bb + r_t2_p22_bb + r_t2_p24_bb + r_t2_p31_bb + r_t2_p33_bb + r_t2_p35_bb + r_t2_p42_bb + r_t2_p44_bb + r_t2_p53_bb);
		end
		
		
	end
	
	//stage 4 Division RB
        reg [BITS-1:0] r_original_rb_2;
        reg signed [BITS+6:0] r_t4_p33_rb;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
                r_original_rb_2 <= 0;
                r_t4_p33_rb <= 0;
            end
            else begin
                r_original_rb_2 <= r_original_rb_1;
                r_t4_p33_rb <= r_t3_p33_rb >>> 4;
            end
            
            
        end
    
            //stage 4 Division BR
        reg signed [BITS+6:0] r_t4_p33_br;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
                r_t4_p33_br <= 0;
            end
            else begin
                r_t4_p33_br <= r_t3_p33_br >>> 4;
            end
            
            
        end
    
            //stage 4 Division BB
        reg signed [BITS+6:0] r_t4_p33_bb;
        always @(posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
                r_t4_p33_bb <= 0;
            end
            else begin
                r_t4_p33_bb <= r_t3_p33_bb >>> 4;
            end
            
            
        end
	
	// clipping
	wire [BITS-1:0] r_t5_p33_rb_i;
    assign r_t5_p33_rb_i = r_t4_p33_rb[BITS+6] ? {BITS{1'b0}} : ((r_t4_p33_rb[BITS-1+6:BITS] || 1'b0) ? {BITS{1'b1}} : r_t4_p33_rb[BITS-1:0]) ; // ((r_t4_p33_rb[24:16] || 9'b000000000) ? 16'b1111111111111111 :

	wire [BITS-1:0] r_t5_p33_br_i;
    assign r_t5_p33_br_i = r_t4_p33_br[BITS+6] ? {BITS{1'b0}} : ((r_t4_p33_br[BITS-1+6:BITS] || 1'b0) ? {BITS{1'b1}} : r_t4_p33_br[BITS-1:0]) ; //((r_t4_p33_br[24:16] || 9'b000000000) ? 16'b1111111111111111 :

	wire [BITS-1:0] r_t5_p33_bb_i;
    assign r_t5_p33_bb_i = r_t4_p33_bb[BITS+6] ? {BITS{1'b0}} : ((r_t4_p33_bb[BITS-1+6:BITS] || 1'b0) ? {BITS{1'b1}} : r_t4_p33_bb[BITS-1:0]) ; //((r_t4_p33_bb[24:16] || 9'b000000000) ? 16'b1111111111111111 :


	//stage 5 selecting pixel Common for RGGB
	reg [BITS-1:0] r_t5_p33;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_t5_p33 <= 0;
		end
		else if(odd_pix_6 && !odd_line_6)begin //RB
			r_t5_p33 <= r_t5_p33_rb_i;//[BITS-4-1:0] ;
		end
		else if(!odd_pix_6 && odd_line_6) begin //BR
			r_t5_p33 <= r_t5_p33_br_i;//[BITS-4-1:0];
		end
		else if(odd_pix_6 && odd_line_6) begin //BB
			r_t5_p33 <= r_t5_p33_bb_i;
		end
		else begin
			r_t5_p33 <= r_original_rb_2;//[BITS-4-1:0];  //same for all 3
		end
	end
	
	//stage 5 selecting pixel Common for BGGR
    reg [BITS-1:0] r_t5_p33_1;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            r_t5_p33_1 <= 0;
        end
        else if(odd_pix_6 && !odd_line_6)begin //RB
            r_t5_p33_1 <= r_t5_p33_br_i;//[BITS-4-1:0] ;
        end
        else if(!odd_pix_6 && odd_line_6) begin //BR
            r_t5_p33_1 <= r_t5_p33_rb_i;//[BITS-4-1:0];
        end
        else if(odd_pix_6 && odd_line_6) begin //BB
            r_t5_p33_1 <= r_original_rb_2;
        end
        else begin
            r_t5_p33_1 <= r_t5_p33_bb_i;//[BITS-4-1:0];  //same for all 3
        end
    end
        
    //stage 5 selecting pixel Common for GRBG
    reg [BITS-1:0] r_t5_p33_2;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            r_t5_p33_2 <= 0;
        end
        else if(odd_pix_6 && !odd_line_6)begin //RB
            r_t5_p33_2 <= r_original_rb_2;//[BITS-4-1:0] ;
        end
        else if(!odd_pix_6 && odd_line_6) begin //BR
            r_t5_p33_2 <= r_t5_p33_bb_i;//[BITS-4-1:0];
        end
        else if(odd_pix_6 && odd_line_6) begin //BB
            r_t5_p33_2 <= r_t5_p33_br_i;
        end
        else begin
            r_t5_p33_2 <= r_t5_p33_rb_i;//[BITS-4-1:0];  //same for all 3
        end
    end
            
   //stage 5 selecting pixel Common for GBRG
   reg [BITS-1:0] r_t5_p33_3;
   always @(posedge pclk or negedge rst_n) begin
       if (!rst_n) begin
           r_t5_p33_3 <= 0;
       end
       else if(odd_pix_6 && !odd_line_6)begin //RB
           r_t5_p33_3 <= r_t5_p33_bb_i;//[BITS-4-1:0] ;
       end
       else if(!odd_pix_6 && odd_line_6) begin //BR
           r_t5_p33_3 <= r_original_rb_2;//[BITS-4-1:0];
       end
       else if(odd_pix_6 && odd_line_6) begin //BB
           r_t5_p33_3 <= r_t5_p33_rb_i;
       end
       else begin
           r_t5_p33_3 <= r_t5_p33_br_i;//[BITS-4-1:0];  //same for all 3
       end
    end

	//Green


	//Stage 1: Selecting the corresponding pixels of raw image for green extraction
	reg signed [BITS+6:0] g_t1_p13, g_t1_p23, g_t1_p31;
	reg signed [BITS+6:0] g_t1_p32, g_t1_p33, g_t1_p34;
	reg signed [BITS+6:0] g_t1_p35, g_t1_p43, g_t1_p53;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			g_t1_p13 <= 0; g_t1_p23 <= 0; g_t1_p31 <= 0;
			g_t1_p32 <= 0; g_t1_p33 <= 0; g_t1_p34 <= 0;
			g_t1_p35 <= 0; g_t1_p43 <= 0; g_t1_p53 <= 0;
		end
		else begin
			g_t1_p13 <= {7'd0,p13}; g_t1_p23 <= {7'd0,p23}; g_t1_p31 <= {7'd0,p31};
			g_t1_p32 <= {7'd0,p32}; g_t1_p33 <= {7'd0,p33}; g_t1_p34 <= {7'd0,p34};
			g_t1_p35 <= {7'd0,p35}; g_t1_p43 <= {7'd0,p43}; g_t1_p53 <= {7'd0,p53};
		end
	end

	//Stage 2: Applying filter 
	reg [BITS-1:0] original;
	reg signed [BITS+6:0] g_t2_p13, g_t2_p23, g_t2_p31;
	reg signed [BITS+6:0] g_t2_p32, g_t2_p33, g_t2_p34;
	reg signed [BITS+6:0] g_t2_p35, g_t2_p43, g_t2_p53;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original <= 0;
			g_t2_p13 <= 0; g_t2_p23 <= 0; g_t2_p31 <= 0;
			g_t2_p32 <= 0; g_t2_p33 <= 0; g_t2_p34 <= 0;
			g_t2_p35 <= 0; g_t2_p43 <= 0; g_t2_p53 <= 0;
		end
		else begin
			original <= g_t1_p33[BITS-1:0];
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
	reg [BITS-1:0] original_1;
	reg signed [BITS+6:0] g_t3_p33, g_t3_p33_i;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original_1 <= 0;
			g_t3_p33_i <= 0;
		end
		else begin
			original_1 <= original;
			g_t3_p33_i <= (g_t2_p13 + g_t2_p23 + g_t2_p31 + g_t2_p32 + g_t2_p33 + g_t2_p34 + g_t2_p35 + g_t2_p43 + g_t2_p53);
		end
		
		
	end

	//stage 4 Division
	reg [BITS-1:0] original_2;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			original_2 <= 0;
			g_t3_p33 <= 0;
		end
		else begin
			original_2 <= original_1;
			g_t3_p33 = g_t3_p33_i >>> 3;
		end
	end
	
	wire [BITS-1:0] g_t4_p33i;
    assign g_t4_p33i = g_t3_p33[BITS+6] ? {BITS{1'b0}} : ((g_t3_p33[BITS-1+6:BITS] || 1'b0) ? {BITS{1'b1}} : g_t3_p33[BITS-1:0]) ; // ((g_t3_p33[24:16] || 9'b000000000) ? 16'b1111111111111111 :

	//stage 5 selecting pixel
	reg [BITS-1:0] g_t4_p33; //RGGB
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			g_t4_p33 <= 0;
		end
		else if(!odd_pix_6 && !odd_line_6)begin
			g_t4_p33 <= g_t4_p33i;//[BITS-4-1:0] ;
		end
		else if(odd_pix_6 && odd_line_6) begin
			g_t4_p33 <= g_t4_p33i;//[BITS-4-1:0];
		end
		else begin
			g_t4_p33 <= original_2;//[BITS-4-1:0]; 
		end
	end
	
    reg [BITS-1:0] g_t4_p33_1; //BGGR
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            g_t4_p33_1 <= 0;
        end
        else if(!odd_pix_6 && !odd_line_6)begin
            g_t4_p33_1 <= g_t4_p33i;//[BITS-4-1:0] ;
        end
        else if(odd_pix_6 && odd_line_6) begin
            g_t4_p33_1 <= g_t4_p33i;//[BITS-4-1:0];
        end
        else begin
            g_t4_p33_1 <= original_2;//[BITS-4-1:0]; 
        end
    end
    
    	reg [BITS-1:0] g_t4_p33_2; //GRBG
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            g_t4_p33_2 <= 0;
        end
        else if(!odd_pix_6 && !odd_line_6)begin
            g_t4_p33_2 <= original_2;//[BITS-4-1:0] ;
        end
        else if(odd_pix_6 && odd_line_6) begin
            g_t4_p33_2 <= original_2;//[BITS-4-1:0];
        end
        else begin
            g_t4_p33_2 <= g_t4_p33i;//[BITS-4-1:0]; 
        end
    end
    
    	reg [BITS-1:0] g_t4_p33_3; //GBRG
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            g_t4_p33_3 <= 0;
        end
        else if(!odd_pix_6 && !odd_line_6)begin
            g_t4_p33_3 <= original_2;//[BITS-4-1:0] ;
        end
        else if(odd_pix_6 && odd_line_6) begin
            g_t4_p33_3 <= original_2;//[BITS-4-1:0];
        end
        else begin
            g_t4_p33_3 <= g_t4_p33i;//[BITS-4-1:0]; 
        end
    end

	//Blue

	//stage 5 selecting pixel Common (Previous stages are same as Red)
	reg [BITS-1:0] b_t5_p33; //RGGB
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			b_t5_p33 <= 0;
		end
		else if(odd_pix_6 && !odd_line_6)begin //RB
			b_t5_p33 <= r_t5_p33_br_i;//[BITS-4-1:0] ;
		end
		else if(!odd_pix_6 && odd_line_6) begin //BR
			b_t5_p33 <= r_t5_p33_rb_i;//[BITS-4-1:0];
		end
		else if(!odd_pix_6 && !odd_line_6) begin //RR
			b_t5_p33 <= r_t5_p33_bb_i;//[BITS-4-1:0];
		end
		else begin
			b_t5_p33 <= r_original_rb_2;//[BITS-4-1:0];  //same for all 3
		end
	end
	
	reg [BITS-1:0] b_t5_p33_1; //BGGR
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            b_t5_p33_1 <= 0;
        end
        else if(odd_pix_6 && !odd_line_6)begin //RB
            b_t5_p33_1 <= r_t5_p33_rb_i;//[BITS-4-1:0] ;
        end
        else if(!odd_pix_6 && odd_line_6) begin //BR
            b_t5_p33_1 <= r_t5_p33_br_i;//[BITS-4-1:0];
        end
        else if(odd_pix_6 && odd_line_6) begin //BB
            b_t5_p33_1 <= r_t5_p33_bb_i;
        end
        else begin
            b_t5_p33_1 <= r_original_rb_2;//[BITS-4-1:0];  //same for all 3
        end
    end
    
	reg [BITS-1:0] b_t5_p33_2; //GRBG
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            b_t5_p33_2 <= 0;
        end
        else if(odd_pix_6 && !odd_line_6)begin //RB
            b_t5_p33_2 <= r_t5_p33_bb_i;//[BITS-4-1:0] ;
        end
        else if(!odd_pix_6 && odd_line_6) begin //BR
            b_t5_p33_2 <= r_original_rb_2;//[BITS-4-1:0];
        end
        else if(odd_pix_6 && odd_line_6) begin //BB
            b_t5_p33_2 <= r_t5_p33_rb_i;
        end
        else begin
            b_t5_p33_2 <= r_t5_p33_br_i;//[BITS-4-1:0];  //same for all 3
        end
    end
    
	reg [BITS-1:0] b_t5_p33_3; //GBRG
   always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            b_t5_p33_3 <= 0;
        end
        else if(odd_pix_6 && !odd_line_6)begin //RB
            b_t5_p33_3 <= r_original_rb_2;//[BITS-4-1:0] ;
        end
        else if(!odd_pix_6 && odd_line_6) begin //BR
            b_t5_p33_3 <= r_t5_p33_bb_i;//[BITS-4-1:0];
        end
        else if(odd_pix_6 && odd_line_6) begin //BB
            b_t5_p33_3 <= r_t5_p33_br_i;
        end
        else begin
            b_t5_p33_3 <= r_t5_p33_rb_i;//[BITS-4-1:0];  //same for all 3
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
	
	wire [1:0] pattern;
	assign pattern = BAYER;
	
	assign out_href = href_dly[DLY_CLK-1];
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_r = out_href ? (pattern[0] ? (pattern[1] ? r_t5_p33_1 : r_t5_p33_2) : (pattern[1] ? r_t5_p33_3 : r_t5_p33)) : {BITS{1'b0}};
	assign out_g = out_href ? (pattern[0] ? (pattern[1] ? g_t4_p33_1 : g_t4_p33_2) : (pattern[1] ? g_t4_p33_3 : g_t4_p33)) : {BITS{1'b0}};
	assign out_b = out_href ? (pattern[0] ? (pattern[1] ? b_t5_p33_1 : b_t5_p33_2) : (pattern[1] ? b_t5_p33_3 : b_t5_p33)) : {BITS{1'b0}};

endmodule