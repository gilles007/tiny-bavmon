;
;  Main.s90 - Main code for the BAV335x PMIC Monitor AT-tiny
;
;  18 May 2015  Gilles  Created
;
.include "target.ah"



;============================================
;            M A I N    C o d e
;============================================
;
.extern     bios_halt
.global     main, _main
main:
_main:      ;
            ; Pre-loop initialization (? not much to do here)
            ;
            ;nop
_qloop:     ;            
            rcall   bios_halt                 ; Display BOOT message
            ;
            sbrc    r16, EVENT_TIMER_BIT
            rjmp    _ev_timer10
            sbrs    r16, EVENT_LINUXHB_BIT
            rjmp    _qloop

_ev_linuxhb:;
            ;  We land here if there is a linux heart beat (rising edge/led on) detected
            ;
            rjmp    _qloop
            ;

_ev_timer10:;
            ;  We land here when another bios_bimer 10ms has elapsed
            ;
            
            
            
            
            rjmp    _qloop
            ;
            
            
            



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   D a t a   S e g m e n t   S R A M
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.data
heartbeat_pattern:
.word


.end
