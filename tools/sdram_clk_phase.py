# All values assumed in nanoseconds
# See https://electronics.stackexchange.com/a/444279 for background

t_CLK = 20

# SDRAM timings - IS42S16160G-7TL (ULX3S v3.1.7)
# https://www.issi.com/WW/pdf/42-45S83200G-16160G.pdf

t_OH_SDRAM = 2.7
t_DS_SDRAM = 1.5
t_DH_SDRAM = 0.8
t_HZ_SDRAM = 5.4

# FPGA timings (guessed)

t_H_MAX_FPGA = 1
t_CO_MAX_FPGA = 5
t_CO_MIN_FPGA = 0
t_SU_FPGA = 1


read_lag = t_OH_SDRAM - t_H_MAX_FPGA
write_lag = t_CLK - t_CO_MAX_FPGA - t_DS_SDRAM
max_lag = min(read_lag, write_lag)
max_lag_deg = max_lag / t_CLK * 360

write_lead = t_CO_MIN_FPGA - t_DH_SDRAM
read_lead = t_CLK - t_HZ_SDRAM - t_SU_FPGA
max_lead = min(read_lead, write_lead)
max_lead_deg = max_lead / t_CLK * 360

print(f"Read Lag:   t_OH(SDRAM) - t_H_MAX(FPGA) =          {read_lag:.2f} ns")
print(f"Write Lag:  t_CLK - t_CO_MAX(FPGA) - t_DS(SDRAM) = {write_lag:.2f} ns")
print(f"Max Lag:    min(Read Lag, Write Lag) =             {max_lag:.2f} ns")
print(f"Max Lag:                                           {max_lag_deg:.2f} deg")
print()
print(f"Write Lead: t_CO_MIN(FPGA) - t_DH(SDRAM) =         {write_lead:.2f} ns")
print(f"Read Lead:  t_CLK - t_HZ(SDRAM) - t_SU(FPGA) =     {read_lead:.2f} ns")
print(f"Max Lead:   min(Read Lead, Write Lead) =           {max_lead: .2f} ns")
print(f"Max Lead:                                          {max_lead_deg:.2f} deg")
print()
print(f"ecp5pll.out1_deg should be set between {-max_lag_deg:.0f} and {max_lead_deg:.0f}")
