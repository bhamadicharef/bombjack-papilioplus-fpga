--	(c) 2012 d18c7db(a)hotmail
--
--	This program is free software; you can redistribute it and/or modify it under
--	the terms of the GNU General Public License version 3 or, at your option,
--	any later version as published by the Free Software Foundation.
--
--	This program is distributed in the hope that it will be useful,
--	but WITHOUT ANY WARRANTY; without even the implied warranty of
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- For full details, see the GNU General Public License at www.gnu.org/licenses

--------------------------------------------------------------------------------

-- ###########################################################################
-- ##### PAGE 8 schema - Palette RAM                                     #####
-- ###########################################################################
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;
library unisim;
	use unisim.vcomponents.all;

entity palette is
	port ( 
		I_CLK_6M_EN		: in  std_logic;
		I_CS_9C00_n		: in  std_logic;
		I_MEWR_n			: in  std_logic;
		I_MERD_n			: in  std_logic;
		I_CMPBLK_n_r	: in  std_logic;
		I_VBLANK_n		: in  std_logic;
		I_OC				: in  std_logic_vector (3 downto 0);
		I_OV				: in  std_logic_vector (2 downto 0);
		I_SC				: in  std_logic_vector (3 downto 0);
		I_SV				: in  std_logic_vector (2 downto 0);
		I_BC				: in  std_logic_vector (3 downto 0);
		I_BV				: in  std_logic_vector (2 downto 0);
		I_AB				: in  std_logic_vector (8 downto 0);
		I_DB				: in  std_logic_vector (7 downto 0);
		--
		O_DB				: out std_logic_vector (7 downto 0);
		O_R				: out std_logic_vector (3 downto 0);
		O_G				: out std_logic_vector (3 downto 0);
		O_B				: out std_logic_vector (3 downto 0)
	);
end palette;

architecture RTL of palette is
-- Page 8
	signal s_color_addr	: std_logic_vector( 7 downto 0) := (others => '0');
	signal s_5E_in			: std_logic_vector( 6 downto 0) := (others => '0');
	signal s_5E_out		: std_logic_vector( 7 downto 0) := (others => '0');
	signal s_5M8			: std_logic := '0';
	signal s_5M12			: std_logic := '0';
	signal s_5M6			: std_logic := '0';
	signal s_8G6			: std_logic := '0';
	signal s_9c00_rd_n	: std_logic := '1';
	signal s_9c00_wr_n	: std_logic := '1';
	signal s_9c01_rd_n	: std_logic := '1';
	signal s_9c01_wr_n	: std_logic := '1';
	type  array_256x4 is array (0 to 255) of std_logic_vector(3 downto 0);
	signal pal_r			: array_256x4 := (others => (others => '0'));
	signal pal_g			: array_256x4 := (others => (others => '0'));
	signal pal_b			: array_256x4 := (others => (others => '0'));
begin
	-- chip 5M page 8
	s_5M8  <= not ( I_OV(0) or I_OV(1) or I_OV(2) );
	s_5M12 <= not ( I_SV(0) or I_SV(1) or I_SV(2) );
	s_5M6  <= not ( I_BV(0) or I_BV(1) or I_BV(2) );

	-- chips 5F, 5H, 5J, 5K, 3M, 5M12, 5M8, 5M6 page 8
	s_5E_in <=  -- priority encoder
		(I_OC & I_OV) when   ( s_5M8 = '0') else
		(I_SC & I_SV) when ( ( s_5M8 = '1') and (s_5M12 = '0') ) else
		(I_BC & I_BV) when ( ( s_5M8 = '1') and (s_5M12 = '1') and (s_5M6 = '0') ) else
		(others => '0');

	-- chip 8G page 8
	s_8G6 <= I_CMPBLK_n_r or s_5E_out(0);

	-- chips 5E, 8G6 page 8
	U5E : process(I_CLK_6M_EN, s_8G6)
	begin
		if s_8G6 = '0' then
			s_5E_out <= (others => '0');
		elsif rising_edge(I_CLK_6M_EN) then
			s_5E_out <= s_5E_in & I_CMPBLK_n_r;
		end if;
	end process;

	-- chips 6D, 6F page 8
	s_color_addr <= I_AB(8 downto 1) when (I_CS_9C00_n = '0') else ("0" & s_5E_out(7 downto 1)) ;

	-- chip 8D page 8
	s_9c00_rd_n <= ( I_CS_9C00_n or I_MERD_n or (    I_AB(0)) );
	s_9c00_wr_n <= ( I_CS_9C00_n or I_MEWR_n or (    I_AB(0)) );
	s_9c01_rd_n <= ( I_CS_9C00_n or I_MERD_n or (not I_AB(0)) );
	s_9c01_wr_n <= ( I_CS_9C00_n or I_MEWR_n or (not I_AB(0)) );

	-- these are the RGB color palette RAMs at base address 9C00
	-- even addresses access red bits 0-3 and green bits 4-7
	-- odd addresses access blue bits 0-3, bits 4-7 unused

	rg_pal : process(s_9c00_wr_n)
	begin
		if rising_edge(s_9c00_wr_n) then
			-- chip 6A page 8
			pal_r(to_integer(unsigned(s_color_addr))) <= I_DB(3 downto 0);
			-- chip 6B page 8
			pal_g(conv_integer(s_color_addr)) <= I_DB(7 downto 4);
		end if;
	end process;

	b_pal : process(s_9c01_wr_n)
	begin
		if rising_edge(s_9c01_wr_n) then
			-- chip 6C page 8
			pal_b(conv_integer(s_color_addr)) <= I_DB(3 downto 0);
		end if;
	end process;

	-- chips 7A, 8B page 8
	U7A8B : process(I_CLK_6M_EN, I_VBLANK_n)
	begin
		if (I_VBLANK_n = '0') then
			O_R <= (others => '0');
			O_G <= (others => '0');
			O_B <= (others => '0');
		elsif rising_edge(I_CLK_6M_EN) then
			O_R <= pal_r(conv_integer(s_color_addr));
			O_G <= pal_g(conv_integer(s_color_addr));
			O_B <= pal_b(conv_integer(s_color_addr));
		end if;
	end process;

	-- chips 7B, 7C, 8C11, 8C8 page 8 output data bus muxes
	O_DB <=
		-- chip 7B, 8C11 page 8
		(pal_g(conv_integer(s_color_addr)) & pal_r(conv_integer(s_color_addr))) when (s_9c00_rd_n = '0') else
		-- chip 7C, 8C8 page 8
		("0000" & pal_b(conv_integer(s_color_addr))) when (s_9c01_rd_n = '0') else
		(others => '0');
end RTL;
