--------------------------------------------------------------------------------
-- Company: FE
-- Engineer: A. Trost, Miha Gjura
--
-- Design Name: red_pitaya_proc
-- Project Name: Red Pitaya v0.94 custom component
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: General FIR filter and output modulation
-- Sys Registers: 0x40300000-0x403FFFFF
--------------------------------------------------------------------------------
-- 
-- Signal path from Red Pitaya fast analog I/O to the Oscilloscope/Generator. 
-- PID shows the original PID component which is excluded and replaced by red_pitaya_proc,
-- which consists of MOD and FIR blocks.
--
--
--  Signal gen              Modulation     PID + ASG   Saturation    output_reg    DDR output     
--                               V             |            |           +             |
-- / - - - \     PID replaced                  |            |         signed          |
-- |  PID  | - - - - - - - - - - +             V            V       to unsigned       V
-- \ - - - /                     |                                      V
--                               V
-- /-------\                 /-------\
-- |  ASG  | --> asg_dat --> |  MOD  | --> dac_a_sum  --> dac_a --> dac_dat_a --> dac_a_out -----> OUT
-- \-------/                 \-------/                      |
--                                                          |
--                                                          |
--                                                          |
--                                                          |
--                                                      loopback
--                                 /---------\              |
--                                 | CLK_DIV |              |
--                                 \---------/              |
--                                      V                   |
-- /-------\                        /-------\               V
-- |  OSC  | <--- adc_proc_dat <--- |  FIR  | <--------- adc_dat <-- adc_dat_raw <-- adc_dat_i <-- IN
-- \-------/                        \-------/
--                                               |
-- / - - - \                                     |
-- |  PID  | < - - - - - - - - - - - - - - - - - +
-- \ - - - /                                               ^            ^               ^
--                                      ^                  |            |               |
--                                      |                  |            |               | 
-- Oscilloscope                    FIR + Clk div       Loopback       Extract         IO REG
--                                                    connection     ADC data
--                                                                     width
--
--
----------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity red_pitaya_proc is
    generic(
        DW                      :       integer := 8                        -- GPIO width
    );
    port (
        clk_i                   : in    std_logic;
        rstn_i                  : in    std_logic;                          -- bus reset - active low

        sys_addr                : in    std_logic_vector(31 downto 0);      -- bus address
        sys_wdata               : in    std_logic_vector(31 downto 0);      -- bus write data
        sys_wen                 : in    std_logic;                          -- bus write enable
        sys_ren                 : in    std_logic;                          -- bus read enable
        sys_rdata               : out   std_logic_vector(31 downto 0);      -- bus read data
        sys_err                 : out   std_logic;                          -- bus error indicator
        sys_ack                 : out   std_logic;                          -- bus acknowledge signal

        adc_a_i, adc_b_i        : in    signed(13 downto 0);                -- ADC 1 & 2 input
        adc_a_o, adc_b_o        : out   signed(13 downto 0);                -- Filtered ADC 1 & 2 output

        dac_a_i, dac_b_i        : in    signed(13 downto 0);                -- DAC 1 & 2 input
        dac_a_o, dac_b_o        : out   signed(13 downto 0);                -- Modulated DAC 1 & 2 output

        led_o                   : out   std_logic_vector(   7 downto 0);    -- LED output
        gpio_p_i, gpio_n_i      : in    std_logic_vector(DW-1 downto 0);    -- GPIO input data
        gpio_p_o, gpio_n_o      : out   std_logic_vector(DW-1 downto 0);    -- GPIO output data
        gpio_p_dir, gpio_n_dir  : out   std_logic_vector(DW-1 downto 0)     -- GPIO direction 
    );
end red_pitaya_proc;

architecture RTL of red_pitaya_proc is

    -- ### COMPONENTS ### --
    component freq_div
        port(
            clk_i       : in  std_logic;
            rstn_i      : in  std_logic;                -- bus reset - active low

            enable      : in  std_logic;                -- enable frequency division
            avg_nFirst  : in  std_logic;                -- avegare or first sample returned

            n           : in  unsigned(4 downto 0);     -- 2^n frequency division
            clk_out     : out std_logic;                -- output clock signal

            x           : in  signed(13 downto 0);      -- input signal
            y           : out signed(13 downto 0)       -- output signal
        );
    end component;

    component out_sum is
        port (
            clk_i       : in  std_logic;
            rstn_i      : in  std_logic;                -- bus reset - active low
    
            mod_en      : in  std_logic;                -- modulation enable
            mod_carr_ch : in  std_logic;                -- modulation carrier channel
            mod_fact    : in  unsigned(13 downto 0);    -- modulation factor
            mod_scale   : in  unsigned(13 downto 0);    -- modulation scaling
    
            dac_a_i     : in  signed(13 downto 0);      -- DAC1 signal
            dac_b_i     : in  signed(13 downto 0);      -- DAC2 signal
            dac_a_o     : out signed(13 downto 0);      -- modulated DAC 1
            dac_b_o     : out signed(13 downto 0)       -- modulated DAC 2
        );
    end component;

    -- ### SIGNALS ### --
    constant ZERO           : std_logic_vector(31 downto 0) := (others => '0');     -- Padding registers

    -- FIR --
    constant coef_num       : integer                       := 5;                   -- Max coeficients

    signal fir_data_in      : signed (13 downto 0);                                 -- x, averaged data in
    signal fir_data_in_avg  : signed (13 downto 0);
    signal fir_data_out     : signed (13 downto 0);                                 -- y, averaged data out

    -- Frequency division control
    signal avg_nFirst       : std_logic                     := '1';                 -- averaging
    signal n                : unsigned (4 downto 0)         := (others => '0');     -- Clock/frequency division
    signal enable_f_div     : std_logic                     := '0';                 -- enable frequency division

    signal clk_fir          : std_logic                     := '0';                 -- Fir filter clock

    -- Data filtering
    type delay      is array (0 to  9) of signed(13 downto 0);
    type c_array    is array (0 to  5) of signed( 9 downto 0);
    type sum_array  is array (0 to  5) of signed(24 downto 0);

    signal x_sig            : delay                 := (others => (others => '0')); -- declaration of array signal
    signal c                : c_array               := (others => (others => '0')); -- declaration of coefficient signal
    signal c_temp           : c_array               := (others => (others => '0')); -- temporary coef array to store written coef.

    signal wcnt, rcnt       : unsigned(2 downto 0)  := (others => '0');             -- write and read counter
    signal wen_dly, ren_dly : std_logic             := '0';                         -- delayed write and read enable

    signal fir_en           : std_logic             := '0';                         -- enable filtering

    signal coef_sum         : sum_array             := (others => (others => '0'));
    signal sum_add0         : signed (29 downto 0)  := (others => '0');
    signal sum_add1         : signed (29 downto 0)  := (others => '0');
    signal sum_add2         : signed (29 downto 0)  := (others => '0');
    signal sum              : signed (13 downto 0)  := (others => '0');

    -- Modulation
    signal mod_en           : std_logic             := '0';                         -- modulation enable
    signal mod_carr_ch      : std_logic             := '0';                         -- modulation carrier channel
    signal mod_fact         : unsigned(13 downto 0) := (others => '0');             -- modulation factor
    signal mod_scale        : unsigned(13 downto 0) := (others => '0');             -- modulation scaling

    -- LED & GPIO --
    
    signal diop_in, dion_in     : std_logic_vector(DW-1 downto 0);                      -- GPIO input
    signal diop_out, dion_out   : std_logic_vector(DW-1 downto 0) := (others => '0');   -- GPIO output
    signal diop_dir, dion_dir   : std_logic_vector(DW-1 downto 0) := (others => '0');   -- Direction in == 0, out == 1
    
    signal led                  : std_logic_vector(   7 downto 0) := (others => '0');   -- LED status

begin

    -- ### CLOCK DIVISION ### --
    -- The input data first passes through the frequency division block, before going to the filter.
    clock_division: freq_div 
    port map (
        clk_i       => clk_i,
        rstn_i      => rstn_i,
        enable      => enable_f_div,
        avg_nFirst  => avg_nFirst,
        n           => n,
        clk_out     => clk_fir,
        x           => fir_data_in,
        y           => fir_data_in_avg
    );

    -- ### FIR ### --
    -- Output signal mulitplexer
    fir_data_out <= sum when (fir_en = '1') else fir_data_in;

    adc_a_o     <= fir_data_out;
    adc_b_o     <= adc_b_i;
    fir_data_in <= adc_a_i;

    -- filter processes data with divided frequency
    filter: process(clk_fir)
    begin
        if rising_edge(clk_fir) then
            if rstn_i = '0' then
                x_sig <= (others => (others => '0'));       -- delete delayed signal
            else
                x_sig <= fir_data_in_avg & x_sig(0 to 8);

                coef_sum(0) <= resize(c(0) * (resize(fir_data_in_avg, 15) + resize(x_sig(9), 15)), 25);
                coef_sum(1) <= resize(c(1) * (resize(       x_sig(0), 15) + resize(x_sig(8), 15)), 25);
                coef_sum(2) <= resize(c(2) * (resize(       x_sig(1), 15) + resize(x_sig(7), 15)), 25);
                coef_sum(3) <= resize(c(3) * (resize(       x_sig(2), 15) + resize(x_sig(6), 15)), 25);
                coef_sum(4) <= resize(c(4) * (resize(       x_sig(3), 15) + resize(x_sig(5), 15)), 25);
                coef_sum(5) <= resize(c(5) * (        x_sig(4)(13) & x_sig(4))                   , 25);

                sum_add0 <= resize(coef_sum(0) + coef_sum(1), 30);
                sum_add1 <= resize(coef_sum(2) + coef_sum(3), 30);
                sum_add2 <= resize(coef_sum(3) + coef_sum(4), 30);
                sum      <= resize(sum_add0 + sum_add1 + sum_add2, 30)(23 downto 10);

            end if;
        end if;
    end process filter;

    -- ### MODULATION ### --

    out_modulation: out_sum port map (
        clk_i       => clk_i,
        rstn_i      => rstn_i,
        mod_en      => mod_en,
        mod_carr_ch => mod_carr_ch,
        mod_fact    => mod_fact,
        mod_scale   => mod_scale,
        dac_a_i     => dac_a_i,
        dac_b_i     => dac_b_i,
        dac_a_o     => dac_a_o,
        dac_b_o     => dac_b_o
        );

    -- ### Registers, write & control logic ### --
    -- Red Pitaya core clock frequency
    pbus: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                -- FIR --
                fir_en <= '0';
                c_temp <= (others => (others => '0'));

                c(0) <= to_signed(110,10);
                c(1) <= to_signed(69,10);
                c(2) <= to_signed(83,10);
                c(3) <= to_signed(95,10);
                c(4) <= to_signed(102,10);
                c(5) <= to_signed(105,10);

                wen_dly <= '0';
                ren_dly <= '0';

                wcnt <= (others => '0');
                rcnt <= (others => '0');
                
                -- Freq div --
                enable_f_div <= '0';
                avg_nFirst <= '1';
                n <= (others => '0');

                -- Modulation --
                mod_en      <= '0';
                mod_carr_ch <= '0';
                mod_fact    <= (others => '0');
                mod_scale   <= (others => '0');

                -- LED & GPIO --
                diop_dir <= (others => '0');
                dion_dir <= (others => '0');
                diop_out <= (others => '0');
                dion_out <= (others => '0');
                led <= (others => '0');

            else
                sys_ack <= sys_wen or sys_ren;      -- acknowledge transactions
                
                -- decode address & write registers
                if sys_wen='1' then
                    if    sys_addr(19 downto 0) = X"00010" then
                        diop_dir <= sys_wdata(DW-1 downto 0);           -- Change direction P

                    elsif sys_addr(19 downto 0) = X"00014" then
                        dion_dir <= sys_wdata(DW-1 downto 0);           -- Change direction N

                    elsif sys_addr(19 downto 0) = X"00018" then
                        diop_out <= sys_wdata(DW-1 downto 0);           -- Change output P

                    elsif sys_addr(19 downto 0) = X"0001C" then
                        dion_out <= sys_wdata(DW-1 downto 0);           -- Change output N

                    elsif sys_addr(19 downto 0) = X"00030" then
                        led <= sys_wdata(7 downto 0);                   -- Change LEDs

                    elsif sys_addr(19 downto 0) = X"00050" then         -- FIR enable
                        fir_en <= sys_wdata(0);

                    elsif sys_addr(19 downto 0) = X"00054" then         -- FIR change coeficients
                        if sys_wdata(0) = '1' then
                            c    <= c_temp;
                            wcnt <= (others => '0');
                        end if;
                    elsif sys_addr(19 downto 0) = X"00058" then         -- FIR Change temp coeficients
                        c_temp(to_integer(wcnt)) <= signed(sys_wdata(9 downto 0));

                    elsif sys_addr(19 downto 0) = X"00060" then         -- Frequency division enable
                        enable_f_div <= sys_wdata(0);

                    elsif sys_addr(19 downto 0) = X"00064" then         -- Averaging enable disable
                        avg_nFirst <= sys_wdata(0);

                    elsif sys_addr(19 downto 0) = X"00068" then         -- Frequency division
                        n <= '0' & unsigned(sys_wdata(3 downto 0));

                    elsif sys_addr(19 downto 0) = X"00070" then         -- Modulation enable
                        mod_en <= sys_wdata(0);                                             

                    elsif sys_addr(19 downto 0) = X"00074" then         -- Modulation carrier channel select
                        mod_carr_ch <= sys_wdata(0);

                    elsif sys_addr(19 downto 0) = X"00078" then         -- Modulation factor
                        mod_fact <= unsigned(sys_wdata(13 downto 0));

                    elsif sys_addr(19 downto 0) = X"0007C" then         -- Modulation output scaling factor
                        mod_scale <= unsigned(sys_wdata(13 downto 0));
                    end if;
                end if;

                -- creating a delayed write/read enable signal, writing/reading on falling edge
                wen_dly <= sys_wen;
                ren_dly <= sys_ren;

                -- increasing write counter on falling edge
                if (wen_dly = '1' and sys_wen = '0' and sys_addr(19 downto 0) = X"00058") then
                    if wcnt = coef_num then
                        wcnt <= (others => '0');    -- prevent overflow
                    else
                        wcnt <= wcnt +1;
                    end if;
                end if;

                if (ren_dly = '1' and sys_ren = '0' and sys_addr(19 downto 0) = X"00058") then
                    if rcnt = coef_num then
                        rcnt <= (others => '0');    -- prevent overflow
                    else
                        rcnt <= rcnt +1;
                    end if;
                end if;
            end if;
        end if;
    end process pbus;

    sys_err <= '0';


    -- Direct connections
    gpio_p_dir <= diop_dir;
    gpio_n_dir <= dion_dir;
    gpio_p_o <= diop_out;
    gpio_n_o <= dion_out;
    diop_in <= gpio_p_i;
    dion_in <= gpio_n_i;
    led_o <= led;


    -- ### Decode address & read data ### --
    with sys_addr(19 downto 0) select
        sys_rdata <= 
                    ZERO(32-1 downto DW)    & diop_dir                              when x"00010",      -- GPIO P direction
                    ZERO(32-1 downto DW)    & dion_dir                              when x"00014",      -- GPIO N direction
                    ZERO(32-1 downto DW)    & diop_out                              when x"00018",      -- GPIO P output
                    ZERO(32-1 downto DW)    & diop_out                              when x"0001C",      -- GPIO N output
                    ZERO(32-1 downto DW)    & diop_in                               when x"00020",      -- GPIO P inputs
                    ZERO(32-1 downto DW)    & dion_in                               when x"00024",      -- GPIO N inputs
                    ZERO(32-1 downto  8)    & led                                   when x"00030",      -- LEDs
                    X"FE24000" & "000"      & fir_en                                when x"00050",      -- ID + fir enable
                    ZERO(32-1 downto 10)    & std_logic_vector(c(to_integer(rcnt))) when x"00058",      -- Reading currently set coeficients
                    ZERO(32-1 downto  1)    & enable_f_div                          when x"00060",      -- Freq division enable
                    ZERO(32-1 downto  1)    & avg_nFirst                            when x"00064",      -- Averaging enable/disable
                    ZERO(32-1 downto  5)    & std_logic_vector(n)                   when x"00068",      -- Frequency divison
                    ZERO(32-1 downto  1)    & mod_en                                when x"00070",      -- Modulation enable
                    ZERO(32-1 downto  1)    & mod_carr_ch                           when x"00074",      -- Modulation carrier channel select
                    ZERO(32-1 downto 14)    & std_logic_vector(mod_fact)            when x"00078",      -- Modulation factor
                    ZERO(32-1 downto 14)    & std_logic_vector(mod_scale)           when x"0007C",      -- Modulation output scaling factor
                    ZERO when others;
end RTL;