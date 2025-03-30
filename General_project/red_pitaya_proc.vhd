--------------------------------------------------------------------------------
-- Company: FE, Red Pitaya
-- Engineer: Miha Gjura
--
-- Design Name: red_pitaya_proc
-- Project Name: Red Pitaya V0.94 custom component
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: General component template
-- Sys Registers: 0x40300000-0x403FFFFF
--------------------------------------------------------------------------------
-- 
-- Signal path from Red Pitaya fast analog I/O to the Oscilloscope/Generator. 
-- PID shows the original PID component which is excluded and replaced by red_pitaya_proc,
-- which consists of MOD and FIR blocks.
--
--
--  Signal gen               Proc comp.    PID + ASG           Saturation    output_reg    DDR output     
--                               V             |                    |           +             |
-- / - - - \     PID replaced                  |                    |         signed          |
-- |  PID  | - - - - - - - - - - +             V                    V       to unsigned       V
-- \ - - - /                     |                                               V
--                               V
-- /-------\                 /-------\
-- |  ASG  | --> asg_dat --> |  PROC | --> dac_a_sum  ----------> dac_a --> dac_dat_a --> dac_a_out -----> OUT
-- \-------/                 \-------/                              |
--                                                                  |
--                                                                  |
--                                                                  |
--                                                                  |
--                                                              loopback
--                                                                  |
--                                                                  |
--                                                                  |
--                                                                  |
-- /-------\                     /-------\               
-- |  OSC  | <-- adc_proc_dat -- | PROC  | <--------------------- adc_dat <-- adc_dat_raw <-- adc_dat_i <-- IN
-- \-------/                     \-------/     
--                                                           |
-- / - - - \                                                 |
-- |  PID  | < - - - - - - - - - - - - - - - - - - - - - - - +
-- \ - - - /                                                        ^             ^              ^
--                                    ^                             |             |              |
--                                    |                             |             |              | 
-- Oscilloscope                  Proc comp.                     Loopback       Extract         IO REG
--                                                             connection      ADC data
--                                                                              width
--
--
----------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

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

architecture Behavioral of red_pitaya_proc is

    constant ZERO               : std_logic_vector(32-1 downto 0) := (others => '0');   -- Register paddings
    
    signal diop_in, dion_in     : std_logic_vector(DW-1 downto 0);
    signal diop_out, dion_out   : std_logic_vector(DW-1 downto 0) := (others => '0');  -- output set to 0
    signal diop_dir, dion_dir   : std_logic_vector(DW-1 downto 0) := (others => '0');  -- direction in == 0, out == 1
    
    signal led                  : std_logic_vector(   7 downto 0) := (others => '0');

    signal a, b                 : unsigned  ( 7 downto 0);  -- amplitude registers
    signal mul_a, mul_b         : signed    (22 downto 0);
    
    signal trig_adc, trig_dac   : std_logic := '0';
    signal adc_sample           : signed    (13 downto 0) := (others => '0');
    signal dac_sample           : signed    (13 downto 0) := (others => '0');

    signal adc_a, adc_b         : signed    (13 downto 0);
    signal dac_a, dac_b         : signed    (13 downto 0);

begin

    -- Input scaling
    -- multiply signed inputs with 8-bit register, register values are unsigned
    mul_a <= adc_a_i * signed('0' & a);
    
    -- divide by 16 (multiplication format 4.4), possible output overflow 
    adc_a <= mul_a(17 downto 4);

    -- Constant generator output
    dac_a <= dac_sample when (trig_dac = '1') else "00000000000000";

    -- Direct connections
    adc_a_o <= adc_a;
    adc_b_o <= adc_b_i;

    dac_a_o <= dac_a;
    dac_b_o <= dac_b_i;

    gpio_p_dir <= diop_dir;
    gpio_n_dir <= dion_dir;
    gpio_p_o   <= diop_out;
    gpio_n_o   <= dion_out;
    diop_in    <= gpio_p_i;
    dion_in    <= gpio_n_i;
    led_o      <= led;


    -- ### REGISTERS (write & control logic) ### --
    pbus: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                diop_dir    <= (others => '0');
                dion_dir    <= (others => '0');
                diop_out    <= (others => '0');
                dion_out    <= (others => '0');
                led         <= (others => '0');

                a           <= x"10";
                dac_sample  <= (others => '0');
                trig_adc    <= '0';
                trig_dac    <= '0';
            else
                sys_ack <= sys_wen or sys_ren;      -- acknowledge transactions
           
                if sys_wen='1' then                                     -- decode address & write registers
                    if sys_addr(19 downto 0)=X"00010" then
                        diop_dir <= sys_wdata(DW-1 downto 0);           -- Change direction P
                    elsif sys_addr(19 downto 0)=X"00014" then
                        dion_dir <= sys_wdata(DW-1 downto 0);           -- Change direction N
                    elsif sys_addr(19 downto 0)=X"00018" then
                        diop_out <= sys_wdata(DW-1 downto 0);           -- Change output P
                    elsif sys_addr(19 downto 0)=X"0001C" then
                        dion_out <= sys_wdata(DW-1 downto 0);           -- Change output N
                    elsif sys_addr(19 downto 0)=X"00030" then
                        led <= sys_wdata(7 downto 0);                   -- Change LEDs
                    elsif sys_addr(19 downto 0)=X"00054" then       
                        a <= unsigned(sys_wdata(7 downto 0));           -- 8-bit amplitude
                    elsif sys_addr(19 downto 0)=X"00058" then       
                        trig_adc <= sys_wdata(0);                       -- ADC trigger
                    elsif sys_addr(19 downto 0)=X"0005C" then       
                        trig_dac <= sys_wdata(0);                       -- DAC trigger
                    elsif sys_addr(19 downto 0)=X"00064" then       
                        dac_sample <= signed(sys_wdata(13 downto 0));   -- DAC output
                    end if;
               end if;
        
            end if;
        end if;
    end process pbus;

    -- ### Generate & Acquire ### --
    acq_gen: process(clk_i)
        variable i : std_logic := '0';
    begin
        if rising_edge(clk_i) then
            if rstn_i = '0' then
                adc_sample <= (others => '0');
            else
                if trig_adc = '1' and i = '0' then
                    adc_sample <= signed(adc_b_i);
                    i := '1';
                end if;
                
                if sys_wen='1' then                                 -- decode address & write registers
                    if sys_addr(19 downto 0)=X"00058" then
                        i := '0';
                    end if;
                end if;
            end if;
        end if;
    end process acq_gen;

    
    -- Handling errors
    sys_err <= '0';
    
    -- ### Decode address & read data ### --
    with sys_addr(19 downto 0) select
        sys_rdata <= X"FE240000"                                            when x"00050",      -- ID
                    ZERO(32-1 downto DW) & diop_dir                         when x"00010",      -- GPIO P direction
                    ZERO(32-1 downto DW) & dion_dir                         when x"00014",      -- GPIO N direction
                    ZERO(32-1 downto DW) & diop_out                         when x"00018",      -- GPIO P output
                    ZERO(32-1 downto DW) & diop_out                         when x"0001C",      -- GPIO N output
                    ZERO(32-1 downto DW) & diop_in                          when x"00020",      -- GPIO P inputs
                    ZERO(32-1 downto DW) & dion_in                          when x"00024",      -- GPIO N inputs
                    ZERO(32-1 downto  8) & led                              when x"00030",      -- LEDs
                    ZERO(32-1 downto  8) & std_logic_vector(a)              when x"00054",      -- Amplitude
                    ZERO(32-1 downto  1) & trig_adc                         when x"00058",      -- adc trig
                    ZERO(32-1 downto  1) & trig_dac                         when x"0005C",      -- dac trig
                    ZERO(32-1 downto 14) & std_logic_vector(adc_sample)     when x"00060",      -- adc sample
                    ZERO(32-1 downto 14) & std_logic_vector(dac_sample)     when x"00064",      -- adc sample
                    ZERO when others;
end Behavioral;
 
