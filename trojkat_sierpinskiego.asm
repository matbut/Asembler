;===========================================================================================================================================
;	Mateusz Buta 
; 	Zadanie 3
; 	Trojkat Sierpinskiego
;===========================================================================================================================================
dane1   segment

	;STALE PARSER
	SEPARATOR 	equ '$'				; znak rozdzielajacy argumenty
	SPACJA		equ 20h				; kod Asci spacji
	TAB			equ 9h				; kod Asci tabulatora	
	LICZBA_ARG	equ 2 				; liczba argumentow
	
	;ZMIENNNE PARSER
	ile_znak_wiersz dw 0			; ilosc znakow wpisanych do wiersza polecen
	ile_arg dw 0					; ilosc wczytanych argumentow
	
	dl_args db 10 dup(?)			; tablica dlugosci argumentow
	args db 40 dup(?),SEPARATOR 	; tablica argumentow rozdzielonych $
	
	;STALE PROGRAM
	CR equ 0Dh 						; kod Asci znaku powrotu karetki
	LF equ 0Ah 						; kod Asci znaku nowej lini
	KOLOR equ 03h
	TRZY dd 3.0

	;STALE STOS KOPROCESORA
	COS equ 0						; st(0)
	SIN equ 1						; st(1)
	RADIAN equ 2					; st(2)
	DELTA equ 3						; st(3)
	X_POZ equ 4 					; st(4)
	Y_POZ equ 5 					; st(5)
	
	;ZMIENNE PROGRAM
	dlugosc dw ?					; dlugosc boku
	rozdzielnosc dw ?				; liczba podzialow trojkata
	
	x_start dd 5.0					; wspolrzedne startowe 
	y_start dd 475.0				;
	
	max_x dw 640					; maksymalne wspolrzedne zeby nie wyjsc poza zakres bo tryb graficzny: 640x480 color graphics (MCGA,VGA)
	max_y dw 480					;
	
	x dw ?							; bierzace zaookraglone wspolrzedne
	y dw ?							;

	napis db 65087 dup(?),SEPARATOR
	
	;KOMUNIKATY O BLEDACH
	blad_argumentow db "Bledne argumenty.",CR,LF,"Kod bledu: $"
	
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
		; dx - offset drukowanego bledu
		mov ah,9h						; funkcja 9h przerwania 21h drukowanie stringu ds:dx  
		int 21h							; drukowanie komunikatu o bledzie		
		koniec_prog
	endm
;============================================================================================================================================
	koprocesor_inicjacja macro
		finit 							; inicjacja stosu`
		fld [y_start]					; polozenie wspolrzednych startowych
		fld [x_start]					;
		fldpi							; polozenie na stos pi
		fld [TRZY]						;
		fdivp st(1),st(0)				; dzielenie, wynik - pi/3
		fldz							; polozenie na stos 0
		fldz							; 
		fsin							; sinus
		fldz							;
		fcos							; cosinus
		
		; STOS
		; st(0) cosinus kata
		; st(1) sinus kata
		; st(2) kat w radianach
		; st(3) roznica katow: pi/3
		; st(4) wspolzedna x pozycji
		; st(5) wpsolrzeda y pozycji
	endm
;============================================================================================================================================	
	rotacja_w_prawo macro
		fstp st(7)						; zdjecie z wierzcu stosu sinusa i cosinusa bo bedzie liczony nowy
		fstp st(7)						; 
		
		fadd st(0),st(1)				; zwiekszenie kata o roznice
		fld st(0)						;
		fsin							; sinus nowego kata
		fld st(1)						;
		fcos							; cosinus nowego kata
	endm
;============================================================================================================================================	
	rotacja_w_lewo macro
		fstp st(7)						; zdjecie z wierzcu stosu sinusa i cosinusa bo bedzie liczony nowyv
		fstp st(7)						; 
		
		fsub st(0),st(1)				; zmniejszenie kata o roznice
		fld st(0)						;
		fsin							; sinus nowego kata
		fld st(1)						;
		fcos							;
	endm
;============================================================================================================================================
	tryb_graficzny macro
		push ax

	    xor ah,ah						;
	    mov al,12h  					; wywolanie trbu graficznego 640x480 color graphics (MCGA,VGA)
	    int 10h							;
		
		pop ax
	endm
;============================================================================================================================================
	tryb_tekstowy macro
		push ax
		xor ah,ah
		int 16h							; oczekiwanie na wcisniecie klawisza
		
		mov al,03h						; 
		xor ah,ah						; wywolanie trybu tekstowego
		int 10h							;
		pop ax
	endm
;============================================================================================================================================
start1:	
	.286							; dopuszcza stosowanie w programie instrukcji procesora 80286 (np. przesuwanie o wile bitow)
	.387							; koprocesor artmetyki zmiennoprzecinkowej
	assume ds:dane1, ss:stos1		; deklaracja zawartosci rejestrow segmentowych

	mov ax,dane1                	; inicjacja segmentu danych
	mov ds,ax                   	;	
	
	mov	ax,seg wierzch1		    	; inicjacja stosu
	mov	ss,ax			        	;
	mov	sp,offset wierzch1      	;
	
	call pobieranie_wiersza		
	call sprawdzanie_arg
	call args_na_liczby

	call gen_lsystem
		
	tryb_graficzny

	koprocesor_inicjacja 
	call rysuj_bok
	rotacja_w_lewo
	rotacja_w_lewo
	call rysuj_bok
	rotacja_w_lewo
	rotacja_w_lewo
	call rysuj_bok
	
	tryb_tekstowy
	
	koniec_prog
;============================================================================================================================================	
	gen_lsystem proc
		push ax
		push di
	
		xor di,di
		mov ax,[rozdzielnosc]
	
		call lsystem_A
		
		mov [napis+di],SEPARATOR				
	
		mov ax,[rozdzielnosc]
		or al,11111110b				; sprawdzanie parzystosci, i ewentulany rwerers zeby trojkat nie rysowal sie do gory podstawa
		cmp al,11111110b			;
		je nie_rewersuj				;
		call rewers					;
		
		nie_rewersuj:
		pop di
		pop ax
		ret
	gen_lsystem endp
;============================================================================================================================================	
	lsystem_A proc
		; parametry:
		; przyjmuje w ax liczbe interacji 
		; di - przesuniecie
		
		cmp ax,0
		je koniec_lsystem_A
		dec ax
		
		call lsystem_B
		mov [napis+di],'-'
		inc di
		call lsystem_A
		mov [napis+di],'-'
		inc di
		call lsystem_B
		
		inc ax
		ret		
		
		koniec_lsystem_A:
		mov [napis+di],'A'
		inc di	
		
		ret
	lsystem_A endp
;============================================================================================================================================	
	lsystem_B proc
		; parametry:
		; przyjmuje w ax liczbe interacji 
		; di - przesuniecie
		
		cmp ax,0
		je koniec_lsystem_B
		dec ax
		
		call lsystem_A
		mov [napis+di],'+'
		inc di
		call lsystem_B
		mov [napis+di],'+'
		inc di
		call lsystem_A
		
		inc ax
		ret		
		
		koniec_lsystem_B:
		mov [napis+di],'B'
		inc di	
			
		ret
	lsystem_B endp	
;============================================================================================================================================
	rewers proc
		push bx
		
		rewersuj:
			cmp [napis+bx],SEPARATOR
			je koniec_rewers
		
			cmp [napis+bx],'+'				;
			jne szukaj_dalej_1				; zamiana '+' na '-'
			mov [napis+bx],'-'				;
			inc bx
			jmp rewersuj
			
			szukaj_dalej_1:
			cmp [napis+bx],'-'
			jne szukaj_dalej_2
			mov [napis+bx],'+'
			inc bx
			jmp rewersuj

			szukaj_dalej_2:
			
			inc bx
			jmp rewersuj			
		koniec_rewers:
	
		pop bx
		ret
	rewers endp
;============================================================================================================================================
	args_na_liczby proc
		push ax
		push bx
		
		mov bx,offset args
		mov ax,1
		call zwroc_dl_argumentu
		
		call string_na_liczbe 
		; parametry:
		; pobiera: bx - offset napisu, ax, dlugosc
		; zwraca: ax - liczbe
		mov [rozdzielnosc],ax

		mov ax,2
		mov bx,offset args
		call zwroc_argument
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow
		add bx,ax
		mov ax,2
		call zwroc_dl_argumentu
		
		call string_na_liczbe 
		; parametry:
		; pobiera: bx - offset napisu, ax, dlugosc
		; zwraca: ax - liczbe
		mov [dlugosc],ax
		
		pop bx
		pop ax
		ret
	args_na_liczby endp
;============================================================================================================================================	
	rysuj_bok proc	
		push di
		
		xor di,di
		badaj:
			cmp [napis+di],SEPARATOR
			je koniec_badaj
			
			cmp [napis+di],'+'
			jne badaj_dalej_1
			rotacja_w_lewo
			inc di
			jmp badaj
			
			badaj_dalej_1:
			cmp [napis+di],'-'
			jne badaj_dalej_2
			rotacja_w_prawo
			inc di
			jmp badaj		
			
			badaj_dalej_2:
			call rysuj_krawedz
			inc di
			jmp badaj
		koniec_badaj:
		
		pop di
		ret
	rysuj_bok endp
;============================================================================================================================================
	rysuj_krawedz proc
		push ax
		push cx
		push dx
	
		mov cx,dlugosc
		rysuj:
			push cx
			
			fld st(COS)						; wrzuca na wierzch stos cosinus
			faddp st(X_POZ+1),st(0)			; dodaje do pozycji cosinusa i popuje
			fld st(X_POZ)					; zapamietuje nowo pozyce
			fistp [x]						; laduje zaokraglana pozycje do x
			
			fld st(SIN)						; analogicznie jak wyzej
			faddp st(Y_POZ+1),st(0)
			fld st(Y_POZ)
			fistp [y]
				
			mov cx,[x]
			mov dx,[y]
			
			cmp cx,[max_x]
			jae nie_rysuj
			cmp dx,[max_y]
			jae nie_rysuj			
			cmp cx,0
			jb nie_rysuj
			cmp dx,0
			jb nie_rysuj						
			mov ah,0Ch
			mov al,[KOLOR]
			int 10h
			
			nie_rysuj:
			pop cx
		loop rysuj

		pop dx
		pop cx
		pop ax
		ret
	rysuj_krawedz endp
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
	string_na_liczbe proc
		; parametry:
		; pobiera: bx - offset napisu, ax, dlugosc
		; zwraca: ax - liczbe
		xor di,di
		mov cx,ax
		xor ax,ax
		
		zamieniaj:
			push cx
			
			mov cl,10						
			mul cl							
			xor cx,cx
			mov cl,[bx+di]
			
			sub cx,'0'
			add ax,cx			
			inc di
			
			pop cx
		loop zamieniaj
		ret
	string_na_liczbe endp
kod1	ends
end start1