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

// Receive side of a four-phase full handshake.
module full_handshake_rx #(
    parameter DW = 32
)(

    input wire clk,
    input wire rst_n,

    input wire req_i,
    input wire[DW - 1:0] req_data_i,

    output wire ack_o,
    output wire[DW - 1:0] recv_data_o,
    output wire recv_rdy_o

    );

    localparam STATE_IDLE = 1'b0;
    localparam STATE_WAIT_REQ_DROP = 1'b1;

    reg state;
    reg req_sync_d;
    reg req_sync;
    reg ack_r;
    reg recv_rdy_r;
    reg[DW - 1:0] recv_data_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_sync_d <= 1'b0;
            req_sync <= 1'b0;
        end else begin
            req_sync_d <= req_i;
            req_sync <= req_sync_d;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            ack_r <= 1'b0;
            recv_rdy_r <= 1'b0;
            recv_data_r <= {DW{1'b0}};
        end else begin
            recv_rdy_r <= 1'b0;
            case (state)
                STATE_IDLE: begin
                    if (req_sync == 1'b1) begin
                        ack_r <= 1'b1;
                        recv_rdy_r <= 1'b1;
                        recv_data_r <= req_data_i;
                        state <= STATE_WAIT_REQ_DROP;
                    end
                end
                STATE_WAIT_REQ_DROP: begin
                    if (req_sync == 1'b0) begin
                        ack_r <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

    assign ack_o = ack_r;
    assign recv_data_o = recv_data_r;
    assign recv_rdy_o = recv_rdy_r;

endmodule
