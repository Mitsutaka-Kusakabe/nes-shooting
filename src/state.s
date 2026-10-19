; ゲームステート管理 (タイトル / ステージブリーフィング / ワープ演出 / 撃墜 / ゲームオーバー / エンディング)
; および HUD・全スプライト OAM 構築 (チラつき防止ローテーション付き)

STATE_PLAYING  = 0
STATE_WARP     = 1
STATE_DEAD     = 2
STATE_GAMEOVER = 3
STATE_TITLE    = 4
STATE_ENDING   = 5
STATE_BRIEFING = 6

.segment "CODE"

; ---- 16bit LFSR 乱数更新 (A に乱数 0..255 を返す) ----
next_rng:
    lda rng_lo
    lsr
    rol rng_hi
    bcc :+
    eor #$B4
:   sta rng_lo
    eor rng_hi
    rts

; ---- スコア加算 (A = 加算する100点の倍数) ----
add_score_hundreds:
    clc
    adc score+3             ; 百の位
@carry3:
    cmp #10
    bcc @store3
    sec
    sbc #10
    inc score+2             ; 千の位
    jmp @carry3
@store3:
    sta score+3

    lda score+2
@carry2:
    cmp #10
    bcc @store2
    sec
    sbc #10
    inc score+1             ; 万の位
    jmp @carry2
@store2:
    sta score+2

    lda score+1
@carry1:
    cmp #10
    bcc @store1
    sec
    sbc #10
    inc score+0             ; 十万の位
    jmp @carry1
@store1:
    sta score+1

    lda score+0
    cmp #9
    bcc :+
    lda #9
    sta score+0
:   rts

; ---- OAM バッファ全クリア ($FF で画面外へ) ----
clear_oam:
    ldx #0
    lda #$FF
@loop:
    sta OAM_BUF,x
    inx
    bne @loop
    rts

; ============================================================
; タイトル画面 (MOJAxMOJA WARS)
; ============================================================
show_title:
    lda #0
    sta PPUMASK
    sta PPUCTRL
    sta cam_nt
    sta cam_x
    sta cam_y
    sta side_mode
    sta warp_mode
    sta paused
    lda #STATE_TITLE
    sta game_state


    jsr ppu_init
    jsr clear_oam

    ; 背景に宇宙の星々を散りばめる
    lda #$20
    jsr fill_initial_starfield

    ; Row 2 (Y=16): EARTH DEFENSE FORCE CHRONICLE
    lda #<str_title_sub
    sta text_ptr
    lda #>str_title_sub
    sta text_ptr+1
    lda #$20
    ldx #$42
    jsr write_text_at

    ; Row 4 (Y=32): * MOJAxMOJA WARS *
    lda #<str_title_main
    sta text_ptr
    lda #>str_title_main
    sta text_ptr+1
    lda #$20
    ldx #$87
    jsr write_text_at

    ; Row 6 (Y=48): FIGHTER: KBX-026 SAMURAI
    lda #<str_title_ship
    sta text_ptr
    lda #>str_title_ship
    sta text_ptr+1
    lda #$20
    ldx #$C4
    jsr write_text_at

    ; Row 15 (Y=120): ALIEN MOJAxMOJA INVADED
    lda #<str_title_story1
    sta text_ptr
    lda #>str_title_story1
    sta text_ptr+1
    lda #$21
    ldx #$E4
    jsr write_text_at

    ; Row 17 (Y=136): INTERCEPT & DESTROY BOSS!
    lda #<str_title_story2
    sta text_ptr
    lda #>str_title_story2
    sta text_ptr+1
    lda #$22
    ldx #$24
    jsr write_text_at

    ; Row 20 (Y=160): START MISSION
    lda #<str_title_menu1
    sta text_ptr
    lda #>str_title_menu1
    sta text_ptr+1
    lda #$22
    ldx #$89
    jsr write_text_at

    ; Row 22 (Y=176): STAGE SELECT:  -
    lda #<str_title_menu2
    sta text_ptr
    lda #>str_title_menu2
    sta text_ptr+1
    lda #$22
    ldx #$C9
    jsr write_text_at

    ; Row 25 (Y=200): A:MISSILE/LASER/WIDE (LV1-5)
    lda #<str_title_ctrl1
    sta text_ptr
    lda #>str_title_ctrl1
    sta text_ptr+1
    lda #$23
    ldx #$22
    jsr write_text_at

    ; Row 27 (Y=216): B:RANGE BLAST (COOLDOWN)
    lda #<str_title_ctrl2
    sta text_ptr
    lda #>str_title_ctrl2
    sta text_ptr+1
    lda #$23
    ldx #$64
    jsr write_text_at

    ; タイトルの属性テーブル: 上部ロゴ行はパレット2 (ゴールド)、本文はパレット3 (白)
    bit PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #0
@tattr:
    lda #$FF                ; パレット3 (白)
    cpx #8
    bcc :+
    cpx #16
    bcs :+
    lda #$AA                ; 属性行1 (タイル行4-7: MOJAxMOJA WARS ロゴ) はパレット2 (ゴールド)
:   sta PPUDATA
    inx
    cpx #64
    bne @tattr

    lda #TRACK_TITLE
    jsr set_bgm_track

    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10000000          ; NMI ON, PT0
    sta PPUCTRL
    lda #%00011110          ; BG & SPR ON
    sta PPUMASK
    rts

update_title:
    jsr clear_oam
    ; SELECT または 上下で メニュー選択 (0=START, 1=STAGE SELECT)
    lda btn_press
    and #(BTN_SELECT | BTN_UP | BTN_DOWN)
    beq @chk_lr
    lda menu_sel
    eor #1
    sta menu_sel
    lda #SFX_SHOT
    jsr play_sfx

@chk_lr:
    ; 左右または Bボタンで 開始ステージ (1〜4) を切替可能
    lda btn_press
    and #(BTN_RIGHT | BTN_B)
    beq @chk_left
    lda current_stage
    clc
    adc #1
    and #3
    sta current_stage
    lda #1
    sta menu_sel
    lda #SFX_POWERUP
    jsr play_sfx
@chk_left:
    lda btn_press
    and #BTN_LEFT
    beq @draw_t_spr
    lda current_stage
    sec
    sbc #1
    and #3
    sta current_stage
    lda #1
    sta menu_sel
    lda #SFX_POWERUP
    jsr play_sfx

@draw_t_spr:
    ; カーソル矢印 ($16) at Y=159 (menu 0) or Y=175 (menu 1)
    lda menu_sel
    asl
    asl
    asl
    asl                     ; *16
    clc
    adc #159
    sta OAM_BUF+0
    lda #$16
    sta OAM_BUF+1
    lda #$00
    sta OAM_BUF+2
    lda #56
    sta OAM_BUF+3

    ; 選択ステージ番号 ('1'..'4') をスプライト表示 (Y=175, X=184)
    lda #175
    sta OAM_BUF+4
    lda current_stage
    clc
    adc #$91                ; '1' ($31 + $60 = $91)
    sta OAM_BUF+5
    lda #$01
    sta OAM_BUF+6
    lda #184
    sta OAM_BUF+7

    ; タイトル画面中央 (Y=78〜96) のビジュアルショーケース:
    ; 中央: KBX-026 SAMURAI (X=120, Y=88) + レーザービーム
    ; 左右: 地球外生命体 MOJAxMOJA (X=64, X=176, Y=80)
    lda #16
    sta oam_ptr
    lda #120
    sta player_x
    lda #88
    sta player_y
    jsr draw_samurai_at_py

    ; SAMURAI から発射されるツインレーザー演出
    lda #124
    sta tmp_bx
    lda #74
    sta tmp_by
    lda #$09
    sta tmp_tile
    lda #$01
    sta tmp_attr
    jsr push_one_sprite

    ; 左の MOJAxMOJA SCOUT ($20)
    lda #64
    sta tmp_bx
    lda #80
    sta tmp_by
    lda #$20
    sta tmp_tile
    lda #$03
    sta tmp_attr
    jsr push_16x16_metatile

    ; 右の MOJAxMOJA CHARGER ($28)
    lda #176
    sta tmp_bx
    lda #80
    sta tmp_by
    lda #$28
    sta tmp_tile
    lda #$02
    sta tmp_attr
    jsr push_16x16_metatile

    ; START または Aボタンでミッション開始！
    lda btn_press
    and #(BTN_START | BTN_A)
    beq @ret
    lda menu_sel
    bne :+
    lda #0                  ; START MISSION なら STAGE 1 から
    sta current_stage
:
    ; 新規ゲーム初期化
    lda #3
    sta lives
    lda #0
    sta score+0
    sta score+1
    sta score+2
    sta score+3
    sta score+4
    sta score+5
    jsr player_init
    jsr start_stage_briefing
@ret:
    rts

; ============================================================
; ステージ開始ブリーフィング (STAGE 1〜4: MOON / MARS / JUPITER / EARTH)
; ============================================================
start_stage_briefing:
    lda #0
    sta PPUMASK
    sta PPUCTRL
    sta cam_nt
    sta cam_y
    sta row_pending
    sta warp_mode
    lda #STATE_BRIEFING
    sta game_state
    lda #110                ; 約1.8秒表示
    sta state_timer

    jsr ppu_init
    jsr clear_oam
    lda #$20
    jsr fill_initial_starfield

    ; "STAGE X" と ステージ名を描画
    lda #<str_brief_hdr
    sta text_ptr
    lda #>str_brief_hdr
    sta text_ptr+1
    lda #$21
    ldx #$4C
    jsr write_text_at

    ; ステージ番号 ('1'..'4')
    bit PPUSTATUS
    lda #$21
    sta PPUADDR
    lda #$52
    sta PPUADDR
    lda current_stage
    clc
    adc #$91
    sta PPUDATA

    ; ステージ固有サブタイトル (MOON / MARS / JUPITER / EARTH ORBIT)
    lda current_stage
    and #3
    asl
    tax
    lda stage_name_table,x
    sta text_ptr
    lda stage_name_table+1,x
    sta text_ptr+1
    lda #$21
    ldx #$88
    jsr write_text_at

    lda #<str_brief_ship
    sta text_ptr
    lda #>str_brief_ship
    sta text_ptr+1
    lda #$22
    ldx #$06
    jsr write_text_at

    lda #SFX_POWERUP
    jsr play_sfx

    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10000000
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

; ---- ブリーフィング終了後に実ステージを開始 ----
enter_stage_play:
    lda #0
    sta PPUMASK
    sta PPUCTRL

    jsr ppu_init
    jsr init_stage_bg
    jsr enemies_init
    jsr boss_init
    jsr clear_pbullets
    jsr clear_oam

    lda #120
    sta player_x
    lda #184
    sta player_y
    lda #60
    sta inv_timer
    lda #0
    sta b_cooldown
    sta b_blast_timer
    lda #STATE_PLAYING
    sta game_state

    ; ステージBGM開始
    lda current_stage
    and #1
    clc
    adc #TRACK_STAGE1
    jsr set_bgm_track

    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    lda cam_y
    sta PPUSCROLL
    lda #%10000000
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

; ============================================================
; 演出ステート更新 (STATE_WARP / STATE_DEAD / STATE_GAMEOVER / STATE_ENDING / STATE_BRIEFING)
; ============================================================
update_state:
    lda game_state
    cmp #STATE_WARP
    beq @do_warp
    cmp #STATE_DEAD
    bne :+
    jmp @do_dead
:   cmp #STATE_GAMEOVER
    bne :+
    jmp @do_gameover
:   cmp #STATE_ENDING
    bne :+
    jmp @do_ending
:   cmp #STATE_BRIEFING
    beq @do_briefing
    rts

@do_briefing:
    jsr clear_oam
    lda #120
    sta player_x
    lda #148
    sta player_y
    lda #16
    sta oam_ptr
    jsr draw_samurai_at_py
    dec state_timer
    bne :+
    jsr enter_stage_play
:   rts

@do_warp:
    ; ---- ステージクリア後のワープ演出！ ----
    ; 1. state_timer 150..90: 自機が中央へ移動しながら背景がワープ光線化
    ; 2. state_timer 89..1:   自機が超高速で画面上方へワープ離脱！
    lda state_timer
    cmp #90
    bcc @warp_fly_up

    ; 中央 (X=120, Y=160) へ寄せる
    lda player_x
    cmp #120
    beq @wx_ok
    bcc @wx_inc
    dec player_x
    jmp @wx_ok
@wx_inc:
    inc player_x
@wx_ok:
    jmp @warp_tick

@warp_fly_up:
    ; Stage 1〜3 では宿敵・赤いMSが水平ワープ星線の中で画面右端へブースト撤退 (boss_x += 3)！
    lda current_stage
    cmp #3
    bcs @player_warp_move
    lda boss_x
    cmp #240
    bcs @player_warp_move
    clc
    adc #3
    sta boss_x

@player_warp_move:
    ; 画面上端へ猛スピードで飛び去る！
    lda player_y
    cmp #12
    bcc @warp_tick
    sec
    sbc #4
    sta player_y
    ; 16フレームごとにワープパルスフラッシュ
    lda state_timer
    and #$0F
    bne @warp_tick
    lda #2
    sta kill_flash

@warp_tick:
    dec state_timer
    beq :+
    rts
:
    ; ワープ完了！ホワイトアウトフラッシュとともに side_mode=0 (縦スクロール) へ復帰し、次ステージまたはエンディングへ！
    lda #0
    sta warp_mode
    sta side_mode
    sta cam_x
    lda #4
    sta kill_flash
    lda current_stage
    cmp #3
    bcs @all_clear
    inc current_stage
    jsr start_stage_briefing
    rts

@all_clear:
    jsr show_ending
    rts

@do_dead:
    ; ---- 自機撃墜演出 ----
    dec state_timer
    bne @dead_ret
    dec lives
    beq @to_gameover
    ; 残機があればその場でリスポーン復帰
    jsr player_respawn
    lda #STATE_PLAYING
    sta game_state
@dead_ret:
    rts

@to_gameover:
    jsr show_gameover
    rts

@do_gameover:
    lda btn_press
    and #(BTN_START | BTN_A)
    beq :+
    jsr show_title
:   rts

@do_ending:
    jsr clear_oam
    ; エンディング画面で帰還する KBX-026 SAMURAI を描画
    lda frame_count
    lsr
    and #$1F
    clc
    adc #104
    sta player_x
    lda #136
    sta player_y
    lda #16
    sta oam_ptr
    jsr draw_samurai_at_py

    lda btn_press
    and #(BTN_START | BTN_A)
    beq :+
    jsr show_title
:   rts

; ============================================================
; ゲームオーバー画面 & エンディング画面
; ============================================================
show_gameover:
    lda #0
    sta PPUMASK
    sta PPUCTRL
    sta cam_nt
    sta cam_x
    sta cam_y
    sta side_mode
    sta row_pending
    lda #STATE_GAMEOVER
    sta game_state

    jsr ppu_init
    jsr clear_oam

    lda #<str_gameover
    sta text_ptr
    lda #>str_gameover
    sta text_ptr+1
    lda #$21
    ldx #$87                ; 17文字 ("G A M E   O V E R") を中央 (列7 = $87) に配置
    jsr write_text_at


    lda #<str_press_start
    sta text_ptr
    lda #>str_press_start
    sta text_ptr+1
    lda #$22
    ldx #$27
    jsr write_text_at

    lda #TRACK_NONE
    jsr set_bgm_track

    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10000000
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

show_ending:
    lda #0
    sta PPUMASK
    sta PPUCTRL
    sta cam_nt
    sta cam_x
    sta cam_y
    sta side_mode
    sta row_pending
    lda #STATE_ENDING
    sta game_state


    jsr ppu_init
    jsr clear_oam

    lda #<str_end_1
    sta text_ptr
    lda #>str_end_1
    sta text_ptr+1
    lda #$20
    ldx #$C4
    jsr write_text_at

    lda #<str_end_2
    sta text_ptr
    lda #>str_end_2
    sta text_ptr+1
    lda #$21
    ldx #$03
    jsr write_text_at

    lda #<str_end_3
    sta text_ptr
    lda #>str_end_3
    sta text_ptr+1
    lda #$21
    ldx #$44
    jsr write_text_at

    lda #<str_end_4
    sta text_ptr
    lda #>str_end_4
    sta text_ptr+1
    lda #$22
    ldx #$64
    jsr write_text_at

    lda #<str_press_start
    sta text_ptr
    lda #>str_press_start
    sta text_ptr+1
    lda #$22
    ldx #$E7
    jsr write_text_at

    lda #TRACK_CLEAR
    jsr set_bgm_track

    bit PPUSTATUS
    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10000000
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

; ============================================================
; スプライト OAM 描画エンジン (HUD + スプライトローテーション)
; ============================================================
draw_all_sprites:
    jsr clear_oam

    ; 1. 固定 HUD スプライト (スロット 0..14 = OAM $00..$3B)
    jsr draw_hud_sprites

    ; 2. 動的ゲームプレイオブジェクト (スロット 15..63 = OAM $3C..$FC)
    lda #$3C
    sta oam_ptr

    ; 自機 KBX-026 SAMURAI と バリア、B範囲衝撃波を描画
    jsr draw_player_and_barrier

    ; 横並び8スプライト制限による永久消失を防ぐため、フレーム偶奇で描画順をローテーション！
    lda frame_count
    and #1
    bne @odd_order

    jsr draw_pbullets_oam
    jsr draw_enemies_oam
    jsr draw_boss_oam
    jsr draw_ebullets_oam
    jsr draw_items_oam
    rts

@odd_order:
    jsr draw_ebullets_oam
    jsr draw_boss_oam
    jsr draw_enemies_oam
    jsr draw_pbullets_oam
    jsr draw_items_oam
    rts

; ---- HUD スプライト描画 (画面上部 Y=8, Y=16 & 画面下部 Y=222) ----
draw_hud_sprites:
    ; スロット 0..5: 6桁スコア (Y=8, X=192..232)
    ldx #0
    ldy #0
@sc_loop:
    lda #8
    sta OAM_BUF,x
    lda score,y
    clc
    adc #$90                ; '0' ($90)
    sta OAM_BUF+1,x
    lda #$00                ; パレット0
    sta OAM_BUF+2,x
    lda hud_score_x,y
    sta OAM_BUF+3,x
    txa
    clc
    adc #4
    tax
    iny
    cpy #6
    bne @sc_loop

    ; スロット 6..7: 残機アイコン + 残機数 (Y=16, X=8, 16)
    lda #16
    sta OAM_BUF+24
    sta OAM_BUF+28
    lda #$70                ; ミニ SAMURAI アイコン
    sta OAM_BUF+25
    lda lives
    clc
    adc #$90
    sta OAM_BUF+29
    lda #$00
    sta OAM_BUF+26
    sta OAM_BUF+30
    lda #8
    sta OAM_BUF+27
    lda #16
    sta OAM_BUF+31

    ; スロット 8..14: 下部ステータスバー (Y=222)
    ; スロット 8,9,10,(11,12): 現在の形態 ('F1' / 'F2' / 'F2.5' / 'F3' + 形態パーツアイコン)
    lda #222
    sta OAM_BUF+32
    sta OAM_BUF+36
    sta OAM_BUF+40
    lda #$A6                ; 'F' ($46 + $60 = $A6)
    sta OAM_BUF+33
    lda weapon_level        ; 1..3
    clc
    adc #$90
    sta OAM_BUF+37
    ldy weapon_type
    lda form_hud_icon,y     ; $70(Core), $18(Legs), $19(Chest), $73(Gundam)
    sta OAM_BUF+41
    lda #$00
    sta OAM_BUF+34
    sta OAM_BUF+38
    sta OAM_BUF+42
    lda #16
    sta OAM_BUF+35
    lda #24
    sta OAM_BUF+39

    ; 第2.5形態 (weapon_type == FORM_CHEST = 2) のときは '.5' を追加表示して 'F2.5' にする！
    cpy #FORM_CHEST
    beq @hud_f25
    lda #36
    sta OAM_BUF+43
    lda #$FE
    sta OAM_BUF+44
    sta OAM_BUF+48
    sta OAM_BUF+52
    jmp @hud_b_badge

@hud_f25:
    lda #52                 ; アイコンXを右へずらす
    sta OAM_BUF+43
    lda #222
    sta OAM_BUF+44
    sta OAM_BUF+48
    lda #$8E                ; '.' ($2E + $60 = $8E)
    sta OAM_BUF+45
    lda #$95                ; '5' ($35 + $60 = $95)
    sta OAM_BUF+49
    lda #$00
    sta OAM_BUF+46
    sta OAM_BUF+50
    lda #32
    sta OAM_BUF+47
    lda #40
    sta OAM_BUF+51
    lda #$FE
    sta OAM_BUF+52
@hud_b_badge:

    ; スロット 14: Bボタン範囲攻撃 READY バッジ ($71=READY / $72=CHARGE) at X=232, Y=222
    lda #222
    sta OAM_BUF+56
    lda #$71                ; READY
    ldy b_cooldown
    beq :+
    lda #$72                ; CHARGING
:   sta OAM_BUF+57
    lda #$01
    sta OAM_BUF+58
    lda #232
    sta OAM_BUF+59
    rts

; ---- 自機 (3形態: コアファイター / コア＋脚部 / ガンダムMS) + B範囲衝撃波リングの描画 ----
draw_player_and_barrier:
    lda game_state
    cmp #STATE_DEAD
    bne @alive_draw

    ; 撃墜時は爆発スプライト4枚を表示
    lda state_timer
    cmp #30
    bcc @ret_p
    lda player_x
    sta tmp_bx
    lda player_y
    sta tmp_by
    lda #$1C
    sta tmp_tile
    lda #$03
    sta tmp_attr
    jsr push_16x16_same_tile
@ret_p:
    rts

@alive_draw:
    ; 無敵時間中は2フレームごとに点滅
    lda inv_timer
    and #2
    bne @chk_saber_draw

    jsr draw_samurai_at_py

@chk_saber_draw:
    ; 近接ビームサーベル 3コマアニメーション描画 (横画面専用: 32x16 / 32x24 / 32x16 の巨大光刃！)
    lda saber_timer
    beq @chk_b_ring
    lda side_mode
    beq @chk_b_ring         ; 縦画面ではサーベル描画なし

    lda #$00                ; パレット0 (白コア + 紅蓮ビーム刃)
    sta tmp_attr

    lda saber_timer
    cmp #7
    bcc @chk_sb_f2
    ; ---- コマ1: 抜刀・斜め右上チャージ光刃 (PT1 $90-$97, 32x16) ----
    lda #$90
    sta tmp_tile
    lda player_x
    clc
    adc #18
    sta tmp_bx
    lda player_y
    sec
    sbc #2
    sta tmp_by
    jsr push_32x16_metatile
    jmp @chk_b_ring

@chk_sb_f2:
    cmp #4
    bcc @chk_sb_f3
    ; ---- コマ2: 振り下ろし大一閃！ (PT1 $A0-$AB, 32x24 巨大三日月スラッシュ) ----
    lda #$A0
    sta tmp_tile
    lda player_x
    clc
    adc #16
    sta tmp_bx
    lda player_y
    sec
    sbc #6
    sta tmp_by
    jsr push_32x24_metatile
    jmp @chk_b_ring

@chk_sb_f3:
    ; ---- コマ3: 斬り抜け・残心 (PT1 $B0-$B7, 32x16) ----
    lda #$B0
    sta tmp_tile
    lda player_x
    clc
    adc #18
    sta tmp_bx
    lda player_y
    clc
    adc #4
    sta tmp_by
    jsr push_32x16_metatile

@chk_b_ring:

    ; Bボタン範囲攻撃 (b_blast_timer > 0) の拡大プラズマリング描画
    lda b_blast_timer
    beq @done_p
    lda #25
    sec
    sbc b_blast_timer
    asl                     ; 半径 r = (25 - timer) * 2 (2..48px)
    sta tmp

    ; 左上アーク
    lda b_blast_x
    sec
    sbc tmp
    sta tmp_bx
    lda b_blast_y
    sec
    sbc tmp
    sta tmp_by
    lda #$0D
    sta tmp_tile
    lda #$01
    sta tmp_attr
    jsr push_one_sprite

    ; 右上アーク (H反転)
    lda b_blast_x
    clc
    adc tmp
    sta tmp_bx
    lda #$41
    sta tmp_attr
    jsr push_one_sprite

    ; 左下アーク (V反転)
    lda b_blast_x
    sec
    sbc tmp
    sta tmp_bx
    lda b_blast_y
    clc
    adc tmp
    sta tmp_by
    lda #$81
    sta tmp_attr
    jsr push_one_sprite

    ; 右下アーク (HV反転)
    lda b_blast_x
    clc
    adc tmp
    sta tmp_bx
    lda #$C1
    sta tmp_attr
    jsr push_one_sprite
@done_p:
    rts

; ---- player_x, player_y に現在の形態 (0:コアファイター 16x16 / 1:コア+脚部 16x24 / 2:ガンダム 16x24) を描画 ----
draw_samurai_at_py:
    lda player_y
    cmp #12
    bcc @early_ret
    cmp #224
    bcs @early_ret
    jmp @chk_state
@early_ret:
    rts
@chk_state:
    ; 形態チェック (タイトル・ブリーフィング・エンディング以外で weapon_type == 1 or 2 なら 16x24 描画)
    lda game_state
    cmp #STATE_PLAYING
    beq @chk_form
    cmp #STATE_WARP
    beq @chk_form
    jmp @draw_core_fighter

@chk_form:
    lda weapon_type
    beq @draw_core_fighter
    cmp #FORM_LEGS
    beq @draw_form2_legs
    cmp #FORM_CHEST
    beq @draw_form25_chest
    jmp @draw_gundam_ms

@draw_form2_legs:
    ; ---- 第2形態: コアファイター＋脚部 ($48..$4D, 16x24) ----
    lda #$48
    sta tmp_tile
    jmp @draw_16x24_body

@draw_form25_chest:
    ; ---- 第2.5形態: コアファイター＋胸部 ($EA..$EF, 16x24) ----
    lda #$EA
    sta tmp_tile

@draw_16x24_body:
    lda player_x
    sta tmp_bx
    lda player_y
    sec
    sbc #4
    sta tmp_by
    lda #$00                ; パレット0 (白・青・赤 ガンダムトリコロール)
    sta tmp_attr
    jsr push_16x24_metatile
    rts

@draw_gundam_ms:
    ; ---- 第3形態: 斜め向き立ち絵ガンダム＋ビームライフル ($E0..$E8, 24x24 = 9スプライト) ----
    lda #$E0
    sta tmp_tile
    lda player_x
    sec
    sbc #4
    sta tmp_bx
    lda player_y
    sec
    sbc #4
    sta tmp_by
    lda #$00                ; パレット0 (白・青・赤 ガンダムトリコロール)
    sta tmp_attr
    jsr push_24x24_metatile
    rts

@draw_core_fighter:
    ldy oam_ptr
    cpy #$F0
    bcs @ret

    ; TL ($01)
    lda player_y
    sta OAM_BUF,y
    lda #$01
    sta OAM_BUF+1,y
    lda #$00
    sta OAM_BUF+2,y
    lda player_x
    sta OAM_BUF+3,y

    ; TR ($02)
    lda player_y
    sta OAM_BUF+4,y
    lda #$02
    sta OAM_BUF+5,y
    lda #$00
    sta OAM_BUF+6,y
    lda player_x
    clc
    adc #8
    sta OAM_BUF+7,y

    ; BL ($03 or $05 ジェット噴射アニメ)
    lda player_y
    clc
    adc #8
    sta OAM_BUF+8,y
    sta OAM_BUF+12,y
    lda frame_count
    and #4
    beq @f1
    lda #$05
    jmp @set_bl
@f1:
    lda #$03
@set_bl:
    sta OAM_BUF+9,y
    clc
    adc #1
    sta OAM_BUF+13,y
    lda #$00
    sta OAM_BUF+10,y
    sta OAM_BUF+14,y
    lda player_x
    sta OAM_BUF+11,y
    clc
    adc #8
    sta OAM_BUF+15,y

    tya
    clc
    adc #16
    sta oam_ptr
@ret:
    rts

; ---- 16x24 メタタイル (tmp_tile..tmp_tile+5, 2列x3行=6スプライト) を OAM に追加 ----
push_16x24_metatile:
    lda #3
    sta tmp2                ; 3行ループ
@r24:
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    sec
    sbc #8
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    dec tmp2
    bne @r24
    rts

; ---- 24x24 メタタイル (tmp_tile..tmp_tile+8, 3列x3行=9スプライト) を OAM に追加 ----
push_24x24_metatile:
    lda #3
    sta tmp2                ; 3行ループ
@r24x24:
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    sec
    sbc #16
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    dec tmp2
    bne @r24x24
    rts

; ---- 32x16 メタタイル (tmp_tile..tmp_tile+7, 4列x2行=8スプライト) を OAM に追加 ----
push_32x16_metatile:
    lda #2
    sta tmp2                ; 2行ループ
@r32x16:
    ldx #4
@c32x16:
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    dex
    bne @c32x16
    lda tmp_bx
    sec
    sbc #32
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    dec tmp2
    bne @r32x16
    rts

; ---- 32x24 メタタイル (tmp_tile..tmp_tile+11, 4列x3行=12スプライト) を OAM に追加 ----
push_32x24_metatile:
    lda #3
    sta tmp2                ; 3行ループ
@r32x24:
    ldx #4
@c32x24:
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    dex
    bne @c32x24
    lda tmp_bx
    sec
    sbc #32
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    dec tmp2
    bne @r32x24
    rts

; ---- 自機弾 & 第3形態の貫通レーザー照射 (自機〜画面端) の OAM 描画 ----

draw_pbullets_oam:
    ; 1. 第3形態の貫通ロングレーザー照射中 (laser_timer > 0) なら自機銃口から画面端まで一本のレーザーを描画！
    lda laser_timer
    beq @draw_normal_pbul
    lda weapon_type
    cmp #FORM_GUNDAM
    bne @draw_normal_pbul

    lda #$09                ; ビームレーザータイル ($09)
    sta tmp_tile
    lda frame_count
    and #1                  ; パレット0と1を毎フレーム交互に煌めかせる
    sta tmp_attr

    lda side_mode
    bne @draw_laser_side

    ; ---- 縦スクロール道中: 上方向へ貫通レーザー照射 ----
    lda player_x
    clc
    adc #11                 ; 右腕ビームライフルの銃口X座標
    sta tmp_bx
    lda player_y
    sec
    sbc #10
    sta tmp_by
@beam_loop:
    lda tmp_by
    cmp #12                 ; 画面上端 (Y=12) まで隙間なく照射！
    bcc @draw_normal_pbul
    jsr push_one_sprite
    lda tmp_by
    sec
    sbc #10                 ; 10px刻みで画面上端まで連結描画
    sta tmp_by
    jmp @beam_loop

@draw_laser_side:
    ; ---- 横表示ロボット戦: ガンダムの右向きライフル銃口から画面右端まで水平貫通レーザー照射！ ----
    lda player_y
    clc
    adc #4                  ; 右向きライフルの銃口Y座標
    sta tmp_by
    lda player_x
    clc
    adc #20
    sta tmp_bx

    ; 8スプライト制限によるボス付近・画面右端での消失を防ぐため、フレーム偶奇で16px交互配置
    lda frame_count
    and #1
    beq :+
    lda tmp_bx
    clc
    adc #16
    sta tmp_bx
:
@beam_side_loop:
    lda tmp_bx
    cmp #248                ; 画面右端 (X=248) まで照射！
    bcs @draw_normal_pbul
    jsr push_one_sprite
    lda tmp_bx
    clc
    adc #32                 ; 32px刻みで配置 (各フレーム最大6スプライト <= 8個制限)
    bcs @draw_normal_pbul   ; 8bitオーバーフロー(256到達)で画面右端到達・脱出！
    sta tmp_bx
    jmp @beam_side_loop

@draw_normal_pbul:

    ldx #MAX_PBULLETS-1
@loop:
    lda pbul_flag,x
    beq @next
    lda pbul_x,x
    sta tmp_bx
    lda pbul_y,x
    sta tmp_by
    lda pbul_tile,x
    sta tmp_tile
    lda #$00
    ldy pbul_vx,x
    bmi @set_a
    beq @set_a
    ora #$40                ; 右斜め弾はH反転
@set_a:
    sta tmp_attr
    stx tmp_save_x
    jsr push_one_sprite
    ldx tmp_save_x
@next:
    dex
    bpl @loop
    rts

; ---- 敵機 & 支援輸送機 (キャリア) の OAM 描画 ----
draw_enemies_oam:
    ldx #MAX_ENEMIES-1
@loop:
    lda enemy_flag,x
    beq @next
    stx tmp_save_x
    lda enemy_x,x
    sta tmp_bx
    lda enemy_y,x
    sta tmp_by

    lda enemy_flag,x
    cmp #2
    bne @alive_e

    ; 爆発中 (16x16)
    lda #$1C
    ldy enemy_timer,x
    cpy #8
    bcs :+
    lda #$1D
:   sta tmp_tile
    lda #$03
    sta tmp_attr
    jsr push_16x16_same_tile
    ldx tmp_save_x
    jmp @next

@alive_e:
    ; enemy_drop != 0 なら味方の「支援輸送機 ($74-$77)」として描画！
    lda enemy_drop,x
    beq @normal_enemy
    lda #$74                ; 支援輸送機 (ガンペリー風キャリア)
    sta tmp_tile
    lda #$00                ; パレット0 (白・青・赤の連邦/味方カラー)
    sta tmp_attr
    jsr push_16x16_metatile
    ldx tmp_save_x
    jmp @next

@normal_enemy:
    ; 敵タイプ (0..3) -> ベースタイル $20, $24, $28, $2C (2色宇宙戦闘機・UFO)
    lda enemy_type,x
    asl
    asl
    clc
    adc #$20
    sta tmp_tile
    lda #$03                ; 通常敵はパレット3 (2色構成)
    sta tmp_attr
    jsr push_16x16_metatile
    ldx tmp_save_x
@next:
    dex
    bpl @loop
    rts

; ---- スプライトによるテキスト描画 (tmp_bx, tmp_by から横へ8px刻みで OAM に配置) ----
draw_sprite_text:
    ldy #0
@st_loop:
    lda (text_ptr),y
    beq @st_done
    cmp #$20
    beq @st_space           ; 空白は描画スキップしてXだけ進める
    clc
    adc #$60                ; ASCII -> フォントタイル ($80-$BF)
    sta tmp_tile
    lda #$00                ; パレット0
    sta tmp_attr
    sty tmp_save_y
    jsr push_one_sprite
    ldy tmp_save_y
@st_space:
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    iny
    bne @st_loop
@st_done:
    rts

; ---- 横表示ロボット戦: 量産型中ボス (MOJA-01..04) & 宿敵・赤いMS (RIVAL RED MS) の OAM 描画 ----
draw_boss_oam:
    ; ワープ撤退演出中 (game_state == STATE_WARP かつ Stage 1〜3) なら、画面右へ離脱する赤いMSを描画！
    lda game_state
    cmp #STATE_WARP
    bne @chk_bstate
    lda current_stage
    cmp #3
    bcs @no_boss_draw
    lda boss_x
    cmp #232
    bcs @no_boss_draw
    ; 撤退ブースト噴射炎スプライト ($05) を赤いMSの左側に描画
    lda boss_x
    clc
    adc #4
    sta tmp_bx
    lda boss_y
    clc
    adc #12
    sta tmp_by
    lda #$05
    sta tmp_tile
    lda #$00
    sta tmp_attr
    jsr push_one_sprite
    jmp @boss_alive_draw

@no_boss_draw:
    rts

@chk_bstate:
    lda boss_state
    beq @no_boss_draw
    cmp #2
    bne :+
    jmp @do_boss_explode
:   cmp #3
    bne @chk_bstate4

    ; =========================================================================
    ; ---- boss_state = 3: WARNING 警告テキストを画面中央に大迫力点滅表示！ ----
    ; =========================================================================
    lda warning_timer
    and #4
    bne :+
    rts                     ; 点滅OFFフレーム
:
    ; 1行目 (Y=80, X=96): "WARNING!" (8文字 -> 8スプライト制限以内)
    lda #<str_warn_title
    sta text_ptr
    lda #>str_warn_title
    sta text_ptr+1
    lda #96
    sta tmp_bx
    lda #80
    sta tmp_by
    jsr draw_sprite_text

    ; 2行目 (Y=96): "ENEMY MS" (8文字) または "RED MS" (6文字)
    lda boss_type
    bne @warn_rival_txt
    lda #<str_warn_midboss
    sta text_ptr
    lda #>str_warn_midboss
    sta text_ptr+1
    lda #96
    sta tmp_bx
    jmp @draw_line2
@warn_rival_txt:
    lda #<str_warn_rival
    sta text_ptr
    lda #>str_warn_rival
    sta text_ptr+1
    lda #104
    sta tmp_bx
@draw_line2:
    lda #96
    sta tmp_by
    jsr draw_sprite_text

    ; 3行目 (Y=112, X=96): "APPROACH" (8文字 -> 8スプライト制限以内)
    lda #<str_warn_approach
    sta text_ptr
    lda #>str_warn_approach
    sta text_ptr+1
    lda #96
    sta tmp_bx
    lda #112
    sta tmp_by
    jsr draw_sprite_text
    rts

@chk_bstate4:
    ; boss_state == 4 (ボス飛来突入シーン) または 1 (戦闘中)
    cmp #4
    bne @boss_alive_draw

    ; 飛来突入シーン中はボスの右後方にジェット噴射炎 ($05) を描画！
    lda boss_x
    clc
    adc #24
    sta tmp_bx
    lda boss_y
    clc
    adc #12
    sta tmp_by
    lda #$05
    sta tmp_tile
    lda #$00
    sta tmp_attr
    jsr push_one_sprite
    jmp @boss_alive_draw

@do_boss_explode:
    ; 撃破爆発中は 48x32 領域の左右2箇所に大爆発スプライトを展開
    lda boss_x
    clc
    adc #4
    sta tmp_bx
    lda boss_y
    clc
    adc #8
    sta tmp_by
    lda #$1C
    sta tmp_tile
    lda #$03
    sta tmp_attr
    jsr push_16x16_same_tile

    lda boss_x
    clc
    adc #28
    sta tmp_bx
    lda boss_y
    clc
    adc #8
    sta tmp_by
    lda #$1D
    sta tmp_tile
    lda #$02
    sta tmp_attr
    jsr push_16x16_same_tile
    rts

@boss_alive_draw:
    ; 被弾フラッシュ中はパレット1(シアン白)、通常はパレット2(ステージ固有中ボス色 or 赤いMS専用色)
    lda #$02
    ldy boss_flash
    beq :+
    lda #$01
:   sta tmp_attr

    ; 宿敵・赤いMS (boss_type == 1) なら PT1 $58-$63、量産型中ボス (boss_type == 0) ならステージ別 $30/$3C/$C0/$CC
    lda boss_type
    bne @use_rival_tile
    ldx current_stage
    lda boss_base_tile_tbl,x ; PT1 $30(ザク), $3C(ドム), $C0(ズゴック), $CC(グフ)
    jmp @got_ms_tile
@use_rival_tile:
    lda #$58                ; PT1 $58-$63: 宿敵・赤いモビルスーツ (24x32)
@got_ms_tile:
    sta tmp_tile


    ; 24x32 (3列 x 4行 = 12スプライト) の横向きモビルスーツ本体を (boss_x + 12, boss_y) に描画！
    ; (横3枚=24px幅のため、自機3枚+サーベル2枚と並んでも横8スプライト制限を超えず欠けゼロ！)
    lda boss_y
    sta tmp_by
    lda #4
    sta tmp2                ; 4行カウンタ
@ms_row_loop:
    lda boss_x
    clc
    adc #12
    sta tmp_bx

    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx

    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx

    jsr push_one_sprite
    inc tmp_tile

    lda tmp_by
    clc
    adc #8
    sta tmp_by
    dec tmp2
    bne @ms_row_loop

    ; Stage 3・4 の赤いMS (オールレンジ試作型 / フルスペック型) は周囲にビット/ファンネル2機 ($0E) を展開！
    lda boss_type
    beq @chk_gouf_rod
    lda current_stage
    cmp #2
    bcc @ms_draw_done
    lda boss_x
    sta tmp_bx
    lda boss_y
    clc
    adc #8
    sta tmp_by
    lda #$0E
    sta tmp_tile
    lda #$02
    sta tmp_attr
    jsr push_one_sprite
    lda boss_x
    clc
    adc #38
    sta tmp_bx
    jsr push_one_sprite
    rts

@chk_gouf_rod:
    ; Stage 4 中ボス グフ型 (MOJA-04) は前方にヒート・ロッド (電熱鞭 $09) を伸縮展開！
    lda current_stage
    cmp #3
    bne @ms_draw_done
    lda boss_timer
    and #$20
    beq @ms_draw_done
    lda boss_x
    clc
    adc #4
    sta tmp_bx
    lda boss_y
    clc
    adc #24
    sta tmp_by
    lda #$09
    sta tmp_tile
    lda #$01
    sta tmp_attr
    jsr push_one_sprite
@ms_draw_done:
    rts

; ---- 敵弾の OAM 描画 ----
draw_ebullets_oam:
    ldx #MAX_EBULLETS-1
@loop:
    lda ebul_flag,x
    beq @next
    lda ebul_x,x
    sta tmp_bx
    lda ebul_y,x
    sta tmp_by
    lda ebul_tile,x
    sta tmp_tile
    lda frame_count
    lsr
    and #1
    ora #$02                ; パレット2と3で明滅させて視認性アップ
    sta tmp_attr
    stx tmp_save_x
    jsr push_one_sprite
    ldx tmp_save_x
@next:
    dex
    bpl @loop
    rts

; ---- 味方支援機 (ガンペリー輸送機) & 2倍サイズ合体パーツ (16x16: $78-$7B=脚部パーツ / $7C-$7F=胸部パーツ) の OAM 描画 ----
draw_items_oam:
    ; 1. 味方支援機 (ally_state != 0) の描画
    lda ally_state
    beq @draw_dropped_parts

    ; 味方支援機本体 (16x16, $74-$77, パレット0)
    lda ally_x
    sta tmp_bx
    lda ally_y
    sta tmp_by
    lda #$74
    sta tmp_tile
    lda #$00
    sta tmp_attr
    jsr push_16x16_metatile

    ; ally_state == 1 (運搬降下中) なら、機体下部 (ally_x, ally_y+14) に懸吊中の16x16合体パーツも描画！
    lda ally_state
    cmp #1
    bne @draw_dropped_parts
    lda ally_x
    sta tmp_bx
    lda ally_y
    clc
    adc #14
    sta tmp_by
    lda ally_part
    and #1
    asl
    asl
    clc
    adc #$78                ; $78-$7B=脚部パーツ(16x16), $7C-$7F=胸部パーツ(16x16)
    sta tmp_tile
    lda #$00
    sta tmp_attr
    jsr push_16x16_metatile

@draw_dropped_parts:
    ; 2. 切り離された後の16x16合体パーツの描画
    ldx #MAX_ITEMS-1
@loop:
    lda item_flag,x
    beq @next
    lda item_x,x
    sta tmp_bx
    lda item_y,x
    sta tmp_by
    lda item_type,x
    and #1
    asl
    asl
    clc
    adc #$78                ; $78-$7B=脚部パーツ(16x16), $7C-$7F=胸部パーツ(16x16)
    sta tmp_tile
    lda #$00                ; パレット0 (ガンダムトリコロール: 白・青・赤)
    sta tmp_attr
    stx tmp_save_x
    jsr push_16x16_metatile
    ldx tmp_save_x
@next:
    dex
    bpl @loop
    rts

; ---- 8x8 スプライト1個を OAM に追加 (tmp_bx, tmp_by, tmp_tile, tmp_attr) ----
push_one_sprite:
    ldy oam_ptr
    cpy #$FC
    bcs @full
    lda tmp_by
    sta OAM_BUF,y
    lda tmp_tile
    sta OAM_BUF+1,y
    lda tmp_attr
    sta OAM_BUF+2,y
    lda tmp_bx
    sta OAM_BUF+3,y
    tya
    clc
    adc #4
    sta oam_ptr
@full:
    rts

; ---- 16x16 メタタイル (tmp_tile..tmp_tile+3) を OAM に追加 ----
push_16x16_metatile:
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    sec
    sbc #8
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    jsr push_one_sprite
    inc tmp_tile
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    jsr push_one_sprite
    rts

; ---- 16x16 爆発 (同一タイル4枚を H/V 反転して 16x16 展開) ----
push_16x16_same_tile:
    jsr push_one_sprite
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    lda tmp_attr
    eor #$40
    sta tmp_attr
    jsr push_one_sprite
    lda tmp_bx
    sec
    sbc #8
    sta tmp_bx
    lda tmp_by
    clc
    adc #8
    sta tmp_by
    lda tmp_attr
    eor #$C0
    sta tmp_attr
    jsr push_one_sprite
    lda tmp_bx
    clc
    adc #8
    sta tmp_bx
    lda tmp_attr
    eor #$40
    sta tmp_attr
    jsr push_one_sprite
    rts

.segment "RODATA"
boss_base_tile_tbl:
    .byte $30, $3C, $C0, $CC

hud_score_x:
    .byte 192, 200, 208, 216, 224, 232

form_hud_icon:
    .byte $70, $18, $19, $73 ; 0:初期=Core($70), 1:第2=Legs($18), 2:第2.5=Chest($19), 3:第3=Gundam($73)

str_title_sub:
    .byte "EARTH DEFENSE FORCE CHRONICLE", 0
str_title_main:
    .byte "* MOJAxMOJA WARS *", 0
str_title_ship:
    .byte "FIGHTER: KBX-026 SAMURAI", 0
str_title_story1:
    .byte "CORE -> LEGS -> GUNDAM MS!", 0
str_title_story2:
    .byte "DOCK PARTS & DESTROY BOSS!", 0
str_title_menu1:
    .byte "START MISSION", 0
str_title_menu2:
    .byte "STAGE SELECT:", 0
str_title_ctrl1:
    .byte "A:MISSILE / 3WAY / BEAM RIFLE", 0
str_title_ctrl2:
    .byte "B:RANGE BLAST (COOLDOWN)", 0

str_brief_hdr:
    .byte "STAGE", 0
str_brief_ship:
    .byte "KBX-026 SAMURAI LAUNCH!", 0

stage_name_table:
    .addr str_st1_name, str_st2_name, str_st3_name, str_st4_name

str_st1_name:
    .byte "SECTOR 1: THE MOON", 0
str_st2_name:
    .byte "SECTOR 2: RED MARS", 0
str_st3_name:
    .byte "SECTOR 3: JUPITER", 0
str_st4_name:
    .byte "SECTOR 4: EARTH ORBIT", 0

str_gameover:
    .byte "G A M E   O V E R", 0
str_press_start:
    .byte "PRESS START BUTTON", 0

str_warn_title:
    .byte "WARNING!", 0
str_warn_midboss:
    .byte "ENEMY MS", 0
str_warn_rival:
    .byte "RED MS", 0
str_warn_approach:
    .byte "APPROACH", 0

str_end_1:
    .byte "MISSION ACCOMPLISHED!!", 0

str_end_2:
    .byte "EMPEROR MOJAxMOJA DEFEATED!", 0
str_end_3:
    .byte "KBX-026 SAMURAI SAVED EARTH", 0
str_end_4:
    .byte "THANK YOU FOR PLAYING!", 0
