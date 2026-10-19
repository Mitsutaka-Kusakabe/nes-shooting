; MOJAxMOJA 地球外生命体 (4種) のスポーン・AI・敵弾・当たり判定・パワーアップアイテム制御

MAX_ENEMIES  = 6
MAX_EBULLETS = 6
MAX_ITEMS    = 2

ENEMY_SCOUT   = 0       ; 小型偵察モジャ (直進 + 自機狙い弾)
ENEMY_SWOOP   = 1       ; サインカーブ機動モジャ (左右揺れ降下)
ENEMY_CHARGER = 2       ; 高速突撃モジャ (自機Xホーミング急降下)
ENEMY_TURRET  = 3       ; 重装砲台モジャ (高耐久 + 2連弾)

ITEM_RAPID    = 0       ; [R] 連射強化 (Lv1〜5)
ITEM_LASER    = 1       ; [L] レーザー強化 (Lv1〜5, ワイドと択一)
ITEM_WIDE     = 2       ; [W] ワイド強化 (Lv1〜5, レーザーと択一)
ITEM_BARRIER  = 3       ; [B] バリア強化 (Lv1〜5)

.segment "CODE"

; ---- ステージ開始時の敵・敵弾・アイテム・味方支援機初期化 ----
enemies_init:
    ldx #MAX_ENEMIES-1
    lda #0
    sta ally_state
@clr_e:
    sta enemy_flag,x
    dex
    bpl @clr_e

    ldx #MAX_EBULLETS-1
@clr_eb:
    sta ebul_flag,x
    dex
    bpl @clr_eb

    ldx #MAX_ITEMS-1
@clr_it:
    sta item_flag,x
    dex
    bpl @clr_it
    rts

; ---- ステージの新しいメタ行 (meta_idx) 到達時の編隊 & 味方支援機スポーン ----
spawn_wave_for_meta:
    lda boss_state
    beq :+
    rts
:
    ; ★ ステージの 1/3 地点 (meta_idx == 21 / 64): 味方支援機が「脚部パーツ (0)」を運んで登場！
    ldy meta_idx
    cpy #21
    bne @chk_two_thirds
    lda #0                  ; 0 = 脚部パーツ ($18)
    sta ally_part
    jsr spawn_ally_carrier
    rts

@chk_two_thirds:
    ; ★ ステージの 1/2 地点 (meta_idx == 32 / 64): 横表示・量産型ロボット中ボス (MOJA-01..04) が登場！
    cpy #32
    bne @chk_chest_part
    jsr spawn_midboss
    rts

@chk_chest_part:
    ; ★ ステージの 2/3 地点 (meta_idx == 42 / 64): 味方支援機が「胸部パーツ (1)」を運んで登場！
    cpy #42
    bne @normal_wave
    lda #1                  ; 1 = 胸部パーツ ($19)
    sta ally_part
    jsr spawn_ally_carrier
    rts

@normal_wave:
    ; 味方支援機が登場中 (ally_state != 0) は敵編隊のスポーンを一時停止してドッキング演出を際立たせる
    lda ally_state
    beq :+
    rts
:
    ; 4メタ行ごと、またはフィーチャー5(軌道リング)のとき敵1体出現
    lda (level_ptr),y
    sta tmp                 ; tmp = 地形フィーチャー (0..5)
    cmp #5
    beq do_wave_spawn
    tya
    and #3                  ; 4メタ行に1回スポーン
    beq do_wave_spawn
    rts

; ---- サブ行途中 (meta_sub_row == 8, 14) での通常敵補充スポーン ----
spawn_sub_wave:
    lda boss_state
    bne @no_sub
    lda ally_state
    bne @no_sub
    ldy meta_idx
    tya
    and #1                  ; 偶数メタ行のサブ行で適度に敵1体を補充 (画面内上限 stage_max_enemies 厳守)
    beq do_wave_spawn
@no_sub:
    rts

do_wave_spawn:
    ; 現在の画面内生存敵数をカウントし、ステージ別上限に達していたらスポーンしない
    ldy #0
    ldx #MAX_ENEMIES-1
@cnt_e:
    lda enemy_flag,x
    cmp #1
    bne :+
    iny
:   dex
    bpl @cnt_e

    ldx current_stage
    tya
    cmp stage_max_enemies,x
    bcc :+
    rts
:
    ; 敵を1体だけスポーン (X = 40..199)
    jsr next_rng
    and #$7F
    clc
    adc #40
    sta tmp_bx
    lda #20
    sta tmp_by

    ldy meta_idx
    lda (level_ptr),y
    and #3
    sta tmp_type
    lda #0                  ; 敵機はパーツを持たない (味方支援機のみがパーツを運んでくる)
    sta tmp_carrier
    jsr spawn_one_enemy
    rts

; ---- 味方支援機 (ガンペリー輸送機) の出撃開始 ----
spawn_ally_carrier:
    lda #1                  ; 1 = パーツ懸吊・運搬降下中
    sta ally_state
    lda #120                ; 画面中央上端から登場
    sta ally_x
    lda #16
    sta ally_y
    lda #SFX_POWERUP
    jsr play_sfx
    rts

; ---- 敵1体生成 (tmp_bx, tmp_by, tmp_type, tmp_carrier) ----
spawn_one_enemy:
    ldx #MAX_ENEMIES-1
@find:
    lda enemy_flag,x
    beq @found
    dex
    bpl @find
    rts
@found:
    lda #1                  ; 1 = 生存
    sta enemy_flag,x
    lda tmp_bx
    sta enemy_x,x
    lda tmp_by
    sta enemy_y,x
    lda tmp_type
    sta enemy_type,x
    lda tmp_carrier
    sta enemy_drop,x
    lda #0
    sta enemy_timer,x

    ; 仕様書 4.1: 小型雑魚(type 0..2) = HP 1 (通常ミサイル1発で撃破)、中型遮蔽機(type 3) = HP 3〜6
    lda tmp_type
    cmp #ENEMY_TURRET
    beq @med_hp
    lda #1
    sta enemy_hp,x
    rts
@med_hp:
    lda current_stage
    and #3
    clc
    adc #3                  ; Stage 1..4 で HP 3, 4, 5, 6
    sta enemy_hp,x
    rts

; ---- 毎フレームの敵・敵弾・アイテム更新 ----
update_enemies:
    ldx #MAX_ENEMIES-1
@eloop:
    stx cur_enemy_idx
    lda enemy_flag,x
    bne :+
    jmp @enext
:   cmp #2
    bne @alive

    ; 2 = 爆発エフェクト中
    dec enemy_timer,x
    beq :+
    jmp @enext
:   lda #0
    sta enemy_flag,x
    jmp @enext

@alive:
    inc enemy_timer,x
    lda enemy_type,x
    cmp #ENEMY_SWOOP
    beq @ai_swoop
    cmp #ENEMY_CHARGER
    beq @ai_charger
    cmp #ENEMY_TURRET
    beq @ai_turret

    ; ---- 0: MOJA SCOUT (ゆっくり直進降下 1px/frame + 弾1発) ----
    inc enemy_y,x
    lda enemy_timer,x
    cmp #48
    bne @check_bounds
    jsr enemy_fire_bullet
    jmp @check_bounds

@ai_swoop:
    ; ---- 1: MOJA SWOOP (サインカーブ風の緩やかな左右移動 1px/frame + 降下) ----
    inc enemy_y,x
    lda enemy_timer,x
    and #$20
    beq @swoop_r
    lda enemy_x,x
    sec
    sbc #1
    cmp #16
    bcc @check_bounds
    sta enemy_x,x
    jmp @swoop_shot
@swoop_r:
    lda enemy_x,x
    clc
    adc #1
    cmp #224
    bcs @check_bounds
    sta enemy_x,x
@swoop_shot:
    lda enemy_timer,x
    cmp #60
    bne @check_bounds
    jsr enemy_fire_bullet
    jmp @check_bounds

@ai_charger:
    ; ---- 2: MOJA CHARGER (自機Xへゆっくりホーミングしながら降下 1.5px/frame) ----
    inc enemy_y,x
    lda frame_count
    and #1
    beq @check_bounds
    inc enemy_y,x
    lda enemy_x,x
    cmp player_x
    bcc @chg_r
    beq @check_bounds
    dec enemy_x,x
    jmp @check_bounds
@chg_r:
    inc enemy_x,x
    jmp @check_bounds

@ai_turret:
    ; ---- 3: MOJA TURRET (ゆっくり降下しながら低頻度で弾発射) ----
    lda frame_count
    and #1
    bne :+
    inc enemy_y,x
:   lda enemy_timer,x
    and #$7F
    cmp #$38
    bne @check_bounds
    jsr enemy_fire_bullet

@check_bounds:
    ldx cur_enemy_idx
    lda enemy_y,x
    cmp #220
    bcc @check_cols
    lda #0
    sta enemy_flag,x
    jmp @enext

@check_cols:
    ; 自機弾との当たり判定
    jsr check_pbullets_vs_enemy
    ldx cur_enemy_idx
    lda enemy_flag,x
    cmp #1
    bne @enext

    ; 自機本体 / バリアとの接触判定 (|ex - px| < 12 かつ |ey - py| < 12)
    lda enemy_x,x
    sec
    sbc player_x
    bcs :+
    eor #$FF
    adc #1
:   cmp #13
    bcs @enext

    lda enemy_y,x
    sec
    sbc player_y
    bcs :+
    eor #$FF
    adc #1
:   cmp #13
    bcs @enext

    ; 接触！まず敵機にダメージを与え、自機側も被弾処理を呼ぶ
    lda #3
    jsr damage_enemy_x
    jsr hit_player

@enext:
    ldx cur_enemy_idx
    dex
    bmi :+
    jmp @eloop
:

    ; 敵弾とアイテムの更新
    jsr update_ebullets
    jsr update_items
    rts

; ---- 敵Xに対する自機弾すべてとの衝突チェック ----
check_pbullets_vs_enemy:
    ldy #MAX_PBULLETS-1
@bloop:
    lda pbul_flag,y
    beq @bnext

    ; |pbul_x + 4 - (enemy_x + 8)| < 11
    lda pbul_x,y
    clc
    adc #4
    sta tmp
    lda enemy_x,x
    clc
    adc #8
    sec
    sbc tmp
    bcs :+
    eor #$FF
    adc #1
:   cmp #11
    bcs @bnext

    ; |pbul_y + 4 - (enemy_y + 8)| < 11
    lda pbul_y,y
    clc
    adc #4
    sta tmp
    lda enemy_y,x
    clc
    adc #8
    sec
    sbc tmp
    bcs :+
    eor #$FF
    adc #1
:   cmp #11
    bcs @bnext

    ; 命中！貫通弾 (pbul_pierce != 0) でなければ自機弾を消す
    lda pbul_pierce,y
    bne :+
    lda #0
    sta pbul_flag,y
:
    lda pbul_dmg,y
    sty tmp_save_y
    jsr damage_enemy_x
    ldy tmp_save_y
    ldx cur_enemy_idx
    lda enemy_flag,x
    cmp #1
    bne @done               ; 撃破されたらループ終了

@bnext:
    dey
    bpl @bloop
@done:
    rts

; ---- 敵Xに A ダメージを与える ----
damage_enemy_x:
    sta tmp
    lda enemy_hp,x
    sec
    sbc tmp
    beq @killed
    bcc @killed
    sta enemy_hp,x
    lda #SFX_HIT
    jsr play_sfx
    rts

@killed:
    ; 撃破！爆発状態 (flag=2) に遷移
    lda #2
    sta enemy_flag,x
    lda #16
    sta enemy_timer,x
    lda #SFX_EXPLODE
    jsr play_sfx

    ; スコア加算 (+100点) (※合体パーツは敵からはドロップせず、味方支援機のみが運んでくる)
    lda #1
    jsr add_score_hundreds
    rts

; ---- 味方支援機が投下した合体パーツを生成 (tmp_bx, tmp_by, ally_part) ----
spawn_powerup_item:
    ldx #MAX_ITEMS-1
@find:
    lda item_flag,x
    beq @found
    dex
    bpl @find
    ldx #0                  ; 空きがなければスロット0を上書きして必ず出現させる
@found:
    lda #1
    sta item_flag,x
    lda tmp_bx
    sta item_x,x
    lda tmp_by
    sta item_y,x
    lda ally_part           ; 0 = ステージ1/3 脚部パーツ($18), 1 = ステージ2/3 胸部パーツ($19)
    sta item_type,x
    rts

; ---- 味方支援機の運搬・投下・離脱演出 & 合体パーツの更新 ----
update_items:
    jsr update_ally_carrier

    ldx #MAX_ITEMS-1
@loop:
    lda item_flag,x
    beq @next

    ; 毎フレーム1px降下しつつ、2フレームに1回自機Xへ1px引き寄せられてスムーズにドッキングできるようにする
    inc item_y,x
    lda frame_count
    and #1
    bne @chk_b_it
    lda item_x,x
    cmp player_x
    bcc @it_r
    beq @chk_b_it
    dec item_x,x
    jmp @chk_b_it
@it_r:
    inc item_x,x

@chk_b_it:
    lda item_y,x
    cmp #220
    bcc @chk_pick
    lda #0
    sta item_flag,x
    jmp @next

@chk_pick:
    ; 自機(16px幅)と16x16合体パーツのドッキング判定 (|player_x - item_x| < 16 かつ |player_y - item_y| < 18)
    lda player_x
    sec
    sbc item_x,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #16
    bcs @next

    lda player_y
    sec
    sbc item_y,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #18
    bcs @next

    ; 合体パーツ取得！ドッキング！（効果音「ガッ・シャン！！」＋発光フラッシュ）
    lda #0
    sta item_flag,x
    lda item_type,x
    stx tmp_save_x
    jsr apply_powerup
    lda #2
    sta kill_flash
    lda #SFX_DOCK
    jsr play_sfx
    lda #5
    jsr add_score_hundreds  ; ドッキングボーナス +500点
    ldx tmp_save_x

@next:
    dex
    bpl @loop
    rts

; ---- 味方支援機 (ガンペリー輸送機) のフレーム更新 ----
; ally_state = 1: 画面上部から自機Xへ寄り添いながら Y=76 まで降下し、パーツを切り離す！
; ally_state = 2: パーツ投下後、画面上方へ帰還離脱する！
update_ally_carrier:
    lda ally_state
    beq @ally_ret
    cmp #2
    beq @ally_leave

    ; ---- ally_state == 1: パーツを懸吊して降下中 ----
    inc ally_y
    ; 2フレームに1回、自機Xに向かって横位置を合わせる (味方機が届けに来てくれる演出)
    lda frame_count
    and #1
    bne @chk_drop_y
    lda ally_x
    cmp player_x
    bcc @ally_r
    beq @chk_drop_y
    dec ally_x
    jmp @chk_drop_y
@ally_r:
    inc ally_x

@chk_drop_y:
    ; Y=76 に到達したら16x16合体パーツを切り離して投下し、味方支援機は帰還フェーズ(2)へ！
    lda ally_y
    cmp #76
    bcc @ally_ret
    lda ally_x
    sta tmp_bx
    lda ally_y
    clc
    adc #14
    sta tmp_by
    jsr spawn_powerup_item
    lda #2                  ; 2 = 帰還上昇フェーズ
    sta ally_state
    lda #SFX_POWERUP
    jsr play_sfx
    rts

@ally_leave:
    ; ---- ally_state == 2: パーツを切り離した後、上空へ帰還離脱 ----
    lda ally_y
    cmp #16
    bcc @ally_gone
    sec
    sbc #2
    sta ally_y
@ally_ret:
    rts
@ally_gone:
    lda #0
    sta ally_state
    rts

; ---- 合体パーツ効果適用 (ビットマスク合体方式) ----
; 入力: A = item_type (0 = 脚部パーツ[bit0=1], 1 = 胸部パーツ[bit1=2])
; 仕様:
;   - 初期形態 (00b=0: コアファイター) + 脚部(01b) -> 第2形態   (01b=1: コア＋脚部 / 3WAYミサイル)
;   - 初期形態 (00b=0: コアファイター) + 胸部(10b) -> 第2.5形態 (10b=2: コア＋胸部 / 2WAYミサイル)
;   - 第2形態(01b) + 胸部(10b) または 第2.5形態(10b) + 脚部(01b) -> 第3形態 (11b=3: ガンダム / 2秒貫通レーザー)
apply_powerup:
    and #1
    clc
    adc #1                  ; A = 1 (脚部パーツ: bit0) または 2 (胸部パーツ: bit1)
    ora weapon_type         ; 現在の形態ビットと合成 (0..3)
    cmp weapon_type
    bne @form_changed
    ; すでに装着済みのパーツ (または第3形態=3) なら追加スコアボーナス (+500点)
    lda #5
    jsr add_score_hundreds
    rts

@form_changed:
    sta weapon_type
    cmp #FORM_GUNDAM
    beq @lv3
    lda #2                  ; 第2形態(1) / 第2.5形態(2) は HUD基本レベル '2'
    sta weapon_level
    rts
@lv3:
    lda #3                  ; 第3形態(3: ガンダム) は HUD基本レベル '3'
    sta weapon_level
    rts

; ---- 敵Xから自機狙い弾を1発発射 (支援輸送機は攻撃しない) ----
enemy_fire_bullet:
    ldx cur_enemy_idx
    lda enemy_drop,x
    bne @ret                ; 支援輸送機(carrier)は味方支援機なので弾を撃たない！
    lda enemy_y,x
    cmp #112                ; 画面上半分にいるときだけ発射 (至近距離撃ち防止)
    bcs @ret
    lda enemy_x,x
    clc
    adc #4
    sta tmp_bx
    lda enemy_y,x
    clc
    adc #12
    sta tmp_by

    ; 自機Xとの比較で vx = -1, 0, +1 を決定
    lda #0
    sta tmp_vx
    lda player_x
    sec
    sbc tmp_bx
    bcc @left
    cmp #20
    bcc @set_vy
    lda #1
    sta tmp_vx
    jmp @set_vy
@left:
    cmp #<(-20)
    bcs @set_vy
    lda #<(-1)
    sta tmp_vx
@set_vy:
    lda #1                  ; 弾速はゆっくり (1px/フレーム)
    sta tmp_vy
    lda #$0E
    sta tmp_tile
    jsr spawn_ebullet
@ret:
    rts

; ---- 敵弾1発生成 (tmp_bx, tmp_by, tmp_vx, tmp_vy, tmp_tile) ----
spawn_ebullet:
    ; 画面内の敵弾数を数え、ステージ上限を超えていたら発射しない
    ldx #0
    ldy #MAX_EBULLETS-1
@cnt_eb:
    lda ebul_flag,y
    beq :+
    inx
:   dey
    bpl @cnt_eb

    txa
    ldx current_stage
    cmp stage_max_ebullets,x
    bcc :+
    rts
:
    ldy #MAX_EBULLETS-1
@find:
    lda ebul_flag,y
    beq @found
    dey
    bpl @find
    rts
@found:
    lda #1
    sta ebul_flag,y
    lda tmp_bx
    sta ebul_x,y
    lda tmp_by
    sta ebul_y,y
    lda tmp_vx
    sta ebul_vx,y
    lda tmp_vy
    sta ebul_vy,y
    lda tmp_tile
    sta ebul_tile,y
    rts

; ---- 敵弾の移動 & 自機との当たり判定 ----
update_ebullets:
    ldx #MAX_EBULLETS-1
@loop:
    lda ebul_flag,x
    beq @next

    ; 横方向 (vx) は2フレームに1回だけ移動させて斜め弾の角度と速度を緩やかにする
    lda frame_count
    and #1
    bne @move_y
    lda ebul_x,x
    clc
    adc ebul_vx,x
    cmp #8
    bcc @kill
    cmp #248
    bcs @kill
    sta ebul_x,x

@move_y:
    ; 縦方向 (vy) も基本 1px/フレームでゆっくり降下
    lda ebul_y,x
    clc
    adc ebul_vy,x
    cmp #220
    bcs @kill
    sta ebul_y,x

    ; 自機との当たり判定 (|ebul_x - (player_x+4)| < 6 かつ |ebul_y - (player_y+4)| < 6)
    lda player_x
    clc
    adc #4
    sec
    sbc ebul_x,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #6
    bcs @next

    lda player_y
    clc
    adc #4
    sec
    sbc ebul_y,x
    bcs :+
    eor #$FF
    adc #1
:   cmp #6
    bcs @next

    ; 被弾！敵弾を消して hit_player へ
    lda #0
    sta ebul_flag,x
    stx tmp_save_x
    jsr hit_player
    ldx tmp_save_x
    jmp @next

@kill:
    lda #0
    sta ebul_flag,x
@next:
    dex
    bpl @loop
    rts

; ---- 自機被弾処理 (仕様書 3.1: 2段階アーマーパージ耐久システム) ----
; - 第3形態 (MSフル合体: アーマー2層＋コア): 1被弾で胸部パーツパージ -> 第2形態 (FORM_LEGS) へ！
; - 第2 / 第2.5形態 (半合体: アーマー1層＋コア): 被弾でアーマー破損パージ -> 初期形態 (FORM_CORE) へ！
; - 初期形態 (コアファイター: HP 1): 被弾で1機撃墜 (STATE_DEAD)
hit_player:
    lda inv_timer
    bne @ignore             ; 無敵時間中
    lda warp_mode
    bne @ignore             ; ワープ演出中

    lda weapon_type
    cmp #FORM_GUNDAM
    beq @purge_to_form2
    cmp #FORM_CORE
    bne @purge_to_core
    lda barrier_hp
    bne @purge_to_core

    ; 初期形態(コアファイター)での被弾は 1機ミス (STATE_DEAD)
    lda #STATE_DEAD
    sta game_state
    lda #70
    sta state_timer
    lda #6
    sta kill_flash
    lda #SFX_DEAD
    jsr play_sfx
@ignore:
    rts

@purge_to_form2:
    ; 第3形態(ガンダム) -> 1層目アーマーパージ！第2形態(コア＋脚部)へ移行！
    lda #FORM_LEGS
    sta weapon_type
    lda #2
    sta weapon_level
    jmp @apply_purge_common

@purge_to_core:
    ; 第2/第2.5形態 -> アーマーパージして初期形態(コアファイター)へ緊急脱出！
    lda #FORM_CORE
    sta weapon_type
    lda #1
    sta weapon_level

@apply_purge_common:
    lda #0
    sta barrier_hp
    sta laser_timer
    sta saber_timer
    sta shot_timer
    lda #60                 ; 1秒間の緊急脱出無敵時間
    sta inv_timer
    lda #3
    sta kill_flash
    lda #SFX_EXPLODE
    jsr play_sfx
    rts

.segment "RODATA"
enemy_base_hp:
    .byte 1, 1, 1, 2

stage_max_enemies:
    .byte 2, 3, 3, 4

stage_max_ebullets:
    .byte 2, 3, 4, 5
