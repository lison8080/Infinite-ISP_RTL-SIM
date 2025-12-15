/*************************************************************************
> File Name: isp_dgain.v
> Description: Digital gain works to improve the image exposure
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Digital Gain
 */

module isp_dgain
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter DGAIN_ARRAY_SIZE = 100,
	parameter DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE)
)
(
	input pclk,
	input rst_n,
	
    input isManual,
	input [DGAIN_ARRAY_BITS-1:0] manual_index,
	input [DGAIN_ARRAY_BITS-1:0] ae_feedback_index,
	input [DGAIN_ARRAY_SIZE*8-1:0] dgain_array, // integer multiplier
		

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,

	output out_href,
	output out_vsync,
	output [DGAIN_ARRAY_BITS-1:0] applied_index,
	output [BITS-1:0] out_raw
);

//========== INDEX CONTROL LOGIC START ==========//
wire [DGAIN_ARRAY_BITS-1:0] index;
assign applied_index = index;

// detecting vertical blanking before first period
reg in_vsync_prev;
always @(posedge pclk or negedge rst_n) begin
	if (!rst_n)
		in_vsync_prev <= 1'b0;
	else
		in_vsync_prev <= in_vsync;
end

//detect 2nd rising edge of VSYNC i.e. post-first frame pixels
reg first_in_vsync_rise;
always @(posedge pclk or negedge rst_n) begin
	if (!rst_n)
		first_in_vsync_rise <= 1'b0;
	else begin
		if (in_vsync & ~in_vsync_prev)	//VSYNC rising-edge
			first_in_vsync_rise <= 1'b1;
	end
end

//define second vertical blanking period as post-first_frame pixel data
reg second_vertical_blanking;
always @(posedge pclk or negedge rst_n) begin
	if (!rst_n)
		second_vertical_blanking <= 1'b0;
	else begin
		if ((~in_vsync_prev & in_vsync) & first_in_vsync_rise) //VSYNC rising-edge & first_rising_edge_passed_already
			second_vertical_blanking <= 1'b1;
		else
			second_vertical_blanking <= second_vertical_blanking;
	end
end

assign index = isManual ?  manual_index : (second_vertical_blanking ? ae_feedback_index : manual_index);
//========== INDEX CONTROL LOGIC END ==========//

wire [7:0] dgain_wire [DGAIN_ARRAY_SIZE-1:0];
generate
genvar i;
for (i = 0; i < DGAIN_ARRAY_SIZE; i = i + 1) begin // range kernel quantized weights
	assign dgain_wire[i] = dgain_array[(8*i)+:8];
	end
endgenerate

wire [7:0] gain; // selecting final gain value to be multiplied 
assign gain = index < DGAIN_ARRAY_SIZE ? dgain_wire[index] : dgain_wire[0]; 

reg [BITS-1+8:0] data_0;
always @ (posedge pclk or negedge rst_n) begin
	if (!rst_n) begin
		data_0 <= 0;
	end
	else begin
		data_0 <= in_raw * gain;
	end
end

	// clipping
	reg [BITS-1:0] data_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_1 <= 0;
		end
		else begin
			data_1 <= data_0[BITS-1+8:0] > {BITS{1'b1}} ? {BITS{1'b1}} : data_0[BITS-1:0];
		end
	end
	
	// Adjusting for computation delay
	localparam DLY_CLK = 2;
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
	assign out_raw = out_href ? data_1 : {BITS{1'b0}};
	
endmodule