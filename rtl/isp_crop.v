/*************************************************************************
> File Name: isp_crop.v
> Description: Crops the raw image while keeping the Bayer pattern intact
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Crop
 */

module isp_crop
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
)
(
	input pclk,
	input rst_n,

	// input [15:0] crop_x,
	// input [15:0] crop_y,
	input [11:0] crop_w,
	input [11:0] crop_h,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_data,

	output out_href,
	output out_vsync,
	output [BITS-1:0] out_data
);

    // Line start and line end detection

	reg prev_href;
	wire line_start = (~prev_href) & in_href;
	wire line_end = prev_href & (~in_href);
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_href <= 0;
		else
			prev_href <= in_href;
	end

    // Count pixel in a line, to select required region for cropping

	reg [15:0] pix_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			pix_cnt <= 0;
		else if (line_start)
			pix_cnt <= 0;
		else if (pix_cnt < {16{1'b1}})
			pix_cnt <= pix_cnt + 1'b1;
		else
			pix_cnt <= pix_cnt;
	end

    // Frame start detection
	
	reg prev_vsync;
	wire frame_start = prev_vsync & (~in_vsync);
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_vsync <= 0;
		else
			prev_vsync <= in_vsync;
	end

    // Count lines, to select required region for cropping

	reg [15:0] line_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			line_cnt <= 0;
		else if (frame_start)
			line_cnt <= 0;
		else if (line_end)
			line_cnt <= line_cnt + 1'b1;
		else
			line_cnt <= line_cnt;
	end

    //Registering the input data(pixel)

	reg [BITS-1:0] data_r;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			data_r <= 0;
		else
			data_r <= in_data;
	end
	reg in_href_delayed;
	always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n)
            in_href_delayed <= 0;
        else
            in_href_delayed <= in_href;
    end

	//crop_x defines the equal number of colums needed to be croped from both left and right
	//crop_y defines the equal number of rows needed to be croped from both top and bottom

	wire [15:0] crop_x, crop_y;
    assign crop_x = (WIDTH - crop_w) >> 1;
    assign crop_y = (HEIGHT - crop_h) >> 1;

    //output valid signal (href) will get high depending upon the above calculated values of crop_x and crop_y
	//Condition goes as follows:
	// (pixel count >= number of colums needed to be cropped from left) && (pixel count < output width + number of colums needed to be cropped from right) && 
	// (line count >= number of rows needed to be croped from top) && (line count < output height + number of roes needed to be croped from bottom)

    wire out_href_crop ;
	assign out_href_crop = (pix_cnt >= crop_x) && (pix_cnt < crop_x + crop_w) && (line_cnt >= crop_y) && (line_cnt < crop_y + crop_h);

    //As we are cropping in Bayer domain, so need to make sure Bayer pattern is intact 
	//If required croped height and width are not keeping Bayer pattern intact, no croping will be done

    assign out_href = ((((WIDTH - crop_w) % 4) == 0) && (((HEIGHT - crop_h) % 4 ==0)) && ((crop_x != 0) || (crop_y != 0))) ? out_href_crop : in_href_delayed;
    
	assign out_vsync = in_vsync;
	assign out_data = out_href ? data_r : {BITS{1'b0}};
endmodule
