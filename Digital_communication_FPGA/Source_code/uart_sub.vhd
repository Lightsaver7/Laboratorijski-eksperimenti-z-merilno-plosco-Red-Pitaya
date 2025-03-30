--------------------------------------------------------------------------------
-- Company: FE
-- Engineer: Miha Gjura
--
-- Design Name: uart
-- Project Name: Red Pitaya logic UART
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: UART vaja
-- Sys Registers: 0x40340050-94
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity uart_sub is
    port(
        clk             : in  std_logic;
        rstn            : in  std_logic;

        speed_set       : in  unsigned(15 downto 0);
        stop_bits_set   : in  unsigned(1 downto 0);
        parity_set      : in  unsigned(1 downto 0);
        data_set        : in  std_logic_vector(7 downto 0);

        ready           : in std_logic;
        done            : out std_logic;


        TX_data         : out std_logic
    );
end uart_sub;


architecture Behavioral of uart_sub is

    constant ZERO       : std_logic_vector(31 downto 0) := (others => '0');     -- Padding registers

    type uart_state is (IDLE_ST, START_ST, DATA_ST, PARITY_ST, STOPB_ST);

    signal st : uart_state := IDLE_ST;

    signal count            : unsigned(31 downto 0)         := (others => '0');     -- Counter for changing TX line
    signal data, new_data   : std_logic_vector(7 downto 0)  := (others => '0');     -- Data bits == 8 (limitation), transmit data
    signal speed            : unsigned(15 downto 0) := (others => '0');             -- Maximum number is 13021 (baudrate = 9600)
    signal stop_bits        : unsigned(1 downto 0)  := "01";                         -- Stop bit setting (0/1 = 1 Stop Bit, 2/3 = 2 Stop bits)
    signal parity_s         : unsigned(1 downto 0)  := "00";                        -- Parity setting (0 = No parity, 1 = Odd, 2 = Even)
    signal parity           : std_logic := '0';                                     -- Parity

    signal bit_count        : unsigned(3 downto 0)  :=  (others => '0');            -- Data bit counter
    signal rdy              : std_logic := '0';                                     -- Data transmitted, Data ready flags

begin

    uart: process(clk)
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                -- Default settings
                st <= IDLE_ST;                  -- default state
                data <= (others => '0');        -- reset data
                count <= (others => '0');       -- reset counter
                bit_count <= (others => '0');   -- Data bit counter
                TX_data <= '1';                 -- Data line held high
    
                -- Default flags
                done <= '0';                    -- data package transmitted (new data can be input)
            else

                case st is

                    -- wait for new data, everything reset
                    when IDLE_ST =>
                        count <= (others => '0');
                        TX_data <= '1';

                        if rdy = '1' then                   -- When data is written we go to start state
                            st    <= START_ST;

                            speed <= speed_set;             -- Apply settings
                            stop_bits <= stop_bits_set;
                            parity_s <= parity_set;
                            data  <= new_data;

                            done  <= '0';
                            rdy <= '0';
                        else
                            st    <= IDLE_ST;               -- Else stay in IDLE state
                            done  <= '1';
                        end if;

                    -- Generate start bit
                    when START_ST =>
                        TX_data <= '0';

                        if count < speed-1 then             -- Wait for one cycle then move to DATA state
                            count <= count + 1;
                            st <= START_ST;
                        else
                            count <= (others => '0');
                            st <= DATA_ST;
                        end if;

                    -- Transmit data
                    when DATA_ST =>

                        TX_data <= data(to_integer(bit_count)); -- Current data bit to output

                        if count < speed-1 then                 -- Check for CLK division cycle
                            st <= DATA_ST;
                            count <= count + 1;
                        else
                            count <= (others => '0');
    
                            if bit_count < 7 then
                                st <= DATA_ST;
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= (others => '0');
                                
                                -- No parity
                                if parity_s = 0 then
                                    st <= STOPB_ST;
                                else
                                    st <= PARITY_ST;
                                end if;
                            end if;

                        end if;

                    -- Parity state
                    when PARITY_ST =>
                        TX_data <= parity;

                        if count < speed-1 then
                            count <= count + 1;
                            st <= PARITY_ST;
                        else
                            count <= (others => '0');
                            st <= STOPB_ST;
                        end if;

                    -- Stop bit state
                    when STOPB_ST =>
                        TX_data <= '1';

                        if stop_bits <= 1 then
                            if count < speed-1 then
                                count <= count + 1;
                                st <= STOPB_ST;
                            else
                                count <= (others => '0');
                                st <= IDLE_ST;
                                done <= '1';
                            end if;
                        else
                            if count < (2*speed)-1 then
                                count <= count + 1;
                                st <= STOPB_ST;
                            else
                                count <= (others => '0');
                                st <= IDLE_ST;
                                done <= '1';
                            end if;
                        end if;


                    when others =>
                        st <= IDLE_ST;

                end case;

                if ready = '1' then
                    rdy <= '1';
                    new_data <= data_set;
                end if;

            end if;
        end if;
    end process uart;


-- calculate parity
with parity_s select
    parity <=   data(7) xnor data(6) xnor data(5) xnor data(4) xnor data(3) xnor data(2) xnor data(1) xnor data(0) when "01",
                data(7)  xor data(6)  xor data(5)  xor data(4)  xor data(3)  xor data(2)  xor data(1)  xor data(0) when "10",
               '0' when others;

end Behavioral;