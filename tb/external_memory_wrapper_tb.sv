`timescale 1ns / 1ps

`include "defines.v"

module external_memory_wrapper_tb;

    reg clk;
    reg rst;

    reg req;
    reg we;
    reg[`MemMaskBus] wmask;
    reg[`MemAddrBus] addr;
    reg[`MemBus] wdata;
    wire[`MemBus] rdata;
    wire ready;

    wire backend_req;
    wire backend_we;
    wire[`MemAddrBus] backend_addr;
    wire[`MemBus] backend_wdata;
    wire[`MemMaskBus] backend_wmask;

    integer cycle_count;

    external_memory_wrapper #(
        .USE_MODEL(1),
        .WAIT_CYCLES(3),
        .DEPTH_WORDS(1024)
    ) dut (
        .clk(clk),
        .rst(rst),
        .req_i(req),
        .we_i(we),
        .wmask_i(wmask),
        .addr_i(addr),
        .data_i(wdata),
        .data_o(rdata),
        .ready_o(ready),
        .backend_req_o(backend_req),
        .backend_we_o(backend_we),
        .backend_addr_o(backend_addr),
        .backend_wdata_o(backend_wdata),
        .backend_wmask_o(backend_wmask),
        .backend_rdata_i(`ZeroWord),
        .backend_ready_i(`False)
    );

    always #10 clk = ~clk;

    task wait_ready;
        begin
            cycle_count = 0;
            while (ready !== 1'b1) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > 16) begin
                    $display("EXTMEM_TB timeout waiting ready");
                    $finish;
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        req = 1'b0;
        we = `WriteDisable;
        wmask = 4'h0;
        addr = `ZeroWord;
        wdata = `ZeroWord;

        repeat (4) @(posedge clk);
        rst = `RstDisable;
        @(posedge clk);

        // full word write
        addr = 32'h3000_0000;
        wdata = 32'h1122_3344;
        wmask = 4'hf;
        we = `WriteEnable;
        req = 1'b1;
        wait_ready();
        repeat (2) @(posedge clk);
        req = 1'b0;
        we = `WriteDisable;

        // readback
        addr = 32'h3000_0000;
        req = 1'b1;
        wait_ready();
        if (rdata !== 32'h1122_3344) begin
            $display("EXTMEM_TB readback mismatch got=0x%08x exp=0x11223344", rdata);
            $finish;
        end
        @(posedge clk);
        req = 1'b0;

        $display("EXTMEM_TB_PASS");
        $finish;
    end

endmodule
