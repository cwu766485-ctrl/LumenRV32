`timescale 1 ns / 1 ps

`include "../rtl/core/defines.v"

module axi4_extmem_bridge_tb;

    reg clk;
    reg rst;

    reg req;
    reg we;
    reg[31:0] addr;
    reg[31:0] wdata;
    reg[3:0] wmask;
    wire[31:0] rdata;
    wire ready;

    wire[31:0] m_axi_awaddr;
    wire[7:0] m_axi_awlen;
    wire[2:0] m_axi_awsize;
    wire[1:0] m_axi_awburst;
    wire m_axi_awvalid;
    reg m_axi_awready;

    wire[31:0] m_axi_wdata;
    wire[3:0] m_axi_wstrb;
    wire m_axi_wlast;
    wire m_axi_wvalid;
    reg m_axi_wready;

    reg[1:0] m_axi_bresp;
    reg m_axi_bvalid;
    wire m_axi_bready;

    wire[31:0] m_axi_araddr;
    wire[7:0] m_axi_arlen;
    wire[2:0] m_axi_arsize;
    wire[1:0] m_axi_arburst;
    wire m_axi_arvalid;
    reg m_axi_arready;

    reg[31:0] m_axi_rdata;
    reg[1:0] m_axi_rresp;
    reg m_axi_rlast;
    reg m_axi_rvalid;
    wire m_axi_rready;

    reg[31:0] mem[0:255];
    integer cycle_count;
    integer op_count;
    integer seed;
    integer i;
    integer random_mask;
    reg aw_seen_r;
    reg w_seen_r;
    reg[31:0] awaddr_seen_r;
    reg[31:0] wdata_seen_r;
    reg[3:0] wstrb_seen_r;
    integer b_delay_r;
    reg read_pending_r;
    reg[31:0] read_addr_r;
    reg[31:0] read_data_r;
    integer r_delay_r;

    function [31:0] apply_mask;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] mask;
        begin
            apply_mask = old_word;
            if (mask[0]) apply_mask[7:0] = new_word[7:0];
            if (mask[1]) apply_mask[15:8] = new_word[15:8];
            if (mask[2]) apply_mask[23:16] = new_word[23:16];
            if (mask[3]) apply_mask[31:24] = new_word[31:24];
        end
    endfunction

    axi4_extmem_bridge dut(
        .clk(clk),
        .rst(rst),
        .req_i(req),
        .we_i(we),
        .addr_i(addr),
        .data_i(wdata),
        .wmask_i(wmask),
        .data_o(rdata),
        .ready_o(ready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    always #5 clk = ~clk;

    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count > 4000) begin
                $display("AXI4_EXTMEM_BRIDGE_TB_TIMEOUT state=%0d req=%0d ready=%0d awv=%0d awr=%0d wv=%0d wr=%0d bv=%0d br=%0d arv=%0d arr=%0d rv=%0d rr=%0d",
                    dut.state_r, req, ready, m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready,
                    m_axi_bvalid, m_axi_bready, m_axi_arvalid, m_axi_arready, m_axi_rvalid, m_axi_rready);
                $finish(1);
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            m_axi_awready <= 1'b0;
            m_axi_wready <= 1'b0;
            m_axi_bresp <= 2'b00;
            m_axi_bvalid <= 1'b0;
            m_axi_arready <= 1'b0;
            m_axi_rdata <= 32'h0;
            m_axi_rresp <= 2'b00;
            m_axi_rlast <= 1'b0;
            m_axi_rvalid <= 1'b0;
            aw_seen_r <= 1'b0;
            w_seen_r <= 1'b0;
            awaddr_seen_r <= 32'h0;
            wdata_seen_r <= 32'h0;
            wstrb_seen_r <= 4'h0;
            b_delay_r <= 0;
            read_pending_r <= 1'b0;
            read_addr_r <= 32'h0;
            read_data_r <= 32'h0;
            r_delay_r <= 0;
        end else begin
            m_axi_awready <= 1'b0;
            m_axi_wready <= 1'b0;
            m_axi_arready <= 1'b0;

            if (!aw_seen_r && m_axi_awvalid && (($urandom() & 2'h3) != 0)) begin
                m_axi_awready <= 1'b1;
                aw_seen_r <= 1'b1;
                awaddr_seen_r <= m_axi_awaddr;
            end

            if (!w_seen_r && m_axi_wvalid && (($urandom() & 2'h3) != 2'h1)) begin
                m_axi_wready <= 1'b1;
                w_seen_r <= 1'b1;
                wdata_seen_r <= m_axi_wdata;
                wstrb_seen_r <= m_axi_wstrb;
                if (m_axi_wlast !== 1'b1) begin
                    $display("AXI4_EXTMEM_BRIDGE_TB_FAIL write beat missing wlast");
                    $finish(1);
                end
            end

            if (aw_seen_r && w_seen_r && !m_axi_bvalid && b_delay_r == 0) begin
                mem[awaddr_seen_r[9:2]] <= apply_mask(mem[awaddr_seen_r[9:2]], wdata_seen_r, wstrb_seen_r);
                b_delay_r <= ($urandom() % 4) + 1;
            end else if (b_delay_r > 1 && !m_axi_bvalid) begin
                b_delay_r <= b_delay_r - 1;
            end else if (b_delay_r == 1 && !m_axi_bvalid) begin
                m_axi_bvalid <= 1'b1;
                b_delay_r <= 0;
            end

            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
                aw_seen_r <= 1'b0;
                w_seen_r <= 1'b0;
            end

            if (!read_pending_r && !m_axi_rvalid && m_axi_arvalid && (($urandom() & 2'h3) != 2'h2)) begin
                m_axi_arready <= 1'b1;
                read_pending_r <= 1'b1;
                read_addr_r <= m_axi_araddr;
                read_data_r <= mem[m_axi_araddr[9:2]];
                r_delay_r <= ($urandom() % 4) + 1;
            end

            if (read_pending_r && !m_axi_rvalid) begin
                if (r_delay_r > 1) begin
                    r_delay_r <= r_delay_r - 1;
                end else if (r_delay_r == 1) begin
                    m_axi_rdata <= read_data_r;
                    m_axi_rvalid <= 1'b1;
                    m_axi_rlast <= 1'b1;
                    r_delay_r <= 0;
                end
            end

            if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast <= 1'b0;
                read_pending_r <= 1'b0;
            end
        end
    end

    task automatic bridge_write;
        input [31:0] wr_addr;
        input [31:0] wr_data;
        input [3:0] wr_mask;
        input integer hold_extra_cycles;
        begin
            @(negedge clk);
            req = 1'b1;
            we = `WriteEnable;
            addr = wr_addr;
            wdata = wr_data;
            wmask = wr_mask;
            while (ready !== `True) begin
                @(posedge clk);
            end
            repeat (hold_extra_cycles) @(posedge clk);
            @(negedge clk);
            req = 1'b0;
            we = `WriteDisable;
            addr = 32'h0;
            wdata = 32'h0;
            wmask = 4'h0;
        end
    endtask

    task automatic bridge_read;
        input [31:0] rd_addr;
        input [31:0] expected;
        input integer hold_extra_cycles;
        begin
            @(negedge clk);
            req = 1'b1;
            we = `WriteDisable;
            addr = rd_addr;
            wdata = 32'h0;
            wmask = 4'h0;
            while (ready !== `True) begin
                @(posedge clk);
            end
            #1;
            if (rdata !== expected) begin
                $display("AXI4_EXTMEM_BRIDGE_TB_FAIL read addr=%h got=%h expect=%h", rd_addr, rdata, expected);
                $finish(1);
            end
            repeat (hold_extra_cycles) @(posedge clk);
            @(negedge clk);
            req = 1'b0;
            addr = 32'h0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstEnable;
        req = 1'b0;
        we = `WriteDisable;
        addr = 32'h0;
        wdata = 32'h0;
        wmask = 4'h0;
        cycle_count = 0;
        op_count = 0;
        seed = 32'h1bad_f00d;
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 32'h1000_0000 + i;
        end

        repeat (8) @(posedge clk);
        rst = `RstDisable;
        repeat (4) @(posedge clk);

        bridge_write(32'h3000_0040, 32'h1122_3344, 4'hf, 1);
        op_count = op_count + 1;
        bridge_read(32'h3000_0040, 32'h1122_3344, 0);
        op_count = op_count + 1;

        bridge_write(32'h3000_0040, 32'hdead_beef, 4'b0101, 0);
        op_count = op_count + 1;
        bridge_read(32'h3000_0040, 32'h11ad_33ef, 1);
        op_count = op_count + 1;

        for (i = 0; i < 24; i = i + 1) begin
            reg [31:0] rand_addr;
            reg [31:0] rand_data;
            reg [3:0] rand_wmask;
            reg [31:0] expected_word;
            rand_addr = 32'h3000_0000 + (($urandom() % 64) << 2);
            rand_data = $urandom();
            random_mask = $urandom() & 4'hf;
            rand_wmask = (random_mask == 0) ? 4'hf : random_mask[3:0];
            if (($urandom() & 1'b1) == 1'b1) begin
                expected_word = apply_mask(mem[rand_addr[9:2]], rand_data, rand_wmask);
                bridge_write(rand_addr, rand_data, rand_wmask, $urandom() & 1'b1);
                mem[rand_addr[9:2]] = expected_word;
            end else begin
                bridge_read(rand_addr, mem[rand_addr[9:2]], $urandom() & 1'b1);
            end
            op_count = op_count + 1;
        end

        $display("AXI4_EXTMEM_BRIDGE_TB_PASS ops=%0d seed=0x%08x", op_count, seed);
        $finish;
    end

endmodule
