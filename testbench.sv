
`timescale 1ns / 1ps

module top_tb;
    
    // 1. Inputs as reg, Outputs as wire
    reg [65:0] ENC_DATA;
    reg CLK;
    reg ARESET;
    
    wire DESCRAMB_OUT;
    wire [65:0] DECODE_DATA_IN;
    wire VALID_DATA;
    wire GARBAGE_FLAG;
    wire SCRAMB_OUT;
    
    // 2. Instantiate the Top Module
    top DUT (
        .ENC_DATA(ENC_DATA),
        .CLK(CLK),
        .ARESET(ARESET),
        .DESCRAMB_OUT(DESCRAMB_OUT),
        .DECODE_DATA_IN(DECODE_DATA_IN),
        .VALID_DATA(VALID_DATA),
        .GARBAGE_FLAG(GARBAGE_FLAG),
        .SCRAMB_OUT(SCRAMB_OUT)
    );
    
    // 3. Waveform Dumping
    initial begin
        $dumpfile("top_dump.vcd"); 
        $dumpvars(0, top_tb); 
    end

    // 4. Clock Generation (10ns period)
    initial begin
        CLK = 1'b0;
    end
    always #5 CLK = ~CLK;
    
    // 5. Randomize Data Task
    task randomize_encoder_data_packet;
        begin
            // 2-bit header (01 for data) + 64 bits of random payload
            ENC_DATA = {2'b01, $random, $random};
        end
    endtask
    
    // ---------------------------------------------------------
    // DEBUG: Text-based Logic Analyzer
    // ---------------------------------------------------------
    initial begin
        $display("Starting Cycle-by-Cycle Monitor...");
        $monitor("Time = %0t | VALID_DATA = %b | DECODE_DATA_IN = %h", 
                 $time, VALID_DATA, DECODE_DATA_IN);
    end

    // ---------------------------------------------------------
    // DEBUG: Previous Cycle Tracker
    // ---------------------------------------------------------
    reg [65:0] PREV_DECODE_DATA;
    
    always @(posedge CLK) begin
        PREV_DECODE_DATA <= DECODE_DATA_IN;
    end

    // ---------------------------------------------------------
    // Upgraded Automated Checking Block
    // ---------------------------------------------------------
    always @(posedge CLK) begin
        if (VALID_DATA) begin
            $display("\n==================================================");
            $display("TRIGGER: VALID_DATA went HIGH at Time %0t", $time);
            $display("--------------------------------------------------");
            $display("Transmitted Payload      : %h", ENC_DATA);
            $display("Current DECODE_DATA_IN   : %h", DECODE_DATA_IN);
            $display("Previous DECODE_DATA_IN  : %h", PREV_DECODE_DATA);
            
            if (ENC_DATA == DECODE_DATA_IN)
                $display(">>> RESULT: Match on CURRENT cycle.");
            else if (ENC_DATA == PREV_DECODE_DATA)
                $display(">>> RESULT: Match on PREVIOUS cycle! (Timing misalignment detected)");
            else
                $display(">>> RESULT: Total Mismatch.");
            $display("==================================================\n");
        end
    end

    // 7. Main Stimulus Block
    initial begin
        // Initialize Inputs
        ENC_DATA = 66'd0;
        ARESET = 1'b1;
        
        #20;
        
        @(negedge CLK); 
            ARESET = 1'b0;
            
        // Inject the single packet and hold it steady
        randomize_encoder_data_packet();
        
        // Wait long enough for 58 cycles of garbage + 64 cycles of shifting
        #1500;
       
        $finish;
    end            
    
endmodule
