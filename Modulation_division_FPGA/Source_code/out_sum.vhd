--------------------------------------------------------------------------------
-- Company: FE
-- Engineer: Miha Gjura
--
-- Design Name: out_sum
-- Project Name: Red Pitaya output sum
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: Output sum
-- Sys Registers:
--------------------------------------------------------------------------------
-- Modulates the output according to the following scheme
--
--  Inputs                  Carrier/message                               Rescale                     Output
--
--              /--------\                                                             /--------\
--  dac_a_i --> |        | --> carr ------------------> X ------> X ----> dac_rsc ---> |        | --> dac_a_o
--              |        |                              ^         ^                    |        |
--              | SWITCH |                              |         |                    | SWITCH |
--              |        |                              |         |                    |        |
--  dac_b_i --> |        | --> msg ---> X ------> + ----+         |          +-------> |        | --> dac_b_o
--              \--------/              ^         ^               |          |         \--------/
--                  |                   |         |               |          |
--                  |                mod_fact   const          mod_scale     |
--                  |                             1                          |
--                  |                                                        |
--                  +--------------------------------------------------------+
--
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity out_sum is
    port (
        clk_i       : in std_logic;
        rstn_i      : in  std_logic;            -- bus reset - active low

        mod_en      : in std_logic;             -- modulation enable
        mod_carr_ch : in std_logic;             -- modulation carrier channel
        mod_fact    : in unsigned(13 downto 0); -- modulation factor
        mod_scale   : in unsigned(13 downto 0); -- modulation scaling

        dac_a_i     : in signed(13 downto 0);   -- DAC1 signal
        dac_b_i     : in signed(13 downto 0);   -- DAC2 signal
        dac_a_o     : out signed(13 downto 0);  -- modulated DAC 1
        dac_b_o     : out signed(13 downto 0)   -- modulated DAC 2
    );
end out_sum;

architecture RTL of out_sum is
    constant ONE : unsigned (16-1 downto 0) := to_unsigned(2**13, 16);     -- Constant one == 8192 (X"1000")
    signal msg_mult : signed(29-1 downto 0) := (others => '0');
    signal msg_add  : signed(15-1 downto 0) := (others => '0');
    signal car_mult : signed(29-1 downto 0) := (others => '0');
    signal dac_mult : signed(31-1 downto 0) := (others => '0');

    signal msg, carr : signed(14-1 downto 0);
    signal dac_rsc : signed (14-1 downto 0);

begin


    -- Multiplexers
    carr <= dac_a_i when (mod_carr_ch = '0') else dac_b_i;          -- define carrier and message
    msg  <= dac_b_i when (mod_carr_ch = '0') else dac_a_i;  

    dac_a_o <= dac_rsc when(mod_en = '1' and mod_carr_ch = '0') else dac_a_i;     -- define modulation output (carrier channel outputs modulated waveform)
    dac_b_o <= dac_rsc when(mod_en = '1' and mod_carr_ch = '1') else dac_b_i;

    -- ### Equations ###
    -- c(t) = A*sin(2*pi*fc*t)                                      -- carrier wave
    -- m(t) = M*sin(2*pi*fm*t + fi) = A*m*sin(2*pi*fm*t + fi)       -- message signal
    -- m = M/A
    -- fm << fc
    -- y(t) = (1 + m(t)/A)*c(t)
    -- 

    -- //! ASSUMPTIONS:
    -- //! fm << fc
    -- //! m <= 1           -- modulation factor smaller than 1 (undermodulation)

    modulation: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                msg_mult <= (others => '0');
                msg_add <= (others => '0');
                car_mult <= (others => '0');
                dac_mult <= (others => '0');
            else
                -- delay carrier by multiplication and addition clock delay??
                msg_mult <= msg * signed(resize(mod_fact, 15));                         -- multiply message signal with modulation factor (A_msg/A_carr)
                msg_add <= to_signed(8192, 15) + msg_mult(28-1 downto 13);              -- add constant 1
                
                -- how much delay do these two introduce
                car_mult <= msg_add * carr;                                             -- multiply carrier signal with message "amplitude"
                dac_mult <= car_mult(29-1 downto 13) * signed(resize(mod_scale,15));    -- rescale output signal to fit inside 14 bits
                dac_rsc <= dac_mult(27-1 downto 13);
            end if;
        end if;
    end process modulation;

end RTL;

