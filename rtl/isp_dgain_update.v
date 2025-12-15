/*************************************************************************
> File Name: isp_dgain_update.v
> Description: Updating index of the Gain array for selecting Digital Gain 
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
************************************************************************/
`timescale 1ns / 1ps

/*
 * ISP - Digital Gain updated
 */

module isp_dgain_update
#(
  parameter DGAIN_ARRAY_SIZE = 100,
  parameter DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE)
  ) 
(
    input pclk,
	input rst_n,
	

	input [1:0] ae_response,
	input [DGAIN_ARRAY_BITS-1:0] dgain_current_index,
	
	output [DGAIN_ARRAY_BITS-1:0] dgain_resulting_index
	

);

// determine index based on ae_response
reg signed [DGAIN_ARRAY_BITS-1:0] index_result_mux_out;
reg [DGAIN_ARRAY_BITS-1:0] dgain_index_r;
always @ (*)
 begin
 case (ae_response)
 2'b00: begin index_result_mux_out = dgain_current_index; end
 2'b01: begin index_result_mux_out = dgain_current_index == 4'd0 ? dgain_current_index : dgain_current_index - 1; end
 2'b10: begin index_result_mux_out = dgain_current_index; end
 2'b11: begin index_result_mux_out = dgain_current_index == DGAIN_ARRAY_SIZE-1 ? dgain_current_index : dgain_current_index + 1; end 
 endcase
 end

// Dgain index register
always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
			dgain_index_r <= 0;
		end
		else begin
		dgain_index_r <= index_result_mux_out;
		end 
end 



assign dgain_resulting_index = dgain_index_r;

endmodule