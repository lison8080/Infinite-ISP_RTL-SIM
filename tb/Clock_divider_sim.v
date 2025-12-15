/*************************************************************************
> File Name: Clock_divider_sim.v
> Description: Behavioral Clock Divider for simulation (replaces FPGA primitive)
> Author: Simulation Model
************************************************************************/
`timescale 1ns / 1ps

module Clock_divider 
    #(
        parameter CLK_DIVIDER = 1
    )
    (
        input pclk,
        output scale_clk           
    );
    
    generate
        if (CLK_DIVIDER == 1) begin : no_div
            // No division, pass through
            assign scale_clk = pclk;
        end
        else begin : with_div
            // Simple clock divider using counter
            reg [$clog2(CLK_DIVIDER)-1:0] counter = 0;
            reg clk_out = 0;
            
            always @(posedge pclk) begin
                if (counter == CLK_DIVIDER - 1) begin
                    counter <= 0;
                    clk_out <= ~clk_out;
                end
                else begin
                    counter <= counter + 1;
                end
            end
            
            assign scale_clk = clk_out;
        end
    endgenerate

endmodule
