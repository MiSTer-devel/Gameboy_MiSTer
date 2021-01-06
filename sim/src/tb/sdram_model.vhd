library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
use tb.globals.all;

entity sdram_model is
   port 
   (
      clk               : in  std_logic;
      cart_addr         : in  std_logic_vector(23 downto 0);
      cart_rd           : in  std_logic;
      cart_do           : out std_logic_vector(7 downto 0);
      cart_cgb_flag     : out std_logic_vector(7 downto 0);
      cart_sgb_flag     : out std_logic_vector(7 downto 0);
      cart_mbc_type     : out std_logic_vector(7 downto 0);
      cart_rom_size     : out std_logic_vector(7 downto 0);
      cart_ram_size     : out std_logic_vector(7 downto 0);
      cart_old_licensee : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of sdram_model is

   -- not full size, because of memory required
   type t_data is array(0 to (2**23)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
begin

   process
   
      variable data : t_data := (others => 0);
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte      : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (0 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   
   begin
      wait until rising_edge(clk);
      
      if (cart_rd = '1') then 
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         wait until rising_edge(clk);
         wait until rising_edge(clk);         
         cart_do       <= std_logic_vector(to_unsigned(data(to_integer(unsigned(cart_addr))), 8));
      end if; 

      cart_cgb_flag     <= std_logic_vector(to_unsigned(data(16#143#), 8));
      cart_sgb_flag     <= std_logic_vector(to_unsigned(data(16#146#), 8));
      cart_mbc_type     <= std_logic_vector(to_unsigned(data(16#147#), 8));
      cart_rom_size     <= std_logic_vector(to_unsigned(data(16#148#), 8));
      cart_ram_size     <= std_logic_vector(to_unsigned(data(16#149#), 8));
      cart_old_licensee <= std_logic_vector(to_unsigned(data(16#14B#), 8));
      
      COMMAND_FILE_ACK_1 <= '0';
      if COMMAND_FILE_START_1 = '1' then
         
         assert false report "received" severity note;
         assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
      
         file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
      
         targetpos := COMMAND_FILE_TARGET;
      
         while (not endfile(infile)) loop
            
            read(infile, next_vector, actual_len);  
             
            read_byte := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
            
            --report "read_byte=" & integer'image(to_integer(unsigned(read_byte)));
            
            data(targetpos) := to_integer(unsigned(read_byte));
            targetpos       := targetpos + 1;
            
         end loop;
      
         file_close(infile);
      
         COMMAND_FILE_ACK_1 <= '1';
      
      end if;

   
   
   end process;
   
end architecture;


