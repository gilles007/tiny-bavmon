#include <avr/io.h>

;##################################################################################################################################
;
;  I M P O R T A N T   N O T E :   A S   P E R   G I G A   D E V I C E S   N A N O   O S   S P E C I F I C A T I O N S
;  AT-Tiny Register r25 is a system wide ZERO register (always set to zero by initialization and by each intterupt (just in case)
;  Additionally! Because the Tiny has limited ROM (and to save space) bios interrupts use registers r24~r25 without saving them
;
;##################################################################################################################################

#ifndef  __SFR_OFFSET
#warning __SFR_OFFSET was not defined, you may not be using the right compiler (though I think the # would fail first)
#define  __SFR_OFFSET    0
#endif




; Events, configuration constants
;==================================
.equ  EVENT_TIMER_BIT,  	4
.equ  EVENT_TIMER_MASK,   (1 << EVENT_TIMER_BIT)

.equ  EVENT_LINUXHB_BIT,  1
.equ  EVENT_LINUXHB_MASK, (1 << EVENT_LINUXHB_BIT)


;************************************************
; Target Hardware Constants for library routines
;************************************************

; PB0: BOOTSTRAP_WD input is used to enable/disable linux heartbeat watchdot
; when tied to ground, this pin will never see any rising edges and WD will be disabled
; when tied to the linux heartbeat LED, this pin will detect the heartbeat and enable WD reset
.equ  BOOTSTRAP_WD_BIT,  0
.equ  BOOTSTRAP_WD_MASK, (1 << BOOTSTRAP_WD_BIT)


; PB1: BOOTSTRAP_ON input used to enable/disable Always ON Appliance mode
; weak pulled up externally to +5V will enable the always on Appliance
; weak pulled down externally will disable the always on Appliance mode
; The theory here is that the BAV335x +3.3V is off by default, when pulled up, this pin will read 1 until the BAV +3.3V goes on, pulling this pin down
; this is how we can detect if the PMIC was disabled by software (pin goes high again, unless externally pulled down to disable the always on mode).
; Basically, if this pin is EVER high, then the appliance mode is enabled (not just a bootstrap option really),
; and we are responsible for turning on the PMIC by generating a pulse in the Power Button Port (here below defined)
.equ  BOOTSTRAP_ON_BIT,  1
.equ  BOOTSTRAP_ON_MASK, (1 << BOOTSTRAP_ON_BIT)


; PB2: output to the mosfet which simulates depressing the PMIC power button (when high)
.equ  PMIC_BUTTON_BIT, 2
.equ  PMIC_BUTTON_MASK, (1 << PMIC_BUTTON_BIT)


; PB3: output to the mosfet which produces the BAV335x system wide reset (when high)
.equ  BAV_RESET_BIT, 3
.equ  BAV_RESET_MASK, (1 << BAV_RESET_BIT)




;*******************************************
; Target Hardware Constants for application
;*******************************************



;***************************************
; Target Application Specific Constants
;***************************************

.equ  SYSEV_U12SEC,	   SYSEV_USER30