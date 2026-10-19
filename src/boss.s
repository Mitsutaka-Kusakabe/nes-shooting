; 横表示ロボット戦: 量産型ロボット中ボス 4機 (MOJA-01..04) & 宿敵・赤いモビルスーツ (RIVAL RED MS) 制御
; [中ボス (boss_type = 0, meta_idx == 32)]:
;   STAGE 1 (月):   ザク型 (MOJA-01, HP 30, PT1 $30-$3B)
;   STAGE 2 (火星): ドム型 (MOJA-02, HP 35, PT1 $3C-$47)
;   STAGE 3 (木星): ズゴック型 (MOJA-03, HP 40, PT1 $C0-$CB)
;   STAGE 4 (地球): グフ型 (MOJA-04, HP 50, PT1 $CC-$D7)
; [宿敵・赤いMS (boss_type = 1, meta_idx == 63)]:
;   全ステージラストに登場 (HP 80 / 90 / 100 / 120, PT1 $58-$63, 専用赤パレット)

.segment "CODE"

boss_init:
    lda #0
    sta boss_state
    sta boss_type
    sta side_mode
    sta cam_x
    sta warning_timer
    sta boss_hp
    sta boss_timer
    sta boss_flash
    rts

; ---- ステージ中盤 (meta_idx == 32) 到達時の「量産型ロボット中ボス (MOJA-01..04)」WARNING警告開始 ----
spawn_midboss:
    lda #0
    sta boss_type           ; 0 = 量産型中ボス (MOJA-01..04)
    jmp start_boss_warning

; ---- ステージ終端 (meta_idx == 63) 到達時の「宿敵・赤いモビルスーツ (RIVAL RED MS)」WARNING警告開始 ----
spawn_boss:
    lda #1
    sta boss_type           ; 1 = 宿敵・赤いモビルスーツ (RIVAL RED MS)

start_boss_warning:
    lda #3                  ; 3 = WARNING警告フェーズ (縦スクロール道中のまま約2秒間大警告！)
    sta boss_state
    lda #0
    sta side_mode           ; 警告中は縦画面道中を維持
    lda #120                ; 120フレーム (約2秒間) しっかり警告表示！
    sta warning_timer
    lda #0
    sta boss_timer
    sta boss_flash

    ; 画面上のザコ敵・敵弾を全消去して警告演出に集中させる
    ldx #MAX_ENEMIES-1
:   sta enemy_flag,x
    dex
    bpl :-
    ldx #MAX_EBULLETS-1
:   sta ebul_flag,x
    dex
    bpl :-

    ; 警告アラート音
    lda #SFX_BOMB
    jsr play_sfx
    lda #4
    sta kill_flash          ; 警告フラッシュ
    rts

; ---- 毎フレームの 中ボス / 宿敵・赤いMS 更新 ----
update_boss:
    lda boss_state
    bne :+
    rts
:   cmp #3
    bne @chk_intro

    ; =========================================================================
    ; ---- boss_state = 3: WARNING 警告フェーズ (縦画面のまま2秒間点滅＆サイレン) ----
    ; =========================================================================
    lda warning_timer
    and #$0F
    bne :+
    lda #SFX_BOMB           ; 周期的に警告サイレン音を鳴らす
    jsr play_sfx
:   lda warning_timer
    and #$1F
    bne :+
    lda #2
    sta kill_flash          ; 周期的に画面をパルス発光
:   dec warning_timer
    bne @warn_ret

    ; WARNING 警告完了！ホワイトアウト発光とともに横画面 (PT1) へ切り替え！
    lda #6
    sta kill_flash          ; 強烈なホワイトアウト発光！
    lda #1
    sta side_mode           ; 横スクロール・PT1サイドビューバンクへ突入！
    sta cam_x
    lda #4                  ; 4 = ボス飛来・登場シーンフェーズ
    sta boss_state
    lda #248                ; 画面右端の外側 (X=248, Y=92) から突入！
    sta boss_x
    lda #92
    sta boss_y
    lda #0
    sta boss_dir
    sta boss_timer

    ; 自機を左側決戦位置 (X=44, Y=100) へ配置
    lda #44
    sta player_x
    lda #100
    sta player_y

    ; HPセット
    ldx current_stage
    lda boss_type
    bne @set_rival_hp
    lda MidBoss_HP_Table,x  ; HP = 30, 35, 40, 50
    sta boss_hp
    jmp @intro_bgm
@set_rival_hp:
    lda Rival_HP_Table,x    ; HP = 80, 90, 100, 120
    sta boss_hp

@intro_bgm:
    lda #TRACK_BOSS
    jsr set_bgm_track
    lda #SFX_WARP           ; ブースト高速突入音
    jsr play_sfx
@warn_ret:
    rts

@chk_intro:
    cmp #4
    bne @chk_dying

    ; =========================================================================
    ; ---- boss_state = 4: ボス飛来・滑り込み登場シーン (右外から高速進入して定位置で停止！) ----
    ; =========================================================================
    lda boss_x
    sec
    sbc #3                  ; 3px/frame で右外から滑り込み突入！
    cmp #176
    bcs :+
    lda #176                ; 決戦定位置 (X=176) にピタッと停止！
    sta boss_x
    lda #1                  ; 1 = 通常戦闘開始！
    sta boss_state
    lda #SFX_HIT            ; 逆噴射ブレーキ停止音
    jsr play_sfx
    rts
:   sta boss_x
    rts

@chk_dying:
    cmp #2
    bne @boss_alive

    ; =========================================================================
    ; ---- boss_state = 2: 撃破爆発 / 撤退前ヒットストップ演出 ----
    ; =========================================================================
    lda boss_timer
    and #7
    bne :+
    lda #2
    sta kill_flash
    lda #SFX_EXPLODE
    jsr play_sfx
:   dec boss_timer
    bne @boss_ret

    ; 爆発シーケンス終了！中ボス (boss_type == 0) か 宿敵・赤いMS (boss_type == 1) かで分岐
    lda #0
    sta boss_state
    lda boss_type
    bne @rival_defeated

    ; ---- 中ボス (MOJA-01..04) 撃破！ホワイトアウトして縦スクロール道中後半へシームレス復帰！ ----
    lda #0
    sta side_mode           ; 縦スクロール道中モード (PT0) へ復帰
    sta cam_x
    lda #4
    sta kill_flash          ; ホワイトアウトフラッシュ ($30)
    lda current_stage
    and #1
    clc
    adc #TRACK_STAGE1
    jsr set_bgm_track
    rts

@rival_defeated:
    ; ---- 宿敵・赤いMS (RIVAL RED MS) 決着！ワープ撤退演出 (Exec_Warp_Escape_Sequence) へ遷移！ ----
    lda #STATE_WARP
    sta game_state
    lda #150                ; 2.5秒のワープ撤退＆次ステージ遷移演出
    sta state_timer
    lda #1
    sta warp_mode
    lda #4
    sta kill_flash          ; ホワイトアウトフラッシュ
    lda #TRACK_CLEAR
    jsr set_bgm_track
    lda #SFX_WARP
    jsr play_sfx
@boss_ret:
    rts

@boss_alive:
    ; =========================================================================
    ; ---- boss_state = 1: 通常戦闘中 (移動速度を適度に落としサーベル戦を重視！) ----
    ; =========================================================================
    lda boss_flash
    beq :+
    dec boss_flash
:   inc boss_timer

    ; サイドビュー上下機動スピード調整:
    ; 中ボス: 2フレームに1px (0.5px/f) どっしり構えて近接サーベルで斬り込みやすい！
    ; 赤いMS: 2フレームに3px (1.5px/f) 以前の3px/fから半減し、俊敏ながらサーベルで十分捉えられる！
    lda #0
    sta tmp                 ; 移動量
    lda boss_type
    bne @rival_spd
    ; 中ボス (boss_type == 0)
    lda frame_count
    and #1
    beq @do_vertical
    inc tmp                 ; 2フレームに1px
    jmp @do_vertical
@rival_spd:
    ; 赤いMS (boss_type == 1)
    lda #1
    sta tmp
    lda frame_count
    and #1
    beq @do_vertical
    inc tmp                 ; 奇数フレーム2px, 偶数フレーム1px (平均1.5px/f)

@do_vertical:
    lda tmp
    beq @stage_special      ; 移動量0なら縦移動スキップ

    lda boss_dir
    bne @move_up
    ; 下移動 (上限 Y=156)
    lda boss_y
    clc
    adc tmp
    cmp #156
    bcc :+
    lda #1
    sta boss_dir
    lda #156
:   sta boss_y
    jmp @stage_special

@move_up:
    lda boss_y
    sec
    sbc tmp
    cmp #36
    bcs :+
    lda #0
    sta boss_dir
    lda #36
:   sta boss_y

@stage_special:
    ; 前後ステップ機動 (X=148〜188) は4フレームに1回のみゆっくり更新
    lda frame_count
    and #3
    bne @boss_attacks

    lda boss_type
    bne @do_x_weave
    lda current_stage
    beq @boss_attacks
@do_x_weave:
    lda boss_timer
    and #$40
    beq @retreat_x
    lda boss_x
    cmp #156
    bcc @boss_attacks
    beq @boss_attacks
    dec boss_x
    jmp @boss_attacks
@retreat_x:
    lda boss_x
    cmp #184
    bcs @boss_attacks
    inc boss_x

@boss_attacks:

    ; 攻撃タイマー判定 (128フレーム周期でゆったり攻撃)
    lda boss_timer
    and #$7F
    cmp #$30
    beq @fire_spread
    cmp #$70
    beq @fire_special
    jmp @check_boss_cols


@fire_spread:
    ; 3WAY ボス弾発射 (4面は5WAY!)
    jsr boss_fire_3way
    lda current_stage
    cmp #3
    bcc @check_boss_cols
    jsr boss_fire_outer_pair
    jmp @check_boss_cols

@fire_special:
    ; ステージ別特殊攻撃:
    ; 1面・2面: 自機狙い単発
    ; 3面・4面: 護衛戦闘機射出
    lda current_stage
    cmp #2
    bcs @summon_moja
    jsr boss_fire_aimed
    jmp @check_boss_cols

@summon_moja:
    lda boss_x
    clc
    adc #16                 ; 48px幅の中央から護衛機(16px)を射出
    sta tmp_bx
    lda boss_y
    clc
    adc #24
    sta tmp_by
    lda #ENEMY_CHARGER
    sta tmp_type
    lda #0
    sta tmp_carrier
    jsr spawn_one_enemy
    jsr boss_fire_aimed

@check_boss_cols:
    ; 自機弾との当たり判定 (48x32 ボス領域: boss_x..boss_x+48, boss_y..boss_y+30)
    ldy #MAX_PBULLETS-1
@bloop:
    lda pbul_flag,y
    beq @bnext

    ; X判定: pbul_x + 4 >= boss_x かつ pbul_x < boss_x + 48
    lda pbul_x,y
    clc
    adc #4
    cmp boss_x
    bcc @bnext
    lda boss_x
    clc
    adc #48
    cmp pbul_x,y
    bcc @bnext

    ; Y判定: pbul_y + 4 >= boss_y かつ pbul_y < boss_y + 28
    lda pbul_y,y
    clc
    adc #4
    cmp boss_y
    bcc @bnext
    lda boss_y
    clc
    adc #28
    cmp pbul_y,y
    bcc @bnext

    ; 命中！自機弾を消去してボスにダメージ (ボスには貫通弾も1ヒットで消えるようにして多段即死を防ぐ)
    lda #0
    sta pbul_flag,y
    lda pbul_dmg,y
    sty tmp_save_y
    jsr damage_boss_by_a
    ldy tmp_save_y
    lda boss_state
    cmp #1
    bne @cols_done

@bnext:
    dey
    bpl @bloop

    ; 自機とボス本体の接触判定 (48x32)
    lda player_x
    clc
    adc #12
    cmp boss_x
    bcc @cols_done
    lda boss_x
    clc
    adc #44
    cmp player_x
    bcc @cols_done

    lda player_y
    clc
    adc #12
    cmp boss_y
    bcc @cols_done
    lda boss_y
    clc
    adc #26
    cmp player_y
    bcc @cols_done

    jsr hit_player

@cols_done:
    rts

; ---- ボスに A ダメージを与える ----
damage_boss_by_a:
    sta tmp
    lda #6
    sta boss_flash
    lda boss_hp
    sec
    sbc tmp
    beq @boss_killed
    bcc @boss_killed
    sta boss_hp
    lda #SFX_HIT
    jsr play_sfx
    rts

@boss_killed:
    lda #0
    sta boss_hp
    lda #2                  ; 撃破爆発ステート
    sta boss_state
    lda #88                 ; 爆発フレーム数
    sta boss_timer
    lda #6
    sta kill_flash
    ; 画面内の敵・敵弾を全消去 (アイテムは残す)
    ldx #MAX_ENEMIES-1
    lda #0
:   sta enemy_flag,x
    dex
    bpl :-
    ldx #MAX_EBULLETS-1
:   sta ebul_flag,x
    dex
    bpl :-
    ; ボス撃破ボーナス +2000点 (100点x20)
    lda #20
    jsr add_score_hundreds
    lda #SFX_EXPLODE
    jsr play_sfx
    rts

; ---- ボス 3WAY 拡散弾発射 (サイドビュー: 左方向へ発射！) ----
boss_fire_3way:
    lda boss_x
    sta tmp_bx
    lda boss_y
    clc
    adc #12
    sta tmp_by
    lda #$0F                ; ボス大型火球タイル
    sta tmp_tile
    lda #<(-2)              ; 左方向へ 2px/フレーム
    sta tmp_vx

    ; 中央水平弾
    lda #0
    sta tmp_vy
    jsr spawn_ebullet
    ; 上斜め弾
    lda #<(-1)
    sta tmp_vy
    jsr spawn_ebullet
    ; 下斜め弾
    lda #1
    sta tmp_vy
    jsr spawn_ebullet
    rts

; ---- ボス 5WAY 外翼弾発射 ----
boss_fire_outer_pair:
    lda boss_x
    sta tmp_bx
    lda boss_y
    clc
    adc #12
    sta tmp_by
    lda #$0F
    sta tmp_tile
    lda #<(-2)
    sta tmp_vx

    lda #<(-2)
    sta tmp_vy
    jsr spawn_ebullet
    lda #2
    sta tmp_vy
    jsr spawn_ebullet
    rts

; ---- ボス 自機狙い弾 (サイドビュー: 左方向＋自機Y狙い) ----
boss_fire_aimed:
    lda boss_x
    sta tmp_bx
    lda boss_y
    clc
    adc #12
    sta tmp_by
    lda #$0F
    sta tmp_tile
    lda #<(-2)              ; 左方向へ 2px/フレーム
    sta tmp_vx
    lda #0
    sta tmp_vy
    lda player_y
    cmp tmp_by
    bcc @aim_u
    lda #1
    sta tmp_vy
    jmp spawn_ebullet
@aim_u:
    lda #<(-1)
    sta tmp_vy
    jmp spawn_ebullet

.segment "RODATA"
stage_boss_hp:
    .byte 20, 28, 36, 44

