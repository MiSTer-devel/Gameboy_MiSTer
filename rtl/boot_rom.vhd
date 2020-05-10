library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity boot_rom is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of boot_rom is
	type rom is array(0 to  255) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"31",X"FE",X"FF",X"AF",X"21",X"FF",X"9F",X"32",X"CB",X"7C",X"20",X"FB",X"21",X"26",X"FF",X"0E",
		X"11",X"3E",X"80",X"32",X"E2",X"0C",X"3E",X"F3",X"E2",X"32",X"3E",X"77",X"77",X"3E",X"FC",X"E0",
		X"47",X"F0",X"50",X"FE",X"42",X"28",X"75",X"11",X"04",X"01",X"21",X"10",X"80",X"1A",X"4F",X"CD",
		X"A0",X"00",X"CD",X"A0",X"00",X"13",X"7B",X"FE",X"34",X"20",X"F2",X"11",X"B2",X"00",X"06",X"08",
		X"1A",X"22",X"22",X"13",X"05",X"20",X"F9",X"3E",X"19",X"EA",X"10",X"99",X"21",X"2F",X"99",X"0E",
		X"0C",X"3D",X"28",X"08",X"32",X"0D",X"20",X"F9",X"2E",X"0F",X"18",X"F3",X"67",X"3E",X"64",X"57",
		X"E0",X"42",X"3E",X"91",X"E0",X"40",X"04",X"1E",X"02",X"0E",X"0C",X"F0",X"44",X"FE",X"90",X"20",
		X"FA",X"0D",X"20",X"F7",X"1D",X"20",X"F2",X"0E",X"13",X"24",X"7C",X"1E",X"83",X"FE",X"62",X"28",
		X"06",X"1E",X"C1",X"FE",X"64",X"20",X"06",X"7B",X"E2",X"0C",X"3E",X"87",X"E2",X"F0",X"42",X"90",
		X"E0",X"42",X"15",X"20",X"D2",X"05",X"20",X"64",X"16",X"20",X"18",X"CB",X"E0",X"40",X"18",X"5C",
		X"06",X"04",X"C5",X"CB",X"11",X"17",X"C1",X"CB",X"11",X"17",X"05",X"20",X"F5",X"22",X"22",X"22",
		X"22",X"C9",X"3C",X"42",X"B9",X"A5",X"B9",X"A5",X"42",X"3C",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",
		X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"FF",X"3E",X"01",X"E0",X"50");
begin

data <= rom_data(to_integer(unsigned(addr))) when rising_edge(clk);

end architecture;

library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity fast_boot_rom is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(7 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of fast_boot_rom is
	type rom is array(0 to  255) of std_logic_vector(7 downto 0);
	signal rom_data: rom := (
		X"31",X"FE",X"FF",X"21",X"00",X"80",X"22",X"CB",X"6C",X"28",X"FB",X"3E",X"80",X"E0",X"26",X"E0",
		X"11",X"3E",X"F3",X"E0",X"12",X"E0",X"25",X"3E",X"77",X"E0",X"24",X"3E",X"FC",X"E0",X"47",X"11",
		X"04",X"01",X"21",X"10",X"80",X"1A",X"47",X"CD",X"82",X"00",X"CD",X"82",X"00",X"13",X"7B",X"EE",
		X"34",X"20",X"F2",X"11",X"B1",X"00",X"0E",X"08",X"1A",X"13",X"22",X"23",X"0D",X"20",X"F9",X"3E",
		X"19",X"EA",X"10",X"99",X"21",X"2F",X"99",X"0E",X"0C",X"3D",X"28",X"08",X"32",X"0D",X"20",X"F9",
		X"2E",X"0F",X"18",X"F5",X"3E",X"91",X"E0",X"40",X"06",X"2D",X"CD",X"A3",X"00",X"3E",X"83",X"CD",
		X"AA",X"00",X"06",X"05",X"CD",X"A3",X"00",X"3E",X"C1",X"CD",X"AA",X"00",X"06",X"46",X"CD",X"A3",
		X"00",X"21",X"B0",X"01",X"E5",X"F1",X"21",X"4D",X"01",X"01",X"13",X"00",X"11",X"D8",X"00",X"C3",
		X"FE",X"00",X"3E",X"04",X"0E",X"00",X"CB",X"20",X"F5",X"CB",X"11",X"F1",X"CB",X"11",X"3D",X"20",
		X"F5",X"79",X"22",X"23",X"22",X"23",X"C9",X"E5",X"21",X"0F",X"FF",X"CB",X"86",X"CB",X"46",X"28",
		X"FC",X"E1",X"C9",X"CD",X"97",X"00",X"05",X"20",X"FA",X"C9",X"E0",X"13",X"3E",X"87",X"E0",X"14",
		X"C9",X"3C",X"42",X"B9",X"A5",X"B9",X"A5",X"42",X"3C",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",
		X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"E0",X"50");
begin

data <= rom_data(to_integer(unsigned(addr))) when rising_edge(clk);

end architecture;
