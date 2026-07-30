`timescale 1ns / 1ps

module ethernet_decoder(
    input  wire        CLK,
    input  wire        ARESET,
    input  wire [65:0] ENC_BLOCK, // 66-bit block from descrambler
    input  wire        VALID_DATA,
    output reg  [63:0] XGMII_RXD,     // 64-bit MAC data bus
    output reg  [7:0]  XGMII_RXC      // 8-bit MAC control bus
);

    //Sync Header Definitions
    localparam SYNC_DATA = 2'b01;
    localparam SYNC_CTRL = 2'b10;

    //Block Type Hex Codes
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

    //Standard XGMII Control Characters
    localparam CHAR_IDLE  = 8'h07;
    localparam CHAR_START = 8'hFB;
    localparam CHAR_TERM  = 8'hFD;
    localparam CHAR_ERROR = 8'hFE;

    //Internal Wire Assignments for Readability
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