`include "descrambler.v"
`include "scrambler.v"

module top(input [65:0] ENC_DATA,
           input CLK,
           input ARESET,
           output DESCRAMB_OUT,
           output [65:0] DECODE_DATA_IN,
           output VALID_DATA,
           output GARBAGE_FLAG,
           output SCRAMB_OUT
          );
  
  wire [1:0] CMD_BITS;
  
  
  scrambler TX_SCRAMBLER (.ENC_DATA(ENC_DATA),
                         .CLK(CLK),
                         .ARESET(ARESET),
                         .CMD_BITS(CMD_BITS),
                         .SCRAMB_OUT(SCRAMB_OUT)
                        );
  
  descrambler RX_DESCRAMBLER (.SCRAMB_IN(SCRAMB_OUT),
                           .CLK(CLK),
                           .ARESET(ARESET),
                           .CMD_BITS(CMD_BITS),
                           .DESCRAMB_OUT(DESCRAMB_OUT),
                           .DECODE_DATA(DECODE_DATA_IN),
                           .VALID_DATA(VALID_DATA),
                           .GARBAGE_FLAG(GARBAGE_FLAG)
                          );
  
endmodule                  