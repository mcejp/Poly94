import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""

    for cycle in range(10):
        dut.clk_25mhz.value = 0
        await Timer(1, units="ns")
        dut.clk_25mhz.value = 1
        await Timer(1, units="ns")

    dut._log.info("reset_n is %s", dut.reset_n.value)
    assert dut.reset_n.value == 0
