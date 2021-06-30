library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity speedcontrol is
   port
   (
      clk_sys     : in  std_logic;
      reset       : in  std_logic;
      romread     : in  std_logic;
      romack      : in  std_logic;
      pausevideo  : in  std_logic;
      ce          : out std_logic := '0';
      ce_2x       : out std_logic := '0'    
   );
end entity;

architecture arch of speedcontrol is

   signal clkdiv      : unsigned(2 downto 0) := (others => '0'); 
     
   type tstate is
   (
      NORMAL,
      WAITRAM
   );
   signal state : tstate := NORMAL;

begin

   process(clk_sys)
      variable skipclock : std_logic;
   begin
      if falling_edge(clk_sys) then
      
         ce    <= '0';
         ce_2x <= '0';         
         
         skipclock := '0';
         
         clkdiv <= clkdiv + 1;
         if (clkdiv = "000") then
            ce <= '1';
         end if;
         if (clkdiv(1 downto 0) = "00") then
            ce_2x    <= '1';
         end if;
         
         if (reset = '1') then
            
            state       <= NORMAL;
         
         else

            case (state) is
            
               when NORMAL =>
                  if (romread = '1') then
                     state <= WAITRAM;
                  end if;
                  
               when WAITRAM =>
                  if (romack = '1') then
                     state <= NORMAL;
                  else
                     skipclock := '1';
                  end if; 
               
            end case;
            
         end if;
         
         if (pausevideo = '1') then
            skipclock := '1';
         end if;
         
         if (skipclock = '1') then
            ce         <= '0';
            ce_2x      <= '0';
            if (clkdiv = "100") then
               clkdiv <= "001";
            end if;
            if (clkdiv = "000") then
               clkdiv <= "101";
            end if;
         end if;
         
      end if;
   end process;
   
   

end architecture;
