`timescale 1ns / 1ps

module descrambler(
    input SCRAMB_IN,      
    input CLK,
    input ARESET,
    input [1:0] CMD_BITS,
    output DESCRAMB_OUT,
    output reg [65:0] DECODE_DATA,
    output reg VALID_DATA,    
    output reg GARBAGE_FLAG
    );
    
    reg [63:0] DECODE_DATA_BUFFER;
    reg [57:0] LFSR_data;
    wire scramb_key;
    wire [57:0] seed_value;
  
    reg [6:0] VALID_COUNTER; 
    reg [5:0] sync_counter; 
    reg current_frame_invalid;
    
    assign scramb_key = LFSR_data[19] ^ LFSR_data[0];
    assign DESCRAMB_OUT = scramb_key ^ SCRAMB_IN;
    assign seed_value = 58'h123456789ABCDE; 
    
    
    
    // Deserializer (Shift Register & Counter)
    
    always @(posedge CLK or posedge ARESET) begin
        if (ARESET) begin
            DECODE_DATA_BUFFER <= 64'd0;
            VALID_COUNTER      <= 7'd0;
            VALID_DATA         <= 1'b0;
        end 
        else 
          begin
            
            DECODE_DATA_BUFFER <= {DESCRAMB_OUT, DECODE_DATA_BUFFER[63:1]};
          
            if(GARBAGE_FLAG)
            begin
              current_frame_invalid <= 1'b1;
            end
            
            if (VALID_COUNTER == 7'd63) begin
                VALID_COUNTER <= 7'd0;
                
                DECODE_DATA <= {CMD_BITS, DESCRAMB_OUT, DECODE_DATA_BUFFER[63:1]};
              
                
              if (GARBAGE_FLAG == 1'b0 && current_frame_invalid == 1'b0) 
                begin
                    VALID_DATA <= 1'b1; 
                end 
              else 
                begin
                    VALID_DATA <= 1'b0; 
                end
              
              current_frame_invalid <= 1'b0;
            end 
            else begin
                VALID_COUNTER <= VALID_COUNTER + 1'b1;
                VALID_DATA    <= 1'b0;
            end
        end
    end
  
    
    // Scrambler LFSR & Garbage Flag Tracking
    
    always @(posedge CLK or posedge ARESET) begin
        if (ARESET) begin
            LFSR_data    <= seed_value;
            GARBAGE_FLAG <= 1'b1;
            sync_counter <= 6'd0;
        end else begin
            LFSR_data <= {SCRAMB_IN, LFSR_data[57:1]};
            
            if (sync_counter < 6'd58) begin
                sync_counter <= sync_counter + 1'b1;
                GARBAGE_FLAG <= 1'b1; 
            end else begin
                GARBAGE_FLAG <= 1'b0;
            end
        end
    end   
endmodule