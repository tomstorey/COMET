create_clock -name {osc_40mhz} -period 25.000 -waveform {0.000 12.500} [get_ports {osc_40mhz}]
create_clock -name {cpu_clk} -period 100.000 -waveform {0.000 50.000} [get_ports {clock_divider:inst|cpu_clk}]
