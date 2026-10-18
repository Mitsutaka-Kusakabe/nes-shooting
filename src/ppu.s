; PPU 初期化・パレット管理・テキスト描画ユーティリティ
; 呼び出し時は描画オフ (PPUMASK=0) であること

.segment "CODE"

ppu_init:
    ; 基本パレット転送 ($3F00-$3F1F)
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
@pal:
    lda palette_data,x
    sta PPUDATA
    inx
    cpx #32
    bne @pal

    ; 現在のステージ (0..3) に応じた背景パレット1 (地形色) と スプライトパレット2 (ボス/強敵色) を設定
    lda current_stage
    and #3
    asl
    asl                 ; *4
    tax
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$05            ; BG パレット1 ($3F05-$3F07) = 惑星地表・要塞カラー
    sta PPUADDR
    lda stage_terrain_pal,x
    sta PPUDATA
    lda stage_terrain_pal+1,x
    sta PPUDATA
    lda stage_terrain_pal+2,x
    sta PPUDATA

    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$19            ; スプライトパレット2 ($3F19-$3F1B) = ステージ固有 MOJAxMOJA ボス&強敵カラー
    sta PPUADDR
    lda stage_boss_pal,x
    sta PPUDATA
    lda stage_boss_pal+1,x
    sta PPUDATA
    lda stage_boss_pal+2,x
    sta PPUDATA

    ; 上下ネームテーブル ($2000-$2FFF) をクリア
    jsr clear_all_nametables
    rts

; ---- 上下ネームテーブル ($2000-$23FF, $2800-$2BFF) をタイル0でクリア ----
clear_all_nametables:
    bit PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$0C            ; $2000-$2BFF (12ページ = 3KB)
    ldy #$00
    lda #$00
@clr:
    sta PPUDATA
    iny
    bne @clr
    dex
    bne @clr
    rts

; ---- ASCII 文字列描画 (text_ptr が指す 0終端文字列を PPUADDR へ出力) ----
; ASCII $20-$5F -> タイル $80-$BF (+ $60)
write_text:
    ldy #0
@loop:
    lda (text_ptr),y
    beq @done
    clc
    adc #$60
    sta PPUDATA
    iny
    bne @loop
@done:
    rts

; ---- 指定PPUアドレス (A=Hi, X=Lo) に text_ptr の文字列を描画 ----
write_text_at:
    bit PPUSTATUS
    sta PPUADDR
    stx PPUADDR
    jmp write_text

.segment "RODATA"

; ステージ別 惑星地形パレット (BG パレット1: 暗部, 中間色, ハイライト)
stage_terrain_pal:
    .byte $00, $10, $30, $00    ; STAGE 1: MOON (月面: ダークグレー, シルバー, ホワイト)
    .byte $06, $16, $27, $00    ; STAGE 2: MARS (火星: 赤錆, クリムゾン, オレンジ)
    .byte $07, $18, $2A, $00    ; STAGE 3: JUPITER (木星: 琥珀, イエローオーカー, エメラルドガス)
    .byte $01, $12, $2C, $00    ; STAGE 4: EARTH ORBIT (地球軌道: ディープブルー, アースブルー, シアン)

; ステージ別 MOJAxMOJA ボス・強敵パレット (SPR パレット2)
stage_boss_pal:
    .byte $04, $14, $35, $00    ; STAGE 1: ルナ・モジャコア (バイオレット / ピンク)
    .byte $06, $16, $37, $00    ; STAGE 2: クリムゾン・モジャビースト (深紅 / ゴールド)
    .byte $09, $1A, $38, $00    ; STAGE 3: ジュピター・モジャキャリア (毒緑 / ネオンイエロー)
    .byte $05, $15, $30, $00    ; STAGE 4: エンペラー・MOJAxMOJA (マゼンタ / 閃光ホワイト)

palette_data:
    ; BG パレット0: 宇宙空間の星々 (黒, ダークブルー, シアン, ホワイト)
    .byte $0F, $02, $1C, $30
    ; BG パレット1: 惑星地形 (ステージごとに差し替え)
    .byte $0F, $00, $10, $30
    ; BG パレット2: 要塞・軌道構造物・タイトルロゴ (黒, 紺, 赤, ゴールド)
    .byte $0F, $12, $16, $27
    ; BG パレット3: テキスト・UIハイライト (黒, グレー, ゴールド, ホワイト)
    .byte $0F, $10, $28, $30

    ; SPR パレット0: 自機 KBX-026 SAMURAI & 通常ミサイル/ワイド弾 (黒, 蒼翼$11, 紅蓮$16, 純白$30)
    .byte $0F, $11, $16, $30
    ; SPR パレット1: レーザー / バリア / B範囲ブラスト / アイテム (黒, 青$12, シアン$2C, 白$30)
    .byte $0F, $12, $2C, $30
    ; SPR パレット2: MOJAxMOJA ボス & 大型敵 (ステージ別差し替え)
    .byte $0F, $04, $14, $35
    ; SPR パレット3: MOJAxMOJA 一般敵機 & 敵弾 & 爆発 (黒, 深緑$0A, オレンジ紅$16, 黄白$38)
    .byte $0F, $1A, $16, $38
