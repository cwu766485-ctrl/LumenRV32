`timescale 1 ns / 1 ps

/*
Copyright 2020 Blue Liang, liangkangnan@163.com

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Transmit side of a four-phase full handshake.
module full_handshake_tx #(
    parameter DW = 32
)(

    input wire clk,
    input wire rst_n,

    input wire ack_i,
    input wire req_i,
    input wire[DW - 1:0] req_data_i,

    output wire idle_o,
    output wire req_o,
    output wire[DW - 1:0] req_data_o

    );

    localparam STATE_IDLE = 2'b00;
    localparam STATE_WAIT_ACK = 2'b01;
    localparam STATE_WAIT_ACK_DROP = 2'b10;

    reg[1:0] state;
    reg ack_sync_d;
    reg ack_sync;
    reg idle_r;
    reg req_r;
    reg[DW - 1:0] req_data_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_sync_d <= 1'b0;
            ack_sync <= 1'b0;
        end else begin
            ack_sync_d <= ack_i;
            ack_sync <= ack_sync_d;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            idle_r <= 1'b1;
            req_r <= 1'b0;
            req_data_r <= {DW{1'b0}};
        end else begin
            case (state)
                STATE_IDLE: begin
                    idle_r <= 1'b1;
                    req_r <= 1'b0;
                    if (req_i == 1'b1) begin
                        idle_r <= 1'b0;
                        req_r <= 1'b1;
                        req_data_r <= req_data_i;
                        state <= STATE_WAIT_ACK;
                    end
                end
                STATE_WAIT_ACK: begin
                    if (ack_sync == 1'b1) begin
                        req_r <= 1'b0;
                        state <= STATE_WAIT_ACK_DROP;
                    end
                end
                STATE_WAIT_ACK_DROP: begin
                    if (ack_sync == 1'b0) begin
                        idle_r <= 1'b1;
                        req_data_r <= {DW{1'b0}};
                        state <= STATE_IDLE;
                    end
                end
                default: begin
                    state <= STATE_IDLE;
                    idle_r <= 1'b1;
                    req_r <= 1'b0;
                    req_data_r <= {DW{1'b0}};
                end
            endcase
        end
    end

    assign idle_o = idle_r;
    assign req_o = req_r;
    assign req_data_o = req_data_r;

endmodule
