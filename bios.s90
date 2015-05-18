;
; bios.s90  -  Gilles' OS startup code (nano version for AT tiny 32 bytes SRAM)
;
; 23 Avr 1999    Gilles   Creation
; 26 Jul 1999    Gilles   Split from
; 
#include "target.inc"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   D a t a   S e g m e n t   S R A M
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
.global bios_event, bios_timer_ticks
bios_event:
.byte
bios_timer_ticks:
.word



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       C o d e     S e g m e n t     
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.name        bios
.text



; Capture all Interrupt Vectors (comment out the ones we use)
;=============================================================
.global  _isr_int0, _isr_pci0, _isr_t0cap, _isr_t0ovf, _isr_t0ca
.global  _isr_t0cb, _isr_acmp, _isr_wdt, _isr_vlm, _isr_adc



.org  0
_sreset:    ; HERE defined. DO NOT MODIFY OR REDEFINE.
_isr_int0:  ; External int 0
;_isr_pci0: ; Pin Change int 0
_isr_t0cap: ; Timer 0 capture
_isr_t0ovf: ; Timer 0 overflow
;_isr_t0ca: ; Timer 0 compare A
_isr_t0cb:  ; Timer 0 compare B
_isr_acmp:  ; Analog Comparator event
_isr_wdt:   ; Watchdog Timer
_isr_vlm:   ; Voltage Level Monitor
_isr_adc:   ; ADC Conversion done
            reti




;========================================================================================
;     T I M E R    0    I N T E R R U P T
;---------------------------------------------
; We use Timer 0 to produce an event every 10ms and also keep "exact" time.
; Now, with a timer at 8MHz/prescaler:1024, it would take 78.128ticks to 10ms
; So we count 78ticks 7 times and 79 ticks once which produces exactly 10ms every 80ms.
; (same thing with a timer at 1MHz with a prescaler of 128) 
;========================================================================================
.equ    T0OCRA_LOAD0,    78
.equ    T0OCRA_LOAD1,    77

_isr_t0ca:  ; Timer 0 compare A event
            ;
            clr     r25
            push    r24
            ;
            lds     r24, bios_timer_ticks
            inc     r24
            sts     bios_timer_ticks, r24
            andi    r24, 0x07
            breq    _t0_load0
_t0_load1:  ; 7 out of 8 times, we count till 78 (0..77)
            ldi     r24, T0OCRA_LOAD1
            out     OCR0AH, r25 
            out     OCR0AL, r24
            rjmp    _t0_count
            ;
_t0_load0:  ; every 8th compare, we use value 79
            ldi     r16, T0OCRA_LOAD0
            out     OCR0AH, r25
            out     OCR0AL, r24
            ; now, bios_timer_ticks & 0x07 = 0, maybe it rolled over
            lds     r24, bios_timer_ticks
            tst     r24
            brne    _t0_count
_t0_ovf8:   ; bios_timer_ticks == 0, increase high byte
            lds     r24, bios_timer_ticks+1
            inc     r24
            sts     bios_timer_ticks+1, r24
            ;
_t0_count:  ; Every 10ms, we say so to main via the bios_event "semaphore" event;            
            lds     r24, bios_event
            sbr     r24, EVENT_TIMER_BIT
            sts     bios_event, r24
            ;
            pop     r24
            reti





;===================================================
;     P C   I N T E R R U P T   0
;-------------------------------------------
; Used to detect the linux heartbeat LED going on
;===================================================
_isr_pci0:  ; Pin Change int 0
            ;
            push    r24
            ;
            lds     r24, bios_event
            sbr     r24, EVENT_LINUXHB_BIT
            sts     bios_event, r24
            ;
            pop     r24
            reti






;========================================================
;
;  BIOS_HALT     System call:  wait for bios events
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
.global     bios_halt
bios_halt:  ;
            lds     r16, bios_event
            tst     r16
            breq    bios_halt
            ;
            clr     r25              ; paranoid zero
            ;
            cli                      ; Since bios_event is volatile, protect
            lds     r16, bios_event  ; (volatile)
            mov     r25, r16
            dec     r25
            and     r25, r16         ; now r25 has set the LSB event
            com     r25              ; ^ 0xff
            and     r16, r25         ; clear that bit in current events
            sts     bios_event, r16
            mov     r16, r25
            sei
            clr     r25
            ;
            com     r16              ; ^ 0xff (recover single bit event)
            ret



;==================================================================================================
; U B I O S 1     Called by startup before RAM Zero to initialize system hardware to benine values
;==================================================================================================
.global     _ubios1
_ubios1:    ;
            cli                             ; no interrupts until all until everything is ready (ubios4)
            clr     r25
            ;
            ;  Set port direction and stuff. It's ok to hold the BAV in reset until we're running (longer RC)
            ;
            out     PUEB, r25               ; no pull-ups what-so-ever
            ldi     r24, BAV_RESET_MASK
            out     PORTB, r24              ; ok to hold BAV reset held until we're initialized but make sure we don't touch PMIC ON
            ldi     r24, BAV_RESET_MASK|PMIC_BUTTON_MASK
            out     DDRB, r24               ; set bootstraps as inputs and controls as outputs
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
            ;
            out     TCCR0C, r25             ; no force output compares
            out     TCCR0A, r25
            ldi     r24,0x0d                ; 00x01101: default input capture (unused), CTC, Prescaler:1024
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
            sei                             ; all bets are off (intrrupts on)
            ret



.end
