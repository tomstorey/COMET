/* A simple module that divides the input clock by 64. At an input frequency of 60-70Hz this
 * produces an approximately 1Hz output. */
module div64(
	reset, clk,
	out
);
	input reset, clk;
	output out;
	
	reg [5:0] divider;
	
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			divider <= 6'd0;
		end
		else begin
			divider <= divider + 6'd1;
		end
	end
	
	wire out = divider[5];
endmodule /* div64 */

