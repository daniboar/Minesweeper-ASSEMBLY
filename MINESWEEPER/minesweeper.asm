.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Minesweeper",0
area_width EQU 640
area_height EQU 480
area DD 0
aux DD 0

x0 dd 110 ;coordonata initiala x a chenarului
x1 dd 510 ;coordonata finala x a chenarului
y0 dd 40 ;coordonata initiala y a chenarului
y1 dd 440 ;coordonata finala y a chenarului
verifica dd 0
j dd 0
i dd 0

counter DD 0 ; numara evenimentele de tip timer
counterOK DD 0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_x EQU 110 ; unde incepe chenarul
button_y EQU 40
button_size EQU 400 
patrat_size EQU 45 ; marimea unui patratel
scor DD 11
total EQU 54  ;totalul de patratele verzi

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
	
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
	
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
	
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
	
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
	
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

linie_horizontal macro x, y, len, color
local bucla_line	
	mov eax, y ; eax=y
	mov ebx, area_width
	mul ebx ;eax = y * area_width
	add eax, x ; eax = (y * area_width) + x
	shl eax, 2 ; eax = ((y * area_width) + x) * 4
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_line
endm

linie_vertical macro x, y, len, color
local bucla_line	
	mov eax, y ; eax=y
	mov ebx, area_width
	mul ebx ;eax = y * area_width
	add eax, x ; eax = (y * area_width) + x
	shl eax, 2 ; eax = ((y * area_width) + x) * 4
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, area_width * 4
	loop bucla_line
endm

drawpatrat macro x, y, lungime, latime,color
local bucla_line,b
	mov eax, y ; eax=y
	mov ebx, area_width
	mul ebx ;eax = y * area_width
	add eax, x ; eax = (y * area_width) + x
	shl eax, 2 ; eax = ((y * area_width) + x) * 4
	add eax, area
	mov ecx, latime
	mov ebx, lungime
	shl ebx,2
b: 
	mov esi,ecx
	mov ecx,lungime
bucla_line :
	mov dword ptr[eax],color
	add eax,4
	loop bucla_line
	mov ecx, esi
	add eax, area_width*4
	sub eax, ebx
	loop b
ENDM
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
		
evt_click:
	push ebp
	mov ebx,[ebp+arg2] ; x'ul click-ului
	mov edx,[ebp+arg3] ;y'ul click-ului
	push edx
	push ebx
	
	make_text_macro 'G', area, button_x + button_size/2 - 50, button_y + button_size + 10
	make_text_macro 'O', area, button_x + button_size/2 - 40, button_y + button_size + 10
	make_text_macro 'O', area, button_x + button_size/2 - 30, button_y + button_size + 10
	make_text_macro 'D', area, button_x + button_size/2 - 20, button_y + button_size + 10
	
	make_text_macro 'L', area, button_x + button_size/2  , button_y + button_size + 10
	make_text_macro 'U', area, button_x + button_size/2 + 10, button_y + button_size + 10
	make_text_macro 'C', area, button_x + button_size/2 + 20, button_y + button_size + 10
	make_text_macro 'K', area, button_x + button_size/2 + 30, button_y + button_size + 10

	verificare_bombe_patrat1:
	cmp ebx, 110 ; daca x-ul click-ului e mai mic decat 110 atunci am dat click in afara chenarului (stanga)
	jl wrong
	cmp ebx, 160 ; daca x-ul click-ului e mai mare decat 160 atunci verificam patratul 2 (dreapta)
	jg verificare_bombe_patrat2
	cmp edx, 40  ; daca y-ul click-ului e mai mic decat 40 atunci am dat click in afara chenarului (sus)
	jl wrong
	cmp edx, 90  ; daca y-ul click-ului e mai mare decat 90 atunci verificam patratul 9 (jos)
	jg verificare_bombe_patrat9 
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15
	
	; verificam celelate patratele 
	
	verificare_bombe_patrat2:
	cmp ebx, 170 
	jl verificare_bombe_patrat1
	cmp ebx, 210 
	jg verificare_bombe_patrat3
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat10
	drawpatrat button_x+50, button_y, 50, 50, 000FF00h
	make_text_macro '2', area, button_x +70, button_y + 15
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat3:
	cmp ebx, 211
	jl verificare_bombe_patrat2
	cmp ebx, 260 
	jg verificare_bombe_patrat4
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat11
	drawpatrat button_x+100, button_y, 50, 50, 000FF00h
	make_text_macro '2', area, button_x +120, button_y + 15
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat4:
	cmp ebx, 261 
	jl verificare_bombe_patrat3
	cmp ebx, 310 
	jg verificare_bombe_patrat5
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat12
	drawpatrat button_x+150, button_y, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +170, button_y + 15
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat5:
	cmp ebx, 311 
	jl verificare_bombe_patrat4
	cmp ebx, 360 
	jg verificare_bombe_patrat6
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat13
	drawpatrat button_x+200, button_y, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +220, button_y + 15
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	jmp afisare_litere
	
	verificare_bombe_patrat6:
	cmp ebx, 361 
	jl verificare_bombe_patrat5
	cmp ebx, 410 
	jg verificare_bombe_patrat7
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat14
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	jmp afisare_litere
	
	verificare_bombe_patrat7:
	cmp ebx, 411 
	jl verificare_bombe_patrat6
	cmp ebx, 460 
	jg verificare_bombe_patrat8
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat15
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	jmp afisare_litere
	
	verificare_bombe_patrat8:
	cmp ebx, 461 
	jl verificare_bombe_patrat7
	cmp ebx, 510 
	jg wrong
	cmp edx, 40 
	jl wrong
	cmp edx, 90
	jg verificare_bombe_patrat16
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	jmp afisare_litere
	
	verificare_bombe_patrat9:
	cmp ebx, 110 
	jl wrong
	cmp ebx, 160 
	jg verificare_bombe_patrat10
	cmp edx, 91 
	jl verificare_bombe_patrat1
	cmp edx, 140
	jg verificare_bombe_patrat17
	drawpatrat button_x, button_y+50, 50, 50, 000FF00h
	make_text_macro '2', area, button_x +20, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat10:
	cmp ebx, 161 
	jl wrong
	cmp ebx, 210 
	jg verificare_bombe_patrat11
	cmp edx, 91 
	jl verificare_bombe_patrat2
	cmp edx, 140
	jg verificare_bombe_patrat18
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15

	verificare_bombe_patrat11:
	cmp ebx, 211 
	jl verificare_bombe_patrat10
	cmp ebx, 260 
	jg verificare_bombe_patrat12
	cmp edx, 91 
	jl verificare_bombe_patrat3
	cmp edx, 140
	jg verificare_bombe_patrat19
	drawpatrat button_x+100, button_y+50, 50, 50, 000FF00h
	make_text_macro '2', area, button_x +120, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat12:
	cmp ebx, 261 
	jl verificare_bombe_patrat11
	cmp ebx, 310 
	jg verificare_bombe_patrat13
	cmp edx, 91 
	jl verificare_bombe_patrat4
	cmp edx, 140
	jg verificare_bombe_patrat20
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15
	
	
	verificare_bombe_patrat13:
	cmp ebx, 311 
	jl verificare_bombe_patrat12
	cmp ebx, 360 
	jg verificare_bombe_patrat14
	cmp edx, 91 
	jl verificare_bombe_patrat5
	cmp edx, 140
	jg verificare_bombe_patrat21
	drawpatrat button_x+200, button_y+50, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +220, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat14:
	cmp ebx, 361 
	jl verificare_bombe_patrat13
	cmp ebx, 410 
	jg verificare_bombe_patrat15
	cmp edx, 91 
	jl verificare_bombe_patrat6
	cmp edx, 140
	jg verificare_bombe_patrat22
	drawpatrat button_x+250, button_y+50, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +270, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat15:
	cmp ebx, 411 
	jl verificare_bombe_patrat14
	cmp ebx, 460 
	jg verificare_bombe_patrat16
	cmp edx, 91 
	jl verificare_bombe_patrat7
	cmp edx, 140
	jg verificare_bombe_patrat23
	drawpatrat button_x+300, button_y+50, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +320, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat16:
	cmp ebx, 461 
	jl verificare_bombe_patrat15
	cmp ebx, 510 
	jg wrong
	cmp edx, 91 
	jl verificare_bombe_patrat8
	cmp edx, 140
	jg verificare_bombe_patrat24
	drawpatrat button_x+350, button_y+50, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +370, button_y + 65
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat17:
	cmp ebx, 110 
	jl wrong
	cmp ebx, 160 
	jg verificare_bombe_patrat18
	cmp edx, 141 
	jl verificare_bombe_patrat9
	cmp edx, 190
	jg verificare_bombe_patrat25
	drawpatrat button_x, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +20, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat18:
	cmp ebx, 161 
	jl verificare_bombe_patrat17
	cmp ebx, 210 
	jg verificare_bombe_patrat19
	cmp edx, 141 
	jl verificare_bombe_patrat10
	cmp edx, 190
	jg verificare_bombe_patrat26
	drawpatrat button_x+50, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +70, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat19:
	cmp ebx, 211 
	jl verificare_bombe_patrat18
	cmp ebx, 260
	jg verificare_bombe_patrat20
	cmp edx, 141 
	jl verificare_bombe_patrat11
	cmp edx, 190
	jg verificare_bombe_patrat27
	drawpatrat button_x+100, button_y+100, 50, 50, 000FF00h
	make_text_macro '2', area, button_x +120, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat20:
	cmp ebx, 261 
	jl verificare_bombe_patrat19
	cmp ebx, 310
	jg verificare_bombe_patrat21
	cmp edx, 141 
	jl verificare_bombe_patrat12
	cmp edx, 190
	jg verificare_bombe_patrat28
	drawpatrat button_x+150, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +170, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat21:
	cmp ebx, 311 
	jl verificare_bombe_patrat20
	cmp ebx, 360
	jg verificare_bombe_patrat22
	cmp edx, 141 
	jl verificare_bombe_patrat13
	cmp edx, 190
	jg verificare_bombe_patrat29
	drawpatrat button_x+200, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +220, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat22:
	cmp ebx, 361 
	jl verificare_bombe_patrat21
	cmp ebx, 410
	jg verificare_bombe_patrat23
	cmp edx, 141 
	jl verificare_bombe_patrat14
	cmp edx, 190
	jg verificare_bombe_patrat30
	drawpatrat button_x+250, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +270, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat23:
	cmp ebx, 411 
	jl verificare_bombe_patrat22
	cmp ebx, 460 
	jg verificare_bombe_patrat24
	cmp edx, 141 
	jl verificare_bombe_patrat15
	cmp edx, 190
	jg verificare_bombe_patrat31
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15

	
	verificare_bombe_patrat24:
	cmp ebx, 461 
	jl verificare_bombe_patrat23
	cmp ebx, 510
	jg wrong
	cmp edx, 141 
	jl verificare_bombe_patrat16
	cmp edx, 190
	jg verificare_bombe_patrat32
	drawpatrat button_x+350, button_y+100, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +370, button_y + 115
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat25:
	cmp ebx, 110 
	jl wrong
	cmp ebx, 160
	jg verificare_bombe_patrat26
	cmp edx, 191 
	jl verificare_bombe_patrat17
	cmp edx, 240
	jg verificare_bombe_patrat33
	drawpatrat button_x, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 50, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 100, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +20, button_y + 215
	make_text_macro '1', area, button_x + 120, button_y + 165
	jmp afisare_litere
	
	verificare_bombe_patrat26:
	cmp ebx, 161 
	jl verificare_bombe_patrat25
	cmp ebx, 210
	jg verificare_bombe_patrat27
	cmp edx, 191 
	jl verificare_bombe_patrat18
	cmp edx, 240
	jg verificare_bombe_patrat34
	drawpatrat button_x, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 50, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 100, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +20, button_y + 215
	make_text_macro '1', area, button_x + 120, button_y + 165
	jmp afisare_litere
	
	verificare_bombe_patrat27:
	cmp ebx, 211 
	jl verificare_bombe_patrat26
	cmp ebx, 260
	jg verificare_bombe_patrat28
	cmp edx, 191 
	jl verificare_bombe_patrat19
	cmp edx, 240
	jg verificare_bombe_patrat35
	drawpatrat button_x, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 50, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 100, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +20, button_y + 215
	make_text_macro '1', area, button_x + 120, button_y + 165
	jmp afisare_litere
	
	verificare_bombe_patrat28:
	cmp ebx, 261 
	jl verificare_bombe_patrat27
	cmp ebx, 310
	jg verificare_bombe_patrat29
	cmp edx, 191 
	jl verificare_bombe_patrat20
	cmp edx, 240
	jg verificare_bombe_patrat36
	drawpatrat button_x + 150, button_y+150, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 170, button_y + 165
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat29:
	cmp ebx, 311 
	jl verificare_bombe_patrat28
	cmp ebx, 360
	jg verificare_bombe_patrat30
	cmp edx, 191 
	jl verificare_bombe_patrat21
	cmp edx, 240
	jg verificare_bombe_patrat37
	drawpatrat button_x + 200, button_y+150, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 220, button_y + 165
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat30:
	cmp ebx, 361 
	jl verificare_bombe_patrat29
	cmp ebx, 410
	jg verificare_bombe_patrat31
	cmp edx, 191 
	jl verificare_bombe_patrat22
	cmp edx, 240
	jg verificare_bombe_patrat38
	drawpatrat button_x + 250, button_y+150, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 270, button_y + 165
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat31:
	cmp ebx, 411
	jl verificare_bombe_patrat30
	cmp ebx, 460
	jg verificare_bombe_patrat32
	cmp edx, 191 
	jl verificare_bombe_patrat23
	cmp edx, 240
	jg verificare_bombe_patrat39
	drawpatrat button_x + 300, button_y+150, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 320, button_y + 165
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat32:
	cmp ebx, 461
	jl verificare_bombe_patrat31
	cmp ebx, 510
	jg wrong
	cmp edx, 191 
	jl verificare_bombe_patrat24
	cmp edx, 240
	jg verificare_bombe_patrat40
	drawpatrat button_x + 350, button_y+150, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 370, button_y + 165
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat33:
	cmp ebx, 110
	jl wrong
	cmp ebx, 160
	jg verificare_bombe_patrat34
	cmp edx, 241 
	jl verificare_bombe_patrat25
	cmp edx, 290
	jg verificare_bombe_patrat41
	drawpatrat button_x , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 20, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat34:
	cmp ebx, 161
	jl verificare_bombe_patrat33
	cmp ebx, 210
	jg verificare_bombe_patrat35
	cmp edx, 241 
	jl verificare_bombe_patrat26
	cmp edx, 290
	jg verificare_bombe_patrat42
	drawpatrat button_x + 50 , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 70, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat35:
	cmp ebx, 211
	jl verificare_bombe_patrat34
	cmp ebx, 260
	jg verificare_bombe_patrat36
	cmp edx, 241 
	jl verificare_bombe_patrat27
	cmp edx, 290
	jg verificare_bombe_patrat43
	drawpatrat button_x + 100 , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat36:
	cmp ebx, 261
	jl verificare_bombe_patrat35
	cmp ebx, 310
	jg verificare_bombe_patrat37
	cmp edx, 241 
	jl verificare_bombe_patrat28
	cmp edx, 290
	jg verificare_bombe_patrat44
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15

	
	verificare_bombe_patrat37:
	cmp ebx, 311
	jl verificare_bombe_patrat36
	cmp ebx, 360
	jg verificare_bombe_patrat38
	cmp edx, 241 
	jl verificare_bombe_patrat29
	cmp edx, 290
	jg verificare_bombe_patrat45
	drawpatrat button_x + 200 , button_y+200, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 220, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat38:
	cmp ebx, 361
	jl verificare_bombe_patrat37
	cmp ebx, 410
	jg verificare_bombe_patrat39
	cmp edx, 241 
	jl verificare_bombe_patrat30
	cmp edx, 290
	jg verificare_bombe_patrat46
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15

	
	verificare_bombe_patrat39:
	cmp ebx, 411
	jl verificare_bombe_patrat38
	cmp ebx, 460
	jg verificare_bombe_patrat40
	cmp edx, 241 
	jl verificare_bombe_patrat31
	cmp edx, 290
	jg verificare_bombe_patrat47
	drawpatrat button_x + 300 , button_y+200, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 320, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat40:
	cmp ebx, 461
	jl verificare_bombe_patrat39
	cmp ebx, 510
	jg wrong
	cmp edx, 241 
	jl verificare_bombe_patrat32
	cmp edx, 290
	jg verificare_bombe_patrat48
	drawpatrat button_x + 350 , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 370, button_y + 215
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat41:
	cmp ebx, 110
	jl wrong
	cmp ebx, 160
	jg verificare_bombe_patrat41
	cmp edx, 291 
	jl verificare_bombe_patrat33
	cmp edx, 340
	jg verificare_bombe_patrat49
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15

	
	verificare_bombe_patrat42:
	cmp ebx, 161
	jl verificare_bombe_patrat41
	cmp ebx, 210
	jg verificare_bombe_patrat43
	cmp edx, 291 
	jl verificare_bombe_patrat34
	cmp edx, 340
	jg verificare_bombe_patrat50
	drawpatrat button_x + 50 , button_y+250, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 70, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat43:
	cmp ebx, 211
	jl verificare_bombe_patrat42
	cmp ebx, 260
	jg verificare_bombe_patrat44
	cmp edx, 291 
	jl verificare_bombe_patrat35
	cmp edx, 340
	jg verificare_bombe_patrat51
	drawpatrat button_x + 100 , button_y+250, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat44:
	cmp ebx, 261
	jl verificare_bombe_patrat43
	cmp ebx, 310
	jg verificare_bombe_patrat45
	cmp edx, 291 
	jl verificare_bombe_patrat36
	cmp edx, 340
	jg verificare_bombe_patrat52
	drawpatrat button_x + 150 , button_y+250, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 170, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat45:
	cmp ebx, 311
	jl verificare_bombe_patrat44
	cmp ebx, 360
	jg verificare_bombe_patrat46
	cmp edx, 291 
	jl verificare_bombe_patrat37
	cmp edx, 340
	jg verificare_bombe_patrat53
	drawpatrat button_x + 200 , button_y+250, 50, 50, 000FF00h
	make_text_macro '3', area, button_x + 220, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat46:
	cmp ebx, 361
	jl verificare_bombe_patrat45
	cmp ebx, 410
	jg verificare_bombe_patrat47
	cmp edx, 291 
	jl verificare_bombe_patrat38
	cmp edx, 340
	jg verificare_bombe_patrat54
	drawpatrat button_x + 250 , button_y+250, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 270, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat47:
	cmp ebx, 411
	jl verificare_bombe_patrat46
	cmp ebx, 460
	jg verificare_bombe_patrat48
	cmp edx, 291 
	jl verificare_bombe_patrat39
	cmp edx, 340
	jg verificare_bombe_patrat55
	drawpatrat button_x + 300 , button_y+250, 50, 50, 000FF00h
	make_text_macro '3', area, button_x + 320, button_y + 265
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat48:
	cmp ebx, 461
	jl verificare_bombe_patrat47
	cmp ebx, 510
	jg wrong
	cmp edx, 291 
	jl verificare_bombe_patrat40
	cmp edx, 340
	jg verificare_bombe_patrat50
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15
	
	verificare_bombe_patrat49:
	cmp ebx, 110
	jl wrong
	cmp ebx, 160
	jg verificare_bombe_patrat50
	cmp edx, 341 
	jl verificare_bombe_patrat41
	cmp edx, 390
	jg verificare_bombe_patrat57
	drawpatrat button_x  , button_y + 300, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 20, button_y + 315
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat50:
	cmp ebx, 161
	jl verificare_bombe_patrat49
	cmp ebx, 210
	jg verificare_bombe_patrat51
	cmp edx, 341 
	jl verificare_bombe_patrat42
	cmp edx, 390
	jg verificare_bombe_patrat58
	drawpatrat button_x + 50 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 70, button_y + 315
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat51:
	cmp ebx, 211
	jl verificare_bombe_patrat50
	cmp ebx, 260
	jg verificare_bombe_patrat52
	cmp edx, 341 
	jl verificare_bombe_patrat43
	cmp edx, 390
	jg verificare_bombe_patrat59
	drawpatrat button_x + 100 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 315
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat52:
	cmp ebx, 261
	jl verificare_bombe_patrat51
	cmp ebx, 310
	jg verificare_bombe_patrat53
	cmp edx, 341 
	jl verificare_bombe_patrat44
	cmp edx, 390
	jg verificare_bombe_patrat60
	drawpatrat button_x + 150 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 200 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 150 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 315
	make_text_macro '1', area, button_x + 220, button_y + 315
	make_text_macro '1', area, button_x + 120, button_y + 365
	inc scor
	inc scor
	inc scor
	inc scor
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat53:
	cmp ebx, 311
	jl verificare_bombe_patrat52
	cmp ebx, 360
	jg verificare_bombe_patrat54
	cmp edx, 341 
	jl verificare_bombe_patrat45
	cmp edx, 390
	jg verificare_bombe_patrat61
	drawpatrat button_x + 150 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 200 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 150 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 315
	make_text_macro '1', area, button_x + 220, button_y + 315
	make_text_macro '1', area, button_x + 120, button_y + 365
	inc scor
	inc scor
	inc scor
	inc scor
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat54:
	cmp ebx, 361
	jl verificare_bombe_patrat53
	cmp ebx, 410
	jg verificare_bombe_patrat55
	cmp edx, 341 
	jl verificare_bombe_patrat46
	cmp edx, 390
	jg verificare_bombe_patrat62
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15
	
	verificare_bombe_patrat55:
	cmp ebx, 411
	jl verificare_bombe_patrat54
	cmp ebx, 460
	jg verificare_bombe_patrat56
	cmp edx, 341 
	jl verificare_bombe_patrat47
	cmp edx, 390
	jg verificare_bombe_patrat63
	drawpatrat button_x + 300 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '2', area, button_x + 320, button_y + 315
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat56:
	cmp ebx, 461
	jl verificare_bombe_patrat55
	cmp ebx, 510
	jg wrong
	cmp edx, 341 
	jl verificare_bombe_patrat48
	cmp edx, 390
	jg verificare_bombe_patrat64
	drawpatrat button_x + 350 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 370, button_y + 315
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat57:
	cmp ebx, 110
	jl wrong
	cmp ebx, 160
	jg verificare_bombe_patrat58
	cmp edx, 391 
	jl verificare_bombe_patrat49
	cmp edx, 440
	jg wrong
	drawpatrat button_x  , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 20, button_y + 365
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat58:
	cmp ebx, 161
	jl verificare_bombe_patrat57
	cmp ebx, 210
	jg verificare_bombe_patrat59
	cmp edx, 391 
	jl verificare_bombe_patrat50
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 50  , button_y + 350, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 365
	drawpatrat button_x + 250, button_y+300, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 315
	drawpatrat button_x + 350, button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 370, button_y + 265
	drawpatrat button_x , button_y+250, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 265
	drawpatrat button_x + 250 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 270, button_y + 215
	drawpatrat button_x + 150 , button_y+200, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 215
	drawpatrat button_x+300, button_y+100, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 320, button_y + 115
	drawpatrat button_x+150, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 170, button_y + 65
	drawpatrat button_x+50, button_y+50, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 70, button_y + 65
	drawpatrat button_x, button_y, 50, 50, 0FF0000h
	make_text_macro 'Y', area, button_x + 20, button_y + 15
	
	verificare_bombe_patrat59:
	cmp ebx, 211
	jl verificare_bombe_patrat58
	cmp ebx, 260
	jg verificare_bombe_patrat60
	cmp edx, 391 
	jl verificare_bombe_patrat51
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 150 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 200 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 150 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 315
	make_text_macro '1', area, button_x + 220, button_y + 315
	make_text_macro '1', area, button_x + 120, button_y + 365
	inc scor
	inc scor
	inc scor
	inc scor
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat60:
	cmp ebx, 261
	jl verificare_bombe_patrat59
	cmp ebx, 310
	jg verificare_bombe_patrat61
	cmp edx, 391 
	jl verificare_bombe_patrat52
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 150 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 200 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 300, 50, 50, 000FF00h
	drawpatrat button_x + 100 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 150 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 120, button_y + 315
	make_text_macro '1', area, button_x + 220, button_y + 315
	make_text_macro '1', area, button_x + 120, button_y + 365
	inc scor
	inc scor
	inc scor
	inc scor
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat61:
	cmp ebx, 311
	jl verificare_bombe_patrat60
	cmp ebx, 360
	jg verificare_bombe_patrat62
	cmp edx, 391 
	jl verificare_bombe_patrat53
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 200 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 220, button_y + 365
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat62:
	cmp ebx, 361
	jl verificare_bombe_patrat61
	cmp ebx, 410
	jg verificare_bombe_patrat63
	cmp edx, 391 
	jl verificare_bombe_patrat54
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 250 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 270, button_y + 365
	inc scor
	jmp afisare_litere
	
	verificare_bombe_patrat63:
	cmp ebx, 411
	jl verificare_bombe_patrat62
	cmp ebx, 460
	jg verificare_bombe_patrat64
	cmp edx, 391 
	jl verificare_bombe_patrat55
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 300 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 350 , button_y + 350, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 320, button_y + 365
	jmp afisare_litere
	
	verificare_bombe_patrat64:
	cmp ebx, 461
	jl verificare_bombe_patrat63
	cmp ebx, 510
	jg wrong
	cmp edx, 391 
	jl verificare_bombe_patrat56
	cmp edx, 440
	jg wrong
	drawpatrat button_x + 300 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 350 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 350 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 320, button_y + 365
	make_text_macro '1', area, button_x + 370, button_y + 315
	jmp afisare_litere
		
	; mov counterOK, 0
	; jmp afisare_litere
	
	;mai jos e codul care intializeaza fereastra cu pixeli albi	
wrong:
; nu s-a dat click in interiorul chenarului

button_fail:
	make_text_macro 'G', area, button_x + button_size/2 - 50, button_y + button_size + 10
	make_text_macro 'A', area, button_x + button_size/2 - 40, button_y + button_size + 10
	make_text_macro 'M', area, button_x + button_size/2 - 30, button_y + button_size + 10
	make_text_macro 'E', area, button_x + button_size/2 - 20, button_y + button_size + 10
	
	make_text_macro 'O', area, button_x + button_size/2  , button_y + button_size + 10
	make_text_macro 'V', area, button_x + button_size/2 + 10, button_y + button_size + 10
	make_text_macro 'E', area, button_x + button_size/2 + 20, button_y + button_size + 10
	make_text_macro 'R', area, button_x + button_size/2 + 30, button_y + button_size + 10
	
	jmp afisare_litere
	
clear:
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	 
	linie_horizontal button_x, button_y, button_size, 0
	linie_horizontal button_x, button_y + button_size, button_size, 0
	linie_vertical button_x, button_y, button_size, 0
	linie_vertical button_x + button_size, button_y, button_size,0
	
	linie_horizontal button_x, button_y+50, button_size, 0
	linie_horizontal button_x, button_y+100, button_size, 0
	linie_horizontal button_x, button_y+150, button_size, 0
	linie_horizontal button_x, button_y+200, button_size, 0
	linie_horizontal button_x, button_y+250, button_size, 0
	linie_horizontal button_x, button_y+300, button_size, 0
	linie_horizontal button_x, button_y+350, button_size, 0
	linie_horizontal button_x, button_y+400, button_size, 0
	
	linie_vertical button_x+50, button_y, button_size, 0
	linie_vertical button_x+100, button_y, button_size, 0
	linie_vertical button_x+150, button_y, button_size, 0
	linie_vertical button_x+200, button_y, button_size, 0
	linie_vertical button_x+250, button_y, button_size, 0
	linie_vertical button_x+300, button_y, button_size, 0
	linie_vertical button_x+350, button_y, button_size, 0
	linie_vertical button_x+400, button_y, button_size, 0
	
evt_timer:
	inc counter
	cmp counter, 5
	jz sec
	jmp final
sec:
	inc aux
	mov counter, 0
final:

	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, aux
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 210, 0
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 200, 0
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 190, 0
	
	;afisam patratelele de ajutor de la inceputul jocului
	drawpatrat button_x+200, button_y, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +220, button_y + 15
	drawpatrat button_x+250, button_y, 50, 50, 000FF00h
	drawpatrat button_x+300, button_y, 50, 50, 000FF00h
	drawpatrat button_x+350, button_y, 50, 50, 000FF00h
	drawpatrat button_x + 300 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 350 , button_y + 350, 50, 50, 000FF00h
	drawpatrat button_x + 350 , button_y + 300, 50, 50, 000FF00h
	make_text_macro '1', area, button_x + 320, button_y + 365
	make_text_macro '1', area, button_x + 370, button_y + 315
	drawpatrat button_x, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 50, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x + 100, button_y+150, 50, 50, 000FF00h
	drawpatrat button_x , button_y+200, 50, 50, 000FF00h
	make_text_macro '1', area, button_x +20, button_y + 215
	make_text_macro '1', area, button_x + 120, button_y + 165
	
	;scriem un mesaj
	make_text_macro 'M', area, 260, 0
	make_text_macro 'I', area, 270, 0
	make_text_macro 'N', area, 280, 0
	make_text_macro 'E', area, 290, 0
	make_text_macro 'S', area, 300, 0
	make_text_macro 'W', area, 310, 0
	make_text_macro 'E', area, 320, 0
	make_text_macro 'E', area, 330, 0
	make_text_macro 'P', area, 340, 0
	make_text_macro 'E', area, 350, 0
	make_text_macro 'R', area, 360, 0
	
	make_text_macro 'Z', area, 240, 0 ; smiley face
	make_text_macro 'Y', area, 380, 0 ; sad face
	
	make_text_macro 'B', area, 0, 0
	make_text_macro 'O', area, 10, 0
	make_text_macro 'A', area, 20, 0
	make_text_macro 'R', area, 30, 0
	
	make_text_macro 'D', area, 0, 20
	make_text_macro 'A', area, 10, 20
	make_text_macro 'N', area, 20, 20
	make_text_macro 'I', area, 30, 20
	make_text_macro 'E', area, 40, 20
	make_text_macro 'L', area, 50, 20
	
	
	linie_horizontal button_x, button_y, button_size, 0
	linie_horizontal button_x, button_y + button_size, button_size, 0
	linie_vertical button_x, button_y, button_size, 0
	linie_vertical button_x + button_size, button_y, button_size,0
	
	linie_horizontal button_x, button_y+50, button_size, 0
	linie_horizontal button_x, button_y+100, button_size, 0
	linie_horizontal button_x, button_y+150, button_size, 0
	linie_horizontal button_x, button_y+200, button_size, 0
	linie_horizontal button_x, button_y+250, button_size, 0
	linie_horizontal button_x, button_y+300, button_size, 0
	linie_horizontal button_x, button_y+350, button_size, 0
	linie_horizontal button_x, button_y+400, button_size, 0
	
	linie_vertical button_x+50, button_y, button_size, 0
	linie_vertical button_x+100, button_y, button_size, 0
	linie_vertical button_x+150, button_y, button_size, 0
	linie_vertical button_x+200, button_y, button_size, 0
	linie_vertical button_x+250, button_y, button_size, 0
	linie_vertical button_x+300, button_y, button_size, 0
	linie_vertical button_x+350, button_y, button_size, 0
	linie_vertical button_x+400, button_y, button_size, 0
	
	mov esi, scor  
	cmp esi, total ; comparam daca am dat click pe toate patratelele fara bombe
	jne iesi   ; daca scor != total atunci am dat click pe o bomba si am pierdut
	
	make_text_macro 'A', area, 555, 200
	make_text_macro 'I', area, 565, 200
	
	make_text_macro 'C', area, 525, 220
	make_text_macro 'A', area, 535, 220
	make_text_macro 'S', area, 545, 220
	make_text_macro 'T', area, 555, 220
	make_text_macro 'I', area, 565, 220
	make_text_macro 'G', area, 575, 220
	make_text_macro 'A', area, 585, 220
	make_text_macro 'T', area, 595, 220
	
	
iesi:
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp


start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
