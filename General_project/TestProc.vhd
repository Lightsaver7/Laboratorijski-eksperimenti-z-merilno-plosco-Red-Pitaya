--------------------------------------------------------------------------------
-- Company: FE, Red Pitaya
-- Engineer: Miha Gjura
--
-- Design Name: TestProc
-- Project Name: Red Pitaya V0.94 custom component
-- Target Device: Red Pitaya
-- Tool versions: Vivado 2020
-- Description: Test for General component template
-- Sys Registers: 0x40300000-0x403FFFFF
--------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity TestProc is
end TestProc;

architecture Behavioral of TestProc is

    component red_pitaya_proc
    generic(
        DW                      :       integer := 8;                       -- GPIO width
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
    end component red_pitaya_proc;


    constant DW                   : integer := 8;

    signal clk_i                  : std_logic := '0';
    signal rstn_i                 : std_logic;
    signal sys_addr               : std_logic_vector(31 downto 0);
    signal sys_wdata              : std_logic_vector(31 downto 0);
    signal sys_wen                : std_logic;
    signal sys_ren                : std_logic;
    signal sys_rdata              : std_logic_vector(31 downto 0);
    signal sys_err                : std_logic;
    signal sys_ack                : std_logic;
    signal adc_a_i, adc_b_i       : signed(13 downto 0) := (others => '0');
    signal adc_a_o, adc_b_o       : signed(13 downto 0) := (others => '0');
    signal dac_a_i, dac_b_i       : signed(13 downto 0) := (others => '0');
    signal dac_a_o, dac_b_o       : signed(13 downto 0) := (others => '0');
    signal led_o                  : std_logic_vector(   7 downto 0) := (others => '0');
    signal gpio_p_i, gpio_n_i     : std_logic_vector(DW-1 downto 0) := (others => '0');
    signal gpio_p_o, gpio_n_o     : std_logic_vector(DW-1 downto 0) := (others => '0');
    signal gpio_p_dir, gpio_n_dir : std_logic_vector(DW-1 downto 0) := (others => '0');



    signal n : unsigned(10 downto 0) := to_unsigned(1100, 11);
    type memory_type is array (0 to 31) of integer;
    signal sine : memory_type := (0, 39, 77, 111, 141, 166, 185, 196, 200, 196, 185, 166, 141, 111, 77, 39,
                                    0,-39,-77,-111,-141,-166,-185,-196,-200,-196,-185,-166,-141,-111,-77,-39);
    signal cosine : memory_type := (200, 196, 185, 166, 141, 111, 77, 39, 0,-39,-77,-111,-141,-166,-185,-196,
                                    -200,-196,-185,-166,-141,-111,-77,-39, 0, 39, 77, 111, 141, 166, 185, 196);

    -- Kontrola simulacije
    signal sim : std_logic := '0';

    constant T  : time := 8 ns;

begin

  uut: red_pitaya_proc generic map(
        DW      => DW
        ) port map (
        clk_i      => clk_i,
        rstn_i     => rstn_i,

        sys_addr   => sys_addr,
        sys_wdata  => sys_wdata,
        sys_wen    => sys_wen,
        sys_ren    => sys_ren,
        sys_rdata  => sys_rdata,
        sys_err    => sys_err,
        sys_ack    => sys_ack,

        adc_a_i    => adc_a_i,
        adc_b_i    => adc_b_i,
        adc_a_o    => adc_a_o, 
        adc_b_o    => adc_b_o,

        dac_a_i    => dac_a_i,
        dac_b_i    => dac_b_i,
        dac_a_o    => dac_a_o,
        dac_b_o    => dac_b_o,

        led_o      => led_o,
        gpio_p_i   => gpio_p_i,
        gpio_n_i   => gpio_n_i,
        gpio_p_o   => gpio_p_o,
        gpio_n_o   => gpio_n_o,
        gpio_p_dir => gpio_p_dir,
        gpio_n_dir => gpio_n_dir
    );

    -- Definiraj uro
    clk_process : process
    begin
        if sim = '0' then
            clk_i <= '0'; wait for T/2;
            clk_i <= '1'; wait for T/2;
        else
            wait;
        end if;
    end process;



    -- Generiraj sinusni signal iz tabele, amplituda 32*200
    singen : process(clk_i)
        variable i: integer;
    begin
        if(rising_edge(clk_i)) then
            n <= n + 1;               -- phase increment sets the frequency
            i := to_integer(n(10 downto 6));
        
            dat_a_i <= std_logic_vector(to_signed(sine(i), 14));
            dat_b_i <= std_logic_vector(to_signed(cosine(i), 14));
        end if;
    end process;



    -- Nastavi signale sistemskega vodila
    stim_proc : process
    begin
        rstn_i  <= '0';   -- aktiven reset
        sys_addr  <= x"00000000";
        sys_wdata <= x"00000000";
        sys_wen   <= '0'; sys_ren <= '0';
        wait for 10*T;

        -- deaktiviraj reset, beri ID
        rstn_i  <= '1';
        sys_addr  <= x"00000050";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;
        wait for 10*T;



        -- ### GPIO simulacija ### --
        -- nastavi vhode
        gpio_p_i <= "10100101";
        gpio_n_i <= "00001111";
        wait for 10*T;

        -- beri vhode
        sys_addr  <= x"00000020";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;

        sys_addr  <= x"00000024";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;

        -- nastavi LED
        sys_addr  <= x"00000030";
        sys_wdata <= x"000000F0";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        wait for 100*T;                      -- ### Konec GPIO simulacije ### --



        -- ### ADC/DAC simulacija ### --  
        -- Nastavi DAC izhod
        sys_addr  <= x"00000064";
        wdata_i <= x"00001FFF";     -- 1 V
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        -- Sprozi generacijo DAC
        sys_addr  <= x"0000005C";
        wdata_i <= x"00000001";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        -- Sprozi zajem ADC
        sys_addr  <= x"00000058";
        wdata_i <= x"00000001";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        wait for 10*T;

        -- Beri zajeti ADC vzorec
        sys_addr  <= x"00000060";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;
        wait for 4*T;

        -- Beri DAC amplitudo
        sys_addr  <= x"00000064";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;
        wait for 4*T;

        -- Beri ADC prozilec
        sys_addr  <= x"00000058";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;
        wait for 4*T;

        -- Beri DAC prozilec
        sys_addr  <= x"0000005C";
        sys_ren <= '1'; wait for T;
        sys_ren <= '0'; wait for T;
        wait for 4*T;

        wait for 100*T;

        -- Prozi ADC
        sys_addr  <= x"00000058";
        wdata_i <= x"00000001";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;
        wait for 10*T;          

        wait for 1000*T;                    -- ### Konec ADC/DAC simulacije ### --  


        
        -- ### Simulacija amplitude ### --
        -- Spremeni amplitudo
        sys_addr  <= x"00000054";
        sys_wdata <= x"00000008";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;
    
        wait for 10000*T;

        -- Spremeni amplitudo
        sys_addr  <= x"00000054";
        sys_wdata <= x"00000002";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;
    
        wait for 10000*T;

        -- Spremeni amplitudo
        sys_addr  <= x"00000054";
        sys_wdata <= x"00000000";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        wait for 10000*T;

        -- spremeni amplitudo
        sys_addr  <= x"00000054";
        sys_wdata <= x"00000020";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        wait for 10000*T;

        -- spremeni amplitudo
        sys_addr  <= x"00000054";
        sys_wdata <= x"00000040";
        sys_wen <= '1'; wait for T;
        sys_wen <= '0'; wait for T;

        wait for 10000*T;


        wait for 20000*T;
            
        sim <= '1';    -- ustavi simulacijo
        wait;
    end process;

end;