/*************************************************************************
> File Name: vip_YUVConvFormat.v
> Description: Converts YUV 444 to YUV 422
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps
/*
 * VIP - YUV 444 to 422
 */

module YUVConvFormat
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
	//parameter YUV444TO422 = 0
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input YUV444TO422,
	input [BITS-1:0] in_y,
	input [BITS-1:0] in_u,
	input [BITS-1:0] in_v,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_y,
	output [BITS-1:0] out_c,
	output [BITS-1:0] out_v
);

    // Tracking even/odd pixels for pixel's bayer detection

	reg pix_odd;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			pix_odd <= 1'b0;
		else if (!in_href)
			pix_odd <= 1'b0;
		else
			pix_odd <= ~pix_odd;
	end
	
	// Registering the input data

	reg [BITS-1:0] y_reg;
	reg [BITS-1:0] c_reg_u;
	reg [BITS-1:0] c_reg_v;
	reg pix_odd_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			y_reg <= 0;
			c_reg_u <= 0;
			c_reg_v <= 0;
			pix_odd_1 <= 0;
		end
		else begin
			y_reg <= in_y;
			c_reg_u <= in_u; 
			c_reg_v <= in_v;
			pix_odd_1 <= pix_odd;
		end
	end

    //Working of algorithm is such that it will outputs YUV from first packet and Y only from second packet and so on
	//So implementation is such that it will outputs YU from the first packet and will propagate the V to combine it with the Y of second packet
	//so from input pattern of YUV YUV YUV YUV -> output pattern will be YUV Y YUV Y and so on
	//And in Hardware implementation output pattern will be YU YV YU YV and so on

	reg [BITS-1:0] c_reg_v_1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			c_reg_v_1 <= 0;
		end
		else begin
			 c_reg_v_1 <= c_reg_v; 
		end
	end
	
	//Sending U with Y on even pixels and V with Y on odd pixels

	reg [BITS-1:0] y_out, c_out, v;
        always @ (posedge pclk or negedge rst_n) begin
            if (!rst_n) begin
                y_out <= 0;
                c_out <= 0;
				v <= 0;
            end
            else begin
                 y_out <= y_reg;
                 c_out <= pix_odd_1 ? c_reg_v_1 : c_reg_u; 
				 v <= c_reg_v;
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
    
    wire out_href_422, out_vsync_422;
    wire [BITS-1:0] out_y_422, out_c_422, out_v_422;
	assign out_href_422 = href_dly[DLY_CLK-1];
	assign out_vsync_422 = vsync_dly[DLY_CLK-1];
	assign out_y_422 = out_href_422 ? y_out : {BITS{1'b0}};
	assign out_c_422 = out_href_422 ? c_out : {BITS{1'b0}};
	assign out_v_422 = out_href_422 ? v : {BITS{1'b0}};
	

    wire out_href_444, out_vsync_444;
    wire [BITS-1:0] out_y_444, out_c_444, out_v_444;
	assign out_href_444 = in_href;
	assign out_vsync_444 = in_vsync;
	assign out_y_444 = out_href_444 ? in_y : {BITS{1'b0}};
	assign out_c_444 = out_href_444 ? in_u : {BITS{1'b0}};
	assign out_v_444 = out_href_444 ? in_v : {BITS{1'b0}};
	
	
	assign out_href = YUV444TO422 ? out_href_422 : out_href_444;
	assign out_vsync = YUV444TO422 ? out_vsync_422 : out_vsync_444;
	assign out_y = YUV444TO422 ? out_y_422 : out_y_444;
	assign out_c = YUV444TO422 ? out_c_422 : out_c_444;
	assign out_v = YUV444TO422 ? out_v_422 : out_v_444;
endmodule