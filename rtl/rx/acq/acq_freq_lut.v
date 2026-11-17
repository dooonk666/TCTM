`timescale 1ns / 1ps
// Explicit 39-bin hardware lookup table. No inferred runtime multiply/divide.
module acq_freq_lut (
    input  wire [5:0] index_i,
    output reg signed [31:0] fcw_o,
    output reg signed [19:0] freq_hz_o
);
always @*
begin
    case (index_i)
        6'd0:  begin fcw_o=-32'sd212511403; freq_hz_o=-20'sd303703; end
        6'd1:  begin fcw_o=-32'sd201326592; freq_hz_o=-20'sd287719; end
        6'd2:  begin fcw_o=-32'sd190141781; freq_hz_o=-20'sd271734; end
        6'd3:  begin fcw_o=-32'sd178956971; freq_hz_o=-20'sd255750; end
        6'd4:  begin fcw_o=-32'sd167772160; freq_hz_o=-20'sd239766; end
        6'd5:  begin fcw_o=-32'sd156587349; freq_hz_o=-20'sd223781; end
        6'd6:  begin fcw_o=-32'sd145402539; freq_hz_o=-20'sd207797; end
        6'd7:  begin fcw_o=-32'sd134217728; freq_hz_o=-20'sd191813; end
        6'd8:  begin fcw_o=-32'sd123032917; freq_hz_o=-20'sd175828; end
        6'd9:  begin fcw_o=-32'sd111848107; freq_hz_o=-20'sd159844; end
        6'd10: begin fcw_o=-32'sd100663296; freq_hz_o=-20'sd143859; end
        6'd11: begin fcw_o=-32'sd89478485;  freq_hz_o=-20'sd127875; end
        6'd12: begin fcw_o=-32'sd78293675;  freq_hz_o=-20'sd111891; end
        6'd13: begin fcw_o=-32'sd67108864;  freq_hz_o=-20'sd95906;  end
        6'd14: begin fcw_o=-32'sd55924053;  freq_hz_o=-20'sd79922;  end
        6'd15: begin fcw_o=-32'sd44739243;  freq_hz_o=-20'sd63938;  end
        6'd16: begin fcw_o=-32'sd33554432;  freq_hz_o=-20'sd47953;  end
        6'd17: begin fcw_o=-32'sd22369621;  freq_hz_o=-20'sd31969;  end
        6'd18: begin fcw_o=-32'sd11184811;  freq_hz_o=-20'sd15984;  end
        6'd19: begin fcw_o= 32'sd0;         freq_hz_o= 20'sd0;      end
        6'd20: begin fcw_o= 32'sd11184811;  freq_hz_o= 20'sd15984;  end
        6'd21: begin fcw_o= 32'sd22369621;  freq_hz_o= 20'sd31969;  end
        6'd22: begin fcw_o= 32'sd33554432;  freq_hz_o= 20'sd47953;  end
        6'd23: begin fcw_o= 32'sd44739243;  freq_hz_o= 20'sd63938;  end
        6'd24: begin fcw_o= 32'sd55924053;  freq_hz_o= 20'sd79922;  end
        6'd25: begin fcw_o= 32'sd67108864;  freq_hz_o= 20'sd95906;  end
        6'd26: begin fcw_o= 32'sd78293675;  freq_hz_o= 20'sd111891; end
        6'd27: begin fcw_o= 32'sd89478485;  freq_hz_o= 20'sd127875; end
        6'd28: begin fcw_o= 32'sd100663296; freq_hz_o= 20'sd143859; end
        6'd29: begin fcw_o= 32'sd111848107; freq_hz_o= 20'sd159844; end
        6'd30: begin fcw_o= 32'sd123032917; freq_hz_o= 20'sd175828; end
        6'd31: begin fcw_o= 32'sd134217728; freq_hz_o= 20'sd191813; end
        6'd32: begin fcw_o= 32'sd145402539; freq_hz_o= 20'sd207797; end
        6'd33: begin fcw_o= 32'sd156587349; freq_hz_o= 20'sd223781; end
        6'd34: begin fcw_o= 32'sd167772160; freq_hz_o= 20'sd239766; end
        6'd35: begin fcw_o= 32'sd178956971; freq_hz_o= 20'sd255750; end
        6'd36: begin fcw_o= 32'sd190141781; freq_hz_o= 20'sd271734; end
        6'd37: begin fcw_o= 32'sd201326592; freq_hz_o= 20'sd287719; end
        6'd38: begin fcw_o= 32'sd212511403; freq_hz_o= 20'sd303703; end
        default: begin fcw_o=32'sd0; freq_hz_o=20'sd0; end
    endcase
end
endmodule
