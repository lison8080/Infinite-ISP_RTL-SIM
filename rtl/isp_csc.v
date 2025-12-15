/*************************************************************************
> File Name: isp_csc.v
> Description: Converts RGB to YUV or YCbCr
> Author: 10xEngineers
> Credits: https://github.com/bxinquan
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Color Space Conversion (RGB2YUV)
 */

module isp_csc
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
	input [1:0] in_conv_standard,
	input [BITS-1:0] in_r,
	input [BITS-1:0] in_g,
	input [BITS-1:0] in_b,

	output out_href,
	output out_vsync,
	output [7:0] out_y,
	output [7:0] out_u,
	output [7:0] out_v
);

	//Y = (77  * R + 150 * G + 29  * B) >> 8
	//U = (-43 * R - 85  * G + 128 * B + 32768) >> 8
	//V = (128 * R - 107 * G - 21  * B + 32768) >> 8

	reg [BITS-1:0] data_r;
	reg [BITS-1:0] data_g;
	reg [BITS-1:0] data_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_r <= 0;
			data_g <= 0;
			data_b <= 0;
		end
		else begin
			data_r <= in_r;
			data_g <= in_g;
			data_b <= in_b;
		end
	end

    //Multiplying the coefficeints with corresponding rgb values

	reg signed [BITS+9:0] y_r, y_g, y_b;
	reg signed [BITS+9:0] u_r, u_g, u_b;
	reg signed [BITS+9:0] v_r, v_g, v_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			y_r <= 0;
			y_g <= 0;
			y_b <= 0;
			u_r <= 0;
			u_g <= 0;
			u_b <= 0;
			v_r <= 0;
			v_g <= 0;
			v_b <= 0;
		end
		else if (in_conv_standard == 2'b1)begin
			y_r <= data_r * 47;
			y_g <= data_g * 157;
			y_b <= data_b * 16;
			u_r <= data_r * -26;
			u_g <= data_g * -86;
			u_b <= data_b * 112;
			v_r <= data_r * 112;
			v_g <= data_g * -102;
			v_b <= data_b * -10;
		end
		else begin
		    y_r <= data_r * 77;
            y_g <= data_g * 150;
            y_b <= data_b * 29;
            u_r <= data_r * -44;
            u_g <= data_g * -87;
            u_b <= data_b * 138;
            v_r <= data_r * 131;
            v_g <= data_g * -110;
            v_b <= data_b * -21;
        end    
	end

    //Summation of multiplications

	reg signed [BITS+10:0] data_y;
	reg signed [BITS+10:0] data_u;
	reg signed [BITS+10:0] data_v;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_y <= 0;
			data_u <= 0;
			data_v <= 0;
		end
		else begin
			data_y <= y_r + y_g + y_b ;
			data_u <= u_b + u_r + u_g ;
			data_v <= v_r + v_g + v_b ;
		end
	end
    
	//In order to maintain the precision of 0.5 converting the results into +ve if there is any -ve

	reg  [BITS+10:0] data_y1;
	reg  [BITS+10:0] data_u1;
	reg  [BITS+10:0] data_v1;
	reg  neg_u, neg_v;
	always @ (posedge pclk or negedge rst_n) begin
         if (!rst_n) begin
             data_y1 <= 0;
             data_u1 <= 0;
             data_v1 <= 0;
             neg_u <= 0;
             neg_v <= 0;
         end
         else begin
             data_y1 <= data_y ;
             if(data_u[BITS+10]) begin
                 data_u1 <= -1 * data_u ; //converting it into positive number
                 neg_u   <= 1; 
             end
             else begin
                 data_u1 <= data_u ;
                 neg_u   <= 0;
             end
                
             if(data_v[BITS+10]) begin
                 data_v1 <= -1 * data_v ; //converting it into positive number
                 neg_v   <= 1 ;
             end
             else begin
                 data_v1 <= data_v ;
                 neg_v   <= 0 ;
             end
         end
     end

    //Division by 256 and keeping track of 0.5

	reg  [BITS+2:0] data_y2;
	reg  [BITS+2:0] data_u2;
	reg  [BITS+2:0] data_v2;
	reg data_bit_y,data_bit_u,data_bit_v;
	reg neg_u1, neg_v1;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			data_y2 <= 0;
			data_u2 <= 0;
			data_v2 <= 0;
			data_bit_y <= 0;
            data_bit_u <= 0;
            data_bit_v <= 0;
			neg_u1 <= 0;
			neg_v1 <= 0;
		end
		else begin
			neg_u1 <= neg_u;
			neg_v1 <= neg_v;
			data_bit_y <= data_y1[7];
            data_bit_u <= data_u1[7];
            data_bit_v <= data_v1[7];
			data_y2 <= data_y1 >> 8;
			data_u2 <= data_u1 >> 8;
			data_v2 <= data_v1 >> 8;
		end
	end

    //If bit corresponding to 0.5 place is high then 1 will be added or subtracted depending upon the sign of value (result)

	reg signed [BITS+12:0] data_y3;
	reg signed [BITS+12:0] data_u3;
	reg signed [BITS+12:0] data_v3;
    
    always @ (posedge pclk or negedge rst_n) begin
         if (!rst_n) begin
             data_y3 <= 0;
             data_u3 <= 0;
             data_v3 <= 0;
                
         end
         else begin
             data_y3 <= data_y2 + {(BITS >> 1){1'b1}} + 1 + data_bit_y ;
             if (neg_u1) begin
                 data_u3 <= {(BITS - 1){1'b1}} + 1 - data_u2 - data_bit_u ;
             end else begin
                 data_u3 <= {(BITS - 1){1'b1}} + 1 + data_u2 + data_bit_u ;
             end
                
             if(neg_v1) begin
                 data_v3 <= {(BITS - 1){1'b1}} + 1 - data_v2 - data_bit_v ;
             end
             else begin
                 data_v3 <= {(BITS - 1){1'b1}} + 1 + data_v2 + data_bit_v ;
             end
         end
     end

    //Clipping the result to bring it into bit range

	reg  [BITS-1:0] data_y4;
    reg  [BITS-1:0] data_u4;
    reg  [BITS-1:0] data_v4;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            data_y4 <= 0;
            data_u4 <= 0;
            data_v4 <= 0;
        end
        else begin
            data_y4 <= data_y3[BITS+12] ? {BITS{1'b0}} : ((data_y3[BITS+11:BITS] || 1'b0) ? {BITS{1'b1}} : data_y3[BITS-1:0]);
            data_u4 <= data_u3[BITS+12] ? {BITS{1'b0}} : ((data_u3[BITS+11:BITS] || 1'b0) ? {BITS{1'b1}} : data_u3[BITS-1:0]);
            data_v4 <= data_v3[BITS+12] ? {BITS{1'b0}} : ((data_v3[BITS+11:BITS] || 1'b0) ? {BITS{1'b1}} : data_v3[BITS-1:0]);
        end
    end
        
    //Clipping the result to bring it into 8-bit range and keeping track of 0.5 place bit 

    reg  [BITS-1:0] data_y5;
    reg  [BITS-1:0] data_u5;
    reg  [BITS-1:0] data_v5;
	reg data_bit_y1,data_bit_u1,data_bit_v1;

	generate
		if(BITS > 8)
		begin
			always @ (posedge pclk or negedge rst_n) 
			begin
				if (!rst_n) 
				begin
					data_y5 <= 0;
					data_u5 <= 0;
					data_v5 <= 0;
					data_bit_y1 <= 0;
					data_bit_u1 <= 0;
					data_bit_v1 <= 0;
				end
				else 
				begin
					data_bit_y1 <= data_y4[BITS-8-1];
					data_bit_u1 <= data_u4[BITS-8-1];
					data_bit_v1 <= data_v4[BITS-8-1];
					data_y5 <= data_y4 >> (BITS-8);
					data_u5 <= data_u4 >> (BITS-8);
					data_v5 <= data_v4 >> (BITS-8);
				end
			end
		end
		else
		begin
			always @ (posedge pclk or negedge rst_n) 
			begin
				if (!rst_n) 
				begin
					data_y5 <= 0;
					data_u5 <= 0;
					data_v5 <= 0;
					data_bit_y1 <= 0;
					data_bit_u1 <= 0;
					data_bit_v1 <= 0;
				end
				else 
				begin
					data_bit_y1 <= 1'b0;
					data_bit_u1 <= 1'b0;
					data_bit_v1 <= 1'b0;
					data_y5 <= data_y4;
					data_u5 <= data_u4;
					data_v5 <= data_v4;
				end
			end
		end
	endgenerate

    //Adding 0.5 place bit (0 or 1 will be added)

    reg  [BITS-1:0] data_y6;
    reg  [BITS-1:0] data_u6;
    reg  [BITS-1:0] data_v6;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            data_y6 <= 0;
            data_u6 <= 0;
            data_v6 <= 0;
        end
        else begin
            data_y6 <= data_y5[7:0]+data_bit_y1;
            data_u6 <= data_u5[7:0]+data_bit_u1;
            data_v6 <= data_v5[7:0]+data_bit_v1;
        end
    end

    
	// Adjusting for computation delay
	localparam DLY_CLK = 9;
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

	generate
		if(BITS > 8)
		begin
			assign out_y = out_href ? ( (data_y6[8]) ? {8{1'b1}} : data_y6[7:0] ) : {8{1'b0}};
			assign out_u = out_href ? ( (data_u6[8]) ? {8{1'b1}} : data_u6[7:0] ) : {8{1'b0}};
			assign out_v = out_href ? ( (data_v6[8]) ? {8{1'b1}} : data_v6[7:0] ) : {8{1'b0}};
		end
		else
		begin
			assign out_y = out_href ? data_y6[BITS-1:0] : {8{1'b0}};
			assign out_u = out_href ? data_u6[BITS-1:0] : {8{1'b0}};
			assign out_v = out_href ? data_v6[BITS-1:0] : {8{1'b0}};
		end
	endgenerate
endmodule