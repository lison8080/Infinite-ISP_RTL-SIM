/*************************************************************************
> File Name: isp_ae.v
> Description: Exposure determination
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Auto Exposure
 */

module isp_ae
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_r,
	input [BITS-1:0] in_g,
	input [BITS-1:0] in_b,
	
	input [7:0] center_illuminance,	//always in 8-bit range
	input [15:0] skewness,
	input [11:0] ae_crop_left,
	input [11:0] ae_crop_right,
	input [11:0] ae_crop_top,
	input [11:0] ae_crop_bottom,

	output reg [1:0] ae_response,
	output reg [15:0] ae_result_skewness,
	output reg [1:0] ae_response_debug, 
	
	output reg ae_done
	

	//===== debug ports =====//
	/*,
	output [23:0] cropped_size,	// BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT - 1
	output [40:0] sum_pix_square,
	output [50:0] sum_pix_cube,
	output [63:0] div_out_m_2,
	output [63:0] div_out_m_3,
	output [63:0] div_out_sqrt_fsm,
	output [62:0] sqrt_fsm_out_sqrt,
	output [63:0] div_out_ae_skewness,
	output SQRT_FSM_EN,
	output SQRT_FSM_DIV_EN,
	output SQRT_FSM_DIV_DONE,
	output SQRT_FSM_DONE,
	output [31:0] SQRT_FSM_COUNT*/
	//===== debug ports =====//

);

    //localparams -> move to parameters to fix max BITWIDTH allowed
	//assuming MAX FRAME WIDTH, HEIGHT will be 4095x4095
	localparam BITWIDTH_MAX_WIDTH = 12;		//2^12 - 1 = 4095
	localparam BITWIDTH_MAX_HEIGHT = 12;	//2^12 - 1 = 4095
	
	localparam M_2_BITWIDTH = 18 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_WIDTH;	//9*2+12+12 = 42 bits
	localparam SQRT_BITWIDTH = M_2_BITWIDTH / 2;							//42/2 = 21 bits
	localparam M2_BITWIDTH = M_2_BITWIDTH + SQRT_BITWIDTH;					//42+21 = 63 bits
	
	
	wire href, href_1, href_2; 
    wire vsync, vsync_1, vsync_2;
    wire [BITS-1:0] r, g, b;
    
	//=== circuit to sample window crop coordinates in vertical blanking period when AE skewness calculation is done ===//
	wire ae_vsync;
	assign ae_vsync = in_vsync;
	reg prev_ae_vsync;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_ae_vsync <= 1'b0;
		else
			prev_ae_vsync <= ae_vsync;
	end
	
	//	update of internal regs in vertical blanking would not effect post-crop computation as
	//	valid input pixels and the valid cropped output pixels exist outside vertical blanking 
    reg [BITWIDTH_MAX_WIDTH - 1:0] crop_left, crop_right, crop_top, crop_bottom; 
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            crop_left <= 0;
        end
        else begin
			if (ae_vsync) begin					//update of internal reg in vertical blanking
				crop_left <= ae_crop_left;
			end
        end
    end
	
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            crop_right <= 0;
        end
        
        else begin
			if (ae_vsync) begin
				crop_right <= ae_crop_right;	//update of internal reg in vertical blanking
			end
        end
    end
	
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            crop_top <= 0;
        end
        else begin
			if (ae_vsync) begin					//update of internal reg in vertical blanking
				crop_top <= ae_crop_top;
			end
        end
    end
	
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            crop_bottom <= 0;
        end
        else begin
			if (ae_vsync) begin					//update of internal reg in vertical blanking
				crop_bottom <= ae_crop_bottom;
			end
		end
    end
	//=== circuit to sample window crop coordinates in vertical blanking period when AE skewness calculation is done ===//
	
	// CROP window for AE skewness calculation
    isp_crop_awb_ae #(BITS,WIDTH,HEIGHT) crop_r (.pclk(pclk),.rst_n(rst_n), .crop_left(crop_left), .crop_right(crop_right), .crop_top(crop_top), .crop_bottom(crop_bottom), .in_href(in_href),.in_vsync(in_vsync),.in_data(in_r),.out_href(href),.out_vsync(vsync),.out_data(r));
    isp_crop_awb_ae #(BITS,WIDTH,HEIGHT) crop_g (.pclk(pclk),.rst_n(rst_n), .crop_left(crop_left), .crop_right(crop_right), .crop_top(crop_top), .crop_bottom(crop_bottom), .in_href(in_href),.in_vsync(in_vsync),.in_data(in_g),.out_href(href_1),.out_vsync(vsync_1),.out_data(g));
    isp_crop_awb_ae #(BITS,WIDTH,HEIGHT) crop_b (.pclk(pclk),.rst_n(rst_n), .crop_left(crop_left), .crop_right(crop_right), .crop_top(crop_top), .crop_bottom(crop_bottom), .in_href(in_href),.in_vsync(in_vsync),.in_data(in_b),.out_href(href_2),.out_vsync(vsync_2),.out_data(b));
    
	//Keeping track of pixel odd or even

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

    //Registering the data and bringing it down into 8 bits range

	reg [7:0] data_r, data_g, data_b;
	reg in_href_1;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
            data_r <= 0;
			data_g <= 0;
			data_b <= 0;
			in_href_1 <= 0;
	   end
       else begin
            data_r <= r >> (BITS-8);
			data_g <= g >> (BITS-8);
			data_b <= b >> (BITS-8);
			in_href_1 <= href;
	   end
	end

    //Conversion from RGB to Grey pixel

	reg [15:0] grey_r, grey_g, grey_b;
	reg in_href_2;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
            grey_r <= 0;
			grey_g <= 0;
			grey_b <= 0;
			in_href_2 <= 0;
	   end
       else begin
            grey_r <= data_r * 77;
			grey_g <= data_g * 150;
			grey_b <= data_b * 29;
			in_href_2 <= in_href_1;
		end
	end

	reg [8:0] grey;	//9-bit
	reg in_href_3;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
            grey <= 0;
            in_href_3 <= 0;
       end
       else begin
            grey <= (grey_r + grey_g + grey_b) >> 8;
            in_href_3 <= in_href_2;
       end
	end

	//Subtracting centre illuminance from the grey value

	reg signed[8:0] avg_pixel;	//9-bit
	reg in_href_4;
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            avg_pixel <= 0;
            in_href_4 <= 0;
       end
       else begin
            avg_pixel <= grey - center_illuminance;
            in_href_4 <= in_href_3;
       end
    end


	wire [BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT - 1:0] crop_window_size;	//24-bit
	assign crop_window_size = (WIDTH - crop_left - crop_right) * (HEIGHT - crop_top - crop_bottom);

    //Calculating square of grey pixels

	reg signed[17:0] pix_square;	//9*2=18-bits
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            pix_square <= 0;
        else if((~vsync) & prev_v_sync)		//prev. rising edge VSYNC, changed to falling edge VSYNC
            pix_square <= 0;
        else if(in_href_4)
            pix_square <= avg_pixel * avg_pixel;
        else
            pix_square <= pix_square;
    end

    //Calculating cube of grey pixels

	reg signed[26:0] pix_cube;		//9*3=27-bits
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            pix_cube <= 0;
        else if((~vsync) & prev_v_sync)		//prev. rising edge VSYNC, changed to falling edge VSYNC
            pix_cube <= 0;
        else if(in_href_4)
            pix_cube <= avg_pixel * avg_pixel * avg_pixel;
        else
            pix_cube <= pix_cube;
    end
    
    reg in_href_5;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            in_href_5 <= 0;
        else
            in_href_5 <= in_href_4;
    end 

    //Accumulating sum of grey pixels square

	reg signed [18 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT - 1:0] pix_square_sum;	//42-bit
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            pix_square_sum <= 0;
        else if((~vsync) & prev_v_sync)		//prev. rising edge VSYNC, changed to falling edge VSYNC
            pix_square_sum <= 0;
        else if(in_href_5)
            pix_square_sum <= pix_square_sum + pix_square;
        else
            pix_square_sum <= pix_square_sum;
    end
     
	//Accumulating cube of grey pixels square

	reg signed[27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] pix_cube_sum;	//51-bit
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            pix_cube_sum <= 0;
        else if((~vsync) & prev_v_sync)		//prev. rising edge VSYNC, changed to falling edge VSYNC
            pix_cube_sum <= 0;
        else if(in_href_5)
            pix_cube_sum <= pix_cube_sum + pix_cube;
        else
            pix_cube_sum <= pix_cube_sum;
    end
    
	//Converting Cube summation into +ve if its negative

    reg signed[27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] pix_cube_sum_positive;	//51-bit
    reg m_3_sign;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            pix_cube_sum_positive <= 0;
            m_3_sign <= 0;
        end
        else if(pix_cube_sum[27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1]) begin	//51th-bit
            pix_cube_sum_positive <= pix_cube_sum * -1;
            m_3_sign <= 1;
        end
        else begin
            pix_cube_sum_positive <= pix_cube_sum;
            m_3_sign <= 0;
        end
    end

	//===== SLOW CLOCK GENERATION =====//
    /*
	reg clk_slow;
    reg [1:0] count_slow;

    always @ (posedge pclk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            clk_slow <= 1;
            count_slow <= 0;
        end
        else
        begin
            if(count_slow == 2'b11)
            begin
                clk_slow <= ~clk_slow;
                count_slow <= 0;
            end
            else
            begin
                clk_slow <= clk_slow;
                count_slow <= count_slow + 1;
            end
        end
    end
	*/
	//===== SLOW CLOCK GENERATION =====//
    
    /*
	reg signed [BITS*2 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT:0] pix_square_sum_slow;
    reg signed[BITS*3 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT:0] pix_cube_sum_slow;
    always @ (posedge pclk or negedge rst_n) begin
         if (!rst_n) begin
             pix_square_sum_slow <= 0;
             pix_cube_sum_slow <= 0;
         end
         else begin
             pix_square_sum_slow <= pix_square_sum;
             pix_cube_sum_slow <= pix_cube_sum_positive;
         end
    end
	*/
	
	// divider for m_2 and m_3
	wire [M_2_BITWIDTH -1:0] quo_m_2_div, rem_m_2_div;	//42-bit
	wire fsm_div_m_2_done;
	wire fsm_div_m_2_en;
	assign fsm_div_m_2_en = (~prev_v_sync) & vsync;
	
	wire [M_2_BITWIDTH -1:0] size_for_m_2_div;	//42-bit
	assign size_for_m_2_div = {{(18){1'b0}}, crop_window_size};
	
	shift_div #(M_2_BITWIDTH) fsm_div_m_2
	(
		.clk(pclk),
		.rst_n(rst_n),
		.enable(fsm_div_m_2_en),
		.a(pix_square_sum),
		.b(size_for_m_2_div),
		.c(quo_m_2_div),
		.d(rem_m_2_div),
		.done(fsm_div_m_2_done)
	);

	wire [27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] quo_m_3_div, rem_m_3_div;	//51-bit
	wire fsm_div_m_3_done;
	wire fsm_div_m_3_en;
	assign fsm_div_m_3_en = (~prev_v_sync) & vsync;
	
	wire [27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] size_for_m_3_div;	//51-bit
	assign size_for_m_3_div = {{(27){1'b0}}, crop_window_size};
	
	shift_div #(27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT) fsm_div_m_3
	(
		.clk(pclk),
		.rst_n(rst_n),
		.enable(fsm_div_m_3_en),
		.a(pix_cube_sum_positive),
		.b(size_for_m_3_div),
		.c(quo_m_3_div),
		.d(rem_m_3_div),
		.done(fsm_div_m_3_done) 
	);
	
	// prev. division for m_2, now m_2
    reg signed [M_2_BITWIDTH -1:0] m_2;	//42-bit
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            m_2 <= 0;
        else begin
			if (fsm_div_m_2_done)
				m_2 <= (quo_m_2_div) >>> 6;
			else
				m_2 <= m_2;
		end
    end
    
	// prev. division for m_3, now m_3
    reg signed [27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT -1:0] m_3;	//51-bit
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            m_3 <= 0;
        else begin
			if (fsm_div_m_3_done)
				m_3 <= (quo_m_3_div) >>> 9;
			else
				m_3 <= m_3;
		end
	end
 
	reg fsm_div_m_2_done_delay;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			fsm_div_m_2_done_delay <= 1'b0;
		else begin
			fsm_div_m_2_done_delay <= fsm_div_m_2_done;
		end
	end
	
	reg fsm_div_m_3_done_delay;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			fsm_div_m_3_done_delay <= 1'b0;
		else begin
			fsm_div_m_3_done_delay <= fsm_div_m_3_done;
		end
	end
	
	reg sqrt_fsm_en;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)
			sqrt_fsm_en <= 1'b0;
		else begin
			sqrt_fsm_en <= fsm_div_m_2_done;
		end
	end
    
	
    reg in_href_6;
    always @ (posedge pclk or negedge rst_n) begin
       if (!rst_n) 
            in_href_6 <= 0;
       else
            in_href_6 <= in_href_5;
    end
	
	reg prev_in_href_6;
    always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) 
			prev_in_href_6 <= 0;
        else
			prev_in_href_6 <= in_href_6;
    end
	
	
	//===== SQUARE ROOT FSM BEGIN =====//
    reg [M_2_BITWIDTH -1:0] sqrt, n_by_sqrt;		//9*2+12+12 = 42, [41:0]
    reg [M_2_BITWIDTH -1:0] number, sqrt_i;			//9*2+12+12 = 42, [41:0]
    reg [31:0] count;
	wire sqrt_fsm_div_done;
	wire sqrt_fsm_div_en;
	reg sqrt_fsm_done;
	
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin				//active low async reset
			number <= 0;
			sqrt_i <= 0;
        end
		else begin
			if (sqrt_fsm_en) begin
				number <= m_2;
				sqrt_i <= m_2 >> 1;
			end
        end
    end

	reg sqrt_fsm_en_delay;
    always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			sqrt_fsm_en_delay <= 0;
		end
		else begin
			sqrt_fsm_en_delay <= sqrt_fsm_en;
		end
	end
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			count <= 0;
        end
        /*else if (vsync & (~prev_v_sync)) begin	//vertical blanking removed from inside sqrt fsm to help package sqrt fsm as verilog module
			count <= 0;
		end*/
		else if(sqrt_fsm_en | sqrt_fsm_done) begin	//trigger the square-root FSM, enable the FSM;
			count <= 0;								//prev en was (~in_href_6 & (prev_in_href_6)), now en is (sqrt_fsm_en) 
        end
        else begin									//add condition that next count happens after 1 successful division: num/sqrt
			if (sqrt_fsm_div_done)
				count <= count + 1;
        end
	end
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			sqrt_fsm_done <= 1'b0;
		end
		else begin
			if (sqrt_fsm_en) begin
				sqrt_fsm_done <= 1'b0;
			end
			else begin
				if ((count == 32'h000D) & (~sqrt_fsm_done)) begin	//count == 13 & done signal not already high
					sqrt_fsm_done <= 1'b1;
				end
				else begin
					sqrt_fsm_done <= 1'b0;
				end
			end
		end
	
	end
	
	reg sqrt_fsm_div_done_delay, sqrt_fsm_div_done_delay_2;
	wire [M_2_BITWIDTH -1:0] sqrt_fsm_div_num, sqrt_fsm_div_den, sqrt_fsm_div_quo, sqrt_fsm_div_rem;
	assign sqrt_fsm_div_num = number;
	assign sqrt_fsm_div_den = (!count) ? sqrt_i : sqrt;	//FSM div denominator output of a MUX
	assign sqrt_fsm_div_en = (sqrt_fsm_en_delay | sqrt_fsm_div_done_delay_2) & (~sqrt_fsm_done);
	shift_div #(M_2_BITWIDTH) fsm_div_n_by_sqrt	//42-bit divider
	(
		.clk(pclk),
		.rst_n(rst_n),
		.enable(sqrt_fsm_div_en),
		.a(sqrt_fsm_div_num),
		.b(sqrt_fsm_div_den),
		.c(sqrt_fsm_div_quo),
		.d(sqrt_fsm_div_rem),
		.done(sqrt_fsm_div_done)
	);
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			n_by_sqrt <= 0;
		end
		else begin
			if (!sqrt_fsm_div_den) begin
				n_by_sqrt <= 0;
			end
			else if (sqrt_fsm_div_done) begin
				n_by_sqrt <= sqrt_fsm_div_quo;
			end
		end
	end
	
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			sqrt_fsm_div_done_delay <= 0;
			sqrt_fsm_div_done_delay_2 <= 0;
		end
		else begin
			sqrt_fsm_div_done_delay <= sqrt_fsm_div_done;
			sqrt_fsm_div_done_delay_2 <= sqrt_fsm_div_done_delay;
		end
	end


    reg [M_2_BITWIDTH -1:0] sqrt_delay;	//42-bit
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			sqrt_delay <= 0;
        end
		else begin
            sqrt_delay <= sqrt;
        end
    end
	
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            sqrt <= 0;
        end
        else if (sqrt_fsm_en /*| (vsync & (~prev_v_sync))*/) begin			// sqrt fsm begin; vertical blanking removed from inside sqrt fsm to help package sqrt fsm as verilog module
			sqrt <= 0;
		end
		else if(count == 0 & sqrt_fsm_en_delay) begin
            sqrt <= (sqrt_i + 2) >> 1;
        end
        else if(count > 1 & count < 14 && sqrt_fsm_div_done_delay) begin	//n_by_sqrt valid at sqrt_fsm_div_done_delay high state
            sqrt <= (sqrt_delay + n_by_sqrt) >> 1;
        end
    end
  
        
    /*
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            n_by_sqrt <= 62'd0;
        end
        else if(count == 0) begin
            n_by_sqrt <= number / sqrt_i;
        end
		else if(count > 0 & count < 15) begin
				n_by_sqrt <= number / sqrt;
        end
		else begin
				n_by_sqrt <= n_by_sqrt;
		end
    end
	*/
	
	//===== SQUARE ROOT FSM END =====//
        
    
	/*
    always @(posedge clk_slow or negedge rst_n) begin
        if (!rst_n) begin
            m2 <= 0;
            m3 <= 0;
        end
		else begin
            m2 <= sqrt * m_2;
            m3 <= {m_3,8'd0};
        end
    end
	*/
	
	
	
	
	reg [M2_BITWIDTH -1:0] m2;	//63-bit
	reg m2_sampled;
	reg [((27 + BITWIDTH_MAX_WIDTH + BITWIDTH_MAX_HEIGHT) + 8) - 1:0] m3;	//59-bit
	reg m3_sampled;
	wire m2_and_m3;
	assign m2_and_m3 = (m2_sampled & m3_sampled);
	
	reg sqrt_fsm_done_delay_1, sqrt_fsm_done_delay_2, sqrt_fsm_done_delay_3;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n)	begin
			sqrt_fsm_done_delay_1 <= 1'b0;
			sqrt_fsm_done_delay_2 <= 1'b0;
			sqrt_fsm_done_delay_3 <= 1'b0;
		end
		else begin
			sqrt_fsm_done_delay_1 <= sqrt_fsm_done;
			sqrt_fsm_done_delay_2 <= sqrt_fsm_done_delay_1;
			sqrt_fsm_done_delay_3 <= sqrt_fsm_done_delay_2;
		end
	end
	
	//adding 3 pipelined registers at the output of wide multiplier
	wire [M2_BITWIDTH -1:0] m2_product;
	assign m2_product = m_2 * sqrt[SQRT_BITWIDTH -1:0];	//sqrt(m_2) has half bitwidth of m_2
	reg [M2_BITWIDTH -1:0] m2_regs [2:0];	//63-bit
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			m2_regs[0] <= 0;
			m2_regs[1] <= 0;
			m2_regs[2] <= 0;
		end
		else begin
			m2_regs[0] <= m2_product;
			m2_regs[1] <= m2_regs[0];
			m2_regs[2] <= m2_regs[1];
		end
	
	end
	
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			m2 <= 0;
			m2_sampled <= 0;
		end
		else begin
			if (vsync & (~prev_v_sync)) begin	//reset at VSYNC rising edge (vertical blanking begin)
				m2 <= 0;
				m2_sampled <= 1'b0;
			end
			else if (m2_and_m3) begin	//if m2_sampled & m3_sampled both high, then reset
				m2_sampled <= 1'b0;					//to prevent retrigger of ae_skewness fsm divider
			end
			else if (sqrt_fsm_done_delay_3) begin
				m2 <= m2_regs[2];
				m2_sampled <= 1'b1;
			end
		end
	end
	
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			m3 <= 0;
			m3_sampled <= 1'b0;
		end
		else begin
			if (vsync & (~prev_v_sync)) begin	//reset at VSYNC rising edge (vertical blanking begin)
				m3 <= 0;
				m3_sampled <= 1'b0;
			end
			else if (m2_and_m3) begin
				m3_sampled <= 1'b0;
			end			
			else if (fsm_div_m_3_done_delay) begin	//when m_3 value is valid
				m3 <= {m_3, 8'b0};
				m3_sampled <= 1'b1;
			end			
		end	
	end
    
	wire fsm_div_ae_skewness_en, fsm_div_ae_skewness_done;
	assign fsm_div_ae_skewness_en = (m2_sampled & m3_sampled);
	
	wire [M2_BITWIDTH -1:0] num_fsm_div_ae_skewness, den_fsm_div_ae_skewness, quo_fsm_div_ae_skewness, rem_fsm_div_ae_skewness; //63-bit
	assign num_fsm_div_ae_skewness = m3;
	assign den_fsm_div_ae_skewness = m2;
	
	//FSM divider for AE skewness calculation, 63-bit divider
	shift_div #(M2_BITWIDTH) fsm_div_ae_skewness
	(
		.clk(pclk),
		.rst_n(rst_n),
		.enable(fsm_div_ae_skewness_en),
		.a(num_fsm_div_ae_skewness),
		.b(den_fsm_div_ae_skewness),
		.c(quo_fsm_div_ae_skewness),
		.d(rem_fsm_div_ae_skewness),
		.done(fsm_div_ae_skewness_done)
	);
	
	reg fsm_div_ae_skewness_done_delay, fsm_div_ae_skewness_done_delay_2;
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			fsm_div_ae_skewness_done_delay <= 1'b0;
			fsm_div_ae_skewness_done_delay_2 <= 1'b0;
		end
		else begin
			fsm_div_ae_skewness_done_delay <= fsm_div_ae_skewness_done;
			fsm_div_ae_skewness_done_delay_2 <= fsm_div_ae_skewness_done_delay;
		end
	end
	
	
	reg [15:0] ae_skewness;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            ae_skewness <= 0;
        end
        else if (den_fsm_div_ae_skewness == 0) begin	//divide by zero case
            ae_skewness <= 0;
        end
        else if (fsm_div_ae_skewness_done) begin
            ae_skewness <= quo_fsm_div_ae_skewness[15:0];
        end
    end
        
    reg [1:0] flag;
    always @(posedge pclk or negedge rst_n) begin				//valid flag at fsm_div_ae_skewness_done_delay HIGH
        if (!rst_n) begin
            flag <= 0;
        end
		else if(m_3_sign && (ae_skewness > skewness)) begin		//less than -1; underexposed
            flag <= 2'd3; 
        end
        else if(~m_3_sign && (ae_skewness > skewness)) begin	//greater than +1; overexposed
            flag <= 2'd1;
        end
        else begin												//within range; normal exposure
            flag <= 2'd0;
        end
    end
	
	always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            ae_response <= 0;
            ae_result_skewness <= 0;
            ae_response_debug <= 0;
        end
        else if(fsm_div_ae_skewness_done_delay_2) begin		//prev. VSYNC rising edge
            ae_response <= flag;
            ae_result_skewness <= ae_skewness;
            ae_response_debug <= flag;
        end
        else begin
            ae_response <= 0;								//important for external circuitry of updating DG index
            ae_result_skewness <= ae_result_skewness;
            ae_response_debug <= ae_response_debug;
        end
    end
	
	always @(posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			ae_done <= 1'b0;
		end
		else begin
			if (fsm_div_ae_skewness_done_delay_2) begin
				ae_done <= 1'b1;
			end
			else begin
				ae_done <= 1'b0;
			end
		end
	end
	

	//===== debug ports =====//
	/*assign cropped_size = crop_window_size;
	assign sum_pix_square = pix_square_sum;
	assign sum_pix_cube = pix_cube_sum_positive;
	assign div_out_m_2 = m_2;
	assign div_out_m_3 = m_3;
	assign div_out_sqrt_fsm = n_by_sqrt;
	assign sqrt_fsm_out_sqrt = sqrt;
	assign div_out_ae_skewness = ae_skewness;
	assign SQRT_FSM_EN = sqrt_fsm_en;
	assign SQRT_FSM_DIV_EN = sqrt_fsm_div_en;
	assign SQRT_FSM_DIV_DONE = sqrt_fsm_div_done;
	assign SQRT_FSM_DONE = sqrt_fsm_done;
	assign SQRT_FSM_COUNT = count;*/
	//===== debug ports =====//


endmodule
