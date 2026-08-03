`timescale 1ns / 1ps

module ethernet_decoder(
    input  wire        CLK,
    input  wire        ARESET,
    input  wire [65:0] ENC_BLOCK, // 66-bit block from descrambler
    input  wire        VALID_DATA,
    output reg  [63:0] XGMII_RXD,     // 64-bit MAC data bus
    output reg  [7:0]  XGMII_RXC      // 8-bit MAC control bus
);

    // Sync Header Definitions
    localparam SYNC_DATA = 2'b01;
    localparam SYNC_CTRL = 2'b10;

    // Block Type Hex Codes
    localparam TYPE_IDLE  = 8'h1E;
    localparam TYPE_START = 8'h78;
    localparam TYPE_TERM0 = 8'h87;
    localparam TYPE_TERM1 = 8'h99;
    localparam TYPE_TERM2 = 8'hAA;
    localparam TYPE_TERM3 = 8'hB4;
    localparam TYPE_TERM4 = 8'hCC;
    localparam TYPE_TERM5 = 8'hD2;
    localparam TYPE_TERM6 = 8'hE1;
    localparam TYPE_TERM7 = 8'hFF;

    // Additional Block Types per IEEE 802.3 Fig 49-7
    localparam TYPE_OS_CTRL   = 8'h2D;      // Control on 0-3, OS on 4
    localparam TYPE_START4    = 8'h33;      // Control on 0-3, Start on 4
    localparam TYPE_OS_START4 = 8'h66;      // OS on 0, Start on 4
    localparam TYPE_DOUBLE_OS = 8'h55;      // OS on 0, OS on 4
    localparam TYPE_OS_L0     = 8'h4B;      // OS on 0, Control on 4-7

    // Standard XGMII Control Characters
    localparam CHAR_IDLE   = 8'h07;
    localparam CHAR_START  = 8'hFB;
    localparam CHAR_TERM   = 8'hFD;
    localparam CHAR_ERROR  = 8'hFE;
    localparam CHAR_SEQ_OS = 8'h9C; // Sequence Ordered Set
    localparam CHAR_SIG_OS = 8'h5C; // Signal Ordered Set

    // Internal Wire Assignments for Readability
    wire [1:0]  sync_header;
    wire [7:0]  block_type;
    wire [55:0] payload;

    assign sync_header = ENC_BLOCK[65:64];
    assign block_type  = ENC_BLOCK[63:56];
    assign payload     = ENC_BLOCK[55:0];

    always @(posedge CLK or posedge ARESET) 
    begin
        if (ARESET) 
        begin
            // Reset state: flood the MAC with pure Idles
            XGMII_RXD <= {8{CHAR_IDLE}}; 
            XGMII_RXC <= 8'hFF;
        end 
        else 
        begin
            // Top-level check: Is the incoming data valid?
            if (VALID_DATA == 1'b1) 
            begin
                
                // Evaluate the 2-bit Sync Header
                if (sync_header == SYNC_DATA) begin
                    // -- PURE DATA BLOCK --
                    XGMII_RXC <= 8'h00;                     // All 8 lanes are data
                    XGMII_RXD <= ENC_BLOCK[63:0];           // Map all 64 bits directly
                end 
                else if (sync_header == SYNC_CTRL) begin
                    // -- CONTROL BLOCK --
                    case (block_type)

                        TYPE_IDLE: begin
                            XGMII_RXC <= 8'hFF;
                            XGMII_RXD <= {8{CHAR_IDLE}}; // Restore 8 Idle characters
                        end

                        TYPE_START: begin
                            XGMII_RXC <= 8'h01;          // Lane 0 is control
                            // Restore Start char to Lane 0, map remaining 56 bits to Lanes 1-7
                            XGMII_RXD <= {payload[55:0], CHAR_START};
                        end

                        // START ON LANE 4
                        TYPE_START4: begin
                            XGMII_RXC <= 8'h1F;          // Lanes 0,1,2,3,4 are Control
                            // Pad Lanes 0-3 with Idles, insert Start on 4, map Data to 5-7
                            XGMII_RXD <= {payload[55:32], CHAR_START, {4{CHAR_IDLE}}};
                        end

                        // ORDERED SET ON LANE 4 (Control on 0-3)
                        TYPE_OS_CTRL: begin
                            XGMII_RXC <= 8'h1F;          // Lanes 0,1,2,3,4 are Control
                            // Decompress 4-bit O-code on Lane 4 back to 8-bit Ordered Set
                            XGMII_RXD <= {payload[55:32], (payload[31:28] == 4'h0 ? CHAR_SEQ_OS : CHAR_SIG_OS), {4{CHAR_IDLE}}};
                        end

                        // ORDERED SET ON LANE 0, START ON LANE 4
                        TYPE_OS_START4: begin
                            XGMII_RXC <= 8'h11;          // Lanes 0 and 4 are Control
                            // Reconstruct both the Lane 0 OS and the Lane 4 Start
                            XGMII_RXD <= {payload[55:32], CHAR_START, payload[23:0], (payload[27:24] == 4'h0 ? CHAR_SEQ_OS : CHAR_SIG_OS)};
                        end

                        // DOUBLE ORDERED SET (Lanes 0 and 4)
                        TYPE_DOUBLE_OS: begin
                            XGMII_RXC <= 8'h11;          // Lanes 0 and 4 are Control
                            // Decompress both O-codes into their respective lanes
                            XGMII_RXD <= {payload[55:32], (payload[31:28] == 4'h0 ? CHAR_SEQ_OS : CHAR_SIG_OS), payload[23:0], (payload[27:24] == 4'h0 ? CHAR_SEQ_OS : CHAR_SIG_OS)};
                        end

                        // ORDERED SET ON LANE 0 (Control on 4-7)
                        TYPE_OS_L0: begin
                            XGMII_RXC <= 8'hF1;          // Lanes 4,5,6,7 and 0 are Control
                            // Pad Lanes 4-7 with Idles, reconstruct OS on Lane 0
                            XGMII_RXD <= {{4{CHAR_IDLE}}, payload[23:0], (payload[27:24] == 4'h0 ? CHAR_SEQ_OS : CHAR_SIG_OS)};
                        end

                        TYPE_TERM0: begin
                            XGMII_RXC <= 8'hFF;          // All lanes are control
                            // Restore Term char to Lane 0, pad Lanes 1-7 with Idles
                            XGMII_RXD <= {{7{CHAR_IDLE}}, CHAR_TERM};
                        end

                        TYPE_TERM1: begin
                            XGMII_RXC <= 8'hFE;          // Lane 0 is data, Lanes 1-7 are control
                            XGMII_RXD <= {{6{CHAR_IDLE}}, CHAR_TERM, payload[7:0]};
                        end

                        TYPE_TERM2: begin
                            XGMII_RXC <= 8'hFC;
                            XGMII_RXD <= {{5{CHAR_IDLE}}, CHAR_TERM, payload[15:0]};
                        end

                        TYPE_TERM3: begin
                            XGMII_RXC <= 8'hF8;
                            XGMII_RXD <= {{4{CHAR_IDLE}}, CHAR_TERM, payload[23:0]};
                        end

                        TYPE_TERM4: begin
                            XGMII_RXC <= 8'hF0;
                            XGMII_RXD <= {{3{CHAR_IDLE}}, CHAR_TERM, payload[31:0]};
                        end

                        TYPE_TERM5: begin
                            XGMII_RXC <= 8'hE0;
                            XGMII_RXD <= {{2{CHAR_IDLE}}, CHAR_TERM, payload[39:0]};
                        end

                        TYPE_TERM6: begin
                            XGMII_RXC <= 8'hC0;
                            XGMII_RXD <= {CHAR_IDLE, CHAR_TERM, payload[47:0]};
                        end

                        TYPE_TERM7: begin
                            XGMII_RXC <= 8'h80;          // Lane 7 is control, Lanes 0-6 are data
                            XGMII_RXD <= {CHAR_TERM, payload[55:0]};
                        end

                        default: begin
                            // Invalid Block Type: Output Error characters to protect the MAC
                            XGMII_RXC <= 8'hFF;
                            XGMII_RXD <= {8{CHAR_ERROR}};
                        end
                    endcase
                end 
                else begin
                    // Sync Header Error (00 or 11): Output Error characters
                    XGMII_RXC <= 8'hFF;
                    XGMII_RXD <= {8{CHAR_ERROR}};
                end

            end 
            else begin
                // Invalid Data: Flood MAC with IDLEs
                XGMII_RXC <= 8'hFF;
                XGMII_RXD <= {8{CHAR_IDLE}};
            end
        end
    end

endmodule
