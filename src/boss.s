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
    sta boss_beam_timer
    sta boss_saber_stance
    lda #30
    sta boss_saber_timer
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
    sta boss_max_hp
    jmp @intro_bgm
@set_rival_hp:
    lda Rival_HP_Table,x    ; HP = 80, 90, 100, 120
    sta boss_hp
    sta boss_max_hp

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
    lda #0
    sta boss_charge_phase
    sta boss_charge_timer
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

    ; ボス戦専用モード (boss_battle_mode == 1) なら勝利ファンファーレとともにワープ離脱してタイトルへ
    lda boss_battle_mode
    beq :+
    lda #STATE_WARP
    sta game_state
    lda #120                ; 2秒の勝利ワープ演出
    sta state_timer
    lda #1
    sta warp_mode
    lda #4
    sta kill_flash
    lda #TRACK_CLEAR
    jsr set_bgm_track
    lda #SFX_WARP
    jsr play_sfx
    rts
:
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
    ; ---- boss_state = 1: 通常戦闘中 / boss_state = 5: 狂乱突進モード ----
    ; =========================================================================
    lda boss_flash
    beq :+
    dec boss_flash
:   inc boss_timer

    ; SELECTボタンでサーベル突撃モード (boss_state = 5) ⇄ 通常戦闘 (boss_state = 1) を瞬時切替！(テスト支援機能)
    lda btn_press
    and #BTN_SELECT
    beq @chk_state_melee
    lda boss_state
    cmp #5
    beq @toggle_to_normal
    ; 狂乱近接モードへ切り替え
    lda #5
    sta boss_state
    lda #12
    sta boss_hp             ; HPも12にセット
    lda #0
    sta boss_charge_phase
    sta boss_charge_timer
    sta boss_saber_stance
    lda #30
    sta boss_saber_timer
    lda #SFX_WARP
    jsr play_sfx
    jmp @chk_state_melee
@toggle_to_normal:
    lda #1
    sta boss_state
    lda #30
    sta boss_hp
    lda #176
    sta boss_x
    lda #SFX_SHOT
    jsr play_sfx

@chk_state_melee:
    ; boss_state == 5 (狂乱近接突進モード) かチェック
    lda boss_state
    cmp #5
    bne @normal_boss_ai
    jmp update_boss_melee_charge

@normal_boss_ai:
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
    ; STAGE 4 大ボス (赤いMS) の即死メガ粒子ビーム処理チェック
    lda current_stage
    cmp #3
    bne @normal_atk_timing
    lda boss_type
    beq @normal_atk_timing
    jsr update_stage4_boss_beam

@normal_atk_timing:
    lda boss_timer
    and #$7F
    cmp #$30
    beq @fire_spread
    cmp #$70
    beq @fire_special
    jmp check_boss_cols


@fire_spread:
    ; 3WAY ボス弾発射 (4面は5WAY!)
    jsr boss_fire_3way
    lda current_stage
    cmp #3
    bcc @check_outer
    jsr boss_fire_outer_pair
@check_outer:
    jmp check_boss_cols

@fire_special:
    ; ステージ別特殊攻撃:
    ; 1面・2面: 自機狙い単発
    ; 3面・4面: 護衛戦闘機射出
    lda current_stage
    cmp #2
    bcs @summon_moja
    jsr boss_fire_aimed
    jmp check_boss_cols

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
    jmp check_boss_cols

; =========================================================================
; ---- boss_state = 5: 中ボス & 大ボス 弾切れ・狂乱近接戦闘モード (BOSS_STATE_MELEE) ----
; 仕様:
;   1. 横移動速度を30%減速: 中ボス 2px/f、赤いMS 3px/f (平均2.5px/f)
;   2. 自機手前の近接戦闘圏 (X=100〜130) まで突進したあと、その場で上下左右に揺れ動く近接ドッグファイト！
;      - ボスタイマー周期で自機へ踏み込んだり (X=80〜90: サーベル間合い！)、一歩退いたり (X=120〜140)
;      - 画面端へ一方的に突き抜けて消え去るのではなく、近距離で斬り合いを楽しめる攻防に！
;   3. 前方にヒートホーク / 赤ビームサーベル光刃を常時構えて突撃・戦闘！
; =========================================================================
; =========================================================================
; ---- 狂乱近接戦闘AI (boss_state == 5): サーベル突進・0.5秒追い詰め・後退離脱ループ ----
; boss_charge_phase:
;   0 = 前進突進フェーズ (自機へ向かって猛突撃)
;   1 = 追い詰め・近接戦闘フェーズ (30フレーム = 0.5秒制限！超至近距離でサーベル乱舞)
;   2 = いったん引く (後退離脱) フェーズ (Y固定で X=168 まで急速後退、自機に回避隙を与える)
;   3 = 仕切り直し待機フェーズ (20フレーム一時停止し、自機に反撃チャンスを与えて再突進)
; =========================================================================
update_boss_melee_charge:
    ; ---- ボスのサーベル構え切り替え (上段の構え 0.5s ⇄ 振り下ろし 0.5s) ----
    lda boss_saber_timer
    beq @toggle_boss_saber_stance
    dec boss_saber_timer
    jmp @saber_cycle_done

@toggle_boss_saber_stance:
    lda boss_saber_stance
    eor #1
    sta boss_saber_stance
    beq @boss_to_jodan
    ; 振り下ろし一閃へ移行 (30フレーム = 0.5秒)
    lda #SFX_LASER
    jsr play_sfx
    lda #30
    sta boss_saber_timer
    jmp @saber_cycle_done
@boss_to_jodan:
    ; 上段構えへ移行 (24〜36フレームのランダム幅)
    lda frame_count
    and #7
    clc
    adc #26
    sta boss_saber_timer
@saber_cycle_done:

    ; 突進・移動スピード (中ボス: 2px/f, 赤いMS: 平均2.5px/f)
    lda #2
    ldy boss_type
    beq @got_spd
    lda frame_count
    and #1
    beq :+
    lda #3
    jmp @got_spd
:   lda #2
@got_spd:
    sta tmp                 ; 移動量

    lda boss_charge_phase
    beq @phase0_charge
    cmp #1
    beq @phase1_corner
    cmp #2
    beq @phase2_retreat
    jmp @phase3_pause

@phase0_charge:
    ; ---- Phase 0: 自機へ向かって猛突進 ----
    jsr boss_track_player_y ; 自機Yへ上下追従

    ; 前進 (左へ移動)
    lda boss_x
    sec
    sbc tmp
    sta boss_x

    ; 自機手前の近接ライン (player_x + 18) に到達したか？
    lda player_x
    clc
    adc #18
    cmp boss_x
    bcc @p0_done

    ; 到達！追い詰め・至近戦闘フェーズ (Phase 1) へ移行！
    lda #1
    sta boss_charge_phase
    lda #30                 ; ★ 30フレーム = 0.5秒の追い詰め制限時間！
    sta boss_charge_timer
@p0_done:
    jmp check_boss_cols

@phase1_corner:
    ; ---- Phase 1: 追い詰め・至近戦闘 (0.5秒間限定！) ----
    jsr boss_track_player_y ; 上下に逃げる自機に食らいつく！

    ; 自機の目前 (player_x + 12) に張り付いてサーベルの切先を突きつける！
    lda player_x
    clc
    adc #12
    sta boss_x

    ; 0.5秒制限時間カウントダウン
    dec boss_charge_timer
    bne @p1_done

    ; ★ 0.5秒経過！自機を端に追い詰め続けないよう「いったん引く」(Phase 2) へ移行！
    lda #2
    sta boss_charge_phase
    lda #SFX_WARP           ; 離脱バーニア噴射音
    jsr play_sfx
@p1_done:
    jmp check_boss_cols

@phase2_retreat:
    ; ---- Phase 2: いったん引く (Y固定で右へ急速後退、自機に回避スペースを与える) ----
    ; ★ Y軸の追従を行わないことで、自機が上下に逃げて端から脱出するルートを完全開放！
    lda boss_x
    clc
    adc tmp
    adc #1                  ; 3〜4px/f の急加速バックステップ
    cmp #168
    bcc @set_ret_x
    lda #168
    sta boss_x

    ; 後退完了！仕切り直し待機 (Phase 3) へ
    lda #3
    sta boss_charge_phase
    lda #20                 ; 20フレーム (約0.33秒) の射撃・反撃チャンス！
    sta boss_charge_timer
    jmp check_boss_cols

@set_ret_x:
    sta boss_x
    jmp check_boss_cols

@phase3_pause:
    ; ---- Phase 3: 仕切り直し待機 (X=168 で身構え、自機に攻撃チャンスを与えてから再突進) ----
    ; 緩やかな上下浮遊
    lda frame_count
    and #3
    bne @p3_tick
    lda boss_dir
    bne @p3_up
    inc boss_y
    lda boss_y
    cmp #144
    bcc @p3_tick
    lda #1
    sta boss_dir
    jmp @p3_tick
@p3_up:
    dec boss_y
    lda boss_y
    cmp #48
    bcs @p3_tick
    lda #0
    sta boss_dir

@p3_tick:
    dec boss_charge_timer
    bne @p3_done

    ; 待機終了！再び前進突撃 (Phase 0) へ！
    lda #0
    sta boss_charge_phase
    lda #SFX_POWERUP        ; 突進前のブーストチャージ音
    jsr play_sfx
@p3_done:
    jmp check_boss_cols

; ---- 自機Y座標への上下追従サブルーチン (2フレームに1回) ----
boss_track_player_y:
    lda frame_count
    and #1
    bne :+
    rts
:
    lda player_y
    cmp boss_y
    bcc @y_up
    beq @y_ret
    ; 自機が下側にいる -> 下降
    lda boss_y
    clc
    adc #2
    cmp #156
    bcc :+
    lda #156
:   sta boss_y
    rts
@y_up:
    ; 自機が上側にいる -> 上昇
    lda boss_y
    sec
    sbc #2
    cmp #36
    bcs :+
    lda #36
:   sta boss_y
@y_ret:
    rts

; =========================================================================
; ---- STAGE 4 最終決戦 宿敵・赤いMS 専用: 即死メガ粒子ビーム照射AI ----
; boss_beam_timer:
;   0 = 待機中 (boss_timer周期でチャージ開始)
;   45..1 = チャージ予兆 (モノアイ＆胸部点滅、チャージ音)
;   255..220 = 極太メガ粒子ビーム発射中 (自機に当たれば即死！)
; =========================================================================
update_stage4_boss_beam:
    lda boss_beam_timer
    beq @chk_start_beam
    cmp #200
    bcs @tick_beam_firing

    ; ---- チャージ中 (45..1フレーム) ----
    lda boss_beam_timer
    and #7
    bne :+
    lda #SFX_POWERUP        ; チャージエネルギー充填音
    jsr play_sfx
:   dec boss_beam_timer
    bne @beam_ret

    ; チャージ完了！ビーム発射開始 (255からカウントダウン、36フレーム照射)
    lda #255
    sta boss_beam_timer
    lda #SFX_BOMB           ; 轟音ビーム発射
    jsr play_sfx
    lda #6
    sta kill_flash
    jmp @tick_beam_firing

@chk_start_beam:
    ; 256フレーム周期の $80 でチャージ開始 (約4秒に1回発射)
    lda boss_timer
    cmp #$80
    bne @beam_ret
    lda #45                 ; 45フレーム (約0.75秒) のチャージ予兆
    sta boss_beam_timer
    rts

@tick_beam_firing:
    ; ---- ビーム発射中 (255..220): 自機への即死当たり判定 ----
    lda boss_beam_timer
    sec
    sbc #1
    cmp #220
    bcs :+
    lda #0                  ; 発射終了！
:   sta boss_beam_timer

    ; 当たり判定: 自機がビームの射線上にいるか？
    ; ビームYライン: boss_y + 8 .. boss_y + 24
    ; 自機X <= boss_x (ボスの前方全域)
    lda player_x
    cmp boss_x
    bcs @beam_ret

    lda player_y
    clc
    adc #12
    sec
    sbc boss_y
    bcc @beam_ret
    cmp #32
    bcs @beam_ret

    ; メガ粒子ビーム直撃！アーマーに関係なく即死 (STATE_DEAD)！
    lda inv_timer
    bne @beam_ret
    lda #0
    sta weapon_type         ; アーマーを全消滅
    sta barrier_hp
    jsr hit_player

@beam_ret:
    rts

check_boss_cols:
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
    beq :+
    cmp #5
    beq :+
    jmp @cols_done
:
@bnext:
    dey
    bpl @bloop

    ; 自機とボス本体の接触判定 (48x32)
    lda game_state
    bne @cols_done
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

    ; HP 2/5 以下の狂乱突進トリガー判定
    lda boss_state
    cmp #1
    bne @dmg_done

    ; HP <= boss_max_hp * 2 / 5 かチェック
    ; 計算: (boss_max_hp * 2) / 5
    lda boss_max_hp
    asl
    ; 5で割る (簡易除算)
    ldx #0
    sec
@div5:
    sbc #5
    bcc @div_done
    inx
    bne @div5
@div_done:
    ; X = 閾値HP
    cpx boss_hp
    bcc @dmg_done           ; boss_hp > X なら通常戦闘維持

    ; 狂乱突進モード (boss_state = 5) へ移行！
    lda #5
    sta boss_state
    lda #0
    sta boss_charge_phase
    sta boss_charge_timer
    sta boss_saber_stance
    lda #30
    sta boss_saber_timer
    lda #SFX_WARP           ; ブースト急加速音
    jsr play_sfx
    lda #4
    sta kill_flash          ; 警告フラッシュ
@dmg_done:
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
    lda #<(-3)              ; 左方向へ高速 3px/フレーム (弾速底上げ)
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
    lda #<(-3)              ; 左方向へ高速 3px/フレーム
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
    lda #<(-3)              ; 左方向へ高速 3px/フレーム
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

