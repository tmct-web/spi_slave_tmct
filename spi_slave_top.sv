//=============================================================================
//	spi_slave_tmct
//-----------------------------------------------------------------------------
//  spi_slave_top.sv
//  SPI slave interface module: Top-level entry and protocol controller
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
module spi_slave_tmct_top
(
    input   logic           i_clk,              // Main clock
                                                //  The i_clk frequency MUST be at least x6 the i_spi_clk frequency.
                                                //  For example, if the i_clk is 50 MHz, the i_spi_clk must be less than 8.3 MHz.
    input   logic           i_reset,            // Reset input (Active high)

    input   logic   [7:0]   i_bus_data,         // Data input from internal bus (So called Master-In-Slave-Out)
                                                //  When reading from SPI, i_bus_data must be a valid value immediately 
                                                //  after the o_bus_addr is determined.
                                                //  This is because valid data must be latched between the o_bus_addr determination 
                                                //  and the next i_spi_clk clock.
    output  logic   [7:0]   o_bus_addr,         // Address output to internal bus
    output  logic   [7:0]   o_bus_data,         // Data output to internal bus (So caled Master-Out-Slave-In)
    output  logic           o_bus_wr,           // Write valid pulse to internal bus (1 i_clk cycle)

    input   logic   [1:0]   i_spi_mode,         // SPI mode select input
    input   logic           i_spi_ss_n,         // SPI chip select input (Active low)
    input   logic           i_spi_clk,          // SPI clock input
    input   logic           i_spi_mosi,         // SPI Master-Out-Slave-In
    output  wire            o_spi_miso          // SPI Master-In-Slave-Out
);

    localparam INSTRUCTION_WRITE    = 8'b0000_0010;
    localparam INSTRUCTION_READ     = 8'b0000_0011;

    typedef enum logic [2:0]
    {
        INSTRUCTION     = 3'h0,
        ADDRESS         = 3'h1,
        DATA_READ       = 3'h2,
        DATA_READ_NEXT  = 3'h3,
        DATA_WRITE      = 3'h4,
        DATA_WRITE_NEXT = 3'h5,
        HALT            = 3'h6
    } spi_state_enum;

    spi_state_enum currentState;
    spi_state_enum nextState;

    logic           wip;
    logic           rx_data_valid;
    logic   [1:0]   mode;
    logic   [7:0]   rx_data;
    logic           tx_data_valid;
    logic   [7:0]   tx_data;

    spi_slave_engine m_spi_slave_engine
    (
        .i_clk              (i_clk),            // Main clock
        .i_reset            (i_reset),          // Reset input (Active high)

        .i_tx_data          (tx_data),          // Byte to serialize to MISO
        .i_tx_data_valid    (tx_data_valid),    // Data valid pulse to register
        .o_rx_data          (rx_data),          // Byte received on MOSI
        .o_rx_data_valid    (rx_data_valid),    // Data valid pulse (1 clock cycle)
        .o_wip              (wip),              // Work in progress

        .i_spi_mode         (i_spi_mode),       // SPI mode select input
        .i_spi_ss_n         (i_spi_ss_n),       // SPI chip select input
        .i_spi_clk          (i_spi_clk),        // SPI clock input
        .i_spi_mosi         (i_spi_mosi),       // SPI Master-Out-Slave-In
        .o_spi_miso         (o_spi_miso)        // SPI Master-In-Slave-Out
    );


    //-------------------------------------------------------------------------
    //  State machine: State transition synchronization
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            currentState <= INSTRUCTION;
        end
        else
        begin
            currentState <= nextState;
        end
    end


    //-------------------------------------------------------------------------
    //  State machine: Output signal table
    //-------------------------------------------------------------------------
    always_ff @(posedge i_clk, posedge i_reset)
    begin
        if (i_reset)
        begin
            mode <= 2'b11;
            o_bus_addr <= 8'h0;
            tx_data_valid <= 1'b0;
            tx_data <= 8'h0;
            o_bus_data <= 8'h0;
            o_bus_wr <= 1'b0;
        end
        else
        begin
            if (currentState == INSTRUCTION)
            begin
                if (rx_data_valid)
                begin
                    if      (rx_data == INSTRUCTION_READ)   mode <= 2'b00;  // Read(Master-In-Slave-Out)
                    else if (rx_data == INSTRUCTION_WRITE)  mode <= 2'b01;  // Write(Master-Out-Slave-In)
                    else                                    mode <= 2'b11;  // Unknown
                end
                tx_data_valid <= 1'b0;
            end
            else if (currentState == ADDRESS)
            begin
                if (rx_data_valid)
                begin
                    o_bus_addr <= rx_data;
                    tx_data <= i_bus_data;
                    if (mode == 2'b00) tx_data_valid <= 1'b1;
                end
            end
            else if (currentState == DATA_READ)
            begin
                tx_data <= i_bus_data;
            end
            else if (currentState == DATA_READ_NEXT)
            begin
                tx_data <= i_bus_data;
                o_bus_addr <= o_bus_addr + 8'h1;
            end
            else if (currentState == DATA_WRITE)
            begin
                if (rx_data_valid)
                begin
                    o_bus_data <= rx_data;
                    o_bus_wr <= 1'b1;
                end
            end
            else if (currentState == DATA_WRITE_NEXT)
            begin
                o_bus_wr <= 1'b0;
                o_bus_addr <= o_bus_addr + 8'h1;
            end
            else if (currentState == HALT)
            begin
                o_bus_wr <= 1'b0;
                tx_data_valid <= 1'b0;
            end
        end
    end


    //-------------------------------------------------------------------------
    //  State machine: State transition table
    //-------------------------------------------------------------------------
    always_comb
    begin
        if (wip)
        begin
            if (currentState == INSTRUCTION)
            begin
                if (rx_data_valid) nextState = ADDRESS; else nextState = INSTRUCTION;
            end
            else if (currentState == ADDRESS)
            begin
                if (rx_data_valid)
                begin
                    if      (mode == 2'b00) nextState = DATA_READ;
                    else if (mode == 2'b01) nextState = DATA_WRITE;
                    else                    nextState = HALT;
                end
                else
                begin
                    nextState = ADDRESS;
                end
            end
            else if (currentState == DATA_READ)
            begin
                if (rx_data_valid) nextState = DATA_READ_NEXT; else nextState = DATA_READ;
            end
            else if (currentState == DATA_READ_NEXT)
            begin
                nextState = DATA_READ;
            end
            else if (currentState == DATA_WRITE)
            begin
                if (rx_data_valid) nextState = DATA_WRITE_NEXT; else nextState = DATA_WRITE;
            end
            else if (currentState == DATA_WRITE_NEXT)
            begin
                nextState = DATA_WRITE;
            end
            else if (currentState == HALT)
            begin
                nextState = HALT;
            end
            else
            begin
                nextState = INSTRUCTION;
            end
        end
        else
        begin
            nextState = INSTRUCTION;
        end
    end

endmodule