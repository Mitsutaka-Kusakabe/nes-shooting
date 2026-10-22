; ゲームオーバーBGM「TEARS OF SYLPH」(Ys風アレンジ)
; tools/gen_music.py により自動生成 (直接編集しないこと)
.segment "RODATA"

gov_LOOP = 0
gov_order:
    .byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
    .byte $FF

gov_pat_lo:
    .byte <gov_pat_Y1, <gov_pat_Y2, <gov_pat_Y3, <gov_pat_Y4, <gov_pat_Y5, <gov_pat_Y6, <gov_pat_Y7, <gov_pat_Y8, <gov_pat_Y9, <gov_pat_Y10, <gov_pat_Y11, <gov_pat_Y12, <gov_pat_Y13, <gov_pat_Y14, <gov_pat_Y15
gov_pat_hi:
    .byte >gov_pat_Y1, >gov_pat_Y2, >gov_pat_Y3, >gov_pat_Y4, >gov_pat_Y5, >gov_pat_Y6, >gov_pat_Y7, >gov_pat_Y8, >gov_pat_Y9, >gov_pat_Y10, >gov_pat_Y11, >gov_pat_Y12, >gov_pat_Y13, >gov_pat_Y14, >gov_pat_Y15

gov_pat_Y1:
    .byte $25, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $2D, $FF, $FF, $FF, $2C, $FF, $FF, $FF
    .byte $06, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $12, $FF, $FF, $FF, $15, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $1E, $FF, $FF, $FF, $21, $FF, $FF, $FF, $25, $FF, $FF, $FF, $2A, $FF, $FF, $FF
gov_pat_Y2:
    .byte $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $29, $FF, $FF, $FF, $2A, $FF, $FF, $FF
    .byte $05, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $14, $FF, $FF, $FF, $19, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $21, $FF, $FF, $FF, $25, $FF, $FF, $FF, $20, $FF, $FF, $FF, $21, $FF, $FF, $FF
gov_pat_Y3:
    .byte $2C, $FF, $FF, $FF, $FF, $FF, $2D, $FF, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $0E, $FF, $FF, $FF, $15, $FF, $FF, $FF, $1A, $FF, $FF, $FF, $1E, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $23, $FF, $FF, $FF, $FF, $FF, $25, $FF, $21, $FF, $FF, $FF, $25, $FF, $FF, $FF
gov_pat_Y4:
    .byte $29, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $0D, $FF, $FF, $FF, $14, $FF, $FF, $FF, $19, $FF, $FF, $FF, $1D, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $20, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $25, $FF, $FF, $FF, $29, $FF, $FF, $FF
gov_pat_Y5:
    .byte $25, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $2D, $FF, $FF, $FF, $2F, $FF, $FF, $FF
    .byte $06, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $12, $FF, $FF, $FF, $15, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $1E, $FF, $FF, $FF, $21, $FF, $FF, $FF, $25, $FF, $FF, $FF, $27, $FF, $FF, $FF
gov_pat_Y6:
    .byte $31, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2F, $FF, $FF, $FF, $2D, $FF, $FF, $FF
    .byte $0B, $FF, $FF, $FF, $12, $FF, $FF, $FF, $17, $FF, $FF, $FF, $1A, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $29, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2C, $FF, $FF, $FF, $2A, $FF, $FF, $FF
gov_pat_Y7:
    .byte $2C, $FF, $FF, $FF, $FF, $FF, $2D, $FF, $2C, $FF, $FF, $FF, $2A, $FF, $FF, $FF
    .byte $0D, $FF, $FF, $FF, $14, $FF, $FF, $FF, $17, $FF, $FF, $FF, $19, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $29, $FF, $FF, $FF, $FF, $FF, $2A, $FF, $29, $FF, $FF, $FF, $25, $FF, $FF, $FF
gov_pat_Y8:
    .byte $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $06, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $12, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $21, $FF, $FF, $FF, $25, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $2D, $FF, $FF, $FF
gov_pat_Y9:
    .byte $2D, $FF, $FF, $FF, $2F, $FF, $FF, $FF, $31, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $09, $FF, $FF, $FF, $10, $FF, $FF, $FF, $15, $FF, $FF, $FF, $19, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $2A, $FF, $FF, $FF, $2C, $FF, $FF, $FF, $2D, $FF, $FF, $FF, $FF, $FF, $FF, $FF
gov_pat_Y10:
    .byte $32, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $31, $FF, $FF, $FF, $2F, $FF, $FF, $FF
    .byte $0B, $FF, $FF, $FF, $12, $FF, $FF, $FF, $17, $FF, $FF, $FF, $1A, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $2F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2D, $FF, $FF, $FF, $2C, $FF, $FF, $FF
gov_pat_Y11:
    .byte $31, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2D, $FF, $FF, $FF, $2A, $FF, $FF, $FF
    .byte $06, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $12, $FF, $FF, $FF, $15, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $2D, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $25, $FF, $FF, $FF
gov_pat_Y12:
    .byte $2C, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $0D, $FF, $FF, $FF, $14, $FF, $FF, $FF, $19, $FF, $FF, $FF, $1D, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $29, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
gov_pat_Y13:
    .byte $2D, $FF, $FF, $FF, $2C, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $29, $FF, $FF, $FF
    .byte $0E, $FF, $FF, $FF, $15, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $14, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $2A, $FF, $FF, $FF, $29, $FF, $FF, $FF, $26, $FF, $FF, $FF, $25, $FF, $FF, $FF
gov_pat_Y14:
    .byte $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $06, $FF, $FF, $FF, $0D, $FF, $FF, $FF, $12, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $21, $FF, $FF, $FF, $25, $FF, $FF, $FF, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF
gov_pat_Y15:
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $06, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
