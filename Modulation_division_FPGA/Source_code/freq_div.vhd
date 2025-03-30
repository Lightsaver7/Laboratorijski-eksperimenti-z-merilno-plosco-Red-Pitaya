--------------------------------------------------------------------------------
-- Company: FE
-- Engineer: Miha Gjura
--
-- Design Name: freq_div
-- Project Name: Red Pitaya sampling frequency divider
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: 2^n frequency divider for the general filter
-- Sys Registers:
--------------------------------------------------------------------------------
-- Divides the input clock by n and calculates the average of n samples. Output is changed every n input clock cycles.
-- 
--            /---------\
--  clk_i --> | CLK_DIV | --------> clk_out
--            \---------/
--                 ^
--                 |
--                2**n
--
--                                                     | \
--         +------------------------> data_in    ----> |   \
--         |                          data_first       |     \
--         |      /----------\                         |      > --------> y
--         |      |          |                         |     /
--  x -----+----> |  DIVIDE  | -----> data_out  -----> |   / ^
--                |          |                         | /   | 
--                \----------/                           ^   |
--                     ^                                 |   |
--                     |                             enable  |
--                    2**n                                  avg_nFirst
--                                                            
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity freq_div is 
    port (
        clk_i       : in  std_logic;
        rstn_i      : in  std_logic;                -- bus reset - active low

        enable      : in  std_logic;                -- enable frequency division
        avg_nFirst  : in  std_logic;                -- avegare or first sample returned

        n           : in  unsigned(4 downto 0);     -- 2^n frequency division
        clk_out     : out std_logic;                -- output clock signal

        x           : in  signed(13 downto 0);      -- input signal
        y           : out signed(13 downto 0)       -- output signal
    );
end freq_div;

architecture RTL of freq_div is
    signal sum          :   signed(31 downto 0) := (others => '0');                 -- Sample sum

    signal cnt          : unsigned(31 downto 0) := (others => '0');                 -- Sample counter

    signal avg          :   signed(13 downto 0);
    signal data_out     :   signed(13 downto 0);
    signal data_in      :   signed(13 downto 0) := (others => '0');
    signal data_first   :   signed(13 downto 0);

    signal n_old        : unsigned( 4 downto 0) := (others => '0');                 -- Old value of N

    signal clk_cnt      : unsigned(31 downto 0) := (others => '0');
    signal clk_divided  : std_logic             := '1';

begin

    -- clock division

    clk_div: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rstn_i = '0' or enable ='0' or n_old /= n) then
                clk_cnt     <= (others => '0');
                clk_divided <= '1';
            else
                if clk_cnt = to_unsigned((2 ** to_integer(n))-1, 32) then       -- check for max counter value
                    clk_cnt     <= (others => '0');                             -- reset counter to 0 after max value
                    clk_divided <= not clk_divided;                             -- invert output clock
                else
                    clk_cnt <= clk_cnt + 1;                                     -- increase counter by one
                end if;
            end if;
        end if;
    end process clk_div;

    clk_out <= clk_divided when (enable = '1') else clk_i;

    -- check change of n
    n_check: process(clk_i)
    begin
        if rising_edge(clk_i) then
            n_old <= n;
        end if;

    end process n_check;


    -- counter process - synced with clock division
    counter: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rstn_i = '0' or enable = '0' or n_old /= n) then            -- reset if enable is OFF or if N has changed
                cnt <= (others => '0');
            else
                if cnt = to_unsigned((2 ** to_integer(n+1))-1, 32) then     -- check for max counter value
                    cnt <= (others => '0');                                 -- reset counter to 0 after max value
                else
                    cnt <= cnt + 1;                                         -- increase counter by one
                end if;
            end if;
        end if;
    end process counter;

    -- averaging process - synced with clock division
    divide: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rstn_i = '0' or enable = '0' or n_old /= n) then                    -- reset if enable is OFF or if N has changed
                sum <= (others => '0');
                avg <= (others => '0');
            else
                if cnt = to_unsigned(0, 32) then                                    -- check for max counter value
                    avg <= sum((13 + to_integer(n+1)) downto to_integer(n+1));      -- Calculate average data (divide the result by 2^n)
                    sum <= resize(data_in, 32);                                     -- Save first sample
                    data_first <= data_in;  
                else
                    sum <= sum + data_in;                                           -- Calculate sum                            
                end if;
            end if;
        end if;
    end process divide;

    data_in <= x;

    y        <= data_out when (enable = '1')     else data_in;           -- account for enable
    data_out <= avg      when (avg_nFirst = '1') else data_first;        -- account for averaging/first captured value

end RTL;
