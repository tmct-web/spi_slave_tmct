//=============================================================================
//	SPI slave sample implementation
//-----------------------------------------------------------------------------
//  spi_slave_sample_top.sv
//  SPI slave sample implementation
//-----------------------------------------------------------------------------
//  © 2022 tmct-web  https://ss1.xrea.com/tmct.s1009.xrea.com/
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
module spi_slave_sample
(
    input   logic           I_CLK,          // Main clock
    input   logic           I_RESET_N,      // Reset input (Active low)

    input   logic           I_SPI_SS_N,     // SPI chip select input (Active low)
    input   logic           I_SPI_CLK,      // SPI clock input
    input   logic           I_SPI_MOSI,     // SPI Master-Out-Slave-In
    output  wire            O_SPI_MISO      // SPI Master-In-Slave-Out
);

    localparam  spi_mode = 2'b00;   // SPI mode

    logic   [7:0]   bus_addr;       // Address output to internal bus
    logic   [7:0]   bus_idata;      // Data output to internal bus (So caled Master-Out-Slave-In)
    logic   [7:0]   bus_odata;      // Data input from internal bus (So called Master-In-Slave-Out)
    logic           bus_wr;         // Write valid pulse to internal bus (1 i_clk cycle)

    logic           reset;
    logic           clk;

    always_comb clk = I_CLK;
    always_comb reset = ~I_RESET_N;


    //-------------------------------------------------------------------------
    //  SPI Slave
    //-------------------------------------------------------------------------
    spi_slave_tmct_top m_spi_slave_tmct_top
    (
        .i_clk      (clk),
        .i_reset    (reset),

        .i_bus_data (bus_odata),
        .o_bus_addr (bus_addr),
        .o_bus_data (bus_idata),
        .o_bus_wr   (bus_wr),

        .i_spi_mode (spi_mode),
        .i_spi_ss_n (I_SPI_SS_N),
        .i_spi_clk  (I_SPI_CLK),
        .i_spi_mosi (I_SPI_MOSI),
        .o_spi_miso (O_SPI_MISO)
    );


    //-------------------------------------------------------------------------
    //  Register
    //-------------------------------------------------------------------------
    regs m_regs
    (
        .i_clk      (clk),
        .i_reset    (reset),
        .i_bus_wr   (bus_wr),
        .i_bus_addr (bus_addr),
        .i_bus_mosi (bus_idata),
        .o_bus_miso (bus_odata)
    );


endmodule