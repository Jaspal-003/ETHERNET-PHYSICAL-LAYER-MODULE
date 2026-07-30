`timescale 1ns/1ps
module ethernet_encoder(
  input CLK,
  input ARESET,
  
  //Interface from MAC(XGMII Standard)
  input [63:0] XGMII_TXD,
  input [7:0] XGMII_TXC,
  
  //Interface to the scrambler
  output reg [65:0] ENC_OUT
);
  
  localparam TYPE_IDLE = 8'h1E;
  localparam TYPE_START = 8'h78;
  localparam TYPE_TERM0 = 8'h87;
  localparam TYPE_TERM1 = 8'h99;
  localparam TYPE_TERM2 = 8'hAA;
  localparam TYPE_TERM3 = 8'hB4;
  localparam TYPE_TERM4 = 8'hCC;
  localparam TYPE_TERM5 = 8'hD2;
  localparam TYPE_TERM6 = 8'hE1;
  localparam TYPE_TERM7 = 8'hFF;
  
  localparam SYNC_DATA = 2'b01;
  localparam SYNC_CTRL = 2'b10;
  
  always@(posedge CLK or posedge ARESET)
    begin
      if(ARESET)
        ENC_OUT <= 66'd0;
      
      else
        begin
          case(XGMII_TXC)
            //Pure Data
            8'h00:
              ENC_OUT <= {SYNC_DATA, XGMII_TXD};
            //Start On lane 0
            8'h01:
              ENC_OUT <= {SYNC_CTRL, TYPE_START, XGMII_TXD[63:8]};
            
            8'hFF:
              begin
                //Check Lane 0 data to see if it's IDLE(0x07) or TERMINATE(0xFD)
                if(XGMII_TXD[7:0] == 8'h07)
                  ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
                else
                  ENC_OUT <= {SYNC_CTRL, TYPE_TERM0, 56'd0};
              end
				// Terminate 1 (1 byte data, 7 bytes control)
                8'hFE: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM1, 48'd0, XGMII_TXD[7:0]};
                end

                // Terminate 2 (2 bytes data, 6 bytes control)
                8'hFC: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM2, 40'd0, XGMII_TXD[15:0]};
                end

                // Terminate 3 (3 bytes data, 5 bytes control)
                8'hF8: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM3, 32'd0, XGMII_TXD[23:0]};
                end

                // Terminate 4 (4 bytes data, 4 bytes control)
                8'hF0: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM4, 24'd0, XGMII_TXD[31:0]};
                end

                // Terminate 5 (5 bytes data, 3 bytes control)
                8'hE0: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM5, 16'd0, XGMII_TXD[39:0]};
                end

                // Terminate 6 (6 bytes data, 2 bytes control)
                8'hC0: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM6, 8'd0, XGMII_TXD[47:0]};
                end

                // Terminate 7 (7 bytes data, 1 byte control)
                8'h80: begin 
                    ENC_OUT <= {SYNC_CTRL, TYPE_TERM7, XGMII_TXD[55:0]};
                end

                // Default Fallback
                default: begin
                    // If an illegal XGMII pattern appears, default to Idle to protect the link
                    ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
                end
                
            endcase            
        end
    end
  
endmodule