//=============================================================================
//	spi_slave_tmct
//-----------------------------------------------------------------------------
//  spi_slave.sv
//  SPI slave interface module: SPI slave engine
//-----------------------------------------------------------------------------
//  © 2022 tmct-web https://ss1.xrea.com/tmct.s1009.xrea.com/
//
//  Redistribution and use in source and binary forms, with or without modification, 
//  are permitted provided that the following conditions are met:
//
//  1.  Redistributions of source code must retain the above copyright notice, 
//      this list of conditions and the following disclaimer.
//
//  2.  Redistributions in binary form must reproduce the above copyright notice, 
//      this list of conditions and the following disclaimer in the documentation and/or 
//      other materials provided with the distribution.
//
//  3.  Neither the name of the copyright holder nor the names of 
//      its contributors may be used to endorse or promote products derived from 
//      this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//=============================================================================
module spi_slave_engine
(
    input   logic           i_clk,              // Main clock
                                                //  The i_clk frequency MUST be at least x6 the i_spi_clk frequency.
                                                //  For example, if the i_clk is 50 MHz, the i_spi_clk must be less than 8.3 MHz.
    input   logic           i_reset,            // Reset input (Active high)

    input   logic   [7:0]   i_tx_data,          // Byte to serialize to MISO
    input   logic           i_tx_data_valid,    // Data valid pulse to register
    output  logic   [7:0]   o_rx_data,          // Byte received on MOSI
    output  logic           o_rx_data_valid,    // Data valid pulse (1 clock cycle)
    output  logic           o_wip,              // Work in progress

    input   logic   [1:0]   i_spi_mode,         // SPI mode select input
                                                //                  clk idle  Sample   Shift
                                                //  2'b00: mode0 .. Low       Posedge  Negedge
                                                //  2'b01: mode1 .. Low       Negedge  Posedge
                                                //  2'b10: mode2 .. High      Posedge  Negedge
                                                //  2'b11: mode3 .. High      Negedge  Posedge
    input   logic           i_spi_ss_n,         // SPI chip select input (Active low)
    input   logic           i_spi_clk,          // SPI clock input
    input   logic           i_spi_mosi,         // SPI Master-Out-Slave-In
    output  wire            o_spi_miso          // SPI Master-In-Slave-Out
);

    logic           spi_miso;
    logic   [2:0]   spi_clk_count;

    logic   [7:0]   rx_data;
    logic   [7:0]   tx_data_l;

    logic   [1:0]   spi_clk_sreg;
    logic           spi_clk_shift_en;
    logic           spi_clk_shift_valid;
    logic           spi_clk_latch_en;
    logic           spi_clk_latch_en_l;

    always_comb o_spi_miso = i_spi_ss_n ? 1'bz : spi_miso;


    //-------------------------------------------------------------------------
    //  i_spi_clk edge detection
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            spi_clk_sreg <= 2'b00;
            spi_clk_latch_en_l <= 1'b0;
        end
        else
        begin
            spi_clk_sreg <= { spi_clk_sreg[0], i_spi_clk };
            spi_clk_latch_en_l <= spi_clk_latch_en;
            if ((i_spi_mode == 2'd0) || (i_spi_mode == 2'd3))
            begin
                if (spi_clk_sreg == 2'b01) spi_clk_latch_en <= 1'b1; else spi_clk_latch_en <= 1'b0;
                if (spi_clk_sreg == 2'b10) spi_clk_shift_en <= 1'b1; else spi_clk_shift_en <= 1'b0;
            end
            else
            begin
                if (spi_clk_sreg == 2'b01) spi_clk_shift_en <= 1'b1; else spi_clk_shift_en <= 1'b0;
                if (spi_clk_sreg == 2'b10) spi_clk_latch_en <= 1'b1; else spi_clk_latch_en <= 1'b0;
            end
        end
    end


    //-------------------------------------------------------------------------
    //  SERDES
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            //-----------------------------------------------------------------
            //  Asynchronous reset
            //-----------------------------------------------------------------
            spi_clk_count <= 3'h0;
            o_rx_data <= 8'h0;
            rx_data <= 8'h0;
            o_rx_data_valid <= 1'b0;
            spi_miso <= 1'b0;
            spi_clk_shift_valid <= 1'b0;
            o_wip <= 1'b0;
        end
        else
        begin
            if (i_spi_ss_n)
            begin
                //-------------------------------------------------------------
                //  Device not selected
                //-------------------------------------------------------------
                spi_clk_count <= 3'h0;
                o_rx_data_valid <= 1'b0;
                spi_clk_shift_valid <= 1'b0;
                spi_miso <= 1'b0;
                o_wip <= 1'b0;
            end
            else
            begin
                //-------------------------------------------------------------
                //  Device selected
                //-------------------------------------------------------------
                o_wip <= 1'b1;
                if (spi_clk_latch_en)
                begin
                    // RX data latch ------------------------------------------
                    if      (spi_clk_count == 3'h0) rx_data[7] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h1) rx_data[6] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h2) rx_data[5] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h3) rx_data[4] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h4) rx_data[3] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h5) rx_data[2] <= i_spi_mosi;
                    else if (spi_clk_count == 3'h6) rx_data[1] <= i_spi_mosi;
                    else                            rx_data[0] <= i_spi_mosi;
                end

                // Clock counter ----------------------------------------------
                if      (spi_clk_shift_en & spi_clk_shift_valid)    spi_clk_count <= spi_clk_count + 3'h1;
                else if (o_rx_data_valid)                           spi_clk_count <= 3'h0;

                // Byte operation complete detection --------------------------
                if ((spi_clk_count == 3'h7) && spi_clk_latch_en_l)
                begin
                    o_rx_data <= rx_data;
                    o_rx_data_valid <= 1'b1;
                end
                else
                begin
                    o_rx_data_valid <= 1'b0;
                end

                // Shift enable signal generation -----------------------------
                // Ignore shifts prior to the first latch signal
                if      (spi_clk_latch_en)  spi_clk_shift_valid <= 1'b1;
                else if (o_rx_data_valid)   spi_clk_shift_valid <= 1'b0;

                // TX data output ---------------------------------------------
                if      (spi_clk_count == 3'h0) spi_miso <= tx_data_l[7];
                else if (spi_clk_count == 3'h1) spi_miso <= tx_data_l[6];
                else if (spi_clk_count == 3'h2) spi_miso <= tx_data_l[5];
                else if (spi_clk_count == 3'h3) spi_miso <= tx_data_l[4];
                else if (spi_clk_count == 3'h4) spi_miso <= tx_data_l[3];
                else if (spi_clk_count == 3'h5) spi_miso <= tx_data_l[2];
                else if (spi_clk_count == 3'h6) spi_miso <= tx_data_l[1];
                else                            spi_miso <= tx_data_l[0];
            end
        end
    end


    //-------------------------------------------------------------------------
    //  i_tx_data register
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            tx_data_l <= 8'h0;
        end
        else
        begin
            if      (i_tx_data_valid)   tx_data_l <= i_tx_data;
            else if (o_rx_data_valid)   tx_data_l <= 8'h0;
        end
    end

endmodule