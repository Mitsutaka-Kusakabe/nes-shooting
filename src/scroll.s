; 縦スクロール & ステージ背景ストリーミング描画 (水平ミラーリング: $2000 と $2800 を上下連結)
; カメラ Y (cam_y: 0..239) を減算することで背景が上から下へ流れる

.segment "CODE"

; ---- ステージ開始時の背景初期化 (描画オフ中に呼ぶ) ----
init_stage_bg:
    lda #0
    sta cam_nt              ; 開始ネームテーブル (0=$2000)
    sta cam_y               ; 開始スクロールY (0)
    sta cam_x               ; 開始スクロールX (0)
    sta side_mode           ; 0=縦スクロール道中モード
    sta warning_timer       ; WARNING演出タイマー
    sta scroll_sub          ; サブピクセルカウンタ
    sta meta_idx            ; ステージ進行メタ行 (0..63)
    sta row_pending         ; NMI 行転送フラグ
    sta warp_mode           ; ワープ演出フラグ (0=通常, 1=高速ワープ中)
    lda #2
    sta meta_sub_row        ; メタ行内のサブ行 (2..17, 0, 1 の18行サイクル = 1メタ行2.4秒)

    ; 現在ステージの level_maps ポインタをセット (level_maps + current_stage * 64)
    lda current_stage
    and #3
    lsr                     ; C = bit0, A = bit1
    lda #0
    ror                     ; A = (current_stage & 1) ? $80 : $00
    lsr                     ; A = (current_stage & 1) ? $40 : $00
    clc
    adc #<level_maps
    sta level_ptr
    lda current_stage
    and #3
    lsr                     ; A = current_stage >> 1 (0 or 1)
    adc #>level_maps
    sta level_ptr+1

    ; BGパレット0 にもステージ色 (暗色・中間色・白星) を反映して中央地形も美しく発色させる
    lda current_stage
    and #3
    asl
    asl
    tax
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$01
    sta PPUADDR
    lda stage_terrain_pal,x
    sta PPUDATA
    lda stage_terrain_pal+1,x
    sta PPUDATA
    lda #$30                ; 色3は常に純白 (星の輝き)
    sta PPUDATA

    ; NT0 ($2000) と NT2 ($2800) の両方に初期星空を描画
    lda #$20
    jsr fill_initial_starfield
    lda #$28
    jsr fill_initial_starfield

    ; 属性テーブル ($23C0, $2BC0): 左右端(列0-7, 24-31)をパレット1($55)、中央をパレット0($00)に設定
    lda #$23
    jsr init_stage_attr
    lda #$2B
    jsr init_stage_attr
    rts

; ---- ネームテーブル1面分 (30行 x 32列) に初期星空を配置 ----
fill_initial_starfield:
    bit PPUSTATUS
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #30                 ; 30行
@row_loop:
    ldy #0                  ; 32列
@col_loop:
    jsr next_rng
    and #$3F
    cmp #1
    beq @dim_star
    cmp #2
    beq @bright_star
    lda #$00
    jmp @write_t
@dim_star:
    lda #$50
    jmp @write_t
@bright_star:
    lda #$51
@write_t:
    sta PPUDATA
    iny
    cpy #32
    bne @col_loop
    dex
    bne @row_loop
    rts

; ---- 属性テーブル初期化 (A = $23 or $2B) ----
init_stage_attr:
    bit PPUSTATUS
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #8                  ; 8属性行
@arow:
    ; 左2バイト = パレット1 ($55), 中央4バイト = パレット0 ($00), 右2バイト = パレット1 ($55)
    lda #$55
    sta PPUDATA
    sta PPUDATA
    lda #$00
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    sta PPUDATA
    lda #$55
    sta PPUDATA
    sta PPUDATA
    dex
    bne @arow
    rts

; ---- 毎フレームの縦スクロール / 横表示モード時の水平スクロール更新 ----
update_scroll:
    ; 横表示・1-on-1 ロボット戦モード (side_mode == 1) なら水平方向 ($2005 cam_x) にスクロール！
    lda side_mode
    beq @vert_scroll_mode
    lda warp_mode
    beq @side_normal_spd
    ; ワープ撤退演出中 (Exec_Warp_Escape_Sequence): 水平方向へ 8px/フレームの超高速ハイパーワープ！
    lda cam_x
    clc
    adc #8
    sta cam_x
    rts
@side_normal_spd:
    inc cam_x
    rts

@vert_scroll_mode:
    ; スクロール速度の決定:
    ; - ワープ中 (warp_mode=1): 8px/フレームの超高速スクロール！
    ; - 通常道中 / ボス戦: 1px/フレーム (2フレームに2px = 毎フレーム1px)
    lda warp_mode
    beq @normal_speed
    lda #8
    jmp @do_scroll

@normal_speed:
    ; 毎フレーム 1px 下方向へスクロール (cam_y を 1 減らす)
    lda #1

@do_scroll:
    sta tmp                 ; tmp = 今回の移動ピクセル数 (1 or 8)
    lda cam_y
    lsr
    lsr
    lsr
    sta tmp2                ; tmp2 = 移動前のタイル行 (0..29)

    lda cam_y
    sec
    sbc tmp
    bcs @no_wrap
    ; 0未満になったら 240 を足して上下ネームテーブルを切替
    adc #240
    sta cam_y
    lda cam_nt
    eor #1
    sta cam_nt
    jmp @check_row

@no_wrap:
    sta cam_y

@check_row:
    ; 8px境界 (タイル行) を跨いだら、画面上端に現れる行をバッファに生成
    lda cam_y
    lsr
    lsr
    lsr
    cmp tmp2
    beq @done_scroll

    ; 新しいタイル行 (A = 0..29) をキューに入れる
    jsr queue_scroll_row

@done_scroll:
    rts

; ---- 新しく画面上端に入る1行 (32タイル) を生成し NMI 転送予約 ----
; 入力: A = タイル行 (0..29)
queue_scroll_row:
    sta tmp3                ; tmp3 = タイル行 (0..29)

    ; PPU アドレス計算: Base ($2000 or $2800) + (row * 32)
    lda tmp3
    lsr
    lsr
    lsr                     ; row >> 3 (0..3)
    ora #$20
    ldx cam_nt
    beq :+
    ora #$08                ; cam_nt=1 なら $28xx
:   sta row_ppu_hi

    lda tmp3
    asl
    asl
    asl
    asl
    asl                     ; (row & 7) << 5
    sta row_ppu_lo

    ; まず row_buf[0..31] を星空 (またはワープ光線) で埋める
    ldx #0
@star_loop:
    jsr next_rng
    ldy warp_mode
    bne @warp_tiles

    ; 通常星空
    and #$1F
    cmp #1
    beq @put_dim
    cmp #2
    beq @put_bright
    cmp #3
    bne @put_blank
    lda tmp3
    and #1
    bne @put_blank
    lda #$52                ; きらめき星
    jmp @store_star
@put_dim:
    lda #$50
    jmp @store_star
@put_bright:
    lda #$51
    jmp @store_star
@put_blank:
    lda #$00
    jmp @store_star

@warp_tiles:
    ; ワープ中は高速縦ライン ($53, $54) を高密度に流す！
    and #$07
    cmp #0
    beq @w1
    cmp #1
    beq @w2
    lda #$00
    jmp @store_star
@w1:
    lda #$53
    jmp @store_star
@w2:
    lda #$54

@store_star:
    sta row_buf,x
    inx
    cpx #32
    bne @star_loop

    ; ワープ中またはボス戦中は地形フィーチャーを描かず星空のみ流す
    lda warp_mode
    beq :+
    jmp @finish_queue
:   lda boss_state
    beq :+
    jmp @finish_queue
:
    ; ステージマップ (level_ptr)[meta_idx] の背景フィーチャー (0..5) を合成
    ldy meta_idx
    lda (level_ptr),y
    sta tmp                 ; tmp = feature (0..5)
    bne :+
    jmp @advance_meta       ; 0 = 星空のみ
:

    ; 16x16 メタタイルのベース番号を決定
    ; feat 1 (クレーター) -> $55
    ; feat 2 (岩礁)       -> $59
    ; feat 3 (ガス帯)     -> $5D
    ; feat 4 (要塞壁)     -> $61
    ; feat 5 (軌道リング) -> $65
    ; サブ行 (2..17, 0, 1) のうち:
    ; - 単発オブジェクト (feat 1, 5) は先頭1メタタイル (meta_sub_row == 2, 3) のみ描画
    ; - 連続地形 (feat 2, 3, 4) は前半4メタタイル (meta_sub_row == 2..9) に描画
    lda meta_sub_row
    cmp #2
    bcc @skip_feat
    ldx tmp
    cpx #1
    beq @chk_single_meta
    cpx #5
    beq @chk_single_meta
    cmp #10
    bcs @skip_feat
    jmp @calc_feat_tile
@chk_single_meta:
    cmp #4
    bcc @calc_feat_tile
@skip_feat:
    jmp @advance_meta

@calc_feat_tile:
    ; meta_sub_row の bit0 が 0 なら下段タイル (+2)、1 なら上段タイル (+0)
    and #1
    bne @top_half
    lda feat_base_tile,x
    clc
    adc #2
    jmp @got_feat_tile
@top_half:
    lda feat_base_tile,x
@got_feat_tile:
    sta tmp2                ; tmp2 = 左タイル, tmp2+1 = 右タイル

    ; フィーチャー種類に応じた横配置
    lda tmp
    cmp #1
    beq @place_craters
    cmp #2
    beq @place_ridges
    cmp #3
    beq @place_gas_band
    cmp #4
    beq @place_fortress
    cmp #5
    beq @place_orbital
    jmp @advance_meta

@place_craters:
    ; 左右にクレーターを配置 (列2-3, 列28-29)
    ldx #2
    jsr put_metatile_pair
    ldx #28
    jsr put_metatile_pair
    jmp @advance_meta

@place_ridges:
    ; 両サイドに岩礁帯 (列0-3, 列28-31)
    ldx #0
    jsr put_metatile_pair
    ldx #2
    jsr put_metatile_pair
    ldx #28
    jsr put_metatile_pair
    ldx #30
    jsr put_metatile_pair
    jmp @advance_meta

@place_gas_band:
    ; 木星ガス雲・星雲帯 (列4-9, 列22-27)
    ldx #4
    jsr put_metatile_pair
    ldx #6
    jsr put_metatile_pair
    ldx #24
    jsr put_metatile_pair
    ldx #26
    jsr put_metatile_pair
    jmp @advance_meta

@place_fortress:
    ; モジャ要塞壁 (列0-5, 列26-31)
    ldx #0
    jsr put_metatile_pair
    ldx #2
    jsr put_metatile_pair
    ldx #4
    jsr put_metatile_pair
    ldx #26
    jsr put_metatile_pair
    ldx #28
    jsr put_metatile_pair
    ldx #30
    jsr put_metatile_pair
    jmp @advance_meta

@place_orbital:
    ; 軌道リング・防衛ライン (破線状に横断: 列2-3, 10-11, 20-21, 28-29)
    ldx #2
    jsr put_metatile_pair
    ldx #10
    jsr put_metatile_pair
    ldx #20
    jsr put_metatile_pair
    ldx #28
    jsr put_metatile_pair

@advance_meta:
    ; 18タイル行 (144px = 2.4秒) ごとに meta_idx を +1 進める (64メタ行 = 道中約2分34秒 + ボス戦 = 1ステージ約3分)
    ; meta_sub_row 遷移: 2 -> 3 -> ... -> 17 -> 0 -> 1 -> (次の meta_idx へ進み 2 に戻る)
    lda meta_sub_row
    cmp #1
    beq @next_meta_row
    clc
    adc #1
    cmp #18
    bcc :+
    lda #0
:   sta meta_sub_row
    ; サブ行の途中 (meta_sub_row == 8, 14) でも適度に敵1体補充判定を呼ぶ
    cmp #8
    beq @sub_wave
    cmp #14
    bne @finish_queue
@sub_wave:
    jsr spawn_sub_wave
    jmp @finish_queue

@next_meta_row:
    lda #2
    sta meta_sub_row
    lda meta_idx
    cmp #63
    bcs @at_boss_point
    inc meta_idx
    ; 新しいメタ行に到達したので敵編隊 & 味方支援機スポーン判定を呼ぶ
    jsr spawn_wave_for_meta
    jmp @finish_queue

@at_boss_point:
    ; メタ行60以降でボス未出現ならボス出現！
    lda boss_state
    bne @finish_queue
    jsr spawn_boss

@finish_queue:
    lda #1
    sta row_pending
    rts

; ---- row_buf[X], row_buf[X+1] に tmp2, tmp2+1 を格納 ----
put_metatile_pair:
    lda tmp2
    sta row_buf,x
    clc
    adc #1
    sta row_buf+1,x
    rts

; ---- NMI 中に row_buf[0..31] を PPU ネームテーブルへ高速転送 ----
write_scroll_row:
    bit PPUSTATUS
    lda row_ppu_hi
    sta PPUADDR
    lda row_ppu_lo
    sta PPUADDR
    ldx #0
@wloop:
    lda row_buf,x
    sta PPUDATA
    inx
    cpx #32
    bne @wloop
    lda #0
    sta row_pending
    rts

.segment "RODATA"
feat_base_tile:
    .byte $00, $55, $59, $5D, $61, $65
