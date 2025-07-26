
-- Create Date: 2024-07-26 14:24:05
-- Design Name: ads_driver
-- Module Name: ads_driver - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- This module is a VHDL driver for the Texas Instruments ADS1115 
-- 16-bit ADC. It controls an I2C master component to configure the ADC
-- and read conversion data from a specified channel.
--
-- Dependencies: 
--   - i2c_master.vhd: An I2C master component.
--
-- Revision:
-- Revision 1.00 - Restructured for clarity and best practices.
-- Revision 0.01 - File Created
--
-- Additional Comments:
-- The state machine handles the sequence of I2C operations required to:
-- 1. Write to the Config register to set the MUX for the desired channel
--    and start a single-shot conversion.
-- 2. Write to the Address Pointer register to select the Conversion register.
-- 3. Read the 16-bit conversion result from the Conversion register.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; --arithmetic operations

entity ads_driver is
    Port (
        -- System Signals
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;

        -- Control & Status
        go      : in  STD_LOGIC;
        done    : out STD_LOGIC;
        ack_er  : out STD_LOGIC;

        -- ADC Interface
        chs     : in  STD_LOGIC_VECTOR(1 downto 0); -- Channel select (00 to 11)
        chx     : out STD_LOGIC_VECTOR(15 downto 0); -- Channel data output

        -- I2C Interface
        sda     : inout STD_LOGIC;
        scl     : inout STD_LOGIC
    );
end ads_driver;

architecture Behavioral of ads_driver is

    --================================================================
    -- Type Definitions
    --================================================================
    type state_type is (
        S_IDLE,
        S_CONFIG_POINTER,
        S_CONFIG_MSB,
        S_CONFIG_LSB,
        S_WAIT_CONFIG,
        S_SET_CONV_POINTER,
        S_WAIT_SET_POINTER,
        S_START_READ,
        S_READ_MSB,
        S_READ_LSB,
        S_SAVE_DATA,
        S_STOP_READ
    );

    --================================================================
    -- Constants
    --================================================================
    -- ADS1115 I2C Address (for ADDR pin connected to GND)
    constant C_I2C_ADDR         : STD_LOGIC_VECTOR(6 downto 0) := "1001000"; -- 0x48
    
    -- ADS1115 Register Pointers
    constant C_REG_PTR_CONV     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    constant C_REG_PTR_CONFIG   : STD_LOGIC_VECTOR(7 downto 0) := x"01";

    -- ADS1115 Configuration Bytes
    -- MSB: OS=1 (start), MUX=chs, PGA=001 (+/-4.096V), MODE=1 (single-shot)
    -- LSB: DR=100 (128SPS), COMP_MODE=0, COMP_POL=0, COMP_LAT=0, COMP_QUE=11
    constant C_CONFIG_LSB_VAL   : STD_LOGIC_VECTOR(7 downto 0) := x"83"; -- 128SPS, default comparator

    --================================================================
    -- Signals
    --================================================================
    -- State machine signals
    signal current_state, next_state : state_type;

    -- I2C Master interface signals
    signal i2c_en       : STD_LOGIC;
    signal i2c_rw       : STD_LOGIC;
    signal i2c_busy     : STD_LOGIC;
    signal i2c_ack_err  : STD_LOGIC;
    signal i2c_wr_data  : STD_LOGIC_VECTOR(7 downto 0);
    signal i2c_rd_data  : STD_LOGIC_VECTOR(7 downto 0);

    -- Internal data register
    signal data_reg     : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Dynamic configuration MSB based on channel selection
    signal config_msb   : STD_LOGIC_VECTOR(7 downto 0);

    --================================================================
    -- Components
    --================================================================
    component i2c_master is
        Port (
            clk       : in    STD_LOGIC;                      -- System clock
            reset_n   : in    STD_LOGIC;                      -- Active low reset
            ena       : in    STD_LOGIC;                      -- Latch in command
            addr      : in    STD_LOGIC_VECTOR(6 downto 0);   -- Address of target slave
            rw        : in    STD_LOGIC;                      -- '0' is write, '1' is read
            data_wr   : in    STD_LOGIC_VECTOR(7 downto 0);   -- Data to write to slave
            busy      : out   STD_LOGIC;                      -- Indicates transaction in progress
            data_rd   : out   STD_LOGIC_VECTOR(7 downto 0);   -- Data read from slave
            ack_error : buffer  STD_LOGIC;                    -- Flag if improper acknowledge from slave
            sda       : inout STD_LOGIC;                      -- Serial data output of I2C bus
            scl       : inout STD_LOGIC                       -- Serial clock output of I2C bus
        );
    end component;

begin

    --================================================================
    -- Component Instantiation
    --================================================================
    ads1115 : i2c_master
        port map (
            clk       => clk,
            reset_n   => rst, -- Assuming active-high reset in this entity, but component needs active-low
            ena       => i2c_en,
            addr      => C_I2C_ADDR,
            rw        => i2c_rw,
            data_wr   => i2c_wr_data,
            busy      => i2c_busy,
            data_rd   => i2c_rd_data,
            ack_error => i2c_ack_err,
            sda       => sda,
            scl       => scl
        );

    --================================================================
    -- Concurrent Assignments
    --================================================================
    -- Output the acknowledge error flag
    ack_er <= i2c_ack_err;
    
    -- Construct the MSB of the configuration register dynamically
    -- OS=1, MUX=chs, PGA=001(4.096V), MODE=1
    config_msb <= '1' & chs & "100" & '1';

    --================================================================
    -- Sequential Logic (State Register)
    --================================================================
    state_reg_proc : process(clk, rst)
    begin
        if rst = '1' then -- Using active-high reset for consistency
            current_state <= S_IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process state_reg_proc;

    --================================================================
    -- Combinational Logic (Next State & Outputs)
    --================================================================
    fsm_comb_proc : process(current_state, go, i2c_busy, i2c_ack_err, i2c_rd_data, config_msb)
    begin
        -- Default assignments for outputs
        next_state  <= current_state;
        i2c_en      <= '0';
        i2c_rw      <= '0'; -- Default to write
        i2c_wr_data <= (others => '0');
        done        <= '0';
        
        case current_state is

            when S_IDLE =>
                done <= '1';
                if go = '1' then
                    next_state <= S_CONFIG_POINTER;
                end if;

            -- === Configuration Write Sequence ===
            when S_CONFIG_POINTER =>
                i2c_en      <= '1';
                i2c_wr_data <= C_REG_PTR_CONFIG;
                if i2c_busy = '0' then
                    next_state <= S_CONFIG_MSB;
                end if;

            when S_CONFIG_MSB =>
                i2c_en      <= '1';
                i2c_wr_data <= config_msb;
                if i2c_busy = '0' then
                    next_state <= S_CONFIG_LSB;
                end if;

            when S_CONFIG_LSB =>
                i2c_en      <= '1';
                i2c_wr_data <= C_CONFIG_LSB_VAL;
                if i2c_busy = '0' then
                    next_state <= S_WAIT_CONFIG;
                end if;
                
            when S_WAIT_CONFIG =>
                -- Wait for the write sequence to finish
                if i2c_busy = '0' then
                    if i2c_ack_err = '1' then
                        next_state <= S_IDLE; -- Error, return to idle
                    else
                        next_state <= S_SET_CONV_POINTER;
                    end if;
                end if;

            -- === Set Pointer to Conversion Register for Reading ===
            when S_SET_CONV_POINTER =>
                i2c_en      <= '1';
                i2c_wr_data <= C_REG_PTR_CONV;
                if i2c_busy = '0' then
                    next_state <= S_WAIT_SET_POINTER;
                end if;

            when S_WAIT_SET_POINTER =>
                if i2c_busy = '0' then
                    if i2c_ack_err = '1' then
                        next_state <= S_IDLE;
                    else
                        next_state <= S_START_READ;
                    end if;
                end if;

            -- === Data Read Sequence ===
            when S_START_READ =>
                i2c_en     <= '1';
                i2c_rw     <= '1'; -- Switch to read mode
                if i2c_busy = '0' then
                    next_state <= S_READ_MSB;
                end if;

            when S_READ_MSB =>
                i2c_en     <= '1';
                i2c_rw     <= '1';
                if i2c_busy = '0' then
                    next_state <= S_READ_LSB;
                end if;

            when S_READ_LSB =>
                i2c_en     <= '1';
                i2c_rw     <= '1';
                if i2c_busy = '0' then
                    next_state <= S_STOP_READ;
                end if;
                
            when S_STOP_READ =>
                -- The i2c_master should handle the stop condition.
                -- We transition when busy goes low.
                if i2c_busy = '0' then
                    next_state <= S_SAVE_DATA;
                end if;

            when S_SAVE_DATA =>
                -- Data is valid on the cycle after the read states.
                -- We can transition directly to IDLE.
                next_state <= S_IDLE;

            when others =>
                next_state <= S_IDLE;

        end case;
    end process fsm_comb_proc;
    
    --================================================================
    -- Data Registering Process
    --================================================================
    data_reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- Latch the MSB when the FSM moves from READ_MSB
            if current_state = S_READ_MSB and next_state = S_READ_LSB then
                data_reg(15 downto 8) <= i2c_rd_data;
            end if;
            
            -- Latch the LSB when the FSM moves from READ_LSB
            if current_state = S_READ_LSB and next_state = S_STOP_READ then
                data_reg(7 downto 0) <= i2c_rd_data;
            end if;
            
            -- Output the final registered value when returning to idle
            if next_state = S_IDLE then
                chx <= data_reg;
            end if;
            
            -- Reset data register on system reset
            if rst = '1' then
                data_reg <= (others => '0');
                chx <= (others => '0');
            end if;
        end if;
    end process data_reg_proc;

end Behavioral;
