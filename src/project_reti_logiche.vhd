-- PF RL 2025/26 - project_reti_logiche

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk          : in  STD_LOGIC;
        i_rst          : in  STD_LOGIC;
        i_start        : in  STD_LOGIC;
        i_task_id      : in  STD_LOGIC_VECTOR(5 downto 0);
        i_task_priority: in  STD_LOGIC_VECTOR(1 downto 0);
        i_op           : in  STD_LOGIC_VECTOR(1 downto 0);
        o_done         : out STD_LOGIC;
        o_task_id      : out STD_LOGIC_VECTOR(5 downto 0);
        o_mem_addr     : out STD_LOGIC_VECTOR(15 downto 0);
        i_mem_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        o_mem_data     : out STD_LOGIC_VECTOR(7 downto 0);
        o_mem_we       : out STD_LOGIC;
        o_mem_en       : out STD_LOGIC
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_t is (
        INIT,
        INIT_WAIT,
        IDLE,
        READ_COUNT,
        WAIT_COUNT,
        DECODE,
        INC_READ,           -- OP 00
        WAIT_INC,
        INC_WRITE,
        RM_SAVE_FIRST,      -- OP 01
        WAIT_RM_FIRST,
        RM_SAVE_FIRST_READ,
        RM_SHIFT_READ,
        WAIT_RM_SHIFT,
        RM_SHIFT_WRITE,
        RM_UPDATE_COUNT,
        INS_FIND,           -- OP 10
        WAIT_FIND,
        INS_DECIDE,
        INS_SHIFT_READ,
        WAIT_INS_SHIFT,
        INS_SHIFT_WRITE,
        INS_WRITE_TASK,
        INS_UPDATE_COUNT,
        CLEAR,              -- OP 11
        DONE
    );

    signal state : state_t;

    signal reg_op            : std_logic_vector(1 downto 0);
    signal reg_count         : unsigned(5 downto 0);
    signal reg_idx           : unsigned(5 downto 0);
    signal reg_task_id       : std_logic_vector(5 downto 0);
    signal reg_task_priority : std_logic_vector(1 downto 0);
    signal reg_out_id        : std_logic_vector(5 downto 0);
    signal reg_insert_pos    : unsigned(5 downto 0);

begin

    process(i_clk, i_rst)
        variable v_priority     : unsigned(1 downto 0);
        variable v_new_priority : unsigned(1 downto 0);
        variable v_task_byte    : std_logic_vector(7 downto 0);
    begin
        if i_rst = '1' then
            o_done            <= '1';
            o_mem_en          <= '0';
            o_mem_we          <= '0';
            o_mem_addr        <= (others => '0');
            o_mem_data        <= (others => '0');
            o_task_id         <= (others => '0');
            reg_op            <= (others => '0');
            reg_count         <= (others => '0');
            reg_idx           <= (others => '0');
            reg_task_id       <= (others => '0');
            reg_task_priority <= (others => '0');
            reg_out_id        <= (others => '0');
            reg_insert_pos    <= (others => '0');
            state             <= INIT;

        elsif rising_edge(i_clk) then
            -- valori default per la memoria
            o_mem_en   <= '0';
            o_mem_we   <= '0';
            o_mem_addr <= (others => '0');
            o_mem_data <= (others => '0');

            case state is

                when INIT =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= (others => '0');
                    o_mem_data <= (others => '0');
                    o_done     <= '1';
                    state      <= INIT_WAIT;

                when INIT_WAIT =>
                    o_done <= '1';
                    if i_start = '0' then
                        state <= IDLE;
                    end if;

                when IDLE =>
                    o_done <= '0';
                    if i_start = '1' then
                        reg_op            <= i_op;
                        reg_task_id       <= i_task_id;
                        reg_task_priority <= i_task_priority;
                        state             <= READ_COUNT;
                    end if;

                when READ_COUNT =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= (others => '0');
                    state      <= WAIT_COUNT;

                when WAIT_COUNT =>
                    o_mem_en <= '1';
                    state    <= DECODE;

                when DECODE =>
                    reg_count <= unsigned(i_mem_data(5 downto 0));
                    
                    case reg_op is
                        when "00" =>  -- Inc priorità
                            if unsigned(i_mem_data(5 downto 0)) = 0 then
                                state <= DONE;
                            else
                                reg_idx <= to_unsigned(1, 6);
                                state   <= INC_READ;
                            end if;

                        when "01" =>  -- Rimuovi
                            if unsigned(i_mem_data(5 downto 0)) = 0 then
                                o_task_id <= (others => '0');
                                state     <= DONE;
                            else
                                state <= RM_SAVE_FIRST;
                            end if;

                        when "10" =>  -- Inserisci
                            if unsigned(i_mem_data(5 downto 0)) >= 63 then
                                state <= DONE;
                            elsif unsigned(i_mem_data(5 downto 0)) = 0 then
                                reg_insert_pos <= to_unsigned(1, 6);
                                state          <= INS_WRITE_TASK;
                            else
                                reg_idx <= to_unsigned(1, 6);
                                state   <= INS_FIND;
                            end if;

                        when "11" =>  -- Clear
                            state <= CLEAR;

                        when others =>
                            state <= IDLE;
                    end case;

                -- OP 00: incrementa priorità
                when INC_READ =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= std_logic_vector(resize(reg_idx, 16));
                    state      <= WAIT_INC;

                when WAIT_INC =>
                    o_mem_en <= '1';
                    state    <= INC_WRITE;

                when INC_WRITE =>
                    v_priority := unsigned(i_mem_data(1 downto 0));
                    
                    if v_priority = 3 then
                        v_new_priority := to_unsigned(3, 2);
                    else
                        v_new_priority := v_priority + 1;
                    end if;
                    
                    v_task_byte := i_mem_data(7 downto 2) & std_logic_vector(v_new_priority);

                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= std_logic_vector(resize(reg_idx, 16));
                    o_mem_data <= v_task_byte;

                    if reg_idx = reg_count then
                        state <= DONE;
                    else
                        reg_idx <= reg_idx + 1;
                        state   <= INC_READ;
                    end if;

                -- OP 01: rimuovi il primo task
                when RM_SAVE_FIRST =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= std_logic_vector(to_unsigned(1, 16));
                    state      <= WAIT_RM_FIRST;

                when WAIT_RM_FIRST =>
                    o_mem_en <= '1';
                    state    <= RM_SAVE_FIRST_READ;

                when RM_SAVE_FIRST_READ =>
                    reg_out_id <= i_mem_data(7 downto 2);
                    reg_idx    <= to_unsigned(2, 6);

                    if reg_count = 1 then
                        state <= RM_UPDATE_COUNT;
                    else
                        state <= RM_SHIFT_READ;
                    end if;

                when RM_SHIFT_READ =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= std_logic_vector(resize(reg_idx, 16));
                    state      <= WAIT_RM_SHIFT;

                when WAIT_RM_SHIFT =>
                    o_mem_en <= '1';
                    state    <= RM_SHIFT_WRITE;

                when RM_SHIFT_WRITE =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= std_logic_vector(resize(reg_idx - 1, 16));
                    o_mem_data <= i_mem_data;

                    if reg_idx = reg_count then
                        state <= RM_UPDATE_COUNT;
                    else
                        reg_idx <= reg_idx + 1;
                        state   <= RM_SHIFT_READ;
                    end if;

                when RM_UPDATE_COUNT =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= (others => '0');
                    o_mem_data <= std_logic_vector(resize(reg_count - 1, 8));
                    o_task_id  <= reg_out_id;
                    state      <= DONE;

                -- OP 10: inserimento nuovo task
                when INS_FIND =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= std_logic_vector(resize(reg_idx, 16));
                    state      <= WAIT_FIND;

                when WAIT_FIND =>
                    o_mem_en <= '1';
                    state    <= INS_DECIDE;

                when INS_DECIDE =>
                    if unsigned(i_mem_data(1 downto 0)) > unsigned(reg_task_priority) then
                        reg_insert_pos <= reg_idx;
                        reg_idx        <= reg_count;
                        state          <= INS_SHIFT_READ;
                    elsif reg_idx = reg_count then
                        reg_insert_pos <= reg_count + 1;
                        state          <= INS_WRITE_TASK;
                    else
                        reg_idx <= reg_idx + 1;
                        state   <= INS_FIND;
                    end if;

                when INS_SHIFT_READ =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '0';
                    o_mem_addr <= std_logic_vector(resize(reg_idx, 16));
                    state      <= WAIT_INS_SHIFT;

                when WAIT_INS_SHIFT =>
                    o_mem_en <= '1';
                    state    <= INS_SHIFT_WRITE;

                when INS_SHIFT_WRITE =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= std_logic_vector(resize(reg_idx + 1, 16));
                    o_mem_data <= i_mem_data;

                    if reg_idx = reg_insert_pos then
                        state <= INS_WRITE_TASK;
                    else
                        reg_idx <= reg_idx - 1;
                        state   <= INS_SHIFT_READ;
                    end if;

                when INS_WRITE_TASK =>
                    v_task_byte := reg_task_id & reg_task_priority;
                    o_mem_en    <= '1';
                    o_mem_we    <= '1';
                    o_mem_addr  <= std_logic_vector(resize(reg_insert_pos, 16));
                    o_mem_data  <= v_task_byte;
                    state       <= INS_UPDATE_COUNT;

                when INS_UPDATE_COUNT =>
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= (others => '0');
                    o_mem_data <= std_logic_vector(resize(reg_count + 1, 8));
                    state      <= DONE;

		-- OP 00: clear
                when CLEAR => 
                    o_mem_en   <= '1';
                    o_mem_we   <= '1';
                    o_mem_addr <= (others => '0');
                    o_mem_data <= (others => '0');
                    state      <= DONE;

                when DONE =>
                    o_done <= '1';
                    if i_start = '0' then
                        o_done <= '0';
                        state  <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;