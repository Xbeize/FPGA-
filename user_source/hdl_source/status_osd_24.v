`timescale 1ns/1ps

// Frame-locked 5x7 status OSD. Coordinates are reconstructed from the
// already-aligned video sync/de bundle, so this block adds no pipeline delay.
module status_osd_24 #(
    parameter integer OSD_X = 8,
    parameter integer OSD_Y = 8
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       hs,
    input  wire       vs,
    input  wire       de,
    input  wire [23:0] rgb_in,
    input  wire [1:0] active_index,
    input  wire       auto_enabled,
    input  wire [3:0] state_code,
    output wire [23:0] rgb_out,
    output wire       osd_active
);

reg [10:0] pixel_x;
reg [11:0] pixel_y;
reg de_q;
reg vs_q;
reg [1:0] index_q;
reg auto_q;
reg [3:0] state_q;
wire frame_start = vs_q && !vs;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pixel_x <= 11'd0;
        pixel_y <= 12'd0;
        de_q <= 1'b0;
        vs_q <= 1'b1;
        index_q <= 2'd0;
        auto_q <= 1'b0;
        state_q <= 4'd0;
    end else begin
        de_q <= de;
        vs_q <= vs;
        if (!vs) begin
            pixel_x <= 11'd0;
            pixel_y <= 12'd0;
        end else if (de) begin
            if (!de_q)
                pixel_x <= 11'd1;
            else
                pixel_x <= pixel_x + 1'b1;
        end else if (de_q) begin
            pixel_x <= 11'd0;
            pixel_y <= pixel_y + 1'b1;
        end
        if (frame_start) begin
            index_q <= active_index;
            auto_q <= auto_enabled;
            state_q <= state_code;
        end
    end
end

function [4:0] font_row;
    input [3:0] value;
    input [2:0] row;
    begin
        case (value)
            4'h0: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b10001;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
            4'h1: case(row) 0:font_row=5'b00100;1:font_row=5'b01100;2:font_row=5'b00100;3:font_row=5'b00100;4:font_row=5'b00100;5:font_row=5'b00100;default:font_row=5'b11111; endcase
            4'h2: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00001;3:font_row=5'b11111;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b11111; endcase
            4'h3: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
            4'h4: case(row) 0:font_row=5'b10001;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b00001; endcase
            4'h5: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
            4'h6: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
            4'h7: case(row) 0:font_row=5'b11111;1:font_row=5'b00001;2:font_row=5'b00010;3:font_row=5'b00100;4:font_row=5'b01000;5:font_row=5'b01000;default:font_row=5'b01000; endcase
            4'h8: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b11111; endcase
            4'h9: case(row) 0:font_row=5'b11111;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b00001;5:font_row=5'b00001;default:font_row=5'b11111; endcase
            4'ha: case(row) 0:font_row=5'b01110;1:font_row=5'b10001;2:font_row=5'b10001;3:font_row=5'b11111;4:font_row=5'b10001;5:font_row=5'b10001;default:font_row=5'b10001; endcase
            4'he: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b11111; endcase
            4'hf: case(row) 0:font_row=5'b11111;1:font_row=5'b10000;2:font_row=5'b10000;3:font_row=5'b11110;4:font_row=5'b10000;5:font_row=5'b10000;default:font_row=5'b10000; endcase
            default: font_row = 5'b00000;
        endcase
    end
endfunction

reg osd_hit;
reg [3:0] char_value;
reg [2:0] char_row;
reg [4:0] glyph_row;
reg [5:0] local_x;

always @* begin
    osd_hit = 1'b0;
    char_value = 4'h0;
    char_row = pixel_y - OSD_Y;
    glyph_row = 5'b0;
    local_x = pixel_x - OSD_X;
    if (de && pixel_x >= OSD_X && pixel_x < OSD_X + 32 &&
        pixel_y >= OSD_Y && pixel_y < OSD_Y + 8) begin
        case (local_x / 8)
            0: char_value = {2'b00, index_q} + 1'b1;
            1: char_value = auto_q ? 4'ha : 4'he;
            2: char_value = state_q;
            3: char_value = 4'h0;
            default: char_value = 4'h0;
        endcase
        glyph_row = font_row(char_value, char_row);
        if ((local_x % 8) < 5 && char_row < 7)
            osd_hit = glyph_row[4 - (local_x % 8)];
    end
end

assign osd_active = osd_hit;
assign rgb_out = osd_hit ? (state_q == 4'd4 ? 24'hff4444 : 24'hffff00) : rgb_in;

endmodule
