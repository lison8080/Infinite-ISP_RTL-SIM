/*************************************************************************
> File Name: isp_jbf.v
> Description: Joint Bilateral Filter for Bayer Noise Reduction
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Noise Reduction
 * Gaussian Filter
 */

module isp_jbf
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
	parameter WEIGHT_BITS = 5
	)
(
	input pclk,
	input rst_n,

    input [5*5*WEIGHT_BITS-1:0] space_kernel_r,
	input [5*5*WEIGHT_BITS-1:0] space_kernel_g,
	input [5*5*WEIGHT_BITS-1:0] space_kernel_b,
	input [9*BITS-1:0]          color_curve_x_r,  // difference array for approximation of exponential for red pixels
	input [9*WEIGHT_BITS-1:0]   color_curve_y_r,  // weights for red pixels corresponding to difference
	input [9*BITS-1:0]          color_curve_x_g,  // difference array for approximation of exponential for green pixels
	input [9*WEIGHT_BITS-1:0]   color_curve_y_g,  // weights for red pixels corresponding to difference 
	input [9*BITS-1:0]          color_curve_x_b,  // difference array for approximation of exponential for blue pixels
	input [9*WEIGHT_BITS-1:0]   color_curve_y_b,  // weights for blue pixels corresponding to difference
	
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	input [BITS-1:0] in_green,
	

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_raw
);
// DEBUG block moved after p_rb_t1 and p_g_t1 declarations (see below)
localparam DEBUG = 0;
    reg [BITS-1:0]        color_curve_x_wire[9-1:0];
	reg [WEIGHT_BITS-1:0] color_curve_y_wire[9-1:0];
	reg [WEIGHT_BITS-1:0] space_weight_wire[5*5-1:0];
	reg [WEIGHT_BITS-1:0] color_weight_wire[5*5-1:0];
	wire [BITS-1:0]        color_curve_x_g_wire[9-1:0];
	wire [WEIGHT_BITS-1:0] color_curve_y_g_wire[9-1:0];
	wire [BITS-1:0]        color_curve_x_r_wire[9-1:0];
	wire [WEIGHT_BITS-1:0] color_curve_y_r_wire[9-1:0];
	wire [BITS-1:0]        color_curve_x_b_wire[9-1:0];
	wire [WEIGHT_BITS-1:0] color_curve_y_b_wire[9-1:0];
	wire [WEIGHT_BITS-1:0] space_weight_g_wire[5*5-1:0];
    wire [WEIGHT_BITS-1:0] space_weight_r_wire[5*5-1:0];
    wire [WEIGHT_BITS-1:0] space_weight_b_wire[5*5-1:0];
	
	// splitting up kernel weights and differnce levels into arrays for the ease of referencing
	generate
		genvar i, j;  
		for (i = 0; i < 5; i = i + 1) begin   // rb space kernel weights
			for (j = 0; j < 5; j = j + 1) begin
				assign space_weight_r_wire[i*5+j] = space_kernel_r[WEIGHT_BITS*(i*5+j)+:WEIGHT_BITS];
				assign space_weight_g_wire[i*5+j] = space_kernel_g[WEIGHT_BITS*(i*5+j)+:WEIGHT_BITS];
				assign space_weight_b_wire[i*5+j] = space_kernel_b[WEIGHT_BITS*(i*5+j)+:WEIGHT_BITS];
			end
		end		
		for (i = 0; i < 9; i = i + 1) begin // range kernel quantized weights
			assign color_curve_x_r_wire[i] = color_curve_x_r[(BITS*i)+:BITS];
			assign color_curve_y_r_wire[i] = color_curve_y_r[(WEIGHT_BITS*i)+:WEIGHT_BITS];
			assign color_curve_x_g_wire[i] = color_curve_x_g[(BITS*i)+:BITS];
			assign color_curve_y_g_wire[i] = color_curve_y_g[(WEIGHT_BITS*i)+:WEIGHT_BITS];
			assign color_curve_x_b_wire[i] = color_curve_x_b[(BITS*i)+:BITS];
			assign color_curve_y_b_wire[i] = color_curve_y_b[(WEIGHT_BITS*i)+:WEIGHT_BITS];
		end
		
	endgenerate
    
	// line buffers for raw
	// As we have window size of 9x9, so we need to save 8 rows in linebuffers while the current input row is realized with shift registers
	wire [BITS-1:0] shiftout;  
	wire [BITS-1:0] tap7x, tap6x, tap5x, tap4x,tap3x, tap2x, tap1x, tap0x;
	shift_register #(BITS, WIDTH, 8) linebuffer(pclk, in_href, in_raw, shiftout, {tap7x, tap6x, tap5x, tap4x,tap3x, tap2x, tap1x, tap0x});
	
	reg [BITS-1:0] in_data_r;
	reg [BITS-1:0] p_rb_t1[9*9-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_p_t1
		integer i, j;
		if (!rst_n) begin
			in_data_r <= 0;
			for (i = 0; i < 9*9; i = i + 1)
				p_rb_t1[i] <= 0;
		end
		else begin
			in_data_r <= in_raw;
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 8; j = j + 1)
					p_rb_t1[i*9+j] <= p_rb_t1[i*9+j+1];
			
			p_rb_t1[0*9+8] <= tap7x;
			p_rb_t1[1*9+8] <= tap6x;
			p_rb_t1[2*9+8] <= tap5x; 
			p_rb_t1[3*9+8] <= tap4x;
			p_rb_t1[4*9+8] <= tap3x;
			p_rb_t1[5*9+8] <= tap2x;
			p_rb_t1[6*9+8] <= tap1x;
			p_rb_t1[7*9+8] <= tap0x;
			p_rb_t1[8*9+8] <= in_data_r;
		end
	end

	// line buffers for green channel
	wire [BITS-1:0] g_shiftout; 
	wire [BITS-1:0] tap7x_g, tap6x_g, tap5x_g, tap4x_g, tap3x_g, tap2x_g, tap1x_g, tap0x_g;
	shift_register #(BITS, WIDTH, 8) linebufferGreen(pclk, in_href, in_green, g_shiftout, {tap7x_g, tap6x_g, tap5x_g, tap4x_g, tap3x_g, tap2x_g, tap1x_g, tap0x_g});
	
	reg [BITS-1:0] in_data_g;
	reg [BITS-1:0] p_g_t1[9*9-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_p_g_t1
		integer i, j;
		if (!rst_n) begin
			in_data_g <= 0;
			for (i = 0; i < 9*9; i = i + 1)
				p_g_t1[i] <= 0;
		end
		else begin
			in_data_g <= in_green;
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 8; j = j + 1)
					p_g_t1[i*9+j] <= p_g_t1[i*9+j+1];
			
			p_g_t1[0*9+8] <= tap7x_g;
			p_g_t1[1*9+8] <= tap6x_g;
			p_g_t1[2*9+8] <= tap5x_g; 
			p_g_t1[3*9+8] <= tap4x_g;
			p_g_t1[4*9+8] <= tap3x_g;
			p_g_t1[5*9+8] <= tap2x_g;
			p_g_t1[6*9+8] <= tap1x_g;
			p_g_t1[7*9+8] <= tap0x_g;
			p_g_t1[8*9+8] <= in_data_g;
		end
	end

// verifying validity of input frames (DEBUG block)
generate
if ( DEBUG == 1) begin : debug
    
tb_dvp_to_file
	#(
		"inputRawWindows9x9.bin", 
		81*16  // 3 x BITS  for three channels    
	 )
	dvp2file_rb_9x9
	(
		.pclk(pclk), 
		.rst_n(rst_n),
		.href(in_href),
		.vsync(in_vsync),
		.data({ 
		{4'd0,p_rb_t1[80]},{4'd0,p_rb_t1[79]},{4'd0,p_rb_t1[78]},{4'd0,p_rb_t1[77]},{4'd0,p_rb_t1[76]},{4'd0,p_rb_t1[75]},{4'd0,p_rb_t1[74]},{4'd0,p_rb_t1[73]},{4'd0,p_rb_t1[72]},
		{4'd0,p_rb_t1[71]},{4'd0,p_rb_t1[70]},{4'd0,p_rb_t1[69]},{4'd0,p_rb_t1[68]},{4'd0,p_rb_t1[67]},{4'd0,p_rb_t1[66]},{4'd0,p_rb_t1[65]},{4'd0,p_rb_t1[64]},{4'd0,p_rb_t1[63]},
		{4'd0,p_rb_t1[62]},{4'd0,p_rb_t1[61]},{4'd0,p_rb_t1[60]},{4'd0,p_rb_t1[59]},{4'd0,p_rb_t1[58]},{4'd0,p_rb_t1[57]},{4'd0,p_rb_t1[56]},{4'd0,p_rb_t1[55]},{4'd0,p_rb_t1[54]},
		{4'd0,p_rb_t1[53]},{4'd0,p_rb_t1[52]},{4'd0,p_rb_t1[51]},{4'd0,p_rb_t1[50]},{4'd0,p_rb_t1[49]},{4'd0,p_rb_t1[48]},{4'd0,p_rb_t1[47]},{4'd0,p_rb_t1[46]},{4'd0,p_rb_t1[45]},
		{4'd0,p_rb_t1[44]},{4'd0,p_rb_t1[43]},{4'd0,p_rb_t1[42]},{4'd0,p_rb_t1[41]},{4'd0,p_rb_t1[40]},{4'd0,p_rb_t1[39]},{4'd0,p_rb_t1[38]},{4'd0,p_rb_t1[37]},{4'd0,p_rb_t1[36]},
		{4'd0,p_rb_t1[35]},{4'd0,p_rb_t1[34]},{4'd0,p_rb_t1[33]},{4'd0,p_rb_t1[32]},{4'd0,p_rb_t1[31]},{4'd0,p_rb_t1[30]},{4'd0,p_rb_t1[29]},{4'd0,p_rb_t1[28]},{4'd0,p_rb_t1[27]},
		{4'd0,p_rb_t1[26]},{4'd0,p_rb_t1[25]},{4'd0,p_rb_t1[24]},{4'd0,p_rb_t1[23]},{4'd0,p_rb_t1[22]},{4'd0,p_rb_t1[21]},{4'd0,p_rb_t1[20]},{4'd0,p_rb_t1[19]},{4'd0,p_rb_t1[18]},
		{4'd0,p_rb_t1[17]},{4'd0,p_rb_t1[16]},{4'd0,p_rb_t1[15]},{4'd0,p_rb_t1[14]},{4'd0,p_rb_t1[13]},{4'd0,p_rb_t1[12]},{4'd0,p_rb_t1[11]},{4'd0,p_rb_t1[10]},{4'd0,p_rb_t1[9]},
		{4'd0,p_rb_t1[8]},{4'd0,p_rb_t1[7]},{4'd0,p_rb_t1[6]},{4'd0,p_rb_t1[5]},{4'd0,p_rb_t1[4]},{4'd0,p_rb_t1[3]},{4'd0,p_rb_t1[2]},{4'd0,p_rb_t1[1]},{4'd0,p_rb_t1[0]}
		})
	);
	tb_dvp_to_file
	#(
    "inputGreenWindows9x9.bin",
	81*16  // 3 x BITS  for three channels       
	 )
	dvp2file_g_9x9
	(
		.pclk(pclk), 
		.rst_n(rst_n),
		.href(in_href),
		.vsync(in_vsync),
		.data({ 
		{4'd0,p_g_t1[80]},{4'd0,p_g_t1[79]},{4'd0,p_g_t1[78]},{4'd0,p_g_t1[77]},{4'd0,p_g_t1[76]},{4'd0,p_g_t1[75]},{4'd0,p_g_t1[74]},{4'd0,p_g_t1[73]},{4'd0,p_g_t1[72]},
		{4'd0,p_g_t1[71]},{4'd0,p_g_t1[70]},{4'd0,p_g_t1[69]},{4'd0,p_g_t1[68]},{4'd0,p_g_t1[67]},{4'd0,p_g_t1[66]},{4'd0,p_g_t1[65]},{4'd0,p_g_t1[64]},{4'd0,p_g_t1[63]},
		{4'd0,p_g_t1[62]},{4'd0,p_g_t1[61]},{4'd0,p_g_t1[60]},{4'd0,p_g_t1[59]},{4'd0,p_g_t1[58]},{4'd0,p_g_t1[57]},{4'd0,p_g_t1[56]},{4'd0,p_g_t1[55]},{4'd0,p_g_t1[54]},
		{4'd0,p_g_t1[53]},{4'd0,p_g_t1[52]},{4'd0,p_g_t1[51]},{4'd0,p_g_t1[50]},{4'd0,p_g_t1[49]},{4'd0,p_g_t1[48]},{4'd0,p_g_t1[47]},{4'd0,p_g_t1[46]},{4'd0,p_g_t1[45]},
		{4'd0,p_g_t1[44]},{4'd0,p_g_t1[43]},{4'd0,p_g_t1[42]},{4'd0,p_g_t1[41]},{4'd0,p_g_t1[40]},{4'd0,p_g_t1[39]},{4'd0,p_g_t1[38]},{4'd0,p_g_t1[37]},{4'd0,p_g_t1[36]},
		{4'd0,p_g_t1[35]},{4'd0,p_g_t1[34]},{4'd0,p_g_t1[33]},{4'd0,p_g_t1[32]},{4'd0,p_g_t1[31]},{4'd0,p_g_t1[30]},{4'd0,p_g_t1[29]},{4'd0,p_g_t1[28]},{4'd0,p_g_t1[27]},
		{4'd0,p_g_t1[26]},{4'd0,p_g_t1[25]},{4'd0,p_g_t1[24]},{4'd0,p_g_t1[23]},{4'd0,p_g_t1[22]},{4'd0,p_g_t1[21]},{4'd0,p_g_t1[20]},{4'd0,p_g_t1[19]},{4'd0,p_g_t1[18]},
		{4'd0,p_g_t1[17]},{4'd0,p_g_t1[16]},{4'd0,p_g_t1[15]},{4'd0,p_g_t1[14]},{4'd0,p_g_t1[13]},{4'd0,p_g_t1[12]},{4'd0,p_g_t1[11]},{4'd0,p_g_t1[10]},{4'd0,p_g_t1[9]},
		{4'd0,p_g_t1[8]},{4'd0,p_g_t1[7]},{4'd0,p_g_t1[6]},{4'd0,p_g_t1[5]},{4'd0,p_g_t1[4]},{4'd0,p_g_t1[3]},{4'd0,p_g_t1[2]},{4'd0,p_g_t1[1]},{4'd0,p_g_t1[0]}
		})
	);
	
    end
endgenerate
	
	// blocks for current pixel's Bayer detection and its propgation to next stages of pipeline
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
	reg [1:0] fmt[3:0];
	always @ (posedge pclk or negedge rst_n) begin :_bayer
	   integer i;
	   if (!rst_n) begin
	       for (i = 0; i < 4 ; i = i+1) begin
	            fmt[i] <= 0;
	       end
	       end else begin
	           fmt [0] <= format;
	           for ( i = 1 ; i < 4; i = i+1) begin
	                fmt[i] <= fmt[i-1];
	                end 
	           end
	    end
	   
	
	// slecting 5x5 window from 9x9 input based on pixel's Bayer filter
    reg [BITS-1:0] p_t2[5*5-1:0];
	reg [BITS-1:0] p_t3[5*5-1:0];
	reg [BITS-1:0] p_t4[5*5-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_p_t2
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 5*5; i = i + 1) begin
				p_t2[i] <= 0;
				p_t3[i] <= 0;
				p_t4[i] <= 0;
			end
		end
		else begin
		    if ((fmt[1] == 2'd1) || (fmt[1] == 2'd2)) begin : for_green
			for (i = 0; i < 5; i = i + 1)
				for (j = 0; j < 5; j = j + 1) begin
					p_t2[i*5+j] <= p_g_t1[(i+2)*9+ (j+2)];
					p_t3[i*5+j] <= p_t2[i*5+j];
					p_t4[i*5+j] <= p_t3[i*5+j];
				end
			end
			else begin : for_rb
			     for (i = 0; i < 5; i = i + 1)
				for (j = 0; j < 5; j = j + 1) begin : for_rb
					p_t2[i*5+j] <= p_rb_t1[i*9*2+j*2];
					p_t3[i*5+j] <= p_t2[i*5+j];
					p_t4[i*5+j] <= p_t3[i*5+j];
				end
			
		end
end 
end 	
	
	

	
	// computing difference of all pixels with center pixel for green channel
	reg [BITS-1:0] diff_t2[9*9-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_diff_t2
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 9*9; i = i + 1)
				diff_t2[i] <= 0;
		end
		else begin
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 9; j = j + 1)
					diff_t2[i*9+j] <= p_g_t1[4*9+4] < p_g_t1[i*9+j] ? p_g_t1[i*9+j] - p_g_t1[4*9+4] : p_g_t1[4*9+4] - p_g_t1[i*9+j];
		end
	end
	
	// selecting color curve
	always @(*) begin : _mux
	integer i;
	case (fmt[2])
	2'b00: begin 
	       for (i = 0; i < 9; i = i + 1) begin
	           color_curve_x_wire[i] = color_curve_x_r_wire[i];
	           color_curve_y_wire[i] = color_curve_y_r_wire[i];
	           end
	       end
	2'b01: begin 
	       for (i = 0; i < 9; i = i + 1) begin
	           color_curve_x_wire[i] = color_curve_x_g_wire[i];
	           color_curve_y_wire[i] = color_curve_y_g_wire[i];
	           end
	       end
	2'b10: begin 
	       for (i = 0; i < 9; i = i + 1) begin
	           color_curve_x_wire[i] = color_curve_x_g_wire[i];
	           color_curve_y_wire[i] = color_curve_y_g_wire[i];
	           end
	       end
	2'b11: begin 
	       for (i = 0; i < 9; i = i + 1) begin
	           color_curve_x_wire[i] = color_curve_x_b_wire[i];
	           color_curve_y_wire[i] = color_curve_y_b_wire[i];
	           end
	       end     
	  
	endcase
	end            
	
	

	//for green interpolation
	reg  [WEIGHT_BITS-1:0] color_weight_t3[9*9-1:0];
	wire [WEIGHT_BITS-1:0] color_weight_max = space_weight_g_wire[2*5+2];
	always @ (posedge pclk or negedge rst_n) begin : _blk_color_weight_t3
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 9*9; i = i + 1)
				color_weight_t3[i] <= 0;
		end
		else begin
			for (i = 0; i < 9; i = i + 1)
				for (j = 0; j < 9; j = j + 1)
					if (diff_t2[i*9+j] < color_curve_x_wire[0])
						color_weight_t3[i*9+j] <= color_weight_max;
					else if (diff_t2[i*9+j] < color_curve_x_wire[1])
						color_weight_t3[i*9+j] <= color_curve_y_wire[0];
					else if (diff_t2[i*9+j] < color_curve_x_wire[2])
						color_weight_t3[i*9+j] <= color_curve_y_wire[1];
					else if (diff_t2[i*9+j] < color_curve_x_wire[3])
						color_weight_t3[i*9+j] <= color_curve_y_wire[2];
					else if (diff_t2[i*9+j] < color_curve_x_wire[4])
						color_weight_t3[i*9+j] <= color_curve_y_wire[3];
					else if (diff_t2[i*9+j] < color_curve_x_wire[5])
						color_weight_t3[i*9+j] <= color_curve_y_wire[4];
					else if (diff_t2[i*9+j] < color_curve_x_wire[6])
						color_weight_t3[i*9+j] <= color_curve_y_wire[5];
					else if (diff_t2[i*9+j] < color_curve_x_wire[7])
						color_weight_t3[i*9+j] <= color_curve_y_wire[6];
					else if (diff_t2[i*9+j] < color_curve_x_wire[8])
						color_weight_t3[i*9+j] <= color_curve_y_wire[7];
					else
                        color_weight_t3[i*9+j] <= color_curve_y_wire[8];
		end
	end

	
	
	
	// selecting spactial weights
	always @(*) begin :_mux_space_weights 
	integer i, j;
	case (fmt[3])
		2'b00: begin
			   for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   space_weight_wire[i*5+j] <= space_weight_r_wire[i*5+j];
			   end
	    2'b11: begin
			   for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   space_weight_wire[i*5+j] <= space_weight_b_wire[i*5+j];
			   end
	   default: begin
	            for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   space_weight_wire[i*5+j] <= space_weight_g_wire[i*5+j];
			   end
	 endcase
	 end
	 
	 // selecting color intensity based weights
	 always @(*) begin :_mux_color_weights 
	integer i, j;
	case (fmt[3])
		2'b00: begin
			   for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   color_weight_wire[i*5+j] <= color_weight_t3[i*9*2+j*2];
			   end
	    2'b11: begin
			   for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   color_weight_wire[i*5+j] <= color_weight_t3[i*9*2+j*2];
			   end
	   default: begin
	            for (i = 0; i < 5; i = i + 1)
				    for (j = 0; j < 5; j = j + 1)
					   color_weight_wire[i*5+j] <= color_weight_t3[(i+2)*9+(j+2)];
			   end
	 endcase
	 end 
	
	// final weight = color_weight x spatial_weight
	reg [2*WEIGHT_BITS-1:0] weight_t4[5*5-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_weight_rb_t4
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 5*5; i = i + 1)
				weight_t4[i] <= 0;
		end
		else begin
		      for (i = 0; i < 5; i = i + 1)
				for (j = 0; j < 5; j = j + 1)
					weight_t4[i*5+j] <= space_weight_wire[i*5+j] * color_weight_wire[i*5+j];
	 end 
end

	// pixel wise multiplication of input patch with final weights
	reg [BITS+2*WEIGHT_BITS-1:0] value_mul_t5[5*5-1:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_value_mul_t5
		integer i, j;
		if (!rst_n) begin
			for (i = 0; i < 5*5; i = i + 1)
				value_mul_t5[i] <= 0;
		end
		else begin
			for (i = 0; i < 5; i = i + 1)
				for (j = 0; j < 5; j = j + 1)
					value_mul_t5[i*5+j] <= weight_t4[i*5+j] * p_t4[i*5+j];
		end
	end
	
	
	
	// sum along the rows
	reg [BITS+2*WEIGHT_BITS+3-1:0] value_sum_x_t6[4:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_value_sum_x_t6
		integer i;
		if (!rst_n) begin
			for (i = 0; i < 5; i = i + 1)
				value_sum_x_t6[i] <= 0;
		end
		else begin
			for (i = 0; i < 5; i = i + 1)
				value_sum_x_t6[i] <= value_mul_t5[i*5+0] + value_mul_t5[i*5+1] + value_mul_t5[i*5+2] + value_mul_t5[i*5+3] + value_mul_t5[i*5+4] ;
		end
	end
	
	
	
	// final sum ( along the column)
	reg [BITS+2*WEIGHT_BITS+8-1:0] value_sum_t7;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			value_sum_t7 <= 0;
		end
		else begin
			value_sum_t7 <= value_sum_x_t6[0] + value_sum_x_t6[1] + value_sum_x_t6[2] + value_sum_x_t6[3] + value_sum_x_t6[4];
		end
	end
		
		
	//row wise sum of weights for RB t5
	reg [2*WEIGHT_BITS+4-1:0] weight_sum_x_t5[4:0];
	always @ (posedge pclk or negedge rst_n) begin : _blk_weight_sum_x_rb_t5
		integer i;
		if (!rst_n) begin
			for (i = 0; i < 5; i = i + 1)
				weight_sum_x_t5[i] <= 0;
		end
		else begin
			for (i = 0; i < 5; i = i + 1)
				weight_sum_x_t5[i] <= weight_t4[i*5+0] + weight_t4[i*5+1] + weight_t4[i*5+2] + weight_t4[i*5+3] + weight_t4[i*5+4];
		end
	end
	
		
	//weight sum t7 ( t7 to make it synchronized with other results)
	reg [2*WEIGHT_BITS+4-1:0] weight_sum_t6;
	reg [2*WEIGHT_BITS+4-1:0] weight_sum_t7;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			weight_sum_t6 <= 0;
			weight_sum_t7 <= 0;
		end
		else begin
			weight_sum_t6 <= weight_sum_x_t5[0] + weight_sum_x_t5[1] + weight_sum_x_t5[2] + weight_sum_x_t5[3] + weight_sum_x_t5[4];
			weight_sum_t7 <= weight_sum_t6;
		end
	end
	
	// final operands for division
	wire [BITS+2*WEIGHT_BITS+8-1:0] num, denom;
	assign num = value_sum_t7;
	assign denom = {{BITS{1'b0}},weight_sum_t7};

	// pipelined division	
	wire [BITS+2*WEIGHT_BITS+8-1:0] target_quo, target_rem;
	shift_div_uint #(BITS+2*WEIGHT_BITS+8) target_div_g (pclk, rst_n, num, denom, target_quo, target_rem);
	
	// final output
	reg [BITS-1:0] out_data;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			out_data <= 0;
		else
			out_data <= (|target_quo[BITS+2*WEIGHT_BITS+8-1:BITS]) ? {BITS{1'b1}} : target_quo[BITS-1:0];
	end
			
	
	// Adjusting for computation delay
	localparam DLY_CLK = 13 + BITS+2*WEIGHT_BITS+8;
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

	localparam DEBUG_counter = 0;
	generate
	if (DEBUG_counter) begin:d_counter
		reg [32:0] counter,counter_out;
		always @ (posedge pclk or negedge rst_n) begin  
			if (!rst_n) begin
				counter <= 0;
			end else if (in_href) begin
				counter <= counter +1;
			end else begin
				counter <= counter;
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
		
		reg [15:0] q_g,q_rb;
		always @(*) begin
			q_g = value_sum_t7 / weight_sum_t7;
		end		
	end
	endgenerate	
	
	assign out_href = href_dly[DLY_CLK-1];
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_raw = out_data;		

endmodule