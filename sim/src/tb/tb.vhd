library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
library gameboy;

library procbus;
use procbus.pProc_bus.all;
use procbus.pRegmap.all;

library reg_map;
use reg_map.pReg_gameboy.all;

entity etb  is
end entity;

architecture arch of etb is

   constant clk_speed : integer := 100000000;
   constant baud      : integer := 25000000;
 
   signal clk100      : std_logic := '1';
 
   signal reset       : std_logic := '1';
   signal clksys      : std_logic := '1';
   signal clkram      : std_logic := '1';
   
   signal clkdiv      : unsigned(2 downto 0) := (others => '0');
   signal nextdiv     : unsigned(2 downto 0) := (others => '0');
   
   signal ce          : std_logic := '1';
   signal ce_2x       : std_logic := '1';
   
   signal speed       : std_logic;
   
   signal command_in  : std_logic;
   signal command_out : std_logic;
   signal command_out_filter : std_logic;
   
   signal proc_bus_in : proc_bus_type;
   
   signal lcd_clkena   : std_logic;
   signal lcd_clkena_1 : std_logic := '0';
   signal lcd_data     : std_logic_vector(14 downto 0);
   signal lcd_mode     : std_logic_vector(1 downto 0);
   signal lcd_on       : std_logic;
   signal lcd_vsync    : std_logic;
   signal lcd_vsync_1  : std_logic := '0';
   
   signal gbc_bios_addr : std_logic_vector(11 downto 0);
   signal gbc_bios_do   : std_logic_vector(7 downto 0);
   
   signal cart_addr : std_logic_vector(15 downto 0);
   signal cart_rd   : std_logic;
   signal cart_wr   : std_logic;
   signal cart_act  : std_logic;
   signal cart_do   : std_logic_vector(7 downto 0);
   signal cart_di   : std_logic_vector(7 downto 0);
   
   
   signal pixel_out_x    : integer range 0 to 159;
   signal pixel_out_y    : integer range 0 to 143;
   signal pixel_out_data : std_logic_vector(14 downto 0);  
   signal pixel_out_we   : std_logic := '0';       
   
   
   signal is_CGB         : std_logic := '1';
   
   -- settings
   signal GB_on            : std_logic_vector(Reg_GB_on.upper             downto Reg_GB_on.lower)             := (others => '0');

   
begin

   reset  <= not GB_on(0);
   clksys <= not clksys after 14 ns;
   clkram <= not clkram after 7 ns;
   
   clk100 <= not clk100 after 5 ns;
   
   -- registers
   iReg_GBA_on            : entity procbus.eProcReg generic map (Reg_GB_on      )   port map (clk100, proc_bus_in, GB_on, GB_on);      
   
   cart_act <= cart_rd or cart_wr;
   
   ispeedcontrol : entity gameboy.speedcontrol
   port map
   (
      clk_sys  => clksys,
      speed    => speed,
      pause    => '0',
      speedup  => '1',
      cart_act => cart_act,
      ce       => ce,
      ce_2x    => ce_2x
   );
   
   isdram_model : entity tb.sdram_model
   port map
   (
      clk       => clkram,      
      cart_addr => cart_addr,
      cart_rd   => cart_rd,  
      cart_do   => cart_do  
   );
   
   igb : entity gameboy.gb
   port map
   (
      reset             => reset,
            
      clk_sys           => clksys,
      ce                => ce,
      ce_2x             => ce_2x,
         
      fast_boot         => '1',
      joystick          => x"00",
      isGBC             => is_CGB,
      isGBC_game        => is_CGB,
   
      -- cartridge interface
      -- can adress up to 1MB ROM
      cart_addr         => cart_addr,
      cart_rd           => cart_rd,  
      cart_wr           => cart_wr, 
      cart_do           => cart_do,  
      cart_di           => cart_di,  
      
      --gbc bios interface
      gbc_bios_addr     => gbc_bios_addr,
      gbc_bios_do       => gbc_bios_do,
      
      -- audio
      audio_l           => open,
      audio_r           => open,
      
      -- lcd interface
      lcd_clkena        => lcd_clkena,
      lcd_data          => lcd_data,  
      lcd_mode          => lcd_mode,  
      lcd_on            => lcd_on,    
      lcd_vsync         => lcd_vsync, 
   
      joy_p54           => open,
      joy_din           => "0000",
         
      speed             => speed,   --GBC
         
      gg_reset          => reset,
      gg_en             => '0',
      gg_code           => (128 downto 0 => '0'),
      gg_available      => open,
   
      --serial port
      sc_int_clock2     => open,
      serial_clk_in     => '0',
      serial_clk_out    => open,
      serial_data_in    => '0',
      serial_data_out   => open
   );
   
   igb_bios : entity tb.gb_bios
   port map
   (
      clk     => clksys,
      address => gbc_bios_addr,
      data    => gbc_bios_do
   );
   
   process(clksys)
   begin
      if rising_edge(clksys) then
         pixel_out_we <= '0';
         lcd_vsync_1   <= lcd_vsync;
         lcd_clkena_1 <= lcd_clkena;
         if (lcd_on = '1') then
            if (lcd_vsync = '1' and lcd_vsync_1 = '0') then
               pixel_out_x <= 0;
               pixel_out_y <= 0;
            elsif (lcd_clkena_1 = '1' and lcd_clkena = '0') then
               pixel_out_x  <= 0;
               pixel_out_we <= '1';
               if (pixel_out_y < 143) then
                  pixel_out_y <= pixel_out_y + 1;
               end if;
            elsif (lcd_clkena = '1' and ce = '1') then
               if (pixel_out_x < 159) then
                  pixel_out_x  <= pixel_out_x + 1;
               end if;
               pixel_out_we <= '1';
            end if;
         end if;
         
         if (is_CGB = '0') then
            case (lcd_data(1 downto 0)) is
               when "00"   => pixel_out_data <= "11111" & "11111" & "11111";
               when "01"   => pixel_out_data <= "10000" & "10000" & "10000";
               when "10"   => pixel_out_data <= "01000" & "01000" & "01000";
               when "11"   => pixel_out_data <= "00000" & "00000" & "00000";
               when others => pixel_out_data <= "00000" & "00000" & "11111";
            end case;
         else
            pixel_out_data <= lcd_data;
         end if;
         
      end if;
   end process;
   
   iframebuffer : entity work.framebuffer
   generic map
   (
      FRAMESIZE_X => 160,
      FRAMESIZE_Y => 144
   )
   port map
   (
      clk                => clksys,
                          
      pixel_in_x         => pixel_out_x,
      pixel_in_y         => pixel_out_y,
      pixel_in_data      => pixel_out_data,
      pixel_in_we        => pixel_out_we
   );
   
   iTestprocessor : entity procbus.eTestprocessor
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud,
      is_simu   => '1'
   )
   port map 
   (
      clk               => clk100,
      bootloader        => '0',
      debugaccess       => '1',
      command_in        => command_in,
      command_out       => command_out,
            
      proc_bus          => proc_bus_in,
      
      fifo_full_error   => open,
      timeout_error     => open
   );
   
   command_out_filter <= '0' when command_out = 'Z' else command_out;
   
   itb_interpreter : entity tb.etb_interpreter
   generic map
   (
      clk_speed => clk_speed,
      baud      => baud
   )
   port map
   (
      clk         => clk100,
      command_in  => command_in, 
      command_out => command_out_filter
   );
   
end architecture;


