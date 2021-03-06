#make_bin#

; BIN is plain binary format similar to .com format, but not limited to 1 segment;
; All values between # are directives, these values are saved into a separate .binf file.
; Before loading .bin file emulator reads .binf file with the same file name.

; All directives are optional, if you don't need them, delete them.

; set loading address, .bin file will be loaded to this address:
#LOAD_SEGMENT=0500h#
#LOAD_OFFSET=0000h#

; set entry point:
#CS=0500h#	; same as loading segment
#IP=0000h#	; same as loading offset

; set segment registers
#DS=0500h#	; same as loading segment
#ES=0500h#	; same as loading segment

; set stack
#SS=0500h#	; same as loading segment
#SP=FFFEh#	; set to top of loading segment

; set general registers (optional)
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#


;----jumping to code----

	jmp start_01
	db 509 dup(0)
	
	;IVT entry for 80H
	dw t_isr                    ;interupt for clock which raises interupt after every 1 min
	dw 0000
	db 508 dup(0)
	
	nop
	dw 0000
	dw 0000
	dw ad_isr                  ;nmi interupt which contains subroutine for 4 moisture sensors and 1 watr sensors
	dw 0000
	db 1012 dup(0)

	
;declaring variables
time dw 0            ;due to assumption, clock starting at midnight 12
lane_output db 0
lane db 8 dup(0)  
moist_thresh db 0C8h 
water_thresh db 64h     
min db 0
current_device db 0
water_flag db 0
moist_1st_sensor db 0
moist_2nd_sensor db 0
	

	
;--actual program--

start_01: cli  
    
;--initializing DS, ES, SS at start of RAM--
;use 0200h as IVT entry for 80h - address of entry - 60h x 4 = 0180h
	mov ax, 0180h
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0FFFEh 
	
;--initialize 8255(A)--                      ;8255a port a-40
																				
;PORT A output | PORT B input | Port c output    ==================================================

	mov al, 10000010b 
	out 46h, al
	;programming control register    
	
;--initialize 8255(B)--
;PORT A not used so input | PORT B input | PORT C output ==========================================

	mov al, 10010010b
	out 4Eh, al
	;programming control register  

;--initializing 8253-(1) and insert count--
	mov al, 00010110b 	;counter 0 | write LSB  | mode 3 - sq. wave generator (0.5 MHz) | binary
	out 56h, al
	mov al, 01111000b	;counter 1 | write MSB + LSB | mode 4 | binary
	out 56h, al	        
	mov al, 10111000b	;counter 2 | write MSB + LSB| mode 4 | binary
	out 56h, al	     
	
	mov al,05d  ;moving count value = 05d to counter 0 to get 0.5MHz ADC clock
	out 50h,al 
	
	mov al, 0A8h 
	out 52h, al ;first reads in LSB
	mov al, 61h
	out 52h, al ;now reads in MSB      
	;25000 in hex is 61A8h loaded in counter 1 to get 100Hz
	
	mov al, 70h 
	out 54h, al ;first reads in LSB
	mov al, 17h
	out 54h, al ;now reads in MSB      
	;6000 in hex is 1770h loaded in counter 2 to get 1 min
	
;--initializing 8259--
	mov al, 00010011b	;ICW1 | SNGL | edge-triggered | x86 - IC4 - Do - 1 | Ao = 0
	out 58h, al
	mov al, 80h	;ICW2 | vector no. 60h for IR0 | Ao = 1
	out 5Ah, al
	mov al, 00000001b	;ICW4 | uPM = 1 | Ao = 1
	out 5Ah, al
	mov al, 11111110b	;OCW1 | only IR0 is enabled | Ao = 1
	out 5Ah, al	 

	
	sti    ;set interrupt flag
	


 
;--CHECKING THE TIME - WHETHER IT IS 660 min (11 am) OR 1080 min (6 pm) AND IF IT IS 1440 min(24 hours) THEN SET THE CLOCK BACK TO 00--
min_clk:
	mov ax,time
    cmp ax,294h
	je  sys 
	mov ax,time
	cmp ax,438h
	je  sys
	mov ax,time
	cmp ax,5A0h
	jne min_clk
	mov ax,00
	mov time,ax
	jmp min_clk
	
;--THE MAIN PROGRAM THAT TAKES IN INPUT FROM PORT B AND THEN OUTPUTS TO PORT A-- , (PORT C configures the adc) 

sys:   
 MOV AL,00000100b    ;put channel as 100 to select in4 pin  
 mov dl,00001100b     ; 3th bit is for adc -2| 2,1,0 bits are for channel no of that adc
 mov current_device,dl  ;sets which device is currently giving input to adc
    OUT 4CH,AL
   
   ;give ale  
          mov       al,00100100b
		  out       4Ch,al 
		 
   ;give soc  
          mov		al,00110100b
		  out		4Ch,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010100b
		  out       4Ch,al  
  ;make soc 0
		  
		  mov       al,00000100b
		  out       4Ch,al 
		  
		 
		cmp water_flag,1
		je off		    ;comparing if water threhold not match
		
	
	
	;========================================================================================================================================
	
	
	
	Mi12: 
		 mov al,00000011b  ;initializing moisture sensor to give data
		 mov dl,00001011b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 4CH,AL
		 
		 ;give ale  
          mov       al,00100011b
		  out       4Ch,al 
		 
   ;give soc  
          mov		al,00110011b
		  out		4Ch,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010011b
		  out       4Ch,al  
  ;make soc 0
		  
		  mov       al,00000011b
		  out       4Ch,al 
		  
		 
    Mi11:
         mov al,00000010b  ;initializing moisture sensor to give data
		 mov dl,00001010b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 4CH,AL
		 
		 ;give ale  
          mov       al,00100010b
		  out       4Ch,al 
		 
	;give soc  
          mov		al,00110010b
		  out		4Ch,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010010b
		  out       4Ch,al  
	;make soc 0
		  
		  mov       al,00000010b
		  out       4Ch,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne Mi10
	lea di,lane
	mov bl,1
	mov [di+2],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
	
	;========================================================================================================================================
	
	
	
	
	
	
	
	
	
	Mi10:
	       mov al,00000001b  ;initializing moisture sensor to give data
		 mov dl,00001001b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 4CH,AL
		 
		 ;give ale  
          mov       al,00100001b
		  out       4Ch,al 
		 
   ;give soc  
          mov		al,00110001b
		  out		4Ch,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010001b
		  out       4Ch,al  
  ;make soc 0
		  
		  mov       al,00000001b
		  out       4Ch,al 
		  
		 
    Mi9:
         mov al,00000000b  ;initializing moisture sensor to give data
		 mov dl,00001000b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 4CH,AL
		 
		 ;give ale  
          mov       al,00100000b
		  out       4Ch,al 
		 
	;give soc  
          mov		al,00110000b
		  out		4Ch,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010000b
		  out       4Ch,al  
	;make soc 0
		  
		  mov       al,00000000b
		  out       4Ch,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne Mi8
	lea di,lane
	mov bl,1
	mov [di+3],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
	
	
	
	;========================================================================================================================================
	
	
	
	
	
	Mi8:
	       mov al,00000111b  ;initializing moisture sensor to give data
		 mov dl,00000111b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100111b
		  out       44h,al 
		 
   ;give soc  
          mov		al,00110111b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010111b
		  out       44h,al  
  ;make soc 0
		  
		  mov       al,00000111b
		  out       44h,al 
		  
		 
    Mi7:
         mov al,00000110b  ;initializing moisture sensor to give data
		 mov dl,00000110b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100110b
		  out       44h,al 
		 
	;give soc  
          mov		al,00110110b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010110b
		  out       44h,al  
	;make soc 0
		  
		  mov       al,00000110b
		  out       44h,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne Mi6
	lea di,lane
	mov bl,1
	mov [di+4],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
	
	
	
	;========================================================================================================================================
	
	
	
	
	
	Mi6:
	       mov al,00000101b  ;initializing moisture sensor to give data
		 mov dl,00000101b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100101b
		  out       44h,al 
		 
   ;give soc  
          mov		al,00110101b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010101b
		  out       44h,al  
  ;make soc 0
		  
		  mov       al,00000101b
		  out       44h,al 
		  
		 
    Mi5:
         mov al,00000100b       ;initializing moisture sensor to give data
		 mov dl,00000100b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100100b
		  out       44h,al 
		 
	;give soc  
          mov		al,00110100b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010100b
		  out       44h,al  
	;make soc 0
		  
		  mov       al,00000100b
		  out       44h,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne Mi4
	lea di,lane
	mov bl,1
	mov [di+5],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
	
	
	
	
	
	
	;========================================================================================================================================
	
	
	
	
	
	Mi4:
	       mov al,00000011b  ;initializing moisture sensor to give data
		 mov dl,00000011b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100011b
		  out       44h,al 
		 
   ;give soc  
          mov		al,00110011b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010011b
		  out       44h,al  
  ;make soc 0
		  
		  mov       al,00000011b
		  out       44h,al 
		  
		 
    Mi3:
         mov al,00000010b       ;initializing moisture sensor to give data
		 mov dl,00000010b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100010b
		  out       44h,al 
		 
	;give soc  
          mov		al,00110010b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010010b
		  out       44h,al  
	;make soc 0
		  
		  mov       al,00000010b
		  out       44h,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne Mi2
	lea di,lane
	mov bl,1
	mov [di+6],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
	
	
	
	
	
	;========================================================================================================================================
	
	
	
	
	
	Mi2:
	       mov al,00000001b  ;initializing moisture sensor to give data
		 mov dl,00000001b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100001b
		  out       44h,al 
		 
   ;give soc  
          mov		al,00110001b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
  ;make ale 0 
		  mov       al,00010001b
		  out       44h,al  
  ;make soc 0
		  
		  mov       al,00000001b
		  out       44h,al 
		  
		 
    Mi1:
         mov al,00000000b       ;initializing moisture sensor to give data
		 mov dl,00000000b
		 mov current_device,dl  ;sets which device is currently giving input to adc
         OUT 44H,AL
		 
		 ;give ale  
          mov       al,00100000b
		  out       44h,al 
		 
	;give soc  
          mov		al,00110000b
		  out		44h,al 
		  
		  nop
		  nop
		  nop
		  nop
	;make ale 0 
		  mov       al,00010000b
		  out       44h,al  
	;make soc 0
		  
		  mov       al,00000000b
		  out       44h,al 
		  
		 
    mov al,moist_1st_sensor
    mov bl,moist_2nd_sensor
    or al,bl
    cmp al,1
    jne off
	lea di,lane
	mov bl,1
	mov [di+7],bl
	mov al,lane
	out 40h,al
	mov dl,0
	mov moist_1st_sensor,dl
	mov moist_2nd_sensor,dl
    
    	
		  
		  
		  
		  
		  
		  
		  
    off:          
    mov al,0h
    out 40h,al 
	
    jmp min_clk 
    
t_isr:					
	inc time 
	
	mov al, 00100000b	; setting the OCW2 to set non specific EOI
	out 58h, al
	iret 
	
ad_isr:
   mov al,current_device         ;(get channel value)
   cmp al,00001100b    ;(compare if this is the water channel, inp4)
   jne M12           ;(if not water channel check another channel)
   in al,4Ah
   cmp al,water_thresh
   jl no_water_exit
   jmp exit_isr
   
   
   
   
   no_water_exit: mov cl,1
                  mov water_flag,cl
				  iret
				  
				  
	M12: cmp al,00001011b
         jne M11
		 in al,4Ah
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M11:cmp al,00001010b
        jne M10
        in al,4Ah
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr
		
		
		
	M10: cmp al,00001001b
         jne M9
		 in al,4Ah
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M9:cmp al,00001000b
        jne M8
        in al,4Ah
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr
		
	
    M8: cmp al,00000111b
         jne M7
		 in al,42h
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M7:cmp al,00000110b
        jne M6
        in al,42h
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr	
		
	


    M6: cmp al,00000101b
         jne M5
		 in al,42h
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M5:cmp al,00000100b
        jne M4
        in al,42h
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr		
		
		
	M4: cmp al,00000011b
         jne M3
		 in al,42h
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M3:cmp al,00000010b
        jne M2
        in al,42h
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr	

 
    M2: cmp al,00000001b
         jne M1
		 in al,42h
		 cmp al,moist_thresh
		 jl set_flag_1
		 jmp exit_isr
		 
	M1: in al,42h
		cmp al,moist_thresh
		jl set_flag_2
		jmp exit_isr	 
		
		
		
       
	   
	set_flag_1:
	mov bl,1
	mov moist_1st_sensor,bl
	iret
	
	set_flag_2:
	mov bl,1
	mov moist_2nd_sensor,bl
	iret
	
	
	
	exit_isr:
	iret
	
HLT           ; halt!	