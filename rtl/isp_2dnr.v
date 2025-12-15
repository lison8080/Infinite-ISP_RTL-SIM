/*************************************************************************
> File Name: isp_2dnr.v
> Description: 2D noise Reduction
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - 2D noise Reduction
 */

module isp_2dnr
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter WEIGHT_BITS = 5,
	parameter LUT_SIZE = 15
	
)
(
    input pclk,
	input rst_n,
	
	input [LUT_SIZE*BITS-1:0]          diff_value,// difference array for approximation of exponential for y channel pixels
	input [LUT_SIZE*WEIGHT_BITS-1:0]   weight,// weights for y pixels corresponding to difference

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_y,
	input [BITS-1:0] in_u,
	input [BITS-1:0] in_v,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_y, 
	output [BITS-1:0] out_u,
	output [BITS-1:0] out_v
);

localparam DEBUG = 0;

wire [BITS-1:0] diff_value_wire [LUT_SIZE-1:0];
wire [WEIGHT_BITS-1:0]   weight_wire[LUT_SIZE-1:0];

// splitting up kernel weights and difference levels into arrays for the ease of referencing 
generate
genvar i;
for (i = 0; i < LUT_SIZE; i = i + 1) begin // range kernel quantized weights
	assign diff_value_wire[i] = diff_value[(BITS*i)+:BITS];
	assign weight_wire[i] = weight[(WEIGHT_BITS*i)+:WEIGHT_BITS];
	end
endgenerate
    
    // Line buffer for y channel 
    wire [BITS-1:0] shiftout;
	wire [BITS-1:0] tap7x, tap6x, tap5x, tap4x,tap3x, tap2x, tap1x, tap0x;
	shift_register #(BITS, WIDTH, 8) linebuffer(pclk, in_href, in_y, shiftout, {tap7x, tap6x, tap5x, tap4x,tap3x, tap2x, tap1x, tap0x});
	
	reg [BITS-1:0] in_data_y;
	reg [BITS-1:0] m_t1[9*9-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_p_t1
		integer i, j;
		if (!rst_n) begin
			in_data_y <= 0;
			for (i = 0; i < 9*9; i = i + 1)
				m_t1[i] <= 0;
		end
		else begin
			in_data_y <= in_y;
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 8; j = j + 1)
					m_t1[i*9+j] <= m_t1[i*9+j+1];
			
			m_t1[0*9+8] <= tap7x;
			m_t1[1*9+8] <= tap6x;
			m_t1[2*9+8] <= tap5x; 
			m_t1[3*9+8] <= tap4x;
			m_t1[4*9+8] <= tap3x;
			m_t1[5*9+8] <= tap2x;
			m_t1[6*9+8] <= tap1x;
			m_t1[7*9+8] <= tap0x;
			m_t1[8*9+8] <= in_data_y;
		end
	end
	reg [BITS-1:0] m_t2[9*9-1:0];
	reg [BITS-1:0] m_t3[9*9-1:0];
	
	// Shifting the input value for y channel
	always @ (posedge pclk or negedge rst_n) begin : _blk_m_t2
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 9*9; i = i + 1) begin
				m_t2[i] <= 0;
				m_t3[i] <= 0;
			end
		end
		else begin
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 9; j = j + 1) begin
					m_t2[i*9+j] <= m_t1[i*9+j];
					m_t3[i*9+j] <= m_t2[i*9+j];
				end
		end
	end
	
	// Line buffer for u channel 
    wire [BITS-1:0] u_shiftout;
	wire [BITS-1:0] u_tap3x, u_tap2x, u_tap1x, u_tap0x;
	shift_register #(BITS, WIDTH, 4) linebuffer_u(pclk, in_href, in_u, u_shiftout, {u_tap3x, u_tap2x, u_tap1x, u_tap0x});
	
	// Line buffer for v channel
	wire [BITS-1:0] v_shiftout;
	wire [BITS-1:0] v_tap3x, v_tap2x, v_tap1x, v_tap0x;
	shift_register #(BITS, WIDTH, 4) linebuffer_v(pclk, in_href, in_v, v_shiftout, {v_tap3x, v_tap2x, v_tap1x, v_tap0x});
	
	// pipeline delay for u and v channels
	reg [BITS-1:0] u_t1 [4:0];
	reg [BITS-1:0] v_t1 [4:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_uv
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 5; i = i + 1)
				u_t1[i] <= 0;
		end
		else begin
			u_t1[4] <= u_tap3x;
			v_t1[4] <= v_tap3x;
			for (i = 0; i < 4; i = i + 1) begin
				 u_t1[i] <= u_t1[i+1];
				 v_t1[i] <= v_t1[i+1];
			end
	     end
    end
    wire [2*BITS-1:0] uv_t1;
    assign uv_t1 = {u_t1[0],v_t1[0]};
    
	// Taking difference with center pixel
    reg [2*BITS-1:0] uv_t2;
    reg [BITS-1:0] diff_t2[9*9-1:0];
    always @ (posedge pclk or negedge rst_n) begin : _blk_diff_t2
		integer i, j;
		if (!rst_n) begin
		    uv_t2 <= 0;
			for (i = 0; i < 9*9; i = i + 1)
				diff_t2[i] <= 0;
		end
		else begin
		    uv_t2 <= uv_t1;
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 9; j = j + 1)
					diff_t2[i*9+j] <= m_t1[4*9+4] < m_t1[i*9+j] ? m_t1[i*9+j] - m_t1[4*9+4] : m_t1[4*9+4] - m_t1[i*9+j];
		end
	end

// Comparing the calculated difference with elements of difference array to assign weight based on position
reg [2*BITS-1:0] uv_t3;
reg  [WEIGHT_BITS-1:0] weight_t3[9*9-1:0];
wire [WEIGHT_BITS-1:0] weight_max = {BITS{1'b1}}; // maximum possible for now
always @ (posedge pclk or negedge rst_n) begin : _blk_weight_t3
	integer i, j;
	if (!rst_n) begin
		for (i = 0; i < 9*9; i = i + 1) begin
			weight_t3[i] <= 0;
			uv_t3 <= 0;
		end
	end
	else begin
	    uv_t3 <= uv_t2;
		for (i = 0; i < 9; i = i + 1)
    		for (j = 0; j < 9; j = j + 1)
	//			if (diff_t2[i*9+j] < diff_value_wire[])
	//				weight_t3[i*9+j] <= weight_max;
    //			else if (diff_t2[i*9+j] < diff_value_wire[1])
			    if (diff_t2[i*9+j] < diff_value_wire[1])
                  weight_t3[i*9+j] <= weight_wire[0];
                else if (diff_t2[i*9+j] < diff_value_wire[2])
                  weight_t3[i*9+j] <= weight_wire[1];
                else if (diff_t2[i*9+j] < diff_value_wire[3])
                  weight_t3[i*9+j] <= weight_wire[2];
                else if (diff_t2[i*9+j] < diff_value_wire[4])
                  weight_t3[i*9+j] <= weight_wire[3];
                else if (diff_t2[i*9+j] < diff_value_wire[5])
                  weight_t3[i*9+j] <= weight_wire[4];
                else if (diff_t2[i*9+j] < diff_value_wire[6])
                  weight_t3[i*9+j] <= weight_wire[5];
                else if (diff_t2[i*9+j] < diff_value_wire[7])
                  weight_t3[i*9+j] <= weight_wire[6];
                else if (diff_t2[i*9+j] < diff_value_wire[8])
                  weight_t3[i*9+j] <= weight_wire[7];
                else if (diff_t2[i*9+j] < diff_value_wire[9])
                  weight_t3[i*9+j] <= weight_wire[8];
                else if (diff_t2[i*9+j] < diff_value_wire[10])
                  weight_t3[i*9+j] <= weight_wire[9];
                else if (diff_t2[i*9+j] < diff_value_wire[11])
                  weight_t3[i*9+j] <= weight_wire[10];
                else if (diff_t2[i*9+j] < diff_value_wire[12])
                  weight_t3[i*9+j] <= weight_wire[11];
                else if (diff_t2[i*9+j] < diff_value_wire[13])
                  weight_t3[i*9+j] <= weight_wire[12];
                else if (diff_t2[i*9+j] < diff_value_wire[14])
                  weight_t3[i*9+j] <= weight_wire[13];
                else if (diff_t2[i*9+j] < diff_value_wire[15])
                  weight_t3[i*9+j] <= weight_wire[14];
                else if (diff_t2[i*9+j] < diff_value_wire[16])
                  weight_t3[i*9+j] <= weight_wire[15];
                else if (diff_t2[i*9+j] < diff_value_wire[17])
                  weight_t3[i*9+j] <= weight_wire[16];
                else if (diff_t2[i*9+j] < diff_value_wire[18])
                  weight_t3[i*9+j] <= weight_wire[17];
                else if (diff_t2[i*9+j] < diff_value_wire[19])
                  weight_t3[i*9+j] <= weight_wire[18];
                else if (diff_t2[i*9+j] < diff_value_wire[20])
                  weight_t3[i*9+j] <= weight_wire[19];
                else if (diff_t2[i*9+j] < diff_value_wire[21])
                  weight_t3[i*9+j] <= weight_wire[20];
                else if (diff_t2[i*9+j] < diff_value_wire[22])
                  weight_t3[i*9+j] <= weight_wire[21];
                else if (diff_t2[i*9+j] < diff_value_wire[23])
                  weight_t3[i*9+j] <= weight_wire[22];
                else if (diff_t2[i*9+j] < diff_value_wire[24])
                  weight_t3[i*9+j] <= weight_wire[23];
                else if (diff_t2[i*9+j] < diff_value_wire[25])
                  weight_t3[i*9+j] <= weight_wire[24];
                else if (diff_t2[i*9+j] < diff_value_wire[26])
                  weight_t3[i*9+j] <= weight_wire[25];
                else if (diff_t2[i*9+j] < diff_value_wire[27])
                  weight_t3[i*9+j] <= weight_wire[26];
                else if (diff_t2[i*9+j] < diff_value_wire[28])
                  weight_t3[i*9+j] <= weight_wire[27];
                else if (diff_t2[i*9+j] < diff_value_wire[29])
                  weight_t3[i*9+j] <= weight_wire[28];
                else if (diff_t2[i*9+j] < diff_value_wire[30])
                  weight_t3[i*9+j] <= weight_wire[29];
                else if (diff_t2[i*9+j] < diff_value_wire[31])
                  weight_t3[i*9+j] <= weight_wire[30];
				else
                  weight_t3[i*9+j] <= weight_wire[31];
	end
end

    //row wise sum of weights t4
	reg [WEIGHT_BITS+4-1:0] weight_sum_t4[8:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_weight_sum_t4
		integer i;
		if (!rst_n) begin
			for (i = 0; i < 9; i = i + 1)
				weight_sum_t4[i] <= 0;
		end
		else begin
			for (i = 0; i < 9; i = i + 1)
				weight_sum_t4[i] <= weight_t3[i*9+0] + weight_t3[i*9+1] + weight_t3[i*9+2] + weight_t3[i*9+3] + weight_t3[i*9+4] + weight_t3[i*9+5] + weight_t3[i*9+6] + weight_t3[i*9+7] + weight_t3[i*9+8];
		end
	end
	
	//column wise sum of weights t5, adding a delay t6
	reg [WEIGHT_BITS+7-1:0] weight_sum_t5;
	reg [WEIGHT_BITS+7-1:0] weight_sum_t6;

	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			weight_sum_t5 <= 0;
			weight_sum_t6 <= 0;
		end
		else begin
			weight_sum_t5 <= weight_sum_t4[0] + weight_sum_t4[1] + weight_sum_t4[2] + weight_sum_t4[3] + weight_sum_t4[4] + weight_sum_t4[5] + weight_sum_t4[6] + weight_sum_t4[7] + weight_sum_t4[8];
			weight_sum_t6 <= weight_sum_t5;
		end
	end


// Applying filter on y channel
reg [2*BITS-1:0] uv_t4;
reg [BITS+WEIGHT_BITS-1:0] value_mul_t4[9*9-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_value_mul_t5
		integer i, j;
		if (!rst_n) begin
		    uv_t4 <= 0;
			for (i = 0; i < 9*9; i = i + 1)
				value_mul_t4[i] <= 0;
		end
		else begin
		    uv_t4 <= uv_t3;
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 9; j = j + 1)
					value_mul_t4[i*9+j] <= weight_t3[i*9+j] * m_t3[i*9+j];
		end
	end	

// computing sum along the row t5
reg [2*BITS-1:0] uv_t5;	
reg [BITS+WEIGHT_BITS+4-1:0] value_sum_x_t5[8:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_value_sum_x_t5
		integer i;
		if (!rst_n) begin
		    uv_t5 <= 0;
			for (i = 0; i < 9; i = i + 1)
				value_sum_x_t5[i] <= 0;
		end
		else begin
		    uv_t5 <= uv_t4;
			for (i = 0; i < 9; i = i + 1)
				value_sum_x_t5[i] <= value_mul_t4[i*9+0] + value_mul_t4[i*9+1] + value_mul_t4[i*9+2] + value_mul_t4[i*9+3] + value_mul_t4[i*9+4] + value_mul_t4[i*9+5] + value_mul_t4[i*9+6] + value_mul_t4[i*9+7] + value_mul_t4[i*9+8];
		end
	end 

// Adding rows to get accumulated result t6
reg [2*BITS-1:0] uv_t6;
reg [BITS+WEIGHT_BITS+7-1:0] value_sum_t6;	

	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
		    uv_t6 <= 0;
			value_sum_t6 <= 0;
		end
		else begin
		    uv_t6 <= uv_t5;
			value_sum_t6 <= value_sum_x_t5[0] + value_sum_x_t5[1] + value_sum_x_t5[2] + value_sum_x_t5[3] + value_sum_x_t5[4] + value_sum_x_t5[5] + value_sum_x_t5[6] + value_sum_x_t5[7] + value_sum_x_t5[8];
		end
	end

// Dividing the accumulated value by sum of kernel weights to get normalized value
wire [BITS+WEIGHT_BITS+1+7-1:0] num, den;  // +1 to shift the numenator to the left
assign den = {{1'b0},{BITS{1'b0}},{weight_sum_t6}};
assign num = {value_sum_t6,{1'b0}};
wire [BITS+WEIGHT_BITS+7+1-1:0] target_quo, target_rem;
shift_div_uint #(BITS+WEIGHT_BITS+7+1) target_div_g (pclk, rst_n, num, den, target_quo, target_rem); 

wire [BITS-1:0] nr2d_u, nr2d_v;
data_delay #(BITS, (BITS+WEIGHT_BITS+7+1)) nr2d_delay_u (pclk, rst_n, uv_t6[2*BITS-1:BITS], nr2d_u);
data_delay #(BITS, (BITS+WEIGHT_BITS+7+1)) nr2d_delay_v (pclk, rst_n, uv_t6[BITS-1:0], nr2d_v);
reg [BITS-1:0] out_y_final_1, out_u_final_1, out_v_final_1;
reg round;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			out_y_final_1 <= 0;
			out_u_final_1 <= 0;
			out_v_final_1 <= 0;	
			round <= 0;		
		end else begin
		    round <= target_quo[0];
			out_y_final_1 <= (|target_quo[BITS+WEIGHT_BITS+7+1-1:BITS+1]) ? {BITS{1'b1}} :  target_quo[BITS:1];
			out_u_final_1 <= nr2d_u;
			out_v_final_1 <= nr2d_v;
		end
	end

// Round off the ouput value
reg [BITS-1:0] out_y_final, out_u_final, out_v_final;
always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			out_y_final <= 0;
			out_u_final <= 0;
			out_v_final <= 0;			
		end 
		else begin
		 out_u_final <=  out_u_final_1;
		 out_v_final <=  out_v_final_1;
		 if (round == 1 & out_y_final_1 < {BITS{1'b1}}) 
		        out_y_final <= out_y_final_1 + 1'b1;
		 else 
		        out_y_final <= out_y_final_1;
		   
		end
	end 
	 
// delay for href and vsync
localparam DLY_CLK = 14+BITS+WEIGHT_BITS+7;
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

// counting in_href and out_href 
generate
	if (DEBUG) begin:d_counter
		reg [32:0] counter_in, counter_out;

		always @ (posedge pclk or negedge rst_n) begin  
		   if (!rst_n) begin
		       counter_in <= 0;
		   end else if (in_href) begin
		       counter_in <= counter_in +1;
		   end else begin
		       counter_in <= counter_in;
		   end 
	    end

	    always @ (posedge pclk or negedge rst_n) begin  
		   if (!rst_n) begin
		       counter_out <= 0;
		   end else if (out_href) begin
		       counter_out <= counter_out +1;
		   end else begin
		       counter_out <= counter_out;
		   end 
	    end
	
	   	reg [15:0] q_debug;
	
	   	always @(*) begin
			q_debug = value_sum_t6 / weight_sum_t6;
	    end        
	end
endgenerate

assign out_href = href_dly[DLY_CLK-1];
assign out_vsync = vsync_dly[DLY_CLK-1];
assign out_y = out_href ? out_y_final : {BITS{1'b0}};
assign out_u = out_href ? out_u_final : {BITS{1'b0}};
assign out_v = out_href ? out_v_final : {BITS{1'b0}};

endmodule
