library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity speedcontrol is
   port
   (
      clk_sys     : in  std_logic;
      pause       : in  std_logic;
      speedup     : in  std_logic;
      cart_act    : in  std_logic;
      ce          : out std_logic := '0';
      ce_2x       : out std_logic := '0';
      ceNormal    : out std_logic := '0';
      ce_2xNormal : out std_logic := '0'
   );
end entity;

architecture arch of speedcontrol is

   signal clkdiv       : unsigned(2 downto 0) := (others => '0');
   signal nextdiv      : unsigned(2 downto 0) := (others => '0');
                       
   signal clkdivNormal : unsigned(2 downto 0) := (others => '0');
                       
   signal cart_act_1   : std_logic := '0';

begin

   process(clk_sys)
   begin
      if falling_edge(clk_sys) then
         if (pause = '1') then
         
            ce          <= '0';
            ce_2x       <= '0';
            ceNormal    <= '0';
            ce_2xNormal <= '0';
            
         else
         
            clkdiv       <= clkdiv + 1;
            clkdivNormal <= clkdivNormal + 1;
            
            -- generation for speed depending on speedup
            cart_act_1 <= cart_act;
            
            if (clkdiv = "000") then ce <= '1'; else ce <= '0'; end if;
            if ((nextdiv = "111" and clkdiv(1 downto 0) = "00") or nextdiv = "001") then ce_2x <= '1'; else ce_2x <= '0'; end if;
            
            if (clkdiv = nextdiv and (clkdiv = "111" or cart_act = '0')) then
               clkdiv  <= "000";
               if (speedup = '1') then
                  nextdiv <= "001";
               else
                  nextdiv <= "111";
               end if;
            end if;
            
            if (cart_act = '1' and cart_act_1 = '0') then
               nextdiv <= "111";
            end if;
            
            -- generation for non speed up base, used e.g. for sound hack
            if (clkdivNormal = "000")            then ceNormal    <= '1'; else ceNormal    <= '0'; end if;
            if (clkdivNormal(1 downto 0) = "00") then ce_2xNormal <= '1'; else ce_2xNormal <= '0'; end if;
         
         end if;
         
      end if;
   end process;

end architecture;
