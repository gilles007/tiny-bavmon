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
.extern     flash_r16
.extern     delay_xx

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
            ;ldi     r20, FLAG_INRESET_PULSE + FLAG_INPOWER_PULSE
            ;out     PORT_OUT, r20                 ;   // generate pulse on PMIC power button
            ;sts     main_flags, r20               ;   // main _qloop will release it when pulse_time reaches the target pulse length
            sts			main_flags, r25




            ;
_qloop:     ;**************************************************************************************************
            ;
            ;  M A I N   E V E N T   L O O P   (Dequeues events form the BIOS and processes them accordignly)
            ;
            ;**************************************************************************************************



            rcall   bios_wait_for_event           ; Display BOOT message
;            sbrc    r16, EVENT_TIMER_BIT
;            rjmp    _ev_timer
            sbrc    r16, EVENT_LED_OFF_BIT
            rjmp    _ev_ledoff
            sbrs    r16, EVENT_LED_ON_BIT
            rjmp    _qloop
            ;
            ;
            ;
_ev_ledon:  ;******************************************************
            ;
            ;  EVENT_LED_ON   (Linux heartbeat led just turned on)
            ;
            ;******************************************************
            ;
sbi     PORT_OUT, OUT_PMICBUTTON_BIT

            rjmp    _qloop
            ;
            ;
            ;
_ev_ledoff: ;********************************************************
            ;
            ;  EVENT_LED_OFF   (Linux heartbeat led just turned off)
            ;
            ;********************************************************
            ;
cbi     PORT_OUT, OUT_PMICBUTTON_BIT

            rjmp    _qloop
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
            ; qrst_timer++;
            ; if (qrst_timer > LINUX_QRS_TIMEOUT) {
            ;   set flag QRST_TIME_OUT
            ;   shift 'LAST_LED_STATE' into signature again // slowly adding up to all '0' or all '1' if LED is stuck
            ;   if (!FLAG_WD_ENABLED)
            ;     continue
            ;   if (signature == 'all 0') || (signature == 'all 1') {
            ;     set FLAG_RESET_ON
            ;     push PMIC button (for 7+ secs)
            ;   }
            ; }
            ; else if (flag QRST_TIME_OUT)
            ;   continue
            ; if (FLAG_LED_IS_ON) && (qrst_time >



            ; qrst_timer++
            ; if (qrst_timer < TIME_OUT_VALUE)
            ;   continue
            ; shift 'last led status' into signature
            ; set flag QRST_TIME_OUT
            ; if (flag WD_ENABLED is NOT set)
            ;   continue
            ; if (signature == all '0') || (signature == all '1')
            ;   // initiate Reset
            ;   set_flag FLAG_INRESET
            ;   push PMIC button
            ;   reset pulse_time (int)





            rjmp    _qloop                        ; }
            



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   D a t a   S e g m e n t   S R A M
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
main_flags:             ; Main flags is used for booleans storage
.byte 0
heartbeat_signature:    ; Keeps a signature of the heart beat (to detect if it's present and/or if a timeout has occured)
.word 0
qrst_timer:              ; Used to detect time between heart beats
.byte 0
pulse_time:             ; Used to count the length of the PMIC and RESET pulses
.byte 0


.end
