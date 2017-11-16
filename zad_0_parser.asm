;===========================================================================================================================================
;	Mateusz Buta 
; 	Parser
;===========================================================================================================================================

dane1   segment
	;STALE
	SEPARATOR 	equ '$'				; znak rozdzielajacy argumenty
	SPACJA		equ 20h				; kod Asci spacji
	TAB			equ 9h				; kod Asci tabulatora

	;ZMIENNNE
	ile_znak_wiersz dw 0			; ilosc znakow wpisanych do wiersza polecen
	ile_arg dw 0					; ilosc wczytanych argumentow
	
	dl_args db 10 dup(?)			; tablica dlugosci argumentow
	args db 40 dup(?),SEPARATOR 	; tablica argumentow rozdzielonych $
	
	;ZMIENNNE DODATKOWE
	ente db 0ah,0dh,'$'				; drukowalny enter
 
dane1   ends
;===========================================================================================================================================      
stos1	segment STACK

	dw	100h dup(?)					;256 x slowo o dowolnej wartosci
	wierzch1	dw ?
	
stos1	ends        
;===========================================================================================================================================
kod1	segment
;===========================================================================================================================================		
	koniec_prog macro					
        mov ax, 4C00h					; funkcja 4C00h przerwania 21h konczaca dzialanie programu
        int 21h							;
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
	call drukowanie
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
    drukowanie proc    
	    push ax
		push dx
	    push cx       
		mov cx,[ile_arg]
		
		cmp cx,0
		je koniec_drukuj

		drukuj_arg:
			mov ax,cx
			call zwroc_argument
			; parametry:
			; ax - pobiera nr argumentu od 1, zwraca przesuniecie w tablicy argumentow	
			mov dx,offset args
			add dx,ax
					
			mov ah,9
			int 21h
			
			mov dx, offset ente
			mov ah,9
			int 21h
		loop drukuj_arg

		koniec_drukuj:
	    pop cx
		pop dx
	    pop ax        
        ret
    drukowanie endp
;===========================================================================================================================================	
kod1	ends
end start1
