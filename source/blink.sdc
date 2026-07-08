# -----------------------------------------------------------------------------
# blink.sdc  --  Timing constraints
#
# The design is clocked by the on-chip OSCD oscillator.  With HF_CLK_DIV="12"
# (divide-by-13 of the 450 MHz base) HFCLKOUT is ~34.6 MHz.  Timing is
# non-critical for a blinky, but we declare the clock so the tools can analyze
# it and report a clean timing summary.  Period 28.9 ns = 34.6 MHz.
# -----------------------------------------------------------------------------

create_clock -name {clk} -period 28.9 [get_nets clk]
