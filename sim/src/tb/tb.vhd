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

   constant clk_speed : integer := 32000000;
   constant baud      : integer := 1000000;
 
   signal reset       : std_logic := '1';
   signal clksys      : std_logic := '1';
   signal clkram      : std_logic := '1';
   
   signal clkdiv      : unsigned(2 downto 0) := (others => '0');
   signal nextdiv     : unsigned(2 downto 0) := (others => '0');
   
   signal ce          : std_logic := '1';
   signal ce_2x       : std_logic := '1';
   
   signal speed       : std_logic;
   signal DMA_on      : std_logic;
   
   signal command_in  : std_logic;
   signal command_out : std_logic;
   signal command_out_filter : std_logic;
   
   signal proc_bus_in : proc_bus_type;
   
   signal lcd_clkena   : std_logic;
   signal lcd_data     : std_logic_vector(14 downto 0);
   signal lcd_mode     : std_logic_vector(1 downto 0);
   signal lcd_mode_1   : std_logic_vector(1 downto 0);
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
   
   signal serial_clk_out  : std_logic;
   signal serial_data_out : std_logic;
   
   signal pixel_out_x    : integer range 0 to 159;
   signal pixel_out_y    : integer range 0 to 143;
   signal pixel_out_data : std_logic_vector(14 downto 0);  
   signal pixel_out_we   : std_logic := '0';       
   
   signal is_CGB         : std_logic;
   
   signal sleep_savestate : std_logic;

   -- ddrram
   signal DDRAM_CLK        : std_logic;
   signal DDRAM_BUSY       : std_logic;
   signal DDRAM_BURSTCNT   : std_logic_vector(7 downto 0);
   signal DDRAM_ADDR       : std_logic_vector(28 downto 0);
   signal DDRAM_DOUT       : std_logic_vector(63 downto 0);
   signal DDRAM_DOUT_READY : std_logic;
   signal DDRAM_RD         : std_logic;
   signal DDRAM_DIN        : std_logic_vector(63 downto 0);
   signal DDRAM_BE         : std_logic_vector(7 downto 0);
   signal DDRAM_WE         : std_logic;
   
   signal ch1_addr         : std_logic_vector(27 downto 1);
   signal ch1_dout         : std_logic_vector(63 downto 0);
   signal ch1_din          : std_logic_vector(63 downto 0);
   signal ch1_req          : std_logic;
   signal ch1_rnw          : std_logic;
   signal ch1_ready        : std_logic;
   
   signal SAVE_out_Din     : std_logic_vector(63 downto 0);
   signal SAVE_out_Dout    : std_logic_vector(63 downto 0);
   signal SAVE_out_Adr     : std_logic_vector(25 downto 0);
   signal SAVE_out_rnw     : std_logic;                    
   signal SAVE_out_ena     : std_logic;                                    
   signal SAVE_out_done    : std_logic; 
   
   -- settings
   signal GB_on          : std_logic_vector(Reg_GB_on.upper             downto Reg_GB_on.lower)             := (others => '0');
   signal GB_SaveState   : std_logic_vector(Reg_GB_SaveState.upper      downto Reg_GB_SaveState.lower)      := (others => '0');
   signal GB_LoadState   : std_logic_vector(Reg_GB_LoadState.upper      downto Reg_GB_LoadState.lower)      := (others => '0');

   -- savestates
   signal cart_ram_size : std_logic_vector(7 downto 0);
   
   signal Savestate_CRAMAddr       : std_logic_vector(19 downto 0);   
   signal Savestate_CRAMRWrEn      : std_logic;    
   signal Savestate_CRAMWriteData  : std_logic_vector(7 downto 0); 
   signal Savestate_CRAMReadData   : std_logic_vector(7 downto 0); 
   
   signal SaveStateExt_Din  : std_logic_vector(63 downto 0);   
   signal SaveStateExt_Adr  : std_logic_vector(9 downto 0);   
   signal SaveStateExt_wren : std_logic;    
   signal SaveStateExt_rst  : std_logic;     
   signal SaveStateExt_Dout : std_logic_vector(63 downto 0);   
   signal SaveStateExt_load : std_logic;    
   
   -- automatic test
   signal testdone : std_logic_vector(0 downto 0) := "0";
   signal testok   : std_logic_vector(0 downto 0) := "0";
   
   type t_serialarray is array(0 to 5) of std_logic_vector(7 downto 0);
   signal serialarray : t_serialarray := (others => (others => '0'));
   signal serialpointer : integer range 0 to 5 := 0;
   signal serialbuffer : std_logic_vector(7 downto 0);
   
   
begin

   reset  <= not GB_on(0);
   clksys <= not clksys after 14 ns;
   clkram <= not clkram after 7 ns;
   
   -- registers
   iReg_GBA_on        : entity procbus.eProcReg generic map (Reg_GB_on       )   port map (clksys, proc_bus_in, GB_on       , GB_on       );      
   iReg_GB_SaveState  : entity procbus.eProcReg generic map (Reg_GB_SaveState)   port map (clksys, proc_bus_in, GB_SaveState, GB_SaveState);      
   iReg_GB_LoadState  : entity procbus.eProcReg generic map (Reg_GB_LoadState)   port map (clksys, proc_bus_in, GB_LoadState, GB_LoadState);
   
   iReg_GB_TestDone   : entity procbus.eProcReg generic map (Reg_GB_TestDone )   port map (clksys, proc_bus_in, testdone);      
   iReg_GB_TestOk     : entity procbus.eProcReg generic map (Reg_GB_TestOk   )   port map (clksys, proc_bus_in, testok  );      
   
   cart_act <= cart_rd or cart_wr;
   
   ispeedcontrol : entity gameboy.speedcontrol
   port map
   (
      clk_sys  => clksys,
      pause    => sleep_savestate,
      speedup  => '1',
      cart_act => cart_act,
      DMA_on   => DMA_on,
      ce       => ce,
      ce_2x    => ce_2x
   );
   
   igb : entity gameboy.gb
   port map
   (
      reset                   => reset,
                  
      clk_sys                 => clksys,
      ce                      => ce,
      ce_2x                   => ce_2x,
               
      fast_boot               => '1',
      joystick                => x"FF",
      isGBC                   => is_CGB,
      isGBC_game              => is_CGB,
      isSGB                   => '0',
   
      -- cartridge interface
      -- can adress up to 1MB ROM
      cart_addr               => cart_addr,
      cart_rd                 => cart_rd,  
      cart_wr                 => cart_wr, 
      cart_do                 => cart_do,  
      cart_di                 => cart_di,  
      
      --gbc bios interface
      gbc_bios_addr           => gbc_bios_addr,
      gbc_bios_do             => gbc_bios_do,
            
      -- audio    
      audio_l                 => open,
      audio_r                 => open,
            
      -- lcd interface     
      lcd_clkena              => lcd_clkena,
      lcd_data                => lcd_data,  
      lcd_mode                => lcd_mode,  
      lcd_on                  => lcd_on,    
      lcd_vsync               => lcd_vsync, 
         
      joy_p54                 => open,
      joy_din                 => "1111",
               
      speed                   => speed,   --GBC
      DMA_on                  => DMA_on,
               
      gg_reset                => reset,
      gg_en                   => '0',
      gg_code                 => (128 downto 0 => '0'),
      gg_available            => open,
         
      --serial port     
      sc_int_clock2           => open,
      serial_clk_in           => '0',
      serial_clk_out          => serial_clk_out,
      serial_data_in          => '0',
      serial_data_out         => serial_data_out,
            
      cart_ram_size           => cart_ram_size,
      save_state              => GB_SaveState,
      load_state              => GB_LoadState,
      sleep_savestate         => sleep_savestate,
      savestate_number        => 0,
            
      SaveStateExt_Din        => SaveStateExt_Din, 
      SaveStateExt_Adr        => SaveStateExt_Adr, 
      SaveStateExt_wren       => SaveStateExt_wren,
      SaveStateExt_rst        => SaveStateExt_rst, 
      SaveStateExt_Dout       => SaveStateExt_Dout,
      SaveStateExt_load       => SaveStateExt_load,
      
      Savestate_CRAMAddr      => Savestate_CRAMAddr,     
      Savestate_CRAMRWrEn     => Savestate_CRAMRWrEn,    
      Savestate_CRAMWriteData => Savestate_CRAMWriteData,
      Savestate_CRAMReadData  => Savestate_CRAMReadData, 
      
      
      SAVE_out_Din            => SAVE_out_Din,   
      SAVE_out_Dout           => SAVE_out_Dout,  
      SAVE_out_Adr            => SAVE_out_Adr,   
      SAVE_out_rnw            => SAVE_out_rnw,   
      SAVE_out_ena            => SAVE_out_ena,   
      SAVE_out_done           => SAVE_out_done,
            
      rewind_on               => '0',
      rewind_active           => '0'
   );
   
   
   imbc : entity gameboy.mbc
   port map
   (
      clk_sys                 => clksys,
      clkram                  => clkram,
      reset                   => reset,
      ce_cpu2x                => ce_2x,
                     
      cart_addr               => cart_addr,
      cart_rd                 => cart_rd,  
      cart_wr                 => cart_wr, 
      cart_do                 => cart_do,  
      cart_di                 => cart_di,  
      
      cart_ram_size           => cart_ram_size,
      is_gbc                  => is_CGB,
                     
      sleep_savestate         => sleep_savestate,
                  
      SaveStateBus_Din        => SaveStateExt_Din, 
      SaveStateBus_Adr        => SaveStateExt_Adr, 
      SaveStateBus_wren       => SaveStateExt_wren,
      SaveStateBus_rst        => SaveStateExt_rst, 
      SaveStateBus_Dout       => SaveStateExt_Dout,
      savestate_load          => SaveStateExt_load,
                     
      Savestate_CRAMAddr      => Savestate_CRAMAddr,     
      Savestate_CRAMRWrEn     => Savestate_CRAMRWrEn,    
      Savestate_CRAMWriteData => Savestate_CRAMWriteData,
      Savestate_CRAMReadData  => Savestate_CRAMReadData
   );

   ch1_addr <= SAVE_out_Adr(25 downto 0) & "0";
   ch1_din  <= SAVE_out_Din;
   ch1_req  <= SAVE_out_ena;
   ch1_rnw  <= SAVE_out_rnw;
   SAVE_out_Dout <= ch1_dout;
   SAVE_out_done <= ch1_ready;
   
   iddrram : entity tb.ddram
   port map (
      DDRAM_CLK        => clksys,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE,                
                                   
      ch1_addr         => ch1_addr,        
      ch1_dout         => ch1_dout,        
      ch1_din          => ch1_din,         
      ch1_req          => ch1_req,         
      ch1_rnw          => ch1_rnw,         
      ch1_ready        => ch1_ready
   );
   
   iddrram_model : entity tb.ddrram_model
   port map
   (
      DDRAM_CLK        => clksys,      
      DDRAM_BUSY       => DDRAM_BUSY,      
      DDRAM_BURSTCNT   => DDRAM_BURSTCNT,  
      DDRAM_ADDR       => DDRAM_ADDR,      
      DDRAM_DOUT       => DDRAM_DOUT,      
      DDRAM_DOUT_READY => DDRAM_DOUT_READY,
      DDRAM_RD         => DDRAM_RD,        
      DDRAM_DIN        => DDRAM_DIN,       
      DDRAM_BE         => DDRAM_BE,        
      DDRAM_WE         => DDRAM_WE        
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
         lcd_mode_1    <= lcd_mode;
         if (lcd_on = '1') then
            if (lcd_vsync = '1' and lcd_vsync_1 = '0') then
               pixel_out_x <= 0;
               pixel_out_y <= 0;
            elsif (lcd_mode_1 /= "11" and lcd_mode = "11") then
               pixel_out_x  <= 0;
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
            pixel_out_data <= lcd_data(4 downto 0) & lcd_data(9 downto 5) & lcd_data(14 downto 10);
         end if;
         
      end if;
   end process;
   
   -- capture serial out for mooneye tests
   process
   begin
      wait until (rising_edge(serial_clk_out) or reset = '1');
      if (reset = '1') then
         serialarray   <= (others => (others => '0'));
         serialpointer <= 0;
         testdone      <= "0";
         testok        <= "0";
      else
         serialbuffer <= serialbuffer(6 downto 0) & serial_data_out;  
         wait for 30 us;
         if (serial_clk_out = '1') then
            serialarray(serialpointer) <= serialbuffer;
            if (serialpointer < 5) then
               serialpointer <= serialpointer + 1;
            else
               testdone <= "1";
               if (serialarray(0) = x"03" and 
                  serialarray(1) = x"05" and 
                  serialarray(2) = x"08" and 
                  serialarray(3) = x"0D" and 
                  serialarray(4) = x"15") then
                  testok <= "1";
               end if;
            end if;
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
      clk               => clksys,
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
      clk         => clksys,
      command_in  => command_in, 
      command_out => command_out_filter
   );
   
end architecture;


