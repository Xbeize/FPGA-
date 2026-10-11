`timescale 1ns/1ps

module frame_fade_control #(
    parameter integer FADE_FRAMES = 16
)(
    input  wire       pixel_clk,
    input  wire       rst,
    input  wire       vs,
    input  wire       player_active,
    input  wire       switch_request,
    input  wire       switch_done_toggle,
    output reg        black_ready,
    output reg  [4:0] brightness
);

localparam [1:0] IDLE = 2'd0, FADE_OUT = 2'd1,
                 WAIT_SWITCH = 2'd2, FADE_IN = 2'd3;
reg [1:0] state;
reg vs_d;
reg [1:0] request_sync;
reg [1:0] done_sync;
reg done_seen;
reg [1:0] blank_frames;
wire frame_start = vs && !vs_d;

always @(posedge pixel_clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        vs_d <= 1'b0;
        request_sync <= 2'b00;
        done_sync <= 2'b00;
        done_seen <= 1'b0;
        blank_frames <= 2'd0;
        black_ready <= 1'b0;
        brightness <= FADE_FRAMES;
    end else begin
        vs_d <= vs;
        request_sync <= {request_sync[0], switch_request};
        done_sync <= {done_sync[0], switch_done_toggle};
        if (!player_active) begin
            state <= IDLE;
            brightness <= FADE_FRAMES;
            black_ready <= 1'b0;
            blank_frames <= 2'd0;
            done_seen <= done_sync[1];
        end else case (state)
            IDLE: if (request_sync[1]) begin
                state <= FADE_OUT;
                brightness <= FADE_FRAMES;
            end
            FADE_OUT: if (frame_start) begin
                if (brightness == 5'd1) begin
                    brightness <= 5'd0;
                    black_ready <= 1'b1;
                    state <= WAIT_SWITCH;
                end else begin
                    brightness <= brightness - 1'b1;
                end
            end
            WAIT_SWITCH: begin
                if (done_sync[1] != done_seen) begin
                    done_seen <= done_sync[1];
                    black_ready <= 1'b0;
                    blank_frames <= 2'd0;
                end else if (!black_ready && frame_start) begin
                    if (blank_frames == 2'd1)
                        state <= FADE_IN;
                    else
                        blank_frames <= blank_frames + 1'b1;
                end
            end
            FADE_IN: if (frame_start) begin
                if (brightness == FADE_FRAMES - 1) begin
                    brightness <= FADE_FRAMES;
                    state <= IDLE;
                end else begin
                    brightness <= brightness + 1'b1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
