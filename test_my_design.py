import cocotb
from cocotb.triggers import Timer


CLK_FREQ = 50_000_000
PERIOD_NS = 1_000_000_000 / CLK_FREQ


@cocotb.test()
async def test_cpu_boot(dut):
    uart_log = b""
    EXPECTED = b"12345678\n\nHello"

    for cycle in range(4000):
        # Drive system clock
        dut.clk_sys.value = 0
        await Timer(PERIOD_NS / 2, units="ns")
        dut.clk_sys.value = 1
        await Timer(PERIOD_NS / 2, units="ns")

        # Capture serial output
        if not dut.top_inst.uart_tx_busy.value and dut.top_inst.uart_tx_strobe.value:
            uart_log += bytes([dut.top_inst.uart_tx_data.value])

            if uart_log == EXPECTED:
                break

    assert uart_log.startswith(EXPECTED)
