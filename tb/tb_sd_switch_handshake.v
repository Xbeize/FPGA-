`timescale 1ns/1ps

module tb_sd_switch_handshake;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg black_ready = 1'b0;
    reg write_finish_toggle = 1'b0;
    wire display_valid;
    wire switch_request;
    wire switch_done_toggle;
    wire [1:0] disp_buf_idx;
    integer cycles;

    always #5 clk = ~clk;

    sd_card_bmp #(.CLK_FREQ_HZ(50)) dut (
        .clk(clk), .rst(rst), .key_next(1'b1), .key_auto(1'b1),
        .bmp_width(16'd640), .bmp_height(16'd480),
        .display_valid(display_valid), .state_code(),
        .switch_request(switch_request), .black_ready(black_ready),
        .switch_done_toggle(switch_done_toggle),
        .write_finish_toggle(write_finish_toggle),
        .write_buf_idx(), .disp_buf_idx(disp_buf_idx),
        .write_req(), .write_req_ack(1'b0), .write_en(), .write_data(),
        .SD_nCS(), .SD_DCLK(), .SD_MOSI(), .SD_MISO(1'b1)
    );

    initial begin
        force dut.sd_init_done = 1'b1;
        force dut.bmp_ready = 1'b1;
        force dut.scan_done = 1'b1;
        repeat (3) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        dut.scan_kicked = 1'b1;
        dut.first_image_committed = 1'b1;
        dut.display_valid = 1'b1;
        dut.img_found_count = 3'd2;
        dut.img_sector1 = 32'd100;
        force dut.key_next_press = 1'b1;
        @(negedge clk);
        release dut.key_next_press;
        for (cycles = 0; cycles < 12; cycles = cycles + 1)
            @(negedge clk);
        if (!dut.load_busy || dut.pending_buf_idx != 2'd1)
            $fatal(1, "next frame was not queued to spare buffer");
        write_finish_toggle = 1'b1;
        wait (switch_request);
        repeat (8) @(negedge clk);
        if (disp_buf_idx !== 2'd0 || switch_done_toggle !== 1'b0 || !display_valid)
            $fatal(1, "display switched before black confirmation");
        black_ready = 1'b1;
        wait (switch_done_toggle);
        @(negedge clk);
        if (disp_buf_idx !== 2'd1 || switch_request !== 1'b0 || dut.load_busy)
            $fatal(1, "buffer did not commit exactly at black confirmation");
        black_ready = 1'b0;
        repeat (8) @(negedge clk);
        if (switch_done_toggle !== 1'b1)
            $fatal(1, "commit toggled more than once");
        $display("PASS: loaded frame waits for black confirmation and commits once");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "switch handshake timed out");
    end
endmodule
