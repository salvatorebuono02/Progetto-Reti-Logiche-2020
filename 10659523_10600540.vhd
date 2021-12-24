-----------PROGETTO RETI LOGICHE 
-----------Politecnico di Milano A.A. 2020/2021
-----------Alessandro Bianco [10659523] e Salvatore Buono [10600540]



Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Use IEEE.NUMERIC_STD.ALL;



-------------------STRUTTRA ENTITA PROPOSTA DA PROGETTO


entity project_reti_logiche is
     port (
	i_clk : in std_logic;
	i_rst : in std_logic;
	i_start : in std_logic;
	i_data: in std_logic_vector(7 downto 0);
	o_address : out std_logic_vector(15 downto 0);
	o_done    : out std_logic;
	o_en      : out std_logic;
	o_we      : out std_logic;
	o_data    : out std_logic_vector (7 downto 0)
     );
end project_reti_logiche;




----------------DESCRIZIONE MACCHINA A STATI
Architecture behavioral of project_reti_logiche is 

type state is ( 
	
	RESET,					------Stato di reset della macchina
	START,					------Stato di avvio della macchina
	WAIT_STATE,				------Stato di attesa per settare registro colonne o righe
	LOAD_COL,				------Stato in cui viene memorizzato il numero di colonne
	LOAD_RIG,				------Stato in cui viene memorizzato il numero di righe
	PRE_CALC,				------Stato che effettua il primo calcolo sulla dimensione
	CALC_DIM,				------Stato in cui viene calcolata la dimensione
	LOAD_FIRST,  			------Caricamento del primo valore come ipotetico massimo e minimo
	LOAD_VAL,				------Stato che permette il load del valore corrente
	CALC_MAXMIN,			------Stato dove viene eleaborato il massimo e minimo del vettore
	START_EQZ,				------Stato di inizio elaborazione del valore del pixel
	TEMPORARY_PX1,			------Stato di primo calcolo
	TEMPORARY_PX2,			------Stato di trafsormazione calcolo effettutato in vettore
	SHIFT_LEVEL,			------Stato per effettuare le operazioni di shift in base al valore assunto da delta_value
	END_EQZ,				------Stato per il confronto dell' elaborato e la predisposizione alla scrittura
	CTRL_PREW,				------Effettua dimensioni e setta o_data
	WRITING,				------Stato di scrittura su RAM del valore pixel equalizzato
	NEXT_PX,				------Predisposizione a prendere il prox px da equalizzare
	DONE,					------Stato di che porta alto o_done
	DONE_WAIT    			------Stato finale, resetta la macchina
);

	signal  NEXT_STATE : state;   ----Serve a tenere traccia dei cambiamenti di stato


---------------SEGNALI UTILI A LIMITARE I CICLI
signal limit_count : integer;
signal limit_eqz : integer;

---------------SEGNALI UTILI A SALVARE INDIRIZZI
signal start_addr : integer;
signal save_addr_NOTelab : std_logic_vector (15 downto 0);----utile per riprendere l'equalizzazione dall'indirizzo non ancora equalizzato

---------------SEGNALI UTILI A PREDISPORRE INDIRIZZI DI SCRITTURA
signal counter_eqz : integer;
signal addr_out :integer;

---------------FLAG DI CONTROLLO
signal o_ready_TOeqz : std_logic;
signal col_loaded : std_logic;

---------------SEGNALI CON COLONNE, RIGHE  E DIMENSIONE
signal o_righe : integer range 0 to 128;
signal o_col : integer range 0 to 128;
signal o_dim : integer;

---------------SEGNALI DI MASSIMO,MINIMO E LA LORO DIFFERENZA
signal o_minimo : integer range 0 to 255;
signal o_massimo : integer range 0 to 255;
signal delta_value : integer range 0 to 255;

---------------SEGNALI PER ELABORAZIONE PIXEL EQUALIZZATO
signal o_tempx0 : integer;
signal o_tempx1 : std_logic_vector(7 downto 0) ;
signal o_tempx2 : std_logic_vector(15 downto 0);
Signal o_px_TOctrl : integer ;

---------------VALORE DEL PIXEL CORRENTE
signal value : integer range 0 to 255;


begin
process(i_clk,i_rst)

begin

if (i_rst = '1') then
	NEXT_STATE <= RESET;
        
elsif (rising_edge(i_clk)) then 
	
	case NEXT_STATE is   
	
-----------STATO CHE RESETTA LA MACCHINA OGNI QUALVOLTA i_rst = 1
			when RESET =>
				o_en <= '0';
				o_we <= '0';	
				o_data <= "00000000";
				o_done <= '0';
				o_address <= "0000000000000000";									 
	
				o_dim <= 0;
				o_col <= 0;
				o_righe <= 0;

				o_minimo <= 0;	
				o_massimo <= 0;
				delta_value <= 0;
				o_tempx0 <= 0;
				o_tempx1  <= "00000000";
				o_tempx2  <= "0000000000000000";
				o_px_TOctrl <= 0;
	
				o_ready_TOeqz <= '0';
				col_loaded <= '0';
			
				save_addr_NOTelab <= "0000000000000000"; 
				value <= 0;
				start_addr <= 0;

				limit_count <= 0;
				limit_eqz <= 0;
				addr_out <= 0;

				counter_eqz <= 0;
				NEXT_STATE <= START;
				
----------STATO DI AVVIO DELLA MACCHINA, SI ATTENDE IL SEGNALE DI i_start PER PROSEGUIRE
			
			when START =>
				if (i_start = '1' AND i_rst = '0') then 
	      			o_en <= '1';
	        		o_we <= '0';
					counter_eqz <= 0;
		    		o_address <= "0000000000000000";
					col_loaded<= '0';
					o_ready_TOeqz <= '0';
					
		        	NEXT_STATE <= WAIT_STATE;
				end if;
            
----------STATO DI ATTESA PER CARICARE i_data
			
			when WAIT_STATE =>
			
					if (col_loaded = '0') then
						NEXT_STATE <= LOAD_COL;
					else
						NEXT_STATE <= LOAD_RIG;
					end if;
					
---------------CARICAMENTO DELLE COLONNE

			when LOAD_COL =>
			
				o_col <= TO_INTEGER(unsigned(i_data));
				col_loaded <= '1';
			
				if (i_data = "00000000") then 
					NEXT_STATE <= DONE;    --------se le colonne sono pari a 0 non c'è niente da equalizzare
				else
					o_address <= "0000000000000001";
					NEXT_STATE <= WAIT_STATE;
				end if;

			
------------------CARICAMENTO DELLE RIGHE
	
			when LOAD_RIG =>
			
				o_righe <= TO_INTEGER(unsigned(i_data));
				o_address <= "0000000000000010";
				if (i_data = "00000000") then 
					NEXT_STATE <= DONE;   --------- se le righe sono pari a0 non c'è niente da equalizzare
				else
					NEXT_STATE <= PRE_CALC;
				end if;

--------------STATO DI INIZIO CALCOLO DIMENSIONE

			when PRE_CALC =>
			
				o_dim <= o_col;
				o_righe <= o_righe - 1 ; ------infatti se siamo arrivati fin qui, c'è almeno una riga: mi anticipo il primo calcolo
				NEXT_STATE <= CALC_DIM;
			
------------------CALCOLO DIMENSIONE
					
			when CALC_DIM =>
				
				if (o_righe > 0) then   ------la moltiplicazione riga per colonna è vista dal punto di vista combinatorio come somme successive
				  	o_dim <= o_dim + o_col;
	              	o_righe <= o_righe - 1 ;
				  	NEXT_STATE <= CALC_DIM;
				else
					o_address <= "0000000000000011";
                	NEXT_STATE <= LOAD_FIRST;
				end if;
				
------------------SETTAGGIO MASSIMO E MINIMO	
		
			when LOAD_FIRST =>

				o_massimo <= TO_INTEGER(unsigned(i_data));
				o_minimo <= TO_INTEGER(unsigned(i_data));
				limit_count <= o_dim + 2; --------Vengono settati i limiti di elaborazione informazioni utilizzati per ciclare
				limit_eqz <= o_dim + 3;
				start_addr <= 4;
				if (o_dim = 1) then
					o_ready_TOeqz <= '1'; ---non serve calcolare massimo e minimo: possiamo equalizzare
					start_addr <= 2;
					o_address <= "0000000000000010";
				end if;
				
               	NEXT_STATE <= LOAD_VAL;
			

----------------CARICAMENTO VALORE PIXEL CORRENTE

			when LOAD_VAL =>
				o_we <= '0';
				
				if (o_ready_TOeqz = '0') then -------------Flag di controllo: sarà portato ad 1 quando sarà computato il calcolo max/min
					value <= TO_INTEGER(unsigned(i_data));
					o_address <= std_logic_vector(TO_UNSIGNED(start_addr,16));

					NEXT_STATE <= CALC_MAXMIN;
				else
					delta_value <= o_massimo - o_minimo; ---settaggio delta_value e passaggio nello stato di equalizzazione
					start_addr <= start_addr + 1;
					NEXT_STATE <= START_EQZ;
				end if;
				
--------------------------STATO DI CALCOLO MAX/MIN		
	
			when CALC_MAXMIN =>
				
				if (value < o_minimo) then
					o_minimo <= TO_INTEGER(unsigned(i_data));
				elsif (value > o_massimo) then
                    o_massimo <= TO_INTEGER(unsigned(i_data));
				end if;
					
				if (start_addr < limit_count) then  ----utlizzo il limitatore che ho settato prima 
					start_addr <= start_addr + 1;
      			  	
					NEXT_STATE <= LOAD_VAL;					
				
				else
				
					o_address <= "0000000000000010";------Settaggio indirizzo per ripartire correttamente dal primo valore di pixel
					start_addr <= 2;
					o_ready_TOeqz <= '1';
					
					NEXT_STATE <= LOAD_VAL;
				end if;
				    
--------------STATO DI INIZIO ELABORAZIONE VALORE PIXEL
		
			when START_EQZ =>
			
				o_we <= '0';
				if (start_addr < limit_eqz) then ------utilizzo il limitatore settato prima per le equalizzazioni
					save_addr_NOTelab <= std_logic_vector(TO_UNSIGNED(start_addr,16));
					value <= TO_INTEGER(unsigned(i_data));
					
					NEXT_STATE <= TEMPORARY_PX1;
				else 
					NEXT_STATE <= DONE;
				end if;
				
---------------CALCOLO VALORE DA CONVERTIRE IN VETTORE

			when TEMPORARY_PX1 =>
				o_tempx0 <= value - o_minimo;
				NEXT_STATE <= TEMPORARY_PX2;
				
---------------STATO DI CONVERSIONE VALORE IN VETTORE	
		
			when TEMPORARY_PX2 =>
				o_tempx1 <= std_logic_vector(to_unsigned(o_tempx0,8));
				NEXT_STATE <= SHIFT_LEVEL;

------------------SHIFT LEVEL
------------------se valutiamo un vettore da 16 bit composto da tanti zeri quanti sono i valori da shiftare, la differenza calcolata prima e antecediamo gli zeri per compensare ed arivare a 16 bit, quando ritrasformeremo il valore, sarà come averlo moltiplicato per potenze di 2

			when SHIFT_LEVEL =>
				case delta_value is
					when 0 => o_tempx2 <= o_tempx1 & "00000000";
					when 1 to 2 => o_tempx2 <= "0" & o_tempx1 & "0000000";
					when 3 to 6 => o_tempx2 <= "00" & o_tempx1 & "000000";
					when 7 to 14=> o_tempx2 <= "000"& o_tempx1 &"00000";
					when 15 to 30 => o_tempx2 <= "0000" & o_tempx1 & "0000";
					when 31 to 62 => o_tempx2 <= "00000" & o_tempx1 & "000";
					when 63 to 126 => o_tempx2 <= "000000" & o_tempx1 & "00";
					when 127 to 254 => o_tempx2 <= "0000000" & o_tempx1 &"0";
					when 255 =>  o_tempx2 <= "00000000" & o_tempx1;
				end case;
	
				NEXT_STATE <= END_EQZ;

--------------FINE EQUALIZZAZIONE E PREDISPOSIZIONE VALORE DA SCRIVERE

			when END_EQZ =>
				
				o_px_toCTRL <= TO_INTEGER(unsigned(o_tempx2));
				addr_out <= limit_count + counter_eqz;
				counter_eqz <= counter_eqz + 1;
				NEXT_STATE <= CTRL_PREW;


-----------------PREPARAZIONE INDIRIZZO DI SCRITTURA E CONTROLLO LIMITE A 255
		
			when CTRL_PREW =>
			
				if(o_px_TOctrl < 255) then ----controllo di valore massimo ammissibile sulla scala di grigi
					o_data <= std_logic_vector(to_unsigned(o_px_toCTRL,8));
				else
					o_data <= "11111111";
				end if;
				
				o_address <= std_logic_vector(TO_UNSIGNED(addr_out,16));
				NEXT_STATE <= WRITING;

------------SCRITTURA SU MEMORIA PIXEL EQUALIZZATO

			when WRITING =>
		
				o_we <= '1';-----inizia lo stato di scrittura, we è alto per il successivo ciclo di clock
				
				NEXT_STATE <= NEXT_PX;
		
-------------PREPRAZIONE PROSSIMO INDIRIZZO DA EQUALIZZARE	
			when NEXT_PX =>
				o_we <= '0';------in questo stato viene scritto il valore in memoria e si prepara l'indirizzo della prossima equalizzazione
				o_address <= save_addr_NOTelab;
				NEXT_STATE <= LOAD_VAL;

-----------------STATO CHE MANDA ALTO IL SEGNALE DI DONE

			when DONE =>
				o_done <= '1';
				o_we <= '0';
				o_en <= '0';
				NEXT_STATE <= DONE_WAIT;
				
-----------------STATO FINALE DI ATTESA PER UNA NUOVA ELABORAZIONE

			when DONE_WAIT =>
			
				if(i_start = '1' AND i_rst = '0') then ----continuo a ciclare qui fino a quando lo start non si abbassa
					NEXT_STATE <= DONE_WAIT;
					
				elsif (i_start ='0') then
				 	o_done <= '0';
				 	NEXT_STATE <= START;
			    end if;
		
	end case;
end if;
end process;
	
end Behavioral;


