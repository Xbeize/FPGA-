`timescale 1ns/1ps

module tb_audio_sine_scale;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg tone_enable = 1'b0;
    wire audio_valid;
    wire [23:0] audio_left;
    wire [23:0] audio_right;
    wire acr_valid;
    wire [19:0] acr_cts;
    wire [19:0] acr_n;
    integer sample_count = 0;
    integer acr_count = 0;
    integer waveform_changes = 0;
    integer cycle;
    integer index;
    reg [23:0] previous_sample = 24'd0;
    reg [23:0] phase_samples [0:63];

    always #20 clk = ~clk;

    audio_sine_scale_48k #(.NOTE_HOLD_SAMPLES(8)) dut (
        .clk(clk), .rst(rst), .tone_enable(tone_enable), .audio_valid(audio_valid),
        .audio_left(audio_left), .audio_right(audio_right)
    );
    audio_arc_calculate acr (
        .I_clk(clk), .I_rst(rst), .I_audio_valid(audio_valid),
        .O_acr_valid(acr_valid), .O_acr_cts(acr_cts), .O_acr_n(acr_n)
    );

    initial begin
        for (index = 0; index < 64; index = index + 1) begin
            @(negedge clk);
            dut.phase_accumulator = {index[5:0], 26'd0};
            #1 phase_samples[index] = dut.sample_value;
        end
        if (phase_samples[0] !== 24'h000000 || phase_samples[16] !== 24'h400000 ||
            phase_samples[32] !== 24'h000000 || phase_samples[48] !== 24'hc00000)
            $fatal(1, "wrong sine zero crossings or peaks");
        for (index = 1; index < 32; index = index + 1) begin
            if (phase_samples[index] !== -phase_samples[64-index])
                $fatal(1, "asymmetric sine at phase %0d", index);
        end
        repeat (2) @(negedge clk);
        rst = 1'b0;
        for (cycle = 0; cycle < 600; cycle = cycle + 1) begin
            @(negedge clk);
            if (audio_valid && (audio_left !== 24'd0 || dut.note_index !== 3'd0))
                $fatal(1, "tone played before enable");
        end
        tone_enable = 1'b1;
        for (cycle = 0; cycle < 50002; cycle = cycle + 1) begin
            @(negedge clk);
            if (audio_valid) begin
                sample_count = sample_count + 1;
                if (audio_left !== audio_right ||
                    $signed(audio_left) > 24'sh400000 ||
                    $signed(audio_left) < -24'sh400000)
                    $fatal(1, "invalid stereo sample %h", audio_left);
                if (audio_left !== previous_sample)
                    waveform_changes = waveform_changes + 1;
                previous_sample = audio_left;
                if (dut.note_index !== ((sample_count / 8) % 8))
                    $fatal(1, "wrong note at sample %0d: %0d", sample_count, dut.note_index);
            end
            if (acr_valid) begin
                acr_count = acr_count + 1;
                if (acr_n !== 6144 || acr_cts < 24900 || acr_cts > 25100)
                    $fatal(1, "unexpected ACR N/CTS: %0d/%0d", acr_n, acr_cts);
            end
        end
        if (sample_count != 96 || acr_count != 2 || waveform_changes < 20)
            $fatal(1, "samples=%0d ACR=%0d changes=%0d",
                   sample_count, acr_count, waveform_changes);
        $display("PASS: 48 kHz sine, eight-note cycle, ACR N=6144");
        $finish;
    end
endmodule
