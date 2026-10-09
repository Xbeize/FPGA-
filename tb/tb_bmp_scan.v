`timescale 1ns/1ps

module tb_bmp_scan;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg scan_start = 1'b0;
    reg sd_sec_read_data_valid = 1'b0;
    reg sd_sec_read_end = 1'b0;
    reg [7:0] sd_sec_read_data = 8'd0;
    wire ready;
    wire scan_done;
    wire scan_found_valid;
    wire [31:0] scan_found_sector;
    wire [2:0] scan_found_total;
    wire [31:0] sd_sec_read_addr;
    integer index;

    always #5 clk = ~clk;

    bmp_read dut (
        .clk(clk), .rst(rst), .ready(ready),
        .scan_start(scan_start), .scan_start_sector(32'd3),
        .scan_max_sector(32'd3), .scan_target_count(3'd1),
        .scan_done(scan_done), .scan_found_valid(scan_found_valid),
        .scan_found_sector(scan_found_sector), .scan_found_total(scan_found_total),
        .load_start(1'b0), .load_abort(1'b0), .load_sector(32'd0),
        .sd_init_done(1'b1), .state_code(),
        .bmp_width(16'd640), .bmp_height(16'd480),
        .write_req(), .write_req_ack(1'b0),
        .sd_sec_read(), .sd_sec_read_addr(sd_sec_read_addr),
        .sd_sec_read_data(sd_sec_read_data),
        .sd_sec_read_data_valid(sd_sec_read_data_valid),
        .sd_sec_read_end(sd_sec_read_end),
        .bmp_data_wr_en(), .bmp_data()
    );

    function [7:0] header_byte;
        input integer byte_index;
        input integer valid_header;
        begin
            case (byte_index)
                0:  header_byte = valid_header ? 8'h42 : 8'h00;
                1:  header_byte = 8'h4d;
                2:  header_byte = 8'he8;
                3:  header_byte = 8'h03;
                18: header_byte = 8'h80;
                19: header_byte = 8'h02;
                22: header_byte = 8'he0;
                23: header_byte = 8'h01;
                28: header_byte = 8'h18;
                default: header_byte = 8'h00;
            endcase
        end
    endfunction

    task run_scan;
        input integer valid_header;
        begin
            rst = 1'b1;
            repeat (2) @(negedge clk);
            rst = 1'b0;
            @(negedge clk) scan_start = 1'b1;
            @(negedge clk) scan_start = 1'b0;
            repeat (2) @(negedge clk);
            for (index = 0; index < 34; index = index + 1) begin
                sd_sec_read_data = header_byte(index, valid_header);
                sd_sec_read_data_valid = 1'b1;
                @(negedge clk);
                sd_sec_read_data_valid = 1'b0;
                @(negedge clk);
            end
            repeat (3) @(negedge clk);
            sd_sec_read_end = 1'b1;
            @(posedge clk);
            #1;
            if (!scan_done || scan_found_valid !== valid_header[0] ||
                scan_found_total !== valid_header[2:0])
                $fatal(1, "scan mismatch valid=%0d done=%b found=%b total=%0d",
                       valid_header, scan_done, scan_found_valid, scan_found_total);
            if (valid_header && scan_found_sector !== 32'd3)
                $fatal(1, "wrong BMP sector");
            @(negedge clk) sd_sec_read_end = 1'b0;
        end
    endtask

    initial begin
        run_scan(1);
        run_scan(0);
        $display("PASS: registered BMP header match accepts valid and rejects invalid sectors");
        $finish;
    end
endmodule
