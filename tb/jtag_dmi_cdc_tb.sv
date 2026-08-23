`timescale 1 ns / 1 ps

// Asynchronous-clock test for the two DMI handshake channels used by jtag_top.
// TCK and cpu_clk have unrelated phase and period. The test checks that each
// request is delivered once, its 40-bit bundle is intact, and the response
// returns once with the expected payload.
module jtag_dmi_cdc_tb;
    localparam DW = 40;
    localparam [DW-1:0] RESPONSE_XOR = 40'h5A_A55AA55A;

    reg cpu_clk;
    reg jtag_tck;
    reg arst_n;

    reg tck_req_i;
    reg [DW-1:0] tck_req_data_i;
    wire tck_req_idle;
    wire tck_req_o;
    wire [DW-1:0] tck_req_data_o;
    wire cpu_req_ack;
    wire cpu_req_valid;
    wire [DW-1:0] cpu_req_data;

    wire cpu_rsp_req_i;
    wire [DW-1:0] cpu_rsp_data_i;
    wire cpu_rsp_idle;
    wire cpu_rsp_o;
    wire [DW-1:0] cpu_rsp_data_o;
    wire tck_rsp_ack;
    wire tck_rsp_valid;
    wire [DW-1:0] tck_rsp_data;

    wire tck_rst_n;
    wire cpu_rst_n;
    reg [DW-1:0] expected_req [0:3];
    integer cpu_req_count;
    integer tck_rsp_count;
    integer failures;

    // cpu_clk: 100 MHz. TCK: 58.8 MHz with a phase offset from cpu_clk.
    initial begin
        cpu_clk = 1'b0;
        forever #5 cpu_clk = ~cpu_clk;
    end

    initial begin
        jtag_tck = 1'b0;
        #3;
        forever #8.5 jtag_tck = ~jtag_tck;
    end

    jtag_cdc_reset_sync u_tck_reset_sync (
        .clk(jtag_tck), .arst_n(arst_n), .srst_n(tck_rst_n)
    );

    jtag_cdc_reset_sync u_cpu_reset_sync (
        .clk(cpu_clk), .arst_n(arst_n), .srst_n(cpu_rst_n)
    );

    // DMI request: TCK domain -> CPU domain.
    full_handshake_tx #(.DW(DW)) u_req_tx (
        .clk(jtag_tck), .rst_n(tck_rst_n),
        .ack_i(cpu_req_ack), .req_i(tck_req_i), .req_data_i(tck_req_data_i),
        .idle_o(tck_req_idle), .req_o(tck_req_o), .req_data_o(tck_req_data_o)
    );

    full_handshake_rx #(.DW(DW)) u_req_rx (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .req_i(tck_req_o), .req_data_i(tck_req_data_o),
        .ack_o(cpu_req_ack), .recv_data_o(cpu_req_data), .recv_rdy_o(cpu_req_valid)
    );

    // DMI response: CPU domain -> TCK domain.
    assign cpu_rsp_req_i = cpu_req_valid;
    assign cpu_rsp_data_i = cpu_req_data ^ RESPONSE_XOR;

    full_handshake_tx #(.DW(DW)) u_rsp_tx (
        .clk(cpu_clk), .rst_n(cpu_rst_n),
        .ack_i(tck_rsp_ack), .req_i(cpu_rsp_req_i), .req_data_i(cpu_rsp_data_i),
        .idle_o(cpu_rsp_idle), .req_o(cpu_rsp_o), .req_data_o(cpu_rsp_data_o)
    );

    full_handshake_rx #(.DW(DW)) u_rsp_rx (
        .clk(jtag_tck), .rst_n(tck_rst_n),
        .req_i(cpu_rsp_o), .req_data_i(cpu_rsp_data_o),
        .ack_o(tck_rsp_ack), .recv_data_o(tck_rsp_data), .recv_rdy_o(tck_rsp_valid)
    );

    always @(posedge cpu_clk) begin
        if (!cpu_rst_n) begin
            cpu_req_count <= 0;
        end else if (cpu_req_valid) begin
            if (cpu_req_count >= 4 || cpu_req_data !== expected_req[cpu_req_count]) begin
                $display("JTAG_CDC_REQ_MISMATCH index=%0d actual=%h", cpu_req_count, cpu_req_data);
                failures <= failures + 1;
            end
            cpu_req_count <= cpu_req_count + 1;
        end
    end

    always @(posedge jtag_tck) begin
        if (!tck_rst_n) begin
            tck_rsp_count <= 0;
        end else if (tck_rsp_valid) begin
            if (tck_rsp_count >= 4 || tck_rsp_data !== (expected_req[tck_rsp_count] ^ RESPONSE_XOR)) begin
                $display("JTAG_CDC_RSP_MISMATCH index=%0d actual=%h", tck_rsp_count, tck_rsp_data);
                failures <= failures + 1;
            end
            tck_rsp_count <= tck_rsp_count + 1;
        end
    end

    task automatic issue_request(input [DW-1:0] data);
        begin
            while (!tck_req_idle) @(posedge jtag_tck);
            @(negedge jtag_tck);
            tck_req_data_i = data;
            tck_req_i = 1'b1;
            @(negedge jtag_tck);
            tck_req_i = 1'b0;
        end
    endtask

    task automatic wait_response_count(input integer target);
        integer timeout;
        begin
            timeout = 0;
            while (tck_rsp_count < target && timeout < 400) begin
                @(posedge jtag_tck);
                timeout = timeout + 1;
            end
            if (tck_rsp_count < target) begin
                $display("JTAG_CDC_RESPONSE_TIMEOUT target=%0d count=%0d", target, tck_rsp_count);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        arst_n = 1'b0;
        tck_req_i = 1'b0;
        tck_req_data_i = {DW{1'b0}};
        cpu_req_count = 0;
        tck_rsp_count = 0;
        failures = 0;
        expected_req[0] = 40'h04_12345678;
        expected_req[1] = 40'h15_00C0FFEE;
        expected_req[2] = 40'h2A_DEADBEEF;
        expected_req[3] = 40'h3F_13579BDF;

        // Deliberately release reset away from either clock edge.
        #37 arst_n = 1'b1;
        wait (tck_rst_n && cpu_rst_n);

        issue_request(expected_req[0]);
        wait_response_count(1);
        issue_request(expected_req[1]);
        wait_response_count(2);
        issue_request(expected_req[2]);
        wait_response_count(3);
        issue_request(expected_req[3]);
        wait_response_count(4);

        repeat (8) @(posedge jtag_tck);
        if (cpu_req_count != 4 || tck_rsp_count != 4 || !tck_req_idle || !cpu_rsp_idle) begin
            $display("JTAG_CDC_COUNT_OR_IDLE_FAILURE req=%0d rsp=%0d req_idle=%b rsp_idle=%b",
                     cpu_req_count, tck_rsp_count, tck_req_idle, cpu_rsp_idle);
            failures = failures + 1;
        end

        if (failures == 0) begin
            $display("JTAG_DMI_CDC_TB_PASS");
            $finish;
        end else begin
            $display("JTAG_DMI_CDC_TB_FAIL failures=%0d", failures);
            $fatal(1);
        end
    end
endmodule
