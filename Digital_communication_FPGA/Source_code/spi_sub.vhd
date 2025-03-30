--------------------------------------------------------------------------------
-- Company: UL FE, Red Pitaya
-- Engineer: Miha Gjura
--
-- Design Name: spi
-- Project Name: Red Pitaya logic SPI
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: SPI vaja
-- Sys Registers: 0x40340100 ID
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity spi_sub is
    port(
        clk             : in  std_logic;
        rstn            : in  std_logic;
        enable          : in  std_logic;        -- Enable component

        clk_div         : in   unsigned(31 downto 0);   -- Clock division (speed)

        cpol            : in   std_logic;       -- Clock polarity
        cpha            : in   std_logic;       -- Clock phase

        cs              : out  std_logic;       -- Only one chip select
        sck             : out  std_logic;
        miso            : in   std_logic;       -- Main in, Sub out (master in slave out)
        mosi            : out  std_logic;       -- Main out, Sub in (master out slave in)

        data_in         : in   std_logic_vector(7 downto 0);    -- Parallel data in
        data_out        : out  std_logic_vector(7 downto 0);    -- Parallel data out

        busy            : out std_logic
    );
end spi_sub;


architecture Behavioral of spi_sub is

    type spi_state is (READY_ST, TRANSMIT_ST);                                      -- SPI state machine

    constant ZERO : std_logic_vector(31 downto 0) := (others => '0');               -- ZERO constant for clearing

    signal state                : spi_state := READY_ST;                            -- SPI state
    signal sclock               : std_logic;                                        -- serial clock buffer
    signal chip_select          : std_logic;                                        -- Chip select buffer

    signal cpol_temp, cpha_temp : std_logic_vector(0 downto 0);

    signal rx_buff, tx_buff     : std_logic_vector(7 downto 0) := (others => '0');  -- Input & output data buffers
    
    signal clk_toggle_cnt       : unsigned(15 downto 0) := (others => '0');         -- Clock toggle counter
    signal clk_toggle_max       : unsigned(15 downto 0) := (others => '0');         -- Clock toggle max counter
    signal clk_div_buff         : unsigned(31 downto 0) := to_unsigned(1, 32);      -- CLK_DIV buffer

    constant bits               : integer := 8;                                     -- Transmission width buffer

    signal clk_counter          : unsigned(31 downto 0) := (others => '0');         -- SCK counter
    signal assert_data          : std_logic;                                        -- write data or receive data

begin

    -- Za dejanski primer za studente se privzame, da sta CPOL = 0 in CPHA = 1

    spi: process(clk, rstn, cpol_temp)
    begin
        if rstn = '0' then
            busy <= '1';                    -- set busy signal
            chip_select <= '1';             -- deselect all sub devices
            sclock <= cpol_temp(0);         -- Serial clock to default state
            mosi <= '0';                    -- Output to 0 - Z

            data_out <= ZERO(7 downto 0);   -- output data to 0

            state <= READY_ST;              -- state to READY

        elsif rising_edge(clk) then
            
            case state is

                when READY_ST =>
                    chip_select <= '1';                 -- Select sub device
                    sclock <= cpol_temp(0);             -- keep SCK on the set clock polarity
                    mosi <= '0';                        -- High impedance output - Z

                    -- User input
                    if enable = '1' then                                -- request from computer to transmit data
                        busy <= '1';                                    -- set busy flag
                        state <= TRANSMIT_ST;                           -- change to transmit state

                        tx_buff <= data_in;                             -- save data to internal buffer
                        data_out <= ZERO(7 downto 0);                   -- Disable data output
                        clk_toggle_max <= resize(to_unsigned(bits*2, 9) + unsigned(cpha_temp), 16);    -- calculate max clk count
                        assert_data <= NOT cpha_temp(0);

                        if (clk_div = 0) then                           -- Make sure to prevent unindentified behaviour
                            clk_div_buff <= to_unsigned(1, 32);         -- ==> apply max speed
                            clk_counter <= (others => '0');
                        else
                            clk_div_buff <= clk_div;                    -- apply set speed
                            clk_counter <= clk_div -1;
                        end if;

                    else
                        busy <= '0';                                    -- clear busy flag
                        state <= READY_ST;                              -- stay in ready state
                        data_out <= rx_buff;                            -- Data output is enabled
                    end if;

                when TRANSMIT_ST =>
                    busy <= '1';                            -- set busy flag
                    chip_select <= '0';                     -- select output

                    data_out <= ZERO(7 downto 0);

                    -- Check if clock division value is met
                    if (clk_counter = clk_div_buff -1) then
                        assert_data <= NOT assert_data;
                        clk_counter <= (others => '0');             -- Reset clock counter
                        
                        if clk_toggle_cnt = clk_toggle_max then  -- If max toggle count
                            clk_toggle_cnt <= (others => '0');      -- Reset toggle count
                        else
                            clk_toggle_cnt <= clk_toggle_cnt + 1;   -- Increase clock toggle counter
                        end if;

                        -- SPI clock toggle needed?
                        if clk_toggle_cnt <= to_unsigned(bits*2, clk_toggle_cnt'length) and chip_select = '0' then
                            sclock <= not sclock;
                        end if;

                        -- Input data buffer
                        if ((assert_data = '0') and (clk_toggle_cnt < clk_toggle_max) and (chip_select = '0')) then
                            rx_buff <= rx_buff((bits-2) downto 0) & miso;
                        end if;

                        -- Output data buffer
                        if ((assert_data = '1') and (clk_toggle_cnt < clk_toggle_max -1)) then
                            mosi <= tx_buff(bits-1);
                            tx_buff <= tx_buff((bits-2) downto 0) & '0';
                        end if;


                        -- Continuous mode skipped

                        -- Transition back to ready state
                        if (clk_toggle_cnt = clk_toggle_max) then
                            busy <= '0';
                            chip_select <= '1';
                            mosi <= '0';            -- Z
                            data_out <= rx_buff;
                            state <= READY_ST;
                        else
                            state <= TRANSMIT_ST;
                        end if;

                    else
                        clk_counter <= clk_counter + 1;             -- Increase clock counter
                        state <= TRANSMIT_ST;
                    end if;
                    
                when others =>
                    state <= READY_ST;
            end case;

        end if;
    end process spi;

    -- Wires to the output
    cs <= chip_select;
    sck <= sclock;
    cpha_temp <= (0 => cpha);
    cpol_temp <= (0 => cpol);
end Behavioral;