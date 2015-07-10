;
; bios.s90  -  Gilles' OS startup code (nano version for AT tiny 32 bytes SRAM)
;
; 23 Avr 1999    Gilles   Creation
; 26 Jul 1999    Gilles   Split from
; 
.include "target.ah"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   D a t a   S e g m e n t   S R A M
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
.global bios_event, bios_timer_ticks
bios_event:
.byte 0
bios_timer_ticks:
.word 0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       C o d e     S e g m e n t     
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.name        bios
.text



; Capture all Interrupt Vectors (comment out the ones we use)
;=============================================================
.global  _isr_int0, _isr_pci0, _isr_t0cap, _isr_t0ov, _isr_t0ca
.global  _isr_t0cb, _isr_acmp, _isr_wdt, _isr_vlm, _isr_adc


_sreset:    ; HERE defined. DO NOT MODIFY OR REDEFINE.
_isr_int0:  ; External int 0
;_isr_pci0: ; Pin Change int 0
_isr_t0cap: ; Timer 0 capture
_isr_t0ov:  ; Timer 0 overflow
;_isr_t0ca: ; Timer 0 compare A
_isr_t0cb:  ; Timer 0 compare B
_isr_acmp:  ; Analog Comparator event
_isr_wdt:   ; Watchdog Timer
_isr_vlm:   ; Voltage Level Monitor
_isr_adc:   ; ADC Conversion done
            reti




.global delay_xx
delay_xx:   ldi     r19, 1
            rjmp    1f
delay_xxx:  ldi     r19, 2
1:          ldi     r18, 0xd0
2:          ldi     r17, 0x80
3:          nop
            dec     r17
            brne    3b
            dec     r18
            brne    2b
            dec     r19
            brne    1b
            ret


; flashes value of r16 on LED in binary starting with MSB (short pulse = 0, long pulse = 1)
.global flash_r16
flash_r16:  cli
            ldi     r17, 8
1:          ;
            push    r17
            ;
            sbi     PORT_OUT, OUT_PMICBUTTON_BIT
            rcall   delay_xx                      ; short pusle if MSB=0
            rol     r16
            brcc    2f
            rcall   delay_xxx                     ; lengthen pulse if MSB=1
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
;            rjmp    3f
            ;
2:          cbi     PORT_OUT, OUT_PMICBUTTON_BIT
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
3:          ;
            cbi     PORT_OUT, OUT_PMICBUTTON_BIT
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            ;
            pop     r17
            sei
            dec     r17
            brne    1b
            ;
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            rcall   delay_xxx
            ret





;========================================================================================
;     T I M E R    0    I N T E R R U P T
;---------------------------------------------
; We use Timer 0 to produce an event every 10ms and also keep "exact" time.
; --> With a ClkIO at 8MHz/prescaler:1024, it would take 78.128 ticks to 10ms
; So we count 78ticks 7 times and 79 ticks once which produces exactly 8*10ms every 80ms.
; (same thing with ClkIO at 1MHz with a prescaler of 128)
;.equ    T0OCRA_LOAD0,    77
;.equ    T0OCRA_LOADN,    78
; --> With a ClkIO at 4MHz/prescaler:256, it would take 156.24 ticks to 10ms
; So we count 156 ticks 3 times and  157 ticks once which produces 4*10ms every 40ms.
.equ    T0OCRA_LOAD0,    156
.equ    T0OCRA_LOADN,    157
;========================================================================================

_isr_t0ca:  ; Timer 0 compare A event
            ;
            push    r24
            in      r24, SREG
            push    r24
            ;
            lds     r24, bios_timer_ticks
            inc     r24
            sts     bios_timer_ticks, r24
            brne    _t0_novf
            ;
            lds     r25, bios_timer_ticks+1
            inc     r25
            sts     bios_timer_ticks+1, r25
_t0_novf:   ;
            clr     r25
            andi    r24, 0x03
            breq    _t0_loadN
            ;
            ; N-1 time out of N, we count LOAD0
            ldi     r24, T0OCRA_LOAD0
            out     OCR0AH, r25 
            out     OCR0AL, r24
            rjmp    _t0_count
            ;
_t0_loadN:  ; every Nth compare, we compensate
            ldi     r24, T0OCRA_LOADN
            out     OCR0AH, r25
            out     OCR0AL, r24
            ;
_t0_count:  ; Send the EVENT_TIMER message every 10ms for main's house-keeping
            ;
            lds     r24, bios_event
            sbr     r24, EVENT_TIMER
 ;           sts     bios_event, r24
            ;
            pop     r24
            out     SREG, r24
            pop     r24
            reti





;===================================================
;     P C   I N T E R R U P T   0
;-------------------------------------------
; Used to detect the linux heartbeat LED going on
;===================================================
_isr_pci0:  ; Pin Change int 0
            push    r24
            in      r24, SREG
            push    r24
            clr     r25
            ;
            lds     r24, bios_event
            sbis    PORT_IN, LINUX_HBLED_BIT      ; if (LED is ON)
            rjmp    _i0_ledoff
            sbr     r24, EVENT_LED_ON             ;   push_event(LED just went ON);
            rjmp    _i0_done
_i0_ledoff: ;                                     ; else
            sbr     r24, EVENT_LED_OFF            ;   push_event(LED just went OFF);
_i0_done:   ;
            sts     bios_event, r24
            ;
            pop     r24
            out     SREG, r24
            pop     r24
            reti






;========================================================
;
;  BIOS_WAIT_FOR_EVENT:    Wait for bios events
;
;  Blocks and returns one of the bios events in r16
;  Note that if there are multiple events waiting
;  halt always returns the LSB event without any
;  fair chance round robin, so event bits must be
;  prioritized. This is why they can be defined by
;  the user.
;
;  returns the LSB event in r16
;  modifies r25 but not really since we only use it
;  with interrupts off and clear it again when done
;  (r25 is the system wide ZERO register)
;
;========================================================
.global     bios_wait_for_event
bios_wait_for_event:
            lds     r16, bios_event
            and     r16, r16
            breq    bios_wait_for_event
            ;
            cli                       ; Since bios_event is volatile, protect
            lds     r16, bios_event   ; (volatile)
            mov     r25, r16
            dec     r25
            and     r25, r16          ; contains all set bits minus the LSB set
            eor     r25, r16          ; now r25 has only the LSB event
            eor     r16, r25          ; remove that bit from r16
            sts     bios_event, r16
            mov     r16, r25
            clr     r25
            sei
            ;
            ret



;==================================================================================================
; U B I O S 1     Called by startup before RAM Zero to initialize system hardware to benine values
;==================================================================================================
.global     _ubios1
_ubios1:    ;
            cli                             ; no interrupts until all until everything is ready (ubios4)
            clr     r25
            ;
            ;  Now is a good time to speed up Clock (so we initialize faster)
            ;
            ldi     r24, CCP_SIGNATURE
            out     CCP, r24
            ldi     r24, 0x01               ; Run at Clk/2 = 4MHz (plenty fast for what we need to do)
            out     CLKPSR, r24
            ;
            ;  Set port direction and stuff. It's ok to hold the BAV in reset until we're running (longer RC)
            ;
            ldi     r24, OUT_BAVRESET
            out     PORTB, r24              ; ok to hold BAV reset held until we're initialized but make sure we don't touch the PMIC switch though
            ldi     r24, OUT_BAVRESET | OUT_PMICBUTTON
            out     DDRB, r24               ; set bootstraps as inputs and controls as outputs
            out     PUEB, r25               ; no pull-ups what-so-ever
            ;
            ret




;===================================================================================================
; U B I O S 4     Called by startup after RAM Zero to initialize more system and run time variables
;===================================================================================================
.global     _ubios4
_ubios4:    ;
            ;  Set timer 0 up for basic bios time functionality
            ;  to Clear on Compare A (CTC), no Output Compare A/B (OC0A/B) pins, Int on CompareA
            ;
            clr     r25                     ; r25 is our zero register 
            out     TCCR0C, r25             ; no force output compares
            out     TCCR0A, r25
            ldi     r24,0x0C                ; 00z01100: default input capture (unused), CTC, ClkIO prescaler: 256
            out     TCCR0B, r24
            ;
            ldi     r24, T0OCRA_LOAD0
            out     OCR0AH, r25
            out     OCR0AL, r24             ; Set output compare A value
            ;
            out     TCNT0H, r25
            out     TCNT0L, r25             ; Reset timer 0 counter
            ;
            ldi     r24, 2
            out     TIMSK0, r24             ; enable interrupt on compare A
            ;
            inc     r25                     ; (r25 = 1)
            out     PCMSK, r25              ; enable PCINT0 as source of PCINT (1~3 disabled)
            out     PCICR, r25              ; enable PCINT interrupt
            ;
            clr     r25
            sts     bios_event, r25
            sei                             ; all bets are off (intrrupts on)
            ret



.end
