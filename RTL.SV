module interrupt_controller(
  input wire enable,
  input wire clk,
  input wire rst,
  input wire power_in,
  input wire [1:0]edge_detection_mode,
  input wire external_wakeup_interrupt,
  input wire overflow_int,
  input wire match_int,
  output wire power_req,
  output wire clk_req,
  output reg wakeup_interrupt
  );

  wire timer_int;
  reg timer_int_d;
  
  assign power_req = enable;
  assign clk_req   = power_in & enable;
  assign timer_int = overflow_int | match_int | external_wakeup_interrupt;
  
  always@(posedge clk or posedge rst or negedge enable or negedge power_in)begin
  if(rst || !enable || !power_in)begin
	wakeup_interrupt <= 1'b0;
	timer_int_d <= 1'b0;
  end 
  else begin
  timer_int_d <= timer_int;
  case(edge_detection_mode)
  	2'b01: wakeup_interrupt <= timer_int & ~timer_int_d;
	2'b10: wakeup_interrupt <= ~timer_int & timer_int_d;
	2'b11: wakeup_interrupt <= timer_int ^ timer_int_d;
	default: wakeup_interrupt <= 1'b0;
  endcase
  end
  end
endmodule


