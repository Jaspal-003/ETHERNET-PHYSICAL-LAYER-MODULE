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
  
  // Terminate Block Types
  localparam TYPE_TERM0 = 8'h87;
  localparam TYPE_TERM1 = 8'h99;
  localparam TYPE_TERM2 = 8'hAA;
  localparam TYPE_TERM3 = 8'hB4;
  localparam TYPE_TERM4 = 8'hCC;
  localparam TYPE_TERM5 = 8'hD2;
  localparam TYPE_TERM6 = 8'hE1;
  localparam TYPE_TERM7 = 8'hFF;

  // NEW: Additional Block Types per IEEE 802.3 Fig 49-7
  localparam TYPE_OS_CTRL = 8'h2D;      // Control on 0-3, OS on 4
  localparam TYPE_START4 = 8'h33;       // Control on 0-3, Start on 4
  localparam TYPE_OS_START4 = 8'h66;    // OS on 0, Start on 4
  localparam TYPE_DOUBLE_OS = 8'h55;    // OS on 0, OS on 4
  localparam TYPE_OS_L0 = 8'h4B;        // OS on 0, Control on 4-7
  
  localparam SYNC_DATA = 2'b01;
  localparam SYNC_CTRL = 2'b10;
  
  always@(posedge CLK or posedge ARESET)
    begin
      if(ARESET)
        ENC_OUT <= 66'd0;
      
      else
        begin
          case(XGMII_TXC)
            // Pure Data
            8'h00:
              ENC_OUT <= {SYNC_DATA, XGMII_TXD};

            // Start or Ordered Set on Lane 0
            // Start On lane 0
            8'h01: 
            begin
              // The only valid control character here is Start (0xFB)
              if (XGMII_TXD[7:0] == 8'hFB)           
                ENC_OUT <= {SYNC_CTRL, TYPE_START, XGMII_TXD[63:8]};
              else
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'hFFFFFFFFFFFFFF}; // Error fallback
            end

            // Start or Ordered Set on Lane 4 (Lanes 0-3 are Control)
            8'h1F: begin
              if (XGMII_TXD[39:32] == 8'hFB)         // Start on Lane 4
                ENC_OUT <= {SYNC_CTRL, TYPE_START4, XGMII_TXD[63:40], 32'd0};
              else if (XGMII_TXD[39:32] == 8'h9C)    // Sequence Ordered Set
                ENC_OUT <= {SYNC_CTRL, TYPE_OS_CTRL, XGMII_TXD[63:40], 4'h0, 28'd0};
              else if (XGMII_TXD[39:32] == 8'h5C)    // Signal Ordered Set
                ENC_OUT <= {SYNC_CTRL, TYPE_OS_CTRL, XGMII_TXD[63:40], 4'hF, 28'd0};
              else
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
            end

            // Ordered Set on Lane 0 AND (Start or OS) on Lane 4
            8'h11: begin
              if (XGMII_TXD[7:0] == 8'h9C || XGMII_TXD[7:0] == 8'h5C) begin
                if (XGMII_TXD[39:32] == 8'hFB) begin
                    // OS + Start (Block Type 0x66)
                    ENC_OUT <= {SYNC_CTRL, TYPE_OS_START4, XGMII_TXD[63:40], 4'd0, (XGMII_TXD[7:0] == 8'h9C ? 4'h0 : 4'hF), XGMII_TXD[31:8]};
                end
                else if (XGMII_TXD[39:32] == 8'h9C || XGMII_TXD[39:32] == 8'h5C) begin
                    // Double OS (Block Type 0x55)
                    ENC_OUT <= {SYNC_CTRL, TYPE_DOUBLE_OS, XGMII_TXD[63:40], (XGMII_TXD[39:32] == 8'h9C ? 4'h0 : 4'hF), (XGMII_TXD[7:0] == 8'h9C ? 4'h0 : 4'hF), XGMII_TXD[31:8]};
                end
                else begin
                    ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
                end
              end
              else begin
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
              end
            end

            // Ordered Set on Lane 0 (Lanes 4-7 are Control)
            8'hF1: begin
              if (XGMII_TXD[7:0] == 8'h9C)
                ENC_OUT <= {SYNC_CTRL, TYPE_OS_L0, 28'd0, 4'h0, XGMII_TXD[31:8]};
              else if (XGMII_TXD[7:0] == 8'h5C)
                ENC_OUT <= {SYNC_CTRL, TYPE_OS_L0, 28'd0, 4'hF, XGMII_TXD[31:8]};
              else
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
            end
            
            // All Lanes Control (Idles, Terminate 0, Errors)
            8'hFF: begin
              if(XGMII_TXD[7:0] == 8'h07)
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
              else if(XGMII_TXD[7:0] == 8'hFD)
                ENC_OUT <= {SYNC_CTRL, TYPE_TERM0, 56'd0};
              else
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0}; // Error fallback
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

            // Default Fallback for illegal XGMII patterns
            default: begin
                ENC_OUT <= {SYNC_CTRL, TYPE_IDLE, 56'd0};
            end
            
          endcase            
        end
    end
  
endmodule
