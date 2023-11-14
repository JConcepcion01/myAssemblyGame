.include "constants.inc"
.include "header.inc"

; varibale we'll use later
.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
counter: .res 1
jumping: .res 1
descending: .res 1
walking: .res 1
walking_counter: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
.exportzp player_x, player_y, pad1

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.import read_controller1

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  LDA #$00

  ; read controller
  JSR read_controller1

  ; update tiles *after* DMA transfer
	; and after reading controller state
	JSR update_player
  JSR draw_player

  ; No background scrolling on this game
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  RTI
.endproc

.import reset_handler

.export main

.proc main
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR

  ; load the palettes
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

; For loops to draw the whole background
LoadBackground:
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDX #$00

FirstBGLoop:
  LDA background, x
  STA PPUDATA
  INX
  BNE FirstBGLoop
  LDX #$00

SecondBGLoop:
  LDA background+256, x
  STA PPUDATA
  INX
  BNE SecondBGLoop
  LDX #$00

ThirdBGLoop:
  LDA background+512, x
  STA PPUDATA
  INX
  BNE ThirdBGLoop
  LDX #$00

FourthBGLoop:
  LDA background+768, x
  STA PPUDATA
  INX
  BNE FourthBGLoop
  LDX #$00

LoadAttribute:
  LDA PPUSTATUS
  LDA #$C0
  STA PPUADDR
  LDA #$C0
  STA PPUADDR
  LDX #$00

AttributesLoop:
LDA attributes, x
STA PPUDATA
INX
CPX #$08
BNE AttributesLoop 

; This for loop can be commented to stop drawing the
; sprites on the upper left corner:

;   LDX #$00
; spritesLoop:
;   LDA sprites,X
;   STA $0210,X
;   INX
;   CPX #$D0
;   BNE spritesLoop

  vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
	STA ppuctrl_settings
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc

; These are to draw all the character sprites
; in the upper left corner cuz it was part of one
; of the specs. It aint really necesary for the
; game itself...

sprites:
; character sprites
;   yPos, sprite, attibute, xpos
.byte $00, $05, $00, $00
.byte $00, $06, $00, $08
.byte $08, $07, $00, $00
.byte $08, $08, $00, $08

;walking
.byte $00, $05, $00, $10
.byte $00, $06, $00, $18
.byte $08, $09, $00, $10
.byte $08, $0a, $00, $18

.byte $00, $05, $00, $20
.byte $00, $06, $00, $28
.byte $08, $0b, $00, $20
.byte $08, $0c, $00, $28

.byte $00, $05, $00, $30
.byte $00, $06, $00, $38
.byte $08, $0d, $00, $30
.byte $08, $0e, $00, $38

;jumping
.byte $12, $05, $00, $00
.byte $12, $06, $00, $08
.byte $1a, $19, $00, $00
.byte $1a, $1a, $00, $08

;game over
.byte $12, $15, $00, $10
.byte $12, $16, $00, $18
.byte $1a, $17, $00, $10
.byte $1a, $18, $00, $18

; character sprites (LOOKING LEFT)
;   yPos, sprite, attibute, xpos
.byte $24, $05, $40, $08
.byte $24, $06, $40, $00
.byte $2c, $07, $40, $08
.byte $2c, $08, $40, $00

;walking
.byte $24, $06, $40, $10
.byte $24, $05, $40, $18
.byte $2c, $0a, $40, $10
.byte $2c, $09, $40, $18

.byte $24, $06, $40, $20
.byte $24, $05, $40, $28
.byte $2c, $0c, $40, $20
.byte $2c, $0b, $40, $28

.byte $24, $06, $40, $30
.byte $24, $05, $40, $38
.byte $2c, $0e, $40, $30
.byte $2c, $0d, $40, $38

;jumping
.byte $36, $06, $40, $00
.byte $36, $05, $40, $08
.byte $3e, $1a, $40, $00
.byte $3e, $19, $40, $08

;game over
.byte $36, $16, $40, $10
.byte $36, $15, $40, $18
.byte $3e, $18, $40, $10
.byte $3e, $17, $40, $18



.proc update_player
  PHP  ; Start by saving registers,
  PHA
  TXA
  PHA
  TYA
  PHA

check_if_jumping:
  LDA #$01
  CMP jumping
  BNE check_if_descending
  ; if it doesnt take the BNE it means it's jumping
  ; if it takes it, it means we're done jumping so
  ; we wanna know if we're perhaps descending
  INC counter

  LDA #$23
  CMP counter
  BEQ stop_jump
  ; if it takes the BEQ jump, it means the counter reached the
  ; number I determined should be the max time going up
  ; so we gotta stop ascending and start descending

  ; if it doesnt take that tag jump, it means the counter is still
  ; going so we keep going up
  DEC player_y
  DEC player_y
  
  ; we're done with all the jumpy stuff, let's go check the control inputs
  JMP check_left


check_if_descending:
  LDA #$01
  CMP descending
  BNE check_left
  ; if it doesnt take the BNE it means the
  ; the character is descending

  ; so if we're descending lets move down
  JMP check_down

stop_jump:
  ; make the jumping variable be false
  LDA#$00
  STA jumping

  ; reset the counter
  LDA#$00
  STA counter

  ;make the descending varibale true
  LDA#$01
  STA descending

check_left:
  LDA pad1        ; Load button presses
  AND #BTN_LEFT   ; Filter out all but Left
  BEQ check_right ; If result is zero, left not pressed so let's check the right button

  ;if we're pressing the left button
  ;make the walking variable true
  LDA #$01
  STA walking

  ;this counter will help us with the
  ;sprite animation later
  LDA walking_counter
  CMP #$13
  BCC continue_left
  ;we compare the counter with the hex value $13 (which is 19 in decimal)
  ;if the counter is less than $13 then we may continue with what we must do

  ; if the value is greater than $13 then it wont take that jump and it'll
  ; run the next few lines that will reset that counter back to zero
  LDA #$00
  STA walking_counter

continue_left:

  ;increase the counter
  INC walking_counter

  ;since we're pressing left
  ;make the player's direction be 0
  ;this will be used later for the player drawing
  LDA #$00
  STA player_dir    ; face left

  LDA player_x
  CMP #$00
  BEQ check_right 
  ; if it's at the left edge dont decrease player_x

  ; if the branch is not taken, then we're not in the edge so 
  ; you may move the player left
  DEC player_x  
  DEC player_x 

  ;Lets check if we're above the platform
  LDA player_y
  CMP #$70
  BEQ check_left_corner
  ; if BEQ is taken we're equal to the platform y-level
  ; so we may be on top of it

  JMP check_right

  check_left_corner:
    LDA player_x
    CMP #$6b
    BCS check_right
    ; if BCS is taken we're equal or more than the platform left corner
    ; meaning we're on the platform

    ; if the BCS route is not taken then that means we're not standing
    ; on the platform so make descend be true
    LDA #$01
    STA descending


check_right:
  LDA pad1        ; Load button presses
  AND #BTN_RIGHT  ; Filter out all but right
  BEQ check_up    ; If result is zero, right not pressed so let's check the right button

  ; if the BEQ route to check_up is not taken it means we're pressing right
  ; so let's make walking be true
  LDA #$01
  STA walking

  ;as explained in pressing left, lets increase the counter
  LDA walking_counter
  CMP #$13
  BCC continue_right

  ;if we get here the counter is greater than $13 so let's reset it
  ;SIDENOTE; the $13 value was just pure trial and error for what worked 
  ;best for my stage if your character needs to jump lower then lower the value
  ;and viceversa
  LDA #$00
  STA walking_counter

continue_right:

  ;increase the counter
  INC walking_counter

  ;we're walking right, so make the direction
  ;be equal to 1
  LDA #$01
  STA player_dir    ; face right

  LDA player_x
  CMP #$f0
  BEQ check_up ; if it's at the right edge dont increment player_x

  ;if it didnt reach the $f0 right corner value, then we may keep
  ;walking to theright
  INC player_x
  INC player_x

  ;Lets check if we're above the platform
  LDA player_y
  CMP #$70
  BEQ check_right_corner
  ; if BEQ is taken we're equal to the platform y-level

  JMP check_up

check_right_corner:
  LDA player_x
  CMP #$b0
  BCC check_up
  ; if BCC is taken we're equal or less than the platform right corner
  ; meaning we're on the platform

  ;like with the check_left case, if we didnt take the BCC route, then we're
  ;not on the platform so keep going down till we reach the floor
  LDA #$01
  STA descending

  ;lets check the up button press
  JMP check_up

stop_descend:

  ;if we're inside this tag it means some other place
  ;made a jump here cuz we're at the floor so lets stop
  ;the descend

  ;reset the jump counter
  LDA#$00
  STA counter

  ;we stopped descending so make descending be false
  LDA#$00
  STA descending

check_up:

  LDA pad1             ; Load button presses
  AND #BTN_UP          ; Filter out all but up
  BEQ done_checking    ; If result is zero, up is not pressed so we're done checking buttons

  ;Let's check if we have began to desecend
  LDA #$01
  CMP descending
  BEQ done_checking
  
  ;if not then we dont take the BEQ route and jumping is true
  LDA #$01
  STA jumping

check_down:
  ;we're not checking for down buton press since our game doesnt make use
  ;of the down button, but we'll still make use of the logic for the desecend

  ;check if descend is false
  LDA #$00
  CMP descending
  BEQ done_checking

  ;if it isnt, then we get here to make some other checks

  ;check if we're at ground level
  LDA player_y
  CMP #$a0
  BEQ stop_descend ; if it's at the floor level dont increase player_y anymore

  ;Lets check if we're above the platform
  LDA player_y
  CMP #$70
  BEQ check_xRightPlatform
  ; if BEQ is taken we're equal to the platform y-level

  JMP inc_yCoordinate

  check_xRightPlatform:
    LDA player_x
    CMP #$b0
    BCC check_xLeftPlatform
  ; if BCC is taken we're equal or less than the platform right corner
  JMP inc_yCoordinate

  check_xLeftPlatform:
    LDA player_x
    CMP #$6B
    BCS stop_descend
  ; if BCS is taken we're equal or more than the platform left corner
  ; meaning we're on top of the platform so we wanna stay on top of it until we move from on top of it

  inc_yCoordinate:
    ;if we're here if means we must increase the player's y-coordinate
    ;which will make them go down which means we're descending
    INC player_y
    INC player_y
  
  JMP check_left

done_checking:

 ;This is to get the walking back to 0
 ;if not moving right or left
  LDA pad1
  AND #BTN_RIGHT
  BNE continue_done

  LDA pad1
  AND #BTN_LEFT
  BNE continue_done

  ;if we get here it means we're not pressing left or right so we're not walking
  ;so walking will be false
  LDA #$00
  STA walking
  STA walking_counter

continue_done:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ;is jumping true? if it is draw the character with the jump sprites
  LDA #$00
  CMP jumping
  BNE draw_jumping

  ;if its falling we also want to use the jumping sprite
  LDA #$00
  CMP descending
  BNE draw_jumping

  ;lets check if we're walking, if we are, use the walking sprites
  LDA #$00
  CMP walking
  BNE draw_walking

  ; if we get here it means we're not doing any of the above so we're
  ; just standing, so use the standing sprites and save each one into those
  ; memory addresses.
  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$07
  STA $0209
  LDA #$08
  STA $020d

  ;sprites are now chosen, lets next choose which direction we're facing
  JMP select_direction

draw_jumping:
  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$19
  STA $0209
  LDA #$1a
  STA $020d

  ;sprites are now chosen, lets next choose which direction we're facing
  JMP select_direction

draw_walking:

  ;if the counter is less than $06 use the first walking sprite
  LDA walking_counter
  CMP #$06
  BCC draw_first_walk

  ;if the counter is less than $0b use the second walking sprite
  LDA walking_counter
  CMP #$0b
  BCC draw_second_walk

  ;if the counter is less than $13 use the third walking sprite
  LDA walking_counter
  CMP #$13
  BCC draw_third_walk

  ;The 06-0b-13 are just gaps of time so the sprite can remain the same for long
  ;enough. If the intervals are too small like 01-02-03, then the animation will be
  ;too fast which I personally think looks weird

  draw_first_walk:

  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$09
  STA $0209
  LDA #$0a
  STA $020d

  ;sprites are now chosen, lets next choose which direction we're facing
  JMP select_direction

  draw_second_walk:

  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$0b
  STA $0209
  LDA #$0c
  STA $020d

  ;sprites are now chosen, lets next choose which direction we're facing
  JMP select_direction

  draw_third_walk:

  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$0d
  STA $0209
  LDA #$0e
  STA $020d

  ;sprites are now chosen, lets next choose which direction we're facing
  JMP select_direction

select_direction:
  ; where should the charcter face?
  LDA #$00
  CMP player_dir
  BEQ draw_facing_left

  LDA #$01
  CMP player_dir
  BEQ draw_facing_right


draw_facing_right:
  ; write player tile attributes
  ; use palette 0
  LDA #%00000000
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$07
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  ;we're done drawing the character
  JMP end_draw

draw_facing_left:
  ; write player tile attributes
  ; use palette 0
  LDA #%01000000 ; that '1' flips the sprite horizontally. The last two 0's determine which palette to use
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0204
  LDA player_x
  STA $0207

  ; top right tile (x + 8):
  LDA player_y
  STA $0200
  LDA player_x
  CLC
  ADC #$07
  STA $0203

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  STA $020f

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  CLC
  ADC #$08
  STA $020b

end_draw:

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
; background pallete: 
.byte $0f, $2C, $30, $0C ; $00
.byte $0f, $01, $21, $31 ; $01
.byte $0f, $36, $2A, $18 ; $02
.byte $0f, $10, $20, $31 ; $03

; character pallete:
.byte $0f, $2C, $30, $0C ; $00
.byte $0f, $0f, $0f, $0f ; $01
.byte $0f, $0f, $0f, $0f ; $02
.byte $0f, $0f, $0f, $0f ; $03

background:
	.byte $0b,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$0b,$03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$03
	.byte $03,$03,$03,$0b,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0b
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0f,$0f,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0f
	.byte $03,$03,$03,$03,$03,$03,$0b,$03,$03,$03,$03,$03,$0c,$0d,$0d,$0e
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$03,$03,$0c,$0d
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$0f,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$0c,$0e,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$0c,$0d,$0e,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$0b,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0c,$0e
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$08
	.byte $03,$0f,$0f,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$08,$02
	.byte $0c,$0d,$0d,$0e,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$08,$02,$02
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0f,$0f,$0f,$0f,$0f
	.byte $0f,$03,$03,$0b,$03,$03,$03,$03,$03,$03,$0b,$03,$03,$07,$02,$02
	.byte $03,$03,$03,$03,$0c,$0e,$03,$03,$0b,$03,$0c,$0d,$0d,$0d,$0d,$0d
	.byte $0d,$0e,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$03,$03,$08,$09,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$03,$08,$02,$02,$09,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$07,$02,$02
	.byte $03,$03,$07,$02,$02,$02,$03,$0a,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$0c,$07,$02,$02,$02,$08,$02,$09,$03,$0b,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$0c,$0e,$03,$03,$03,$07,$02,$02
	.byte $0b,$03,$07,$02,$02,$02,$07,$02,$02,$03,$03,$03,$03,$03,$14,$10
	.byte $10,$10,$10,$10,$10,$13,$03,$03,$03,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$03,$07,$02,$02,$02,$07,$02,$02,$03,$03,$03,$03,$03,$15,$11
	.byte $11,$11,$11,$11,$11,$12,$03,$03,$03,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$03,$07,$02,$02,$02,$07,$02,$02,$03,$03,$03,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$0b,$03,$03,$03,$03,$07,$02,$02
	.byte $03,$03,$07,$02,$02,$02,$07,$02,$02,$03,$08,$09,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$08,$09,$07,$02,$02
	.byte $03,$03,$07,$02,$02,$02,$07,$02,$02,$03,$07,$02,$03,$03,$03,$03
	.byte $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$07,$02,$07,$02,$02
	.byte $05,$03,$07,$02,$02,$02,$07,$02,$02,$05,$07,$02,$08,$09,$03,$03
	.byte $05,$03,$03,$03,$03,$03,$03,$03,$05,$05,$03,$07,$02,$07,$02,$02
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06
	.byte $55,$55,$55,$f5,$55,$55,$55,$d5,$55,$57,$55,$d5,$55,$5f,$55,$55
	.byte $5f,$7d,$d5,$fd,$75,$55,$55,$55,$75,$55,$55,$55,$55,$55,$75,$55
	.byte $55,$55,$55,$d1,$f0,$74,$55,$55,$a5,$a5,$a5,$a5,$a5,$a5,$a5,$a5
	.byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a

attributes:
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $55,$55,$55,$55,$55,$55,$55,$55
  .byte $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA
  .byte $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA

.segment "CHR"
.incbin "graphics.chr"

;To Run:
; first open terminal at folder then run these:
;    ca65 src/background.asm
;    ca65 src/controllers.asm
;    ca65 src/reset.asm
;    ca65 src/myGame.asm
;    ld65 src/background.o src/controllers.o src/myGame.o src/reset.o -C nes.cfg -o myGame.nes

; Now open the .nes file on your emulator. Im using Mesen