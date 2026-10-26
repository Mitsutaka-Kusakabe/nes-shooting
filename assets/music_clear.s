; ステージ移動BGM「INTRODUCTION!! - WARP OVERDRIVE」(Issue #18 案A)
; tools/gen_music.py により自動生成 (直接編集しないこと)
.segment "RODATA"

clr_LOOP = 0
clr_order:
    .byte 0, 1, 2, 3
    .byte $FF

clr_pat_lo:
    .byte <clr_pat_C1, <clr_pat_C2, <clr_pat_C3, <clr_pat_C4
clr_pat_hi:
    .byte >clr_pat_C1, >clr_pat_C2, >clr_pat_C3, >clr_pat_C4

clr_pat_C1:
    .byte $2C, $FF, $FF, $27, $2C, $FF, $2E, $FF, $2F, $FF, $FF, $2A, $2F, $FF, $31, $FF
    .byte $14, $00, $14, $20, $14, $00, $14, $20, $0B, $00, $0B, $17, $0B, $00, $0B, $17
    .byte $01, $00, $00, $01, $02, $00, $01, $00, $01, $00, $00, $01, $02, $00, $02, $02
    .byte $23, $FF, $FF, $1E, $23, $FF, $25, $FF, $27, $FF, $FF, $23, $27, $FF, $28, $FF
clr_pat_C2:
    .byte $33, $FF, $FF, $FF, $31, $FF, $2F, $FF, $2E, $FF, $2F, $FF, $31, $FF, $33, $FF
    .byte $10, $00, $10, $1C, $10, $00, $10, $1C, $12, $00, $12, $1E, $12, $00, $12, $1E
    .byte $01, $00, $01, $00, $02, $00, $01, $00, $01, $00, $01, $00, $02, $00, $01, $02
    .byte $2C, $27, $23, $27, $2C, $27, $23, $27, $2A, $25, $22, $25, $2A, $2E, $2F, $31
clr_pat_C3:
    .byte $34, $FF, $FF, $33, $31, $FF, $2F, $FF, $2E, $FF, $2B, $FF, $2C, $FF, $FF, $FF
    .byte $0D, $00, $0D, $19, $10, $00, $10, $1C, $0F, $00, $0F, $1B, $14, $FF, $FF, $FF
    .byte $01, $00, $00, $01, $02, $00, $01, $00, $02, $00, $02, $00, $01, $02, $02, $02
    .byte $2C, $FF, $FF, $2A, $28, $FF, $27, $FF, $25, $FF, $27, $FF, $24, $FF, $FF, $FF
clr_pat_C4:
    .byte $27, $2C, $30, $33, $38, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00
    .byte $08, $FF, $FF, $FF, $14, $FF, $FF, $FF, $08, $FF, $FF, $FF, $00, $00, $00, $00
    .byte $01, $00, $00, $00, $02, $00, $00, $00, $01, $00, $00, $00, $00, $00, $00, $00
    .byte $24, $27, $2C, $30, $33, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00
