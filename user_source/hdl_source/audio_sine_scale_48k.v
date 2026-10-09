`timescale 1ns/1ps

module audio_sine_scale_48k #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer NOTE_HOLD_SAMPLES = 24_000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        tone_enable,
    output reg         audio_valid,
    output reg [23:0]  audio_left,
    output reg [23:0]  audio_right
);

localparam integer SAMPLE_HZ = 48_000;
localparam integer OUTPUT_GAIN_SHIFT = 2;
reg [31:0] sample_accumulator;
reg [31:0] phase_accumulator;
reg [31:0] note_sample_count;
reg [2:0] note_index;
reg [4:0] quarter_index;
wire [5:0] phase_index = phase_accumulator[31:26];
wire [23:0] magnitude;
wire [23:0] sample_value;

// C4 D4 E4 F4 G4 A4 B4 C5, using the example's 48 kHz phase increments.
function [31:0] note_increment;
    input [2:0] index;
    begin
        case (index)
            3'd0: note_increment = 32'd23409862;
            3'd1: note_increment = 32'd26276681;
            3'd2: note_increment = 32'd29494578;
            3'd3: note_increment = 32'd31248410;
            3'd4: note_increment = 32'd35075155;
            3'd5: note_increment = 32'd39370534;
            3'd6: note_increment = 32'd44191930;
            3'd7: note_increment = 32'd46819716;
        endcase
    end
endfunction

always @(*) begin
    if (phase_index <= 6'd16)
        quarter_index = phase_index[4:0];
    else if (phase_index <= 6'd32)
        quarter_index = 6'd32 - phase_index;
    else if (phase_index <= 6'd48)
        quarter_index = phase_index - 6'd32;
    else
        quarter_index = 7'd64 - {1'b0, phase_index};
end

function [23:0] quarter_sine;
    input [4:0] index;
    begin
        case (index)
            5'd0:  quarter_sine = 24'h000000;
            5'd1:  quarter_sine = 24'h01917a;
            5'd2:  quarter_sine = 24'h031f17;
            5'd3:  quarter_sine = 24'h04a502;
            5'd4:  quarter_sine = 24'h061f79;
            5'd5:  quarter_sine = 24'h078ad7;
            5'd6:  quarter_sine = 24'h08e39e;
            5'd7:  quarter_sine = 24'h0a267a;
            5'd8:  quarter_sine = 24'h0b504f;
            5'd9:  quarter_sine = 24'h0c5e40;
            5'd10: quarter_sine = 24'h0d4db3;
            5'd11: quarter_sine = 24'h0e1c59;
            5'd12: quarter_sine = 24'h0ec836;
            5'd13: quarter_sine = 24'h0f4fa1;
            5'd14: quarter_sine = 24'h0fb14c;
            5'd15: quarter_sine = 24'h0fec47;
            5'd16: quarter_sine = 24'h100000;
            default: quarter_sine = 24'h000000;
        endcase
    end
endfunction

assign magnitude = quarter_sine(quarter_index) << OUTPUT_GAIN_SHIFT;
assign sample_value = phase_index[5] ? -magnitude : magnitude;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sample_accumulator <= 32'd0;
        phase_accumulator <= 32'd0;
        note_sample_count <= 32'd0;
        note_index <= 3'd0;
        audio_valid <= 1'b0;
        audio_left <= 24'd0;
        audio_right <= 24'd0;
    end else begin
        audio_valid <= 1'b0;
        if (sample_accumulator + SAMPLE_HZ >= CLK_HZ) begin
            sample_accumulator <= sample_accumulator + SAMPLE_HZ - CLK_HZ;
            audio_valid <= 1'b1;
            if (!tone_enable) begin
                phase_accumulator <= 32'd0;
                note_sample_count <= 32'd0;
                note_index <= 3'd0;
                audio_left <= 24'd0;
                audio_right <= 24'd0;
            end else begin
                phase_accumulator <= phase_accumulator + note_increment(note_index);
                audio_left <= sample_value;
                audio_right <= sample_value;
                if (note_sample_count == NOTE_HOLD_SAMPLES - 1) begin
                    note_sample_count <= 32'd0;
                    note_index <= note_index + 1'b1;
                end else begin
                    note_sample_count <= note_sample_count + 1'b1;
                end
            end
        end else begin
            sample_accumulator <= sample_accumulator + SAMPLE_HZ;
        end
    end
end

endmodule
