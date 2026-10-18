; 各面 BOSS 機 (48x32 巨大 MOJAxMOJA フラッグシップ 4種) の制御
; 1面(月): LUNAR BIG-CORE ($30-$3B)
; 2面(火星): CRIMSON VALKYRIE ($3C-$47)
; 3面(木星): JUPITER UFO CARRIER ($C0-$CB)
; 4面(地球付近): EMPEROR DREADNOUGHT ($CC-$D7)

.segment "CODE"

boss_init:
    lda #0
    sta boss_state
    sta boss_hp
    sta boss_timer
    sta boss_flash
    rts

; ---- ステージ終端到達時の BOSS 出現 ----
spawn_boss:
    lda #1
    sta boss_state
    lda #104                ; 48px幅の中央 (256-48)/2 = 104
    sta boss_x
    lda #16
    sta boss_y
    lda #0
    sta boss_dir
    sta boss_timer
    sta boss_flash

    ldx current_stage
    lda stage_boss_hp,x
    sta boss_hp

    ; ボス戦BGMへ切替 & 警告音
    lda #TRACK_BOSS
    jsr set_bgm_track
    lda #SFX_BOMB
    jsr play_sfx
    rts

; ---- 毎フレームの BOSS 更新 ----
update_boss:
    lda boss_state
    bne :+
    rts
:   cmp #2
    bne @boss_alive

    ; ---- boss_state = 2: 撃破大爆発演出 ----
    lda boss_timer
    and #7
    bne :+
    lda #2
    sta kill_flash
    lda #SFX_EXPLODE
    jsr play_sfx
:   dec boss_timer
    bne @boss_ret

    ; ボス完全撃破！ステージクリア＆ワープ演出へ遷移！
    lda #0
    sta boss_state
    lda #STATE_WARP
    sta game_state
    lda #150                ; 2.5秒のワープ演出
    sta state_timer
    lda #1
    sta warp_mode
    lda #TRACK_CLEAR
    jsr set_bgm_track
    lda #SFX_WARP
    jsr play_sfx
@boss_ret:
    rts

@boss_alive:
    lda boss_flash
    beq :+
    dec boss_flash
:   inc boss_timer

    ; 登場降下 (boss_y < 44 の間は下へ降りてくる)
    lda boss_y
    cmp #44
    bcs @patrol
    inc boss_y
    jmp @check_boss_cols

@patrol:
    ; 横移動スピード: 1面・3面は1px (HP減少時2px)、2面・4面は2px
    lda #1
    ldx current_stage
    cpx #1
    beq @fast_move
    cpx #3
    beq @fast_move
    lda boss_hp
    cmp #20
    bcs @got_bspd
@fast_move:
    lda #2
@got_bspd:
    sta tmp                 ; tmp = 横移動速度

    lda boss_dir
    bne @move_left
    ; 右移動 (48px幅のため上限 X=188)
    lda boss_x
    clc
    adc tmp
    cmp #188
    bcc :+
    lda #1
    sta boss_dir
    lda #188
:   sta boss_x
    jmp @stage_special

@move_left:
    lda boss_x
    sec
    sbc tmp
    cmp #20
    bcs :+
    lda #0
    sta boss_dir
    lda #20
:   sta boss_x

@stage_special:
    ; 2面(火星)と4面(地球)のボスは周期的に前進プレッシャー移動 (Y=44〜76)
    lda current_stage
    and #1
    beq @boss_attacks
    lda boss_timer
    and #$40
    beq @retreat_y
    lda boss_y
    cmp #76
    bcs @boss_attacks
    inc boss_y
    jmp @boss_attacks
@retreat_y:
    lda boss_y
    cmp #44
    bcc @boss_attacks
    beq @boss_attacks
    dec boss_y

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

; ---- ボス 3WAY 拡散弾発射 ----
boss_fire_3way:
    lda boss_x
    clc
    adc #20                 ; 48px幅の中央 (24-4=20)
    sta tmp_bx
    lda boss_y
    clc
    adc #26
    sta tmp_by
    lda #$0F                ; ボス大型火球タイル
    sta tmp_tile
    lda #1                  ; 弾速を 1px/フレーム に緩和
    sta tmp_vy

    ; 中央弾
    lda #0
    sta tmp_vx
    jsr spawn_ebullet
    ; 左斜め弾
    lda #<(-1)
    sta tmp_vx
    jsr spawn_ebullet
    ; 右斜め弾
    lda #1
    sta tmp_vx
    jsr spawn_ebullet
    rts

; ---- ボス 5WAY 外翼弾発射 ----
boss_fire_outer_pair:
    lda boss_x
    clc
    adc #20
    sta tmp_bx
    lda boss_y
    clc
    adc #24
    sta tmp_by
    lda #$0F
    sta tmp_tile
    lda #1
    sta tmp_vy

    lda #<(-2)
    sta tmp_vx
    jsr spawn_ebullet
    lda #2
    sta tmp_vx
    jsr spawn_ebullet
    rts

; ---- ボス 自機狙い弾 ----
boss_fire_aimed:
    lda boss_x
    clc
    adc #20
    sta tmp_bx
    lda boss_y
    clc
    adc #26
    sta tmp_by
    lda #$0F
    sta tmp_tile
    lda #1                  ; 弾速を 1px/フレーム に緩和
    sta tmp_vy
    lda #0
    sta tmp_vx
    lda player_x
    cmp tmp_bx
    bcc @aim_l
    lda #1
    sta tmp_vx
    jmp spawn_ebullet
@aim_l:
    lda #<(-1)
    sta tmp_vx
    jmp spawn_ebullet

.segment "RODATA"
stage_boss_hp:
    .byte 20, 28, 36, 44
