module i2c_EEPROM (
    input clk, reset, newd, page_wrt,
    input [2:0] a_n,
    input read,
    input [5:0] no_of_bytes,
    output sda,
    output scl,
    input [7:0] din,
    input [15:0] addr,
    output [7:0] dout,
    output reg busy, ack_err, done
);

    parameter sys_freq = 40000000; //40MHZ
    parameter i2c_freq = 100000; //100KHz

    parameter clk_count4 = (sys_freq/i2c_freq); // 400
    parameter clk_count = (clk_count4)/4; // 100

    integer count = 0; // for slow clk
    reg [1:0] pulse = 0; // segmentation of 1 bit duration

    // COUNT LOGIC
    always @(posedge clk) begin
        if (reset) count <= 0;
        else begin
            if (busy == 0) count <= 0;
            else begin
                if (count == clk_count - 1) count <= 0;
                else count <= count + 1;
            end
        end
    end

    // PULSE LOGIC
    always @(posedge clk) begin
        if (reset) pulse <= 0;
        else begin
            if (busy == 0) pulse <= 0;
            else begin
                if (count == clk_count - 1) begin
                    if (pulse == 3) pulse <= 0;
                    else pulse <= pulse + 1;
                end
                else pulse <= pulse;
            end
        end
    end
    
    parameter IDLE = 0, START = 1, WRITE_CTRL = 2, ACK_1 = 3, WRITE_DATA = 4,
                READ_DATA = 5, ACK_2 = 6, MASTER_ACK = 7, STOP = 8, WRITE_ADDR_H = 9,
                WRITE_ADDR_L = 10, ACK_3 = 11, ACK_4 = 12, ACK_5 = 13, PAGE_WRITE = 14; 

    reg [4:0] state;
    reg scl_t = 0;
    reg sda_t = 0;

    reg [3:0] bit_count = 0;
    integer p_count = 0;
    reg [7:0] data_ctrl = 0, data_tx = 0;
    reg [7:0] data_addr_h, data_addr_l;
    reg r_ack;
    reg [7:0] rx_data;
    reg [7:0] page_data [62:0];
    reg sda_en;

    always @(posedge clk) begin
        if (reset) begin
            bit_count <= 0;
            data_ctrl <= 0;
            data_tx <= 0;
            scl_t <= 1;
            sda_t <= 1;
            busy <= 0;
            ack_err <= 0;
            done <= 0;
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE : begin
                    done <= 0;
                    if (newd) begin
                        state <= START;
                        data_ctrl <= {4'b1010, a_n, read};
                        data_addr_h <= addr[15:8];
                        data_addr_l <= addr[7:0];
                        data_tx <= din;
                        busy <= 1;
                        ack_err <= 0;
                    end
                    else begin
                        state <= IDLE;
                        data_ctrl <= 0;
                        data_tx <= 0;
                        busy <= 0;
                        ack_err <= 0;
                    end
                end

                //////////////////////////////////////

                START : begin
                    sda_en <= 1; 
                    case (pulse)
                        0 : begin scl_t = 1; sda_t = 1; end
                        1 : begin scl_t = 1; sda_t = 1; end
                        2 : begin scl_t = 1; sda_t = 0; end
                        3 : begin scl_t = 1; sda_t = 0; end
                    endcase

                    state <= (count == clk_count - 1 & pulse == 3) ? WRITE_CTRL : START; // possible bug
                end

                //////////////////////////////////////

                WRITE_CTRL : begin
                    sda_en <= 1;
                    if (bit_count <= 7) begin
                        case (pulse)
                            0 : begin scl_t = 0; sda_t = 0; end
                            1 : begin scl_t = 0; sda_t = data_ctrl[7-bit_count]; end
                            2 : begin scl_t = 1; end
                            3 : begin scl_t = 1; end
                        endcase

                        if (count == clk_count - 1 & pulse == 3) begin
                            state <= WRITE_CTRL;
                            bit_count <= bit_count + 1;
                            scl_t <= 0;
                        end
                        else begin
                            state <= WRITE_CTRL;
                            bit_count <= bit_count;
                        end
                    end

                    else begin
                        state <= ACK_1;
                        scl_t <= 0;
                        sda_en <= 0;
                        bit_count <= 0;
                    end
                end

                //////////////////////////////////////

                ACK_1 : begin
                    sda_en <= 0;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 0; end
                        1 : begin scl_t <= 0; sda_t <= 0; end // 0 ack coz no slave rn
                        2 : begin scl_t <= 1; sda_t <= 0; r_ack <= 0; end // change logic, when slave avl
                        3 : begin scl_t <= 1; sda_t <= 0; end
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin
                        if (r_ack == 0) begin
                            state <= WRITE_ADDR_H;
                            sda_en <= 1;
                            sda_t <= 1;
                            ack_err <= 0;
                        end
                        else begin
                            state <= STOP;
                            sda_en <= 1;
                            ack_err <= 1;
                        end
                    end
                    else begin
                        state <= ACK_1;
                    end
                end

                //////////////////////////////////////

                WRITE_ADDR_H : begin
                    sda_en <= 1;
                    if (bit_count <= 7) begin
                        case (pulse)
                            0 : begin scl_t = 0; sda_t = 0; end
                            1 : begin scl_t = 0; sda_t = data_addr_h[7-bit_count]; end
                            2 : begin scl_t = 1; end
                            3 : begin scl_t = 1; end
                        endcase

                        if (count == clk_count - 1 & pulse == 3) begin
                            state <= WRITE_ADDR_H;
                            bit_count <= bit_count + 1;
                            scl_t <= 0;
                        end
                        else begin
                            state <= WRITE_ADDR_H;
                            bit_count <= bit_count;
                        end
                    end

                    else begin
                        state <= ACK_3;
                        scl_t <= 0;
                        sda_en <= 0;
                        bit_count <= 0;
                    end
                end

                //////////////////////////////////////

                ACK_3 : begin
                    sda_en <= 0;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 0; end
                        1 : begin scl_t <= 0; sda_t <= 0; end // 0 ack coz no slave rn
                        2 : begin scl_t <= 1; sda_t <= 0; r_ack <= 0; end // change logic, when slave avl
                        3 : begin scl_t <= 1; sda_t <= 0; end
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin
                        if (r_ack == 0) begin
                            state <= WRITE_ADDR_L;
                            sda_en <= 1;
                            sda_t <= 1;
                            ack_err <= 0;
                        end
                        else begin
                            state <= STOP;
                            sda_en <= 1;
                            ack_err <= 1;
                        end
                    end
                    else begin
                        state <= ACK_3;
                    end
                end

                //////////////////////////////////////

                WRITE_ADDR_L : begin
                    sda_en <= 1;
                    if (bit_count <= 7) begin
                        case (pulse)
                            0 : begin scl_t = 0; sda_t = 0; end
                            1 : begin scl_t = 0; sda_t = data_addr_l[7-bit_count]; end
                            2 : begin scl_t = 1; end
                            3 : begin scl_t = 1; end
                        endcase

                        if (count == clk_count - 1 & pulse == 3) begin
                            state <= WRITE_ADDR_L;
                            bit_count <= bit_count + 1;
                            scl_t <= 0;
                        end
                        else begin
                            state <= WRITE_ADDR_L;
                            bit_count <= bit_count;
                        end
                    end

                    else begin
                        state <= ACK_4;
                        scl_t <= 0;
                        sda_en <= 0;
                        bit_count <= 0;
                    end
                end

                //////////////////////////////////////

                ACK_4 : begin
                    sda_en <= 0;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 0; end
                        1 : begin scl_t <= 0; sda_t <= 0; end // 0 ack coz no slave rn
                        2 : begin scl_t <= 1; sda_t <= 0; r_ack <= 0; end // change logic, when slave avl
                        3 : begin scl_t <= 1; sda_t <= 0; end
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin
                        if (r_ack == 0 & data_ctrl[0] == 0) begin
                            state <= WRITE_DATA;
                            sda_en <= 1;
                            sda_t <= 0;
                        end
                        else if (r_ack == 0 & data_ctrl[0] == 1) begin
                            state <= READ_DATA;
                            sda_en <= 0;
                            sda_t <= 1;
                        end
                        else begin
                            state <= STOP;
                            sda_en <= 1;
                            ack_err <= 1;
                        end
                    end
                    else begin
                        state <= ACK_4;
                    end
                end

                //////////////////////////////////////

                WRITE_DATA : begin
                    if (bit_count <= 7) begin
                        
                        sda_en <= 1;
                        case (pulse)
                            0 : begin scl_t <= 0; sda_t <= 0; end
                            1 : begin scl_t <= 0; sda_t <= data_tx[7-bit_count]; end
                            2 : begin scl_t <= 1; end
                            3 : begin scl_t <= 1; end
                        endcase

                        if (count == clk_count - 1 & pulse == 3) begin
                            state <= WRITE_DATA;
                            bit_count <= bit_count + 1;
                            scl_t <= 0;
                        end
                        else begin
                            state <= WRITE_DATA;
                            bit_count <= bit_count;
                        end
                    end
                    else begin
                        state <= ACK_2;
                        sda_en <= 0;
                        scl_t <= 0;
                        bit_count <= 0; 
                    end
                end

                //////////////////////////////////////

                READ_DATA : begin
                    sda_en <= 0;
                    if (bit_count <= 7) begin
                        case (pulse)
                            0 : begin scl_t <= 0; sda_t <= 0; end
                            1 : begin scl_t <= 0; end
                            2 : begin 
                                scl_t <= 1; 
                                // rx_data <= (pulse == 2 & count == 0) ? {rx_data[6:0],sda} : rx_data;
                            end
                            3 : begin scl_t <= 1; end
                        endcase

                        if (count == clk_count - 1 & pulse == 3) begin
                            bit_count <= bit_count + 1;
                            state <= READ_DATA;
                            scl_t <= 0;
                        end
                        else begin
                            state <= READ_DATA;
                            bit_count <= bit_count;
                        end
                    end
                    else begin
                        bit_count <= 0;
                        sda_en <= 1;
                        state <= MASTER_ACK;
                    end
                end

                //////////////////////////////////////

                MASTER_ACK : begin
                    sda_en <= 1;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 1; end // possible bug
                        1 : begin scl_t <= 0; sda_t <= 1; end 
                        2 : begin scl_t <= 1; sda_t <= 1; end
                        3 : begin scl_t <= 1; sda_t <= 1; end  
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin
                        state <= STOP;
                        sda_t <= 0;
                        sda_en <= 1;    
                    end
                    else begin
                        state <= MASTER_ACK;
                    end
                end

                //////////////////////////////////////

                ACK_2 : begin
                    sda_en <= 0;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 0; end
                        1 : begin scl_t <= 0; sda_t <= 0; end
                        2 : begin scl_t <= 1; sda_t <= 0; r_ack <= 0; end
                        3 : begin scl_t <= 1; end 
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin // possibel bug
                        if (r_ack == 0 && page_wrt == 1) begin
                            state <= PAGE_WRITE;
                            ack_err <= 0;
                            sda_en <= 1;
                            sda_t <= 0;
                        end
                        else if (r_ack == 0 && page_wrt == 0) begin
                            state <= STOP;
                            ack_err <= 0;
                            sda_en <= 1;
                            sda_t <= 0;
                        end
                        else begin
                            state <= STOP;
                            ack_err <= 1;
                        end
                    end
                    else begin
                        state <= ACK_2;
                    end
                end

                //////////////////////////////////////

                PAGE_WRITE : begin
                    if (p_count <= no_of_bytes - 1) begin
                        sda_en <= 1;
                        if (bit_count <= 7) begin
                            case (pulse)
                                0 : begin scl_t <= 0; sda_t <= 0; end
                                1 : begin scl_t <= 0; sda_t <= page_data[p_count][7-bit_count]; end
                                2 : begin scl_t <= 1; end
                                3 : begin scl_t <= 1; end
                            endcase

                            if (count == clk_count - 1 & pulse == 3) begin
                                state <= PAGE_WRITE;
                                bit_count <= bit_count + 1;
                                scl_t <= 0;
                            end
                            else begin
                                state <= PAGE_WRITE;
                                bit_count <= bit_count;
                            end
                        end
                        else begin
                            state <= PAGE_WRITE;
                            sda_en <= 1;
                            scl_t <= 0;
                            bit_count <= 0; 
                            p_count <= p_count + 1;
                        end
                    end

                    else begin
                        state <= ACK_5;
                        count <= 0;
                        bit_count <= 0;
                        sda_en <= 0;
                        sda_t <= 0;
                    end
                end

                //////////////////////////////////////

                ACK_5 : begin
                    sda_en <= 0;
                    case (pulse)
                        0 : begin scl_t <= 0; sda_t <= 0; end
                        1 : begin scl_t <= 0; sda_t <= 0; end // 0 ack coz no slave rn
                        2 : begin scl_t <= 1; sda_t <= 0; r_ack <= 0; end // change logic, when slave avl
                        3 : begin scl_t <= 1; sda_t <= 0; end
                    endcase

                    if (count == clk_count - 1 & pulse == 3) begin
                        if (r_ack == 0) begin
                            state <= STOP;
                            sda_en <= 1;
                            sda_t <= 1;
                            ack_err <= 0;
                        end
                        else begin
                            state <= STOP;
                            sda_en <= 1;
                            ack_err <= 1;
                        end
                    end
                    else begin
                        state <= ACK_5;
                    end
                end

                //////////////////////////////////////

                STOP : begin
                    sda_en <= 1;
                    case (pulse)
                        0 : begin scl_t <= 1; sda_t <= 0; end
                        1 : begin scl_t <= 1; sda_t <= 0; end
                        2 : begin scl_t <= 1; sda_t <= 1; end
                        3 : begin scl_t <= 1; sda_t <= 1; end
                    endcase

                    if (count == clk_count -1 & pulse == 3) begin
                        state <= IDLE;
                        scl_t <= 0;
                        sda_en <= 1;
                        busy <= 0;
                        done <= 1; // done is only high here
                    end
                    else begin
                        state <= STOP;
                    end
                end

                //////////////////////////////////////

                default: state <= IDLE;
            endcase
        end
    end  

    assign sda = (sda_en == 1) ? sda_t : 1'bz;
    assign scl = scl_t;
    assign dout = rx_data;
endmodule

module tb;
    reg clk =0; 
    reg rst = 0;
    reg newd = 0;
    reg [15:0] addr = 0;
    reg [2:0] a_n = 0;
    reg read = 0;
    reg page_wrt = 0;
    reg [7:0] din = 0;
    reg [5:0] no_of_bytes = 0;
    wire [7:0] dout;
    wire sda,scl;
    wire busy;
    wire ack_err;
    wire done;
    integer i;   
    integer j; 

    i2c_EEPROM dut (clk, rst, newd, page_wrt, a_n, read, no_of_bytes,
                    sda, scl, din, addr, dout, busy, ack_err, done);

    always #5 clk = ~clk;
    
    initial begin
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        newd = 1;
        read = 0;
        a_n = 3'b101;
        page_wrt = 1;
        addr = 16'hABCD;
        din = 8'b10101010;
        no_of_bytes = 5;
        @(negedge busy);
        repeat(5) @(posedge clk);
        $finish;
    end


    initial begin
        for (i = 0; i < 63; i = i + 1) begin
           dut.page_data[i] = 8'h00;
        end
        #10;
        for (j = 0; j < 5; j++) begin
            dut.page_data[j] = 8'hAA;
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

    initial begin
        #10000000;
        $display("----------------------");
        $display("INFINITE LOOP DETECTED");
        $display("----------------------");
        $finish;
    end
endmodule
