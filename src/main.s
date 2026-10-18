; ============================================================================
; MOJAxMOJA WARS — ファミリーコンピュータ 縦スクロールシューティングゲーム
; 自機: KBX-026 SAMURAI / 敵勢力: 地球外生命体 MOJAxMOJA
; ステージ: 1面(月) -> 2面(火星) -> 3面(木星) -> 4面(地球付近) + 各面BOSS & ワープ演出
; ============================================================================

.include "header.s"

; ---- PPU / APU レジスタ ----
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOY1      = $4016
FRAMECNT  = $4017

OAM_BUF   = $0200       ; スプライト用シャドウ OAM (256バイト)

.segment "ZEROPAGE"
nmi_ready:      .res 1  ; 1=描画データ準備完了 (NMI が 0 に戻す)
frame_count:    .res 1  ; グローバルフレームカウンタ
buttons:        .res 1  ; 現在のパッド入力
prev_buttons:   .res 1  ; 前フレームのパッド入力
btn_press:      .res 1  ; 今フレームで新たに押されたボタン
rng_lo:         .res 1  ; 16bit LFSR 乱数
rng_hi:         .res 1

; ゲーム進行ステート
game_state:     .res 1  ; 0=PLAYING 1=WARP 2=DEAD 3=GAMEOVER 4=TITLE 5=ENDING 6=BRIEFING
state_timer:    .res 1  ; ステート演出用タイマー
paused:         .res 1  ; 1=ポーズ中
menu_sel:       .res 1  ; タイトルメニュー選択 (0=START, 1=STAGE SELECT)
current_stage:  .res 1  ; 0=MOON, 1=MARS, 2=JUPITER, 3=EARTH ORBIT
lives:          .res 1  ; 残機数

; 縦スクロール & 背景ストリーミング
cam_nt:         .res 1  ; 現在のネームテーブルY選択 (0=$2000, 1=$2800)
cam_y:          .res 1  ; 現在の垂直スクロール座標 (0..239)
scroll_sub:     .res 1  ; スクロールサブカウンタ
meta_idx:       .res 1  ; ステージ進行メタ行 (0..63)
meta_sub_row:   .res 1  ; メタ行内サブ行 (0..1)
row_pending:    .res 1  ; 1=NMI で row_buf[0..31] を転送
row_ppu_hi:     .res 1  ; 行転送先 PPU アドレス Hi
row_ppu_lo:     .res 1  ; 行転送先 PPU アドレス Lo
warp_mode:      .res 1  ; 1=ボス撃破後の超高速ワープ航行中
level_ptr:      .res 2  ; 現在ステージのマップデータポインタ

; 自機 KBX-026 SAMURAI 状態 & パワーアップ (MAX 5段階)
player_x:       .res 1
player_y:       .res 1
weapon_type:    .res 1  ; 0=NORMAL MISSILE, 1=LASER, 2=WIDE (レーザーとワイドは択一)
weapon_level:   .res 1  ; 1..5 (違う武器種を取ると Lv1 に戻る)
rapid_level:    .res 1  ; 1..5 (連射強化)
barrier_hp:     .res 1  ; 0..5 (バリア耐久値)
shot_timer:     .res 1  ; Aボタン連射間隔 / レーザー照射後0.5秒(30f)クールタイム
laser_timer:    .res 1  ; 第3形態レーザー照射残りフレーム (120=2秒照射, 0=停止)
b_cooldown:     .res 1  ; Bボタン範囲攻撃クールタイム (0=READY, 120=2秒充填)
b_blast_timer:  .res 1  ; Bボタン範囲攻撃エフェクト残りフレーム
b_blast_x:      .res 1  ; Bボタン範囲攻撃の中心X
b_blast_y:      .res 1  ; Bボタン範囲攻撃の中心Y
inv_timer:      .res 1  ; 無敵フレームタイマー
ally_state:     .res 1  ; 味方支援機状態 (0=不在, 1=パーツ運搬降下中, 2=パーツ投下後帰還中)
ally_x:         .res 1  ; 味方支援機 X座標
ally_y:         .res 1  ; 味方支援機 Y座標
ally_part:      .res 1  ; 運搬中パーツ (0=ステージ1/3 脚部パーツ, 1=ステージ2/3 胸部パーツ)

; ボス状態
boss_state:     .res 1  ; 0=不在, 1=戦闘中, 2=撃破爆発中
boss_hp:        .res 1
boss_x:         .res 1
boss_y:         .res 1
boss_dir:       .res 1
boss_timer:     .res 1
boss_flash:     .res 1

; スコア (6桁 10進: score+0=十万 .. score+5=一)
score:          .res 6

; 演出・OAM・汎用ワーク
kill_flash:     .res 1  ; 画面フラッシュ残りフレーム
oam_ptr:        .res 1  ; 動的 OAM 書き込みオフセット
wave_counter:   .res 1  ; 編隊カウンタ (アイテムキャリア周期用)
item_cycle_idx: .res 1  ; アイテム種別ローテーションカウンタ
cur_enemy_idx:  .res 1  ; 現在処理中の敵インデックス
tmp:            .res 1
tmp2:           .res 1
tmp3:           .res 1
tmp_bx:         .res 1
tmp_by:         .res 1
tmp_vx:         .res 1
tmp_vy:         .res 1
tmp_tile:       .res 1
tmp_attr:       .res 1
tmp_dmg:        .res 1
tmp_pierce:     .res 1
tmp_type:       .res 1
tmp_carrier:    .res 1
tmp_cnt:        .res 1
tmp_save_x:     .res 1
tmp_save_y:     .res 1
text_ptr:       .res 2

; サウンドワーク
bgm_track:      .res 1
bgm_tick:       .res 1
bgm_step:       .res 1
sfx_sq2_type:   .res 1
sfx_sq2_timer:  .res 1
sfx_noi_type:   .res 1
sfx_noi_timer:  .res 1

.segment "BSS"
row_buf:        .res 32 ; 縦スクロール用 横1行 (32タイル) ストリーミングバッファ

; 自機弾プール (MAX_PBULLETS = 8)
pbul_flag:      .res 8
pbul_x:         .res 8
pbul_y:         .res 8
pbul_vx:        .res 8
pbul_vy:        .res 8
pbul_tile:      .res 8
pbul_dmg:       .res 8
pbul_pierce:    .res 8

; 敵機 MOJAxMOJA プール (MAX_ENEMIES = 6)
enemy_flag:     .res 6
enemy_x:        .res 6
enemy_y:        .res 6
enemy_type:     .res 6
enemy_hp:       .res 6
enemy_timer:    .res 6
enemy_drop:     .res 6

; 敵弾プール (MAX_EBULLETS = 6)
ebul_flag:      .res 6
ebul_x:         .res 6
ebul_y:         .res 6
ebul_vx:        .res 6
ebul_vy:        .res 6
ebul_tile:      .res 6

; パワーアップアイテムプール (MAX_ITEMS = 2)
item_flag:      .res 2
item_x:         .res 2
item_y:         .res 2
item_type:      .res 2

.segment "CODE"
reset:
    sei
    cld
    ldx #$40
    stx FRAMECNT        ; APU フレーム IRQ 無効化
    ldx #$FF
    txs
    inx                 ; X = 0
    stx PPUCTRL         ; NMI 無効
    stx PPUMASK         ; 描画オフ
    stx APUSTATUS       ; APU オフ
    bit PPUSTATUS
:   bit PPUSTATUS       ; vblank 1回目待ち
    bpl :-

    ; RAM クリア ($0000-$07FF)
    lda #$00
    tax
@clr_ram:
    sta $0000,x
    sta $0100,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @clr_ram

    ; シャドウ OAM を $FF で初期化
    lda #$FF
@clr_oam:
    sta OAM_BUF,x
    inx
    bne @clr_oam

:   bit PPUSTATUS       ; vblank 2回目待ち
    bpl :-

    ; 乱数シード初期化
    lda #$A5
    sta rng_lo
    lda #$5A
    sta rng_hi

    jsr sound_init
    lda #3
    sta lives
    jsr show_title

main_loop:
    inc frame_count
    jsr read_controller

    lda game_state
    beq @playing
    cmp #STATE_TITLE
    bne @other_state
    jsr update_title
    jmp @finish

@other_state:
    ; STATE_WARP の間も背景スクロールと自機・スプライト描画を継続してワープ演出を見せる
    jsr update_state
    lda game_state
    cmp #STATE_WARP
    beq @warp_draw
    cmp #STATE_DEAD
    beq @dead_draw
    jmp @finish

@warp_draw:
    jsr update_scroll
    jsr draw_all_sprites
    jmp @finish

@dead_draw:
    jsr update_scroll
    jsr update_enemies
    jsr update_boss
    jsr draw_all_sprites
    jmp @finish

@playing:
    ; START ボタンでポーズ切替
    lda btn_press
    and #BTN_START
    beq :+
    lda paused
    eor #1
    sta paused
    lda #SFX_POWERUP
    jsr play_sfx
:   lda paused
    bne @finish

    jsr update_scroll
    jsr update_player
    jsr update_enemies
    jsr update_boss
    lda game_state
    cmp #STATE_PLAYING
    beq @do_draw
    cmp #STATE_WARP
    beq @do_draw
    cmp #STATE_DEAD
    beq @do_draw
    jmp @finish

@do_draw:
    jsr draw_all_sprites

@finish:
    jsr update_sound
    lda #1
    sta nmi_ready
@wait_nmi:
    lda nmi_ready
    bne @wait_nmi
    jmp main_loop

; ============================================================================
; NMI: VBlank 期間中に OAM DMA、行ストリーミング転送、フラッシュ、スクロール設定
; ============================================================================
nmi:
    pha
    txa
    pha
    tya
    pha

    lda nmi_ready
    beq @skip

    ; 1. OAM DMA ($0200 -> PPU OAM)
    lda #$00
    sta OAMADDR
    lda #>OAM_BUF
    sta OAMDMA

    ; 2. 縦スクロールで新しく現れた横1行 (32タイル) があれば PPU ネームテーブルへ転送
    lda row_pending
    beq @no_row
    lda #%10000000          ; +1 水平インクリメント
    sta PPUCTRL
    jsr write_scroll_row
@no_row:

    ; 3. 画面フラッシュ演出 (B範囲ブラスト / ボス撃破 / ワープパルス)
    lda kill_flash
    beq @no_flash
    dec kill_flash
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$30                ; 白発光
    lda kill_flash
    bne :+
    ldx #$0F                ; 元の漆黒の宇宙へ戻す
:   stx PPUDATA
@no_flash:

    ; 4. 垂直スクロール座標 (cam_y) と 上下ネームテーブル選択 (cam_nt -> bit1) の適用
    lda cam_nt
    and #1
    asl                     ; bit1 ($00=$2000, $02=$2800)
    ora #%10000000          ; NMI ON, BG=PT0, SPR=PT0
    sta PPUCTRL

    bit PPUSTATUS
    lda #$00                ; Xスクロール = 0
    sta PPUSCROLL
    lda cam_y               ; Yスクロール = 0..239
    sta PPUSCROLL

    lda #0
    sta nmi_ready

@skip:
    pla
    tay
    pla
    tax
    pla
irq:
    rti

; ---- 各サブモジュールのインクルード ----
.include "ppu.s"
.include "controller.s"
.include "scroll.s"
.include "player.s"
.include "enemy.s"
.include "boss.s"
.include "state.s"
.include "sound.s"
.include "../assets/stages.s"
.include "../assets/drums.s"

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHR"
.include "../assets/chr.s"
