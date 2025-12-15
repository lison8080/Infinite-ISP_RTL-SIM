/*************************************************************************
> File Name: vip_dscale.v
> Description: apply downscaling 
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * VIP - Down Scale
 */

module Scale
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960
)
(
	input pclk,
	input scale_pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_y,
	input [BITS-1:0] in_u,
	input [BITS-1:0] in_v,
	input [11:0] s_in_crop_w,
	input [11:0] s_in_crop_h,
	input [11:0] s_out_crop_w,
	input [11:0] s_out_crop_h,
	input [2:0] dscale_w,
	input [2:0] dscale_h,

	output out_pclk,
	output out_href,
	output out_vsync,
	output [BITS-1:0] out_y,
	output [BITS-1:0] out_u,
	output [BITS-1:0] out_v
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
	
	//Working of module is such that it will pick one pixel from each dscale_w number of pixels
	//if dscale_w = 2, then it will pick one pixel from each 2 pixels.
	//So pixel count is used to keep track of the pixel which needs to be picked up.

	reg [3:0] pix_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			pix_cnt <= 0;
		else if ((pix_cnt == dscale_w - 1) || (dscale_w == 0) || line_start)
			pix_cnt <= 0;
		else
			pix_cnt <= pix_cnt + 1'b1;
	end

	reg prev_vsync;
	wire frame_start = prev_vsync & (~in_vsync);
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			prev_vsync <= 0;
		else
			prev_vsync <= in_vsync;
	end

    //Working of module is such that it will pick one row from each dscale_h number of rows
	//if dscale_h = 2, then it will pick one row from each 2 rows.
	//So line count is used to keep track of the row which needs to be picked up.

	reg [3:0] line_cnt;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			line_cnt <= 0;
		else if (frame_start)
			line_cnt <= 0;
		else if (line_end)
			if ((line_cnt == dscale_h - 1) || (dscale_h == 0))
				line_cnt <= 0;
			else
				line_cnt <= line_cnt + 1'b1;
		else
			line_cnt <= line_cnt;
	end
	
	//Registering input data

	reg[BITS-1:0] y, u, v;
	reg href;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            y <= 0;
            u <= 0;
            v <= 0;
            href <= 0;
       end
       else begin
            y <= in_y;
            u <= in_u;
            v <= in_v;
            href <= in_href;
       end
    end

	//Updating data only when both line and pixel counts are zero. otherwise retaining previous values.

	reg [BITS-1:0] data_y, data_u, data_v;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_y <= 0;
			data_u <= 0;
			data_v <= 0;
	    end
		else if (pix_cnt == 4'd0 && line_cnt == 4'd0) begin
			data_y <= y;
            data_u <= u;
            data_v <= v;
        end
		else begin
			data_y <= data_y;
            data_u <= data_u;
            data_v <= data_v;
        end
	end
	

	reg out_href_r;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			out_href_r <= 0;
		else if (line_cnt == 4'd0)
			out_href_r <= href;
		else
			out_href_r <= 0;
	end

	reg out_vsync_r;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n)
			out_vsync_r <= 0;
		else
			out_vsync_r <= in_vsync;
	end

    // For cases of scaling where downscaling factors are not integers, taking help of crop to scale (i.e just cropping the extra pixels)

    wire [BITS-1:0] crop_y, crop_u, crop_v;
    wire [BITS-1:0] crop_y1, crop_u1, crop_v1;
	wire crop_href, crop_href1, crop_href2, crop_vsync, crop_vsync1, crop_vsync2;

	assign crop_y = out_href_r ? data_y : {BITS{1'b0}};
	assign crop_u = out_href_r ? data_u : {BITS{1'b0}};
	assign crop_v = out_href_r ? data_v : {BITS{1'b0}};
	
	isp_scale_crop #(BITS) cropy (.pclk(out_pclk),.rst_n(rst_n),.crop_in_w(s_in_crop_w),.crop_in_h(s_in_crop_h),.crop_out_w(s_out_crop_w),.crop_out_h(s_out_crop_h),.in_href(out_href_r),.in_vsync(in_vsync),.in_data(crop_y),.out_href(crop_href),.out_vsync(crop_vsync),.out_data(crop_y1));
	isp_scale_crop #(BITS) cropu (.pclk(out_pclk),.rst_n(rst_n),.crop_in_w(s_in_crop_w),.crop_in_h(s_in_crop_h),.crop_out_w(s_out_crop_w),.crop_out_h(s_out_crop_h),.in_href(out_href_r),.in_vsync(in_vsync),.in_data(crop_u),.out_href(crop_href1),.out_vsync(crop_vsync1),.out_data(crop_u1));
	isp_scale_crop #(BITS) cropv (.pclk(out_pclk),.rst_n(rst_n),.crop_in_w(s_in_crop_w),.crop_in_h(s_in_crop_h),.crop_out_w(s_out_crop_w),.crop_out_h(s_out_crop_h),.in_href(out_href_r),.in_vsync(in_vsync),.in_data(crop_v),.out_href(crop_href2),.out_vsync(crop_vsync2),.out_data(crop_v1));
	
	// Adjusting for computation delay
	
	localparam DLY_CLK = 4;
	reg [DLY_CLK-1:0] vsync_dly;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			vsync_dly <= 0;
		end
		else begin
			vsync_dly <= {vsync_dly[DLY_CLK-2:0], in_vsync};
		end
	end
	
	assign out_vsync = vsync_dly[DLY_CLK-1];
	assign out_pclk = scale_pclk;
    assign out_href = crop_href;
    assign out_y = crop_href ? crop_y1 : {BITS{1'b0}};
    assign out_u = crop_href1 ? crop_u1 : {BITS{1'b0}};
    assign out_v = crop_href2 ? crop_v1 : {BITS{1'b0}};

endmodule