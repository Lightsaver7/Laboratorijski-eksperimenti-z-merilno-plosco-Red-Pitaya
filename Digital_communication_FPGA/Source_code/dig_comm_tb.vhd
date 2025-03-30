--------------------------------------------------------------------------------
-- Company: UL FE, Red Pitaya
-- Engineer: Miha Gjura
--
-- Design Name: testDigComm
-- Project Name: Red Pitaya digital communication logic testbench
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: Testna struktura za Digitalno komunikacijo
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity TestDigComm is
end TestDigComm;

architecture Behavioral of TestDigComm is

  component red_pitaya_dig_comm
   port (
    clk_i   : in  std_logic;                        -- bus clock
    rstn_i  : in  std_logic;                        -- bus reset - active low

    gpio_n    : out std_logic_vector(7 downto 0);   -- digital pins
    led_o     : out std_logic_vector(7 downto 0);   -- leds
    led_t     : out std_logic_vector(7 downto 0);   -- led tristate control
	  
    sys_addr  : in  std_logic_vector(31 downto 0);  -- bus address
    sys_wdata : in  std_logic_vector(31 downto 0);  -- bus write data
    sys_wen   : in  std_logic;                      -- bus write enable
    sys_ren   : in  std_logic;                      -- bus read enable
    sys_rdata : out std_logic_vector(31 downto 0);  -- bus read data
    sys_err   : out std_logic;                      -- bus error indicator
    sys_ack   : out std_logic);                       -- bus acknowledge signal
  end component;

  signal clk_i   : std_logic := '0';
  signal rstn_i  : std_logic;

  signal led_o   : std_logic_vector(7 downto 0);
  signal led_t   : std_logic_vector(7 downto 0);
  signal gpio_n  : std_logic_vector(7 downto 0);

  signal addr_i  : std_logic_vector(31 downto 0);
  signal wdata_i : std_logic_vector(31 downto 0);
  signal wen_i   : std_logic;
  signal ren_i   : std_logic;
  signal rdata_o : std_logic_vector(31 downto 0);
  signal err_o   : std_logic;
  signal ack_o   : std_logic;

  -- Kontrola simulacije
  signal sim : std_logic := '0';

  constant T  : time := 8 ns;

begin
  uut : red_pitaya_dig_comm port map (
    clk_i   => clk_i,
    rstn_i  => rstn_i,

    gpio_n  => gpio_n,
    led_o   => led_o,
    led_t   => led_t,

    sys_addr  => addr_i,
    sys_wdata => wdata_i,
    sys_wen   => wen_i,
    sys_ren   => ren_i,
    sys_rdata => rdata_o,
    sys_err   => err_o,
    sys_ack   => ack_o    
	);

-- Definiraj uro
  clk_process : process
  begin
    if sim = '0' then
      clk_i <= '0';
      wait for T/2;
      clk_i <= '1';
      wait for T/2;
    else
      wait;
    end if;
  end process;


-- Nastavi signale sistemskega vodila
stim_proc : process
  begin
    rstn_i  <= '0';   -- aktiven reset
    addr_i  <= x"00000000";
    wdata_i <= x"00000000";
    wen_i   <= '0'; ren_i <= '0';
    wait for T/2;
    wait for 10*T;

	-- deaktiviraj reset, beri ID
    rstn_i  <= '1';
    addr_i  <= x"00000050";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;

  -- ### UART ###
    -- beri uart_speed
    addr_i  <= x"00000054";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;

    -- beri uart_set_parity
    addr_i  <= x"00000058";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;

    -- beri uart_stop_bits
    addr_i  <= x"0000005C";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;


  -- ### SPI ###
    -- beri spi_clk_div
    addr_i  <= x"00000074";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;

    -- beri spi_cpha & cpol
    addr_i  <= x"00000078";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;


  -- ### LEDs ###
    -- beri n_en_leds
    addr_i  <= x"00000090";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;

    -- beri led_state
    addr_i  <= x"00000094";
	  ren_i <= '1'; wait for T;
    ren_i <= '0'; wait for T;



  -- CHANGE SETTINGS
  -- ### UART ###
    -- change uart_speed
    addr_i  <= x"00000054";
    wdata_i <= x"0000007D";     -- 1e6 baudrate
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    -- change uart_set_parity
    addr_i  <= x"00000058";
	  wdata_i <= x"00000002";     -- even parity
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

  -- ### SPI ###
    -- change spi_clk_div
    addr_i  <= x"00000074";
    wdata_i <= x"00000000";     -- test 0 spi_clk_div setting 
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    -- change cpol & cpha
    addr_i  <= x"00000078";
    wdata_i <= x"00000002";     -- CPOL = 0, CPHA = 0
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;
    
  -- ### LEDs ###
    -- change led_state
    addr_i  <= x"00000094";
	  wdata_i <= x"00000003";     -- LED0 + LED1
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;


  -- Add data UART
    addr_i  <= x"00000050";
    wdata_i <= x"0000004D";     -- captial M
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

  -- Add data SPI
    addr_i  <= x"00000070";
    wdata_i <= x"0000004D";     -- captial M
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    wait for 125*T;

    -- Test overwrite
    addr_i  <= x"00000050";
    wdata_i <= x"00000049";     -- captial I
	  wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    addr_i  <= x"00000070";
    wdata_i <= x"00000049";     -- captial M
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

  -- ### UART ###
    -- change speed
    addr_i  <= x"00000054";
    wdata_i <= x"00000088";     -- 921600 baudrate
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    -- change set_parity
    addr_i  <= x"00000058";
    wdata_i <= x"00000000";     -- no parity
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    -- change stop_bits
    addr_i  <= x"0000005C";
    wdata_i <= x"00000002";     -- 2 stop bits
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

  -- ### SPI ###
    -- change spi_clk_div
    addr_i  <= x"00000074";
    wdata_i <= x"0000007D";     -- test 0 spi_clk_div setting 
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;

    -- change cpol & cpha
    addr_i  <= x"00000078";
    wdata_i <= x"00000010";     -- CPOL = 0, CPHA = 0
    wen_i <= '1'; wait for T;
    wen_i <= '0'; wait for T;


  -- pocakaj do konca
    wait for 10000000*T;

    sim <= '1';    -- ustavi simulacijo
    wait;
  end process;

end;