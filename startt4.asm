;
;  reset.s90  -  startup code
;
;  23 Avr 1999  Gilles  Creation
;  26 Jul 1999  Gilles  Split from tower series (into lib)
;  02 Jan 2015  Gilles  Modified for AT Tiny 4~10
#include    "target.inc"



;***************************************
;*    Code Segment in internal SRAM    *
;***************************************

.text
.name        startup
;.rseg        scode


;========================
; Interrupt vector table
;========================

.extern  _isr_int0, _isr_pcint0, _isr_t0cap, _isr_t0ovf, _isr_t0cmpa, _isr_t0cmpb
.extern  _isr_ana_comp, _isr_wdt, _isr_vlm, _isr_adc_done

            rjmp    _sreset         ; HERE defined. DO NOT MODIFY OR REDEFINE.
            rjmp    _isr_int0       ; External int 0
            rjmp    _isr_pci0       ; Pin Change int 0
            rjmp    _isr_t0cap      ; Timer 0 capture
            rjmp    _isr_t0ovf      ; Timer 0 overflow
            rjmp    _isr_t0ca       ; Timer 0 compare A
            rjmp    _isr_t0cb       ; Timer 0 compare B
            rjmp    _isr_acmp       ; Analog Comparator event
            rjmp    _isr_wdt        ; Watchdog Timer
            rjmp    _isr_vlm        ; Voltage Level Monitor
            rjmp    _isr_adc        ; ADC Conversion done




;=============================================
;            R E S E T   C o d e
;=============================================
;
.extern      _ubios1                             ; User provided: Hardware Only Initialization (urgent before start)
.extern      _ubios4                             ; User provided: Software Initialization before main is called
.extern      _main                               ; One time user provided hardware initialization

_sreset:    ; First, set stack
            ;
            cli
            clr     r25
            ;
            clr     r31
            ldi     r30, RAMEND
            out     SPL, r30
            out     SPH, r31
            ;
            ; Call user provided hardware initialization
            ;
            rcall   _ubios1
            ;
            ; Zero the internal RAM contents
            ;
            ldi     r30, 0x40
_zloop:     st      z+, r25
            cpi     r30, RAMEND
            brne    _zloop
            ;
            rcall   _ubios4
            rcall   _main
            ;
            ; should not return, but just in case... start all over
            ;
            rjmp    _sreset

            


;**************************************************************************
;
; "div8u" - 8/8 Bit Unsigned Division
;
;  r16 <- (r16 / r17)
;  r18 <- (r16 % r17)
;
;  Changes: r16, r17, r18, r19
;
.global     _div8u

_div8u:     sub     r18, r18                    ; clear remainder and carry
            ldi     r19, 9                      ; init loop counter
d8u_1:	    rol     r16                         ; shift left dividend
            dec     r19                         ; decrement counter
            brne    d8u_2                       ; if done
            ret                                 ;    return
d8u_2:      rol     r18                         ; shift dividend into remainder
            sub     r18, r17                    ; remainder = remainder - divisor
            brcc    d8u_3                       ; if result negative
            add     r18, r17                    ;     restore remainder
            clc                                 ;     clear carry to be shifted into result
            rjmp    d8u_1                       ; else
d8u_3:      sec                                 ;     set carry to be shifted into result
            rjmp    d8u_1



.end