; iNES ヘッダ (Mapper 0 / NROM-256: PRG 32KB + CHR 8KB)
; 縦スクロール用に水平ミラーリング (%00000000) を指定
.segment "HEADER"
    .byte "NES", $1A
    .byte 2             ; PRG-ROM 16KB x2 = 32KB
    .byte 1             ; CHR-ROM 8KB x1
    .byte %00000000     ; Mapper 0, 水平ミラーリング (上下ネームテーブル $2000/$2800 連結)
    .byte %00000000
    .res 8, $00
