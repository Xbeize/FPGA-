`timescale 1ns/1ps

module tb_frame_fade_control;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg vs = 1'b0;
    reg player_active = 1'b1;
    reg request = 1'b0;
    reg done_toggle = 1'b0;
    wire black_ready;
    wire [4:0] brightness;
    integer step;
    integer transition;

    always #20 clk = ~clk;

    frame_fade_control dut (
        .pixel_clk(clk), .rst(rst), .vs(vs), .player_active(player_active),
        .switch_request(request), .switch_done_toggle(done_toggle),
        .black_ready(black_ready), .brightness(brightness)
    );

    task frame;
        begin
            @(negedge clk) vs = 1'b1;
            @(negedge clk) vs = 1'b0;
            repeat (8) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 1'b0;
        if (brightness !== 5'd16) $fatal(1, "not initially bright");
        for (transition = 0; transition < 2; transition = transition + 1) begin
            request = 1'b1;
            repeat (4) @(negedge clk);
            for (step = 15; step >= 0; step = step - 1) begin
                frame();
                if (brightness !== step || black_ready !== (step == 0))
                    $fatal(1, "fade-out step %0d level=%0d ack=%b",
                           step, brightness, black_ready);
            end
            repeat (6) @(negedge clk);
            if (brightness !== 5'd0) $fatal(1, "black hold lost");
            done_toggle = ~done_toggle;
            request = 1'b0;
            repeat (4) @(negedge clk);
            if (black_ready !== 1'b0) $fatal(1, "ack not cleared");
            frame();
            frame();
            if (brightness !== 5'd0) $fatal(1, "prefetch blank frames missing");
            for (step = 1; step <= 16; step = step + 1) begin
                frame();
                if (brightness !== step)
                    $fatal(1, "fade-in step %0d level=%0d", step, brightness);
            end
            frame();
            if (brightness !== 5'd16) $fatal(1, "not idle after fade-in");
        end
        request = 1'b1;
        repeat (4) @(negedge clk);
        frame();
        player_active = 1'b0;
        @(negedge clk);
        if (brightness !== 5'd16 || black_ready !== 1'b0)
            $fatal(1, "inactive player did not clear fade");
        $display("PASS: two frame-aligned fade and switch handshakes");
        $finish;
    end
endmodule
