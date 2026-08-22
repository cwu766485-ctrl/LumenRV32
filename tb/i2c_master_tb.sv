`timescale 1 ns / 1 ps

`include "defines.v"

module i2c_master_tb;
    localparam [31:0] I2C_CTRL   = 32'h0;
    localparam [31:0] I2C_DATA   = 32'h4;
    localparam [31:0] I2C_CMD    = 32'h8;
    localparam [31:0] I2C_STATUS = 32'hc;
    localparam [31:0] I2C_DIV    = 32'h10;

    localparam [7:0] CMD_START = 8'h01;
    localparam [7:0] CMD_STOP  = 8'h02;
    localparam [7:0] CMD_WRITE = 8'h04;
    localparam [7:0] CMD_READ  = 8'h08;
    localparam [7:0] CMD_NACK  = 8'h10;

    reg clk;
    reg rst;
    reg we;
    reg[31:0] addr;
    reg[31:0] wdata;
    wire[31:0] rdata;
    tri scl;
    tri sda;
    wire irq;

    pullup(scl);
    pullup(sda);

    integer start_count;
    integer stop_count;
    integer received_count;
    reg[7:0] received_bytes[0:3];
    reg monitor_enable;
    reg transfer_active;

    // Behavioural single-address slave: ACK every received byte.  Once it
    // receives 0xa1 it returns 0x3c and observes the master's final NACK.
    reg slave_sda_low;
    reg slave_ack_pending;
    reg slave_ack_active;
    reg slave_read_mode;
    reg slave_wait_master_ack;
    reg[2:0] slave_rx_bits;
    reg[7:0] slave_rx_shift;
    reg[2:0] slave_tx_bit;
    reg master_sent_nack;
    reg[7:0] slave_read_data;

    assign sda = slave_sda_low ? 1'b0 : 1'bz;

    i2c_master u_dut(
        .clk(clk), .rst(rst), .we_i(we), .addr_i(addr), .data_i(wdata),
        .data_o(rdata), .scl(scl), .sda(sda), .irq_o(irq)
    );

    always #5 clk = ~clk;

    // I2C protocol monitor: SDA transition while SCL high denotes START/STOP;
    // data is sampled only on SCL rising edges.
    always @(negedge sda) begin
        if (monitor_enable && scl === 1'b1) begin
            start_count = start_count + 1;
            transfer_active = 1'b1;
            slave_rx_bits = 0;
            slave_rx_shift = 8'h00;
            slave_ack_pending = 1'b0;
            slave_ack_active = 1'b0;
        end
    end

    always @(posedge sda) begin
        if (monitor_enable && scl === 1'b1) begin
            stop_count = stop_count + 1;
            transfer_active = 1'b0;
        end
    end

    // Slave receive/ACK state.  ACK is driven during the ninth clock only.
    always @(posedge scl) begin
        if (monitor_enable && slave_wait_master_ack) begin
            master_sent_nack = sda;
            slave_wait_master_ack = 1'b0;
        end else if (monitor_enable && transfer_active && !slave_read_mode &&
            !slave_ack_pending && !slave_ack_active) begin
            slave_rx_shift = {slave_rx_shift[6:0], sda};
            if (slave_rx_bits == 3'd7) begin
                slave_ack_pending = 1'b1;
            end else begin
                slave_rx_bits = slave_rx_bits + 1'b1;
            end
        end
    end

    always @(negedge scl) begin
        if (monitor_enable && slave_ack_pending) begin
            slave_sda_low = 1'b1;
            slave_ack_pending = 1'b0;
            slave_ack_active = 1'b1;
        end else if (monitor_enable && slave_ack_active) begin
            slave_sda_low = 1'b0;
            slave_ack_active = 1'b0;
            slave_rx_bits = 0;
            received_bytes[received_count] = slave_rx_shift;
            received_count = received_count + 1;
            if (slave_rx_shift == 8'ha1) begin
                slave_read_mode = 1'b1;
                slave_tx_bit = 3'd7;
                slave_sda_low = ~slave_read_data[7];
            end
        end else if (monitor_enable && slave_read_mode) begin
            if (slave_tx_bit == 0) begin
                slave_sda_low = 1'b0;
                slave_read_mode = 1'b0;
                slave_wait_master_ack = 1'b1;
            end else begin
                slave_tx_bit = slave_tx_bit - 1'b1;
                slave_sda_low = ~slave_read_data[slave_tx_bit];
            end
        end
    end

    task automatic apb_write;
        input[31:0] write_addr;
        input[31:0] write_data;
        begin
            @(negedge clk);
            addr = write_addr;
            wdata = write_data;
            we = 1'b1;
            @(negedge clk);
            we = 1'b0;
        end
    endtask

    task automatic wait_done;
        integer timeout;
        begin
            addr = I2C_STATUS;
            #1;
            timeout = 0;
            while (rdata[1] != 1'b1) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 500) $fatal(1, "I2C command did not complete");
            end
        end
    endtask

    task automatic write_command;
        input[7:0] byte_value;
        input[7:0] command;
        begin
            apb_write(I2C_DATA, {24'h0, byte_value});
            apb_write(I2C_CMD, {24'h0, command});
            wait_done();
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        we = 1'b0;
        addr = 32'h0;
        wdata = 32'h0;
        start_count = 0;
        stop_count = 0;
        received_count = 0;
        monitor_enable = 1'b0;
        transfer_active = 1'b0;
        slave_sda_low = 1'b0;
        slave_ack_pending = 1'b0;
        slave_ack_active = 1'b0;
        slave_read_mode = 1'b0;
        slave_wait_master_ack = 1'b0;
        slave_rx_bits = 0;
        slave_rx_shift = 8'h0;
        slave_tx_bit = 3'd0;
        master_sent_nack = 1'b0;
        slave_read_data = 8'h3c;

        repeat (3) @(posedge clk);
        rst = `RstDisable;
        apb_write(I2C_CTRL, 32'h1);
        apb_write(I2C_DIV, 32'h1);

        // Invalid commands are rejected while the bus remains released.
        apb_write(I2C_CMD, {24'h0, CMD_WRITE});
        addr = I2C_STATUS;
        #1;
        if (rdata[6] != 1'b1 || rdata[5] != 1'b0 || rdata[0] != 1'b0)
            $fatal(1, "WRITE without START/bus ownership was not rejected");
        apb_write(I2C_CMD, {24'h0, CMD_WRITE | CMD_READ});
        addr = I2C_STATUS;
        #1;
        if (rdata[6] != 1'b1 || rdata[0] != 1'b0)
            $fatal(1, "WRITE|READ was not rejected");

        monitor_enable = 1'b1;
        // Standard register read: START, address+W, register, repeated START,
        // address+R, READ, NACK, STOP.  Every no-STOP byte must finish in
        // HOLD_LOW and preserve ownership of the bus.
        write_command(8'ha0, CMD_START | CMD_WRITE);
        if (rdata[5] != 1'b1 || rdata[3] != 1'b0 || rdata[4] != 1'b1 ||
            rdata[0] != 1'b0 || rdata[6] != 1'b0)
            $fatal(1, "first no-STOP command did not enter HOLD_LOW");
        write_command(8'h12, CMD_WRITE);
        if (rdata[5] != 1'b1 || rdata[3] != 1'b0 || rdata[4] != 1'b1)
            $fatal(1, "second no-STOP command released bus ownership");
        write_command(8'ha1, CMD_START | CMD_WRITE);
        if (rdata[5] != 1'b1 || rdata[3] != 1'b0)
            $fatal(1, "repeated START did not return to HOLD_LOW");

        apb_write(I2C_CMD, {24'h0, CMD_READ | CMD_NACK | CMD_STOP});
        wait_done();
        addr = I2C_DATA;
        #1;
        if (rdata[7:0] != 8'h3c) $fatal(1, "read data mismatch: %h", rdata[7:0]);
        addr = I2C_STATUS;
        #1;
        if (rdata[5] != 1'b0 || rdata[0] != 1'b0 || rdata[2] != 1'b0)
            $fatal(1, "STOP did not release bus or unexpected ACK error");
        if (master_sent_nack != 1'b1) $fatal(1, "master did not NACK final read byte");

        if (start_count != 2) $fatal(1, "expected START and repeated START, got %0d", start_count);
        if (stop_count != 1) $fatal(1, "expected one STOP, got %0d", stop_count);
        if (received_count != 3 || received_bytes[0] != 8'ha0 ||
            received_bytes[1] != 8'h12 || received_bytes[2] != 8'ha1)
            $fatal(1, "write sequence mismatch: count=%0d bytes=%h %h %h",
                   received_count, received_bytes[0], received_bytes[1], received_bytes[2]);
        if (irq != 1'b0) $fatal(1, "IRQ must remain disabled by CTRL[1]=0");

        $display("I2C_MASTER_V2_TB_PASS starts=%0d stops=%0d read=%h",
                 start_count, stop_count, 8'h3c);
        $finish;
    end
endmodule
