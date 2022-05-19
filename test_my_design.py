import cocotb
from cocotb.triggers import Timer


CLK_FREQ = 25_000_000
PERIOD_NS = 1_000_000_000 / CLK_FREQ


@cocotb.test()
async def test_cpu_boot(dut):
    uart_log = b""
    EXPECTED = b"12345678\n\nHello"

    for cycle in range(2000):
        # Drive system clock
        dut.clk_25mhz.value = 0
        await Timer(PERIOD_NS / 2, units="ns")
        dut.clk_25mhz.value = 1
        await Timer(PERIOD_NS / 2, units="ns")

        # Capture serial output
        if dut.top_inst.uart_wr_strobe.value:
            uart_log += bytes([dut.top_inst.uart_data.value])

            if uart_log == EXPECTED:
                break

    assert uart_log.startswith(EXPECTED)
