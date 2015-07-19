;
;  Main.s90 - Main code for the BAV335x PMIC Monitor AT-tiny
;
;  18 May 2015  Gilles  Created
;
.include "target.ah"

; GENERAL COMMENT NOTES (APPLICABLE TO ALL FILES EXCEPT BIOS)
; - r16 is the generic program wide scrap register
; - r20 is the program wide register for main_flags
; - r25 is the program wide ZERO register (including BIOS)


;----------------------------------------------------------------------------------
; function _shift_signature(r20)
; rotates left the heartbeat_signature shifting the current LED signature in b0
; Inputs:
;   LED state as FLAG_LED_IS_ON provided in r20 (main loop wide register for main_flags)
; Outputs:
;   r20 (program wide main_flags) is updated
;   r16 Contains the MSB of the heartbeat signature on output
;----------------------------------------------------------------------------------
_shift_signature:
            mov     r16, r20
            ror     r16                                       ; move b0 FLAG_LED_IS_ON into cary
            lds     r16, heartbeat_signature
            rol     r16
            sts     heartbeat_signature, r16
            lds     r16, heartbeat_signature+1
            rol     r16
            sts     heartbeat_signature+1, r16
            ret

;----------------------------------------------------------------------------------
; function _set_state(r16)
; changes the state to that specified by r16 and clears proper timing counters
; Inputs:
;   r16 contains the new state that we are entering
;   r20 the current value of main_flags
;----------------------------------------------------------------------------------
_set_state:
            sts     qrst_timer, r25                           ; Reset all timers
            sbrs    r20, STATE_PMIC_ON_BIT                    ; except if coming out of PMIC_ON to not retry right away (give PMIC a chance to settle)
            sts     pulse_timer, r25
            sts     pulse_timer+1, r25
            ;
            cbr     r20, STATE_IN_RESET | STATE_PMIC_ON | FLAG_WD_ENABLED | FLAG_QRST_TIMEOUT
            or      r20, r16                                  ;
            sts     main_flags, r20                           ; set new state in main_flags
            ldi     r16, STATE_IN_RESET | STATE_PMIC_ON
            and     r16, r20                                  ; if (state != IN_RESET) && (state != PMIC_ON)
            brne    _sst_swon
            cbi     PORT_OUT, OUT_PMICBUTTON_BIT              ;   release PMIC_BUTTON // this also allows us to enter opearting mode by setting state to 0
            rjmp    _sst_end
_sst_swon:  ;                                                 ; else
            sbi     PORT_OUT, OUT_PMICBUTTON_BIT              ;   depress the PMIC_BUTTON
_sst_end:   ;
            ret





;============================================
;            M A I N    C o d e
;============================================
;



.global     _main
_main:      ;
            ; Pre-loop initialization (? not much to do here)
            ;
            clr     r25                                   ; __zero_register__
            lds     r20, main_flags
            clr     r16
            rcall   _set_state                            ; set_state 0
            ;
            ;
            ;**************************************************************************************************
            ;
            ;  M A I N   E V E N T   L O O P   (Dequeues events form the BIOS and processes them accordignly)
            ;
_continue:  ;**************************************************************************************************
            ;
            rcall   bios_wait_for_event
            lds     r20, main_flags                       ; always have main_flags handy in r20
            sbrc    r16, EVENT_TIMER_BIT                  ; if (event == EVENT_TIMER)
            rjmp    _ev_timer                             ;   do_timer_10ms_house_keeping_work()
            sbrc    r16, EVENT_LED_OFF_BIT                ; else if (event == LED_IS_OFF)
            rjmp    _ev_ledoff                            ;   handle_LED_OFF_event()
            sbrs    r16, EVENT_LED_ON_BIT                 ; else if (event == LED_IS_ON)
            rjmp    _continue                             ; { ....
            ;
            ;
            ;
_ev_ledon:  ;******************************************************
            ;
            ;  EVENT_LED_ON   (Linux heartbeat led just turned on)
            ;
            ;******************************************************
            ;
            sbr     r20, FLAG_LED_IS_ON
            rjmp    _evled_do
            ;
_ev_ledoff: ;********************************************************
            ;
            ;  EVENT_LED_OFF   (Linux heartbeat led just turned off)
            ;
            ;********************************************************
            ;
            cbr     r20, FLAG_LED_IS_ON
_evled_do:  ;
            cbr     r20, FLAG_QRST_TIMEOUT
            sts     main_flags, r20                       ; save current state of led in main_flags FLAG_LED_IS_ON bit
            rcall   _shift_signature                      ; shift current LED state (FLAG_LED_IS_ON) into signature
            sts     qrst_timer, r25                       ; reset qrst_timer
            ;
            subi    r16, LINUX_VALID_SIGHI
            brne    _continue
            lds     r16, heartbeat_signature
            subi    r16, LINUX_VALID_SIGLO
            brne    _continue                             ; if (signature == LINUX_VALID_SIGNATURE)

            sbr     r20, FLAG_WD_ENABLED                  ;   // SAY WE HAVE OBSERVED A LINUX HEARTBEAT FOR LONG ENOUGH
            sts     main_flags, r20                       ;   // FROM NOW ON, THE WATCHDOG FUNCTIONALITY IS ENABLED
_continue2: rjmp    _continue
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
            ;  START BY MANAGING STATE MACHINES
            lds     r22, pulse_timer
            lds     r23, pulse_timer+1
            subi    r22, -1
            sbci    r23, -1                               ; pulse_timer++;
            sts     pulse_timer, r22
            sts     pulse_timer+1, r23
            ;
            sbrc    r20, STATE_IN_RESET_BIT               ; if (state == IN_RESET)
            rjmp    _st_inrst                             ;   handle_reset_pulse();
            sbrc    r20, STATE_PMIC_ON_BIT                ; else if (state == PMIC_ON) {
            rjmp    _st_inpmic                            ;   handle_pmic();
            cpi     r22, TIME_SETTLE_PMIC_TEST            ; else if (lo(pulse_timer) == TIME_SETTLE_PMIC_TEST) {  // shortly agter power-up, and every 2.55s
            brne    _evt_qrst
            ;
            sbis    PORT_IN, BOOTSTRAP_PWR_BIT
            rjmp    _evt_qrst                             ;   if (BAV board power is off)  // (input is high) {
            ldi     r16, STATE_PMIC_ON                    ;     set_state(PMIC_ON)  // depress PMIC button to force board on
            rcall   _set_state                            ;
            rjmp    _continue                             ;     continue;
            ;                                             ;   }
            ;
            ;
            ;
_st_inpmic: ;                                             ; function handle_pmic()
            cpi     r22, TIME_PMIC_ON                     ; {
            brne    _continue                             ;   if (pulse_timer == TIME_PMIC_ON)
            rjmp    1f                                    ;     _set_state(NORMAL_OPERATION) // normal state after power-on or reset
            ;                                             ; }
            ;
            ;
_st_inrst:  ;                                             ; function handle_reset()
            cpi     r22, TIME_IN_RESET_LO                 ; {
            sbci    r23, TIME_IN_RESET_HI
            brne    _continue                             ;   if (pulse_timer == TIME_IN_RESET)
1:          clr     r16                                   ;     _set_state(NORMAL_OPERATION) // normal state after power-on or reset
            rcall   _set_state
            rjmp    _continue                             ; }
            ;
            ;
            ;
            ;
            ;----------------------------------------------------------------
_evt_qrst:  ;  WHEN NO SPECIAL STATES (PMIC) NEED TO BE HANDLED, CHECK QRST
            ;----------------------------------------------------------------
            ;
            lds     r21, qrst_timer
            inc     r21                                   ; qrst_timer++
            sts     qrst_timer, r21
            ;
            brne    _evt_noto                             ; if (qrst_timer rolled over >2.55s since last LED toggle) {
            sbr     r20, FLAG_QRST_TIMEOUT
            sts     main_flags, r20                       ;   set flag QRST_TIMEOUT
            rcall   _shift_signature                      ;   shift 'LAST_LED_STATE' into signature // slowly adding up to all '0' or all '1' when LED is stuck
            ;
            sbrs    r20, FLAG_WD_ENABLED_BIT              ;   if (flag WD_EMABLED is NOT set)
            rjmp    _continue                             ;     continue;
            ;
            mov     r19, r16
            lds     r18, heartbeat_signature
            subi    r18, 1                                ;   if ( (signature == 0x0000) || (signature == 0xffff)
            sbc     r19, r25
            cpi     r18, -2
            sbci    r19, -1
            brlo    _continue2                            ;   {
            ;                                             ;     // WE HAVE NOT HAD A LINUX HEARTBEAT IN A WHILE: THIS MEANS RESET!
            cbr     r20, FLAG_WD_ENABLED                  ;     Clear WD_ENABLED bit Since we're about to reset, disable
            sts     main_flags, r20
            ldi     r16, STATE_IN_RESET
            rcall   _set_state                            ;     set_state(STATE_IN_RESET);
            ;                                             ;   }
            rjmp    _continue                             ; }
_evt_noto:  ;
            sbrc    r20, FLAG_QRST_TIMEOUT_BIT            ; else if ( flag QRST_TIMEOUT)
            rjmp    _continue                             ;   continue;
            nop
            sbrc    r20, FLAG_LED_IS_ON_BIT               ; if (  (flag LED is OFF)
            rjmp    _continue
            subi    r21, LINUX_QRST_THRESHOLD             ;     && (qrst_timer == LINUX_QST_THRESHOLD) {
            brne    _continue2
            rcall   _shift_signature                      ;   shift a second '0' to signature for long pause between 2 heart beats ('1's)
            sbr     r20, FLAG_QRST_TIMEOUT                ;   set FLAG_QRST_TIMEOUT so we don't do this again...
            sts     main_flags, r20
            ;
            rjmp    _continue






;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   D a t a   S e g m e n t   S R A M
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
main_flags:             ; Main flags is used for booleans storage
.byte 0
heartbeat_signature:    ; Keeps a signature of the heart beat (to detect if it's present and/or if a timeout has occured)
.word 0
qrst_timer:             ; Used to detect time between heart beats
.byte 0
pulse_timer:            ; Used to count the length of the PMIC and RESET pulses
.word 0


.end
