;
;  Main.s90 - Main code for the BAV335x PMIC Monitor AT-tiny
;
;  18 May 2015  Gilles  Created
;
.include "target.ah"


; _shift_signature: rotates left the heartbeat signature using the cary for b0
; returns the MSB of the heartbeat signature in r16
;------------------------------------------------------------------------------
_shift_signature:
            lds     r16, heartbeat_signature
            rol     r16
            sts     heartbeat_signature, r16
            lds     r16, heartbeat_signature+1
            rol     r16
            sts     heartbeat_signature+1, r16
            ret




;============================================
;            M A I N    C o d e
;============================================
;
.extern     bios_halt
.global     _main
_main:      ;
            ; Pre-loop initialization (? not much to do here)
            ;
            clr     r25                           ; r25 is our system wide zero register (just being paranoid)
            sts     main_flags, r25
            sts     pulse_time, r25
            ; pre-loop, check if power is off (and auto-power-on option enabled) and generate the power pusle if needed
            ;in      r17, PORT_IN                  ; check to see if power is off and auto-on is enabled
            ;sbrs    r17, BOOTSTRAP_PWR_BIT        ; // PB0 == 1 means no power and auto-on option enabled
            ;rjmp    _qloop                        ; if (there is no power -and- auto-power-on option is enabled)
            ldi     r20, FLAG_INRESET_PULSE + FLAG_INPOWER_PULSE
            ;out     PORT_OUT, r20                 ;   // generate pulse on PMIC power button
            sts     main_flags, r20               ;   // main _qloop will release it when pulse_time reaches the target pulse length

            ; D E B U G    D E B U G     D E B U G
            ldi     r24, 0x04
            out     DDRB, r24
            ;ldi     r24, 0x04
            out     PORTB, r24
            ; D E B U G    D E B U G     D E B U G


            ;
_qloop:     ;**************************************************************************************************
            ;
            ;  M A I N   E V E N T   L O O P   (Dequeues events form the BIOS and processes them accordignly)
            ;
            ;**************************************************************************************************
            rcall   bios_wait_for_event           ; Display BOOT message
            ;
            ;sbrc    r16, EVENT_TIMER_BIT
            rjmp    _ev_timer
            sbrs    r16, EVENT_LINUXHB_BIT
            rjmp    _qloop
            ;
            ;
            ;
_ev_linxhb: ;********************************************************
            ;
            ;  EVENT_LINUX_HEARBEAT  (heartbeat led just turned on)
            ;
            ;********************************************************
            ;
            ; We land here if there is a linux heart beat (rising edge/led on) detected
            ; a normal heartbeat_signature will look like a series of 10 100 10 100 ...
            ;
            lds     r20, main_flags               ; if (we are in the middle of PMIC Power or Reset pulse
            ldi     r16, FLAG_INPOWER_PULSE + FLAG_INRESET_PULSE
            and     r16, r20
            brne    _qloop                        ;   // ignore
            ;
            sbr     r20, FLAG_WAIT_LEDOFF_BIT     ; else
            sts     main_flags, r20               ;   say we're waiting for the heartbeat LED to go off
            sts     qrst_time, r25                ;   and start couting time since raising edge
            rjmp    _qloop
            ;
            ;
            ;
            ;
            ;
            ;
_ev_timer:  ;***************************************************
            ;
            ;  BIOS EVENT TIMER: +10ms exactly since last time
            ;
            ;***************************************************
            ;
            ;
            ;
            ;  Check if we need to release the PMIC Power button pulse
            ;-----------------------------------------------------------
            ;
            lds     r18, pulse_time
            inc     r18
            sts     pulse_time, r18               ; pmic_time++;
            ;
            ;
            ; D E B U G    D E B U G     D E B U G
            ;
            andi    r18, 0x20
            brne    _ledoff
            ;
            ldi     r18, 0x04
            out     PORT_OUT, r18
            rjmp    _qloop

_ledoff:    ;
            clr     r25
            out     PORT_OUT, r25
            rjmp    _qloop
            



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   D a t a   S e g m e n t   S R A M
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
main_flags:             ; Main flags is used for booleans storage
.byte 0
heartbeat_signature:    ; Keeps a signature of the heart beat (to detect if it's present and/or if a timeout has occured)
.word 0
qrst_time:              ; Used to detect time between heart beats
.byte 0
pulse_time:             ; Used to count the length of the PMIC and RESET pulses
.byte 0


.end
