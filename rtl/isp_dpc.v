/*************************************************************************
> File Name: isp_dpc.v
> Description: Corrects the hot or dead pixels
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Defective Pixel Correction
 */

module isp_dpc
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
(
	input pclk,
	input rst_n,

	input [BITS-1:0] threshold, // dpc threshold

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_raw
);

    // As we have window size of 5x5 so need to save first four rows and the current input row is realized with shift registers p5x

	wire [BITS-1:0] shiftout;
	wire [BITS-1:0] tap3x, tap2x, tap1x, tap0x;
	shift_register #(BITS, WIDTH, 4) linebuffer(pclk, in_href, in_raw, shiftout, {tap3x, tap2x, tap1x, tap0x});
	
	//Retrieving the 5x5 window from lineBuffers and current input pixel

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
	
	//Selecting the effective 3x3 window from previously selected 5x5 window

	reg [BITS-1:0] t1_p1, t1_p2, t1_p3;
    reg [BITS-1:0] t1_p4, t1_p5, t1_p6;
    reg [BITS-1:0] t1_p7, t1_p8, t1_p9;
	
	always @ (posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
                t1_p1 <= 0; t1_p2 <= 0; t1_p3 <= 0;
                t1_p4 <= 0; t1_p5 <= 0; t1_p6 <= 0;
                t1_p7 <= 0; t1_p8 <= 0; t1_p9 <= 0;
            end
            else begin
                t1_p1 <= p11; t1_p2 <= p13; t1_p3 <= p15;
                t1_p4 <= p31; t1_p5 <= p33; t1_p6 <= p35;
                t1_p7 <= p51; t1_p8 <= p53; t1_p9 <= p55;
            end
        end

	// Selecting gradient for the current window 
	// step 1 Compute gradients

	reg [BITS+1:0] vertical_grad_i, horizontal_grad_i, left_diagonal_grad_i, right_diagonal_grad_i;
	reg [BITS+1:0] v_pick_1, h_pick_1, l_pick_1, r_pick_1;
	always @(posedge pclk or negedge rst_n ) begin
		if (!rst_n) begin
			vertical_grad_i <= 0;
	 		horizontal_grad_i <= 0;
	 		left_diagonal_grad_i <= 0;
	 		right_diagonal_grad_i <= 0;
			v_pick_1 <= 0;
			h_pick_1 <= 0;
			l_pick_1 <= 0;
			r_pick_1 <= 0;	
		end
		else begin
			vertical_grad_i <= (2 * t1_p5 - t1_p2 - t1_p8);
	 		horizontal_grad_i <= (2 * t1_p5 - t1_p4 - t1_p6);
			left_diagonal_grad_i <= (2 * t1_p5 - t1_p1 - t1_p9);
	 		right_diagonal_grad_i <= (2 * t1_p5 - t1_p3 - t1_p7);
			v_pick_1 <= (t1_p2 + t1_p8) / 2;
			h_pick_1 <= (t1_p4 + t1_p6) / 2;
			l_pick_1 <= (t1_p1 + t1_p9) / 2;
			r_pick_1 <= (t1_p3 + t1_p7) / 2;
	 	end		
	end

    // step 2 Taking absoulte value of gradients
	reg [BITS+1:0] vertical_grad, horizontal_grad, left_diagonal_grad, right_diagonal_grad;
	reg [BITS+1:0] v_pick_2, h_pick_2, l_pick_2, r_pick_2;
	always @(posedge pclk or negedge rst_n ) begin
		if (!rst_n) begin
			vertical_grad <= 0;
			horizontal_grad <= 0;
			left_diagonal_grad <= 0;
			right_diagonal_grad <= 0;
			v_pick_2 <= 0;
			h_pick_2 <= 0;
			l_pick_2 <= 0;
			r_pick_2 <= 0;
		end
		else begin
			vertical_grad <= vertical_grad_i[BITS+1] ? -vertical_grad_i : vertical_grad_i ;
			horizontal_grad <= horizontal_grad_i[BITS+1] ? -horizontal_grad_i : horizontal_grad_i ;
			left_diagonal_grad <= left_diagonal_grad_i[BITS+1] ? -left_diagonal_grad_i : left_diagonal_grad_i ;
			right_diagonal_grad <= right_diagonal_grad_i[BITS+1] ?  -right_diagonal_grad_i : right_diagonal_grad_i ;
			v_pick_2 <= v_pick_1;
			h_pick_2 <= h_pick_1;
			l_pick_2 <= l_pick_1;
			r_pick_2 <= r_pick_1;
		end
	end

	//step 3 finding out the minimum gradient
	wire [BITS+1:0] min_grad;
	assign min_grad = (vertical_grad < horizontal_grad) ? ((vertical_grad < left_diagonal_grad) ?
                            ((vertical_grad < right_diagonal_grad) ?
                             vertical_grad : right_diagonal_grad) :
                            ((left_diagonal_grad < right_diagonal_grad) ?
                             left_diagonal_grad : right_diagonal_grad)) :
                           ((horizontal_grad < left_diagonal_grad) ?
                            ((horizontal_grad < right_diagonal_grad) ?
                             horizontal_grad : right_diagonal_grad) :
                            ((left_diagonal_grad < right_diagonal_grad) ?
                             left_diagonal_grad : right_diagonal_grad));

	reg [BITS+1:0] grad_pick;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			grad_pick <= 0;
		end
		else begin
			if (min_grad == vertical_grad) begin
    			grad_pick <= v_pick_2;
 			end 
			else if (min_grad == horizontal_grad) begin
    			grad_pick <= h_pick_2;
  			end else if (min_grad == left_diagonal_grad) begin
    			grad_pick <= l_pick_2;
  			end else begin
    			grad_pick <= r_pick_2;
  			end
		end
	end

	//step 4 Passing the possible resultant pixel (as condition is needed to check either centre pixel is dead to be replaced or not)
	reg [BITS+1:0] t5_medium;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t5_medium <= 0;
		end
		else begin
			t5_medium <= grad_pick;
		end
	end

	//dead pixel Detection Steps
	//step 1
	
	wire below_min, above_max, defect_cond_1;
	//assign below_min = t1_p5 < min_8(t1_p1, t1_p2, t1_p3, t1_p4, t1_p6, t1_p7, t1_p8, t1_p9);
	//assign above_max = t1_p5 > max_8(t1_p1, t1_p2, t1_p3, t1_p4, t1_p6, t1_p7, t1_p8, t1_p9);
	//assign defect_cond_1 = below_min || above_max;	//if true, means pixel is defective as per 1st condition
	assign below_min = (t1_p5 < t1_p1) && (t1_p5 < t1_p2) && (t1_p5 < t1_p3) && (t1_p5 < t1_p4) && (t1_p5 < t1_p6) && (t1_p5 < t1_p7) && (t1_p5 < t1_p8) && (t1_p5 < t1_p9);
	assign above_max = (t1_p5 > t1_p1) && (t1_p5 > t1_p2) && (t1_p5 > t1_p3) && (t1_p5 > t1_p4) && (t1_p5 > t1_p6) && (t1_p5 > t1_p7) && (t1_p5 > t1_p8) && (t1_p5 > t1_p9);
	assign defect_cond_1 = below_min || above_max;	//if true, means pixel is defective as per 1st condition

	reg defective_pix_1;
	reg signed [BITS:0] t2_p1, t2_p2, t2_p3;
	reg signed [BITS:0] t2_p4, t2_p5, t2_p6;
	reg signed [BITS:0] t2_p7, t2_p8, t2_p9;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			defective_pix_1 <= 0;
			t2_p1 <= 0; t2_p2 <= 0; t2_p3 <= 0;
			t2_p4 <= 0; t2_p5 <= 0; t2_p6 <= 0;
			t2_p7 <= 0; t2_p8 <= 0; t2_p9 <= 0;
		end
		else begin
			defective_pix_1 <= defect_cond_1; // Checking if center pixel satisfying the condition: (min(neighbors) < center_pixel < max(neighbors)
			t2_p1 <= {1'b0,t1_p1}; t2_p2 <= {1'b0,t1_p2}; t2_p3 <= {1'b0,t1_p3};
			t2_p4 <= {1'b0,t1_p4}; t2_p5 <= {1'b0,t1_p5}; t2_p6 <= {1'b0,t1_p6};
			t2_p7 <= {1'b0,t1_p7}; t2_p8 <= {1'b0,t1_p8}; t2_p9 <= {1'b0,t1_p9};
		end
	end

	//step2 Computes the difference between the center pixel and the surrounding eight pixel values

	reg defective_pix_2;
	reg [BITS:0] t3_center;
	reg signed [BITS:0] t3_diff1, t3_diff2, t3_diff3, t3_diff4, t3_diff5, t3_diff6, t3_diff7, t3_diff8;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			defective_pix_2 <= 0;
			t3_center <= 0;
			t3_diff1 <= 0; t3_diff2 <= 0;
			t3_diff3 <= 0; t3_diff4 <= 0;
			t3_diff5 <= 0; t3_diff6 <= 0;
			t3_diff7 <= 0; t3_diff8 <= 0;
		end
		else begin
			defective_pix_2 <= defective_pix_1;
			t3_center <= t2_p5[BITS-1:0];
			t3_diff1 <= t2_p5 - t2_p1;
			t3_diff2 <= t2_p5 - t2_p2;
			t3_diff3 <= t2_p5 - t2_p3;
			t3_diff4 <= t2_p5 - t2_p4;
			t3_diff5 <= t2_p5 - t2_p6;
			t3_diff6 <= t2_p5 - t2_p7;
			t3_diff7 <= t2_p5 - t2_p8;
			t3_diff8 <= t2_p5 - t2_p9;
		end
	end

	//step3 Calculate the absolute value of the difference

	reg t4_defective_pix;
	reg [BITS-1:0] t4_center;
	reg [BITS-1:0] t4_diff1, t4_diff2, t4_diff3, t4_diff4, t4_diff5, t4_diff6, t4_diff7, t4_diff8;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t4_defective_pix <= 0;
			t4_center <= 0;
			t4_diff1 <= 0; t4_diff2 <= 0;
			t4_diff3 <= 0; t4_diff4 <= 0;
			t4_diff5 <= 0; t4_diff6 <= 0;
			t4_diff7 <= 0; t4_diff8 <= 0;
		end
		else begin
			t4_center <= t3_center;
			t4_defective_pix <= defective_pix_2;
			t4_diff1 <= t3_diff1[BITS] ? 1'sd0 - t3_diff1 : t3_diff1;
			t4_diff2 <= t3_diff2[BITS] ? 1'sd0 - t3_diff2 : t3_diff2;
			t4_diff3 <= t3_diff3[BITS] ? 1'sd0 - t3_diff3 : t3_diff3;
			t4_diff4 <= t3_diff4[BITS] ? 1'sd0 - t3_diff4 : t3_diff4;
			t4_diff5 <= t3_diff5[BITS] ? 1'sd0 - t3_diff5 : t3_diff5;
			t4_diff6 <= t3_diff6[BITS] ? 1'sd0 - t3_diff6 : t3_diff6;
			t4_diff7 <= t3_diff7[BITS] ? 1'sd0 - t3_diff7 : t3_diff7;
			t4_diff8 <= t3_diff8[BITS] ? 1'sd0 - t3_diff8 : t3_diff8;
		end
	end
 
	//step4 Determine whether the absolute value of the difference exceeds the input provided threshold
	reg t5_defective_pix;
	reg [BITS-1:0] t5_center;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t5_defective_pix <= 0;
			t5_center <= 0;
		end
		else begin
			t5_center <= t4_center;
			t5_defective_pix <= (t4_defective_pix) && (t4_diff1 > threshold) && (t4_diff2 > threshold) && (t4_diff3 > threshold) && (t4_diff4 > threshold) && (t4_diff5 > threshold) && (t4_diff6 > threshold) && (t4_diff7 > threshold) && (t4_diff8 > threshold);
		end
	end

	//step5 When the dead pixel detection is established, the gradient value is output, and the non-dead pixel outputs the original value
	reg [BITS-1:0] t6_center;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t6_center <= 0;
		end
		else begin
			t6_center <= t5_defective_pix ? t5_medium[BITS-1:0] : t5_center;
		end
	end

    // Adjusting for computation delay	
	localparam DLY_CLK = 10;
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
	assign out_raw = out_href ? t6_center : {BITS{1'b0}};

	function [BITS-1:0] min;
		input [BITS-1:0] a, b, c;
		begin
			min = (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
		end
	endfunction
	function [BITS-1:0] med;
		input [BITS-1:0] a, b, c;
		begin
			med = (a < b) ? ((b < c) ? b : (a < c ? c : a)) : ((b > c) ? b : (a > c ? c : a));
		end
	endfunction
	function [BITS-1:0] max;
		input [BITS-1:0] a, b, c;
		begin
			max = (a > b) ? ((a > c) ? a : c) : ((b > c) ? b : c);
		end
	endfunction
	function [BITS-1:0] min_8;
    	input [BITS-1:0] x1, x2, x3, x4, x5, x6, x7, x8;
    	begin
        	min_8 = x1;
        	if (x2 < min_8) min_8 = x2;
        	if (x3 < min_8) min_8 = x3;
        	if (x4 < min_8) min_8 = x4;
        	if (x5 < min_8) min_8 = x5;
        	if (x6 < min_8) min_8 = x6;
        	if (x7 < min_8) min_8 = x7;
        	if (x8 < min_8) min_8 = x8;
    	end
	endfunction

	function [BITS-1:0] max_8;
    	input [BITS-1:0] x1, x2, x3, x4, x5, x6, x7, x8;
    	begin
        	max_8 = x1;
        	if (x2 > max_8) max_8 = x2;
        	if (x3 > max_8) max_8 = x3;
        	if (x4 > max_8) max_8 = x4;
        	if (x5 > max_8) max_8 = x5;
        	if (x6 > max_8) max_8 = x6;
        	if (x7 > max_8) max_8 = x7;
        	if (x8 > max_8) max_8 = x8;
    	end
	endfunction
endmodule
