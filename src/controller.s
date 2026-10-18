; コントローラ1 読み取り
; buttons: bit7=A bit6=B bit5=Select bit4=Start bit3=Up bit2=Down bit1=Left bit0=Right

BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

.segment "CODE"
read_controller:
    lda buttons
    sta prev_buttons
    lda #$01
    sta JOY1            ; ストローブ開始
    sta buttons         ; リングカウンタ
    lsr a
    sta JOY1            ; ストローブ終了
@loop:
    lda JOY1
    lsr a               ; bit0 -> C
    rol buttons
    bcc @loop
    ; 今フレームで新たに押されたボタン (立ち上がりエッジ)
    lda prev_buttons
    eor #$FF
    and buttons
    sta btn_press
    rts
