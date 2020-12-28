library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.pBus_savestates.all;
use work.pReg_savestates.all;

library work;
entity gbc_snd is
    port (
        clk          : in std_logic;
        ce           : in std_logic;
        reset        : in std_logic;

        is_gbc       : in std_logic;

        s1_read      : in std_logic;
        s1_write     : in std_logic;
        s1_addr      : in std_logic_vector(6 downto 0);
        s1_readdata  : out std_logic_vector(7 downto 0);
        s1_writedata : in std_logic_vector(7 downto 0);

        snd_left     : out std_logic_vector(15 downto 0);
        snd_right    : out std_logic_vector(15 downto 0);

        -- savestates              
        SaveStateBus_Din  : in     std_logic_vector(BUS_buswidth-1 downto 0);
        SaveStateBus_Adr  : in     std_logic_vector(BUS_busadr-1 downto 0);
        SaveStateBus_wren : in     std_logic;
        SaveStateBus_rst  : in     std_logic;
        SaveStateBus_Dout : out    std_logic_vector(BUS_buswidth-1 downto 0)
    );

end gbc_snd;

architecture SYN of gbc_snd is

    subtype wav_t is std_logic_vector(3 downto 0);
    type wav_arr_t is array(0 to 31) of wav_t;

    signal en_snd            : std_logic; -- Enable at base sound frequency (4.19MHz)
    signal en_snd2           : std_logic; -- Enable at clk/2
    signal en_snd4           : std_logic; -- Enable at clk/4
    signal en_512            : std_logic; -- 512Hz enable 

    signal en_snden2         : std_logic; -- Enable at clk/2
    signal en_snden4         : std_logic; -- Enable at clk/4

    signal en_len            : std_logic; -- Sample length
    signal en_len_r          : std_logic;
    signal en_env            : std_logic; -- Envelope
    signal en_sweep          : std_logic; -- Sweep

    signal snd_enable        : std_logic;

    signal sq1_swper         : std_logic_vector(2 downto 0);  -- Sq1 sweep period
    signal sq1_swdir         : std_logic;                     -- Sq1 sweep direction
    signal sq1_swdir_change  : std_logic;                     -- Sq1 sweep direction-change
    signal sq1_swshift       : std_logic_vector(2 downto 0);  -- Sq1 sweep frequency shift
    signal sq1_duty          : std_logic_vector(1 downto 0);  -- Sq1 duty cycle
    signal sq1_slen          : std_logic_vector(6 downto 0);  -- Sq1 play length
    signal sq1_svol          : std_logic_vector(3 downto 0);  -- Sq1 initial volume

    signal sq1_out           : std_logic;

    signal sq1_envsgn        : std_logic;                     -- Sq1 envelope sign
    signal sq1_envsgn_old    : std_logic;                     -- Sq1 old envelope sign (used in zombie mode)
    signal sq1_envper        : std_logic_vector(2 downto 0);  -- Sq1 envelope period
    signal sq1_envper_old    : std_logic_vector(2 downto 0);  -- Sq1 old envelope period  (used in zombie mode)
    signal sq1_freq          : std_logic_vector(10 downto 0); -- Sq1 frequency
    signal sq1_trigger       : std_logic;                     -- Sq1 trigger play note
    signal sq1_lenchk        : std_logic;                     -- Sq1 length check enable
    signal sq1_len_en_change : std_logic;                     -- Sq1 length off -> on

    signal sq1_fr2           : std_logic_vector(10 downto 0); -- Sq1 frequency (shadow copy)
    signal sq1_vol           : std_logic_vector(3 downto 0);  -- Sq1 initial volume
    signal sq1_nr2change     : std_logic;
    signal sq1_lenchange     : std_logic;
    signal sq1_lenquirk      : std_logic;
    signal sq1_freqchange    : std_logic;

    signal sq1_playing       : std_logic;                    -- Sq1 channel active
    signal sq1_wav           : std_logic_vector(5 downto 0); -- Sq1 output waveform
    signal sq1_suppressed    : std_logic;                    -- Sq1 channel 1st sample suppressed when triggered after poweron

    signal sq2_out           : std_logic;

    signal sq2_duty          : std_logic_vector(1 downto 0); -- Sq2 duty cycle
    signal sq2_slen          : std_logic_vector(6 downto 0); -- Sq2 play length
    signal sq2_svol          : std_logic_vector(3 downto 0); -- Sq2 initial volume
    signal sq2_nr2change     : std_logic;
    signal sq2_lenchange     : std_logic;
    signal sq2_lenquirk      : std_logic;
    signal sq2_envsgn        : std_logic;                     -- Sq2 envelope sign
    signal sq2_envper        : std_logic_vector(2 downto 0);  -- Sq2 envelope period
    signal sq2_envsgn_old    : std_logic;                     -- Sq2 old envelope sign (used in zombie mode)
    signal sq2_envper_old    : std_logic_vector(2 downto 0);  -- Sq2 old envelope period  (used in zombie mode)
    signal sq2_freq          : std_logic_vector(10 downto 0); -- Sq2 frequency
    signal sq2_trigger       : std_logic;                     -- Sq2 trigger play note
    signal sq2_lenchk        : std_logic;                     -- Sq2 length check enable

    signal sq2_vol           : std_logic_vector(3 downto 0);  -- Sq2 initial volume
    signal sq2_playing       : std_logic;                     -- Sq2 channel active
    signal sq2_wav           : std_logic_vector(5 downto 0);  -- Sq2 output waveform
    signal sq2_suppressed    : std_logic;                     -- Sq2 channel 1st sample suppressed when triggered after poweron
    
    signal wav_enable        : std_logic;                     -- Wave enable
    signal wav_slen          : std_logic_vector(8 downto 0);  -- Wave play length
    signal wav_lenchange     : std_logic;
    signal wav_lenquirk      : std_logic;
    signal wav_volsh         : std_logic_vector(1 downto 0);  -- Wave volume shift
    signal wav_freq          : std_logic_vector(10 downto 0); -- Wave frequency
    signal wav_trigger       : std_logic;                     -- Wave trigger play note
    signal wav_lenchk        : std_logic;                     -- Wave length check enable
    signal wav_index         : unsigned(4 downto 0);          -- Wave current sample index
    signal wav_access        : unsigned(1 downto 0);          -- Wave table access counter used for DMG
    signal wav_playing       : std_logic;
    signal wav_wav           : std_logic_vector(5 downto 0); -- Wave output waveform
    signal wav_ram           : wav_arr_t;                    -- Wave table
    signal wav_suppressed    : std_logic;                    -- wav channel 1st sample suppressed when triggered after poweron
    signal wav_wav_r         : std_logic_vector(5 downto 0); -- Wave output waveform when suppressed

    signal noi_slen          : std_logic_vector(6 downto 0);
    signal noi_lenchange     : std_logic;
    signal noi_lenquirk      : std_logic;
    signal noi_svol          : std_logic_vector(3 downto 0);
    signal noi_nr2change     : std_logic;
    signal noi_envsgn        : std_logic;
    signal noi_envper        : std_logic_vector(2 downto 0);
    signal noi_envsgn_old    : std_logic;                    -- noi old envelope sign (used in zombie mode)
    signal noi_envper_old    : std_logic_vector(2 downto 0); -- noi old envelope period  (used in zombie mode)
    signal noi_freqsh        : std_logic_vector(3 downto 0);
    signal noi_freqchange    : std_logic;
    signal noi_short         : std_logic;
    signal noi_div           : std_logic_vector(2 downto 0);
    signal noi_trigger       : std_logic;
    signal noi_lenchk        : std_logic;

    signal noi_vol           : std_logic_vector(3 downto 0); -- Noise initial volume
    signal noi_playing       : std_logic;                    -- Noise channel active
    signal noi_wav           : std_logic_vector(5 downto 0); -- Noise output waveform

    signal ch_map            : std_logic_vector(7 downto 0);
    signal ch_vol            : std_logic_vector(7 downto 0);
    signal framecnt          : integer range 0 to 7 := 0;

    signal sq1_trigger_r     : std_logic;
    signal sq2_trigger_r     : std_logic;
    signal wav_trigger_r     : std_logic;
    signal noi_trigger_r     : std_logic;
    signal s1_write_r        : std_logic;

    -- savestates
    type t_reg_wired_or is array(0 to 6) of std_logic_vector(63 downto 0);
    signal reg_wired_or : t_reg_wired_or;
    
    signal SS_Sound1          : std_logic_vector(REG_SAVESTATE_Sound1.upper downto REG_SAVESTATE_Sound1.lower);
    signal SS_Sound1_BACK     : std_logic_vector(REG_SAVESTATE_Sound1.upper downto REG_SAVESTATE_Sound1.lower);
    signal SS_Sound2          : std_logic_vector(REG_SAVESTATE_Sound2.upper downto REG_SAVESTATE_Sound2.lower);
    signal SS_Sound2_BACK     : std_logic_vector(REG_SAVESTATE_Sound2.upper downto REG_SAVESTATE_Sound2.lower);	
    signal SS_Sound3          : std_logic_vector(REG_SAVESTATE_Sound3.upper downto REG_SAVESTATE_Sound2.lower);
    signal SS_Sound3_BACK     : std_logic_vector(REG_SAVESTATE_Sound3.upper downto REG_SAVESTATE_Sound2.lower);    
         
    signal SS_Wave1           : std_logic_vector(REG_SAVESTATE_Wave1.upper downto REG_SAVESTATE_Wave1.lower);
    signal SS_Wave1_BACK      : std_logic_vector(REG_SAVESTATE_Wave1.upper downto REG_SAVESTATE_Wave1.lower);    
    signal SS_Wave2           : std_logic_vector(REG_SAVESTATE_Wave2.upper downto REG_SAVESTATE_Wave2.lower);
    signal SS_Wave2_BACK      : std_logic_vector(REG_SAVESTATE_Wave2.upper downto REG_SAVESTATE_Wave2.lower);    
    
    signal SS_Wave1_GBC       : std_logic_vector(REG_SAVESTATE_Wave1_GBC.upper downto REG_SAVESTATE_Wave1_GBC.lower);
    signal SS_Wave2_GBC       : std_logic_vector(REG_SAVESTATE_Wave2_GBC.upper downto REG_SAVESTATE_Wave2_GBC.lower);
    
begin

   iREG_SAVESTATE_Sound1     : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Sound1 ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(0), SS_Sound1_BACK, SS_Sound1);  
   iREG_SAVESTATE_Sound2     : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Sound2 ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(1), SS_Sound2_BACK, SS_Sound2);  
   iREG_SAVESTATE_Sound3     : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Sound3 ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(2), SS_Sound3_BACK, SS_Sound3);  
                             
   iREG_SAVESTATE_Wave1      : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Wave1  ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(3), SS_Wave1_BACK, SS_Wave1);  
   iREG_SAVESTATE_Wave2      : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Wave2  ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(4), SS_Wave2_BACK, SS_Wave2);  
   iREG_SAVESTATE_Wave1_GBC  : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Wave1  ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(5), SS_Wave1_BACK, SS_Wave1_GBC);  
   iREG_SAVESTATE_Wave2_GBC  : entity work.eReg_Savestate generic map ( REG_SAVESTATE_Wave2  ) port map (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, reg_wired_or(6), SS_Wave2_BACK, SS_Wave2_GBC);  
   
   
   process (reg_wired_or)
      variable wired_or : std_logic_vector(63 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      SaveStateBus_Dout <= wired_or;
   end process;

    en_snd2 <= en_snd and en_snden2;
    en_snd4 <= en_snd and en_snden4;

    process (clk)
    begin
        if rising_edge(clk) then
           if reset = '1' then
                 en_snd <= SS_Sound1(0); --'0';
           else
                 if ce = '1' then
                    en_snd <= not en_snd;
                 end if;
           end if;
      end if;
    end process;
   
   SS_Sound1_BACK(         0) <= en_snd;
   SS_Sound1_BACK(3 downto 1) <= std_logic_vector(to_unsigned(framecnt, 3));
   SS_Sound1_BACK(         4) <= en_len_r ;
   SS_Sound1_BACK(         5) <= en_snden2;
   SS_Sound1_BACK(         6) <= en_snden4;
   SS_Sound1_BACK(         7) <= en_len   ;
   SS_Sound1_BACK(         8) <= en_env   ;
   SS_Sound1_BACK(         9) <= en_sweep ;
   SS_Sound1_BACK(        10) <= en_512   ;
   

    -- Calculate divided and frame sequencer clock enables
    process (clk)
        variable clkcnt   : unsigned(1 downto 0);
        variable cnt_512  : unsigned(12 downto 0);
        variable temp_512 : unsigned(13 downto 0);
    begin
		  if rising_edge(clk) then
			  if reset = '1' then
					clkcnt  := "00";
					cnt_512 := (others => '0');
					framecnt  <= to_integer(unsigned(SS_Sound1(3 downto 1))); -- 0;
					en_len_r  <= SS_Sound1( 4);                               -- '0';
					en_snden2 <= SS_Sound1( 5);                               -- '0';
					en_snden4 <= SS_Sound1( 6);                               -- '0';
					en_len    <= SS_Sound1( 7);                               -- '0';
					en_env    <= SS_Sound1( 8);                               -- '0';
					en_sweep  <= SS_Sound1( 9);                               -- '0';
					en_512    <= SS_Sound1(10);                               -- '0';
			  elsif snd_enable = '0' then --only clock frame sequencer if sound is enabled, restart at 0 
					clkcnt  := "00";
					cnt_512 := (others => '0');
					framecnt  <= 0;
					en_len_r  <= '0';
					en_snden2 <= '0';
					en_snden4 <= '0';
					en_len    <= '0';
					en_env    <= '0';
					en_sweep  <= '0';
					en_512    <= '0';
			  else
					if ce = '1' then
						 -- Base clock divider
						 if en_snd = '1' then
							  clkcnt := clkcnt + 1;
							  if clkcnt(0) = '1' then
									en_snden2 <= '1';
							  else
									en_snden2 <= '0';
							  end if;
							  if clkcnt = "11" then
									en_snden4 <= '1';
							  else
									en_snden4 <= '0';
							  end if;
						 end if;

						 -- Frame sequencer (length, envelope, sweep) clock enables
						 en_len   <= '0';
						 en_env   <= '0';
						 en_sweep <= '0';
						 if en_512 = '1' then
							  en_len_r <= not en_len_r;
							  if framecnt = 0 or framecnt = 2 or framecnt = 4 or framecnt = 6 then
									en_len   <= '1';
									en_len_r <= not en_len_r;
							  end if;
							  if framecnt = 2 or framecnt = 6 then
									en_sweep <= '1';
							  end if;
							  if framecnt = 7 then
									en_env <= '1';
							  end if;

							  if framecnt < 7 then
									framecnt <= framecnt + 1;
							  else
									framecnt <= 0;
							  end if;
						 end if;

						 --
						 en_512 <= '0';
						 if en_snd = '1' then
							  temp_512 := ('0' & cnt_512) + to_unsigned(1, temp_512'length);
							  cnt_512  := temp_512(temp_512'high - 1 downto temp_512'low);
							  en_512 <= temp_512(13);
						 end if;
					end if;
			  end if;
		  end if;
    end process;
   
   SS_Sound1_BACK(13 downto 11) <= sq1_swper  ;
   SS_Sound1_BACK(          14) <= sq1_swdir  ;
   SS_Sound1_BACK(17 downto 15) <= sq1_swshift;
   SS_Sound1_BACK(19 downto 18) <= sq1_duty   ;
   --SS_Sound1_BACK(25 downto 20) <= sq1_slen   ;  size increased, now in sound3 below
   SS_Sound1_BACK(25 downto 20) <= (others => '0');
   SS_Sound1_BACK(29 downto 26) <= sq1_svol   ;
   SS_Sound1_BACK(          30) <= sq1_envsgn ;
   SS_Sound1_BACK(33 downto 31) <= sq1_envper ;
   SS_Sound1_BACK(44 downto 34) <= sq1_freq   ;
   SS_Sound1_BACK(          45) <= sq1_lenchk ;
   SS_Sound1_BACK(          46) <= sq1_trigger;
                     
   SS_Sound1_BACK(48 downto 47) <= sq2_duty   ;
   SS_Sound1_BACK(55 downto 49) <= sq2_slen   ;
   SS_Sound1_BACK(59 downto 56) <= sq2_svol   ;
   SS_Sound1_BACK(          60) <= sq2_envsgn ;
   SS_Sound1_BACK(63 downto 61) <= sq2_envper ;
   SS_Sound2_BACK(10 downto  0) <= sq2_freq   ;
   SS_Sound2_BACK(          11) <= sq2_lenchk ;
   SS_Sound2_BACK(          12) <= sq2_trigger;
               
   SS_Sound2_BACK(          13) <= wav_enable ;
   SS_Sound2_BACK(15 downto 14) <= wav_volsh  ;
   SS_Sound2_BACK(26 downto 16) <= wav_freq   ;
   SS_Sound2_BACK(          27) <= wav_trigger;
   SS_Sound2_BACK(          28) <= wav_lenchk ;
               
   SS_Sound2_BACK(35 downto 29) <= noi_slen   ;
   SS_Sound2_BACK(39 downto 36) <= noi_svol   ;
   SS_Sound2_BACK(          40) <= noi_envsgn ;
   SS_Sound2_BACK(43 downto 41) <= noi_envper ;
   SS_Sound2_BACK(47 downto 44) <= noi_freqsh ;
   SS_Sound2_BACK(          48) <= noi_short  ;
   SS_Sound2_BACK(51 downto 49) <= noi_div    ;
   SS_Sound2_BACK(          52) <= noi_trigger;
   SS_Sound2_BACK(          53) <= noi_lenchk ;
               
   SS_Sound2_BACK(          54) <= snd_enable ;
               
   SS_Sound3_BACK( 7 downto  0) <= ch_map;
   SS_Sound3_BACK(15 downto  8) <= ch_vol;
   SS_Sound3_BACK(22 downto 16) <= sq1_slen;
   
   SS_Wave1_BACK(3  downto  0) <= wav_ram(0) ;
   SS_Wave1_BACK(7  downto  4) <= wav_ram(1) ;
   SS_Wave1_BACK(11 downto  8) <= wav_ram(2) ;
   SS_Wave1_BACK(15 downto 12) <= wav_ram(3) ;
   SS_Wave1_BACK(19 downto 16) <= wav_ram(4) ;
   SS_Wave1_BACK(23 downto 20) <= wav_ram(5) ;
   SS_Wave1_BACK(27 downto 24) <= wav_ram(6) ;
   SS_Wave1_BACK(31 downto 28) <= wav_ram(7) ;
   SS_Wave1_BACK(35 downto 32) <= wav_ram(8) ;
   SS_Wave1_BACK(39 downto 36) <= wav_ram(9) ;
   SS_Wave1_BACK(43 downto 40) <= wav_ram(10);
   SS_Wave1_BACK(47 downto 44) <= wav_ram(11);
   SS_Wave1_BACK(51 downto 48) <= wav_ram(12);
   SS_Wave1_BACK(55 downto 52) <= wav_ram(13);
   SS_Wave1_BACK(59 downto 56) <= wav_ram(14);
   SS_Wave1_BACK(63 downto 60) <= wav_ram(15);
   SS_Wave2_BACK(3  downto  0) <= wav_ram(16);
   SS_Wave2_BACK(7  downto  4) <= wav_ram(17);
   SS_Wave2_BACK(11 downto  8) <= wav_ram(18);
   SS_Wave2_BACK(15 downto 12) <= wav_ram(19);
   SS_Wave2_BACK(19 downto 16) <= wav_ram(20);
   SS_Wave2_BACK(23 downto 20) <= wav_ram(21);
   SS_Wave2_BACK(27 downto 24) <= wav_ram(22);
   SS_Wave2_BACK(31 downto 28) <= wav_ram(23);
   SS_Wave2_BACK(35 downto 32) <= wav_ram(24);
   SS_Wave2_BACK(39 downto 36) <= wav_ram(25);
   SS_Wave2_BACK(43 downto 40) <= wav_ram(26);
   SS_Wave2_BACK(47 downto 44) <= wav_ram(27);
   SS_Wave2_BACK(51 downto 48) <= wav_ram(28);
   SS_Wave2_BACK(55 downto 52) <= wav_ram(29);
   SS_Wave2_BACK(59 downto 56) <= wav_ram(30);
   SS_Wave2_BACK(63 downto 60) <= wav_ram(31);

    -- Registers
    registers : process (clk)
        variable sq1_trigger_cnt : unsigned(2 downto 0);
        variable sq2_trigger_cnt : unsigned(2 downto 0);
        variable noi_trigger_cnt : unsigned(2 downto 0);
        variable wav_trigger_cnt : unsigned(1 downto 0);
        variable wave_index_write : std_logic_vector(3 downto 0);
    begin

        if rising_edge(clk) then
			  -- Registers
			  if reset = '1' then
					-- Reset register values
					sq1_swper   <= SS_Sound1(13 downto 11); --(others => '0');
					sq1_swdir   <= SS_Sound1(          14); --'0';
					sq1_swshift <= SS_Sound1(17 downto 15); --(others => '0');
					sq1_duty    <= SS_Sound1(19 downto 18); --(others => '0');
					sq1_slen    <= SS_Sound3(22 downto 16); --(others => '0');
					sq1_svol    <= SS_Sound1(29 downto 26); --(others => '0');
					sq1_envsgn  <= SS_Sound1(          30); --'0';
					sq1_envper  <= SS_Sound1(33 downto 31); --(others => '0');
					sq1_freq    <= SS_Sound1(44 downto 34); --(others => '0');
					sq1_lenchk  <= SS_Sound1(          45); --'0';
					sq1_trigger <= SS_Sound1(          46); --'0';

					sq2_duty    <= SS_Sound1(48 downto 47); --(others => '0');
					sq2_slen    <= SS_Sound1(55 downto 49); --(others => '0');
					sq2_svol    <= SS_Sound1(59 downto 56); --(others => '0');
					sq2_envsgn  <= SS_Sound1(          60); --'0';
					sq2_envper  <= SS_Sound1(63 downto 61); --(others => '0');
					sq2_freq    <= SS_Sound2(10 downto  0); --(others => '0');
					sq2_lenchk  <= SS_Sound2(          11); --'0';
					sq2_trigger <= SS_Sound2(          12); --'0';

					wav_enable  <= SS_Sound2(          13); --'0';
					wav_volsh   <= SS_Sound2(15 downto 14); --(others => '0');
					wav_freq    <= SS_Sound2(26 downto 16); --(others => '0');
					wav_trigger <= SS_Sound2(          27); --'0';
					wav_lenchk  <= SS_Sound2(          28); --'0';
					sq1_trigger_cnt := (others => '0'); --counter to delay the trigger
					sq2_trigger_cnt := (others => '0'); --counter to delay the trigger
					wav_trigger_cnt := (others => '0'); --counter to delay the trigger
					noi_trigger_cnt := (others => '0'); --counter to delay the trigger
					noi_slen    <= SS_Sound2(35 downto 29); --(others     => '0');
					noi_svol    <= SS_Sound2(39 downto 36); --(others     => '0');
					noi_envsgn  <= SS_Sound2(          40); --'0';
					noi_envper  <= SS_Sound2(43 downto 41); --(others => '0');
					noi_freqsh  <= SS_Sound2(47 downto 44); --(others => '0');
					noi_short   <= SS_Sound2(          48); --'0';
					noi_div     <= SS_Sound2(51 downto 49); --(others => '0');
					noi_trigger <= SS_Sound2(          52); --'0';
					noi_lenchk  <= SS_Sound2(          53); --'0';
					
					ch_map      <= SS_Sound3( 7 downto  0); --(others => '0');
					ch_vol      <= SS_Sound3(15 downto  8); --(others => '0');

					s1_write_r <= '0';
					--      Wave table   https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware#Power_Control
					if is_gbc = '1' then
						 wav_ram(0) <=  SS_Wave1_GBC(3  downto  0); --X"0";
						 wav_ram(1) <=  SS_Wave1_GBC(7  downto  4); --X"0";
						 wav_ram(2) <=  SS_Wave1_GBC(11 downto  8); --X"F";
						 wav_ram(3) <=  SS_Wave1_GBC(15 downto 12); --X"F";
						 wav_ram(4) <=  SS_Wave1_GBC(19 downto 16); --X"0";
						 wav_ram(5) <=  SS_Wave1_GBC(23 downto 20); --X"0";
						 wav_ram(6) <=  SS_Wave1_GBC(27 downto 24); --X"F";
						 wav_ram(7) <=  SS_Wave1_GBC(31 downto 28); --X"F";
						 wav_ram(8) <=  SS_Wave1_GBC(35 downto 32); --X"0";
						 wav_ram(9) <=  SS_Wave1_GBC(39 downto 36); --X"0";
						 wav_ram(10) <= SS_Wave1_GBC(43 downto 40); --X"F";
						 wav_ram(11) <= SS_Wave1_GBC(47 downto 44); --X"F";
						 wav_ram(12) <= SS_Wave1_GBC(51 downto 48); --X"0";
						 wav_ram(13) <= SS_Wave1_GBC(55 downto 52); --X"0";
						 wav_ram(14) <= SS_Wave1_GBC(59 downto 56); --X"F";
						 wav_ram(15) <= SS_Wave1_GBC(63 downto 60); --X"F";
						 wav_ram(16) <= SS_Wave2_GBC(3  downto  0); --X"0";
						 wav_ram(17) <= SS_Wave2_GBC(7  downto  4); --X"0";
						 wav_ram(18) <= SS_Wave2_GBC(11 downto  8); --X"F";
						 wav_ram(19) <= SS_Wave2_GBC(15 downto 12); --X"F";
						 wav_ram(20) <= SS_Wave2_GBC(19 downto 16); --X"0";
						 wav_ram(21) <= SS_Wave2_GBC(23 downto 20); --X"0";
						 wav_ram(22) <= SS_Wave2_GBC(27 downto 24); --X"F";
						 wav_ram(23) <= SS_Wave2_GBC(31 downto 28); --X"F";
						 wav_ram(24) <= SS_Wave2_GBC(35 downto 32); --X"0";
						 wav_ram(25) <= SS_Wave2_GBC(39 downto 36); --X"0";
						 wav_ram(26) <= SS_Wave2_GBC(43 downto 40); --X"F";
						 wav_ram(27) <= SS_Wave2_GBC(47 downto 44); --X"F";
						 wav_ram(28) <= SS_Wave2_GBC(51 downto 48); --X"0";
						 wav_ram(29) <= SS_Wave2_GBC(55 downto 52); --X"0";
						 wav_ram(30) <= SS_Wave2_GBC(59 downto 56); --X"F";
						 wav_ram(31) <= SS_Wave2_GBC(63 downto 60); --X"F";
					else
						 wav_ram(0) <=  SS_Wave1(3  downto  0); --X"8";
						 wav_ram(1) <=  SS_Wave1(7  downto  4); --X"4";
						 wav_ram(2) <=  SS_Wave1(11 downto  8); --X"4";
						 wav_ram(3) <=  SS_Wave1(15 downto 12); --X"0";
						 wav_ram(4) <=  SS_Wave1(19 downto 16); --X"4";
						 wav_ram(5) <=  SS_Wave1(23 downto 20); --X"3";
						 wav_ram(6) <=  SS_Wave1(27 downto 24); --X"A";
						 wav_ram(7) <=  SS_Wave1(31 downto 28); --X"A";
						 wav_ram(8) <=  SS_Wave1(35 downto 32); --X"2";
						 wav_ram(9) <=  SS_Wave1(39 downto 36); --X"D";
						 wav_ram(10) <= SS_Wave1(43 downto 40); --X"7";
						 wav_ram(11) <= SS_Wave1(47 downto 44); --X"8";
						 wav_ram(12) <= SS_Wave1(51 downto 48); --X"9";
						 wav_ram(13) <= SS_Wave1(55 downto 52); --X"2";
						 wav_ram(14) <= SS_Wave1(59 downto 56); --X"3";
						 wav_ram(15) <= SS_Wave1(63 downto 60); --X"C";
						 wav_ram(16) <= SS_Wave2(3  downto  0); --X"6";
						 wav_ram(17) <= SS_Wave2(7  downto  4); --X"0";
						 wav_ram(18) <= SS_Wave2(11 downto  8); --X"5";
						 wav_ram(19) <= SS_Wave2(15 downto 12); --X"9";
						 wav_ram(20) <= SS_Wave2(19 downto 16); --X"5";
						 wav_ram(21) <= SS_Wave2(23 downto 20); --X"9";
						 wav_ram(22) <= SS_Wave2(27 downto 24); --X"B";
						 wav_ram(23) <= SS_Wave2(31 downto 28); --X"0";
						 wav_ram(24) <= SS_Wave2(35 downto 32); --X"3";
						 wav_ram(25) <= SS_Wave2(39 downto 36); --X"4";
						 wav_ram(26) <= SS_Wave2(43 downto 40); --X"B";
						 wav_ram(27) <= SS_Wave2(47 downto 44); --X"8";
						 wav_ram(28) <= SS_Wave2(51 downto 48); --X"2";
						 wav_ram(29) <= SS_Wave2(55 downto 52); --X"E";
						 wav_ram(30) <= SS_Wave2(59 downto 56); --X"D";
						 wav_ram(31) <= SS_Wave2(63 downto 60); --X"A";          
					end if;           

					snd_enable <= SS_Sound2(54); -- '0';

			  else
					if ce = '1' then
						 
						 if en_snd2 = '1' then                            
							  if sq1_trigger_cnt = "000" then
									sq1_trigger <= '0';
							  else
									sq1_trigger_cnt := sq1_trigger_cnt - 1;
							  end if;

							  if sq2_trigger_cnt = "000" then
									sq2_trigger <= '0';
							  else
									sq2_trigger_cnt := sq2_trigger_cnt - 1;
							  end if;

							  if wav_trigger_cnt = "00" then
									wav_trigger <= '0';
								 else
									wav_trigger_cnt := wav_trigger_cnt - 1;
							  end if;

							  if noi_trigger_cnt = "000" then
									noi_trigger <= '0';
							  else
									noi_trigger_cnt := noi_trigger_cnt - 1;
							  end if;
						 end if;

						
						 sq2_nr2change    <= '0';
						 sq1_nr2change    <= '0';
						 noi_nr2change    <= '0';
						 noi_freqchange   <= '0';

						 sq2_lenchange    <= '0';
						 sq1_lenchange    <= '0';
						 wav_lenchange    <= '0';
						 noi_lenchange    <= '0';
						 sq1_lenquirk     <= '0';
						 sq2_lenquirk     <= '0';
						 wav_lenquirk     <= '0';
						 noi_lenquirk     <= '0';
						 sq1_swdir_change <= '0';

						 if sq1_freqchange = '1' then
							  sq1_freq <= sq1_fr2;
						 end if;

						 s1_write_r <= s1_write;  -- check posedge
						 
						 -- write to registers ignored when the apu is off , Wave memory can be read back freely , NR52 power control is always writable 
						 if s1_write = '1' and s1_write_r = '0' and (snd_enable = '1' or s1_addr = "0100110" or s1_addr(5 downto 4) = "11" or (is_gbc = '0' and (s1_addr = "0010001" or  s1_addr = "0010110" or s1_addr = "0011011" or s1_addr = "0100000" ))) then
							  case s1_addr is
										 -- Square 1
									when "0010000" => -- NR10 FF10 -PPP NSSS Sweep period, negate, shift
										 sq1_swper <= s1_writedata(6 downto 4);
										 if s1_writedata(3) = '0' then -- only neg to pos, 1 -> 0
											  sq1_swdir_change <= '1';
										 end if;
										 sq1_swdir   <= s1_writedata(3);
										 sq1_swshift <= s1_writedata(2 downto 0);
									when "0010001" => -- NR11 FF11 DDLL LLLL Duty, Length load (64-L)
										 if snd_enable = '1' then
											  sq1_duty      <= s1_writedata(7 downto 6);
										 end if;
										 sq1_slen      <= std_logic_vector("1000000" - unsigned(s1_writedata(5 downto 0)));
										 sq1_lenchange <= '1';
									when "0010010" => -- NR12 FF12 VVVV APPP Starting volume, Envelope add mode, period
										 -- zombie mode copy old values
										 sq1_envsgn_old <= sq1_envsgn;
										 sq1_envper_old <= sq1_envper;
										 -- write to registers
										 sq1_nr2change  <= '1';
										 sq1_svol       <= s1_writedata(7 downto 4);
										 sq1_envsgn     <= s1_writedata(3);
										 sq1_envper     <= s1_writedata(2 downto 0);
									when "0010011" => -- NR13 FF13 FFFF FFFF Frequency LSB
										 sq1_freq(7 downto 0) <= s1_writedata;
									when "0010100" => -- NR14 FF14 TL-- -FFF Trigger, Length enable, Frequency MSB                           
										 sq1_trigger <= s1_writedata(7);
										 if s1_writedata(7) = '1' then
											  if sq1_playing = '1' then
													sq1_trigger_cnt := "010";  -- --according to sameboy : Timing quirk: if already active, sound starts 2 (2MHz) ticks earlier.
											  else
													sq1_trigger_cnt := "100";
											  end if;
										 end if;
										 if sq1_lenchk = '0' and s1_writedata(6) = '1' and en_len_r = '1' then
											  sq1_lenquirk <= '1';
										 end if;
										 sq1_lenchk            <= s1_writedata(6);
										 sq1_freq(10 downto 8) <= s1_writedata(2 downto 0);

										 -- Square 2
									when "0010110" => -- NR21 FF16 DDLL LLLL Duty, Length load (64-L)
										 if snd_enable = '1' then
											  sq2_duty      <= s1_writedata(7 downto 6);
										 end if;
										 sq2_slen      <= std_logic_vector("1000000" - unsigned(s1_writedata(5 downto 0)));
										 sq2_lenchange <= '1';
									when "0010111" => -- NR22 FF17 VVVV APPP Starting volume, Envelope add mode, period
										 -- zombie mode copy old values
										 sq2_envsgn_old <= sq2_envsgn;
										 sq2_envper_old <= sq2_envper;
										 -- write to registers
										 sq2_svol       <= s1_writedata(7 downto 4);
										 sq2_nr2change  <= '1';
										 sq2_envsgn     <= s1_writedata(3);
										 sq2_envper     <= s1_writedata(2 downto 0);
									when "0011000" => -- NR23 FF18 FFFF FFFF Frequency LSB
										 sq2_freq(7 downto 0) <= s1_writedata;
									when "0011001" => -- NR24 FF19 TL-- -FFF Trigger, Length enable, Frequency MSB                                                   
										 sq2_trigger <= s1_writedata(7);
										 if s1_writedata(7) = '1' then
											  if sq2_playing = '1' then
													sq2_trigger_cnt := "010"; -- according to sameboy : Timing quirk: if already active, sound starts 2 (2MHz) ticks earlier.
											  else
													sq2_trigger_cnt := "100";
											  end if;
										 end if;
										 if sq2_lenchk = '0' and s1_writedata(6) = '1' and en_len_r = '1' then
											  sq2_lenquirk <= '1';
										 end if;
										 sq2_lenchk            <= s1_writedata(6);
										 sq2_freq(10 downto 8) <= s1_writedata(2 downto 0);

										 -- Wave
									when "0011010" => -- NR30 FF1A E--- ---- DAC power
										 wav_enable <= s1_writedata(7);
									when "0011011" => -- NR31 FF1B LLLL LLLL Length load (256-L)
										 -- wav_slen <= s1_writedata;
										 wav_slen      <= std_logic_vector("100000000" - unsigned(s1_writedata));
										 wav_lenchange <= '1';
									when "0011100" => -- NR32 FF1C -VV- ---- Volume code (00=0%, 01=100%, 10=50%, 11=25%)
										 wav_volsh <= s1_writedata(6 downto 5);
									when "0011101" => -- NR33 FF1D FFFF FFFF Frequency LSB
										 wav_freq(7 downto 0) <= s1_writedata;
									when "0011110" => -- NR34 FF1E TL-- -FFF Trigger, Length enable, Frequency MSB
										 wav_trigger <= s1_writedata(7);
										 if s1_writedata(7) = '1' then
											  wav_trigger_cnt := "10";
										 end if;
										 if wav_lenchk = '0' and s1_writedata(6) = '1' and en_len_r = '1' then
											  wav_lenquirk <= '1';
										 end if;
										 wav_lenchk            <= s1_writedata(6);
										 wav_freq(10 downto 8) <= s1_writedata(2 downto 0);

										 -- Noise
									when "0100000" => -- NR41 FF20 --LL LLLL Length load (64-L)
										 noi_slen      <= std_logic_vector("1000000" - unsigned(s1_writedata(5 downto 0)));
										 noi_lenchange <= '1';
									when "0100001" => -- NR42 FF21 VVVV APPP Starting volume, Envelope add mode, period
										 -- zombie mode copy old values
										 noi_envsgn_old <= noi_envsgn;
										 noi_envper_old <= noi_envper;
										 -- write to registers
										 noi_svol       <= s1_writedata(7 downto 4);
										 noi_nr2change  <= '1';
										 noi_envsgn     <= s1_writedata(3);
										 noi_envper     <= s1_writedata(2 downto 0);
									when "0100010" => -- NR43 FF22 SSSS WDDD Clock shift, Width mode of LFSR, Divisor code
										 noi_freqsh     <= s1_writedata(7 downto 4);
										 noi_short      <= s1_writedata(3);
										 noi_div        <= s1_writedata(2 downto 0);
										 noi_freqchange <= '1';
									when "0100011" => -- NR44 FF23 TL-- ---- Trigger, Length enable
										 noi_trigger <= s1_writedata(7);
										 if s1_writedata(7) = '1' then
											  if noi_playing = '0' then
													noi_trigger_cnt := "010";
											  else
													noi_trigger_cnt := "100"; --noi seems to start later instead of early if already playing
											  end if;
										 end if;
										 if noi_lenchk = '0' and s1_writedata(6) = '1' and en_len_r = '1' then
											  noi_lenquirk <= '1';
										 end if;
										 noi_lenchk              <= s1_writedata(6);

										 -- Control/Status
									when "0100100" => ch_vol <= s1_writedata; -- NR50 FF24
									when "0100101" => ch_map <= s1_writedata; -- NR51 FF25

										 -- Wave Table
									when "0110000" | "0110001" | "0110010" | "0110011" | "0110100" | "0110101" | "0110110" | "0110111" | "0111000" | "0111001" | "0111010" | "0111011" | "0111100" | "0111101" | "0111110" | "0111111" => -- FF30 to FF3F
										 if wav_playing = '1' then
											  wave_index_write := std_logic_vector(wav_index(4 downto 1));
										 else
											  wave_index_write := s1_addr(3 downto 0);
										 end if;
					
										 if is_gbc = '1' or wav_access > 0 or wav_playing = '0' then
											  case wave_index_write is
											  when "0000" => --      FF30 0000 1111 Samples 0 and 1
													wav_ram(0) <= s1_writedata(7 downto 4);
													wav_ram(1) <= s1_writedata(3 downto 0);
											  when "0001" => --      FF31 0000 1111 Samples 2 and 3
													wav_ram(2) <= s1_writedata(7 downto 4);
													wav_ram(3) <= s1_writedata(3 downto 0);
											  when "0010" => --      FF32 0000 1111 Samples 4 and 5
													wav_ram(4) <= s1_writedata(7 downto 4);
													wav_ram(5) <= s1_writedata(3 downto 0);
											  when "0011" => --      FF33 0000 1111 Samples 6 and 31
													wav_ram(6) <= s1_writedata(7 downto 4);
													wav_ram(7) <= s1_writedata(3 downto 0);
											  when "0100" => --      FF34 0000 1111 Samples 8 and 31
													wav_ram(8) <= s1_writedata(7 downto 4);
													wav_ram(9) <= s1_writedata(3 downto 0);
											  when "0101" => --      FF35 0000 1111 Samples 10 and 11
													wav_ram(10) <= s1_writedata(7 downto 4);
													wav_ram(11) <= s1_writedata(3 downto 0);
											  when "0110" => --      FF36 0000 1111 Samples 12 and 13
													wav_ram(12) <= s1_writedata(7 downto 4);
													wav_ram(13) <= s1_writedata(3 downto 0);
											  when "0111" => --      FF37 0000 1111 Samples 14 and 15
													wav_ram(14) <= s1_writedata(7 downto 4);
													wav_ram(15) <= s1_writedata(3 downto 0);
											  when "1000" => --      FF38 0000 1111 Samples 16 and 17
													wav_ram(16) <= s1_writedata(7 downto 4);
													wav_ram(17) <= s1_writedata(3 downto 0);
											  when "1001" => --      FF39 0000 1111 Samples 18 and 19
													wav_ram(18) <= s1_writedata(7 downto 4);
													wav_ram(19) <= s1_writedata(3 downto 0);
											  when "1010" => --      FF3A 0000 1111 Samples 20 and 21
													wav_ram(20) <= s1_writedata(7 downto 4);
													wav_ram(21) <= s1_writedata(3 downto 0);
											  when "1011" => --      FF3B 0000 1111 Samples 22 and 23
													wav_ram(22) <= s1_writedata(7 downto 4);
													wav_ram(23) <= s1_writedata(3 downto 0);
											  when "1100" => --      FF3C 0000 1111 Samples 24 and 25
													wav_ram(24) <= s1_writedata(7 downto 4);
													wav_ram(25) <= s1_writedata(3 downto 0);
											  when "1101" => --      FF3D 0000 1111 Samples 26 and 27
													wav_ram(26) <= s1_writedata(7 downto 4);
													wav_ram(27) <= s1_writedata(3 downto 0);
											  when "1110" => --      FF3E 0000 1111 Samples 28 and 29
													wav_ram(28) <= s1_writedata(7 downto 4);
													wav_ram(29) <= s1_writedata(3 downto 0);
											  when "1111" => --      FF3F 0000 1111 Samples 30 and 31
													wav_ram(30) <= s1_writedata(7 downto 4);
													wav_ram(31) <= s1_writedata(3 downto 0);
											  when others => null;
											  end case;
										 end if;

									-- NR52 FF26 P--- NW21 Power control/status, Channel length statuses
									when "0100110" => 
										 snd_enable <= s1_writedata(7);
										 if s1_writedata(7) = '0' then
											  -- Reset register values
											  sq1_swper   <= (others => '0');
											  sq1_swdir   <= '0';
											  sq1_swshift <= (others => '0');
											  sq1_duty    <= (others => '0');
											  
											  sq1_svol    <= (others => '0');
											  sq1_envsgn  <= '0';
											  sq1_envper  <= (others => '0');
											  sq1_freq    <= (others => '0');
											  sq1_lenchk  <= '0';
											  sq1_trigger <= '0';

											  sq2_duty    <= (others => '0');
											  sq2_svol    <= (others => '0');
											  sq2_envsgn  <= '0';
											  sq2_envper  <= (others => '0');
											  sq2_freq    <= (others => '0');
											  sq2_lenchk  <= '0';
											  sq2_trigger <= '0';

											  wav_enable      <= '0';
											  wav_volsh       <= (others => '0');
											  wav_freq        <= (others => '0');
											  wav_trigger     <= '0';
											  wav_lenchk      <= '0';

											  sq1_trigger_cnt := (others => '0'); --counter to leave the trigger high for a few cycles
											  sq2_trigger_cnt := (others => '0'); --counter to leave the trigger high for a few cycles
											  wav_trigger_cnt := (others => '0'); --counter to leave the trigger high for a few cycles
											  noi_trigger_cnt := (others => '0'); --counter to leave the trigger high for a few cycles

											  noi_svol    <= (others     => '0');
											  noi_envsgn  <= '0';
											  noi_envper  <= (others => '0');
											  noi_freqsh  <= (others => '0');
											  noi_short   <= '0';
											  noi_div     <= (others => '0');
											  noi_trigger <= '0';
											  noi_lenchk  <= '0';
											  
											  ch_map      <= (others => '0');
											  ch_vol      <= (others => '0');
											  s1_write_r  <= '0';
											  
											  if is_gbc = '1' then
													sq1_slen    <= (others => '0');
													sq2_slen    <= (others => '0');
													wav_slen    <= (others => '0');
													noi_slen    <= (others => '0');
											  end if;

										 end if;

									when others =>
										 null;
							  end case;
						 end if;
					end if;

			  end if;
		  end if;

    end process;

    process (s1_addr, sq1_swper, sq1_swdir, sq1_swshift, sq1_duty, sq1_svol, sq1_envsgn, sq1_envper, sq1_lenchk,
        noi_playing, wav_playing, sq2_playing, sq1_playing, wav_enable, wav_volsh, wav_ram, wav_index, wav_access,
        sq2_duty, sq2_svol, sq2_envsgn, sq2_envper, sq2_lenchk, snd_enable, wav_lenchk, noi_svol, noi_envsgn, noi_envper,
        noi_freqsh, noi_short, noi_div, noi_lenchk, ch_vol, ch_map, is_gbc, sq1_wav, sq2_wav, wav_wav, noi_wav)
        variable wave_index_read : std_logic_vector(3 downto 0);
    begin
        case s1_addr is
                -- Square 1
            when "0010000" => -- NR10 FF10 -PPP NSSS Sweep period, negate, shift
                s1_readdata <= '1' & sq1_swper & sq1_swdir & sq1_swshift;
            when "0010001" => -- NR11 FF11 DDLL LLLL Duty, Length load (64-L)
                s1_readdata <= sq1_duty & "111111";
            when "0010010" => -- NR12 FF12 VVVV APPP Starting volume, Envelope add mode, period
                s1_readdata <= sq1_svol & sq1_envsgn & sq1_envper;
            when "0010011" => -- NR13 FF13 FFFF FFFF Frequency LSB
                s1_readdata <= X"FF";
            when "0010100" => -- NR14 FF14 TL-- -FFF Trigger, Length enable, Frequency MSB
                s1_readdata <= '1' & sq1_lenchk & "111111";

                -- Square 2
            when "0010110" => -- NR21 FF16 DDLL LLLL Duty, Length load (64-L)
                s1_readdata <= sq2_duty & "111111";
            when "0010111" => -- NR22 FF17 VVVV APPP Starting volume, Envelope add mode, period
                s1_readdata <= sq2_svol & sq2_envsgn & sq2_envper;
            when "0011000" => -- NR23 FF18 FFFF FFFF Frequency LSB
                s1_readdata <= X"FF";
            when "0011001" => -- NR24 FF19 TL-- -FFF Trigger, Length enable, Frequency MSB
                s1_readdata <= '1' & sq2_lenchk & "111111";

            when "0100110" => -- NR52 FF26 P--- NW21 Power control/status, Channel length statuses
                s1_readdata <= snd_enable & "111" & noi_playing & wav_playing & sq2_playing & sq1_playing;

                -- Wave
            when "0011010" => -- NR30 FF1A E--- ---- DAC power
                s1_readdata <= wav_enable & "1111111";
            when "0011011" => -- NR31 FF1B LLLL LLLL Length load (256-L)
                s1_readdata <= X"FF";
            when "0011100" => -- NR32 FF1C -VV- ---- Volume code (00=0%, 01=100%, 10=50%, 11=25%)
                s1_readdata <= '1' & wav_volsh & "11111";
            when "0011101" => -- NR33 FF1D FFFF FFFF Frequency LSB
                s1_readdata <= X"FF";
            when "0011110" => -- NR34 FF1E TL-- -FFF Trigger, Length enable, Frequency MSB
                s1_readdata <= '1' & wav_lenchk & "111111";

                -- Noise
            when "0100000" => -- NR41 FF20 --LL LLLL Length load (64-L)
                s1_readdata <= X"FF";
            when "0100001" => -- NR42 FF21 VVVV APPP Starting volume, Envelope add mode, period
                s1_readdata <= noi_svol & noi_envsgn & noi_envper;
            when "0100010" => -- NR43 FF22 SSSS WDDD Clock shift, Width mode of LFSR, Divisor code
                s1_readdata <= noi_freqsh & noi_short & noi_div;
            when "0100011" => -- NR44 FF23 TL-- ---- Trigger, Length enable
                s1_readdata <= '1' & noi_lenchk & "111111";

                -- Wave Table
            when "0110000" | "0110001" | "0110010" | "0110011" | "0110100" | "0110101" | "0110110" | "0110111" | "0111000" | "0111001" | "0111010" | "0111011" | "0111100" | "0111101" | "0111110" | "0111111" => -- FF30 to FF3F
                if wav_playing = '1' then
                    wave_index_read := std_logic_vector(wav_index(4 downto 1));
                else
                    wave_index_read := s1_addr(3 downto 0);
                end if;

                if is_gbc = '1' or wav_access > 0 or wav_playing = '0' then
                    case wave_index_read is
                        when "0000" => --      FF30 0000 1111 Samples 0 and 1
                            s1_readdata <= wav_ram(0) & wav_ram(1);
                        when "0001" => --      FF31 0000 1111 Samples 2 and 3
                            s1_readdata <= wav_ram(2) & wav_ram(3);
                        when "0010" => --      FF32 0000 1111 Samples 4 and 5
                            s1_readdata <= wav_ram(4) & wav_ram(5);
                        when "0011" => --      FF33 0000 1111 Samples 6 and 7
                            s1_readdata <= wav_ram(6) & wav_ram(7);
                        when "0100" => --      FF34 0000 1111 Samples 8 and 9
                            s1_readdata <= wav_ram(8) & wav_ram(9);
                        when "0101" => --      FF35 0000 1111 Samples 10 and 11
                            s1_readdata <= wav_ram(10) & wav_ram(11);
                        when "0110" => --      FF36 0000 1111 Samples 12 and 13
                            s1_readdata <= wav_ram(12) & wav_ram(13);
                        when "0111" => --      FF37 0000 1111 Samples 14 and 15
                            s1_readdata <= wav_ram(14) & wav_ram(15);
                        when "1000" => --      FF38 0000 1111 Samples 16 and 17
                            s1_readdata <= wav_ram(16) & wav_ram(17);
                        when "1001" => --      FF39 0000 1111 Samples 18 and 19
                            s1_readdata <= wav_ram(18) & wav_ram(19);
                        when "1010" => --      FF3A 0000 1111 Samples 20 and 21
                            s1_readdata <= wav_ram(20) & wav_ram(21);
                        when "1011" => --      FF3B 0000 1111 Samples 22 and 23
                            s1_readdata <= wav_ram(22) & wav_ram(23);
                        when "1100" => --      FF3C 0000 1111 Samples 24 and 25
                            s1_readdata <= wav_ram(24) & wav_ram(25);
                        when "1101" => --      FF3D 0000 1111 Samples 26 and 27
                            s1_readdata <= wav_ram(26) & wav_ram(27);
                        when "1110" => --      FF3E 0000 1111 Samples 28 and 29
                            s1_readdata <= wav_ram(28) & wav_ram(29);
                        when "1111" => --      FF3F 0000 1111 Samples 30 and 31
                            s1_readdata <= wav_ram(30) & wav_ram(31);
                        when others => null;
                    end case;
                else
                    s1_readdata <= X"FF";
                end if;

                -- Control/Status
            when "0100100" =>
                s1_readdata <= ch_vol; -- NR50 FF24
            when "0100101" =>
                s1_readdata <= ch_map; -- NR51 FF25
            
                -- Undocumented Registers
            when "1110110"  =>         -- PCM12 FF76
                  if is_gbc = '1' then
                    s1_readdata <= (others => '0');
                    if  sq2_playing = '1' then
                        s1_readdata(7 downto 4) <= sq2_wav(5 downto 2);
                    end if;
                    if  sq1_playing = '1' then
                        s1_readdata(3 downto 0) <= sq1_wav(5 downto 2);
                    end if;
                  else
                    s1_readdata <= X"FF";
                  end if;
            when "1110111"  =>         -- PCM34 FF77
                  if is_gbc = '1' then
                    s1_readdata <= (others => '0');
                    if  noi_playing = '1' then
                        s1_readdata(7 downto 4) <= noi_wav(5 downto 2);
                    end if;
                    if  wav_playing = '1' then
                        s1_readdata(3 downto 0) <= wav_wav(5 downto 2);  
                    end if;
                  else
                    s1_readdata <= X"FF";
                  end if;

            
            when others =>
                s1_readdata <= X"FF";
        end case;

    end process;
    
    SS_Sound3_BACK(          23) <= sq1_playing;
    SS_Sound3_BACK(34 downto 24) <= sq1_fr2;
    SS_Sound3_BACK(38 downto 35) <= sq1_vol;
    SS_Sound3_BACK(          39) <= sq2_playing;
    SS_Sound3_BACK(43 downto 40) <= sq2_vol;
    SS_Sound3_BACK(49 downto 44) <= wav_wav_r;
    SS_Sound3_BACK(          50) <= wav_playing;
    SS_Sound3_BACK(55 downto 51) <= std_logic_vector(wav_index);
    SS_Sound3_BACK(57 downto 56) <= std_logic_vector(wav_access);
    SS_Sound3_BACK(          58) <= noi_playing;
    SS_Sound3_BACK(62 downto 59) <= noi_vol;

    sound : process (clk, sq1_out, sq1_vol, sq2_out, sq2_vol, noi_vol, sq1_suppressed, sq2_suppressed, wav_suppressed, wav_enable, wav_volsh, wav_wav_r, wav_ram, wav_index)
        constant duty_0          : std_logic_vector(0 to 7) := "00000001";
        constant duty_1          : std_logic_vector(0 to 7) := "10000001";
        constant duty_2          : std_logic_vector(0 to 7) := "10000111";
        constant duty_3          : std_logic_vector(0 to 7) := "01111110";
        variable sq1_fcnt        : unsigned(10 downto 0);
        variable sq1_phase       : integer range 0 to 7;
        variable sq1_len         : std_logic_vector(6 downto 0);
        variable sq1_envcnt      : std_logic_vector(3 downto 0); -- Sq1 envelope timer count
        variable sq1_swcnt       : std_logic_vector(3 downto 0); -- Sq1 sweep timer count
        variable sq1_swoffs      : unsigned(11 downto 0);
        variable sq1_swfr        : unsigned(11 downto 0);

        variable sq1_sweep_en    : std_logic;
        variable sweep_calculate : std_logic;
        variable sweep_update    : std_logic;
        variable sweep_negate    : std_logic;
        variable sq1_sduty       : std_logic_vector(1 downto 0); -- Sq1 duty cycle shadow register

        variable sq2_fcnt        : unsigned(10 downto 0);
        variable sq2_phase       : integer range 0 to 7;
        variable sq2_len         : std_logic_vector(6 downto 0);
        variable sq2_envcnt      : std_logic_vector(3 downto 0); -- Sq2 envelope timer count
        variable sq2_sduty       : std_logic_vector(1 downto 0); -- Sq2 duty cycle shadow register

        variable wav_fcnt        : unsigned(10 downto 0);
        variable wav_len         : std_logic_vector(8 downto 0);
        variable wav_shift_r     : std_logic;
        variable wav_shift       : std_logic;

        variable noi_divisor     : unsigned(10 downto 0); -- Noise frequency divisor
        variable noi_period      : unsigned(10 downto 0); -- Noise period    (calculated)
        variable noi_fcnt        : unsigned(10 downto 0);
        variable noi_lfsr        : unsigned(14 downto 0); -- 15 bits
        variable noi_len         : std_logic_vector(6 downto 0);
        variable noi_envcnt      : std_logic_vector(3 downto 0); -- Noise envelope timer count
        variable noi_out         : std_logic;
        variable noi_xor         : std_logic;

        variable tmp_volume      : unsigned(7 downto 0); -- used in zombie mode

        variable acc_fcnt        : unsigned(11 downto 0);

        variable sq1_trigger_freq : std_logic_vector(10 downto 0);
        variable sq2_trigger_freq : std_logic_vector(10 downto 0);
        -- variable noi_trigger_freq : std_logic_vector(10 downto 0); --TODO: implement this correctly
        variable wav_trigger_freq : std_logic_vector(10 downto 0);
    begin

        if sq1_out = '1' and sq1_suppressed = '0' then
            sq1_wav <= sq1_vol & "00";
        else
            sq1_wav <= "000000";
        end if;
        
        if sq2_out = '1' and sq2_suppressed = '0' then
            sq2_wav <= sq2_vol & "00";
        else
            sq2_wav <= "000000";
        end if;

        if wav_enable = '1' and wav_volsh /= "00" and wav_suppressed = '0' then
            case wav_volsh is
                when "01" => wav_wav   <= wav_ram(to_integer(wav_index)) & "00";
                when "10" => wav_wav   <= '0' & (wav_ram(to_integer(wav_index))(3 downto 1)) & "00";
                when "11" => wav_wav   <= "00" & (wav_ram(to_integer(wav_index))(3 downto 2)) & "00";
                when others => wav_wav <= (others => 'X');
            end case;
        else
            wav_wav <= wav_wav_r;  --when suppressed or triggered while playing
        end if;       

        if noi_out = '1' then
            noi_wav <= noi_vol & "00";
        else
            noi_wav <= "000000";
        end if;

        -- Sound processing
		  if rising_edge(clk) then
			  if reset = '1' then
					sq1_playing       <= SS_Sound3(          23); -- '0';
					sq1_fr2           <= SS_Sound3(34 downto 24); -- (others => '0');
					sq1_fcnt          := (others   => '0');
					sq1_phase         := 0;
					sq1_vol           <= SS_Sound3(38 downto 35); -- "0000";
					sq1_envcnt        := "0000";
					sq1_swcnt         := "0000";
					sq1_swoffs        := (others => '0');
					sq1_swfr          := (others => '0');
					sq1_out           <= '0';
					sq2_playing       <= SS_Sound3(          39); -- '0';
					sq2_fcnt          := (others => '0');
					sq2_phase         := 0;
					sq2_vol           <= SS_Sound3(43 downto 40); -- "0000";
					sq2_envcnt        := "0000";
					sq2_out           <= '0';
                  
					sq1_suppressed    <= '1';
					sq2_suppressed    <= '1';
					wav_suppressed    <= '1';
					wav_wav_r         <= SS_Sound3(49 downto 44); -- "000000";
   
					sq1_sduty         := (others => '0');
					sq2_sduty         := (others => '0');
   
					wav_playing       <= SS_Sound3(          50); -- '0';
					wav_fcnt          := (others => '0');
					wav_shift_r       := '0';
					wav_index         <= unsigned(SS_Sound3(55 downto 51)); -- (others => '0');
					wav_access        <= unsigned(SS_Sound3(57 downto 56)); -- (others => '0');
   
					noi_playing       <= SS_Sound3(          58); -- '0';
					noi_fcnt          := (others => '0');
					noi_lfsr          := (others => '1');
					noi_vol           <= SS_Sound3(62 downto 59); -- "0000";
					noi_envcnt        := "0000";
					noi_out           := '0';
					sweep_calculate   := '0';
					sweep_update      := '0';
					sq1_sweep_en      := '0';
					sweep_negate      := '0';

					sq1_len           := (others => '0');
					sq2_len           := (others => '0');
					wav_len           := (others => '0');
					noi_len           := (others => '0');

					sq1_trigger_r     <= '0'; 
					sq2_trigger_r     <= '0'; 
					wav_trigger_r     <= '0'; 
					noi_trigger_r     <= '0'; 

					sq1_trigger_freq  := (others => '0');
					sq2_trigger_freq  := (others => '0');
					wav_trigger_freq  := (others => '0');
					--noi_trigger_freq  := (others => '0');            

			  else
					if ce = '1' then

						 if sq1_lenchange = '1' then
							  sq1_len := sq1_slen;
						 end if;
						 
						 if sq2_lenchange = '1' then
							  sq2_len := sq2_slen;
						 end if;

						 if noi_lenchange = '1' then
							  noi_len := noi_slen;
						 end if;

						 if wav_lenchange = '1' then
							  wav_len := wav_slen;
						 end if;
						 
						 -- used to detect trigger negedge
						 sq1_trigger_r <= sq1_trigger;
						 sq2_trigger_r <= sq2_trigger;
						 wav_trigger_r <= wav_trigger;
						 noi_trigger_r <= noi_trigger;

						 if snd_enable = '1' then

							  if wav_access > 0 then
									wav_access <= wav_access - 1;
							  end if;

							  ----------------------- Square channel 1	-----------------------------	

							  if en_snd4 = '1' then
									-- Sq1 frequency timer Frequency = 131072/(2048-x) Hz
									if sq1_playing = '1' then
										 acc_fcnt := ('0' & sq1_fcnt) + to_unsigned(1, acc_fcnt'length);
										 if acc_fcnt(acc_fcnt'high) = '1' then
											  sq1_suppressed <= '0';
											  if (sq1_phase < 7) then sq1_phase := sq1_phase + 1; else sq1_phase := 0; end if;
											  sq1_fcnt := unsigned(sq1_freq);
											  sq1_sduty := sq1_duty; -- only change duty after the sample is finished
										 else
											  sq1_fcnt := acc_fcnt(sq1_fcnt'range);
										 end if;
									end if;

									case sq1_sduty is
										 when "00"   => sq1_out <= duty_0(sq1_phase);
										 when "01"   => sq1_out <= duty_1(sq1_phase);
										 when "10"   => sq1_out <= duty_2(sq1_phase);
										 when "11"   => sq1_out <= duty_3(sq1_phase);
										 when others => null;
									end case;
							  end if;

							  -- Length counter
							  if en_len = '1' or sq1_lenquirk = '1' then
									if sq1_len > 0 and sq1_lenchk = '1' then
										 sq1_len := std_logic_vector(unsigned(sq1_len) - 1);
									end if;
							  end if;

							  -- Sweep processing

							  -- sweep counter
							  if en_sweep = '1' then
									sq1_swcnt := std_logic_vector(unsigned(sq1_swcnt) - 1);
									if sq1_swcnt = 0 then

										 -- reload counter with period
										 if sq1_swper = "000" then
											  sq1_swcnt := "1000"; -- set to 8
										 else
											  sq1_swcnt := '0' & sq1_swper; -- set to period
										 end if;

										 -- check if update needed
										 if sq1_sweep_en = '1' and sq1_swper /= "000" then
											  sweep_calculate := '1';
											  sweep_update    := '1';
										 end if;
									end if;
							  end if;

							  sq1_freqchange <= '0';

							  if sq1_sweep_en = '1' then

									-- Calculate next sweep frequency
									if sweep_calculate = '1' then
										 case sq1_swshift is
											  when "000"  => sq1_swoffs  := unsigned('0' & sq1_fr2);
											  when "001"  => sq1_swoffs  := "00" & unsigned(sq1_fr2(10 downto 1));
											  when "010"  => sq1_swoffs  := "000" & unsigned(sq1_fr2(10 downto 2));
											  when "011"  => sq1_swoffs  := "0000" & unsigned(sq1_fr2(10 downto 3));
											  when "100"  => sq1_swoffs  := "00000" & unsigned(sq1_fr2(10 downto 4));
											  when "101"  => sq1_swoffs  := "000000" & unsigned(sq1_fr2(10 downto 5));
											  when "110"  => sq1_swoffs  := "0000000" & unsigned(sq1_fr2(10 downto 6));
											  when "111"  => sq1_swoffs  := "00000000" & unsigned(sq1_fr2(10 downto 7));
											  when others => sq1_swoffs := unsigned('0' & sq1_fr2);
										 end case;
										 if sq1_swdir = '1' then
											  sq1_swfr     := ('0' & unsigned(sq1_fr2)) - sq1_swoffs;
											  sweep_negate := '1';
										 else
											  sq1_swfr     := ('0' & unsigned(sq1_fr2)) + sq1_swoffs;
											  sweep_negate := '0';
										 end if;
										 sweep_calculate := '0';
									end if;

									-- update registers, and calculate next frequency
									if sweep_update = '1' then
										 sweep_update := '0';
										 if (sq1_swper /= "000" and sq1_swshift /= "000") then
											  sq1_fr2        <= std_logic_vector(sq1_swfr(10 downto 0));
											  sq1_freqchange <= '1';
											  sweep_calculate := '1'; -- when updating calculate 2nd time
										 end if;
									end if;

							  end if;

							  if sq1_playing = '1' then

									-- Envelope counter
									if en_env = '1' and sq1_envper /= "000" then

										 sq1_envcnt := std_logic_vector(unsigned(sq1_envcnt) - 1); -- decrement counter 

										 if sq1_envcnt = 0 then
											  if sq1_envsgn = '1' then
													if sq1_vol /= "1111" then -- sq1_vol < 15
														 sq1_vol <= std_logic_vector(unsigned(sq1_vol) + 1);
													end if;
											  else
													if sq1_vol /= "0000" then -- sq1_vol > 
														 sq1_vol <= std_logic_vector(unsigned(sq1_vol) - 1);
													end if;
											  end if;

											  -- reload counter with period
											  if sq1_envper = "000" then
													sq1_envcnt := "1000"; -- set to 8
											  else
													sq1_envcnt := '0' & sq1_envper; -- set to period
											  end if;

										 end if;
									end if;

									-- Check for end of playing conditions
									if (sq1_lenchk = '1' and sq1_len = 0)                         -- Play length timer overrun
										 or (sq1_sweep_en = '1' and sq1_swfr(11) = '1')                      -- Sweep frequency overrun
										 or (sq1_sweep_en = '1' and sq1_swdir_change = '1' and sweep_negate = '1') -- sweep direction change after trigger
										 then
										 sq1_playing <= '0';
										 sq1_envcnt   := (others => '0');
										 sq1_swcnt    := (others => '0');
										 sq1_swfr     := (others => '0');
										 sq1_sweep_en := '0';
									end if;
							  end if;

							  if ((sq1_trigger_r = '1' and sq1_trigger = '0') or sq1_nr2change = '1') and sq1_playing = '1' then  -- falling edge of trigger

									-- using sameboy's logic
									-- "zombie" mode
									tmp_volume := "0000" & unsigned(sq1_vol);

									if sq1_envsgn = '1' then 
										 tmp_volume :=  tmp_volume  + 1;
									end if;

									if (sq1_envsgn xor sq1_envsgn_old) = '1' then
										 tmp_volume := X"10" - tmp_volume;
									end if;

									if (sq1_envper /=  "000") and (sq1_envper_old = "000") and (tmp_volume /= "00000000") and (sq1_envsgn = '0') then 
										 tmp_volume := tmp_volume - 1;
									end if;

									if (sq1_envper_old /= "000") and sq1_envsgn = '1' then 
										 tmp_volume := tmp_volume - 1;
									end if;

									sq1_vol <= std_logic_vector(tmp_volume(3 downto 0));
									-- "zombie" mode

									-- check if dac is enabled
									if sq1_svol = "00000" and sq1_envsgn = '0' then -- dac disabled
										 sq1_playing <= '0';
									end if;
							  end if;

							  -- if sound was triggered and already playing reset/stop frequency counter
							  if sq1_trigger = '1' and sq1_playing = '1' then
									sq1_fcnt  := (others   => '0');
							  end if;

							  if sq1_trigger_r = '0' and sq1_trigger = '1' then -- rising edge of trigger
									sq1_trigger_freq := sq1_freq;   -- keep copy of frequency to avoid change while delaying trigger
							  end if;

							  -- Check sample trigger and start playing
							  if sq1_trigger_r = '1' and sq1_trigger = '0' then -- falling edge of trigger
									-- from sameboy:
									-- Current sample index remains unchanged when restarting channels 1 or 2. It is only reset by turning the APU off.

									if sq1_playing = '0' then
									  sq1_suppressed <= '1';  -- suppress 1st sample if channel wasn't active
									end if;

									sq1_vol <= sq1_svol;
									sq1_fr2 <= sq1_freq;                                        -- shadow frequency register for sweep unit
									sq1_sweep_en := '0';
									if (sq1_swper /= "000" or sq1_swshift /= "000") then -- sweep unit enabled ?
										sq1_sweep_en := '1';
									end if;
									---- sweep quirks ---
									if sq1_swshift /= "000" then
										 sweep_calculate := '1';
									end if;
									if sq1_swper = "000" then
										 sq1_swcnt := "1000"; -- set to 8
									else
										 sq1_swcnt := '0' & sq1_swper; -- set to period
									end if;
									sweep_negate := '0';
									---- sweep quirks ---

									sq1_fcnt := unsigned(sq1_trigger_freq);

									if not (sq1_svol = "00000" and sq1_envsgn = '0') then -- dac enabled
										 sq1_playing <= '1';
									end if;

									-- reload envelope counter with period
									if sq1_envper = "000" then
										 sq1_envcnt := "1000"; -- set to 8
									else
										 sq1_envcnt := '0' & sq1_envper; -- set to period
									end if;
																  
									if sq1_len = 0 then -- trigger quirks
										 if sq1_lenchk = '1' and en_len_r = '1' then
											  sq1_len := "0111111"; -- 63
										 else
											  sq1_len := "1000000"; -- 64
										 end if;
									end if;

							  end if;

							  ----------------------- Square channel 2	-----------------------------	

							  if en_snd4 = '1' then
									-- Sq2 frequency timer  Frequency = 131072/(2048-x) Hz
									if sq2_playing = '1' then
										 acc_fcnt := ('0' & sq2_fcnt) + to_unsigned(1, acc_fcnt'length);
										 if acc_fcnt(acc_fcnt'high) = '1' then
											  sq2_suppressed <= '0';
											  if (sq2_phase < 7) then sq2_phase := sq2_phase + 1; else sq2_phase := 0; end if;
											  sq2_fcnt := unsigned(sq2_freq);
											  sq2_sduty := sq2_duty;  -- only change duty after the sample is finished
										 else
											  sq2_fcnt := acc_fcnt(sq2_fcnt'range);
										 end if;
									end if;

									case sq2_sduty is
										 when "00"   => sq2_out <= duty_0(sq2_phase);
										 when "01"   => sq2_out <= duty_1(sq2_phase);
										 when "10"   => sq2_out <= duty_2(sq2_phase);
										 when "11"   => sq2_out <= duty_3(sq2_phase);
										 when others => null;
									end case;
							  end if;

							  -- Length counter
							  if en_len = '1' or sq2_lenquirk = '1' then
									if sq2_len > 0 and sq2_lenchk = '1' then
										 sq2_len := std_logic_vector(unsigned(sq2_len) - 1);
									end if;
							  end if;

							  if sq2_playing = '1' then

									-- Envelope counter
									if en_env = '1' and sq2_envper /= "000" then

										 sq2_envcnt := std_logic_vector(unsigned(sq2_envcnt) - 1); -- decrement counter 

										 if sq2_envcnt = 0 then
											  if sq2_envsgn = '1' then
													if sq2_vol /= "1111" then -- sq2_vol < 15
														 sq2_vol <= std_logic_vector(unsigned(sq2_vol) + 1);
													end if;
											  else
													if sq2_vol /= "0000" then -- sq2_vol > 0
														 sq2_vol <= std_logic_vector(unsigned(sq2_vol) - 1);
													end if;
											  end if;

											  -- reload counter with period
											  if sq2_envper = "000" then
													sq2_envcnt := "1000"; -- set to 8
											  else
													sq2_envcnt := '0' & sq2_envper; -- set to period
											  end if;
										 end if;
									end if;

									-- Check for end of playing conditions
									-- if sq2_vol = X"0" 										 -- Volume == 0              	
									if sq2_lenchk = '1' and sq2_len = 0 -- Play length timer overrun
										 then
										 sq2_playing <= '0';
										 sq2_envcnt := "0000";
									end if;
							  end if;

							  if ((sq2_trigger_r = '1' and sq2_trigger = '0') or sq2_nr2change = '1') and sq2_playing = '1' then  -- falling edge of trigger

									-- using sameboy's logic
									-- "zombie" mode
									tmp_volume := "0000" & unsigned(sq2_vol);

									if sq2_envsgn = '1' then 
										 tmp_volume :=  tmp_volume  + 1;
									end if;

									if (sq2_envsgn xor sq2_envsgn_old) = '1' then
										 tmp_volume := X"10" - tmp_volume;
									end if;

									if (sq2_envper /=  "000") and (sq2_envper_old = "000") and (tmp_volume /= "00000000") and (sq2_envsgn = '0') then 
										 tmp_volume := tmp_volume - 1;
									end if;

									if (sq2_envper_old /= "000") and sq2_envsgn = '1' then 
										 tmp_volume := tmp_volume - 1;
									end if;

									sq2_vol <= std_logic_vector(tmp_volume(3 downto 0));
									-- "zombie" mode

									-- check if dac is enabled
									if sq2_svol = "00000" and sq2_envsgn = '0' then -- dac disabled
										 sq2_playing <= '0';
									end if;
							  end if;

							  -- if sound was triggered and already playing reset/stop frequency counter
							  if sq2_trigger = '1' and sq2_playing = '1' then
									sq2_fcnt  := (others   => '0');
							  end if;

							  if sq2_trigger_r = '0' and sq2_trigger = '1' then -- rising edge of trigger
									sq2_trigger_freq := sq2_freq;   -- keep copy of frequency to avoid change while delaying trigger
							  end if;

							  -- Check sample trigger and start playing
							  if sq2_trigger_r = '1' and sq2_trigger = '0' then -- falling edge of trigger
									
									-- from sameboy:
									-- Current sample index remains unchanged when restarting channels 1 or 2. It is only reset by turning the APU off.

									if sq2_playing = '0' then
										 sq2_suppressed <= '1';  -- suppress 1st sample if channel wasn't active
									end if;

									sq2_vol <= sq2_svol;
									sq2_fcnt := unsigned(sq2_trigger_freq);

									if not (sq2_svol = "00000" and sq2_envsgn = '0') then -- dac enabled
										 sq2_playing <= '1';
									end if;

									-- reload envelope counter with period
									if sq2_envper = "000" then
										 sq2_envcnt := "1000"; -- set to 8
									else
										 sq2_envcnt := '0' & sq2_envper; -- set to period
									end if;

									if sq2_len = 0 then -- trigger quirks 
										 if sq2_lenchk = '1' and en_len_r = '1' then
											  sq2_len := "0111111"; -- 63
										 else
											  sq2_len := "1000000"; -- 64
										 end if;
									end if;
							  end if;
							  ----------------------- Noise channel -----------------------------	

							  -- Noi frequency timer Frequency = 524288 Hz / r / 2^(s+1) ;For r=0 assume r=0.5 instead  
							  if en_snd4 = '1' then
									if noi_playing = '1' then
										 acc_fcnt := ('0' & noi_fcnt) - to_unsigned(1, acc_fcnt'length);
										 if acc_fcnt = 0 then
											  -- Noise LFSR
											  noi_xor  := noi_lfsr(0) xor noi_lfsr(1);
											  noi_lfsr := noi_xor & noi_lfsr(14 downto 1);

											  if noi_short = '1' then
													noi_lfsr(6) := noi_xor;
											  end if;

											  noi_out  := not noi_lfsr(0);
											  noi_fcnt := noi_period;
										 else
											  noi_fcnt := acc_fcnt(noi_fcnt'range);
										 end if;
									end if;
							  end if;

							  -- Length counter
							  if en_len = '1' or noi_lenquirk = '1' then
									if noi_len > 0 and noi_lenchk = '1' then
										 noi_len := std_logic_vector(unsigned(noi_len) - 1);
									end if;
							  end if;

							  if noi_playing = '1' then

									-- Envelope counter
									if en_env = '1' and noi_envper /= "000" then

										 noi_envcnt := std_logic_vector(unsigned(noi_envcnt) - 1); -- decrement counter 

										 if noi_envcnt = 0 then
											  if noi_envsgn = '1' then
													if noi_vol /= "1111" then -- noi_vol < 15
														 noi_vol <= std_logic_vector(unsigned(noi_vol) + 1);
													end if;
											  else
													if noi_vol /= "0000" then -- noi_vol > 0
														 noi_vol <= std_logic_vector(unsigned(noi_vol) - 1);
													end if;
											  end if;

											  -- reload counter with period
											  if noi_envper = "000" then
													noi_envcnt := "1000"; -- set to 8
											  else
													noi_envcnt := '0' & noi_envper; -- set to period
											  end if;
										 end if;
									end if;

									-- Check for end of playing conditions            	
									if noi_lenchk = '1' and noi_len = 0 -- Play length timer overrun
										 then
										 noi_playing <= '0';
										 noi_envcnt := "0000";
									end if;
							  end if;

							  if ((noi_trigger = '0' and noi_trigger_r = '1') or noi_nr2change = '1') and noi_playing = '1' then

									-- using sameboy's logic
									-- "zombie" mode
									tmp_volume := "0000" & unsigned(noi_vol);

									if noi_envsgn = '1' then 
										 tmp_volume :=  tmp_volume  + 1;
									end if;

									if (noi_envsgn xor noi_envsgn_old) = '1' then
										 tmp_volume := X"10" - tmp_volume;
									end if;

									if (noi_envper /=  "000") and (noi_envper_old = "000") and (tmp_volume /= "00000000") and (noi_envsgn = '0') then 
										 tmp_volume := tmp_volume - 1;
									end if;

									if (noi_envper_old /= "000") and noi_envsgn = '1' then 
										 tmp_volume := tmp_volume - 1;
									end if;

									noi_vol <= std_logic_vector(tmp_volume(3 downto 0));
									-- "zombie" mode

									-- check if dac is enabled
									if noi_svol = "00000" and noi_envsgn = '0' then -- dac disabled
										 noi_playing <= '0';
									end if;
							  end if;

							  if noi_trigger = '1'or noi_freqchange = '1' then

									-- Calculate noise frequency
									case noi_div is
										 when "000"  => noi_period  := to_unsigned(2, noi_period'length);
										 when "001"  => noi_period  := to_unsigned(4, noi_period'length);
										 when "010"  => noi_period  := to_unsigned(8, noi_period'length);
										 when "011"  => noi_period  := to_unsigned(12, noi_period'length);
										 when "100"  => noi_period  := to_unsigned(16, noi_period'length);
										 when "101"  => noi_period  := to_unsigned(20, noi_period'length);
										 when "110"  => noi_period  := to_unsigned(24, noi_period'length);
										 when others => noi_period := to_unsigned(28, noi_divisor'length);
									end case;

									noi_period := noi_period sll to_integer(unsigned(noi_freqsh));
									noi_fcnt   := noi_period;

							  end if;

							  -- Check sample trigger and start playing
							  if noi_trigger_r = '1' and noi_trigger = '0' then -- falling edge of trigger
									noi_vol <= noi_svol;

									noi_lfsr := (others => '1');

									-- reload envelope counter with period
									if noi_envper = "000" then
										 noi_envcnt := "1000"; -- set to 8
									else
										 noi_envcnt := '0' & noi_envper; -- set to period
									end if;

									if not (noi_svol = "00000" and noi_envsgn = '0') then -- dac enabled
										 noi_playing <= '1';
									end if;

									if noi_len = 0 then -- trigger quirks 
										 if noi_lenchk = '1' and en_len_r = '1' then
											  noi_len := "0111111"; -- 63
										 else
											  noi_len := "1000000"; -- 64
										 end if;
									end if;
							  end if;

							  ----------------------------- Wave channel -----------------------------------	

							  wav_shift := '0';
							  if en_snd2 = '1' then
									-- Wave frequency timer Frequency = 4194304/(64*(2048-x)) Hz = 65536/(2048-x) Hz
									if wav_playing = '1' then
										 acc_fcnt := ('0' & wav_fcnt) + to_unsigned(1, acc_fcnt'length);
										 if acc_fcnt(acc_fcnt'high) = '1' then
											  wav_suppressed <= '0';
											  wav_shift := '1';
											  wav_fcnt  := unsigned(wav_freq);
										 else
											  wav_fcnt := acc_fcnt(wav_fcnt'range);
										 end if;
									end if;
							  end if;

							  if wav_trigger_r = '1' and wav_trigger = '0' then
									wav_index <= (others => '0');
									wav_shift_r := '0';
							  else
									-- Rotate wave table on rising edge of wav_shift
									if wav_shift = '1' and wav_shift_r = '0' then
										 wav_index  <= wav_index + 1;
										 wav_access <= "10";
									end if;
									wav_shift_r := wav_shift;
							  end if;

							  -- Length counter
							  if en_len = '1' or wav_lenquirk = '1' then
									if wav_len > 0 and wav_lenchk = '1' then
										 wav_len := std_logic_vector(unsigned(wav_len) - 1);
									end if;
							  end if;

							  if wav_playing = '1' then
									-- Check for end of playing conditions
									if (wav_lenchk = '1' and wav_len = 0) or wav_enable = '0' then
										 wav_playing <= '0';
									end if;
							  end if;

							  if wav_trigger_r = '0' and wav_trigger = '1' then -- rising edge of trigger
									wav_trigger_freq := wav_freq;   -- keep copy of frequency to avoid change while delaying trigger
							  end if;

							  -- Check sample trigger and start playing
							  if wav_trigger_r = '1' and wav_trigger = '0' then

									wav_suppressed <= '1';      -- suppress 1st sample if channel wasn't active or keep playing the current one if enabled

									if wav_playing = '0' then
										 wav_wav_r <= "000000";  -- suppress 1st sample if channel wasn't active 
									else
										 wav_wav_r <= wav_wav;   -- keep playing the current sample if it was active
									end if;

									wav_fcnt := unsigned(wav_trigger_freq);
									
									wav_playing <= '1';
									if wav_len = 0 then -- trigger quirks 
										 if wav_lenchk = '1' and en_len_r = '1' then
											  wav_len := "011111111"; -- 255
										 else
											  wav_len := "100000000"; -- 256
										 end if;
									end if;
							  end if;
						 else  -- snd_enable = '0'
							  sq1_playing <= '0';
							  sq1_fr2     <= (others => '0');
							  sq1_fcnt  := (others   => '0');
							  sq1_phase := 0;
							  sq1_vol <= "0000";
							  sq1_envcnt := "0000";
							  sq1_swcnt  := "0000";
							  sq1_swoffs := (others => '0');
							  sq1_swfr   := (others => '0');
							  sq1_out   <= '0';
							  sq2_playing <= '0';
							  sq2_fcnt  := (others => '0');
							  sq2_phase := 0;
							  sq2_vol <= "0000";
							  sq2_envcnt := "0000";
							  sq2_out    <= '0';

							  sq1_suppressed <= '1';
							  sq2_suppressed <= '1';
							  wav_suppressed <= '1';
							  wav_wav_r <= "000000";

							  sq1_sduty    := (others => '0');
							  sq2_sduty    := (others => '0');
			  
							  wav_playing <= '0';
							  wav_fcnt    := (others => '0');
							  wav_shift_r := '0';
							  wav_index   <= (others => '0');
							  wav_access  <= (others => '0');
			  
							  noi_playing <= '0';
							  noi_fcnt := (others => '0');
							  noi_lfsr := (others => '1');
							  noi_vol <= "0000";
							  noi_envcnt      := "0000";
							  noi_out         := '0';
							  sweep_calculate := '0';
							  sweep_update    := '0';
							  sq1_sweep_en    := '0';
							  sweep_negate    := '0';

							  if is_gbc = '1' then
									sq1_len  := (others => '0');
									sq2_len  := (others => '0');
									wav_len  := (others => '0');
									noi_len  := (others => '0');
							  end if;

							  sq1_trigger_r   <= '0'; 
							  sq2_trigger_r   <= '0'; 
							  wav_trigger_r   <= '0'; 
							  noi_trigger_r   <= '0'; 
						 
						 end if; 

					end if; -- ce
			  end if;
		  end if; -- rising edge
    end process sound;

    -- Test
    process (clk)
        variable l : std_logic_vector(15 downto 0);
    begin
		  if rising_edge(clk) then
			  if reset = '1' then
					l := x"4000";
			  else
					if ce = '1' then
						 if en_512 = '1' then
							  l := not l;
						 end if;
						 --			snd_left <= l;
					end if;
			  end if;
		  end if;
    end process;

    -- Mixer
    mixer : process (sq1_wav, sq2_wav, noi_wav, wav_wav, ch_map, ch_vol)
        variable snd_left_in  : unsigned(7 downto 0);
        variable snd_right_in : unsigned(7 downto 0);
    begin
        snd_left_in  := (others => '0');
        snd_right_in := (others => '0');

        if ch_map(0) = '1' then
            snd_right_in := snd_right_in + ("00" & unsigned(sq1_wav));
        end if;
        if ch_map(1) = '1' then
            snd_right_in := snd_right_in + ("00" & unsigned(sq2_wav));
        end if;
        if ch_map(2) = '1' then
            snd_right_in := snd_right_in + ("00" & unsigned(wav_wav));
        end if;
        if ch_map(3) = '1' then
            snd_right_in := snd_right_in + ("00" & unsigned(noi_wav));
        end if;

        if ch_map(4) = '1' then
            snd_left_in := snd_left_in + ("00" & unsigned(sq1_wav));
        end if;
        if ch_map(5) = '1' then
            snd_left_in := snd_left_in + ("00" & unsigned(sq2_wav));
        end if;
        if ch_map(6) = '1' then
            snd_left_in := snd_left_in + ("00" & unsigned(wav_wav));
        end if;
        if ch_map(7) = '1' then
            snd_left_in := snd_left_in + ("00" & unsigned(noi_wav));
        end if;

        snd_right <= (std_logic_vector(snd_right_in) & "00000") * ch_vol(2 downto 0);
        snd_left  <= (std_logic_vector(snd_left_in) & "00000") * ch_vol(6 downto 4);
    end process;

end SYN;