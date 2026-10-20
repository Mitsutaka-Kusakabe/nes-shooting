; ゲームオーバーBGM「REST IN PEACE」(YS2 Game Over Arrange)
; tools/gen_music.py により自動生成 (直接編集しないこと)
.segment "RODATA"

gov_LOOP = 0
gov_order:
    .byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    .byte $FF

gov_pat_lo:
    .byte <gov_pat_GO1, <gov_pat_GO2, <gov_pat_GO3, <gov_pat_GO4, <gov_pat_GO5, <gov_pat_GO6, <gov_pat_GO7, <gov_pat_GO8, <gov_pat_GO9, <gov_pat_GO10, <gov_pat_GO11, <gov_pat_GO12, <gov_pat_GO13, <gov_pat_GO14
gov_pat_hi:
    .byte >gov_pat_GO1, >gov_pat_GO2, >gov_pat_GO3, >gov_pat_GO4, >gov_pat_GO5, >gov_pat_GO6, >gov_pat_GO7, >gov_pat_GO8, >gov_pat_GO9, >gov_pat_GO10, >gov_pat_GO11, >gov_pat_GO12, >gov_pat_GO13, >gov_pat_GO14

gov_pat_GO1:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $24, $FF, $FF, $FF, $26, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO2:
    .byte $28, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO3:
    .byte $28, $FF, $FF, $FF, $26, $FF, $FF, $FF, $24, $FF, $FF, $FF, $21, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO4:
    .byte $1F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $21, $FF, $FF, $FF, $23, $FF, $FF, $FF
    .byte $07, $FF, $FF, $FF, $0E, $FF, $FF, $FF, $07, $FF, $FF, $FF, $0E, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO5:
    .byte $24, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $0C, $FF, $FF, $FF, $13, $FF, $FF, $FF, $0C, $FF, $FF, $FF, $13, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO6:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $28, $FF, $FF, $FF, $2B, $FF, $FF, $FF
    .byte $10, $FF, $FF, $FF, $17, $FF, $FF, $FF, $10, $FF, $FF, $FF, $17, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO7:
    .byte $2D, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2B, $FF, $FF, $FF, $2A, $FF, $FF, $FF
    .byte $11, $FF, $FF, $FF, $18, $FF, $FF, $FF, $0E, $FF, $FF, $FF, $15, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO8:
    .byte $28, $FF, $FF, $FF, $26, $FF, $FF, $FF, $26, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $10, $FF, $FF, $FF, $17, $FF, $FF, $FF, $10, $FF, $FF, $FF, $17, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO9:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $24, $FF, $FF, $FF, $26, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO10:
    .byte $28, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO11:
    .byte $28, $FF, $FF, $FF, $26, $FF, $FF, $FF, $24, $FF, $FF, $FF, $21, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $09, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO12:
    .byte $1F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $21, $FF, $FF, $FF, $23, $FF, $FF, $FF
    .byte $07, $FF, $FF, $FF, $0E, $FF, $FF, $FF, $07, $FF, $FF, $FF, $0E, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO13:
    .byte $21, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $15, $FF, $FF, $FF, $10, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
gov_pat_GO14:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $09, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
