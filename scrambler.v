// Code your design here
`timescale 1ns / 1ps

module scrambler(
    input [65:0] ENC_DATA,
    input CLK,
    input ARESET,
    output SCRAMB_OUT,
    output [1:0] CMD_BITS
    );
    
    
    reg [57:0] LFSR_data;//Data present in the Shift Register 
    wire scramb_key;
    wire [57:0] seed_value;
    wire [63:0] actual_data;//Basically First two MSB's are truncated
    wire actual_data_bit;//For bit wise XOR Operation
    reg [6:0] KEY_COUNTER;//The counter is incremented on every shift and which eventually means that our Scramb_key bit is generated
    
    assign CMD_BITS = ENC_DATA[65:64];
    assign actual_data = ENC_DATA[63:0];
    
    assign scramb_key = LFSR_data[19] ^ LFSR_data[0];//Baasically 0 -> 58 tap and 19 is 38 tap
    
    assign SCRAMB_OUT = scramb_key ^ actual_data_bit;
    
    assign actual_data_bit = actual_data[KEY_COUNTER];
    
    assign seed_value = 58'h2F42401AAC0FFEE;//Yeh Kuch bhi le can be different on both sides
    
    always@(posedge CLK or posedge ARESET)
    begin
        if(ARESET)
        begin
            LFSR_data <= seed_value;
            KEY_COUNTER <= 7'd0;
        end
        else
        begin
            LFSR_data <= {SCRAMB_OUT, LFSR_data[57:1]};//Right Shift Operation
            
            if(KEY_COUNTER == 63)
                KEY_COUNTER <= 7'd0;
            else
                KEY_COUNTER <= KEY_COUNTER + 1'b1;
        end
    end   
endmodule