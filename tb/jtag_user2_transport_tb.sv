`timescale 1 ns / 1 ps

// USER2-level end-to-end test.  It intentionally models only the BSCANE3
// scan pins so it can run in XSim without a device primitive model.
module jtag_user2_transport_tb;
    localparam DMI_BITS = 40;
    localparam [5:0] DMSTATUS = 6'h11;
    localparam [5:0] DMCONTROL = 6'h10;
    localparam [5:0] COMMAND = 6'h17;
    localparam [5:0] DATA0 = 6'h04;

    reg cpu_clk = 1'b0;
    reg tck = 1'b0;
    reg arst_n = 1'b0;
    reg sel = 1'b0;
    reg capture = 1'b0;
    reg shift = 1'b0;
    reg update = 1'b0;
    reg tdi = 1'b0;
    wire tdo;
    wire reg_we;
    wire[4:0] reg_addr;
    wire[31:0] reg_wdata;
    wire mem_we;
    wire[31:0] mem_addr;
    wire[31:0] mem_wdata;
    wire op_req;
    wire halt_req;
    wire reset_req;
    integer failures = 0;
    integer op_req_count = 0;

    always #5 cpu_clk = ~cpu_clk;
    always #8.5 tck = ~tck;

    jtag_user2_dmi_transport dut (
        .clk(cpu_clk), .arst_n(arst_n), .tck(tck), .sel_i(sel),
        .capture_i(capture), .shift_i(shift), .update_i(update), .tdi_i(tdi),
        .tdo_o(tdo), .reg_we_o(reg_we), .reg_addr_o(reg_addr),
        .reg_wdata_o(reg_wdata), .reg_rdata_i(32'hA5A55A5A),
        .mem_we_o(mem_we), .mem_addr_o(mem_addr), .mem_wdata_o(mem_wdata),
        .mem_rdata_i(32'h0), .op_req_o(op_req), .halt_req_o(halt_req),
        .reset_req_o(reset_req)
    );

    always @(posedge cpu_clk) if (op_req) op_req_count <= op_req_count + 1;

    function automatic [DMI_BITS-1:0] dmi;
        input [5:0] address;
        input [31:0] data;
        input [1:0] op;
        begin dmi = {address, data, op}; end
    endfunction

    task automatic pulse_tck;
        begin @(negedge tck); @(posedge tck); end
    endtask

    // One complete USER2 DR scan.  DMI is LSB-first, and returned data is
    // captured while shifting the outgoing request.  The final UPDATE occurs
    // after the 40 shifts, just as it does through BSCANE3 USER2.
    task automatic user2_scan;
        input [DMI_BITS-1:0] request;
        output [DMI_BITS-1:0] response;
        integer i;
        begin
            sel = 1'b1;
            capture = 1'b1;
            shift = 1'b0;
            update = 1'b0;
            pulse_tck;
            #1;
            capture = 1'b0;
            shift = 1'b1;
            response = {DMI_BITS{1'b0}};
            for (i = 0; i < DMI_BITS; i = i + 1) begin
                @(negedge tck);
                response[i] = tdo;
                tdi = request[i];
                @(posedge tck);
            end
            #1;
            shift = 1'b0;
            update = 1'b1;
            pulse_tck;
            #1;
            update = 1'b0;
            sel = 1'b0;
            pulse_tck;
        end
    endtask

    task automatic wait_for_halt;
        integer timeout;
        begin
            timeout = 0;
            while (!halt_req && timeout < 200) begin
                @(posedge cpu_clk);
                timeout = timeout + 1;
            end
            if (!halt_req) begin
                $display("USER2_HALT_TIMEOUT");
                failures = failures + 1;
            end
        end
    endtask

    task automatic wait_transport_idle;
        integer timeout;
        begin
            timeout = 0;
            while ((dut.dm_busy || !dut.req_idle) && timeout < 200) begin
                @(posedge tck);
                timeout = timeout + 1;
            end
            if (dut.dm_busy || !dut.req_idle) begin
                $display("USER2_TRANSPORT_IDLE_TIMEOUT busy=%b req_idle=%b",
                         dut.dm_busy, dut.req_idle);
                failures = failures + 1;
            end
        end
    endtask

    task automatic wait_for_resume;
        integer timeout;
        begin
            timeout = 0;
            while (halt_req && timeout < 200) begin
                @(posedge cpu_clk);
                timeout = timeout + 1;
            end
            if (halt_req) begin
                $display("USER2_RESUME_TIMEOUT");
                failures = failures + 1;
            end
        end
    endtask

    reg[DMI_BITS-1:0] scan_response;
    integer requests_before;
    initial begin
        #31 arst_n = 1'b1;
        wait (dut.tck_rst_n && dut.cpu_rst_n);

        // Transport-v16 guard: UPDATE without a matching USER2 CAPTURE must
        // be ignored, even while SEL is asserted.
        requests_before = op_req_count;
        sel = 1'b1;
        update = 1'b1;
        pulse_tck;
        update = 1'b0;
        sel = 1'b0;
        repeat (20) @(posedge cpu_clk);
        if (op_req_count != requests_before || halt_req) begin
            $display("USER2_CAPTURE_GUARD_FAIL op_req=%0d prior=%0d halt=%b",
                     op_req_count, requests_before, halt_req);
            failures = failures + 1;
        end

        // DMSTATUS read, then a NOP scan to retrieve the asynchronous reply.
        user2_scan(dmi(DMSTATUS, 32'h0, 2'b01), scan_response);
        wait_transport_idle;
        requests_before = op_req_count;
        user2_scan(dmi(6'h0, 32'h0, 2'b00), scan_response);
        repeat (20) @(posedge cpu_clk);
        if (op_req_count != requests_before) begin
            $display("USER2_NOP_SUBMIT_FAIL op_req=%0d prior=%0d",
                     op_req_count, requests_before);
            failures = failures + 1;
        end
        if (scan_response !== dmi(DMSTATUS, 32'h00430c82, 2'b00)) begin
            $display("USER2_DMSTATUS_FAIL actual=%h", scan_response);
            failures = failures + 1;
        end
        // The response CDC must finish its ack-low phase before the next
        // DMI request; otherwise jtag_dm's one-entry response sender could
        // lose the second response.
        wait_transport_idle;

        // Halt a selected hart, read x5 through abstract command/DATA0, then
        // resume it.  No DMI memory write, reset request, or Flash operation
        // is part of this closeout test.
        user2_scan(dmi(DMCONTROL, 32'h80010001, 2'b10), scan_response);
        wait_transport_idle;
        wait_for_halt;
        user2_scan(dmi(DMSTATUS, 32'h0, 2'b01), scan_response);
        wait_transport_idle;
        user2_scan(dmi(6'h0, 32'h0, 2'b00), scan_response);
        if (scan_response !== dmi(DMSTATUS, 32'h00430382, 2'b00)) begin
            $display("USER2_HALTED_DMSTATUS_FAIL actual=%h", scan_response);
            failures = failures + 1;
        end
        user2_scan(dmi(COMMAND, 32'h00001005, 2'b10), scan_response);
        wait_transport_idle;
        user2_scan(dmi(DATA0, 32'h0, 2'b01), scan_response);
        wait_transport_idle;
        user2_scan(dmi(6'h0, 32'h0, 2'b00), scan_response);
        if (scan_response !== dmi(DATA0, 32'hA5A55A5A, 2'b00)) begin
            $display("USER2_GPR_READ_FAIL actual=%h", scan_response);
            failures = failures + 1;
        end
        user2_scan(dmi(DMCONTROL, 32'h40010001, 2'b10), scan_response);
        wait_transport_idle;
        wait_for_resume;

        if (failures == 0) begin
            $display("JTAG_USER2_TRANSPORT_TB_PASS");
            $finish;
        end else begin
            $display("JTAG_USER2_TRANSPORT_TB_FAIL failures=%0d", failures);
            $fatal(1);
        end
    end
endmodule
