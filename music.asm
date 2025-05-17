; NASM assembly for DOS playing an enhanced Flappy Bird tune
; with a centered text mode UI inside an arcade-style border.
; Background is changed to cyan (entire inner area and text background).
; Exit message changed to "Press ESC to Start Loading Your Game".
; To assemble and run (e.g., in DOSBox):
; nasm arcade_flappy_tune_ui_arcade_cyan_textbg.asm -f bin -o haribird.com
; haribird.com

use16
org 0x100

start:
    ; Initialize music state
    mov word [current_music_note_ptr], music_flappy_theme
    mov word [current_note_duration_counter], 0
    mov byte [is_music_playing_note], 0
    mov word [game_timer], 0

    ; Clear screen and set text mode
    mov ax, 0x0003  ; 80x25 text mode
    int 0x10
    mov ax, 0xb800
    mov es, ax      ; Set ES to video memory segment
    xor di, di      ; Start at top-left (0,0)
    mov cx, 2000    ; Total character cells (80*25)
    ; Use black on black attribute with space char for clear (0x00 = black on black, 0x20 = space)
    mov ax, 0x0020
    rep stosw       ; Fill screen with black spaces

    ; --- Draw Arcade Border ---
    ; Uses double line characters: ╔═╗, ║, ╚═╝
    ; Attribute for border: e.g., Light Green on Black (0x0A)
    mov ah, 0x0A ; Light Green on Black attribute

    ; Draw top border (Row 0)
    mov di, 0
    mov al, [border_chars]  ; ╔
    stosw
    mov cx, 78
    mov al, [border_chars+1]; ═
    rep stosw
    mov al, [border_chars+2]; ╗
    stosw

    ; Draw side borders (rows 1 to 23)
    mov cx, 23              ; Number of rows for sides (25 total rows - top row 0 - bottom row 24 = 23)
    mov di, 80 * 2          ; Start at Row 1, Col 0 (80 columns * 2 bytes/cell)
.side_border_loop:
    push cx                 ; Save outer loop counter
    mov bx, di              ; Save start of current row DI to BX

    ; Draw left side character '║' (Col 0)
    mov al, [border_chars+3]; ║
    mov ah, 0x0A            ; Attribute Light Green on Black
    stosw

    ; Skip to the last column for the right side (Col 79)
    add di, (79 - 1) * 2    ; Move DI from Col 0 to Col 79 (79 columns * 2 bytes/cell) - 1 column already written on the left
    mov al, [border_chars+3]; ║
    mov ah, 0x0A            ; Attribute Light Green on Black
    stosw

    ; Move DI to the start of the next row's side border position (Col 0)
    mov di, bx              ; Restore BX (start of current row) to DI
    add di, 80 * 2          ; Add 80 columns * 2 bytes/cell to move to the start of the next row (Col 0)

    pop cx                  ; Restore outer loop counter
    loop .side_border_loop  ; Repeat for next row

    ; Draw bottom border (Row 24)
    mov di, 24 * 80 * 2     ; Start at bottom-left (Row 24, Col 0)
    mov al, [border_chars+4]; ╚
    mov ah, 0x0A            ; Attribute Light Green on Black
    stosw
    mov cx, 78              ; 78 horizontal segments
    mov al, [border_chars+1]; ═
    mov ah, 0x0A            ; Attribute Light Green on Black
    rep stosw
    mov al, [border_chars+5]; ╝
    mov ah, 0x0A            ; Attribute Light Green on Black
    stosw

    ; --- Fill Inside Border with Cyan Background ---
    ; Loop through rows 1 to 23, columns 1 to 78
    mov bx, 1 ; Row counter (starts at 1)
.cyan_row_loop:
    cmp bx, 24 ; Loop while row < 24 (i.e., rows 1 through 23)
    jge .end_cyan_fill

    ; Calculate start DI for current row (Col 1)
    mov ax, bx      ; AX = row
    mov cl, 80
    mul cl          ; AX = row * 80
    add ax, 1       ; AX = row * 80 + 1 (Column 1)
    mov di, ax
    shl di, 1       ; DI = (row * 80 + 1) * 2 (Byte offset)

    ; Fill columns 1 to 78 in this row
    push bx         ; Save row counter as CX will be used by LOOP
    mov cx, 78      ; Column counter (fill 78 columns)
    ; CHANGED: Fill with Space character (0x20) with Black (0) on Cyan (3) attribute (0x30)
    mov ax, 0x3020  ; <-- CORRECTED ATTRIBUTE for Cyan Background
.cyan_col_loop:
    mov word [es:di], ax
    add di, 2
    loop .cyan_col_loop
    pop bx          ; Restore row counter

    inc bx          ; Move to the next row
    jmp .cyan_row_loop
.end_cyan_fill:

    ; --- Draw Foreground UI (Title, Exit Msg) ---
    ; These will use Cyan as their background color, keeping the original text color.

    ; Title: "Haribirds Tiny Wing Escape"
    ; Length = 28 characters
    ; Centering within the 80-column screen: (80 - 28) / 2 = 26
    ; Placed around row 11 or 12 inside the border (usable rows 1-23)
    mov di, (11 * 80 + 26) * 2 ; Row 11, Col 26
    mov si, title_msg
.title_loop:
    lodsb           ; Load byte from DS:SI into AL, increment SI
    or al, al       ; Check if it's the null terminator (0)
    jz .title_done  ; If zero, message is finished
    ; Attribute: Bright Yellow (E) on Cyan (3) -> 0x3E
    mov ah, 0x3E
    stosw           ; Store AL (character) and AH (attribute) at ES:DI, increment DI by 2
    jmp .title_loop
.title_done:

    ; Exit Instruction: "Press ESC to Start Loading Your Game"
    ; Length = 34 characters
    ; Centering within the 80-column screen: (80 - 34) / 2 = 23
    ; Row: Below title, e.g., Row 13
    mov di, (13 * 80 + 23) * 2 ; Row 13, Col 23 (Updated position for centering)
    mov si, exit_msg
.exit_msg_loop:
    lodsb           ; Load byte from DS:SI into AL, increment SI
    or al, al       ; Check if it's the null terminator (0)
    jz .exit_msg_done ; If zero, message is finished
    ; Attribute: Bright White (F) on Cyan (3) -> 0x3F
    mov ah, 0x3F
    stosw           ; Store AL (character) and AH (attribute) at ES:DI, increment DI by 2
    jmp .exit_msg_loop
.exit_msg_done:

    ; --- End UI Drawing ---


main_loop:
    ; Simulate a game loop delay using INT 1Ah timer ticks
    ; This effectively paces the music at the 18.2 Hz timer interrupt rate
    call wait_frame

    ; --- Call our music player ---
    call play_music_tick

    ; --- Check for ESC key ---
    ; BIOS check for keystroke doesn't wait, just checks buffer status
    mov ah, 0x01
    int 0x16
    jz .continue_loop ; Zero flag set means no key pressed, continue loop

    ; Key was pressed, read it to clear the keyboard buffer and get value
    ; BIOS read keystroke waits if buffer empty, but we know it's not because AH=01 returned non-zero
    mov ah, 0x00
    int 0x16

    cmp al, 0x1B    ; Compare AL with ESC key ASCII (0x1B)
    ; Although the message says "Start Loading", pressing ESC will still exit
    ; the program as that is the original functionality tied to this key press.
    je near exit_program ; If ESC, jump to exit (simulating "loading" then exiting demo)

.continue_loop:
    jmp main_loop   ; Continue the game/music loop


exit_program:
    ; --- Turn off speaker before exiting ---
    call stop_music_explicitly

    mov ax, 0x4C00  ; DOS exit function (AH=4Ch, AL=exit code 00h)
    int 0x21


; --- Subroutines ---

; wait_frame: Corrected to wait for a timer tick
; Waits for the INT 1Ah timer low word to change, indicating a tick has occurred.
; This provides a ~18.2 Hz frame rate (the rate of the system timer).
wait_frame:
    push dx ; Save DX on the stack
    mov ah, 0x00 ; Get system time (CX:DX = ticks since midnight)
    int 0x1a
    ; DX now holds the low word of the timer ticks at the start of the wait
.wait_loop_corrected:
    push dx ; Save the value of DX from the previous INT 1Ah call
    mov ah, 0x00 ; Get system time again
    int 0x1a
    pop bx ; Restore the previous DX value into BX for comparison
    cmp dx, bx ; Compare current DX with the value from before the second INT 1a call
    je .wait_loop_corrected ; If they are the same, the timer hasn't ticked, loop
    ; Timer has ticked (DX is different from BX)
    inc word [game_timer] ; Increment game timer (optional, but useful)
    pop dx ; Restore the original DX from the stack (saved at the beginning of the subroutine)
    ret


stop_music_explicitly:
    push ax
    in al, 0x61
    and al, 0xFC ; Clear bits 0 and 1 to turn off speaker
    out 0x61, al
    mov byte [is_music_playing_note], 0
    pop ax
    ret

play_music_tick:
    push ax
    push bx
    push si

    mov si, [current_music_note_ptr]

    cmp word [si], 0xFFFF ; Check for end of song marker
    je .restart_music_sequence

    cmp word [current_note_duration_counter], 0 ; Is the current note duration finished?
    jg .decrement_music_duration                ; If > 0, just decrement

.load_next_music_segment:
    ; Stop the current note if playing
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    mov byte [is_music_playing_note], 0

    ; Load frequency and duration for the next note/rest
    mov ax, [si]    ; AX = frequency (0 for rest)
    mov bx, [si+2]  ; BX = duration

    ; Basic validation (duration must be positive)
    cmp bx, 0
    jle .handle_invalid_duration ; Skip if duration is invalid or zero (shouldn't happen with valid data)

    ; Set the new duration counter
    mov [current_note_duration_counter], bx

    ; Advance the music pointer
    add si, 4
    mov [current_music_note_ptr], si

    ; Check if it's a rest (frequency is 0)
    cmp ax, 0
    je .music_segment_is_rest ; If frequency is 0, it's a rest

    ; If it's a note, set up the PIT channel 2
    push ax ; Save frequency
    mov al, 0xB6 ; Channel 2, Square wave, LSB then MSB
    out 0x43, al
    pop ax ; Restore frequency (divisor)
    out 0x42, al ; Write LSB
    mov al, ah
    out 0x42, al ; Write B

    ; Enable speaker (bits 0 and 1 of port 0x61)
    in al, 0x61
    or al, 0x03
    out 0x61, al
    mov byte [is_music_playing_note], 1 ; Mark that a note is playing

    jmp .music_tick_done_quit ; Note started, done for this tick

.music_segment_is_rest:
    ; Speaker is already off from .load_next_music_segment
    mov byte [is_music_playing_note], 0 ; Mark that it's a rest (no note playing)
    ; Fall through to decrement_music_duration or done_quit

.decrement_music_duration:
    dec word [current_note_duration_counter]
    ; Done processing for this tick, either decremented or started new segment
    jmp .music_tick_done_quit

.handle_invalid_duration:
    ; Skip the invalid segment
    add si, 4
    mov [current_music_note_ptr], si
    mov word [current_note_duration_counter], 0 ; Ensure duration is 0 so it tries to load next
    jmp .music_tick_done_quit

.restart_music_sequence:
    mov word [current_music_note_ptr], music_flappy_theme ; Reset pointer to start of song
    mov word [current_note_duration_counter], 0 ; Reset duration counter
    ; Ensure speaker is off when restarting
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    mov byte [is_music_playing_note], 0
    jmp .music_tick_done_quit

.music_tick_done_quit:
    pop si
    pop bx
    pop ax
    ret


; --- Data ---
title_msg       db "Haribirds Tiny Wing Escape", 0
exit_msg        db "Press ESC to Start Loading Your Game", 0 ; --- UPDATED MESSAGE ---

; Double line border characters (ASCII)
; ╔═╗ ║ ╚╝
border_chars    db 0xC9, 0xCD, 0xBB, 0xBA, 0xC8, 0xBC

; music_flappy_theme: (Frequency, Duration) pairs. Duration is in timer ticks (18.2Hz)
; Frequencies are calculated as 1193180 / desired_frequency
; Durations are approximately: S=1 tick, E=2 ticks, Q=4 ticks, H=8 ticks, W=16 ticks, DQ=6 ticks, DH=12 ticks.
; Staccato E represented as (Note, 1), (Rest, 1) pair, totaling 2 ticks.
music_flappy_theme:
    ; Part A - Main Motif (Staccato & Bouncy feel)
    ; C5 E_stac, G5 E_stac, E5 E_stac, G5 E_stac, C6 DQ, R Q
    dw 2280,1,  0,1,    ; C5 E_stac (Note 1, Rest 1) -> 2 ticks total
    dw 1522,1,  0,1,    ; G5 E_stac (Note 1, Rest 1)
    dw 1810,1,  0,1,    ; E5 E_stac (Note 1, Rest 1)
    dw 1522,1,  0,1,    ; G5 E_stac (Note 1, Rest 1)
    dw 1140,6,          ; C6 DQ (Note 6)
    dw 0,4,             ; Rest Q (Rest 4)

    ; Part A Variation 1 - Uses F#5, also bouncy
    ; D5 E_stac, A5 E_stac, F#5 E_stac, A5 E_stac, D6 DQ, R Q
    dw 2030,1,  0,1,    ; D5 E_stac
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1612,1,  0,1,    ; F#5 E_stac
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1015,6,          ; D6 DQ
    dw 0,4,             ; R Q

    ; Repeat Main Motif
    ; C5 E_stac, G5 E_stac, E5 E_stac, G5 E_stac, C6 DQ, R Q
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1140,6,          ; C6 DQ
    dw 0,4,             ; R Q

    ; Part A Ending - A bit more melodic run
    ; E5 E_stac, C5 E_stac, A4 E_stac, G4 Q_full, Rest Q_full
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 2712,1,  0,1,    ; A4 E_stac (lower A)
    dw 3044,4,          ; G4 Q_full (lower G, held 4 ticks)
    dw 0,4,             ; Rest Q_full

    ; -- Repeat Part A Block (more bouncy notes) --
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1140,6,          ; C6 DQ
    dw 0,4,             ; R Q

    dw 2030,1,  0,1,    ; D5 E_stac
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1612,1,  0,1,    ; F#5 E_stac
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1015,6,          ; D6 DQ
    dw 0,4,             ; R Q

    dw 2280,1,  0,1,    ; C5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1140,6,          ; C6 DQ
    dw 0,4,             ; R Q

    dw 1810,1,  0,1,    ; E5 E_stac
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 2712,1,  0,1,    ; A4 E_stac
    dw 3044,4,          ; G4 Q_full
    dw 0,8,             ; Rest H (8 ticks rest before bridge)


    ; -- New Section 1: Descending Passage (full durations) --
    ; C6 Q, D6 E, B5 E, A5 E, G5 H, R Q
    dw 1140,4,          ; C6 Q (4 ticks)
    dw 1015,2,          ; D6 E (2 ticks)
    dw 1208,2,          ; B5 E (2 ticks)
    dw 1356,2,          ; A5 E (2 ticks)
    dw 1522,8,          ; G5 H (8 ticks)
    dw 0,4,             ; R Q (4 ticks rest)

    ; F#5 Q, E5 E, D5 E, C5 E, B4 H, R Q
    dw 1612,4,          ; F#5 Q
    dw 1810,2,          ; E5 E
    dw 2030,2,          ; D5 E
    dw 2280,2,          ; C5 E
    dw 2416,8,          ; B4 H (lower B)
    dw 0,4,             ; R Q


    ; -- New Section 2: Arpeggio-like Floating (staccato & full) --
    ; C5 E_stac, E5 E_stac, G5 Q, E5 E_stac, C5 E_stac, G5 Q, R Q (using R Q)
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 1522,4,          ; G5 Q
    dw 1810,1,  0,1,    ; E5 E_stac
    dw 2280,1,  0,1,    ; C5 E_stac
    dw 1522,4,          ; G5 Q
    dw 0,4,             ; R Q

    ; F5 E_stac, A5 E_stac, C6 Q, A5 E_stac, F5 E_stac, C6 Q, R Q (using R Q)
    dw 1700,1,  0,1,    ; F5 E_stac
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1140,4,          ; C6 Q
    dw 1356,1,  0,1,    ; A5 E_stac
    dw 1700,1,  0,1,    ; F5 E_stac
    dw 1140,4,          ; C6 Q
    dw 0,4,             ; R Q

    ; Final rise towards loop
    ; G5 E_stac, B5 E_stac, D6 H, Rest DH
    dw 1522,1,  0,1,    ; G5 E_stac
    dw 1208,1,  0,1,    ; B5 E_stac
    dw 1015,8,          ; D6 H (8 ticks)
    dw 0,12,            ; Rest DH (12 ticks rest)

music_data_end:
    dw 0xFFFF, 0 ; End of song marker - indicates player should loop

; Variables used by music player and game loop
current_music_note_ptr: dw music_flappy_theme
current_note_duration_counter: dw 0
is_music_playing_note: db 0
game_timer: dw 0