; 自機 4形態合体システム
;   0 (FORM_CORE)  : 初期形態 コアファイター (通常ミサイル)
;   1 (FORM_LEGS)  : 第2形態   コアファイター＋脚部 (3WAYミサイル)
;   2 (FORM_CHEST) : 第2.5形態 コアファイター＋胸部 (2WAYミサイル)
;   3 (FORM_GUNDAM): 第3形態   ガンダム (画面端まで貫通レーザー 2秒間照射 ＋ クールタイム0.5秒)
; & Bボタン範囲攻撃(クールタイム制) 制御

MAX_PBULLETS = 8

FORM_CORE   = 0         ; 00b: 初期形態 (コアファイター)
FORM_LEGS   = 1         ; 01b: 第2形態 (コアファイター＋脚部)
FORM_CHEST  = 2         ; 10b: 第2.5形態 (コアファイター＋胸部)
FORM_GUNDAM = 3         ; 11b: 第3形態 (ガンダム フルドッキング)

; ---- 仕様書 セクション5: 武器攻撃力・近接サーベル閾値定数 ----
DMG_MISSILE          = 1
DMG_LASER_TICK       = 2
DMG_SABER            = 8
DMG_PLASMA           = 5
DMG_ENEMY_BULLET     = 1
DMG_ENEMY_HEAVY      = 2
SABER_TRIGGER_DIST_X = 24
SABER_TRIGGER_DIST_Y = 28

.segment "CODE"

; ---- 自機ステータス初期化 (ゲーム開始時: 初期形態コアファイター) ----
player_init:
    lda #120
    sta player_x
    lda #184
    sta player_y
    lda #FORM_CORE
    sta weapon_type         ; 0 = 初期形態(コアファイター)
    lda #1
    sta weapon_level        ; HUD形態表示用 (1=第1形態, 2=第2/2.5形態, 3=第3形態)
    lda #3
    sta rapid_level         ; 初期から快適な連射性能
    lda #0
    sta barrier_hp
    sta shot_timer
    sta laser_timer
    sta saber_timer
    sta b_cooldown          ; Bボタン範囲攻撃 READY (0)
    sta b_blast_timer
    sta inv_timer
    lda #1
    sta difficulty_level    ; デフォルト難易度 = 1 (Normal)
    jsr clear_pbullets
    rts

; ---- ミス後のリスポーン初期化 (コアファイター形態で出撃) ----
player_respawn:
    lda side_mode
    bne @resp_side
    lda #120
    sta player_x
    lda #184
    sta player_y
    jmp @resp_common
@resp_side:
    lda #44
    sta player_x
    lda #100
    sta player_y
@resp_common:
    lda #90                 ; 1.5秒の無敵時間
    sta inv_timer
    lda #0
    sta shot_timer
    sta laser_timer
    sta saber_timer
    sta b_cooldown
    sta b_blast_timer
    lda #FORM_CORE
    sta weapon_type
    lda #1
    sta weapon_level
    jsr clear_pbullets
    rts


clear_pbullets:
    ldx #MAX_PBULLETS-1
    lda #0
@loop:
    sta pbul_flag,x
    dex
    bpl @loop
    rts

; ---- 毎フレームの自機 & 自機弾更新 ----
update_player:
    ; 無敵タイマー減算
    lda inv_timer
    beq :+
    dec inv_timer
:
    ; Bボタン範囲攻撃クールタイム減算
    lda b_cooldown
    beq :+
    dec b_cooldown
:
    ; ビームサーベル3コマアニメーション更新 (saber_timer: 9..7=コマ1抜刀, 6..4=コマ2一閃+弾消し, 3..1=コマ3残心)
    lda saber_timer
    beq :+
    jsr update_beam_saber
    dec saber_timer
:
    ; 8方向移動 (道中: 2.5px/f, 横画面ボス戦: 1.5px/f でサーベルの間合い調整を快適に！)
    lda side_mode
    bne @side_player_spd
    ; 縦画面道中: 2.5px/frame
    lda frame_count
    and #1
    clc
    adc #2
    sta tmp
    jmp @do_player_move
@side_player_spd:
    ; 横画面ボス戦: 1.5px/frame (奇数フレーム1px, 偶数フレーム2px)
    lda frame_count
    and #1
    clc
    adc #1
    sta tmp
@do_player_move:

    lda buttons
    and #BTN_LEFT
    beq @chk_right

    lda player_x
    sec
    sbc tmp
    cmp #16
    bcs :+
    lda #16
:   sta player_x

@chk_right:
    lda buttons
    and #BTN_RIGHT
    beq @chk_up
    lda player_x
    clc
    adc tmp
    cmp #224
    bcc :+
    lda #224
:   sta player_x

@chk_up:
    lda buttons
    and #BTN_UP
    beq @chk_down
    lda player_y
    sec
    sbc tmp
    cmp #28
    bcs :+
    lda #28
:   sta player_y

@chk_down:
    lda buttons
    and #BTN_DOWN
    beq @chk_laser_active
    lda player_y
    clc
    adc tmp
    cmp #196
    bcc :+
    lda #196
:   sta player_y

@chk_laser_active:
    ; 第3形態の貫通レーザー照射中 (laser_timer > 0) かチェック
    lda laser_timer
    beq @chk_fire_a
    lda weapon_type
    cmp #FORM_GUNDAM
    beq @tick_laser
    lda #0
    sta laser_timer
    jmp @chk_fire_a

@tick_laser:
    ; レーザー照射中 (48フレーム): 敵貫通ダメージ処理を実行し、新規発射はロック
    jsr apply_gundam_laser_beam
    dec laser_timer
    bne @chk_fire_b
    ; 照射終了！ -> クールタイム 0.5秒 (30フレーム) を開始！
    lda #30
    sta shot_timer
    jmp @chk_fire_b

@chk_fire_a:
    ; サーベル斬撃中は新規発射しない
    lda saber_timer
    bne @chk_fire_b

    ; 連射クールダウン / レーザー後クールタイム(30f=0.5秒) 減算
    lda shot_timer
    beq @can_shoot_a
    dec shot_timer
    ; 第3形態(ガンダム)のレーザー0.5秒クールタイム中は連打による短縮を禁止（連射不可仕様の厳守）
    lda weapon_type
    cmp #FORM_GUNDAM
    beq @chk_fire_b
    ; ミサイル系形態 (第1・第2・第2.5形態) はボタン単発押し直し (btn_press) で即応性を高める
    lda btn_press
    and #BTN_A
    beq @chk_fire_b
    lda shot_timer
    cmp #3
    bcc @can_shoot_a
    jmp @chk_fire_b

@can_shoot_a:
    lda buttons
    and #BTN_A
    beq @chk_fire_b
    jsr fire_main_weapon

@chk_fire_b:
    ; Bボタン: クールタイム制・範囲攻撃 (PLASMA SHOCKWAVE)
    lda b_cooldown
    bne @update_blast       ; クールタイム中は発射不可
    lda btn_press
    and #BTN_B
    beq @update_blast

    ; 範囲攻撃発動！
    lda #120                ; クールタイム 120フレーム (2秒)
    sta b_cooldown
    lda #24                 ; 衝撃波持続 24フレーム
    sta b_blast_timer
    lda player_x
    clc
    adc #4
    sta b_blast_x
    lda player_y
    clc
    adc #4
    sta b_blast_y
    lda #4
    sta kill_flash          ; 画面フラッシュ
    lda #SFX_BOMB
    jsr play_sfx

@update_blast:
    lda b_blast_timer
    beq @update_bullets
    dec b_blast_timer
    jsr apply_b_blast_effect

@update_bullets:
    jsr update_pbullets
    rts

; ---- Aボタン主兵装発射処理 (近距離オートサーベル分岐 Check_Attack_Type + 4形態別射撃) ----
fire_main_weapon:
    ; 1. 近距離判定 (Check_Attack_Type): 前方 SABER_TRIGGER_DIST 以内に敵またはボスがいればビームサーベル発動！
    jsr check_saber_range
    beq @ranged_attack

    ; ---- 近接ビームサーベル発動！ (3コマアニメ: 9フレーム, 威力 DMG_SABER=8 + 弾消し) ----
    lda #9                  ; コマ1(9..7) -> コマ2(6..4) -> コマ3(3..1)
    sta saber_timer
    lda #12                 ; サーベル振り後のクールダウン
    sta shot_timer
    lda #0
    sta laser_timer         ; レーザー照射中なら中断して斬り込む
    lda #SFX_LASER
    jsr play_sfx
    jsr update_beam_saber
    rts

@ranged_attack:
    ; 2. 遠距離射撃: 第3形態 (ガンダム) は弾プールを使わず 2秒間貫通レーザー照射を開始する
    lda weapon_type
    cmp #FORM_GUNDAM
    bne @check_bullet_pool
    jmp @fire_gundam_laser

@check_bullet_pool:
    ; 現在のアクティブ弾数を数え、上限 (6発) を超えていたら発射しない
    ldy #0
    ldx #MAX_PBULLETS-1
@cnt_loop:
    lda pbul_flag,x
    beq :+
    iny
:   dex
    bpl @cnt_loop

    cpy #6
    bcc :+
    rts
:
    ; ミサイル系の連射間隔タイマーをセット (8フレーム間隔)
    lda #8
    sta shot_timer

    ; 形態 (0=初期コアファイター, 1=第2形態コア+脚部, 2=第2.5形態コア+胸部) で分岐
    lda weapon_type
    cmp #FORM_LEGS
    bne :+
    jmp @fire_legs_3way
:   cmp #FORM_CHEST
    beq @fire_chest_2way

    ; ---- 初期形態 (0: コアファイター): 通常ミサイル (1WAY) ----
    lda #SFX_SHOT
    jsr play_sfx
    lda #$07                ; ミサイルタイル
    sta tmp_tile
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
    lda side_mode
    bne @core_side
    lda player_x
    clc
    adc #4
    sta tmp_bx
    lda player_y
    sec
    sbc #4
    sta tmp_by
    lda #0
    sta tmp_vx
    lda #<(-6)
    sta tmp_vy
    jsr spawn_pbullet
    rts
@core_side:
    lda player_x
    clc
    adc #14
    sta tmp_bx
    lda player_y
    clc
    adc #6
    sta tmp_by
    lda #6
    sta tmp_vx
    lda #0
    sta tmp_vy
    jsr spawn_pbullet
    rts

@fire_chest_2way:
    ; ---- 第2.5形態 (2: コアファイター＋胸部): 2WAY ミサイル ----
    lda #SFX_SHOT
    jsr play_sfx
    lda #$07                ; 直進ミサイル
    sta tmp_tile
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
    lda side_mode
    bne @chest_side

    ; 縦画面: 左右2連ミサイル
    lda player_x
    sta tmp_bx
    lda player_y
    sec
    sbc #4
    sta tmp_by
    lda #0
    sta tmp_vx
    lda #<(-7)
    sta tmp_vy
    jsr spawn_pbullet
    lda player_x
    clc
    adc #8
    sta tmp_bx
    jsr spawn_pbullet
    rts
@chest_side:
    ; 横表示ロボット戦: 上下2連水平ミサイル
    lda player_x
    clc
    adc #16
    sta tmp_bx
    lda player_y
    clc
    adc #2
    sta tmp_by
    lda #7
    sta tmp_vx
    lda #0
    sta tmp_vy
    jsr spawn_pbullet
    lda player_y
    clc
    adc #10
    sta tmp_by
    jsr spawn_pbullet
    rts

@fire_legs_3way:
    ; ---- 第2形態 (1: コアファイター＋脚部): 3WAY ミサイル ----
    lda #SFX_SHOT
    jsr play_sfx
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
    lda side_mode
    bne @legs_side

    ; 中央ミサイル
    lda player_x
    clc
    adc #4
    sta tmp_bx
    lda player_y
    sec
    sbc #6
    sta tmp_by
    lda #0
    sta tmp_vx
    lda #<(-7)
    sta tmp_vy
    lda #$07                ; 直進ミサイル
    sta tmp_tile
    jsr spawn_pbullet

    ; 左斜めミサイル
    lda player_x
    sta tmp_bx
    lda player_y
    sec
    sbc #2
    sta tmp_by
    lda #<(-2)
    sta tmp_vx
    lda #<(-6)
    sta tmp_vy
    lda #$0B                ; 斜めミサイル
    sta tmp_tile
    jsr spawn_pbullet

    ; 右斜めミサイル
    lda player_x
    clc
    adc #8
    sta tmp_bx
    lda #2
    sta tmp_vx
    lda #$0B
    sta tmp_tile
    jsr spawn_pbullet
    rts

@legs_side:
    ; 横表示ロボット戦: 右方向 3WAY ミサイル
    lda player_x
    clc
    adc #16
    sta tmp_bx
    lda player_y
    clc
    adc #6
    sta tmp_by
    lda #7
    sta tmp_vx
    lda #0
    sta tmp_vy
    lda #$07
    sta tmp_tile
    jsr spawn_pbullet
    lda #6
    sta tmp_vx
    lda #<(-2)
    sta tmp_vy
    lda #$0B
    sta tmp_tile
    jsr spawn_pbullet
    lda #2
    sta tmp_vy
    jsr spawn_pbullet
    rts

@fire_gundam_laser:
    ; ---- 第3形態 (3: ガンダム): 自機から画面端まで貫通するレーザーを照射開始 (48フレーム)！ ----
    lda #48                 ; 48フレーム照射 (従来の120fから2/5に短縮し体感2秒に調整)
    sta laser_timer
    lda #SFX_LASER
    jsr play_sfx
    jsr apply_gundam_laser_beam
    rts

; ---- 第3形態の貫通ロングレーザー照射ダメージ処理 (自機から画面端まで敵・ボスを貫通) ----
apply_gundam_laser_beam:
    ; 16フレームごとにビーム持続音を鳴らす
    lda laser_timer
    and #$0F
    bne :+
    lda #SFX_LASER
    jsr play_sfx
:
    ; 1. 縦スクロール道中の通常敵を貫通して撃破！
    ldx #MAX_ENEMIES-1
@l_eloop:
    lda enemy_flag,x
    cmp #1
    bne @l_enext

    lda side_mode
    bne @l_enemy_side

    ; 縦画面: 自機より上 (enemy_y < player_y) かつ |enemy_x - (player_x + 7)| < 14
    lda enemy_y,x
    cmp player_y
    bcs @l_enext
    lda player_x
    clc
    adc #7
    sec
    sbc enemy_x,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #14
    bcs @l_enext
    jmp @l_hit_enemy

@l_enemy_side:
    ; 横表示: 自機より右 (enemy_x >= player_x) かつ |enemy_y - player_y| < 18
    lda enemy_x,x
    cmp player_x
    bcc @l_enext
    lda player_y
    sec
    sbc enemy_y,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #18
    bcs @l_enext

@l_hit_enemy:
    ; レーザー貫通ヒット！雑魚敵を一撃で貫通撃破し、レーザーは止まらず画面端まで進む
    stx tmp_save_x
    lda #DMG_LASER_TICK
    jsr damage_enemy_x
    ldx tmp_save_x

@l_enext:
    dex
    bpl @l_eloop

    ; 2. ボスへの貫通レーザー連続照射ダメージ (8フレームに1回 = DMG_LASER_TICK=2 × 6回 = 計12ダメージ)
    lda boss_state
    cmp #1
    bne @l_done
    lda laser_timer
    and #$07
    bne @l_done             ; 48(初回), 40, 32, 24, 16, 8 の計6回ヒット

    lda side_mode
    bne @l_boss_side

    ; 縦画面ボス判定: (player_x + 15) が boss_x .. boss_x + 48 の範囲内か
    lda player_x
    clc
    adc #15
    sec
    sbc boss_x
    bcc @l_done
    cmp #50
    bcs @l_done
    jmp @l_hit_boss

@l_boss_side:
    ; 横表示ロボット戦ボス判定: 自機ライフルY (player_y + 6) が ボス縦幅 (boss_y - 8 .. boss_y + 32) の範囲内か
    lda player_y
    clc
    adc #14
    sec
    sbc boss_y
    bcc @l_done
    cmp #40
    bcs @l_done

@l_hit_boss:
    lda #DMG_LASER_TICK
    jsr damage_boss_by_a
@l_done:
    rts


; ---- 近接ビームサーベル発動距離チェック (Check_Attack_Type: 横画面・ボス戦 side_mode != 0 のみ発動！) ----
; 出力: A = 1 (横画面ボス戦で前方 SABER_TRIGGER_DIST 以内に敵またはボスあり -> サーベル発動), 0 (遠距離射撃)
check_saber_range:
    lda side_mode
    beq @out_of_range       ; 縦スクロール道中 (side_mode == 0) ではビームサーベルを発動しない！
    lda weapon_type
    cmp #FORM_GUNDAM
    bne @out_of_range       ; 第3形態 (ガンダム) 以外はビームサーベルを持たない！

    ldx #MAX_ENEMIES-1
@s_eloop:
    lda enemy_flag,x
    cmp #1
    bne @s_enext

    ; X距離: |enemy_x - player_x| <= SABER_TRIGGER_DIST_X (24)
    lda player_x
    sec
    sbc enemy_x,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #SABER_TRIGGER_DIST_X+1
    bcs @s_enext

    ; Y距離: 敵が自機の前方近距離 (player_y - 32 <= enemy_y <= player_y + 8) にいるか
    lda player_y
    clc
    adc #8
    sec
    sbc enemy_y,x
    bcc @s_enext
    cmp #SABER_TRIGGER_DIST_Y+12
    bcc @in_range

@s_enext:
    dex
    bpl @s_eloop

    ; ボスとの近接距離判定 (boss_state == 1)
    lda boss_state
    cmp #1
    bne @out_of_range

    ; ボス縦幅 (boss_y - 24 .. boss_y + 55) の範囲内か
    lda player_y
    clc
    adc #24
    sec
    sbc boss_y
    bcc @out_of_range
    cmp #80
    bcs @out_of_range
    ; ボス横幅 (boss_x - 60 .. boss_x + 48) の範囲内か (サイズ2倍リーチ！)
    lda player_x
    clc
    adc #60
    sec
    sbc boss_x
    bcc @out_of_range
    cmp #110
    bcc @in_range

@out_of_range:
    lda #0
    rts
@in_range:
    lda #1
    rts

; ---- 近接ビームサーベル 3コマアニメーション & コマ2 斬撃・弾消し判定 ----
; saber_timer:
;   9..7 = コマ1: 振りかぶり・抜刀 (PT1 $90-$97, 32x16 チャージ光刃)
;   6..4 = コマ2: 振り下ろし一閃 (PT1 $A0-$AB, 32x24 巨大ビーム三日月スラッシュ！威力8＋弾消し)
;   3..1 = コマ3: 斬り抜け・残心 (PT1 $B0-$B7, 32x16 閃光の余波)
update_beam_saber:
    lda saber_timer
    cmp #7
    bcs @saber_early_ret    ; コマ1(9..7) は抜刀モーションのみ
    cmp #4
    bcs @saber_frame2       ; コマ2(6..4) は一閃＋弾消し＋攻撃判定
@saber_early_ret:
    rts

@saber_frame2:
    ; ==== コマ2 (saber_timer == 6..4): 前方斬撃ボックス内の【敵弾消し判定 (前方60px超ワイド！)】 ====
    ldx #MAX_EBULLETS-1
@sb_bloop:
    lda ebul_flag,x
    beq @sb_bnext

    ; 敵弾が自機右側 (player_x - 8 <= ebul_x <= player_x + 64) にあるか
    lda ebul_x,x
    clc
    adc #8
    sec
    sbc player_x
    bcc @sb_bnext
    cmp #72
    bcs @sb_bnext

    ; player_y - 24 <= ebul_y <= player_y + 36
    lda ebul_y,x
    clc
    adc #24
    sec
    sbc player_y
    bcc @sb_bnext
    cmp #60
    bcs @sb_bnext

    ; 巨大ビームサーベルで敵弾を一刀両断・消去！
    lda #0
    sta ebul_flag,x
@sb_bnext:
    dex
    bpl @sb_bloop

    ; ==== コマ2: 前方斬撃ボックス内の【敵機への高威力ダメージ (DMG_SABER = 8)】 ====
    ldx #MAX_ENEMIES-1
@sb_eloop:
    lda enemy_flag,x
    cmp #1
    bne @sb_enext

    lda enemy_x,x
    clc
    adc #8
    sec
    sbc player_x
    bcc @sb_enext
    cmp #72
    bcs @sb_enext

    lda enemy_y,x
    clc
    adc #24
    sec
    sbc player_y
    bcc @sb_enext
    cmp #60
    bcs @sb_enext

    ; サーベル直撃！威力 DMG_SABER (8) で一刀両断！
    stx tmp_save_x
    lda #DMG_SABER
    jsr damage_enemy_x
    ldx tmp_save_x

@sb_enext:
    dex
    bpl @sb_eloop

    ; ==== コマ2初撃フレーム (saber_timer == 6) のみボスへ DMG_SABER (8) ダメージ！ ====
    lda saber_timer
    cmp #6
    bne @saber_done
    lda boss_state
    cmp #1
    bne @saber_done
    lda player_y
    clc
    adc #24
    sec
    sbc boss_y
    bcc @saber_done
    cmp #80
    bcs @saber_done
    lda player_x
    clc
    adc #60
    sec
    sbc boss_x
    bcc @saber_done
    cmp #110
    bcs @saber_done

    lda #DMG_SABER
    jsr damage_boss_by_a



@saber_done:
    rts

; ---- 空きスロットを探して自機弾を1発生成 ----
spawn_pbullet:
    ldx #MAX_PBULLETS-1
@find:
    lda pbul_flag,x
    beq @found
    dex
    bpl @find
    rts
@found:
    lda #1
    sta pbul_flag,x
    lda tmp_bx
    sta pbul_x,x
    lda tmp_by
    sta pbul_y,x
    lda tmp_vx
    sta pbul_vx,x
    lda tmp_vy
    sta pbul_vy,x
    lda tmp_tile
    sta pbul_tile,x
    lda tmp_dmg
    sta pbul_dmg,x
    lda tmp_pierce
    sta pbul_pierce,x
    rts

; ---- 自機弾の移動更新 ----
update_pbullets:
    ldx #MAX_PBULLETS-1
@loop:
    lda pbul_flag,x
    beq @next

    ; X移動
    lda pbul_x,x
    clc
    adc pbul_vx,x
    cmp #8
    bcc @kill
    cmp #248
    bcs @kill
    sta pbul_x,x

    ; Y移動 (上方向へ進むので減算/負数加算)
    lda pbul_y,x
    clc
    adc pbul_vy,x
    cmp #12
    bcc @kill
    cmp #224
    bcs @kill
    sta pbul_y,x
    jmp @next

@kill:
    lda #0
    sta pbul_flag,x
@next:
    dex
    bpl @loop
    rts

; ---- Bボタン範囲攻撃 (PLASMA SHOCKWAVE: 威力 DMG_PLASMA=5 + 敵弾一掃) の効果適用 ----
apply_b_blast_effect:
    ; 1. 画面内の敵弾 (ebul_flag) をすべて消去！
    ldx #MAX_EBULLETS-1
    lda #0
@clr_eb:
    sta ebul_flag,x
    dex
    bpl @clr_eb

    ; 2. 4フレームごとに範囲内の敵とボスへ電撃ダメージ (DMG_PLASMA = 5)
    lda b_blast_timer
    and #3
    cmp #3
    bne @blast_done

    ; 雑魚敵への範囲ダメージ (|ex - b_blast_x| < 76 かつ |ey - b_blast_y| < 76)
    ldx #MAX_ENEMIES-1
@eloop:
    lda enemy_flag,x
    cmp #1
    bne @enext

    lda enemy_x,x
    sec
    sbc b_blast_x
    bcs :+
    eor #$FF
    adc #1
:   cmp #76
    bcs @enext

    lda enemy_y,x
    sec
    sbc b_blast_y
    bcs :+
    eor #$FF
    adc #1
:   cmp #76
    bcs @enext

    ; 範囲ヒット！敵HPを DMG_PLASMA (5) 減らす
    stx tmp_save_x
    lda #DMG_PLASMA
    jsr damage_enemy_x
    ldx tmp_save_x

@enext:
    dex
    bpl @eloop

    ; ボスへの範囲ダメージ (初撃フレーム b_blast_timer == 23 のみ DMG_PLASMA = 5 ダメージ)
    lda b_blast_timer
    cmp #23
    bne @blast_done
    lda boss_state
    cmp #1
    bne @blast_done
    lda boss_y
    clc
    adc #16
    sec
    sbc b_blast_y
    bcs :+
    eor #$FF
    adc #1
:   cmp #92
    bcs @blast_done
    lda #DMG_PLASMA
    jsr damage_boss_by_a

@blast_done:
    rts

.segment "RODATA"
; =========================================================
; 仕様書 セクション5: 難易度調整・計算テーブル (Difficulty & Balance LUTs)
; =========================================================
; 中ボス HP テーブル (Stage 1〜4: ザク型30, ドム型35, ズゴック型40, グフ型50)
MidBoss_HP_Table:
    .byte 30, 35, 40, 50

; ライバル機 (赤いMS) HP テーブル (Stage 1〜4: 80, 90, 100, 120)
Rival_HP_Table:
    .byte 80, 90, 100, 120

; 難易度別 HP補正倍率テーブル (固定小数点 Low/High: Easy=$0080[0.5x], Normal=$0100[1.0x], Hard=$0140[1.25x])
Difficulty_HP_Mult_Lo:
    .byte $80, $00, $40
Difficulty_HP_Mult_Hi:
    .byte $00, $01, $01

; 難易度別 敵弾速度テーブル (Easy=1, Normal=2, Hard=3)
Difficulty_BulletSpeed:
    .byte $01, $02, $03

; 連射レベル (1..5) ごとの画面内最大弾数と発射間隔フレーム
rapid_max_bullets:
    .byte 3, 4, 6, 7, 8
rapid_cooldown_tbl:
    .byte 13, 10, 8, 6, 4

; レーザーレベル (1..5) ごとのパラメータ
laser_vy_tbl:
    .byte <(-8), <(-9), <(-9), <(-10), <(-10)
laser_tile_tbl:
    .byte $08, $08, $09, $09, $09
laser_dmg_tbl:
    .byte 1, 1, 2, 2, 3
laser_pierce_tbl:
    .byte 0, 1, 1, 1, 1
