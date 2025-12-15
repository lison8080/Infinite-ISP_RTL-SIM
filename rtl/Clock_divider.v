/*************************************************************************
> File Name: Clock_divider.v
> Description: Clock Generation for scale module
> Author: 10xEngineers
> Mail: isp@10xengineers.ai
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
    
// BUFGCE_DIV: General Clock Buffer with Divide Function
//             UltraScale
// Xilinx HDL Language Template, version 2022.1

    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(CLK_DIVIDER),              // 1-8
        // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
        .IS_CE_INVERTED(1'b0),          // Optional inversion for CE
        .IS_CLR_INVERTED(1'b0),         // Optional inversion for CLR
        .IS_I_INVERTED(1'b0),           // Optional inversion for I
        .SIM_DEVICE("ULTRASCALE_PLUS")  // ULTRASCALE, ULTRASCALE_PLUS
    )
    BUFGCE_DIV_inst (
        .O(scale_clk),     // 1-bit output: Buffer
        .CE(1'b1),   // 1-bit input: Buffer enable
        .CLR(1'b0), // 1-bit input: Asynchronous clear
        .I(pclk)      // 1-bit input: Buffer
    );

// End of BUFGCE_DIV_inst instantiation
endmodule
