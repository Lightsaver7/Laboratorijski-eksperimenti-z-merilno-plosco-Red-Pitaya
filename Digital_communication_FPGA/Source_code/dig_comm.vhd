--------------------------------------------------------------------------------
-- Company: UL FE, Red Pitaya
-- Engineer: Miha Gjura
--
-- Design Name: dig_comm
-- Project Name: Red Pitaya logic Digital Communication Interfaces
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: UART&SPI vaja
-- Sys Registers: 0x40340050-94
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity red_pitaya_dig_comm is
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
    sys_ack   : out std_logic                       -- bus acknowledge signal
    );
end red_pitaya_dig_comm;



architecture Behavioral of red_pitaya_dig_comm is

    constant ZERO       : std_logic_vector(31 downto 0) := (others => '0');         -- Padding registers

    -- ###### UART SETTINGS ######
    signal uart_data        : std_logic_vector(7 downto 0) := (others => '0');  -- Data bits == 8 (limitation), transmit data
    signal uart_speed    : unsigned(15 downto 0) := (others => '0');         -- Maximum number is 13021 (baudrate = 9600)
    signal uart_stop_bits   : unsigned(1 downto 0)  := "01";                    -- Stop bit setting (0/1 = 1 Stop Bit, 2/3 = 2 Stop bits)
    signal uart_parity_set  : unsigned(1 downto 0)  := "00";                    -- Parity setting (0 = No parity, 1 = Odd, 2 = Even)

    signal uart_TX_data     : std_logic := '1';                                 -- Data line

    signal uart_new_data    : std_logic := '0';                                 -- New Data

    signal uart_done        : std_logic;                                        -- Data transmitted (ready to transmit another package)


    -- ###### SPI SETTINGS ######
    signal spi_enable   : std_logic := '0';                                     -- start SPI transmission flag
    signal spi_clk_div  : unsigned(31 downto 0) := to_unsigned(1, 32);          -- Base SPI clock division

    signal spi_cpol     : std_logic := '0';                                     -- SPI clock polarity
    signal spi_cpha     : std_logic := '0';                                     -- SPI clock phase

    signal spi_cs       : std_logic;                                            -- SPI chip select

    signal spi_sck      : std_logic;                                            -- SPI serial clock
    signal spi_miso     : std_logic := '0';                                     -- Main in, Sub out (master in slave out)
    signal spi_mosi     : std_logic;                                            -- Main out, Sub in (master out slave in)
    
    signal spi_data_in  : std_logic_vector(7 downto 0) := ZERO(7 downto 0);     -- SPI Parallel data in
    signal spi_data_out : std_logic_vector(7 downto 0);                         -- SPI Parallel data out
    
    signal spi_busy     : std_logic;                                            -- SPI Busy flag

    -- ###### OTHER SIGNALS ######
    signal n_en_leds        : std_logic_vector(7 downto 0)  := "00000000";      -- Negative enable LEDs
    signal led_state        : std_logic_vector(7 downto 0)  := "00000000";      -- LED state
    signal led_test         : std_logic := '0';                                 -- Blink signal

    signal led_count        : unsigned(31 downto 0) := (others => '0');         -- LED timer counter



    component uart_sub is
        port(
            clk             : in  std_logic;
            rstn            : in  std_logic;

            speed_set       : in  unsigned(15 downto 0);        -- Clock Division (Communication speed)
            stop_bits_set   : in  unsigned(1 downto 0);         -- Number of stop bits
            parity_set      : in  unsigned(1 downto 0);         -- Parity setting
            data_set        : in  std_logic_vector(7 downto 0); -- Data to be transmited (1 byte)

            ready           : in std_logic;                     -- Ready flag
            done            : out std_logic;                    -- Done flag

            TX_data         : out std_logic                     -- TX line
        );
    end component;

    component spi_sub is
        port(
            clk             : in  std_logic;
            rstn            : in  std_logic;
            enable          : in  std_logic;                        -- Enable component
    
            clk_div         : in   unsigned(31 downto 0);           -- Clock division (Communication speed)
    
            cpol            : in   std_logic;                       -- Clock polarity
            cpha            : in   std_logic;                       -- Clock phase
    
            cs              : out  std_logic;                       -- Only one chip select
            sck             : out  std_logic;
            miso            : in   std_logic;                       -- Main in, Sub out (master in slave out)
            mosi            : out  std_logic;                       -- Main out, Sub in (master out slave in)
    
            data_in         : in   std_logic_vector(7 downto 0);    -- Parallel data in
            data_out        : out  std_logic_vector(7 downto 0);    -- Parallel data out
    
            busy            : out std_logic                        -- Busy flag
        );
    end component spi_sub;


begin

    uart_st_machine : uart_sub port map (
        clk             => clk_i,
        rstn            => rstn_i,
    
        speed_set       => uart_speed,
        stop_bits_set   => uart_stop_bits,
        parity_set      => uart_parity_set,
        data_set        => uart_data,
        ready           => uart_new_data,
        done            => uart_done,
        TX_data         => uart_TX_data
    );

    spi_st_machine : spi_sub port map(
        clk             => clk_i,
        rstn            => rstn_i,

        enable          => spi_enable,
        clk_div         => spi_clk_div,
        cpol            => spi_cpol,
        cpha            => spi_cpha,
        cs              => spi_cs,
        sck             => spi_sck,
        miso            => spi_miso,
        mosi            => spi_mosi,
        data_in         => spi_data_in,
        data_out        => spi_data_out,
        busy            => spi_busy
    );



blink: process(clk_i)
begin
    if rising_edge(clk_i) then
        if rstn_i = '0' then
            led_test <= '0';
            led_count <= (others => '0');
        else
            if led_count = X"773593F" then
                led_test <= not led_test;
                led_count <= (others => '0');
            else
                led_count <= led_count + 1;
            end if;
        end if;
    end if;
end process blink;



-- registers, write & control logic
pbus: process(clk_i)
begin
    if rising_edge(clk_i) then
        if rstn_i = '0' then
            -- ## UART Default settings ##
            uart_data <= (others => '0');        -- reset data

            uart_speed <= to_unsigned(13021,16); -- default baudrate 9600
            uart_parity_set <= "00";             -- No parity
            uart_stop_bits <= "01";              -- 1 stop bit

            -- ## SPI Default settings ##
            spi_clk_div <= to_unsigned(1, 32);      -- clk_division 1 (125 MHz transmission speed)

            spi_cpol <= '0';                    -- clock polarity - start with SCK PE
            spi_cpha <= '1';                    -- clock phase - data available with first clk edge

            spi_data_in <= (others => '0');     -- Default data
            sys_ack <= '0';


        else
            sys_ack <= sys_wen or sys_ren;  -- acknowledge transactions

            if sys_wen='1' then                                                     -- decode address & write registers
                -- UART
                if sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"50") then
                    uart_data <= sys_wdata(7 downto 0);                             -- Save UART data
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"54") then
                    uart_speed <= unsigned(sys_wdata(15 downto 0));                 -- Set UART speed
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"58") then
                    uart_parity_set <= unsigned(sys_wdata(1 downto 0));             -- Set UART parity
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"5C") then
                    uart_stop_bits <= unsigned(sys_wdata(1 downto 0));              -- Set UART number of stop bits
                    -- 60, 64, 68, 6C
                -- SPI
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"70") then
                    spi_data_in <= sys_wdata(7 downto 0);                           -- Save SPI data
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"74") then
                    spi_clk_div <= unsigned(sys_wdata(31 downto 0));                -- Set SPI speed
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"78") then
                    spi_cpol <= sys_wdata(0);                                       -- Set SPI clock phase & polarity
                    spi_cpha <= sys_wdata(1);
                    -- 7C, 80, 84, 88, 8C
                -- LEDs
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"90") then
                    n_en_leds <= sys_wdata(7 downto 0);                             -- Set LED enable
                elsif sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"94") then
                    led_state <= sys_wdata(7 downto 0);                             -- Set LED state
                end if;
            end if;
        end if;
    end if;
end process pbus;

-- Control the UART Ready flag
uartNewData: process(clk_i)
begin
    if rising_edge(clk_i) then
        if rstn_i = '0' then
            uart_new_data <= '0';
        else
            if sys_wen='1' and sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"50") then
                uart_new_data <= '1';
            else
                uart_new_data <= '0';
            end if;
        end if;
    end if;
end process uartNewData;

-- Control the SPI enable flag
spiNewData: process(clk_i)
begin
    if rising_edge(clk_i) then
        if rstn_i = '0' then
            spi_enable <= '0';
        else
            if sys_wen='1' and sys_addr(17 downto 0)=(ZERO(17 downto 8) & X"70") then
                spi_enable <= '1';
            else
                spi_enable <= '0';
            end if;
        end if;
    end if;
end process spiNewData;


-- System error
sys_err <= '0';

-- LEDs
led_o <= (ZERO(7 downto 1) & led_test) OR led_state;
led_t <= n_en_leds;

-- GPIO
gpio_n <= ZERO(7 downto 6) & spi_cs & spi_sck & spi_miso & spi_mosi & ZERO(1) & uart_TX_data;

-- Decode address & read data
with sys_addr(17 downto 0) select
   sys_rdata <= X"FE240000"                                             when (ZERO(17 downto 8) & X"50"),  -- ID
                ZERO(31 downto 16) & std_logic_vector(uart_speed)       when (ZERO(17 downto 8) & X"54"),  -- UART speed
                ZERO(31 downto 2) & std_logic_vector(uart_parity_set)   when (ZERO(17 downto 8) & X"58"),  -- UART Parity setting
                ZERO(31 downto 2) & std_logic_vector(uart_stop_bits)    when (ZERO(17 downto 8) & X"5C"),  -- UART Stop bit settings
                ZERO(31 downto 1) & uart_done                           when (ZERO(17 downto 8) & X"60"),  -- UART Done
                                                                                            --64, 68, 6C     
                std_logic_vector(spi_clk_div)                           when (ZERO(17 downto 8) & X"74"),  -- SPI clock speed (division)
                ZERO(31 downto 2) & spi_cpha & spi_cpol                 when (ZERO(17 downto 8) & X"78"),  -- SPI clock phase & clock polarity
                ZERO(31 downto 1) & spi_busy                            when (ZERO(17 downto 8) & X"80"),  -- SPI busy
                                                                                            -- 84, 88, 8C
                ZERO(31 downto 8) & n_en_leds                           when (ZERO(17 downto 8) & X"90"),  -- Enable LEDs
                ZERO(31 downto 8) & led_state                           when (ZERO(17 downto 8) & X"94"),  -- LED state
                X"00000000" when others;

end Behavioral;