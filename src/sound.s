; APU サウンドエンジン (BGM 5曲 + 効果音 8種 + DPCM ドラム)

TRACK_NONE   = 0
TRACK_TITLE  = 1
TRACK_STAGE1 = 2
TRACK_STAGE2 = 3
TRACK_BOSS   = 4
TRACK_CLEAR  = 5

SFX_SHOT     = 1
SFX_LASER    = 2
SFX_BOMB     = 3
SFX_HIT      = 4
SFX_EXPLODE  = 5
SFX_POWERUP  = 6
SFX_DEAD     = 7
SFX_WARP     = 8
SFX_DOCK     = 9        ; ドッキング合体効果音「ガッ・シャン！！」 (金属クラッチ＋ロック音)

.segment "CODE"

sound_init:
    lda #%00011111          ; SQ1, SQ2, TRI, NOI, DMC 有効化
    sta APUSTATUS
    lda #$30
    sta $4000               ; SQ1 サイレント
    sta $4004               ; SQ2 サイレント
    sta $400C               ; NOI サイレント
    lda #$00
    sta $4008               ; TRI サイレント
    sta bgm_track
    sta bgm_tick
    sta bgm_step
    sta sfx_sq2_type
    sta sfx_sq2_timer
    sta sfx_noi_type
    sta sfx_noi_timer
    rts

; ---- BGM トラック切替 (A = TRACK_*) ----
set_bgm_track:
    sta bgm_track
    lda #0
    sta bgm_tick
    sta bgm_step
    sta bgm_order_idx
    sta bgm_bar_step
    lda #$30
    sta $4000
    lda #$00
    sta $4008
    rts

; ---- 効果音リクエスト (A = SFX_*) ----
play_sfx:
    cmp #SFX_DOCK
    beq @dock_sfx
    cmp #SFX_HIT
    bcs @noise_or_jingle
    ; SHOT / LASER / BOMB は SQ2 + NOI で鳴らす
    cmp #SFX_BOMB
    beq @bomb_sfx
    sta sfx_sq2_type
    lda #10
    sta sfx_sq2_timer
    rts

@dock_sfx:
    ; ★ ドッキング合体効果音「ガッ・シャン！！」 (SQ2 重低音クラッチ->ロック音 + NOI 金属モード2段衝撃音)
    lda #SFX_DOCK
    sta sfx_sq2_type
    sta sfx_noi_type
    lda #28
    sta sfx_sq2_timer
    sta sfx_noi_timer
    rts

@bomb_sfx:
    lda #SFX_BOMB
    sta sfx_sq2_type
    lda #24
    sta sfx_sq2_timer
    lda #SFX_EXPLODE
    sta sfx_noi_type
    lda #24
    sta sfx_noi_timer
    rts

@noise_or_jingle:
    cmp #SFX_POWERUP
    beq @pw_sfx
    cmp #SFX_WARP
    beq @warp_sfx
    ; HIT / EXPLODE / DEAD はノイズチャンネルを使用
    sta sfx_noi_type
    lda #18
    cmp #SFX_HIT
    bne :+
    lda #6
:   sta sfx_noi_timer
    rts

@pw_sfx:
    lda #SFX_POWERUP
    sta sfx_sq2_type
    lda #20
    sta sfx_sq2_timer
    rts

@warp_sfx:
    lda #SFX_WARP
    sta sfx_sq2_type
    lda #40
    sta sfx_sq2_timer
    rts

; ---- 毎フレームのサウンド更新 ----
update_sound:
    jsr update_sfx_sq2
    jsr update_sfx_noi
    jsr update_bgm
    rts

; ---- SQ2 効果音更新 (ショット / レーザー / B範囲ブラスト / パワーアップ / ワープ / ドッキング) ----
update_sfx_sq2:
    lda sfx_sq2_timer
    bne :+
    rts
:   dec sfx_sq2_timer
    bne @active
    lda #$30
    sta $4004
    lda #0
    sta sfx_sq2_type
    rts

@active:
    lda sfx_sq2_type
    cmp #SFX_LASER
    beq @do_laser
    cmp #SFX_BOMB
    beq @do_bomb
    cmp #SFX_POWERUP
    beq @do_pw
    cmp #SFX_WARP
    beq @do_warp
    cmp #SFX_DOCK
    bne :+
    jmp @do_dock_sq2
:

    ; SFX_SHOT: 高音から急速ピッチダウンするミサイル音
    lda #%10111011
    sta $4004
    lda #$08
    sta $4005
    lda #12
    sec
    sbc sfx_sq2_timer
    asl
    asl
    asl
    clc
    adc #$50
    sta $4006
    lda #$00
    sta $4007
    rts

@do_laser:
    ; SFX_LASER: シャープな高周波レーザー音
    lda #%01111100
    sta $4004
    lda #$08
    sta $4005
    lda sfx_sq2_timer
    asl
    asl
    eor #$7F
    and #$7F
    clc
    adc #$28
    sta $4006
    lda #$00
    sta $4007
    rts

@do_bomb:
    ; SFX_BOMB: プラズマ衝撃波のうねり音
    lda #%10111111
    sta $4004
    lda #$08
    sta $4005
    lda sfx_sq2_timer
    asl
    asl
    asl
    eor #$A0
    sta $4006
    lda #$01
    sta $4007
    rts

@do_pw:
    ; SFX_POWERUP: 上昇アルペジオチャイム
    lda #%10111101
    sta $4004
    lda #$08
    sta $4005
    lda #20
    sec
    sbc sfx_sq2_timer
    lsr
    lsr
    and #3
    tay
    lda pw_arp_lo,y
    sta $4006
    lda #$00
    sta $4007
    rts

@do_warp:
    ; SFX_WARP: ハイパードライブ加速音 (徐々に高音へスイープ)
    lda #%10111110
    sta $4004
    lda #$08
    sta $4005
    lda sfx_sq2_timer
    asl
    asl
    clc
    adc #$20
    sta $4006
    lda #$00
    sta $4007
    rts

@do_dock_sq2:
    ; 「ガッ(28..20:重低音クラッチ) -> 間(19..17) -> シャン！(16..1:金属ロック＋ツインアイ発光音)」
    lda sfx_sq2_timer
    cmp #20
    bcs @dock_clunk
    cmp #17
    bcs @dock_gap
    ; 後半(16..1): 「シャン！」の金属ロック共鳴音
    lda #%01111110
    sta $4004
    lda #$08
    sta $4005
    lda #$58
    ldy sfx_sq2_timer
    cpy #10
    bcs :+
    lda #$3C
:   sta $4006
    lda #$00
    sta $4007
    rts
@dock_clunk:
    ; 前半(28..20): 「ガッ！」の重厚なドッキング衝撃音
    lda #%10111111
    sta $4004
    lda #$08
    sta $4005
    lda #$C8
    sta $4006
    lda #$01
    sta $4007
    rts
@dock_gap:
    lda #$30
    sta $4004
    rts

; ---- NOI 効果音更新 (被弾ヒット / 敵撃破爆発 / 自機撃墜 / ドッキング金属音) ----
update_sfx_noi:
    lda sfx_noi_timer
    bne :+
    rts
:   dec sfx_noi_timer
    bne @active
    lda #$30
    sta $400C
    lda #0
    sta sfx_noi_type
    rts

@active:
    lda sfx_noi_type
    cmp #SFX_DOCK
    beq @do_dock_noi
    cmp #SFX_HIT
    beq @do_hit

    ; 爆発音 (EXPLODE / DEAD)
    lda sfx_noi_timer
    lsr
    ora #$34
    sta $400C
    lda #$0E                ; 低音ノイズ
    ldy sfx_noi_type
    cpy #SFX_DEAD
    bne :+
    lda #$0F                ; 自機撃墜時はさらに重低音
:   sta $400E
    lda #$00
    sta $400F
    rts

@do_dock_noi:
    ; APU ノイズの金属ループモード ($80 bit ON) を使った「ガッ・シャン！！」2段金属合体音！
    lda sfx_noi_timer
    cmp #20
    bcs @noi_gassh
    cmp #17
    bcs @noi_silence
    ; 後半(16..1): 「シャン！！」金属ラッチ余韻 (徐々に減衰)
    lsr
    ora #$36
    sta $400C
    lda #$87                ; 金属モード($80) + 中高域金属ピッチ($07)
    ldy sfx_noi_timer
    cpy #8
    bcs :+
    lda #$08                ; 最後はエア圧プシュー余韻
:   sta $400E
    lda #$00
    sta $400F
    rts
@noi_gassh:
    ; 前半(28..20): 「ガッ！」重い金属噛み合わせ音
    lda #$3F                ; 最大音量
    sta $400C
    lda #$8B                ; 金属モード($80) + 重金属ピッチ($0B)
    sta $400E
    lda #$00
    sta $400F
    rts
@noi_silence:
    lda #$30
    sta $400C
    rts

@do_hit:
    lda #$3A
    sta $400C
    lda #$06
    sta $400E
    lda #$00
    sta $400F
    rts

; ---- BGM シーケンサ更新 (SQ1 メロディ + TRI ベース + DPCMドラム + NOI ハイハット) ----
update_bgm:
    lda bgm_track
    bne :+
    rts
:   lda paused
    beq :+
    lda #$30
    sta $4000
    lda #$00
    sta $4008
    rts
:
    ; テンポ制御: 通常ステージ・ボス戦は 6フレーム/step (150 BPM)
    ; タイトル・クリア等は 7フレーム/step
    inc bgm_tick
    lda #6
    ldx bgm_track
    cpx #TRACK_STAGE1
    beq :+
    cpx #TRACK_STAGE2
    beq :+
    cpx #TRACK_BOSS
    beq :+
    lda #7
:   cmp bgm_tick
    bcc @step_next
    beq @step_next
    rts

@step_next:
    lda #0
    sta bgm_tick

    ; 通常ステージ (TRACK_STAGE1, TRACK_STAGE2) か判定
    lda bgm_track
    cmp #TRACK_STAGE1
    beq @do_stage_bgm
    cmp #TRACK_STAGE2
    beq @do_stage_bgm

    ; ---- 従来 32ステップ曲 (TITLE / BOSS / CLEAR) ----
    ldx bgm_step
    inx
    txa
    and #31                 ; 32ステップループ
    sta bgm_step
    tax

    lda bgm_track
    cmp #TRACK_TITLE
    beq @trk_title
    cmp #TRACK_BOSS
    beq @trk_boss
    cmp #TRACK_CLEAR
    beq @trk_clear
    rts

@trk_title:
    lda mel_title,x
    tay
    lda bass_title,x
    jmp @play_legacy_notes

@trk_boss:
    lda mel_boss,x
    tay
    lda bass_boss,x
    jmp @play_legacy_notes

@trk_clear:
    lda mel_clear,x
    tay
    lda bass_clear,x

@play_legacy_notes:
    pha
    cpy #0
    beq @legacy_rest_mel
    lda #%10111011          ; Duty 50%, Vol 11
    sta $4000
    lda #$08
    sta $4001
    lda note_table_lo,y
    sta $4002
    lda note_table_hi,y
    sta $4003
    jmp @legacy_bass
@legacy_rest_mel:
    lda #$30
    sta $4000

@legacy_bass:
    pla
    tay
    beq @legacy_rest_bass
    lda #$81                ; TRI ON
    sta $4008
    lda note_table_lo,y
    sta $400A
    lda note_table_hi,y
    sta $400B
    jmp @do_drums
@legacy_rest_bass:
    lda #$00
    sta $4008
    jmp @do_drums

    ; =========================================================================
    ; ---- 新・通常ステージBGM「LUNAR CATACOMB DRIVE」再生ルーチン ----
    ; =========================================================================
@do_stage_bgm:
    ; 小節ポインタ text_ptr を計算: stg_order[bgm_order_idx] のパターンアドレス
    ldx bgm_order_idx
    lda stg_order,x
    cmp #$FF
    bne :+
    ; ループ位置 (STG_LOOP) へジャンプ
    lda #STG_LOOP
    sta bgm_order_idx
    tax
    lda stg_order,x
:   tax
    lda stg_pat_lo,x
    sta text_ptr
    lda stg_pat_hi,x
    sta text_ptr+1

    ; 1. メロディ (SQ1)
    ldy bgm_bar_step
    lda (text_ptr),y
    cmp #$FF                ; $FF = 伸ばし (キープ)
    beq @stg_bass
    cmp #0                  ; 0 = 休符
    beq @stg_rest_mel
    ; ノート発音
    tax
    lda #%10111011          ; Duty 50%, Vol 11
    sta $4000
    lda #$08
    sta $4001
    lda stg_period_lo,x
    sta $4002
    lda stg_period_hi,x
    sta $4003
    jmp @stg_bass
@stg_rest_mel:
    lda #$30
    sta $4000

@stg_bass:
    ; 2. ベース (TRI: offset +16)
    lda bgm_bar_step
    clc
    adc #16
    tay
    lda (text_ptr),y
    cmp #$FF                ; 伸ばし
    beq @stg_drums
    cmp #0                  ; 休符
    beq @stg_rest_bass
    tax
    lda #$81                ; TRI ON (線形カウンタ最大)
    sta $4008
    lda stg_period_lo,x
    sta $400A
    lda stg_period_hi,x
    sta $400B
    jmp @stg_drums
@stg_rest_bass:
    lda #$00
    sta $4008

@stg_drums:
    ; 3. DPCM ドラム (offset +32: 0=なし, 1=キック, 2=スネア)
    lda bgm_bar_step
    clc
    adc #32
    tay
    lda (text_ptr),y
    beq @stg_step_inc
    cmp #1
    beq @trigger_kick
    ; スネア ($C000 + $03C0 = $C3C0 -> $4012 = $0F, len = $27)
    lda #$0E                ; rate 14
    sta $4010
    lda #$0F                ; ($C000 + $0F*64 = $C3C0)
    sta $4012
    lda #$27                ; len $27*16+1
    sta $4013
    lda #$0F
    sta $4015
    lda #$1F                ; DMC再生トリガー
    sta $4015
    jmp @stg_step_inc
@trigger_kick:
    ; キック ($C000 -> $4012 = $00, len = $3A)
    lda #$0D                ; rate 13
    sta $4010
    lda #$00                ; $C000
    sta $4012
    lda #$3A                ; len $3A*16+1
    sta $4013
    lda #$0F
    sta $4015
    lda #$1F                ; DMC再生トリガー
    sta $4015

@stg_step_inc:
    ; ステップ進行 (0..15)
    inc bgm_bar_step
    lda bgm_bar_step
    cmp #16
    bcc @do_drums
    lda #0
    sta bgm_bar_step
    inc bgm_order_idx
    ; fall-through to @do_drums

@do_drums:
    ; ノイズSFXが鳴っていないときだけリズムハイハットを刻む
    lda sfx_noi_timer
    bne @env_only
    lda bgm_bar_step
    and #1
    bne @hat_light
    lda #$36
    sta $400C
    lda #$03
    sta $400E
    lda #$00
    sta $400F
    rts
@hat_light:
    lda #$33
    sta $400C
    lda #$01
    sta $400E
    lda #$00
    sta $400F
@env_only:
    rts

.segment "RODATA"
.include "../assets/music_stage.s"

pw_arp_lo:
    .byte $AA, $87, $71, $55

; ノート周期テーブル (0=休符, 1..24 = A2..G#4)
note_table_lo:
    .byte $00
    .byte $F9, $E2, $C9, $B3, $9E, $8B, $79, $68, $59, $4A, $3C, $30  ; 1..12 (低音/中音)
    .byte $FB, $EE, $E2, $D6, $C9, $BE, $B3, $A9, $9E, $96, $8B, $84  ; 13..24 (高音)
note_table_hi:
    .byte $00
    .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; 1. タイトル画面テーマ (MOJAxMOJA WARS Heroic Theme)
mel_title:
    .byte 13, 0,16,18, 20, 0,18,16, 18, 0,16,13, 15, 0,13, 0
    .byte 13,15,16,18, 20,21,23,20, 22, 0,20,18, 20, 0, 0, 0
bass_title:
    .byte  1, 1, 8, 8,  6, 6, 6, 6,  4, 4,11,11,  3, 3, 8, 8
    .byte  1, 1, 8, 8,  6, 6,13,13,  8, 8, 6, 6,  1, 0, 1, 0

; 2. ステージ1・3 テーマ (Cosmic Interceptor - Moon / Jupiter)
mel_stage1:
    .byte 20,18,16,20, 23,20,18,16, 18,16,15,18, 20,18,16,15
    .byte 16,18,20,23, 24,23,20,18, 20,22,23,20, 18, 0,16, 0
bass_stage1:
    .byte  1, 8, 1, 8,  1, 8, 1, 8,  6,11, 6,11,  8,12, 8,12
    .byte  4, 9, 4, 9,  6,11, 6,11,  8,12, 8,12,  1, 8, 1, 0

; 3. ステージ2・4 テーマ (Red Planet Assault - Mars / Earth Orbit)
mel_stage2:
    .byte 15,15,18,15, 20,18,15,13, 16,16,19,16, 22,19,16,15
    .byte 18,18,22,18, 23,22,18,16, 20,19,18,16, 15, 0,20, 0
bass_stage2:
    .byte  3,10, 3,10,  3,10, 3,10,  4,11, 4,11,  4,11, 4,11
    .byte  6,12, 6,12,  8,12, 8,12,  3,10, 4,11,  3, 0, 3, 0

; 4. ボス戦テーマ (MOJAxMOJA Dreadnought)
mel_boss:
    .byte 13,14,13,19, 13,14,13,20, 14,15,14,20, 14,15,14,21
    .byte 16,17,16,22, 18,19,18,24, 23,22,20,19, 18,16,14,13
bass_boss:
    .byte  1, 2, 1, 7,  1, 2, 1, 8,  2, 3, 2, 8,  2, 3, 2, 9
    .byte  4, 5, 4,10,  6, 7, 6,12,  8, 7, 6, 5,  4, 3, 2, 1

; 5. ステージクリア & ワープファンファーレ
mel_clear:
    .byte 13,16,20,24, 24, 0,20,24, 23,20,18,20, 22, 0, 0, 0
    .byte 16,20,23,24, 23,20,16,20, 24,24,24, 0, 24, 0, 0, 0
bass_clear:
    .byte  1, 5, 8,12, 12, 0, 8,12,  6, 8,11, 8, 10, 0, 0, 0
    .byte  4, 8,11,12, 11, 8, 4, 8,  1, 1, 1, 0,  1, 0, 0, 0
