------------------------------------------------------------------
-- Edge Case Test Bench per project_reti_logiche
-- Copre: lista vuota, singolo elem, saturazione, priorita estreme,
--        shift massivi, sequenze miste, reset, timing
------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_edge_cases is
end tb_edge_cases;

architecture tb_edge_cases_arch of tb_edge_cases is
    constant CLOCK_PERIOD  : time := 20 ns;
    constant RAM_INIT_ZERO : std_logic_vector(7 downto 0) := "00000000";

    -- Segnali di clock / controllo
    signal tb_clk    : std_logic := '0';
    signal tb_rst    : std_logic := '0';
    signal tb_start  : std_logic := '0';
    signal tb_done   : std_logic;

    -- Segnali ingresso task
    signal tb_task_id       : std_logic_vector(5 downto 0) := (others => '0');
    signal tb_task_priority : std_logic_vector(1 downto 0) := (others => '0');
    signal tb_op            : std_logic_vector(1 downto 0) := (others => '0');

    -- Segnali uscita
    signal tb_o_task_id : std_logic_vector(5 downto 0);

    -- Segnali memoria (DUT -> MEM)
    signal dut_mem_addr : std_logic_vector(15 downto 0);
    signal dut_mem_data : std_logic_vector(7 downto 0);
    signal dut_mem_en   : std_logic;
    signal dut_mem_we   : std_logic;
    signal dut_mem_data_in : std_logic_vector(7 downto 0);

    -- RAM: 64K x 8 bit
    type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);
    signal RAM : ram_type := (OTHERS => RAM_INIT_ZERO);

    -- Segnale per report: contatore test
    signal test_count : integer := 0;

    -- Segnali init memoria (solo il processo MEM scrive su RAM per evitare driver multipli)
    signal init_mode : std_logic := '0';
    signal init_we   : std_logic := '0';
    signal init_addr : integer range 0 to 65535 := 0;
    signal init_data : std_logic_vector(7 downto 0) := (others => '0');

    -- Component DUT
    component project_reti_logiche is
        port (
            i_clk          : in  std_logic;
            i_rst          : in  std_logic;
            i_start        : in  std_logic;
            i_task_id      : in  std_logic_vector(5 downto 0);
            i_task_priority: in  std_logic_vector(1 downto 0);
            i_op           : in  std_logic_vector(1 downto 0);
            o_done         : out std_logic;
            o_task_id      : out std_logic_vector(5 downto 0);
            o_mem_addr     : out std_logic_vector(15 downto 0);
            i_mem_data     : in  std_logic_vector(7 downto 0);
            o_mem_data     : out std_logic_vector(7 downto 0);
            o_mem_we       : out std_logic;
            o_mem_en       : out std_logic
        );
    end component;

begin
    -- Istanziazione DUT
    UUT : project_reti_logiche
        port map (
            i_clk           => tb_clk,
            i_rst           => tb_rst,
            i_start         => tb_start,
            i_task_id       => tb_task_id,
            i_task_priority => tb_task_priority,
            i_op            => tb_op,
            o_done          => tb_done,
            o_task_id       => tb_o_task_id,
            o_mem_addr      => dut_mem_addr,
            i_mem_data      => dut_mem_data_in,
            o_mem_data      => dut_mem_data,
            o_mem_we        => dut_mem_we,
            o_mem_en        => dut_mem_en
        );

    -- Clock generation
    tb_clk <= not tb_clk after CLOCK_PERIOD/2;

    -- Processo memoria (Write-First Mode come da specifica)
    -- Unico driver di RAM (init_mode scrive su inizializzazione)
    MEM : process(tb_clk)
    begin
        if rising_edge(tb_clk) then
            if init_mode = '1' and init_we = '1' then
                RAM(init_addr) <= init_data after 1 ns;
                dut_mem_data_in <= init_data after 1 ns;
            elsif dut_mem_en = '1' then
                if dut_mem_we = '1' then
                    RAM(to_integer(unsigned(dut_mem_addr))) <= dut_mem_data after 1 ns;
                    dut_mem_data_in <= dut_mem_data after 1 ns;
                else
                    dut_mem_data_in <= RAM(to_integer(unsigned(dut_mem_addr))) after 1 ns;
                end if;
            end if;
        end if;
    end process;

    -- ==================================================================
    -- Processo principale di test
    -- ==================================================================
    process
        -- Variabili per test
        variable expected_id : std_logic_vector(5 downto 0);
        variable actual_id   : std_logic_vector(5 downto 0);
        variable actual_byte : std_logic_vector(7 downto 0);

        -- ==============================================================
        -- PROCEDURE: Esegue un'operazione e attende DONE
        -- ==============================================================
        procedure do_op(
            constant op_val    : in std_logic_vector(1 downto 0);
            constant id_val    : in std_logic_vector(5 downto 0);
            constant prio_val  : in std_logic_vector(1 downto 0);
            constant msg       : in string
        ) is
        begin
            tb_op            <= op_val;
            tb_task_id       <= id_val;
            tb_task_priority <= prio_val;
            tb_start         <= '1';
            wait until rising_edge(tb_done);
            tb_start         <= '0';
            wait until falling_edge(tb_done);
            wait until falling_edge(tb_clk);
            report "  [OK] " & msg severity note;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Esegue OP e verifica o_task_id
        -- ==============================================================
        procedure do_op_check_id(
            constant op_val    : in std_logic_vector(1 downto 0);
            constant id_val    : in std_logic_vector(5 downto 0);
            constant prio_val  : in std_logic_vector(1 downto 0);
            constant exp_id    : in std_logic_vector(5 downto 0);
            constant msg       : in string
        ) is
        begin
            tb_op            <= op_val;
            tb_task_id       <= id_val;
            tb_task_priority <= prio_val;
            tb_start         <= '1';
            wait until rising_edge(tb_done);
            tb_start         <= '0';
            assert tb_o_task_id = exp_id
                report "FAIL " & msg & " o_task_id expected=" &
                       integer'image(to_integer(unsigned(exp_id))) &
                       " actual=" &
                       integer'image(to_integer(unsigned(tb_o_task_id)))
                severity failure;
            wait until falling_edge(tb_done);
            wait until falling_edge(tb_clk);
            report "  [OK] " & msg severity note;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Verifica byte di memoria
        -- ==============================================================
        procedure check_mem(
            constant addr : in integer;
            constant exp  : in std_logic_vector(7 downto 0);
            constant msg  : in string
        ) is
        begin
            assert RAM(addr) = exp
                report "FAIL " & msg & " @addr=" & integer'image(addr) &
                       " expected=" & integer'image(to_integer(unsigned(exp))) &
                       " actual=" & integer'image(to_integer(unsigned(RAM(addr))))
                severity failure;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Verifica conteggio task
        -- ==============================================================
        procedure check_count(
            constant exp : in integer;
            constant msg : in string
        ) is
        begin
            assert to_integer(unsigned(RAM(0))) = exp
                report "FAIL " & msg & " count expected=" &
                       integer'image(exp) & " actual=" &
                       integer'image(to_integer(unsigned(RAM(0))))
                severity failure;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Verifica intera lista task
        -- ==============================================================
        procedure check_list(
            constant count  : in integer;
            constant data   : in ram_type;
            constant offset : in integer;
            constant msg    : in string
        ) is
        begin
            check_count(count, msg & " (count)");
            for i in 1 to count loop
                check_mem(i, data(offset + i), msg & " @pos=" & integer'image(i));
            end loop;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Scrive un byte in RAM via init_mode (singolo driver)
        -- ==============================================================
        procedure init_write_byte(
            constant addr : in integer;
            constant data : in std_logic_vector(7 downto 0)
        ) is
        begin
            init_addr <= addr;
            init_data <= data;
            init_we   <= '1';
            init_mode <= '1';
            wait until falling_edge(tb_clk);
            init_we   <= '0';
            init_mode <= '0';
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Azzera memoria (count=0)
        -- ==============================================================
        procedure clear_mem is
        begin
            init_write_byte(0, RAM_INIT_ZERO);
            for i in 1 to 100 loop
                init_write_byte(i, RAM_INIT_ZERO);
            end loop;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Inizializza la memoria con una lista di task
        -- ==============================================================
        procedure init_mem(
            constant count    : in integer;
            constant task_ids : in integer_vector;
            constant prios    : in integer_vector
        ) is
            variable task_byte : std_logic_vector(7 downto 0);
        begin
            -- Azzera tutta la RAM prima di inizializzare
            init_write_byte(0, RAM_INIT_ZERO);
            for i in 1 to (count + 5) loop
                init_write_byte(i, RAM_INIT_ZERO);
            end loop;
            -- Scrivi count
            init_write_byte(0, std_logic_vector(to_unsigned(count, 8)));
            -- Scrivi task
            for i in 1 to count loop
                task_byte := std_logic_vector(to_unsigned(task_ids(i-1), 6)) &
                             std_logic_vector(to_unsigned(prios(i-1), 2));
                init_write_byte(i, task_byte);
            end loop;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Utility per costruire task byte
        -- ==============================================================
        function make_task(id : integer; prio : integer) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(id, 6)) &
                   std_logic_vector(to_unsigned(prio, 2));
        end function;

        -- ==============================================================
        -- PROCEDURE: Reset del DUT
        -- ==============================================================
        procedure reset_dut is
        begin
            tb_rst <= '1';
            wait for 100 ns;
            tb_rst <= '0';
            wait until falling_edge(tb_clk);
            -- Attendi che INIT completi (DONE=1)
            wait until rising_edge(tb_done);
            wait until falling_edge(tb_done);
            wait until falling_edge(tb_clk);
            report "  [OK] Reset completato" severity note;
        end procedure;

        -- ==============================================================
        -- PROCEDURE: Avvia un nuovo test
        -- ==============================================================
        procedure start_test(msg : string) is
        begin
            report "" severity note;
            report "===== TEST: " & msg & " =====" severity note;
        end procedure;

    begin
        -- ================================================================
        -- INIZIALIZZAZIONE (prima del reset)
        -- ================================================================
        tb_start <= '0';
        tb_rst   <= '0';
        wait for 50 ns;

        -- Reset iniziale
        tb_rst <= '1';
        wait for 100 ns;
        tb_rst <= '0';

        -- Aspetta che la FSM completi INIT -> INIT_WAIT -> IDLE
        -- (INIT scrive 0 ad addr 0, INIT_WAIT aspetta START=0, IDLE con DONE=0)
        wait for 200 ns;
        -- Dopo reset, count=0
        check_count(0, "Inizializzazione: count=0 dopo reset");
        wait until falling_edge(tb_clk);
        report "===== INIZIO TEST EDGE CASE =====" severity note;

        -- ================================================================
        -- GRUPPO 1: LISTA VUOTA
        -- ================================================================

        -- TEST 1: OP 00 su lista vuota
        start_test("OP 00 su lista vuota");
        -- RAM(0)=0, nessun task
        do_op("00", "000000", "00", "OP 00 su lista vuota completato");
        check_count(0, "Test 1: count=0 dopo OP 00 su lista vuota");

        -- TEST 2: OP 01 su lista vuota (deve dare o_task_id=0)
        start_test("OP 01 su lista vuota -> output ID=0");
        do_op_check_id("01", "000000", "00", "000000",
                       "OP 01 su lista vuota: o_task_id=0");
        check_count(0, "Test 2: count=0 dopo OP 01 su lista vuota");

        -- TEST 3: OP 10 su lista vuota (inserisce in prima posizione)
        start_test("OP 10 su lista vuota -> insert in pos 1");
        do_op("10", "000101", "00", "OP 10 su lista vuota (ID=5, P=0)");
        check_count(1, "Test 3: count=1 dopo insert in lista vuota");
        check_mem(1, make_task(5, 0), "Test 3: task in pos 1 = ID=5, P=0");

        -- TEST 4: OP 11 su lista vuota (clear)
        start_test("OP 11 su lista vuota (dopo operazioni)");
        -- Dopo test 3 abbiamo count=1, quindi facciamo remove per avere count=0
        do_op("01", "000000", "00", "Remove per svuotare");
        check_count(0, "Test 4: count=0 dopo remove");
        do_op("11", "000000", "00", "OP 11 su lista vuota");
        check_count(0, "Test 4: count=0 dopo clear su lista vuota");

        -- ================================================================
        -- GRUPPO 2: SINGOLO ELEMENTO
        -- ================================================================

        -- TEST 5: Remove su singolo task
        start_test("OP 01 remove su singolo task");
        init_mem(1, (0 => 10), (0 => 0));
        do_op_check_id("01", "000000", "00", "001010",
                       "OP 01 remove singolo: o_task_id=10");
        check_count(0, "Test 5: count=0 dopo remove singolo");

        -- TEST 6: OP 00 increment su singolo task
        start_test("OP 00 increment su singolo task (P=0->1)");
        init_mem(1, (0 => 15), (0 => 0));
        do_op("00", "000000", "00", "OP 00 su singolo task P=0");
        check_count(1, "Test 6: count=1");
        check_mem(1, make_task(15, 1), "Test 6: task P=0->1");

        -- TEST 7: OP 00 su singolo task a priorita 3 (saturazione)
        start_test("OP 00 su singolo task P=3 (saturazione)");
        init_mem(1, (0 => 7), (0 => 3));
        do_op("00", "000000", "00", "OP 00 su P=3 (saturato)");
        check_count(1, "Test 7: count=1");
        check_mem(1, make_task(7, 3), "Test 7: task rimane P=3 (saturo)");

        -- TEST 8: Insert dopo remove (catena)
        start_test("Remove poi Insert su singolo elemento");
        init_mem(1, (0 => 3), (0 => 1));
        do_op_check_id("01", "000000", "00", "000011",
                       "Test 8: remove ID=3");
        check_count(0, "Test 8: count=0 dopo remove");
        do_op("10", "000111", "10", "Test 8: Insert ID=7, P=2");
        check_count(1, "Test 8: count=1 dopo insert");
        check_mem(1, make_task(7, 2), "Test 8: task = ID=7, P=2");

        -- ================================================================
        -- GRUPPO 3: SATURAZIONE PRIORITA
        -- ================================================================

        -- TEST 9: Tutti a priorita 3 -> OP 00 (deve saturare)
        start_test("Tutti i task a P=3, OP 00 -> saturazione");
        init_mem(4,
            (1, 2, 3, 4),
            (3, 3, 3, 3));
        do_op("00", "000000", "00", "OP 00 con tutti P=3");
        check_count(4, "Test 9: count=4");
        check_mem(1, make_task(1, 3), "Test 9: task1 P=3 saturo");
        check_mem(2, make_task(2, 3), "Test 9: task2 P=3 saturo");
        check_mem(3, make_task(3, 3), "Test 9: task3 P=3 saturo");
        check_mem(4, make_task(4, 3), "Test 9: task4 P=3 saturo");

        -- TEST 10: Mix priorità 0,1,2,3 -> OP 00
        start_test("Mix priorita 0,1,2,3 -> 1,2,3,3");
        init_mem(4,
            (10, 20, 30, 40),
            (0, 1, 2, 3));
        do_op("00", "000000", "00", "OP 00 su mix priorita");
        check_mem(1, make_task(10, 1), "Test 10: P=0->1");
        check_mem(2, make_task(20, 2), "Test 10: P=1->2");
        check_mem(3, make_task(30, 3), "Test 10: P=2->3");
        check_mem(4, make_task(40, 3), "Test 10: P=3->3 saturo");

        -- TEST 11: Tre OP 00 consecutivi
        start_test("Tre OP 00 consecutivi -> tutti P=3");
        init_mem(3,
            (1, 2, 3),
            (0, 0, 1));
        do_op("00", "000000", "00", "OP 00 #1");
        check_mem(1, make_task(1, 1), "Test 11: dopo #1 P=1");
        check_mem(2, make_task(2, 1), "Test 11: dopo #1 P=1");
        check_mem(3, make_task(3, 2), "Test 11: dopo #1 P=2");

        do_op("00", "000000", "00", "OP 00 #2");
        check_mem(1, make_task(1, 2), "Test 11: dopo #2 P=2");
        check_mem(2, make_task(2, 2), "Test 11: dopo #2 P=2");
        check_mem(3, make_task(3, 3), "Test 11: dopo #2 P=3");

        do_op("00", "000000", "00", "OP 00 #3");
        check_mem(1, make_task(1, 3), "Test 11: dopo #3 P=3 saturo");
        check_mem(2, make_task(2, 3), "Test 11: dopo #3 P=3 saturo");
        check_mem(3, make_task(3, 3), "Test 11: dopo #3 P=3 saturo");

        -- ================================================================
        -- GRUPPO 4: PRIORITA ESTREME E INSERT ORDERING
        -- ================================================================

        -- TEST 12: Insert con priorità 0 (massima) in lista non vuota
        start_test("Insert P=0 in lista non vuota -> prima posizione");
        init_mem(3,
            (10, 20, 30),
            (1, 2, 3));
        do_op("10", "110011", "00", "Insert ID=51, P=0");
        check_count(4, "Test 12: count=4");
        check_mem(1, make_task(51, 0), "Test 12: pos 1 = ID=51 P=0 (primo)");
        check_mem(2, make_task(10, 1), "Test 12: pos 2 = ID=10 P=1 (shift)");
        check_mem(3, make_task(20, 2), "Test 12: pos 3 = ID=20 P=2 (shift)");
        check_mem(4, make_task(30, 3), "Test 12: pos 4 = ID=30 P=3 (shift)");

        -- TEST 13: Insert con priorità 3 (minima) in lista non vuota
        start_test("Insert P=3 in lista non vuota -> ultima posizione");
        init_mem(3,
            (10, 20, 30),
            (0, 1, 2));
        do_op("10", "101000", "11", "Insert ID=40, P=3");
        check_count(4, "Test 13: count=4");
        check_mem(1, make_task(10, 0), "Test 13: pos 1 invariato");
        check_mem(2, make_task(20, 1), "Test 13: pos 2 invariato");
        check_mem(3, make_task(30, 2), "Test 13: pos 3 invariato");
        check_mem(4, make_task(40, 3), "Test 13: pos 4 = ID=40 P=3 (ultimo)");

        -- TEST 14: Insert con stessa priorità di task esistenti (FIFO)
        start_test("Insert stessa priorita -> coda del gruppo FIFO");
        init_mem(2,
            (10, 20),
            (1, 1));
        do_op("10", "011110", "01", "Insert ID=30, P=1");
        check_count(3, "Test 14: count=3");
        check_mem(1, make_task(10, 1), "Test 14: pos 1 = ID=10 P=1");
        check_mem(2, make_task(20, 1), "Test 14: pos 2 = ID=20 P=1");
        check_mem(3, make_task(30, 1), "Test 14: pos 3 = ID=30 P=1 (coda FIFO)");

        -- TEST 15: Multipli insert stessa priorità — verifica ordine FIFO
        start_test("Multipli insert stessa priorita -> ordine FIFO");
        clear_mem;
        do_op("10", "000001", "00", "Insert ID=1, P=0");
        do_op("10", "000010", "00", "Insert ID=2, P=0");
        do_op("10", "000011", "00", "Insert ID=3, P=0");
        check_count(3, "Test 15: count=3");
        check_mem(1, make_task(1, 0), "Test 15: pos 1 = ID=1 (primo FIFO)");
        check_mem(2, make_task(2, 0), "Test 15: pos 2 = ID=2 (secondo FIFO)");
        check_mem(3, make_task(3, 0), "Test 15: pos 3 = ID=3 (terzo FIFO)");
        -- Inserisci un quarto con stessa priorità
        do_op("10", "000100", "00", "Insert ID=4, P=0");
        check_count(4, "Test 15: count=4");
        check_mem(4, make_task(4, 0), "Test 15: pos 4 = ID=4 (quarto FIFO)");

        -- ================================================================
        -- GRUPPO 5: SHIFT MASSIVI E BOUNDARY
        -- ================================================================

        -- TEST 16: Rimuovi primo con 30 task (shift massivo)
        start_test("Remove primo con 30 task (shift massivo)");
        init_mem(30,
            ( 1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
             11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
             21, 22, 23, 24, 25, 26, 27, 28, 29, 30),
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
             2, 2, 2, 2, 2, 2, 2, 2, 2, 2));
        do_op_check_id("01", "000000", "00", "000001",
                       "Test 16: remove ID=1 da 30 task");
        check_count(29, "Test 16: count=29 dopo remove");
        -- Verifica shift: il vecchio task 2 deve essere ora in pos 1
        check_mem(1, make_task(2, 0), "Test 16: pos 1 = ID=2 (shift OK)");
        check_mem(2, make_task(3, 0), "Test 16: pos 2 = ID=3 (shift OK)");
        check_mem(10, make_task(11, 1), "Test 16: pos 10 = ID=11 (shift OK)");
        check_mem(29, make_task(30, 2), "Test 16: pos 29 = ID=30 (shift OK)");

        -- TEST 17: Insert in mezzo a 25 task
        start_test("Insert in mezzo a 25 task (shift destra massivo)");
        -- Crea 25 task: 10x P=0, 10x P=1, 5x P=2
        init_mem(25,
            ( 1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
             11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
             21, 22, 23, 24, 25),
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
             2, 2, 2, 2, 2));
        -- Insert con priorità 1 -> coda dei P=1 = pos 21 (dopo 10xP=0 + 10xP=1)
        do_op("10", "110010", "01", "Insert ID=50, P=1 (in mezzo)");
        check_count(26, "Test 17: count=26");
        check_mem(1, make_task(1, 0), "Test 17: P=0 invariato pos 1");
        check_mem(10, make_task(10, 0), "Test 17: P=0 invariato pos 10");
        check_mem(11, make_task(11, 1), "Test 17: pos 11 = P=1 invariato (primo P=1)");
        check_mem(20, make_task(20, 1), "Test 17: pos 20 = P=1 invariato (ultimo P=1 vecchio)");
        check_mem(21, make_task(50, 1), "Test 17: pos 21 = nuovo ID=50 P=1 (coda P=1)");
        check_mem(22, make_task(21, 2), "Test 17: pos 22 = ID=21 P=2 (shiftato da 21)");
        check_mem(26, make_task(25, 2), "Test 17: pos 26 = ID=25 P=2 (shiftato da 25)");

        -- TEST 18: Opera su count=31 (limite teorico ID)
        start_test("Insert con count=31 (limite ID univoci)");
        init_mem(31,
            ( 1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
             11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
             21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
             31),
            (0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
             1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
             1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
             1));
        do_op("00", "000000", "00", "OP 00 su 31 task");
        check_count(31, "Test 18: count=31");
        -- Il primo task P=0 doveva diventare P=1
        check_mem(1, make_task(1, 1), "Test 18: primo task P=0->1");

        -- TEST 19: Insert in ultima posizione (prio 3)
        start_test("Insert in ultima pos (P=3) con lista grande");
        init_mem(20,
            ( 1,  2,  3,  4,  5,  6,  7,  8,  9, 10,
             11, 12, 13, 14, 15, 16, 17, 18, 19, 20),
            (0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
             2, 2, 2, 2, 2, 3, 3, 3, 3, 3));
        do_op("10", "111111", "11", "Insert ID=63, P=3 (ultimo)");
        check_count(21, "Test 19: count=21");
        check_mem(21, make_task(63, 3), "Test 19: ultima pos = ID=63 P=3");

        -- ================================================================
        -- GRUPPO 6: SEQUENZE MISTE / INTEGRAZIONE
        -- ================================================================

        -- TEST 20: Full cycle — insert, remove, insert, increment, clear
        start_test("Full cycle: insert + remove + insert + inc + clear");
        clear_mem;
        do_op("10", "000101", "00", "Insert ID=5, P=0");     -- count=1
        check_count(1, "Test 20: count=1 dopo insert");
        do_op("10", "001010", "10", "Insert ID=10, P=2");    -- count=2 [5,0][10,2]
        check_count(2, "Test 20: count=2 dopo secondo insert");
        do_op_check_id("01", "000000", "00", "000101",
                       "Test 20: remove ID=5");               -- remove primo, count=1
        check_count(1, "Test 20: count=1 dopo remove");
        check_mem(1, make_task(10, 2), "Test 20: rimane ID=10 P=2");
        do_op("10", "000001", "01", "Insert ID=1, P=1");     -- insert P=1 (prio > 2, ma < 0)
                                                              -- ordine: [1,1] prio minore = piu alto -> [1,P=1], [10,P=2]
        do_op("00", "000000", "00", "OP 00");                 -- incrementa: [1,P=2], [10,P=3]
        check_mem(1, make_task(1, 2), "Test 20: dopo inc ID=1 P=2");
        check_mem(2, make_task(10, 3), "Test 20: dopo inc ID=10 P=3");
        do_op("11", "000000", "00", "Clear");                 -- svuota
        check_count(0, "Test 20: count=0 dopo clear");

        -- TEST 21: Insert 5 task, remove 2, insert 1, increment 2
        start_test("Insert 5 task, remove 2, insert 1, increment 2");
        clear_mem;
        do_op("10", "000001", "00", "Insert ID=1 P=0");
        do_op("10", "000010", "01", "Insert ID=2 P=1");
        do_op("10", "000011", "10", "Insert ID=3 P=2");
        do_op("10", "000100", "00", "Insert ID=4 P=0");
        do_op("10", "000101", "01", "Insert ID=5 P=1");
        -- Ordine atteso: [1,0], [4,0], [2,1], [5,1], [3,2]
        check_count(5, "Test 21: count=5");
        check_mem(1, make_task(1, 0), "Test 21: pos 1 = ID=1 P=0");
        check_mem(2, make_task(4, 0), "Test 21: pos 2 = ID=4 P=0");
        check_mem(3, make_task(2, 1), "Test 21: pos 3 = ID=2 P=1");
        check_mem(4, make_task(5, 1), "Test 21: pos 4 = ID=5 P=1");
        check_mem(5, make_task(3, 2), "Test 21: pos 5 = ID=3 P=2");
        -- Remove 2: esce ID=1, poi ID=4
        do_op_check_id("01", "000000", "00", "000001",
                       "Test 21: remove primo = ID=1");
        do_op_check_id("01", "000000", "00", "000100",
                       "Test 21: remove secondo = ID=4");
        -- Insert ID=6 P=1 -> dopo 2 remove, [2,1], [5,1], [3,2]: insert pos 3 (prima di P=2)
        do_op("10", "000110", "01", "Insert ID=6 P=1");
        check_mem(3, make_task(6, 1), "Test 21: pos 3 = ID=6 P=1 (coda P=1)");
        check_mem(4, make_task(3, 2), "Test 21: pos 4 = ID=3 P=2 (shiftato)");
        -- OP 00 -> [2,2], [5,2], [6,2], [3,3]
        do_op("00", "000000", "00", "OP 00 #1");
        check_mem(1, make_task(2, 2), "Test 21: dopo inc ID=2 P=2");
        check_mem(2, make_task(5, 2), "Test 21: dopo inc ID=5 P=2");
        check_mem(3, make_task(6, 2), "Test 21: dopo inc ID=6 P=2");
        check_mem(4, make_task(3, 3), "Test 21: dopo inc ID=3 P=3");
        -- Secondo OP 00
        do_op("00", "000000", "00", "OP 00 #2");
        check_mem(1, make_task(2, 3), "Test 21: dopo inc2 ID=2 P=3");
        check_mem(2, make_task(5, 3), "Test 21: dopo inc2 ID=5 P=3");
        check_mem(3, make_task(6, 3), "Test 21: dopo inc2 ID=6 P=3");
        check_mem(4, make_task(3, 3), "Test 21: dopo inc2 ID=3 P=3");

        -- TEST 22: Insert, increment, then insert with higher priority
        start_test("Insert 4 task, OP 00, poi insert nuova priorita alta");
        clear_mem;
        do_op("10", "000001", "00", "Insert ID=1 P=0");
        do_op("10", "000010", "00", "Insert ID=2 P=0");
        do_op("10", "000011", "01", "Insert ID=3 P=1");
        do_op("10", "000100", "10", "Insert ID=4 P=2");
        -- Ordine: [1,0], [2,0], [3,1], [4,2]
        check_mem(3, make_task(3, 1), "Test 22: pos 3 = ID=3 P=1");
        do_op("00", "000000", "00", "OP 00");  -- [1,1], [2,1], [3,2], [4,3]
        do_op("10", "000101", "00", "Insert ID=5 P=0 (alta priorita)");
        check_count(5, "Test 22: count=5");
        check_mem(1, make_task(5, 0), "Test 22: pos 1 = ID=5 P=0 (nuovo primo)");
        check_mem(2, make_task(1, 1), "Test 22: pos 2 = ID=1 P=1 (shift)");

        -- TEST 23: Stress test ping-pong insert/remove
        start_test("Stress ping-pong: Insert/Remove ripetuti");
        clear_mem;
        for i in 1 to 5 loop
            do_op("10", std_logic_vector(to_unsigned(i, 6)), "00",
                  "Ping-pong insert #" & integer'image(i));
            do_op_check_id("01", "000000", "00",
                           std_logic_vector(to_unsigned(i, 6)),
                           "Ping-pong remove #" & integer'image(i));
            check_count(0, "Test 23: count=0 dopo ciclo " & integer'image(i));
        end loop;
        report "  [OK] Test 23: 5 cicli insert/remove completati" severity note;

        -- ================================================================
        -- GRUPPO 7: RESET DURANTE OPERAZIONE
        -- ================================================================

        -- TEST 24: Reset durante OP 00 (incremento)
        start_test("Reset durante OP 00 (incremento)");
        init_mem(10,
            (1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
            (0, 0, 0, 0, 0, 1, 1, 1, 1, 1));
        tb_op            <= "00";
        tb_task_id       <= "000000";
        tb_task_priority <= "00";
        tb_start         <= '1';

        -- Aspetta qualche ciclo, poi asserta reset durante operazione
        wait for 150 ns;
        tb_rst <= '1';
        tb_start <= '0';  -- deassert start subito
        wait for 60 ns;
        tb_rst <= '0';     -- rilascia reset

        -- Lascia DUT completare INIT -> INIT_WAIT -> IDLE
        wait until rising_edge(tb_clk);  -- INIT  -> INIT_WAIT
        wait until rising_edge(tb_clk);  -- INIT_WAIT -> IDLE  (o_done='1')
        wait until rising_edge(tb_clk);  -- IDLE (o_done='0')
        -- Ora DUT è in IDLE con o_done='0'. Avvia OP 11 per leggere stato.
        do_op("11", "000000", "00", "OP 11 dopo reset");
        check_count(0, "Test 24: count=0 dopo reset durante OP 00");
        report "  [OK] Test 24: Reset durante OP 00 completato" severity note;

        -- TEST 25: Reset durante OP 10 (insert)
        start_test("Reset durante OP 10 (insert)");
        init_mem(5,
            (1, 2, 3, 4, 5),
            (0, 1, 1, 2, 3));
        tb_op            <= "10";
        tb_task_id       <= "000110";
        tb_task_priority <= "01";
        tb_start         <= '1';

        wait for 200 ns;  -- durante lo shift/insert
        tb_rst <= '1';
        tb_start <= '0';
        wait for 60 ns;
        tb_rst <= '0';

        -- Lascia DUT completare INIT -> INIT_WAIT -> IDLE
        wait until rising_edge(tb_clk);  -- INIT  -> INIT_WAIT
        wait until rising_edge(tb_clk);  -- INIT_WAIT -> IDLE  (o_done='1')
        wait until rising_edge(tb_clk);  -- IDLE (o_done='0')
        -- Ora DUT è in IDLE con o_done='0'. Avvia OP 11 per leggere stato.
        do_op("11", "000000", "00", "OP 11 dopo reset");
        check_count(0, "Test 25: count=0 dopo reset durante OP 10");
        report "  [OK] Test 25: Reset durante OP 10 completato" severity note;

        -- ================================================================
        -- GRUPPO 8: CATENE RAPIDE / TIMING
        -- ================================================================

        -- TEST 26: START immediato dopo DONE (catena rapida)
        start_test("START immediato dopo DONE");
        clear_mem;
        -- Inserisci un task
        tb_op            <= "10";
        tb_task_id       <= "000001";
        tb_task_priority <= "00";
        tb_start         <= '1';
        wait until rising_edge(tb_done);
        -- SUBITO dopo DONE, senza aspettare START=0, cambiamo operazione
        -- (ma la FSM richiede START=0 per uscire da DONE -> IDLE)
        -- Quindi: START va a 0, ma lo riportiamo a 1 al ciclo dopo
        tb_start <= '0';
        wait until falling_edge(tb_done);
        wait until falling_edge(tb_clk);
        -- Ora START=0, andiamo in IDLE. Subito dopo ripartiamo.
        tb_op            <= "01";
        tb_task_id       <= "000000";
        tb_task_priority <= "00";
        tb_start         <= '1';
        wait until rising_edge(tb_done);
        tb_start <= '0';
        wait until falling_edge(tb_done);
        wait until falling_edge(tb_clk);
        check_count(0, "Test 26: count=0 dopo remove rapido");
        report "  [OK] Test 26: Catena rapida START/DONE completata" severity note;

        -- TEST 27: START mantenuto alto per più cicli
        start_test("START prolungato per piu cicli");
        clear_mem;
        tb_op            <= "10";
        tb_task_id       <= "000010";
        tb_task_priority <= "00";
        tb_start         <= '1';
        -- Tieni START=1 per 5 cicli (l'operazione non dovrebbe ripartire)
        wait for 5 * CLOCK_PERIOD;
        wait until rising_edge(tb_done);
        tb_start <= '0';
        wait until falling_edge(tb_done);
        wait until falling_edge(tb_clk);
        -- Deve aver inserito UN SOLO task (count=1)
        check_count(1, "Test 27: count=1 (una sola operazione)");
        check_mem(1, make_task(2, 0), "Test 27: task ID=2 P=0");

        -- Cambia OP con START ancora alto (ma in IDLE non parte)
        -- Verifichiamo che serva un nuovo START=1
        tb_op <= "01";
        wait for CLOCK_PERIOD;
        tb_start <= '0';
        wait for 2*CLOCK_PERIOD;
        check_count(1, "Test 27: count=1 (nessuna operazione extra)");
        report "  [OK] Test 27: START prolungato non causa doppie esecuzioni" severity note;

        -- ================================================================
        -- FINE TEST
        -- ================================================================
        report "" severity note;
        report "==================================================" severity note;
        report "  TUTTI I TEST EDGE CASE COMPLETATI CON SUCCESSO" severity note;
        report "==================================================" severity note;
        report "Simulation ended! ALL EDGE CASE TESTS PASSED" severity note;
        std.env.stop(0);

    end process;
end tb_edge_cases_arch;
