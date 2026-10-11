`timescale 1ns/1ps

module tb_status_osd_24;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg hs = 1'b0;
    reg vs = 1'b1;
    reg de = 1'b0;
    reg [23:0] rgb_in = 24'h123456;
    reg [1:0] active_index = 2'd1;
    reg auto_enabled = 1'b1;
    reg [3:0] state_code = 4'd2;
    wire [23:0] rgb_out;
    wire osd_active;
    integer i;
    reg saw_osd;

    always #20 clk = ~clk;

    status_osd_24 dut (
        .clk(clk), .rst(rst), .hs(hs), .vs(vs), .de(de), .rgb_in(rgb_in),
        .active_index(active_index), .auto_enabled(auto_enabled),
        .state_code(state_code), .rgb_out(rgb_out), .osd_active(osd_active)
    );

    initial begin
        repeat (2) @(negedge clk);
        rst = 1'b0;
        saw_osd = 1'b0;
        // Begin a frame and drive the first active row. The first glyph is 2.
        vs = 1'b0;
        @(negedge clk);
        vs = 1'b1;
        repeat (2) @(negedge clk);
        for (i = 0; i < 12; i = i + 1) begin
            de = 1'b1;
            repeat (40) begin
                @(negedge clk);
                if (osd_active)
                    saw_osd = 1'b1;
            end
            de = 1'b0;
            repeat (2) @(negedge clk);
        end
        de = 1'b0;
        repeat (2) @(negedge clk);
        if (!saw_osd || osd_active !== 1'b0 || rgb_out !== rgb_in)
            $fatal(1, "OSD did not return: saw=%b active=%b rgb=%h", saw_osd, osd_active, rgb_out);
        $display("PASS: status OSD frame lock and transparent passthrough");
        $finish;
    end
endmodule
