`timescale 1 ns / 1 ps

`include "../core/defines.v"

// APB-register-controlled, single-master I2C controller.
//
// Register map (byte offsets):
//   0x00 CTRL      [0] enable, [1] done IRQ enable
//   0x04 DATA      write TX byte / read RX byte
//   0x08 CMD       [0] START [1] STOP [2] WRITE [3] READ [4] NACK-after-read
//   0x0c STATUS    [0] busy [1] done [2] ack_error [3] SCL [4] SDA
//                   [5] bus_active [6] cmd_error
//   0x10 PRESCALE  half-period divider (SCL = clk / (2 * (PRESCALE + 1)))
//
// A command executes one byte operation.  After a command without STOP the
// controller enters HOLD_LOW (SCL low, SDA released), so software can issue
// another WRITE/READ, a repeated START, or STOP-only without releasing bus
// ownership.  This controller is deliberately single-master and does not yet
// implement clock stretching or input synchronisation/filtering.
module i2c_master(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    output reg[`MemBus] data_o,
    inout wire scl,
    inout wire sda,
    output wire irq_o
);
    localparam [3:0] ST_IDLE          = 4'd0;
    localparam [3:0] ST_START_A       = 4'd1;
    localparam [3:0] ST_START_B       = 4'd2;
    localparam [3:0] ST_WRITE_LOW     = 4'd3;
    localparam [3:0] ST_WRITE_HIGH    = 4'd4;
    localparam [3:0] ST_ACK_LOW       = 4'd5;
    localparam [3:0] ST_ACK_HIGH      = 4'd6;
    localparam [3:0] ST_READ_LOW      = 4'd7;
    localparam [3:0] ST_READ_HIGH     = 4'd8;
    localparam [3:0] ST_RACK_LOW      = 4'd9;
    localparam [3:0] ST_RACK_HIGH     = 4'd10;
    localparam [3:0] ST_STOP_A        = 4'd11;
    localparam [3:0] ST_STOP_B        = 4'd12;
    localparam [3:0] ST_STOP_C        = 4'd13;
    localparam [3:0] ST_HOLD_LOW      = 4'd14;
    localparam [3:0] ST_RESTART_RAISE = 4'd15;

    reg[31:0] ctrl_r;
    reg[15:0] prescale_r;
    reg[15:0] div_count_r;
    reg[3:0] state_r;
    reg busy_r;
    reg done_r;
    reg ack_error_r;
    reg cmd_error_r;
    reg bus_active_r;
    reg[7:0] data_r;
    reg[7:0] tx_data_r;
    reg[7:0] rx_data_r;
    reg[2:0] bit_index_r;
    reg op_write_r;
    reg op_read_r;
    reg stop_r;
    reg nack_r;

    reg scl_low_r;
    reg sda_low_r;
    wire scl_i = scl;
    wire sda_i = sda;
    wire tick = (div_count_r >= prescale_r);

    wire cmd_start = data_i[0];
    wire cmd_stop  = data_i[1];
    wire cmd_write = data_i[2];
    wire cmd_read  = data_i[3];
    wire cmd_nack  = data_i[4];
    wire cmd_has_action = cmd_start || cmd_stop || cmd_write || cmd_read;
    wire cmd_is_legal = cmd_has_action &&
                        !(cmd_write && cmd_read) &&
                        (!cmd_nack || cmd_read) &&
                        (cmd_start ? (cmd_write || cmd_read || !cmd_stop) :
                                     (bus_active_r && (cmd_write || cmd_read || cmd_stop)));

    assign scl = scl_low_r ? 1'b0 : 1'bz;
    assign sda = sda_low_r ? 1'b0 : 1'bz;
    assign irq_o = done_r && ctrl_r[1];

    always @ (*) begin
        scl_low_r = 1'b0;
        sda_low_r = 1'b0;
        case (state_r)
            ST_START_A:       begin sda_low_r = 1'b1; end
            ST_START_B:       begin scl_low_r = 1'b1; sda_low_r = 1'b1; end
            ST_WRITE_LOW:     begin scl_low_r = 1'b1; sda_low_r = ~tx_data_r[bit_index_r]; end
            ST_WRITE_HIGH:    begin sda_low_r = ~tx_data_r[bit_index_r]; end
            ST_ACK_LOW:       begin scl_low_r = 1'b1; end
            ST_ACK_HIGH:      begin end
            ST_READ_LOW:      begin scl_low_r = 1'b1; end
            ST_READ_HIGH:     begin end
            ST_RACK_LOW:      begin scl_low_r = 1'b1; sda_low_r = ~nack_r; end
            ST_RACK_HIGH:     begin sda_low_r = ~nack_r; end
            ST_STOP_A:        begin scl_low_r = 1'b1; sda_low_r = 1'b1; end
            ST_STOP_B:        begin sda_low_r = 1'b1; end
            ST_HOLD_LOW:      begin scl_low_r = 1'b1; end
            default:          begin end
        endcase
    end

    always @ (*) begin
        case (addr_i[5:2])
            4'h0: data_o = ctrl_r;
            // DATA reads return the most recently received byte. DATA writes
            // are retained in data_r and consumed by a later WRITE command.
            4'h1: data_o = {24'h0, rx_data_r};
            4'h3: data_o = {25'h0, cmd_error_r, bus_active_r, sda_i, scl_i,
                             ack_error_r, done_r, busy_r};
            4'h4: data_o = {16'h0, prescale_r};
            default: data_o = `ZeroWord;
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ctrl_r       <= 32'h0;
            prescale_r   <= 16'd249;
            div_count_r  <= 16'd0;
            state_r      <= ST_IDLE;
            busy_r       <= 1'b0;
            done_r       <= 1'b0;
            ack_error_r  <= 1'b0;
            cmd_error_r  <= 1'b0;
            bus_active_r <= 1'b0;
            data_r       <= 8'h0;
            tx_data_r    <= 8'h0;
            rx_data_r    <= 8'h0;
            bit_index_r  <= 3'd7;
            op_write_r   <= 1'b0;
            op_read_r    <= 1'b0;
            stop_r       <= 1'b0;
            nack_r       <= 1'b0;
        end else begin
            if (we_i && addr_i[5:2] == 4'h0) begin
                ctrl_r <= data_i;
            end
            if (we_i && addr_i[5:2] == 4'h4) begin
                prescale_r <= data_i[15:0];
            end
            if (we_i && addr_i[5:2] == 4'h1) begin
                data_r <= data_i[7:0];
            end

            if (we_i && addr_i[5:2] == 4'h2) begin
                if (busy_r || !ctrl_r[0] || !cmd_is_legal) begin
                    cmd_error_r <= 1'b1;
                end else begin
                    busy_r      <= 1'b1;
                    done_r      <= 1'b0;
                    ack_error_r <= 1'b0;
                    cmd_error_r <= 1'b0;
                    tx_data_r   <= data_r;
                    op_write_r  <= cmd_write;
                    op_read_r   <= cmd_read;
                    stop_r      <= cmd_stop;
                    nack_r      <= cmd_nack;
                    bit_index_r <= 3'd7;
                    if (cmd_start) begin
                        bus_active_r <= 1'b1;
                        state_r <= bus_active_r ? ST_RESTART_RAISE : ST_START_A;
                    end else if (cmd_write) begin
                        state_r <= ST_WRITE_LOW;
                    end else if (cmd_read) begin
                        state_r <= ST_READ_LOW;
                    end else begin
                        state_r <= ST_STOP_A;
                    end
                end
            end else if (busy_r) begin
                if (tick) begin
                    div_count_r <= 16'd0;
                    case (state_r)
                        ST_START_A: state_r <= ST_START_B;
                        ST_RESTART_RAISE: state_r <= ST_START_A;
                        ST_START_B: begin
                            bit_index_r <= 3'd7;
                            if (op_write_r) state_r <= ST_WRITE_LOW;
                            else if (op_read_r) state_r <= ST_READ_LOW;
                            else if (stop_r) state_r <= ST_STOP_A;
                            else begin busy_r <= 1'b0; done_r <= 1'b1; state_r <= ST_HOLD_LOW; end
                        end
                        ST_WRITE_LOW: state_r <= ST_WRITE_HIGH;
                        ST_WRITE_HIGH: begin
                            if (bit_index_r == 0) state_r <= ST_ACK_LOW;
                            else begin bit_index_r <= bit_index_r - 1'b1; state_r <= ST_WRITE_LOW; end
                        end
                        ST_ACK_LOW: state_r <= ST_ACK_HIGH;
                        ST_ACK_HIGH: begin
                            if (sda_i != 1'b0) ack_error_r <= 1'b1;
                            if (stop_r) state_r <= ST_STOP_A;
                            else begin busy_r <= 1'b0; done_r <= 1'b1; state_r <= ST_HOLD_LOW; end
                        end
                        ST_READ_LOW: state_r <= ST_READ_HIGH;
                        ST_READ_HIGH: begin
                            rx_data_r[bit_index_r] <= sda_i;
                            if (bit_index_r == 0) state_r <= ST_RACK_LOW;
                            else begin bit_index_r <= bit_index_r - 1'b1; state_r <= ST_READ_LOW; end
                        end
                        ST_RACK_LOW: state_r <= ST_RACK_HIGH;
                        ST_RACK_HIGH: begin
                            if (stop_r) state_r <= ST_STOP_A;
                            else begin busy_r <= 1'b0; done_r <= 1'b1; state_r <= ST_HOLD_LOW; end
                        end
                        ST_STOP_A: state_r <= ST_STOP_B;
                        ST_STOP_B: state_r <= ST_STOP_C;
                        ST_STOP_C: begin
                            busy_r       <= 1'b0;
                            done_r       <= 1'b1;
                            bus_active_r <= 1'b0;
                            state_r      <= ST_IDLE;
                        end
                        default: begin
                            busy_r       <= 1'b0;
                            bus_active_r <= 1'b0;
                            state_r      <= ST_IDLE;
                        end
                    endcase
                end else begin
                    div_count_r <= div_count_r + 1'b1;
                end
            end else begin
                div_count_r <= 16'd0;
            end
        end
    end
endmodule
