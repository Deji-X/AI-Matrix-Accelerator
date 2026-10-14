module matrix_accel_4x4 #(
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
) (
    input  clk,
    input  rst_n,

    input         wr_en,
    input         wr_matrix, // 0 = A, 1 = B
    input  [3:0]  wr_addr,   // row-major element index 0..15
    input  signed [DATA_W-1:0] wr_data,

    input         start,
    output reg        busy,
    output reg        done,

    input  [3:0]  rd_addr,
    output reg signed [ACC_W-1:0] rd_data
);
    reg signed [DATA_W-1:0] A [0:15];
    reg signed [DATA_W-1:0] B [0:15];
    reg signed [ACC_W-1:0]  C [0:15];

    localparam [1:0] IDLE = 2'd0, MAC = 2'd1, WRITE_RESULT = 2'd2;
    reg [1:0] state;

    reg [1:0] row_idx, col_idx, k_idx;
    reg signed [2*DATA_W-1:0] product;
    reg signed [ACC_W-1:0] accum;
    reg signed [ACC_W-1:0] product_ext;

    always @* begin
        product = A[row_idx*4 + k_idx] * B[k_idx*4 + col_idx];
        product_ext = {{(ACC_W-2*DATA_W){product[2*DATA_W-1]}}, product};
        rd_data = C[rd_addr];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            row_idx  <= 0;
            col_idx  <= 0;
            k_idx    <= 0;
            accum    <= 0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;
            if (wr_en && !busy) begin
                if (wr_matrix == 1'b0) A[wr_addr] <= wr_data;
                else                   B[wr_addr] <= wr_data;
            end

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        row_idx <= 0;
                        col_idx <= 0;
                        k_idx   <= 0;
                        accum   <= 0;
                        busy    <= 1'b1;
                        state   <= MAC;
                    end
                end

                MAC: begin
                    if (k_idx == 2'd3) begin
                        accum  <= accum + product_ext;
                        state  <= WRITE_RESULT;
                    end else begin
                        accum  <= accum + product_ext;
                        k_idx  <= k_idx + 1'b1;
                    end
                end

                WRITE_RESULT: begin
                    C[row_idx*4 + col_idx] <= accum;
                    accum <= 0;
                    k_idx <= 0;
                    if (col_idx == 2'd3) begin
                        col_idx <= 0;
                        if (row_idx == 2'd3) begin
                            state <= IDLE;
                            busy  <= 1'b0;
                            done  <= 1'b1;
                        end else begin
                            row_idx <= row_idx + 1'b1;
                            state   <= MAC;
                        end
                    end else begin
                        col_idx <= col_idx + 1'b1;
                        state   <= MAC;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
