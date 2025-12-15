/*************************************************************************
> File Name: isp_awb.v
> Description: AWB computes white balance gains as 3A statistics using the Grey World algorithm
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Auto White Balance
 */

module isp_awb
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter AWB_CROP_LEFT = 0,
	parameter AWB_CROP_RIGHT = 0,
	parameter AWB_CROP_TOP = 0,
	parameter AWB_CROP_BOTTOM = 0
)
(
	input pclk,
	input rst_n,

	input [BITS-1:0] in_underexposed_limit,
	input [BITS-1:0] in_overexposed_limit,
	input [BITS-1:0] in_frames,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	
    output reg [11:0] r_gain,
	output reg [11:0] b_gain,
	output reg high

    //===== debug ports =====//
    /*,
    output [23:0] cropped_size, // BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT - 1
    output [BITS-1:0] awb_overexposed_limit,
    output [BITS-1:0] awb_underexposed_limit,
    output [37:0] div_Rgain_num_meanG,
    output [37:0] div_Rgain_den_sumR,
    output [37:0] div_Rgain_quo_Rgain,
    output [37:0] div_Bgain_num_meanG,
    output [37:0] div_Bgain_den_sumB,
    output [37:0] div_Bgain_quo_Bgain,
    output div_gains_sampled*/
    //===== debug ports =====//

);
   
	//localparams -> move to parameters to fix max BITWIDTH allowed
	//assuming MAX FRAME WIDTH, HEIGHT will be 4095x4095
	localparam BITWIDTH_MAX_WIDTH = 12;		//2^12 - 1 = 4095
	localparam BITWIDTH_MAX_HEIGHT = 12;	//2^12 - 1 = 4095
	
    wire href, vsync;
    wire [BITS-1:0] raw;
    
	reg [BITWIDTH_MAX_WIDTH-1:0] awb_crop_left, awb_crop_right, awb_crop_top, awb_crop_bottom;

	wire fsm_div_r_en, fsm_div_b_en;
	wire fsm_div_r_done, fsm_div_b_done;

    //As we are in Bayer domain so need to make sure cropping does not hurt the Bayer pattern
    //so if some invalid crop values are provided, they will be ceiled up to the closest value(multiple of 4) keeping the Bayer pattern intact
	
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            awb_crop_left <= 0;
        end
        else if (AWB_CROP_LEFT % 4 == 1) begin
            awb_crop_left <= AWB_CROP_LEFT + 3;
        end
        else if (AWB_CROP_LEFT % 4 == 2) begin
            awb_crop_left <= AWB_CROP_LEFT + 2;
        end
        else if (AWB_CROP_LEFT % 4 == 3) begin
            awb_crop_left <= AWB_CROP_LEFT + 1;
        end
        else begin
            awb_crop_left <= AWB_CROP_LEFT;
        end
    end
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            awb_crop_right <= 0;
        end
        else if (AWB_CROP_RIGHT % 4 == 1) begin
            awb_crop_right <= AWB_CROP_RIGHT + 3;
        end
        else if (AWB_CROP_RIGHT % 4 == 2) begin
            awb_crop_right <= AWB_CROP_RIGHT + 2;
        end
        else if (AWB_CROP_RIGHT % 4 == 3) begin
            awb_crop_right <= AWB_CROP_RIGHT + 1;
        end
        else begin
            awb_crop_right <= AWB_CROP_RIGHT;
        end
    end
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            awb_crop_top <= 0;
        end
        else if (AWB_CROP_TOP % 4 == 1) begin
            awb_crop_top <= AWB_CROP_TOP + 3;
        end
        else if (AWB_CROP_TOP % 4 == 2) begin
            awb_crop_top <= AWB_CROP_TOP + 2;
        end
        else if (AWB_CROP_TOP % 4 == 3) begin
            awb_crop_top <= AWB_CROP_TOP + 1;
        end
        else begin
            awb_crop_top <= AWB_CROP_TOP;
        end
    end
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            awb_crop_bottom <= 0;
        end
        else if (AWB_CROP_BOTTOM % 4 == 1) begin
            awb_crop_bottom <= AWB_CROP_BOTTOM + 3;
        end
        else if (AWB_CROP_BOTTOM % 4 == 2) begin
            awb_crop_bottom <= AWB_CROP_BOTTOM + 2;
        end
        else if (AWB_CROP_BOTTOM % 4 == 3) begin
            awb_crop_bottom <= AWB_CROP_BOTTOM + 1;
        end
        else begin
            awb_crop_bottom <= AWB_CROP_BOTTOM;
        end
    end

    //Cropping away the invalid rows and colums

    isp_crop_awb_ae #(BITS,WIDTH,HEIGHT) crop (.pclk(pclk),.rst_n(rst_n), .crop_left(awb_crop_left), .crop_right(awb_crop_right), .crop_top(awb_crop_top), .crop_bottom(awb_crop_bottom), .in_href(in_href),.in_vsync(in_vsync),.in_data(in_raw),.out_href(href),.out_vsync(vsync),.out_data(raw));   
	
    wire [BITS-1:0] shiftout;
	wire [BITS-1:0] tap0x;
    localparam NEW_WIDTH_RIGHT = (AWB_CROP_RIGHT % 4 == 1) ? (AWB_CROP_RIGHT + 3) : ((AWB_CROP_RIGHT % 4 == 2) ? (AWB_CROP_RIGHT + 2) : ((AWB_CROP_RIGHT % 4 == 3) ? (AWB_CROP_RIGHT + 1) : AWB_CROP_RIGHT)) ;
    localparam NEW_WIDTH_LEFT = (AWB_CROP_LEFT % 4 == 1) ? (AWB_CROP_LEFT + 3) : ((AWB_CROP_LEFT % 4 == 2) ? (AWB_CROP_LEFT + 2) : ((AWB_CROP_LEFT % 4 == 3) ? (AWB_CROP_LEFT + 1) : AWB_CROP_LEFT)) ;
    localparam NEW_WIDTH = WIDTH - NEW_WIDTH_RIGHT - NEW_WIDTH_LEFT;

    //Operations are performed on 2x2 window of bayer pattern so one row is saved in the linebuffer

	shift_register #(BITS, NEW_WIDTH, 1) linebuffer(pclk, href, raw, shiftout, tap0x);

    wire [BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] crop_window_size;  //24-bit
    assign crop_window_size = (WIDTH - awb_crop_left - awb_crop_right) * (HEIGHT - awb_crop_top - awb_crop_bottom);

    //Keeping track of even/odd pixels

    reg odd_pix;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			odd_pix <= 0;
		else if (!href)
			odd_pix <= 0;
		else
			odd_pix <= ~odd_pix;
	end
	
	reg prev_href;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_href <= 0;
        else
            prev_href <= href;
    end 
    
    reg prev_v_sync;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_v_sync <= 0;
       else
            prev_v_sync <= vsync;
    end
    
//    reg clk_slow;
//    reg [1:0] count_slow;
    
//    always @ (posedge pclk or negedge rst_n)
//    begin
//        if(!rst_n)
//        begin
//            clk_slow <= 1;
//            count_slow <= 0;
//        end
//        else
//        begin
//            if(count_slow == 2'b11)
//            begin
//                clk_slow <= ~clk_slow;
//                count_slow <= 0;
//            end
//            else
//            begin
//                clk_slow <= clk_slow;
//                count_slow <= count_slow + 1;
//            end
//        end
//    end
    
    reg [BITS-1:0] overexposed_limit, underexposed_limit;
    reg [BITS-1:0] frames;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            overexposed_limit <= 0;
            underexposed_limit <= 0;
            frames <= 0;
        end
        else if ((~prev_v_sync) & vsync) begin	//sample inputs at VSYNC rising-edge
            overexposed_limit <= in_overexposed_limit;
            underexposed_limit <= in_underexposed_limit;
            frames <= in_frames;
        end
        else begin
            overexposed_limit <= overexposed_limit;
            underexposed_limit <= underexposed_limit;
            frames <= frames;
        end
    end   

    //keeping track of even/odd row

    reg odd_line;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            odd_line <= 0;
        else if (vsync)
            odd_line <= 0;
        else if (prev_href & (~href))
            odd_line <= ~odd_line;
        else
            odd_line <= odd_line;
    end
	
    //Capturing the 2*2 window

	reg [BITS-1:0] in_raw_r;
	reg [BITS-1:0] p11,p12;
	reg [BITS-1:0] p21,p22;
    reg odd_pix_1,odd_line_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			in_raw_r <= 0;
            odd_pix_1 <= 0;
            odd_line_1 <= 0;
			p11 <= 0; p12 <= 0;
			p21 <= 0; p22 <= 0;
		end
		else begin
			in_raw_r <= raw;
            odd_pix_1 <= odd_pix;
            odd_line_1 <= odd_line;
			p11 <= p12; p12 <= tap0x;
			p21 <= p22; p22 <= in_raw_r; 
		end
	end

    reg odd_pix_2,odd_line_2;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            odd_pix_2 <= 0;
            odd_line_2 <= 0;
		end
		else begin
            odd_pix_2 <= odd_pix_1;
            odd_line_2 <= odd_line_1;
		end
    end
    
    //If any pixel of 2x2 window is less than the underexposed limit and/or greater than the overexposed limit, the complete window is
    //dropped and is not included in stats calculation

    reg [BITS-1:0] p11_1,p12_1;
    reg [BITS-1:0] p21_1,p22_1;
    reg good;
    reg odd_pix_3,odd_line_3;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            odd_pix_3 <= 0;
            odd_line_3 <= 0;
            good <= 0;
            p11_1 <= 0; p12_1 <= 0;
			p21_1 <= 0; p22_1 <= 0;
		end
		else begin
		    good <= ((p11 > underexposed_limit) & (p11 < overexposed_limit)) & 
                    ((p12 > underexposed_limit) & (p12 < overexposed_limit)) & 
                    ((p21 > underexposed_limit) & (p21 < overexposed_limit)) & 
                    ((p22 > underexposed_limit) & (p22 < overexposed_limit));
            odd_pix_3 <= odd_pix_2;
            odd_line_3 <= odd_line_2;
            p11_1 <= p11; p12_1 <= p12;
			p21_1 <= p21; p22_1 <= p22;
		end
    end
    
    reg odd_pix_4;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n)
            odd_pix_4 <= 0;
        else
            odd_pix_4 <= odd_pix_3;
    end

    //Those windows which pass the above condition takes part in stat calculation
    //What are the stats? We need average of r g and b values as extracted from Bayer window so we simply add pixels to thier coresponding variable    
        
    reg [3*BITS-1:0]  sum_r, sum_gr, sum_gb, sum_b;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
			sum_r <= 0;
            sum_gr <= 0;
            sum_gb <= 0;
            sum_b <= 0;
		end
		else if(good && (!odd_pix_4) && odd_line_3) begin
			sum_r <= sum_r + p11_1;
            sum_gr <= sum_gr + p12_1;
            sum_gb <= sum_gb + p21_1;
            sum_b <= sum_b + p22_1; 
		end
		else if(prev_v_sync & (~vsync)) begin
			sum_r <= 0;
            sum_gr <= 0;
            sum_gb <= 0;
            sum_b <= 0; 
		end
        else begin
            sum_r <= sum_r;
            sum_gr <= sum_gr;
            sum_gb <= sum_gb;
            sum_b <= sum_b; 
        end
    end

    //Shifting the pixels location depending upon the Bayer Pattern

    reg [3*BITS-1:0] mean_g;
    reg [3*BITS-1+8:0] sumr,sumb;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            mean_g <= 0;
            sumr <=  0;
            sumb <= 0;
        end
        else if(prev_v_sync & (~vsync)) begin
            mean_g <= 0;
            sumr <=  0;
            sumb <= 0;
        end 
        else begin
        case (BAYER)
            0: begin //RGGB
                mean_g <= (sum_gr + sum_gb) >> 1;
                sumr <= {8'd0,sum_r};
                sumb <= {8'd0,sum_b};
            end
            1:  begin //GRBG
                 mean_g <= (sum_r + sum_b) >> 1;
                 sumr <= {8'd0,sum_gr};
                 sumb <= {8'd0,sum_gb};
            end
            2: begin //GBRG
                mean_g <= (sum_r + sum_b) >> 1;
                sumr <= {8'd0,sum_gb};
                sumb <= {8'd0,sum_gr};
            end 
           
            3: begin //BGGR
                mean_g <= (sum_gr + sum_gb) >> 1;
                sumr <= {8'd0,sum_b};
                sumb <= {8'd0,sum_r};
            end
                        
            default: begin //RGGB
                mean_g <= (sum_gr + sum_gb) >> 1;
                sumr <= {8'd0,sum_gb};
                sumb <= {8'd0,sum_gr};
            end
        endcase
        end
    end
    
    //Output results are in format of 4.8 (fix point) so appending zeros for that
        
    reg [3*BITS-1+8:0] mean_g_1;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n)
            mean_g_1 <= 0;
        else
		begin
            mean_g_1 <= {mean_g,8'd0};
		end
	end 
 
    //After calculating corresponding sums on complete frame we do following operation:
    // R_Gain = Sum of G pixels / Sum of R Pixels
    // B_Gain = Sum of G pixels / Sum of B pixels
        
    wire [3*BITS-1+8:0] quo_r, rem_r;
    reg  [3*BITS-1+8:0] quo_r_1;
    wire [3*BITS-1+8:0] quo_b, rem_b;
    reg  [3*BITS-1+8:0] quo_b_1;

    
//    always @ (posedge clk_slow or negedge rst_n)
//    begin
//        if(!rst_n)
//        begin
//            sumr_slow <= 0;
//            sumb_slow <= 0;
//            mean_g_slow <= 0;
//        end
//        else
//        begin
//            sumr_slow <= sumr;
//            sumb_slow <= sumb;
//            mean_g_slow <= mean_g_1;
//        end
//    end
    

//    always @ (posedge clk_slow or negedge rst_n)
//begin
//    if(!rst_n)
//    begin
//        quo_r_slow <= 0;
//        quo_b_slow <= 0;
//    end
//    else
//    begin
//        if (sumr_slow == 0 && sumb_slow != 0) begin
//            quo_r_slow <= 12'd256;
//            quo_b_slow <= mean_g_slow / sumb_slow;
//        end
//        else if (sumr_slow != 0 && sumb_slow == 0) begin
//            quo_r_slow <= mean_g_slow / sumr_slow;
//            quo_b_slow <= 12'd256;
//        end
//        else if (sumr_slow == 0 && sumb_slow == 0) begin
//            quo_r_slow <= 12'd256;
//            quo_b_slow <= 12'd256;
//        end
//        else begin
//            quo_r_slow <= mean_g_slow / sumr_slow;
//            quo_b_slow <= mean_g_slow / sumb_slow;
//        end
//    end
//end
    
//    always @ (posedge pclk or negedge rst_n)
//    begin
//        if(!rst_n)
//        begin
//            quo_r <= 0;
//            quo_b <= 0;
//        end
//        else
//        begin
//            quo_r <= quo_r_slow;
//            quo_b <= quo_b_slow;
//        end
//    end
    
    //shift_div_uint #(3*BITS-1+8) target_div_r (pclk,rst_n,mean_g_1,sumr,quo_r,rem_r);
    //shift_div_uint #(3*BITS-1+8) target_div_b (pclk,rst_n,mean_g_1,sumb,quo_b,rem_b);
	shift_div #(3*BITS+8) fsm_div_r (pclk, rst_n, fsm_div_r_en, mean_g_1, sumr, quo_r, rem_r, fsm_div_r_done);
	shift_div #(3*BITS+8) fsm_div_b (pclk, rst_n, fsm_div_b_en, mean_g_1, sumb, quo_b, rem_b, fsm_div_b_done); 
	
	//FSM divider enable (active high) signals driven high at the start of vertical blanking (vsync posedge)
	//making enable signals reg and driving them on posedge clk would re-trigger the divider FSM, performing division twice
	assign fsm_div_r_en = vsync & ~prev_v_sync;
	assign fsm_div_b_en = vsync & ~prev_v_sync;
	/*always @(posedge pclk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			fsm_div_r_en <= 1'b0;
			fsm_div_b_en <= 1'b0;
		end
		else
		begin
			if (vsync & ~prev_v_sync)	//vsync is active low; detecting pclk at which vsync posedge has occurred
			begin
				fsm_div_r_en <= 1'b1;
				fsm_div_b_en <= 1'b1;
			end
			else if (fsm_div_r_done & fsm_div_b_done)
			begin
				fsm_div_r_en <= 1'b0;
				fsm_div_b_en <= 1'b0;
			end
			else
			begin
				fsm_div_r_en <= fsm_div_r_en;
				fsm_div_b_en <= fsm_div_b_en;
			end
		end
	end*/
	
	//sample FSM divider outputs when they are valid
	always @(posedge pclk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			quo_r_1 <= 0;
			quo_b_1 <= 0;
		end
		
		else
		begin
			if (fsm_div_r_done & fsm_div_b_done)
			begin
				if (sumr == 0 && sumb != 0) begin
					quo_r_1 <= 12'd256;
					quo_b_1 <= quo_b;
				end
				else if (sumr != 0 && sumb == 0) begin
					quo_r_1 <= quo_r;
					quo_b_1 <= 12'd256;
				end
				else if (sumr == 0 && sumb == 0) begin
					quo_r_1 <= 12'd256;
					quo_b_1 <= 12'd256;
				end
				else begin
					quo_r_1 <= quo_r;
					quo_b_1 <= quo_b;
				end
			end
			else
			begin
				quo_r_1 <= quo_r_1;
				quo_b_1 <= quo_b_1;
			end
		end
	end
	
	//logic to generate gains_sampled signal for transfer of sampled divider outputs into rgain, bgain registers
	//wire gains_sampled;
	//assign gains_sampled = fsm_div_r_done & fsm_div_b_done;
	reg gains_sampled;
	always @(posedge pclk or negedge rst_n)
	begin
		if (!rst_n)
		begin
			gains_sampled <= 1'b0;
		end
		else
		begin
			if (fsm_div_r_done & fsm_div_b_done)
			begin
				gains_sampled <= 1'b1;
			end
			else
			begin
				gains_sampled <= 1'b0;
			end
		end
	
	end
	
    /*always @ (posedge pclk or negedge rst_n)
begin
    if(!rst_n)
    begin
        quo_r_1 <= 0;
        quo_b_1 <= 0;
    end
    else
    begin
        if (sumr == 0 && sumb != 0) begin
            quo_r_1 <= 12'd256;
            quo_b_1 <= quo_b;
        end
        else if (sumr != 0 && sumb == 0) begin
            quo_r_1 <= quo_r;
            quo_b_1 <= 12'd256;
        end
        else if (sumr == 0 && sumb == 0) begin
            quo_r_1 <= 12'd256;
            quo_b_1 <= 12'd256;
        end
        else begin
            quo_r_1 <= quo_r;
            quo_b_1 <= quo_b;
        end
    end
end*/

    //Selcting last 12 bits (4.8) as resultant data

	reg[BITS-1:0] count;
	reg write;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            r_gain <= 0;
            b_gain <= 0;
            count <= 0;
            write <= 0;
        end
        else if(gains_sampled) begin
            r_gain <= quo_r_1[11:0];
			b_gain <= quo_b_1[11:0];
            count <= count + 1;
            write <= write + 1; 
        end else if(high) begin
            r_gain <= r_gain;
            b_gain <= b_gain;
            count <= 0;
            write <= 0;
        end
        else begin
            r_gain <= r_gain;
            b_gain <= b_gain;
            count <= count;
            write <= 0;
        end
    end
    
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            high <= 1'b0;
        end
        else if(count == frames)begin
            high <= 1'b1;
        end
        else begin
            high <= 1'b0;
        end
    end


    //===== debug ports =====//
    /*assign cropped_size = crop_window_size;
    assign awb_overexposed_limit = overexposed_limit;
    assign awb_underexposed_limit = underexposed_limit;
    assign div_Rgain_num_meanG = mean_g_1;
    assign div_Rgain_den_sumR = sumr;
    assign div_Rgain_quo_Rgain = quo_r;
    assign div_Bgain_num_meanG = mean_g_1;
    assign div_Bgain_den_sumB = sumb;
    assign div_Bgain_quo_Bgain = quo_b;
    assign div_gains_sampled = gains_sampled;*/
    //===== debug ports =====//


endmodule
