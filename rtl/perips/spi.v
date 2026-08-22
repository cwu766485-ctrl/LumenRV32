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


// spi master???
module spi(

    input wire clk,
    input wire rst,

    input wire[31:0] data_i,
    input wire[31:0] addr_i,
    input wire we_i,

    output reg[31:0] data_o,

    output reg spi_mosi,             // spi??????????pi?????????
    input wire spi_miso,             // spi??????????pi?????????
    output wire spi_ss,              // spi???????
    output reg spi_clk               // spi??????????????????clk?????

    );


    localparam SPI_CTRL   = 4'h0;    // spi_ctrl???????????
    localparam SPI_DATA   = 4'h4;    // spi_data???????????
    localparam SPI_STATUS = 4'h8;    // spi_status???????????

    // spi????????
    // addr: 0x00
    // [0]: 1: enable, 0: disable
    // [1]: CPOL
    // [2]: CPHA
    // [3]: select slave, 1: select, 0: deselect
    // [15:8]: clk div
    reg[31:0] spi_ctrl;
    // spi????????
    // addr: 0x04
    // [7:0] cmd or inout data
    reg[31:0] spi_data;
    // spi????????
    // addr: 0x08
    // [0]: 1: busy, 0: idle
    reg[31:0] spi_status;

    reg[8:0] clk_cnt;               // ??????
    reg en;                         // ????????????????????????????
    reg[4:0] spi_clk_edge_cnt;      // spi clk?????????
    reg spi_clk_edge_level;         // spi clk?????
    reg[7:0] rdata;                 // ??pi????????????
    reg done;                       // ?????????
    reg[3:0] bit_index;             // ???bit???
    wire[8:0] div_cnt;


    assign spi_ss = ~spi_ctrl[3];   // SPI??????????

    assign div_cnt = spi_ctrl[15:8];// 0: 2?????????????????????6???????2???????????


    // ?????????
    // ?????????????
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            en <= 1'b0;
        end else begin
            if (spi_ctrl[0] == 1'b1) begin
                en <= 1'b1;
            end else if (done == 1'b1) begin
                en <= 1'b0;
            end else begin
                en <= en;
            end
        end
    end

    // ??????????????
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            clk_cnt <= 9'h0;
        end else if (en == 1'b1) begin
            if (clk_cnt == div_cnt) begin
                clk_cnt <= 9'h0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= 9'h0;
        end
    end

    // ??pi clk????????
    // ????????????????????????????
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            spi_clk_edge_cnt <= 5'h0;
            spi_clk_edge_level <= 1'b0;
        end else if (en == 1'b1) begin
            // ???????????
            if (clk_cnt == div_cnt) begin
                if (spi_clk_edge_cnt == 5'd17) begin
                    spi_clk_edge_cnt <= 5'h0;
                    spi_clk_edge_level <= 1'b0;
                end else begin
                    spi_clk_edge_cnt <= spi_clk_edge_cnt + 1'b1;
                    spi_clk_edge_level <= 1'b1;
                end
            end else begin
                spi_clk_edge_level <= 1'b0;
            end
        end else begin
            spi_clk_edge_cnt <= 5'h0;
            spi_clk_edge_level <= 1'b0;
        end
    end

    // bit???
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            spi_clk <= 1'b0;
            rdata <= 8'h0;
            spi_mosi <= 1'b0;
            bit_index <= 4'h0;
        end else begin
            if (en) begin
                if (spi_clk_edge_level == 1'b1) begin
                    case (spi_clk_edge_cnt)
                        // ???????????
                        1, 3, 5, 7, 9, 11, 13, 15: begin
                            spi_clk <= ~spi_clk;
                            if (spi_ctrl[2] == 1'b1) begin
                                spi_mosi <= spi_data[bit_index];   // ???1bit???
                                bit_index <= bit_index - 1'b1;
                            end else begin
                                rdata <= {rdata[6:0], spi_miso};   // ??bit???
                            end
                        end
                        // ???????????
                        2, 4, 6, 8, 10, 12, 14, 16: begin
                            spi_clk <= ~spi_clk;
                            if (spi_ctrl[2] == 1'b1) begin
                                rdata <= {rdata[6:0], spi_miso};   // ??bit???
                            end else begin
                                spi_mosi <= spi_data[bit_index];   // ???1bit???
                                bit_index <= bit_index - 1'b1;
                            end
                        end
                        17: begin
                            spi_clk <= spi_ctrl[1];
                        end
                    endcase
                end
            end else begin
                // ???????
                spi_clk <= spi_ctrl[1];
                if (spi_ctrl[2] == 1'b0) begin
                    spi_mosi <= spi_data[7];           // ???????????
                    bit_index <= 4'h6;
                end else begin
                    bit_index <= 4'h7;
                end
            end
        end
    end

    // ??????(???)???
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            done <= 1'b0;
        end else begin
            if (en && spi_clk_edge_cnt == 5'd17) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // write reg
    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            spi_ctrl <= 32'h0;
            spi_data <= 32'h0;
            spi_status <= 32'h0;
        end else begin
            spi_status[0] <= en;
            if (we_i == 1'b1) begin
                case (addr_i[3:0])
                    SPI_CTRL: begin
                        spi_ctrl <= data_i;
                    end
                    SPI_DATA: begin
                        spi_data <= data_i;
                    end
                    default: begin

                    end
                endcase
            end else begin
                spi_ctrl[0] <= 1'b0;
                // ???????????????????
                if (done == 1'b1) begin
                    spi_data <= {24'h0, rdata};
                end
            end
        end
    end

    // read reg
    always @ (*) begin
        if (rst == 1'b0) begin
            data_o = 32'h0;
        end else begin
            case (addr_i[3:0])
                SPI_CTRL: begin
                    data_o = spi_ctrl;
                end
                SPI_DATA: begin
                    data_o = spi_data;
                end
                SPI_STATUS: begin
                    data_o = spi_status;
                end
                default: begin
                    data_o = 32'h0;
                end
            endcase
        end
    end

endmodule


