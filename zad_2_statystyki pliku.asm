;===========================================================================================================================================
;	Mateusz Buta 
; 	Zadanie 2
; 	Odczyt z pliku
;	Statystyka i weryfikacja pliku
;===========================================================================================================================================
dane1   segment

	;STALE PARSER
	SEPARATOR 	equ 0				; znak rozdzielajacy argumenty
	SPACJA		equ 20h				; kod Asci spacji
	TAB			equ 9h				; kod Asci tabulatora	
	LICZBA_ARG	equ 2 				; liczba argumentow
	
	;ZMIENNNE PARSER
	ile_znak_wiersz dw 0			; ilosc znakow wpisanych do wiersza polecen
	ile_arg dw 0					; ilosc wczytanych argumentow
	
	dl_args db 10 dup(?)			; tablica dlugosci argumentow
	args db 60 dup(?),SEPARATOR 	; tablica argumentow rozdzielonych separatorem
	
	;STALE PROGRAM
	DL_BUFORA equ 4000h  			; dlugosc 16KB bufora
	DL_TAB_OFFSETOW equ 14			; dlugosc tablicy offsetow drukowanych napisow statystyk
	CR equ 0Dh 						; kod Asci znaku powrotu karetki
	LF equ 0Ah 						; kod Asci znaku nowej lini	
	ILE_Z_INTERPUNK dw 9			; liczba znakow interpunkcyjnych
	Z_INTERPUNK db ".,:;?!-'",'"'	; tablica znakow interpunkcyjnych
	ILE_Z_BIALE dw 9				; liczba bialych znakow
	Z_BIALE db SPACJA,TAB			; tablica bialych znakow
	
	;ZMIENNE PROGRAM
	koniec_pliku db 0				; flaga, przyjmuje wartosc 1 jesli nastapil koniec pliku
	ile_znak_pobrano dw 0			; licznik znakow przechowywanych w buforze
	
	id_pliku_do_odczytu dw ?		; uchwyt pliku do odczytu
	id_pliku_do_zapisu dw ?			; uchwyt pliku do zapisu

	ile_lini dw 0					; liczniki do statystyk
	ile_zdan dw 0					;
	ile_wyrazow dw 0				;
	ile_liter dw 0					;
	ile_cyfr dw 0					;
	ile_biale dw 0					;
	ile_interpunk dw 0				;
	
	byl_interpunk db 0 				; flagi
	byl_bialy_znak db 0				;
	byl_litera db 0					;
	byl_cyfra db 0					;
	poczatek_wyraz db 0				;
	koniec_wyraz db 0				;

	bufor db DL_BUFORA dup(?)		; bufor znakow pobranych z pliku
	ile_znakow_bufora dw DL_BUFORA	; licznik pobranych znakow z bufora do programu
	
	liczba db 6 dup(?),				; tablica gdzie zwracana jest liczba po konwersji na strig

	
	;DRUKOWANE NAPISY
	napis_weryfikacja db "Weryfikacja pliku... $"					; drukowane napisy 
	napis_statystyka db "Statystyka pliku... ",CR,LF,'$'			;
	blad_znak_1 db CR,LF,"Zly znak: $"								; 
	blad_znak_2 db CR,LF,"Numer lini: $"							; 
	blad_znak_3 db CR,LF,"Numer znaku w lini: $"					;
	dobre_znaki db CR,LF,"Wszystkie znaki w pliku sa poprawne $"	;
	
	napis_linie db 			"Liczba lini: $"			; drukowane napisy stastyk
	napis_zdan db CR,LF,	"Liczba zdan: $"			;
	napis_wyrazow db CR,LF,	"Liczba wyrazow: $"			;
	napis_litery db CR,LF,	"Liczba liter: $"			;
	napis_cyfry db CR,LF,	"Liczba cyfr: $"			;
	napis_biale db CR,LF,	"Biale znaki: $"			;
	napis_interpuk db CR,LF,"Znaki interpunkcyjne: $"	;
	
	tab_napis dw offset napis_linie, offset napis_zdan, offset napis_wyrazow, offset napis_litery, offset napis_cyfry, offset napis_biale, offset napis_interpuk
	; tablica offsetow drukowanych napisow
	tab_dl dw 13,15,18,16,15,15,24
	; tablica dlugosci drukowanych napisow
	
	; KOMUNIKATY BLEDOW
	blad_argumentow db "Bledne argumenty.",CR,LF,"Kod bledu: $"
	blad_utworzenia  db "Blad utworzenia pliku.",CR,LF,"Kod bledu: $"
	blad_otwarcia  db "Blad otwarcia pliku.",CR,LF,"Kod bledu: $"
	blad_czytania  db "Blad czytania pliku.",CR,LF,"Kod bledu: $"
	blad_zapisu db "Blad zapisu do pliku.",CR,LF,"Kod bledu: $"
	blad_zamkniecia  db "Blad zamkniecia pliku.",CR,LF,"Kod bledu: $"
	blad_zawartosci  db "W pliku znajduja sie niepoprawne znaki",CR,LF,"Kod bledu: $"
 
dane1   ends
;===========================================================================================================================================      
stos1	segment STACK

	dw	100h dup(?)					;256 x slowo o dowolnej wartosci
	wierzch1	dw ?
	
stos1	ends        
;===========================================================================================================================================
kod1	segment
;===========================================================================================================================================		
	koniec_prog macro					; zakoncz program
        mov ax, 04C00h
        int 21h
    endm
;===========================================================================================================================================	
	blad macro
		; ax - kod bledu
		; dx - offset drukowanego bledu
		call liczba_na_string
		; ax - pobiera drukowana liczba, zwraca liczbe cyfr
		; liczba jest zapamietana w tablicy liczba
		mov ah,9h						; funkcja 9h przerwania 21h drukowanie stringu ds:dx  
		int 21h							; drukowanie komunikatu o bledzie
		
		mov dx,offset liczba			; funkcja 9h przerwania 21h drukowanie stringu ds:dx		
		mov ah,9h						; drukowanie kodu bledu
		int 21h							; 		
		koniec_prog
	endm
;===========================================================================================================================================
	;	MAKRA DO STATYSTYK
;============================================================================================================================================
	inkrementuj macro zmienna
		push bx
		mov bx,[zmienna]
		inc bx
		mov [zmienna],bx	
		pop bx
	endm
;===========================================================================================================================================	
	interpunkcyjne macro
		; parametry:
		; al - pobiera znak, zwraca pierwszy nie interpunkcyjny znak
		; ah - poprzedni znak
		local zlicz_interpunk_nie_pobierz_znak,	zlicz_interpunk_pobierz_znak,	koniec_interpunk	
		local sprawdz_interpunk,	sprawdz_dalej_interpunk	
		
		mov [byl_interpunk],0
		jmp zlicz_interpunk_nie_pobierz_znak
		
		zlicz_interpunk_pobierz_znak:
			call pobierz_znak
			; Parametry:
			; al - zwracany znak
			
			cmp [koniec_pliku],1			; sprawdzanie czy nastapil czy koniec pliku
			je koniec_sprawdz
			
			zlicz_interpunk_nie_pobierz_znak:
			
			xor bx,bx
			sprawdz_interpunk:
				cmp bx,ILE_Z_INTERPUNK
				jae koniec_interpunk
					
				cmp al,[Z_INTERPUNK+bx]			; sprawdzanie w petli znakow interpunkcyjnych
				jne sprawdz_dalej_interpunk		;
				inkrementuj ile_interpunk
				mov byl_interpunk,1
				jmp zlicz_interpunk_pobierz_znak
					
				sprawdz_dalej_interpunk:
				inc bx
			jmp sprawdz_interpunk
			
		koniec_interpunk:
	endm
;===========================================================================================================================================
	biale_znaki macro
		; parametry:
		; al - pobiera znak, zwraca pierwszy nie bialy znak
		; ah - poprzedni znak
		local zlicz_biale_znaki_nie_pobierz_znak,	zlicz_biale_znaki_pobierz_znak,	koniec_biale_znaki	
		local sprawdz_biale_znaki,	sprawdz_dalej_biale_znaki	
		
		mov [byl_bialy_znak],0	
		jmp zlicz_biale_znaki_nie_pobierz_znak
		
		zlicz_biale_znaki_pobierz_znak:
			call pobierz_znak
			; Parametry:
			; al - zwracany znak
			
			cmp [koniec_pliku],1			; sprawdzanie czy nastapil czy koniec pliku
			je koniec_sprawdz
			
			zlicz_biale_znaki_nie_pobierz_znak:
			
			xor bx,bx
			sprawdz_biale_znaki:
				cmp bx,ILE_Z_BIALE
				jae koniec_biale_znaki
					
				cmp al,[Z_BIALE+bx]			; sprawdzanie w petli znakow interpunkcyjnych
				jne sprawdz_dalej_biale_znaki;
				inkrementuj ile_biale
				mov byl_bialy_znak,1
				jmp zlicz_biale_znaki_pobierz_znak
					
				sprawdz_dalej_biale_znaki:
				inc bx
			jmp sprawdz_biale_znaki
			
		koniec_biale_znaki:
	endm
;===========================================================================================================================================	
	cyfry macro
		; parametry:
		; al - pobiera znak, zwraca pierwszy znak nie będący cyfrą
		; ah - poprzedni znak	
		local zlicz_cyfry_nie_pobierz_znak,	zlicz_cyfry_pobierz_znak,	koniec_cyfry

		mov [byl_cyfra],0		
		jmp zlicz_cyfry_nie_pobierz_znak
		
		zlicz_cyfry_pobierz_znak:
			call pobierz_znak
			; Parametry:
			; al - zwracany znak
			
			cmp [koniec_pliku],1			; sprawdzanie czy nastapil czy koniec pliku
			je koniec_sprawdz	
			
			zlicz_cyfry_nie_pobierz_znak:				
		
			cmp al,'0'						; czy kod asci znaku miesci się w zakresie kodow asci od 0 do 9
			jb koniec_cyfry					;
            cmp al,'9'						;
			ja koniec_cyfry					;	
			inkrementuj ile_cyfr
			mov [byl_cyfra],1
			jmp zlicz_cyfry_pobierz_znak		
			
		koniec_cyfry:
	endm	
;===========================================================================================================================================
	litery macro
		; parametry:
		; al - pobiera znak, zwraca pierwszy znak ktory nie jest litera
		; ah - poprzedni znak	
		local zlicz_litery_nie_pobierz_znak,	zlicz_litery_pobierz_znak,	koniec_litery	
		local sprawdz_dalej_litery	 
		
		mov [byl_litera],0
		jmp zlicz_litery_nie_pobierz_znak
		
		zlicz_litery_pobierz_znak:
			call pobierz_znak
			; Parametry:
			; al - zwracany znak
			
			cmp [koniec_pliku],1			; sprawdzanie czy nastapil czy koniec pliku
			je koniec_sprawdz	
			
			zlicz_litery_nie_pobierz_znak:
		
			cmp al,'A'						; czy kod asci znaku miesci sie w zakresie  asci od A do Z
			jb koniec_litery				;
            cmp al,'Z'						;
			ja sprawdz_dalej_litery			;	
			inkrementuj ile_liter
			mov [byl_litera],1
			jmp zlicz_litery_pobierz_znak
			
			sprawdz_dalej_litery:
			
			cmp al,'a'						; czy kod asci znaku miesci sie w zakresie  asci od a do z
			jb koniec_litery				;
            cmp al,'z'						;
			ja koniec_litery				;
			inkrementuj ile_liter
			mov [byl_litera],1
			jmp zlicz_litery_pobierz_znak
		
		koniec_litery:
	endm
;===========================================================================================================================================
start1:	
	.286							; dopuszcza stosowanie w programie instrukcji procesora 80286 (np. przesuwanie o wile bitow)
	assume ds:dane1, ss:stos1		; deklaracja zawartosci rejestrow segmentowych

	mov ax,dane1                	; inicjacja segmentu danych
	mov ds,ax                   	;	
	
	mov	ax,seg wierzch1		    	; inicjacja stosu
	mov	ss,ax			        	;
	mov	sp,offset wierzch1      	;
	
	call pobieranie_wiersza		
	call sprawdzanie_arg
	

	cmp [args],'-'					; sprawdzanie czy 1 argument ma postać "-v"
	jne statystyki					;
	cmp [args+1],'v'				;
	jne statystyki					;
	cmp [args+2],SEPARATOR			;
	jne statystyki					;

	call weryfikuj_znaki
	koniec_prog
	
	statystyki:
	call statystyki_pliku
	koniec_prog
;===========================================================================================================================================
	pobieranie_wiersza proc
	    push ax
	    push bx	
	    push di
	    push si			
	
	    mov ah,62h                  	; pobranie segmentu PSP do bx, w którym offset 80H,81H wskazuje znaki wprowadzone w wierszu poleceń
		int 21h							;	
		mov es,bx						; zapisanie segment PSP do es 
		
		xor ax,ax						;
		mov al,byte ptr es:[0080h] 		; pobranie liczby znakow ze wskazaniem na pobranie 1 bajtu z adresu					
		mov [ile_znak_wiersz],ax		; zapisanie liczby znaków do zmiennej         				
		
		xor di,di						; licznik ile znakow zostalo pobranych
		xor si,si						; licznik ile znakow zostalo wstawianych
		
		pobieraj_znaki:
			cmp di,[ile_znak_wiersz]		; warunek konca petli while, sprawdza czy pobrano wszystkie znaki z wiersza
            jae koniec_wiersza				;
			
			mov al,es:[di+0081h]			; pobranie znaku wprowadzonego w wierszu poleceń do al
			inc di							;
			
		    cmp al,SPACJA                 	; Sprawdzanie czy pobrany znak jest bialym znakiem
    	    je pobieraj_znaki      			; jesli tak to pobieranie kolejnego znaku
		    cmp al,TAB						; 
    	    je pobieraj_znaki               ; 
			
			call pobierz_argument			; brak bialych znakow - znak rozpoczyna argument, funkcja pobranie argumentu
			; parametry:
			; al - pobiera pierwszy znak argumentu,zwaca pierwszy bialy znak
			; di,si liczniki znakow
        jmp pobieraj_znaki				; petla, pobierajaca wszystkie znaki z wiersza
			
		koniec_wiersza:
	    pop si
	    pop di 		
	    pop bx 
	    pop ax 	    
	    ret
	pobieranie_wiersza endp
;===========================================================================================================================================
	pobierz_argument proc
		; parametry:
		; al - pobiera pierwszy znak argumentu,zwaca pierwszy bialy znak
		; di,si - liczniki znakow
		push bx
		
		xor bx,bx 						; bx licznik znakow biezacego argumentu
		pobieraj_znaki_argumentu:
			mov [args+si+bx],al 			; zapisanie pobranego znaku do arg
			inc bx							; 
			
			cmp di,[ile_znak_wiersz]		; warunek konca petli, sprawdza czy pobrano wszystkie znaki
            jae koniec_argumentu			;			
			
			mov al,es:[di+0081h]			; pobranie znaku wprowadzonego w wierszu poleceń do al
			inc di							;
			
		    cmp al,SPACJA                 	; Sprawdzanie czy pobrany znak jest bialym znakiem,  
    	    je koniec_argumentu    			; jesli tak to koniec arguemntu
		    cmp al,TAB						; 
    	    je koniec_argumentu    			;          		
		jmp pobieraj_znaki_argumentu			
	
		koniec_argumentu:		
		mov [args+si+bx],SEPARATOR 			; dopisanie '$' po argumencie
		add si,bx						;
		inc si							; aktualizacja licznika znakow si
		
		push di
		mov di,[ile_arg]				; uzupelnienie tabicy przechowujecej dlugosc argumentow
		
		mov [dl_args+di],bl				;
		pop di

		mov bx,[ile_arg]				; zwiekszenie liczby argumentow
		inc bx							;
		mov [ile_arg],bx				;
		
		pop bx						
		ret
	pobierz_argument endp
;===========================================================================================================================================
	zwroc_argument proc
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow
		push cx
		push bx
				
		xor bx,bx						; bx - suma przesuniec w tablicy argumentow
		mov cx,ax						; cx - licznik sumowanych argumentow
		dec cx							;	 
		cmp cx,0						; 
		je koniec_zwroc					;
		
		sumuj_dlugosci_argumentow:
			mov ax,cx
			call zwroc_dl_argumentu
			; parametry:
			; ax - pobiera nr argumentu od 1, zwraca dlugosc
			add bx,ax						; sumowane dlugosci argumentow
			inc bx							; dodanie separatora
		loop sumuj_dlugosci_argumentow
		
		koniec_zwroc:
		mov ax,bx
		
		pop bx
		pop cx
		ret
	zwroc_argument endp
;===========================================================================================================================================	
	zwroc_dl_argumentu proc
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca dlugosc	
		push bx
		
		dec ax								; przesuniecia w tablicy dlugosci są od 0
		mov bx,ax							; bx - przesuniecie w tablicy argumentow
		
		xor ax,ax							; zapisanie do ax przesuniecia
		mov al,[dl_args+bx]					;
		
		pop bx
		ret
	zwroc_dl_argumentu endp
;===========================================================================================================================================
	sprawdzanie_arg proc
		push ax
		push dx
		
		cmp [ile_arg],LICZBA_ARG			; sprawdzanie czy w wierszu byly 2 argumenty
		je dobra_ilosc_argumentow			;
		mov dx,offset blad_argumentow		; jesli nie to obsluga bledu
		xor ax,ax							;
		blad								;
		
		dobra_ilosc_argumentow:
		pop ax
		pop dx
		ret
	sprawdzanie_arg endp
;===========================================================================================================================================
    utworz_plik proc
		; parametry:
		; ax - pobiera offset nazwy pliku, zwraca id pliku (uchwyt)	
		push cx
		push dx		
		
		xor cx,cx						; cx -atrybuty pliku
        mov dx,ax						; dx - offset nazwy pliku
		mov	ah,3Ch	 			        ; funkcja 3Ch przerwania 21h utworzenie i otwarcie pliku, 		
	    int	21h 						; jesli plik istnieje to jego zawartosc jest tracona

		jnc koniec_utworzenia			; flaga CF=0 jesli przerwanie nie zakonczylo sie bledem
		mov dx,offset blad_utworzenia	; obsluga bledu
		blad							;
		
		koniec_utworzenia:	
		pop dx
		pop cx		
		ret
	utworz_plik endp	
;===========================================================================================================================================		
    otworz_plik proc
		; parametry:
		; ax - pobiera offset nazwy pliku, zwraca id pliku (uchwyt)
		push dx
		
        mov dx,ax						; dx - offset nazwy pliku
		mov al,0						; al=0 - otwarcie pliku do odczytu
		mov	ah,3Dh	 			        ; funkcja 3Dh przerwania 21h otwarcie istniejacego pliku 		
	    int	21h 						; 

		jnc koniec_otwarcia				; flaga CF=0 jesli przerwanie nie zakonczylo sie bledem
		mov dx,offset blad_otwarcia		; obsluga bledu
		blad							;
		
		koniec_otwarcia:	
		pop dx
		ret
	otworz_plik endp
;===========================================================================================================================================	
	zamknij_plik proc
		; parametry:
		; ax - id pliku (uchwyt);	
		push bx
		push dx		
	
		mov bx,ax						; bx - id pliku (uchwyt)
		mov	ah,3Eh  			        ; funkcja 3Eh przerwania 21h zamkniecie pliku 		
	    int	21h 						;	
	
		jnc koniec_zamkniecia			; flaga CF=0 jesli przerwanie nie zakonczylo sie bledem
		mov dx,offset blad_zamkniecia	; obsluga bledu
		blad							;
	
		koniec_zamkniecia:
		pop dx
		pop bx
		ret
	zamknij_plik endp
;===========================================================================================================================================
	pobierz_znak proc
		; Parametry:
		; al - zwracany znak
		push bx
		push cx
		push dx
		
		push ax							; odlozenie poprzedniego pobranego znaku na stos
		
		mov bx,[ile_znakow_bufora]		; pobranie licznika znakow przechowywanych w buforze
		inc bx							;
		cmp bx,[ile_znak_pobrano]		; sprawdzenie czy licznik doszedł do końca pobranych znakow
		jb nie_pobieraj_bufora			; jesli nie to nie trzeba pobierac nowego bufora
		
		mov bx,[id_pliku_do_odczytu]	; bx - id pliku (uchwyt)
		mov dx,offset bufor				; odczyt z pliku stringu ds:dx
		mov cx,DL_BUFORA				; cx - liczba czytanych znakow
		mov ah,3Fh  					; funkcja 3Fh przerwania 21h pobranie cx znakow do stringu ds:dx
		int 21h  						;	
		mov [ile_znak_pobrano],ax		; zapamietanie ile znakow pobrano
		
		jnc poprawne_pobranie			; flaga CF=0 jesli przerwanie nie zakonczylo sie bledem
		mov dx,offset blad_czytania		; obsluga bledu
		blad							;
		
		poprawne_pobranie:		
		xor bx,bx

		cmp ax,0						; sprawdzenie czy liczba pobranych znakow nie jest rowna 0
		jne nie_pobieraj_bufora			;
		mov [koniec_pliku],1			; bo wtedy koneic pliku
		
		nie_pobieraj_bufora:
		pop ax							;
		mov ah,al						; zapamietanie poprzedniego pobranego znaku w ah
		mov al,[bufor+bx]				; zwrocenie kolejnego znaku z bufora 
		mov [ile_znakow_bufora],bx		;
		
		pop dx
		pop cx
		pop bx
		ret
	pobierz_znak endp
;===========================================================================================================================================
	zapisz_do_pliku proc
		; paramtery:
		; bx - offset napisu
		; ax - liczba znakow 
		; koniec_pliku - flaga, 1 jesli nastopil koniec pliku
		push cx
		push dx
		push di ; chodzi po buforze
		push si ; chodzi po ds:dx
			
		cmp [koniec_pliku],1			; sprawdzenie czy juz koniec zapisu do pliku
		je koniec_zapisu_1				;
		
		mov di,[ile_znakow_bufora]		; di - indeks poruszajacy sie po buforze
		xor si,si						; si - indeks poruszajacy sie po napisie
		przepisuj_do_bufora:
				cmp di,DL_BUFORA				; czy koniec bufora
				je zapisuj_do_pliku				; 
				cmp si,ax						; czy koniec napisu
				je koniec_zapisu_2				; 
			
				mov dl,[bx+si]					; przpiesanie znaku z napisu do bufora
				mov [bufor+di],dl				;
				inc si							;
				inc di							;
			jmp przepisuj_do_bufora
			
			zapisuj_do_pliku:
			push bx							; 
			mov dx,offset bufor				; parametry do obsługi przerwania
			mov bx,[id_pliku_do_zapisu]		;
			mov cx,DL_BUFORA				;
			
			mov ah,40h						; funkcja 40h przerwania 21h zapis cx znaków ze stringu ds:dx do pliku 	 
			int 21h							;
			
			jnc poprawny_zapis_1			; flaga CF=0 jesli udane
			mov dx,offset blad_zapisu		; obsluga bledu
			blad							;
			
			poprawny_zapis_1:	
			xor di,di
			pop bx
		jmp przepisuj_do_bufora
		
		koniec_zapisu_1:
		mov dx,offset bufor				; parametry do obsługi przerwania
		mov bx,[id_pliku_do_zapisu]		;
		mov cx,[ile_znakow_bufora]		;

		mov ah,40h						; funkcja 40h przerwania 21h zapis cx znaków ze stringu ds:dx do pliku 	 
		int 21h							;
			
		jnc poprawny_zapis_2			; flaga CF=0 jesli udane
		mov dx,offset blad_zapisu		; obsluga bledu
		blad							;
		poprawny_zapis_2:		
		
		koniec_zapisu_2:
		mov [ile_znakow_bufora],di		; zapisanie dokąd jest zapisany bufor
		
		pop si
		pop di
		pop dx
		pop cx
		ret
	zapisz_do_pliku endp
;===========================================================================================================================================
	weryfikuj_znaki proc
		push ax
		push bx
		push dx
		push di
		push si	
		
		mov dx,offset napis_weryfikacja	;
		mov ah,9h						; funkcja 9h przerwania 21h drukowanie napisu ds:dx	 
		int 21h							;
	
		mov ax,2
		call zwroc_argument
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow
		
		add ax,offset args				; ustawienie odpowiedniego ofsetu na poczatek 2 argumentu
		call otworz_plik
		; parametry:
		; ax - pobiera offset nazwy pliku, zwraca id pliku (uchwyt)
		; al - tryb otwracia pliku
		mov [id_pliku_do_odczytu],ax	
		
		xor si,si						; licznik znakow w lini
		mov di,1						; licznik lini
		weryfikuj_znak:
			call pobierz_znak
			; Parametry:
			; al - zwracany znak
			cmp [koniec_pliku],1			; czy koniec pliku
			je wszystkie_dobre_znaki
			
			cmp al,CR						; jesli znak powrotu karetki
			jne weryfikuj_dalej_1			;
			xor si,si						; to zerowanie liczniku znakow  linie
			jmp weryfikuj_znak				;
			
			weryfikuj_dalej_1:
            cmp al,LF						; jesli znak nowej lini
			jne weryfikuj_dalej_2			;
			inc di							; to zwiekszanie licznika linii
			jmp weryfikuj_znak				;
			
			weryfikuj_dalej_2:
			inc si							; policzenie pobranego znaku, jesli nie byl CR lub LF
			
			xor bx,bx
			weryfikuj_interpunk:
				cmp bx,ILE_Z_INTERPUNK			
				jae weryfikuj_dalej_3				
				
				cmp al,[Z_INTERPUNK+bx]			; sprawdzanie znakow inteprunkcyjnych w petli
				je weryfikuj_znak				;
				inc bx							;
			jmp weryfikuj_interpunk
			
			weryfikuj_dalej_3:
			
			xor bx,bx
			weryfikuj_biale:
				cmp bx,ILE_Z_BIALE
				jae weryfikuj_dalej_4
				
				cmp al,[Z_BIALE+bx]				; sprawdzanie bialych znakow w petli
				je weryfikuj_znak				;
				inc bx							;
			jmp weryfikuj_biale

			weryfikuj_dalej_4:
			
			cmp al,'0'						; czy kod asci znaku miesci się w zakresie kodow asci od 0 do 9
			jb zly_znak 					;
            cmp al,'9'						;
			jbe weryfikuj_znak				;			
			
			cmp al,'A'						; czy kod asci znaku miesci się w zakresie kodow asci od A do Z
			jb zly_znak 					;
            cmp al,'Z'						;
			jbe weryfikuj_znak				;	

			cmp al,'a'						; czy kod asci znaku miesci się w zakresie kodow asci od a do z
			jb zly_znak 					;
            cmp al,'z'						;
			jbe weryfikuj_znak				;				

			jmp zly_znak					; jesli nie udalo sie wyfiltorowac znaku, to znaczy jest zly 
		
		zly_znak:
		
		call drukuj_zly_znak
		
		jmp koniec_weryfikuj_znaki
		
		wszystkie_dobre_znaki:
		mov dx,offset dobre_znaki		;
		mov ah,9h						; drukowanie komunikatu  
		int 21h							; 
			
		koniec_weryfikuj_znaki:
		mov ax,id_pliku_do_odczytu
		call zamknij_plik
		; parametry:
		; ax - id pliku (uchwyt);
		
		pop si
		pop di
		pop dx
		pop bx
		pop ax
		ret
	weryfikuj_znaki endp
;===========================================================================================================================================	
	drukuj_zly_znak proc
		push dx	
		; parametry:
		; al - zly znak
		
		mov dx,offset blad_znak_1		;
		mov ah,9h						; drukowanie komunikatu  
		int 21h							; 

		mov dl,al						; drukowanie blednego znaku
		mov ah,2h						; 
		int 21h			
		
		mov dx,offset blad_znak_2		;
		mov ah,9h						; drukowanie komunikatu  
		int 21h							;
		
		mov ax,di                		;	                     
		call liczba_na_string			; zamiana numeru linii na liczbe
		mov dx,offset liczba			; drukowanie numeru linii
		mov ah,9h						; 
		int 21h			
		
		mov dx,offset blad_znak_3		;
		mov ah,9h						; drukowanie komunikatu 
		int 21h							; 
		
		mov ax,si                		;	                     
		call liczba_na_string			; zamiana numeru znaku na liczbe
		mov dx,offset liczba			; drukowanie numeru znaku
		mov ah,9h						;
		int 21h		
	
		pop dx
		ret
	drukuj_zly_znak endp
;===========================================================================================================================================	
	statystyki_pliku proc
		push ax
		push bx
		push dx

		mov dx,offset napis_statystyka
		mov ah,9h						
		int 21h		
	
		mov ax,offset args				; ustawienie ofsetu na poczatek 1 argumentu
		call otworz_plik
		; parametry:
		; ax - pobiera offset nazwy pliku, zwraca id pliku (uchwyt)
		mov [id_pliku_do_odczytu],ax			

		mov ax,2
		call zwroc_argument
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow
		add ax,offset args				; ustawienie ofsetu na poczatek 2 argumentu

		call utworz_plik
		; parametry:
		; ax - pobiera offset nazwy pliku, zwraca id pliku (uchwyt)
		mov [id_pliku_do_zapisu],ax	
		
		call pobierz_znak				
		; Parametry:
		; al - zwracany znak	
	
		cmp [koniec_pliku],1			; sprawdzanie czy plik jest pusty
		je drukuj_wynik_sprawdzania		;	
	
		inkrementuj ile_lini			; jesli nie to ma przynajmniej jedna linie
	
		mov [poczatek_wyraz],1			; plik moze sie zaczynac od wyrazu
		jmp sprawdz_pobrany_znak
		
		sprawdz_pobierz_nowy_znak:
			
			call pobierz_znak				
			; Parametry:
			; al - zwracany znak
			
			cmp [koniec_pliku],1			; sprawdzanie czy plik jest pusty
			je koniec_sprawdz				;				
			
			sprawdz_pobrany_znak:

			mov [byl_bialy_znak],0
			mov [byl_litera],0
			mov [byl_cyfra],0
			mov [byl_interpunk],0
			
			cmp al,CR						; pomijanie znaku powrotu karetki
			jne sprawdz_dalej_1				;
			cmp [poczatek_wyraz],1
			jmp sprawdz_pobierz_nowy_znak	;
				
			sprawdz_dalej_1:
			
            cmp al,LF						; zliczanie znakow nowej linii			
			jne sprawdz_dalej_2				;
			inkrementuj ile_lini			;
			mov [poczatek_wyraz],1
			jmp sprawdz_pobierz_nowy_znak
			
			sprawdz_dalej_2:
			
			interpunkcyjne					; pobieranie ciagu znakow interpunkcyjnych
			cmp [byl_interpunk],1			
			jne sprawdz_dalej_3
			mov [poczatek_wyraz],1
			jmp sprawdz_pobrany_znak	
			
			sprawdz_dalej_3:	
		
			biale_znaki						; pobieranie ciagu bialych znakow
			cmp [byl_bialy_znak],1			
			jne sprawdz_dalej_4
			mov [poczatek_wyraz],1
			jmp sprawdz_pobrany_znak					
			
			sprawdz_dalej_4:
			
			litery							; pobieranie ciagu liter
			cmp [byl_litera],1			
			jne sprawdz_dalej_5
			
			cmp [poczatek_wyraz],1
			jne sprawdz_pobrany_znak
			
				biale_znaki
				
				sprawdz_koniec_zdania:		; badanie czy nastapilo zdanie
				cmp al,'?'
				je policz_zdanie
				cmp al,'!'
				je policz_zdanie
				cmp al,'.'
				je policz_zdanie
				jmp nie_licz_zdania
		
				policz_zdanie:
				inkrementuj ile_zdan
				inkrementuj ile_wyrazow
				jmp sprawdz_pobrany_znak
				
				; zwiekszanie licznika zdan i wyrazow		
				nie_licz_zdania:
				
				cmp [byl_bialy_znak],1			
				jne sprawdz_wyraz_dalej_1
				inkrementuj ile_wyrazow
				jmp sprawdz_pobrany_znak					
				
				sprawdz_wyraz_dalej_1:
				
				interpunkcyjne					; pobieranie ciagu znakow interpunkcyjnych
				cmp [byl_interpunk],1			
				jne sprawdz_wyraz_dalej_2
				inkrementuj ile_wyrazow	
				jmp sprawdz_pobrany_znak	

				sprawdz_wyraz_dalej_2:
				
				cmp al,CR						; pomijanie znaku powrotu karetki
				jne nie_bylo_wyrazu				;
				inkrementuj ile_wyrazow
				jmp sprawdz_pobierz_nowy_znak	;				
				
				nie_bylo_wyrazu:
				mov [poczatek_wyraz],0
				jmp sprawdz_pobrany_znak
				
			sprawdz_dalej_5:
			mov [poczatek_wyraz],0
			
			cyfry							; pobieranie ciagu cyfr
			cmp [byl_cyfra],1			
			je sprawdz_pobrany_znak

			; jesli znak przedarl sie przez to sito, to byl niepoprawny
			
			niepoprawny_znak:
			xor ax,ax
			mov dx,offset blad_zawartosci		; obsluga bledu
			blad	

		koniec_sprawdz:
		cmp ah,LF							; zmniejszanie liczby lini, jesli ostani znak byl znakiem nowej lini
		jne koniec_sprawdz_dalej			; bo ostatnia linia jest pusta, wiec nie mozna jej liczyc
		mov bx,[ile_lini]
		dec bx
		mov [ile_lini],bx
		
		koniec_sprawdz_dalej:
		
		cmp [byl_litera],1
		jne drukuj_wynik_sprawdzania
		cmp [poczatek_wyraz],1
		jne drukuj_wynik_sprawdzania
		inkrementuj ile_wyrazow
		
		drukuj_wynik_sprawdzania:			
		call drukuj_statystytki				; drukowanie statystyk na ekran i do pliku
		koniec_statystyki_pliku:
		mov ax,id_pliku_do_odczytu
		
		call zamknij_plik
		; parametry:
		; ax - id pliku (uchwyt);
		mov ax,id_pliku_do_zapisu
		call zamknij_plik
		; parametry:
		; ax - id pliku (uchwyt);
		
		pop dx
		pop bx
		pop ax	
		ret
	statystyki_pliku endp
;===========================================================================================================================================	
	drukuj_statystytki proc
		push ax
		push bx
		push cx
		push dx
		push di
	
		xor di,di
		
		mov [ile_znakow_bufora],0
		mov [koniec_pliku],0
		drukuj:
			mov bx,[tab_napis+di]			; ofset komunikatu
			mov ax,[tab_dl+di]				; dlugosc komunikatu
			
			call zapisz_do_pliku 
			; paramtery:
			; bx - offset napisu
			; ax - liczba znakow 
			; koniec_pliku - flaga, 1 jesli nastopil koniec pliku
		
			mov dx,[tab_napis+di]			;
			mov ah,9h						; drukowanie komunikatu na ekran
			int 21h							;
			
			mov ax,[ile_lini+di]            ; zamiana liczny na string    		                     
			call liczba_na_string			;
			; ax - pobiera drukowana liczba, zwraca liczbe cyfr
			; liczba jest zapamietana w tablicy liczba
			
			mov bx,offset liczba			; drukowanie liczby do pliku
			call zapisz_do_pliku 
			; paramtery:
			; bx - offset napisu
			; ax - liczba znakow 
			; koniec_pliku - flaga, 1 jesli nastopil koniec pliku			
			
			mov dx,offset liczba			;
			mov ah,9h						; drukowanie liczby na ekran
			int 21h							;
			
			inc di
			inc di
			cmp di,DL_TAB_OFFSETOW
			jae koniec_drukuj
		jmp drukuj

		koniec_drukuj:
		mov [koniec_pliku],1
		call zapisz_do_pliku 
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	drukuj_statystytki endp
;===========================================================================================================================================
	liczba_na_string proc
	; ax - pobiera drukowana liczba, zwraca liczbe cyfr
	; liczba jest zapamietana w tablicy liczba
	push bx
	push cx
	push dx
		
	xor cx,cx 						; licznik cyfr w liczbie
	wydziel_cyfry:
		xor dx,dx						; dx+ax - dzielna
		mov bx,10						; 10 - 2 bajtowy dzielnik 				
		div bx							;
		
		push dx							; odlozenie cyfry na stos 
		inc cx
		
		cmp ax,0						; warunek konca wydzielania cyfr
		je zapisz_liczbe				;
		
		jmp wydziel_cyfry
	zapisz_liczbe:
	mov ax,cx
	xor bx,bx						; indeks tablicy liczba gdzie wpisywane sa cyfry
	
	zapisz_cyfre:    
		pop dx							; pobranie cyfry ze stosu w odwrotnej kolejnosci
		add dx,48						; zamiana cyfry na Asci
		mov [liczba+bx],dl				; wpisanie do tablicy liczba
		inc bx							;
	loop zapisz_cyfre
	mov [liczba+bx],'$'				; '$' na koniec napisu
	
	pop dx
	pop cx
	pop bx
	ret
	liczba_na_string endp
;===========================================================================================================================================
kod1	ends
end start1
