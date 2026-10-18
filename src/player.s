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
    sta b_cooldown          ; Bボタン範囲攻撃 READY (0)
    sta b_blast_timer
    sta inv_timer
    jsr clear_pbullets
    rts

; ---- ミス後のリスポーン初期化 (コアファイター形態で出撃) ----
player_respawn:
    lda #120
    sta player_x
    lda #184
    sta player_y
    lda #90                 ; 1.5秒の無敵時間
    sta inv_timer
    lda #0
    sta shot_timer
    sta laser_timer
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
    ; 8方向移動 (2px/フレーム、2フレームに1回+1pxボーナスで軽快移動)
    lda frame_count
    and #1
    clc
    adc #2
    sta tmp                 ; tmp = 移動速度 (2.5px/frame)

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
    ; レーザー照射中 (120フレーム = 2.0秒間): 敵貫通ダメージ処理を実行し、新規発射はロック
    jsr apply_gundam_laser_beam
    dec laser_timer
    bne @chk_fire_b
    ; 2秒間の照射終了！ -> クールタイム 0.5秒 (30フレーム) を開始！
    lda #30
    sta shot_timer
    jmp @chk_fire_b

@chk_fire_a:
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

; ---- Aボタン主兵装発射処理 (4形態別) ----
fire_main_weapon:
    ; 第3形態 (ガンダム) は弾プールを使わず 2秒間貫通レーザー照射を開始する
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
    beq @fire_legs_3way
    cmp #FORM_CHEST
    beq @fire_chest_2way

    ; ---- 初期形態 (0: コアファイター): 通常ミサイル (1WAY) ----
    lda #SFX_SHOT
    jsr play_sfx
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
    lda #$07                ; ミサイルタイル
    sta tmp_tile
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
    jsr spawn_pbullet
    rts

@fire_chest_2way:
    ; ---- 第2.5形態 (2: コアファイター＋胸部): 2WAY ミサイル ----
    lda #SFX_SHOT
    jsr play_sfx

    ; 左ミサイル (player_x)
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
    lda #$07                ; 直進ミサイル
    sta tmp_tile
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
    jsr spawn_pbullet

    ; 右ミサイル (player_x + 8)
    lda player_x
    clc
    adc #8
    sta tmp_bx
    jsr spawn_pbullet
    rts

@fire_legs_3way:
    ; ---- 第2形態 (1: コアファイター＋脚部): 3WAY ミサイル ----
    lda #SFX_SHOT
    jsr play_sfx

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
    lda #1
    sta tmp_dmg
    lda #0
    sta tmp_pierce
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

@fire_gundam_laser:
    ; ---- 第3形態 (3: ガンダム): 自機から画面端まで貫通するレーザーを照射開始 (48フレーム)！ ----
    lda #48                 ; 48フレーム照射 (従来の120fから2/5に短縮し体感2秒に調整)
    sta laser_timer
    lda #SFX_LASER
    jsr play_sfx
    jsr apply_gundam_laser_beam
    rts

; ---- 第3形態の貫通ロングレーザー照射ダメージ処理 (自機から画面上端まで敵を貫通) ----
apply_gundam_laser_beam:
    ; 16フレームごとにビーム持続音を鳴らす
    lda laser_timer
    and #$0F
    bne :+
    lda #SFX_LASER
    jsr play_sfx
:
    ; レーザー中心X = player_x + 11 (右腕ビームライフル銃口ライン)
    ; 1. 画面上端〜自機Yより上にいるすべての通常敵を貫通して撃破！
    ldx #MAX_ENEMIES-1
@l_eloop:
    lda enemy_flag,x
    cmp #1
    bne @l_enext

    ; 自機より上 (enemy_y < player_y) にいるか
    lda enemy_y,x
    cmp player_y
    bcs @l_enext

    ; X座標判定: |(enemy_x + 8) - (player_x + 15)| < 14 -> |enemy_x - (player_x + 7)| < 14
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

    ; レーザー貫通ヒット！雑魚敵を一撃で貫通撃破し、レーザーは止まらず画面端まで進む
    stx tmp_save_x
    lda #3
    jsr damage_enemy_x
    ldx tmp_save_x

@l_enext:
    dex
    bpl @l_eloop

    ; 2. ボスへの貫通レーザー連続照射ダメージ (8フレームに1回 = 1回の照射で最大6ダメージ)
    lda boss_state
    cmp #1
    bne @l_done
    lda laser_timer
    and #$07
    bne @l_done             ; 48(初回), 40, 32, 24, 16, 8 の計6回ヒット

    ; ボス横幅判定: (player_x + 15) が boss_x .. boss_x + 48 の範囲内か
    lda player_x
    clc
    adc #15
    sec
    sbc boss_x
    bcc @l_done
    cmp #50
    bcs @l_done

    lda #1
    jsr damage_boss_by_a
@l_done:
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

; ---- Bボタン範囲攻撃 (PLASMA SHOCKWAVE) の効果適用 ----
apply_b_blast_effect:
    ; 1. 画面内の敵弾 (ebul_flag) をすべて消去！
    ldx #MAX_EBULLETS-1
    lda #0
@clr_eb:
    sta ebul_flag,x
    dex
    bpl @clr_eb

    ; 2. 4フレームごとに範囲内の敵とボスへ電撃ダメージ
    lda b_blast_timer
    and #3
    cmp #3
    bne @blast_done

    ; 雑魚敵への範囲ダメージ (|ex - b_blast_x| < 72 かつ |ey - b_blast_y| < 72)
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

    ; 範囲ヒット！敵HPを 2 減らす
    stx tmp_save_x
    lda #2
    jsr damage_enemy_x
    ldx tmp_save_x

@enext:
    dex
    bpl @eloop

    ; ボスへの範囲ダメージ (距離 88px 以内なら1ヒットあたりダメージ2)
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
    lda #2
    jsr damage_boss_by_a

@blast_done:
    rts

.segment "RODATA"
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
