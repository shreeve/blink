// -----------------------------------------------------------------------------
// blink.v  --  Blinky for the Lattice CrossLinkU-NX-33 Evaluation Board
//              (LIFCL-33U-9CTG104I, FCCSP104 package)
//
// Uses the FPGA's on-chip high-frequency oscillator (OSCD hard block) as the
// clock source, so NO external clock pin is required.  A free-running counter
// divides that clock down to a ~1 Hz, human-visible blink on one LED.
// -----------------------------------------------------------------------------
`default_nettype none

module blink (
    output wire led            // drives one user LED on the board
);

    // -------------------------------------------------------------------------
    // On-chip oscillator.  The CrossLinkU-NX-33 (LIFCL-33U) uses the "OSCD"
    // hard block (OSCA is used on the larger LIFCL-40/17 parts).
    // Base HF oscillator = 450 MHz.  HFCLKOUT = 450 MHz / DIV, where the OSCD
    // HF_CLK_DIV *string* encodes (DIV - 1) -- confirmed in the Radiant osc IP:
    //   HFCLKOUT = 450e6 / HF_CLK_DIV_DEC   (ip/lifcl/osc/ldc/constraint.ldc)
    //   HF_CLK_DIV = str(HF_CLK_DIV_DEC - 1) (plugin.py: ext_calc_div_str)
    // So HF_CLK_DIV = "12"  ->  DIV = 13  ->  450 / 13  ~=  34.6 MHz.
    // -------------------------------------------------------------------------
    wire clk;

    OSCD #(
        .HF_CLK_DIV   ("12"),        // ~18.75 MHz HFCLKOUT
        .HF_OSC_EN    ("ENABLED"),   // turn the HF oscillator on
        .LF_OUTPUT_EN ("DISABLED")
    ) osc_i (
        .HFOUTEN    (1'b1),          // enable the HF clock output
        .HFSDSCEN   (1'b0),
        .HFOUTCIBEN (1'b0),
        .REBOOT     (1'b0),
        .HFCLKOUT   (clk),           // ~18.75 MHz clock used by the design
        .LFCLKOUT   (),
        .HFCLKCFG   (),
        .HFSDCOUT   ()
    );

    // -------------------------------------------------------------------------
    // Clock divider.  led = bit[24], which is high for 2^24 clocks and low for
    // 2^24 clocks, so a full on/off period is 2^25 clocks:
    //   2^25 / 34.6e6 ~= 0.97 s  ->  ~1.03 Hz blink.
    // (bit[23] gave a 2^24-clock period ~= 0.48 s ~= 2.06 Hz -- the "2 Hz" that
    //  was observed, because the real clock is 34.6 MHz, not the 18.75 MHz the
    //  old comment assumed.)
    // -------------------------------------------------------------------------
    reg [31:0] counter = 32'd0;

    always @(posedge clk)
        counter <= counter + 32'd1;

    assign led = counter[24];

endmodule

`default_nettype wire
