/*************************************************************************
> File Name: isp_sharpen.v
> Description: Unsharp masking with strength control
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Sharpen
 */

module isp_sharpen
#(
    parameter BITS = 8,
    parameter WIDTH = 1280,
	parameter HEIGHT = 960,
    parameter SHARP_WEIGHT_BITS = 20
)
(
    input pclk,
	input rst_n,

    // Kernel for y channel 
    input [9*9*SHARP_WEIGHT_BITS-1:0] luma_kernel,
    // Sharpen Strength
    input [11:0] sharpen_strength,
    
	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data_y,
	input [BITS-1:0] in_data_u,
	input [BITS-1:0] in_data_v,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data_y,
	output [BITS-1:0] out_data_u,
	output [BITS-1:0] out_data_v
);
    
    localparam SHARPEN_BITS = 20;

    reg [SHARP_WEIGHT_BITS-1:0] kernel_y_0 [(9*9)-1:0];
    always @(*) begin   : kernel_y0
        integer i;
        for (i = 0; i < 81; i = i + 1) begin 
            kernel_y_0[i] = luma_kernel[SHARP_WEIGHT_BITS*i+:SHARP_WEIGHT_BITS];
        end 
    end

    reg signed [11:0] sharpen_strength_0;
    reg [SHARP_WEIGHT_BITS-1:0] kernel_y [(9*9)-1:0];
    always @(posedge pclk or negedge rst_n) begin : Kernel_0
        integer i;
        if (!rst_n) begin
           sharpen_strength_0 <= 0;
           for (i = 0; i < 81; i = i + 1) begin
               kernel_y[i] <= 0;
           end
        end 
        else begin
           sharpen_strength_0 <= sharpen_strength;
           for (i = 0; i < 81; i = i + 1) begin
               kernel_y[i] = kernel_y_0[i];
           end
        end
    end

    // Line buffer for channel y
    wire [BITS-1:0] lineout_y;
	 wire [BITS-1:0] tap7x_y, tap6x_y, tap5x_y, tap4x_y, tap3x_y, tap2x_y, tap1x_y, tap0x_y;
    shift_register #(BITS, WIDTH, 8) linebuffer_y(pclk, in_href, in_data_y, lineout_y, {tap7x_y, tap6x_y, tap5x_y, tap4x_y, tap3x_y, tap2x_y, tap1x_y, tap0x_y});
    
    reg [BITS-1:0] in_data_y_i;
    reg [BITS-1:0] pixel_y [(9*9)-1:0];
	 always @ (posedge pclk or negedge rst_n) begin : line_buffer_out_y
	   integer i, j;
		if (!rst_n) begin
         in_data_y_i <= 0;
			for (i = 0; i < 81; i = i + 1) begin
				pixel_y[i] <= 0;
         end
		end
		else begin
         in_data_y_i <= in_data_y;
			for (i = 0; i < 9; i = i + 1) begin
				for (j = 0; j < 8; j = j + 1) begin
					pixel_y[i*9+j] <= pixel_y[i*9+j+1];
            end
         end
         pixel_y[0*9+8] <= tap7x_y;
			pixel_y[1*9+8] <= tap6x_y;
			pixel_y[2*9+8] <= tap5x_y;
			pixel_y[3*9+8] <= tap4x_y;
			pixel_y[4*9+8] <= tap3x_y;
			pixel_y[5*9+8] <= tap2x_y;
			pixel_y[6*9+8] <= tap1x_y;
			pixel_y[7*9+8] <= tap0x_y;
			pixel_y[8*9+8] <= in_data_y_i;
		end
	end

    // Line buffer for channel u
    wire [BITS-1:0] lineout_u;
	 wire [BITS-1:0] tap7x_u, tap6x_u, tap5x_u, tap4x_u, tap3x_u, tap2x_u, tap1x_u, tap0x_u;
    shift_register #(BITS, WIDTH, 8) linebuffer_u(pclk, in_href, in_data_u, lineout_u, {tap7x_u, tap6x_u, tap5x_u, tap4x_u, tap3x_u, tap2x_u, tap1x_u, tap0x_u});
    
    reg [BITS-1:0] in_data_u_i;
    reg [BITS-1:0] pixel_u [(9*9)-1:0];
	 always @ (posedge pclk or negedge rst_n) begin : line_buffer_out_u
	   integer i, j;
		if (!rst_n) begin
         in_data_u_i <= 0;
			for (i = 0; i < 81; i = i + 1) begin
				pixel_u[i] <= 0;
         end
		end
		else begin
         in_data_u_i <= in_data_u;
			for (i = 0; i < 9; i = i + 1) begin
				for (j = 0; j < 8; j = j + 1) begin
					pixel_u[i*9+j] <= pixel_u[i*9+j+1];
            end
         end
         pixel_u[0*9+8] <= tap7x_u;
			pixel_u[1*9+8] <= tap6x_u;
			pixel_u[2*9+8] <= tap5x_u;
			pixel_u[3*9+8] <= tap4x_u;
			pixel_u[4*9+8] <= tap3x_u;
			pixel_u[5*9+8] <= tap2x_u;
			pixel_u[6*9+8] <= tap1x_u;
			pixel_u[7*9+8] <= tap0x_u;
			pixel_u[8*9+8] <= in_data_u_i;
		end
	 end

    // Line buffer for channel v
    wire [BITS-1:0] lineout_v;
	 wire [BITS-1:0] tap7x_v, tap6x_v, tap5x_v, tap4x_v, tap3x_v, tap2x_v, tap1x_v, tap0x_v;
    shift_register #(BITS, WIDTH, 8) linebuffer_v(pclk, in_href, in_data_v, lineout_v, {tap7x_v, tap6x_v, tap5x_v, tap4x_v, tap3x_v, tap2x_v, tap1x_v, tap0x_v});
    
    reg [BITS-1:0] in_data_v_i;
    reg [BITS-1:0] pixel_v [(9*9)-1:0];
	 always @ (posedge pclk or negedge rst_n) begin : line_buffer_out_v
	   integer i, j;
		if (!rst_n) begin
         in_data_v_i <= 0;
			for (i = 0; i < 81; i = i + 1) begin
				pixel_v[i] <= 0;
         end
		end
		else begin
         in_data_v_i <= in_data_v;
			for (i = 0; i < 9; i = i + 1) begin
				for (j = 0; j < 8; j = j + 1) begin
					pixel_v[i*9+j] <= pixel_v[i*9+j+1];
            end
         end
         pixel_v[0*9+8] <= tap7x_v;
			pixel_v[1*9+8] <= tap6x_v;
			pixel_v[2*9+8] <= tap5x_v;
			pixel_v[3*9+8] <= tap4x_v;
			pixel_v[4*9+8] <= tap3x_v;
			pixel_v[5*9+8] <= tap2x_v;
			pixel_v[6*9+8] <= tap1x_v;
			pixel_v[7*9+8] <= tap0x_v;
			pixel_v[8*9+8] <= in_data_v_i;
		end
	 end

    /* Stage 1: Mutiplication */
    // Applying filter on channel y 
    reg [SHARP_WEIGHT_BITS+BITS-1:0] pixel_mult_y [(9*9)-1:0];
    always @(posedge pclk or negedge rst_n) begin : Multiplication_y
      integer i;
      if (!rst_n) begin
         for (i = 0; i < 81; i = i + 1) begin
            pixel_mult_y[i] <= 0;
         end
      end
      else begin
         for (i = 0; i < 81; i = i + 1) begin
            pixel_mult_y[i] <= kernel_y[i] * pixel_y[i];
        end
      end
    end

    // Register the values of u and v channel pixel
    reg [BITS-1:0] pixel_y_1;
    reg [BITS-1:0] pixel_u_1;
    reg [BITS-1:0] pixel_v_1;
    reg signed [11:0] sharpen_strength_1;
    always @(posedge pclk or negedge rst_n) begin : STAGE_1
        if (!rst_n) begin
           sharpen_strength_1 <= 0;
           pixel_y_1 <= 0;
           pixel_u_1 <= 0;
           pixel_v_1 <= 0;
        end
        else begin
           sharpen_strength_1 <= sharpen_strength_0;
           pixel_y_1 <= pixel_y[40];
           pixel_u_1 <= pixel_u[40];
           pixel_v_1 <= pixel_v[40];
        end
    end

    /* Stage 2: Accumulation Stage_1*/
    // For channel y
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_1;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_2;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_3;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_4;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_5;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_6;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_7;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_8;
    reg [SHARP_WEIGHT_BITS+BITS+4-1:0] pixel_row_9;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_row_1 <= 0;
           pixel_row_2 <= 0;
           pixel_row_3 <= 0;
           pixel_row_4 <= 0;
           pixel_row_5 <= 0;
           pixel_row_6 <= 0;
           pixel_row_7 <= 0;
           pixel_row_8 <= 0;
           pixel_row_9 <= 0;
        end
        else begin
           pixel_row_1 <= pixel_mult_y[0] + pixel_mult_y[1] + pixel_mult_y[2] + pixel_mult_y[3] + pixel_mult_y[4] + pixel_mult_y[5] + pixel_mult_y[6] + pixel_mult_y[7] + pixel_mult_y[8];
           pixel_row_2 <= pixel_mult_y[9] + pixel_mult_y[10] + pixel_mult_y[11] + pixel_mult_y[12] + pixel_mult_y[13] + pixel_mult_y[14] +pixel_mult_y[15] + pixel_mult_y[16] + pixel_mult_y[17];
           pixel_row_3 <= pixel_mult_y[18] + pixel_mult_y[19] + pixel_mult_y[20] + pixel_mult_y[21] + pixel_mult_y[22] + pixel_mult_y[23] + pixel_mult_y[24] + pixel_mult_y[25] + pixel_mult_y[26];
           pixel_row_4 <= pixel_mult_y[27] + pixel_mult_y[28] + pixel_mult_y[29] + pixel_mult_y[30] + pixel_mult_y[31] + pixel_mult_y[32] + pixel_mult_y[33] + pixel_mult_y[34] + pixel_mult_y[35];
           pixel_row_5 <= pixel_mult_y[36] + pixel_mult_y[37] + pixel_mult_y[38] + pixel_mult_y[39] + pixel_mult_y[40] + pixel_mult_y[41] + pixel_mult_y[42] + pixel_mult_y[43] + pixel_mult_y[44];
           pixel_row_6 <= pixel_mult_y[45] + pixel_mult_y[46] + pixel_mult_y[47] + pixel_mult_y[48] + pixel_mult_y[49] + pixel_mult_y[50] + pixel_mult_y[51] + pixel_mult_y[52] + pixel_mult_y[53];
           pixel_row_7 <= pixel_mult_y[54] + pixel_mult_y[55] + pixel_mult_y[56] + pixel_mult_y[57] + pixel_mult_y[58] + pixel_mult_y[59] + pixel_mult_y[60] + pixel_mult_y[61] + pixel_mult_y[62];
           pixel_row_8 <= pixel_mult_y[63] + pixel_mult_y[64] + pixel_mult_y[65] + pixel_mult_y[66] + pixel_mult_y[67] + pixel_mult_y[68] + pixel_mult_y[69] + pixel_mult_y[70] + pixel_mult_y[71];
           pixel_row_9 <= pixel_mult_y[72] + pixel_mult_y[73] + pixel_mult_y[74] + pixel_mult_y[75] + pixel_mult_y[76] + pixel_mult_y[77] + pixel_mult_y[78] + pixel_mult_y[79] + pixel_mult_y[80];
        end
    end

    reg [BITS-1:0] pixel_y_2;
    reg [BITS-1:0] pixel_u_2;
    reg [BITS-1:0] pixel_v_2;
    reg signed [11:0] sharpen_strength_2;
    always @(posedge pclk or negedge rst_n) begin : STAGE_2
        if (!rst_n) begin
           sharpen_strength_2 <= 0;
           pixel_y_2 <= 0;
           pixel_u_2 <= 0;
           pixel_v_2 <= 0;
        end
        else begin
           sharpen_strength_2 <= sharpen_strength_1;
           pixel_y_2 <= pixel_y_1;
           pixel_u_2 <= pixel_u_1;
           pixel_v_2 <= pixel_v_1;
        end
    end
 
    /* Stage 3: Accumulation Stage_2*/
    reg [SHARP_WEIGHT_BITS+BITS+8-1:0] pixel_acc_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_acc_y <= 0;
        end
        else begin
           pixel_acc_y <= pixel_row_1 + pixel_row_2 + pixel_row_3 + pixel_row_4 + pixel_row_5 + pixel_row_6 + pixel_row_7 + pixel_row_8 + pixel_row_9;
        end
    end

    reg [BITS-1:0] pixel_y_3;
    reg [BITS-1:0] pixel_u_3;
    reg [BITS-1:0] pixel_v_3;
    reg signed [11:0] sharpen_strength_3;
    always @(posedge pclk or negedge rst_n) begin : STAGE_3
        if (!rst_n) begin
           sharpen_strength_3 <= 0;
           pixel_y_3 <= 0;
           pixel_u_3 <= 0;
           pixel_v_3 <= 0;
        end
        else begin
           sharpen_strength_3 <= sharpen_strength_2;
           pixel_y_3 <= pixel_y_2;
           pixel_u_3 <= pixel_u_2;
           pixel_v_3 <= pixel_v_2;
        end
    end

    /* Stage 4: Division */
    // For channel y
    reg [SHARPEN_BITS-5:0] pixel_div_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_div_y <= 0;
        end 
        else begin
           pixel_div_y <= pixel_acc_y >> SHARP_WEIGHT_BITS;
        end
    end

    reg [BITS-1:0] pixel_y_4;
    reg [BITS-1:0] pixel_u_4;
    reg [BITS-1:0] pixel_v_4;
    reg signed [11:0] sharpen_strength_4;
    always @(posedge pclk or negedge rst_n) begin : STAGE_4
        if (!rst_n) begin
           sharpen_strength_4 <= 0;
           pixel_y_4 <= 0;
           pixel_u_4 <= 0;
           pixel_v_4 <= 0;
        end
        else begin
           sharpen_strength_4 <= sharpen_strength_3;
           pixel_y_4 <= pixel_y_3;
           pixel_u_4 <= pixel_u_3;
           pixel_v_4 <= pixel_v_3;
        end
    end

    /* Stage 5: Subtraction */
    // For channel y
    reg signed [SHARPEN_BITS-4:0] pixel_sub_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_sub_y <= 0;
        end 
        else begin
           pixel_sub_y <= {{BITS{1'b0}}, pixel_y_4} - pixel_div_y;
        end
    end
 
    reg [BITS-1:0] pixel_y_5;
    reg [BITS-1:0] pixel_u_5;
    reg [BITS-1:0] pixel_v_5;
    reg signed [11:0] sharpen_strength_5;
    always @(posedge pclk or negedge rst_n) begin : STAGE_5
        if (!rst_n) begin
           sharpen_strength_5 <= 0;
           pixel_y_5 <= 0;
           pixel_u_5 <= 0;
           pixel_v_5 <= 0;
        end
        else begin
           sharpen_strength_5 <= sharpen_strength_4;
           pixel_y_5 <= pixel_y_4;
           pixel_u_5 <= pixel_u_4;
           pixel_v_5 <= pixel_v_4;
        end
    end

    /* Stage 6: Sharpen Strength */
    // For channel y
    reg signed [SHARPEN_BITS+BITS+1:0] pixel_str_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_str_y <= 0;
        end 
        else begin
           pixel_str_y <= sharpen_strength_5 * pixel_sub_y;
        end
    end

    reg [BITS-1:0] pixel_y_6;
    reg [BITS-1:0] pixel_u_6;
    reg [BITS-1:0] pixel_v_6;
    always @(posedge pclk or negedge rst_n) begin : STAGE_6
        if (!rst_n) begin
           pixel_y_6 <= 0;
           pixel_u_6 <= 0;
           pixel_v_6 <= 0;
        end
        else begin
           pixel_y_6 <= pixel_y_5;
           pixel_u_6 <= pixel_u_5;
           pixel_v_6 <= pixel_v_5;
        end
    end

    /* Stage 7: Shifting */
    // channel y
    reg signed [SHARPEN_BITS-1:0] pixel_shift_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_shift_y <= 0;
        end 
        else begin
           pixel_shift_y <= pixel_str_y >>> 10;
        end
    end
    
    reg [BITS-1:0] pixel_y_7;
    reg [BITS-1:0] pixel_u_7;
    reg [BITS-1:0] pixel_v_7;
    always @(posedge pclk or negedge rst_n) begin : STAGE_7
        if (!rst_n) begin
           pixel_y_7 <= 0;
           pixel_u_7 <= 0;
           pixel_v_7 <= 0;
        end
        else begin
           pixel_y_7 <= pixel_y_6;
           pixel_u_7 <= pixel_u_6;
           pixel_v_7 <= pixel_v_6;
        end
    end

    /* Stage 8: Addition */
    // For channel y
    reg signed [SHARPEN_BITS-1:0] pixel_add_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_add_y <= 0;
        end 
        else begin
           pixel_add_y <= {{12{1'b0}}, pixel_y_7} + pixel_shift_y;
        end
    end

    reg [BITS-1:0] pixel_u_8;
    reg [BITS-1:0] pixel_v_8;
    always @(posedge pclk or negedge rst_n) begin : STAGE_8
        if (!rst_n) begin
           pixel_u_8 <= 0;
           pixel_v_8 <= 0;
        end
        else begin
           pixel_u_8 <= pixel_u_7;
           pixel_v_8 <= pixel_v_7;
        end
    end

    /* Stage 9: Clipping */
    // For channel y
    reg [SHARPEN_BITS-1:0] pixel_out_y;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
           pixel_out_y <= 0;
        end 
        else begin
           pixel_out_y <= (pixel_add_y[19] == 1'b1) ? {8{1'b0}} :((pixel_add_y[19:0] > 20'd255) ? {8{1'b1}} : pixel_add_y);
        end
    end

    reg [BITS-1:0] pixel_u_9;
    reg [BITS-1:0] pixel_v_9;
    always @(posedge pclk or negedge rst_n) begin : STAGE_9
        if (!rst_n) begin
           pixel_u_9 <= 0;
           pixel_v_9 <= 0;
        end
        else begin
           pixel_u_9 <= pixel_u_8;
           pixel_v_9 <= pixel_v_8;
        end
    end

    localparam DLY_CLK = 15;    // 9 for stages, 4 for Line buffer, 2 for I/O
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
    assign out_data_y = out_href ? pixel_out_y[BITS-1:0] : {BITS{1'b0}};
    assign out_data_u = out_href ? pixel_u_9 : {BITS{1'b0}};
    assign out_data_v = out_href ? pixel_v_9 : {BITS{1'b0}};

endmodule
