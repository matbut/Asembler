;===========================================================================================================================================
;	Mateusz Buta 
; 	Zadanie 1
; 	Prezentacja funkcji skrótu klucza publicznego w postaci grafiki ASCII
; 	Modyfikacja - negacja bitow
;===========================================================================================================================================

dane1   segment

	;STALE
	DL_1_ARG 	equ 1		; dlugolsc 1 argumentu
	DL_2_ARG 	equ 32		; dlugolsc 2 argumentu
	LICZBA_ARG	equ 2 		; liczba argumentow
	DL_TAB 		equ 16		; liczba argumentow
	START_W 	equ 4		; miejsce startu gonca (wiersz, kolumna)
	START_K 	equ 8		;
	ILE_W 		equ 9		; wymiary planszy (wiersz, kolumna)
	ILE_K 		equ 17		;
	
	;ZMIENNNE
	ile_znak_wiersz dw 0	; ilosc znakow wpisanych do wiersza polecen
	ile_arg dw 0			; ilosc wczytanych argumentow
	
	dl_args db 40 dup(?)	; tablica dlugosci argumentow rozdzielonych $
	args db 40 dup(?) 		; tablica argumentow rozdzielonych $
	tab db 16 dup (?)		; skrot klucza publicznego
	koncowe_polozenie_w dw ?
 	koncowe_polozenie_k dw ?
	
	plansza	db 0C9h,0CDh,0CDh,0CDh,0B9h," RSA 1024 ",0CCh,0CDh,0CDh,0BBh,0Ah,0Dh,
		ILE_W dup(0BAh,ILE_K  dup (0),0BAh,0Ah,0Dh),
		0C8h,ILE_K dup (0CDh),0BCh,0Ah,0Dh,'$'
	; wyswietlana plansza z ramką

	maska db 00000011b,00001100b,00110000b,11000000b						; talica masek do wczytywania par bitow z klucza
	asci db ' ','.','o','+','=','*','B','O','X','@','%','&','#','/'		 	; tablica znakow asci
	komunikat  db "Bledne argumenty $"										; komunikat o bledzie
	  
dane1   ends
;===========================================================================================================================================      
stos1	segment STACK

	dw	100h dup(?)					; 256 x slowo o dowolnej wartosci
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
	znak_na_hex macro
		;zamiana w resjetrze al
		local zamiana		
		push bx
        cmp al,'9'						; czy kod asci znaku miesci się w zakresie kodow asci od 0 do 9
		mov bh,48						; przechowanie że trzeba odjac 48 aby z kodow asci 0..9 otrzymac liczby 0..9
		jbe zamiana						;
			
        cmp al,'f'						; czy kod asci znaku miesci się w zakresie kodow asci od a do f	
		mov bh,87						; przechowanie że trzeba odjac 87 aby z kodow asci cyfr A..F otrzymac liczby 10..15
		jbe zamiana						; 
		
		koniec_prog						; na wypadek bledu
		zamiana:
		sub al,bh						; odjmowanie, zamiana asci na wartosc
		pop bx
	endm
;===========================================================================================================================================	
	wspolzedne_na_polozenie macro
		inc si							; przesuniecie o 1 przez ramke
		inc di							;
		push ax
		mov ax,di						; obsluga indeksu wiersza tablicy - mnozenie przez 21 - liczbę kolumn w wierszu (17+znaczki)
		mov ah,ILE_K+4					; tylko w al znajdują się znaczace bity di bo di < 255
		mul ah							; mnozenie	
		mov di,ax						; przeniesienie do di
		pop ax
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
	call gen_tab
    call gen_ruchy_gonca
	call drukowanie_plansza
	
	koniec_prog
;===========================================================================================================================================	
	pobieranie_wiersza proc
	    push ax
	    push bx	
	    push di
	    push si			
	
	    mov ah,62h                  	; funkcja 62h przerwania 21h, pobranie segmentu PSP do bx, 
		int 21h							; w którym ofset 80H,81H wskazuje znaki wprowadzone w wierszu poleceń	
		mov es,bx						; 
		
		xor ax,ax
		mov al,byte ptr es:[0080h] 		; pobranie liczby znakow ze wskazaniem na pobranie 1 bajtu z adresu					
		mov ile_znak_wiersz,ax			; zapisanie liczby znaków do zmiennej         				
		
		xor di,di						; licznik ile znakow zostalo pobranych
		xor si,si						; licznik ile znakow zostalo wstawianych
		
		pobieraj_znaki:
			cmp di,[ile_znak_wiersz]		; warunek konca petli while, sprawdza czy pobrano wszystkie znaki z wiersza
            jae koniec_wiersza				;
			
			mov al,es:[di+0081h]			; pobranie znaku wprowadzonego w wierszu poleceń do al
			inc di							;
			
		    cmp al,20h                 		; Sprawdzanie czy pobrany znak jest bialym znakiem, [Spacja] 
    	    je pobieraj_znaki      			; jesli tak to pobieranie kolejnego znaku
		    cmp al,09h						; [Tabulacja pozioma]
    	    je pobieraj_znaki               ; 
			
			call pobierz_argument			; brak bialych znakow - znak rozpoczyna argument, funkcja pobranie argumentu
			; parametry:
			; al - pobiera pierwszy znak argumentu,zwaca pierwszy bialy znak
			; di,si liczniki znakow
        jmp pobieraj_znaki				
			
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
			
		    cmp al,20h                 		; Sprawdzanie czy pobrany znak jest bialym znakiem, [Spacja] 
    	    je koniec_argumentu    			; jesli tak to koniec arguemntu
		    cmp al,09h						; [Tabulacja pozioma]
    	    je koniec_argumentu    			; 
	
		jmp pobieraj_znaki_argumentu		
	
		koniec_argumentu:		
		mov [args+si+bx],'$' 			; dopisanie '$' po argumencie
		add si,bx						;
		inc si							; aktualizacja licznika znakow si
		
		push di
		mov di,[ile_arg]				; uzupelnienie tabicy przechowujecej dlugosc argumentow
		shl di,1						; pomnozenie przez 2
		mov [dl_args+di],bl				; dopisanie '$' po wpisanej dlugosci 		
		mov [dl_args+di+1],'$'			;
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
		; bx - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow
		push cx							
		
		mov cx,bx						; cx - licznik ile pozostalo $ do znalezienia w petli loop
		dec cx							;	
		
		xor bx,bx						; bx - licznik znakow w tablicy argumentow
		przeskakuj_argumenty:
			push cx	
			szukaj_$:
				mov cl,[args+bx]				; przegladanie znakow argumentu
				inc bx							;
				cmp cl,'$'						; sprawdzanie czy znak jest $
				je znaleziono_$
			jmp szukaj_$
			znaleziono_$:
			pop cx
		loop przeskakuj_argumenty
	
		pop cx
		ret
	zwroc_argument endp
;===========================================================================================================================================	
	zwroc_dl_argumentu proc
		; parametry:
		; ax - pobiera nr argumentu od 1, zwraca dlugosc	
		push di
		
		dec ax							;
		shl ax,1						; podwojenie, co drugi znak jest $
		mov di,ax						; 

		
		xor ax,ax						; pobranie dlugosci do ax
		mov al,[dl_args+di]				;
		
		pop di
		ret
	zwroc_dl_argumentu endp
;===========================================================================================================================================
	sprawdzanie_arg proc
		push ax 

		mov ax,[ile_arg]				; spr czy ilosc argumentow sie zgadza
		cmp ax,LICZBA_ARG				;	
		je sprawdzaj_dalej				;
		call bledne_argumenty				; drukowanie komunikatu o bledzie
		
		sprawdzaj_dalej:
		call spr_1_arg
		call spr_2_arg

	    pop ax        
		ret
	sprawdzanie_arg endp
;===========================================================================================================================================	
	spr_1_arg proc
		push ax
	
		mov ax,1						; sprawdzanie dlugosci 1  argumentu 
		call zwroc_dl_argumentu			;
		cmp ax,DL_1_ARG					;
		jne zly_1_arg					;
	
		mov al,[args]					; sprawdzanie pierwszego argumentu czy jest 0 lub 1
		cmp al,'0'						;
		je koniec_spr_1_arg				;
		cmp al,'1'						;
		je koniec_spr_1_arg				;
		jmp zly_1_arg					;

		zly_1_arg:						 
		call bledne_argumenty
		
		koniec_spr_1_arg:	
		pop ax
		ret
	spr_1_arg endp
;===========================================================================================================================================
	spr_2_arg proc
		push ax
		push di
	
		mov ax,2						; sprawdzanie dlugosci 2 argumentu 
		call zwroc_dl_argumentu			; 
		cmp ax,DL_2_ARG					;
		jne zly_2_arg					;		
		
		xor di,di                    	; dx bedzie lcznikiem ile znakow sprawdzono
        sprawdz_czy_hex:
            mov al,[args+di+DL_1_ARG+1]     ; pobieranie kolejego znaku 2 argumentu	

			cmp al,'0'						; czy kod asci znaku miesci się w zakresie kodow asci od 0 do 9
			jb zly_2_arg					;
            cmp al,'9'						;
			;mov ah,48						; przechowanie że trzeba odjac 48 aby z kodow asci 0..9 otrzymac liczby 0..9
			jbe dobry_znak					;
			
			cmp al,'a'						; czy kod asci znaku miesci się w zakresie kodow asci od a do f
			jb zly_2_arg					;
            cmp al,'f'						;	
			;mov ah,87						; przechowanie że trzeba odjac 87 aby z kodow asci cyfr A..F otrzymac liczby 10..15
			jbe dobry_znak					;
			
			jmp zly_2_arg					; jesli nie udalo sie wyfiltorowac znaku, to znaczy jest zly 

			dobry_znak:
			;sub al,ah						;
			;mov [args+di+DL_1_ARG+1],al	;
			
			inc di
			cmp di,DL_2_ARG					
            jae koniec_spr_2_arg			
        jmp sprawdz_czy_hex					
		
		zly_2_arg:						
		call bledne_argumenty
		
		koniec_spr_2_arg:
		pop di
		pop ax
		ret
	spr_2_arg endp	
;===========================================================================================================================================
	bledne_argumenty proc
		push dx
		push ax
	
		mov dx,offset komunikat			; drukowanie komunikatu o bledzie 
		mov ah,9h						; 
		int 21h							; 
		koniec_prog
		
		pop ax
		pop dx
	bledne_argumenty endp	
;===========================================================================================================================================
	gen_tab proc
		push si
		push cx
		push ax
		
		xor si,si 						; licznik bajtow nowej tablicy
		xor di,di 						; licznik bajtow starej tablicy
		polocz_2_znaki:
			mov al,[args+di+DL_1_ARG+1] ; pobranie pierwszego bajtu z tablicy argumentow
			inc di						; 
			znak_na_hex					; 
			mov ah,al					;
			
			shl ah, 4					; przesuniecie o 4 bity w lewo (czyli pomnozenie przez 16)
			
			mov al,[args+di+DL_1_ARG+1] ; pobranie drugiego bajtu z tablicy argumentow
			inc di						;
			znak_na_hex					;
			
			or al,ah					; sumowanie dwoch bajtow z tablicy argumentow w jeden bajt
			
			mov [tab+si],al				; zapisanie do nowej tablicy
			inc si						;
			
			cmp di,DL_2_ARG				; warunek konca, poloczenie wszystkich znakow i wygnerowanie tablicy
			je koniec_znaki				
		jmp polocz_2_znaki				
			
		koniec_znaki:
		pop ax
		pop cx
		pop si
		ret
	gen_tab endp
;===========================================================================================================================================
	gen_ruchy_gonca proc
		push bx
		push di
		push si
		
		xor bx,bx						; bx licznik
		mov di,START_W					; wiersz  tablicy od 0 do 8  ( 9 pol) 
		mov si,START_K					; kolumna tablicy od 0 do 16 (17 pol) 
		
		ruchy:
			mov al,[tab+bx]					; pobranie bajtu ze skrotu klucza reprezntujacego 4 ruchy
			
			cmp [args],'1'					; sprawdzanie czy jest modyfikacja
			je modyfikacja					;
			jmp bez_modyfikacji				;
			
			modyfikacja:					; 
			not al							; negacja bitow
			bez_modyfikacji:				;
			
			call goniec_ruch				; i jego wykonanie
			; parametry:
			; al - bajt reprezntujacy 4 ruchy
			; di,si, wspolzedne gonca (wiersz,kolumna)
			
			inc bx								
			cmp bx,DL_TAB					 
			je koniec_gen			
		jmp ruchy	
		
		koniec_gen:
		mov [koncowe_polozenie_w],di	; zapamietanie gdzie wstawic literke E
		mov [koncowe_polozenie_k],si	;
		
		pop si
		pop di
		pop bx
		ret
	gen_ruchy_gonca endp
;===========================================================================================================================================
	goniec_ruch proc
		; parametry:
		; al - bajt reprezntujacy 4 ruchy
		; di,si, wspolzedne gonca (wiersz,kolumna)
        push bx
		push cx		
	
		xor bx,bx						; bx - licznik 4 ruchy w jednym bajcie
		ruch:
			push ax	
			push bx
			mov ah,[maska+bx]				; pobranie odpowiedniej maski
			and al,ah						; pobranie odpowiednich dwóch bitow ruchu
			
			mov cx,bx						; przesuniecie dwóch bitow ruchu w prawo
			shl cx,1						; pomnozenie przez 2
			shr al,cl						;																													
			
		    ruch_gura_dul:
		    test al,10b 					; sprawdzenie kierunku ruchu
		    jz ruch_gora					;
		    jnz ruch_dol					;
			
			ruch_gora:
				cmp di,0						; sprawdzenie czy ruch nie wcyhodzi poza krawedz
				je ruch_lewo_prawo				;
				dec di							;
				jmp ruch_lewo_prawo				;
				
			ruch_dol:
				cmp di,ILE_W-1					; sprawdzenie czy ruch nie wcyhodzi poza krawedz
				je ruch_lewo_prawo				;
				inc di							;
				jmp ruch_lewo_prawo 			;
			
			ruch_lewo_prawo:				
			test al,01b 					; sprawdzenie kierunku ruchu
		    jz ruch_lewo					;
		    jnz ruch_prawo					;
			
			ruch_lewo:			
				cmp si,0						; sprawdzenie czy ruch nie wcyhodzi poza krawedz
				je koniec_ruch					;
				dec si							;
				jmp koniec_ruch					;
			
			ruch_prawo: 				
				cmp si,ILE_K-1					; sprawdzenie czy ruch nie wcyhodzi poza krawedz
				je koniec_ruch					;
				inc si							;
				jmp koniec_ruch					;
					
			koniec_ruch:
			
			call goniec_dodaj_odwiedziny			; zapisanie obecnosci gonca na polu
			; parametry:
			; di,si, wspolzedne gonca (wiersz,kolumna)
			
			pop bx
			pop ax
			inc bx
			cmp bx,4					
			je koniec_4_ruchow				
		jmp ruch				
		
		koniec_4_ruchow:
		pop cx
		pop bx
		ret
	goniec_ruch endp	
;===========================================================================================================================================	
	goniec_dodaj_odwiedziny proc 
		; parametry:
		; di,si, wspolzedne gonca (wiersz,kolumna)
		push ax
		push si
		push di

		wspolzedne_na_polozenie
		add si,di						
		
		mov al,[plansza+si]			; zapisanie obecnosci gonca na polu
		inc al						;
		mov [plansza+si],al			;
		
		pop di
		pop si
		pop ax
		ret
	goniec_dodaj_odwiedziny endp
;===========================================================================================================================================	
	drukowanie_plansza proc
		push dx
		push ax
		
		call plansza_na_asci

	    mov dx,offset plansza			;	                     
        mov	ah,9h						; funkcja 9 Wypisywanie stringu ds:dx (do znaku $) 
	    int	21h           				;	

		pop ax
		pop dx
		ret
	drukowanie_plansza endp
;===========================================================================================================================================
	plansza_na_asci proc
		push bx
		xor di,di
		zamien_na_asci_wiersze:
			xor si,si
			zamien_na_asci_kolumny:
				call zamien_na_asci
				
				inc si
				cmp si,ILE_K						; warunek konca petli, sprawdza czy wydrukowana wszystkie znaki z wiersza
				je koniec_kolumn				
			jmp zamien_na_asci_kolumny
			
			koniec_kolumn:
					
			inc di
			cmp di,ILE_W						; warunek konca petli, sprawdza czy wydrukowana wszystkie znaki z planszy
			je koniec_wierszy				
		jmp zamien_na_asci_wiersze			
			
		koniec_wierszy:	
		pop bx
		ret
	plansza_na_asci endp
;===========================================================================================================================================
	zamien_na_asci proc 
        push bx
		push ax
		push si
		push di
		
		wspolzedne_na_polozenie
		add si,di						;

		xor bx,bx						; pobranie liczby odwiedzin gonca do bx
		mov bl,[plansza+si]				; 
		
		cmp bl,14						; przechwycenie znaku ^ dla 14 lub wiecej odwiedzin
		jae znak_14						;
		jmp znak_z_tablicy				;
		znak_14:						;
		mov [plansza+si],'^'			;
		jmp koniec_zamiany				;
		
		znak_z_tablicy:
		mov al,[asci+bx]				; wstawienie odpowiedniego znaku z tablicy Ascii
		mov [plansza+si],al				;
		
		koniec_zamiany:					; wstawienie S na początek ruchu gonca
		mov di,START_W					;
		mov si,START_K					;
		wspolzedne_na_polozenie			; makro ktore zwraca polozenie w tablicy
		add si,di						;
		mov [plansza+si],'S'			;
		
		mov di,[koncowe_polozenie_w] 	; wstawienie literki E
		mov si,[koncowe_polozenie_k]	;
		wspolzedne_na_polozenie			; makro ktore zwraca polozenie w tablicy
		add si,di						;
		mov [plansza+si],'E'			;
		
		pop di
		pop si
		pop ax
		pop bx
		ret
	zamien_na_asci endp
;===========================================================================================================================================	
kod1	ends
end start1 