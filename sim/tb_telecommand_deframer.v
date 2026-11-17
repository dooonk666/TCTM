`timescale 1ns / 1ps
// Protocol 3.1, tables 1 and 3. Bytes arrive MSB first.
// Only the sync may be inverted: EB90 or 146F. Compile with xvlog -sv.
module tb_telecommand_deframer;
    localparam [63:0] TAIL = 64'hC5C5C5C5C5C5C579;
    localparam [71:0] COMMAND = 72'h7C918C75D7C918C75D;
    reg clk=0, rst=1, rx_valid=0, frame_ready=0;
    reg [7:0] rx_data=0;
    wire rx_ready, frame_valid, frame_error, sync_inverted;
    wire [15:0] frame_address;
    wire [7:0] frame_format;
    wire [9:0] payload_length;
    wire [4095:0] payload_data;
    wire [2:0] frame_error_code;
    integer accepted_frames=0, error_count=0, last_error=0, cases_passed=0;
    reg previous_error=0;
    reg [7:0] formats [0:5];
    integer lengths [0:5];
    integer f, inv, n, old_errors, old_frames, stage;
    always #5 clk = ~clk; // 100 MHz

    telecommand_deframer dut (
        .clk(clk), .rst(rst),
        .rx_valid_i(rx_valid), .rx_data_i(rx_data), .rx_ready_o(rx_ready),
        .frame_valid_o(frame_valid), .frame_ready_i(frame_ready),
        .frame_address_o(frame_address), .frame_format_o(frame_format),
        .payload_length_o(payload_length), .payload_data_o(payload_data),
        .sync_inverted_o(sync_inverted), .frame_error_o(frame_error),
        .frame_error_code_o(frame_error_code)
    );

    // Output handshakes are sampled BEFORE the DUT's NBA updates.
    always @(posedge clk)
        if (!rst && frame_valid && frame_ready)
            accepted_frames = accepted_frames + 1;
    // Registered errors are sampled AFTER NBA, independently of stimulus.
    always @(posedge clk) begin
        #1;
        if (rst) previous_error=0;
        else begin
            if (frame_error === 1'b1) begin
                if (previous_error || frame_valid)
                    $fatal(1, "error pulse too long or error frame published");
                error_count=error_count+1;
                last_error=frame_error_code;
            end
            previous_error=frame_error;
        end
    end

    // Real repeated 36-bit OC command for direct frames. Indirect data includes
    // both syncs and an embedded tail, then position-dependent bytes (also >256).
    function [7:0] body_byte;
        input [7:0] fmt;
        input integer index, seed;
        begin
            if (fmt == 8'h39) body_byte=COMMAND[(8-index)*8 +: 8];
            else if (index == 0) body_byte=8'hEB;
            else if (index == 1) body_byte=8'h90;
            else if (index == 2) body_byte=8'h14;
            else if (index == 3) body_byte=8'h6F;
            else if (index >= 4 && index <= 10) body_byte=8'hC5;
            else if (index == 11) body_byte=8'h79;
            else body_byte=(index*37 + index/256 + seed*19) & 255;
        end
    endfunction

    // Consecutive calls stream at one byte per cycle, obeying ready/valid.
    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk); rx_valid=1; rx_data=value;
            @(posedge clk);
            while (rx_ready !== 1'b1) @(posedge clk);
            #2;
        end
    endtask
    task idle_cycles;
        input integer count;
        integer k;
        begin
            @(negedge clk); rx_valid=0;
            for (k=0; k<count; k=k+1) begin
                rx_data=k[0] ? 8'hEB : 8'h90; // Invalid data must be ignored.
                @(posedge clk); #2;
                @(negedge clk);
            end
        end
    endtask
    task send_header;
        input [15:0] sync_word, address;
        input [7:0] fmt;
        begin
            send_byte(sync_word[15:8]); send_byte(sync_word[7:0]);
            send_byte(address[15:8]); send_byte(address[7:0]); send_byte(fmt);
        end
    endtask
    task send_frame;
        input [15:0] sync_word;
        input [7:0] fmt;
        input integer length, seed, gaps;
        input [63:0] tail_word;
        integer k;
        begin
            send_header(sync_word, 16'hB42E, fmt);
            for (k=0; k<length; k=k+1) begin
                if (gaps && k%7 == 0) idle_cycles(2);
                send_byte(body_byte(fmt, k, seed));
            end
            for (k=7; k>=0; k=k-1) send_byte(tail_word[k*8 +: 8]);
        end
    endtask
    task check_frame;
        input [7:0] fmt;
        input integer length, seed, inverted;
        integer k;
        begin
            if (frame_valid !== 1 || rx_ready !== 0 || frame_address !== 16'hB42E ||
                frame_format !== fmt || payload_length !== length || sync_inverted !== inverted[0])
                $fatal(1, "metadata mismatch fmt=%h length=%0d inv=%0d", fmt, length, inverted);
            // Bytes above payload_length are unspecified; do not check them.
            for (k=0; k<length; k=k+1)
                if (payload_data[k*8 +: 8] !== body_byte(fmt, k, seed))
                    $fatal(1, "payload mismatch fmt=%h byte=%0d got=%h expected=%h",
                           fmt, k, payload_data[k*8 +: 8], body_byte(fmt, k, seed));
        end
    endtask
    task release_frame;
        integer before_count;
        begin
            before_count=accepted_frames;
            @(negedge clk); rx_valid=0; frame_ready=1;
            @(posedge clk); #2;
            if (frame_valid !== 0 || rx_ready !== 1 || accepted_frames != before_count+1)
                $fatal(1, "output handshake failed");
            @(negedge clk); frame_ready=0;
        end
    endtask
    task check_error;
        input integer before_count, code;
        begin
            idle_cycles(3);
            if (error_count != before_count+1 || last_error != code ||
                frame_valid !== 0 || frame_error !== 0 || rx_ready !== 1)
                $fatal(1, "expected one error code=%0d, count=%0d last=%0d",
                       code, error_count-before_count, last_error);
        end
    endtask
    task reset_dut;
        begin
            @(negedge clk); rx_valid=0; frame_ready=0;
            #1; rst=1; // Assert asynchronous reset away from the clock edge.
            #1;
            if (frame_valid !== 0 || frame_error !== 0 || rx_ready !== 1)
                $fatal(1, "reset did not clear control outputs");
            repeat (3) @(negedge clk);
            rst=0;
        end
    endtask
    task recovery_frame;
        begin
            send_frame(16'hEB90, 8'h39, 9, 0, 0, TAIL);
            check_frame(8'h39, 9, 0, 0);
            release_frame;
        end
    endtask

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("tb_telecommand_deframer.vcd");
            $dumpvars(0, tb_telecommand_deframer);
        end
        formats[0]=8'h39; lengths[0]=9;
        formats[1]=8'h5A; lengths[1]=32;
        formats[2]=8'h69; lengths[2]=64;
        formats[3]=8'h96; lengths[3]=128;
        formats[4]=8'hA5; lengths[4]=256;
        formats[5]=8'hC9; lengths[5]=512;
        reset_dut;
        for (n=0; n<48; n=n+1) send_byte(8'h55); // 384-bit preamble
        idle_cycles(2);
        if (frame_valid !== 0 || error_count != 0) $fatal(1, "preamble accepted");
        for (inv=0; inv<2; inv=inv+1)
            for (f=0; f<6; f=f+1) begin
                old_errors=error_count;
                send_frame(inv ? 16'h146F : 16'hEB90, formats[f], lengths[f], f+inv, inv, TAIL);
                check_frame(formats[f], lengths[f], f+inv, inv);
                // Output backpressure: present an input byte while blocked.
                @(negedge clk); rx_valid=1; rx_data=8'h55;
                repeat (5) begin
                    @(posedge clk); #2;
                    check_frame(formats[f], lengths[f], f+inv, inv);
                end
                release_frame;
                if (error_count != old_errors) $fatal(1, "error on a good frame");
                cases_passed=cases_passed+1;
                $display("PASS format=%h length=%0d inverted=%0d", formats[f], lengths[f], inv);
                for (n=0; n<16; n=n+1) send_byte(8'h55);
            end
        // No protocol idle sequence between consecutive frames.
        recovery_frame; recovery_frame;
        cases_passed=cases_passed+1;
        // One-bit sync error must be ignored; overlapping EB EB 90 must work.
        old_errors=error_count; old_frames=accepted_frames;
        send_header(16'hEB91, 16'hB42E, 8'h39);
        for (n=0; n<17; n=n+1) send_byte(0);
        idle_cycles(3);
        if (error_count != old_errors || accepted_frames != old_frames || frame_valid !== 0)
            $fatal(1, "invalid sync accepted");
        send_byte(8'hEB); recovery_frame;
        cases_passed=cases_passed+1;
        old_errors=error_count;
        send_byte(8'hEB); send_byte(8'h90); send_byte(8'hB4); send_byte(8'h2F);
        check_error(old_errors, 1); recovery_frame;
        cases_passed=cases_passed+1;
        old_errors=error_count;
        send_header(16'h146F, 16'hB42E, 8'h38);
        check_error(old_errors, 2); recovery_frame;
        cases_passed=cases_passed+1;
        // Corrupt each of the eight tail bytes separately.
        for (n=0; n<8; n=n+1) begin
            old_errors=error_count;
            send_frame(16'hEB90, 8'h39, 9, 0, 0, TAIL ^ (64'h1 << (n*8)));
            check_error(old_errors, 3); recovery_frame;
            cases_passed=cases_passed+1;
        end
        // Reset in address, payload, partial tail, and held-output states.
        for (stage=0; stage<4; stage=stage+1) begin
            old_errors=error_count;
            if (stage == 0) begin
                send_byte(8'hEB); send_byte(8'h90); send_byte(8'hB4);
            end else if (stage == 1) begin
                send_header(16'hEB90, 16'hB42E, 8'hC9);
                send_byte(8'h12); send_byte(8'h34);
            end else if (stage == 2) begin
                send_header(16'hEB90, 16'hB42E, 8'h39);
                for (n=0; n<9; n=n+1) send_byte(body_byte(8'h39, n, 0));
                send_byte(8'hC5);
            end else send_frame(16'h146F, 8'h39, 9, 0, 0, TAIL);
            old_frames=accepted_frames;
            reset_dut; idle_cycles(3);
            if (accepted_frames != old_frames || error_count != old_errors)
                $fatal(1, "reset published a partial frame/error");
            recovery_frame;
            cases_passed=cases_passed+1;
        end
        idle_cycles(5);
        if (error_count != 10 || accepted_frames != 29)
            $fatal(1, "unexpected totals frames=%0d errors=%0d", accepted_frames, error_count);
        $display("TB_TELECOMMAND_DEFRAMER_PASS cases=%0d frames=%0d expected_errors=%0d",
                 cases_passed, accepted_frames, error_count);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "watchdog timeout: handshake or framing stalled");
    end
endmodule
