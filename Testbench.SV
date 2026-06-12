mailbox gen2drv=new();
mailbox mon2scb=new();
mailbox mon2cov=new();

class common;
  static int num=100;
endclass

class transaction;
  rand bit enable;
  rand bit power_in;
  rand bit [1:0]edge_detection_mode;
  rand bit external_wakeup_interrupt;
  rand bit overflow_int;
  rand bit match_int;
  bit wakeup_interrupt;
  constraint c1{enable==1;}
  constraint c2{power_in==1;}
  constraint c3 {edge_detection_mode inside {[0:3]};}
endclass

class generator;
  transaction tx;
  task run();
  repeat(common::num)begin
  tx=new();
  assert(tx.randomize());
  gen2drv.put(tx);
  end
  endtask
endclass

interface int_cont(input reg clk,rst);
	logic enable;
	logic power_in;
    logic [1:0]edge_detection_mode;
	logic external_wakeup_interrupt;
	logic overflow_int;
	logic match_int;
	logic wakeup_interrupt;
	logic power_req;
	logic clk_req;
endinterface

class driver;
	transaction tx;
	virtual int_cont vif;

	function new();
		vif=top.pif;
	endfunction

	task run();
	repeat(common::num)begin
	gen2drv.get(tx);
    @(negedge vif.clk);
	vif.enable = tx.enable;
	vif.power_in = tx.power_in;
	vif.edge_detection_mode = tx.edge_detection_mode;
	vif.external_wakeup_interrupt = tx.external_wakeup_interrupt;
	vif.overflow_int = tx.overflow_int;
	vif.match_int = tx.match_int;
	end
	endtask
endclass

class monitor;
	transaction tx;
	virtual int_cont vif;

	function new();
		vif=top.pif;
	endfunction

	task run();
	repeat(common::num)begin
	tx=new();
    @(posedge vif.clk);
    #1;
	tx.enable = vif.enable;
	tx.power_in = vif.power_in;
	tx.edge_detection_mode = vif.edge_detection_mode;
	tx.external_wakeup_interrupt = vif.external_wakeup_interrupt;
	tx.overflow_int = vif.overflow_int;
	tx.match_int = vif.match_int;
	tx.wakeup_interrupt = vif.wakeup_interrupt;
	$display("Monitor_transaction = %p",tx);
    mon2scb.put(tx);
    mon2cov.put(tx);
	end
	endtask
endclass

class scoreboard;
	transaction tx;
		bit ref_wakeup_interrupt;
		bit timer_int;
		bit timer_int_d;

		task run();
        repeat(common::num)begin
		mon2scb.get(tx);
		timer_int= tx.overflow_int | tx.match_int | tx.external_wakeup_interrupt;
        if(! tx.enable || ! tx.power_in)begin
		   ref_wakeup_interrupt=0;
		   timer_int_d=0;
		end 
    else begin
    case(tx.edge_detection_mode)
	2'b01: ref_wakeup_interrupt = timer_int & ~timer_int_d;
	2'b10: ref_wakeup_interrupt = ~timer_int & timer_int_d;
	2'b11: ref_wakeup_interrupt = timer_int ^ timer_int_d;
	default : ref_wakeup_interrupt=0;
    endcase
	timer_int_d = timer_int;
	end
	if(ref_wakeup_interrupt == tx.wakeup_interrupt)begin
	$display("test passed");
	$display("reference=%0d, actual=%0d",ref_wakeup_interrupt,tx.wakeup_interrupt);
	end
	else begin
	$display("test failled");
	$display("reference=%0d, actual=%0d",ref_wakeup_interrupt,tx.wakeup_interrupt);
	end
	end
	endtask
endclass

class coverage;
  transaction tx;

  covergroup int_cg;
    edge_mode_cp : coverpoint tx.edge_detection_mode
    {
      bins disable_mode = {0};
      bins rising_mode  = {1};
      bins falling_mode = {2};
      bins both_mode    = {3};
    }

    overflow_cp : coverpoint tx.overflow_int
    {
      bins low  = {0};
      bins high = {1};
    }

    match_cp : coverpoint tx.match_int
    {
      bins low  = {0};
      bins high = {1};
    }

    ext_cp : coverpoint tx.external_wakeup_interrupt
    {
      bins low  = {0};
      bins high = {1};
    }

    wakeup_cp : coverpoint tx.wakeup_interrupt
    {
      bins low  = {0};
      bins high = {1};
    }

    interrupt_cross : cross overflow_cp,
                             match_cp,
                             ext_cp;

   mode_vs_wakeup : cross edge_mode_cp,
                       wakeup_cp;
  endgroup

  function new();
    int_cg = new();
  endfunction

  task run();

    repeat(common::num)
    begin
      mon2cov.get(tx);
      int_cg.sample();
    end

    $display("--------------------------------------");
    $display("FUNCTIONAL COVERAGE = %0.2f %%",int_cg.get_coverage());
    $display("--------------------------------------");

  endtask
endclass


class agent;
	generator gen;
	driver drv;
	monitor mon;
    task run();
	gen=new();
	drv=new();
	mon=new();
	fork
	gen.run();
	drv.run();
	mon.run();
	join
	endtask
endclass

class environment;
	agent agn;
	scoreboard scb;
    coverage cov;
	task run();
	agn=new();
	scb=new();
    cov=new();
	fork
	agn.run();
	scb.run();
    cov.run();
	join
	endtask
endclass


module top;

  reg clk, rst;
  environment env;
  int_cont pif(clk,rst);

  interrupt_controller dut(
    .enable(pif.enable),
    .clk(pif.clk),
    .rst(pif.rst),
    .power_in(pif.power_in),
    .edge_detection_mode(pif.edge_detection_mode),
    .external_wakeup_interrupt(pif.external_wakeup_interrupt),
    .overflow_int(pif.overflow_int),
    .match_int(pif.match_int),
    .wakeup_interrupt(pif.wakeup_interrupt),
    .power_req(pif.power_req),
    .clk_req(pif.clk_req)
  );

  // Clock Generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset Values
  task reset_signals();
    pif.enable                    = 0;
    pif.power_in                  = 0;
    pif.edge_detection_mode       = 0;
    pif.external_wakeup_interrupt = 0;
    pif.overflow_int              = 0;
    pif.match_int                 = 0;
  endtask

  // Main Test
  initial begin

    rst = 1'b1;
    reset_signals();

    repeat(10) @(posedge clk);

    rst = 1'b0;

    env = new();
    env.run();

    $display("====================================");
    $display(" INTERRUPT CONTROLLER TEST PASSED ");
    $display("====================================");

    $finish;

  end

  // Waveform Dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,top);
  end

  // Timeout Protection
  initial begin
    #100000;

    $display("====================================");
    $display(" TEST TIMEOUT ");
    $display("====================================");

    $finish;
  end

endmodule



