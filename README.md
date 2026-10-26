# MOJAxMOJA WARS (ファミコン向け 縦スクロール＆横画面ロボット戦シューティング)

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Web%20Apps%20Online-blue?logo=github)](https://mitsutaka-kusakabe.github.io/nes-shooting/)
[![Play Web Emu](https://img.shields.io/badge/Play-Web%20Emulator-success?logo=nintendo)](https://mitsutaka-kusakabe.github.io/cluade-famicom-emu/)

ファミリーコンピュータ (NES) 向けの 1人プレイ専用シューティングゲームです。  
**縦スクロールの宇宙戦 → 味方支援機との合体 → 横画面でのロボットMS (Mitame Sugoi: 見た目凄い) 1対1ボス戦** という流れで、全4宙域を突破します。  
6502 アセンブラ (`cc65` / `ca65` + `ld65`) を用いてフルスクラッチで実装しています。

> 細かい挙動・数値・内部仕様は **[docs/SPEC.md（詳細仕様書）](docs/SPEC.md)** にまとめています。
> 本リポジトリのWebツールは **[GitHub Pages](https://mitsutaka-kusakabe.github.io/nes-shooting/)** でブラウザから直接ご利用いただけます。

## ▶ プレイ方法 (Webエミュレータ)

**[cluade-famicom-emu (Web版)](https://mitsutaka-kusakabe.github.io/cluade-famicom-emu/)** を開き、画面左上の **「ROMを開く」** から `game.nes` (または `roms/v1.0.0-mojaxmoja-wars.nes`) を選択するとブラウザ上で直接プレイできます。

## スクリーンショット

| タイトル | STAGE 1 道中（第3形態のレーザー照射） |
| :---: | :---: |
| ![タイトル](docs/images/title.png) | ![STAGE 1 道中](docs/images/stage1_gameplay.png) |

| STAGE 1 味方支援機による合体 | WARNING（ボス接近） |
| :---: | :---: |
| ![合体シーン](docs/images/stage1_docking.png) | ![WARNING](docs/images/warning.png) |

**ボス戦（横画面）**

![STAGE 1 中ボス戦](docs/images/boss_stage1_midboss.png)

| 狂乱モード：上段の構え | 狂乱モード：振り下ろし |
| :---: | :---: |
| ![上段の構え](docs/images/boss_saber_jodan.png) | ![振り下ろし](docs/images/boss_saber_slash.png) |

![STAGE 4 ラスボスの荷電粒子ビーム](docs/images/boss_final_beam.png)

## ストーリー

地球が謎の地球外生命体 **「MOJAxMOJA」** の侵略を受けている。  
地球防衛軍は最新鋭コアブロック戦闘機 **「KBX-026 SAMURAI」** を宇宙へ送り出し、これを迎撃する。  
ステージ途中で駆けつける味方支援輸送機から「脚部パーツ」「胸部パーツ」を受け取って合体し、決戦形態**「ホワイトセーバー」**へと変形。各宙域に立ちはだかる量産型ロボットMSと、宿敵・**紅蓮のMS（RIVAL RED MS）**を撃破して地球を救え！

## ゲームの流れ

```text
 タイトル → ブリーフィング → ┌ 縦スクロール道中（前半） ┐
                              │  ・MOJAxMOJA 編隊を迎撃  │
                              │  ・中ボス直前に合体！    │
                              └─────────┬───────────────┘
                                        ▼
                      WARNING → 横画面ボス戦：量産型ロボット（中ボス）
                                        ▼
                          縦スクロール道中（後半）… ラスボス直前にも再合体
                                        ▼
                      WARNING → 横画面ボス戦：宿敵・赤いMS
                                        ▼
                 ボス大破逃走＆自機追撃ワープ → 次の宙域へ（STAGE 4 撃破でエンディング）
```

| ステージ | 宙域 | 中ボス（量産型ロボットMS） | ステージボス |
| :---: | :--- | :--- | :--- |
| **STAGE 1** | **月 (THE MOON)** | 重装兵型 `MOJA-01`（HP 30） | 宿敵・紅蓮のMS（HP 80） |
| **STAGE 2** | **火星 (RED MARS)** | ホバー装甲型 `MOJA-02`（HP 35） | 宿敵・紅蓮のMS（HP 90） |
| **STAGE 3** | **木星 (JUPITER)** | 強襲クロー型 `MOJA-03`（HP 40） | 宿敵・紅蓮のMS（HP 100） |
| **STAGE 4** | **地球付近 (EARTH ORBIT)** | 電熱鞭機 `MOJA-04`（HP 50） | 宿敵・紅蓮のMS 最終決戦（HP 120・荷電粒子ビーム） |

## 自機：KBX-026 SAMURAI（4形態ドッキング合体システム）

ステージ中、味方支援輸送機（キャリア機）が **脚部パーツ（第1陣）** と **胸部パーツ（第2陣）** を各ボス戦の手前で自律的に順次運んできます。  
脚部パーツの取得成否に関わらず胸部パーツが出撃するため、脚部を取り逃がした場合でも胸部を取得して「第2.5形態」に変形可能。ボス戦突入前に十分なドッキング時間が確保されています。パーツを受け取る（接触する）と合体音（「ガッ・シャン！！」）とともに機体が進化します。  
被弾してもすぐには撃墜されず、**装甲（合体パーツ）がパージされて一段階ダウン** します（初期形態で被弾すると1機ミス。自機は3機）。

| 形態 | 見た目 | 合体条件 | Aボタン主兵装 |
| :---: | :---: | :--- | :--- |
| **第1形態**<br>コア戦闘機 | <img src="docs/images/form1.png" width="96"> | 出撃時 / 被弾パージ後 | **通常ミサイル**（単発・連射可） |
| **第2形態**<br>コア＋脚部 | <img src="docs/images/form2.png" width="96"> | 第1形態 ＋ 脚部パーツ | **強化ミサイル**（前方直進・高威力） |
| **第2.5形態**<br>コア＋胸部 | <img src="docs/images/form25.png" width="96"> | 第1形態 ＋ 胸部パーツ | **2WAY 通常ミサイル**（左右2連装） |
| **第3形態**<br>ホワイトセーバー（MS） | <img src="docs/images/form3.png" width="96"> | 脚部 ＋ 胸部（フル合体） | **貫通レーザー**（照射0.3秒／クールタイム0.7秒）＋ **プラズマブレード** |

- **被弾時の変化**：第3形態 → 第2形態 → 第1形態 → 撃墜（1機ミス）。パージ直後は1秒間の無敵。
- **B ボタン：プラズマショックウェーブ**（全形態共通・範囲攻撃）  
  自機周囲に電撃リングが広がり、**画面内の敵弾をすべて消去**しつつ範囲内の敵・ボスにダメージ。約2秒のクールタイム制（画面右下のバッジ `B` で状態確認）。
- **第3形態のプラズマブレード（横画面ボス戦のみ）**  
  ボスが近づくと自動的に斬撃が発動し、敵弾を斬り払います。ボスが **狂乱モード** に入ると、**A ボタンを離している間は上段の構え、押している間は振り下ろし** になります（後述）。

### 合体パーツ・味方支援機

| 名称 | 見た目 | 役割 |
| :--- | :---: | :--- |
| **味方支援輸送機** | <img src="docs/images/ally_carrier.png" width="96"> | 画面上から自機に寄り添って降下し、パーツを投下して帰還する |
| **脚部パーツ (Bパーツ)** | <img src="docs/images/part_legs.png" width="64"> | 取得で第2形態へ（ドッキングボーナス +500点）。第2形態と完全一致するスリム脚設計 |
| **胸部パーツ (Aパーツ)** | <img src="docs/images/part_chest.png" width="64"> | 取得で第2.5形態へ。脚部と揃えば第3形態へ（頭部アンテナ・胸部・青の胴体接続部・両腕ユニット） |

## 敵キャラクタ紹介

### 縦スクロール道中の雑魚：MOJAxMOJA

| 名称 | 見た目 | 動き・攻撃 | 耐久 |
| :--- | :---: | :--- | :---: |
| **MOJA SCOUT**<br>小型偵察機 | <img src="docs/images/enemy_scout.png" width="96"> | ゆっくり直進降下し、途中で自機狙い弾を1発撃つ | 1 |
| **MOJA SWOOP**<br>サイン波機動機 | <img src="docs/images/enemy_swoop.png" width="96"> | 左右に揺れながら降下し、自機狙い弾を撃つ | 1 |
| **MOJA CHARGER**<br>突撃機 | <img src="docs/images/enemy_charger.png" width="96"> | 自機Xへホーミングしながら急降下（体当たり） | 1 |
| **MOJA TURRET**<br>重装砲台 | <img src="docs/images/enemy_turret.png" width="96"> | ゆっくり降下しつつ低頻度で弾を撃つ高耐久型 | 3〜6<br>(面で増加) |

撃破すると **+100点**（ドッキングボーナス・余剰パーツ取得は **+500点**、ボス撃破は **+2000点**）。スコアが **20,000点ごと**（2万点、4万点、6万点…）に達すると自機が **1UP** し、専用ファンファーレ効果音（「ぱぱぱぱーん。」）が鳴り響きます（残機上限9機）。3機編隊で出現し、画面内の敵数・敵弾数はステージが進むほど増えます。

### 横画面ボス：量産型ロボットMS（中ボス）

| 名称 | 見た目 | 登場 | 特徴 |
| :--- | :---: | :---: | :--- |
| **重装兵型 MOJA-01** | <img src="docs/images/boss_trooper.png" width="128"> | STAGE 1 | 丸ドーム頭・モノアイ・動力パイプ・左肩スパイクアーマー・大型マシンガンを備えた量産機。基本パターン（3WAY弾＋自機狙い弾） |
| **ホバー装甲型 MOJA-02** | <img src="docs/images/boss_hover.png" width="128"> | STAGE 2 | 十字モノアイ・胸部拡散ビーム砲・重バズーカ・重装ホバースカート＆ホバー脚部を備えた重装甲機。前後ステップ機動が加わる |
| **強襲クロー型 MOJA-03** | <img src="docs/images/boss_claw.png" width="128"> | STAGE 3 | ドーム頭部ロケット弾孔・V字モノアイ・胸部ダクト＆コクピットハッチ・前方3連アイアンネイル爪・尖った膝アーマーを備えた水陸両用強襲機。護衛突撃機を射出する |
| **電熱鞭機 MOJA-04** | <img src="docs/images/boss_whip.png" width="128"> | STAGE 4 | ブレードアンテナ・両肩湾曲スパイク・黒胸部・両手構えサーベルを備えた白兵戦機。5WAY弾＋プラズマウィップ |

### 宿敵：紅蓮のMS（各ステージのボス）

| 名称 | 見た目 | 特徴 |
| :--- | :---: | :--- |
| **RIVAL RED MS**<br>宿敵・紅蓮のMS | <img src="docs/images/boss_rival.png" width="128"> | 指揮官用ブレードアンテナ・モノアイ・動力パイプ・大型スコープ付きバズーカ水平構え・右肩Lシールド・左肩3連スパイクアーマーを備えた真紅の宿敵機。全ステージのラストに登場。撃破時は機体を表示したまま大破・損害爆発を起こしながら画面右端へ逃走し、自機が右方向へ猛追撃して次宙域へワープ。STAGE 3 以降は自律浮遊砲台（ビット）2基を展開。**STAGE 4 では「即死の荷電粒子ビーム」を約4秒ごとに照射**（予兆のチャージ光球あり／直撃で即死） |

### ボスの狂乱モード（HP 2/5 以下）

ボスは **HPが 2/5 以下** になると武器を構えて突進してくる **狂乱モード** に入ります。

1. **突進** … 自機めがけて猛スピードで接近
2. **追い詰め（0.5秒）** … 自機の目前に張り付いてサーベルを振る
3. **後退（いったん引く）** … 回避の隙を与える
4. **仕切り直し（約0.33秒）** … 反撃のチャンス → 再び突進

ボスは **上段の構え（約0.5秒）⇄ 振り下ろし（0.5秒）** を繰り返します。自機（第3形態）も **A ボタンのリリース＝上段 / 押下中＝振り下ろし** で斬り合います。

## 操作方法

| ボタン | タイトル画面 | プレイ中 | ゲームオーバー / エンディング |
| :--- | :--- | :--- | :--- |
| **十字キー ↑ / ↓** | メニュー選択（`START MISSION` / `STAGE SELECT` / `BOSS BATTLE`） | 自機の8方向移動 | ― |
| **十字キー ← / →** | ステージまたはボスの選択 | 自機の8方向移動 | ― |
| **A ボタン** | ゲーム開始 | 主兵装（ミサイル／レーザー）。狂乱ボス戦の第3形態では上段⇄振り下ろし | タイトルへ戻る |
| **B ボタン** | ステージ／ボス選択を進める | 範囲攻撃（プラズマショックウェーブ） | ― |
| **START** | ゲーム開始 | ポーズ ON / OFF | タイトルへ戻る |
| **SELECT** | メニュー項目の切り替え | ボス戦中：**通常 ⇄ 狂乱モード** を即時切替（テスト用） | ― |

## テスト・デバッグ機能

- **BOSS BATTLE モード**：タイトルで `BOSS BATTLE` を選び、← → で対戦ボス（`1-TRPR` `2-HOVR` `3-CLAW` `4-WHIP` `R-RED`）を選んで START。  
  道中を飛ばして **第3形態・残機5** でボス戦に直行できます。ボスを倒すとタイトルへ戻ります。
- **SELECT**（ボス戦中）：ボスを即座に狂乱モード（HP 12）へ切り替え／通常戦闘へ復帰。サーベル戦のテストに便利です。

## サウンド

APU 4チャンネル（矩形波×2、三角波、ノイズ）＋ DPCM ドラムで、タイトル・道中（2曲）・ボス戦・ステージ移動（『Introduction!!』風 4ch＋DPCM 高速シンセロック＆クリスタルアルペジオアレンジ）・ゲームオーバー（「Tears of Sylph」Ys風アレンジ）の BGM を実装。ミサイル、レーザー、プラズマ、ヒット、ピッチスイープ大爆発音、自機大破撃墜音（急降下クラッシュ＋ロング重爆轟）、ドッキング合体音（「ガッ・シャン！！」）、20,000点1UPファンファーレ（「ぱぱぱぱーん。」）、ワープなどの効果音を搭載しています。

## 必要環境・ビルド方法

ビルドには [cc65](https://cc65.github.io/) ツールチェーン（`ca65` / `ld65`）、`python3`、および `make` を使用します（Windows 環境では WSL 上でのビルドに対応しています）。

```sh
# Ubuntu / WSL の場合
sudo apt install cc65 make python3
```

```sh
python3 tools/gen_chr.py        # CHR-ROM タイルデータ (assets/chr.s) を生成
make                            # game.nes を生成 (iNES 形式, Mapper 0 / NROM-256: PRG 32KB + CHR 8KB)
python3 tools/verify_game.py    # 6502 エミュレータによる全4面通し自動検証テスト
python3 tools/test_boss_mode.py     # ボス戦専用モード & SELECT切替の検証
python3 tools/test_saber_stances.py # サーベル 上段/振り下ろしの検証
python3 tools/render_readme_shots.py # README 用スクリーンショットを docs/images/ に再生成
make clean                      # ビルド成果物を削除
```

生成された `game.nes` を任意の NES エミュレータ（[cluade-famicom-emu](https://mitsutaka-kusakabe.github.io/cluade-famicom-emu/), Mesen, FCEUX 等）で読み込んでプレイできます。

## ディレクトリ構成

```text
├── Makefile              # ca65 / ld65 ビルド定義
├── nes.cfg               # ld65 リンカ設定 (PRG 32KB + CHR 8KB)
├── game.nes              # ビルド済み最新 ROM イメージ
├── roms/                 # バージョン別 ROM アーカイブ (v1.0.0-mojaxmoja-wars.nes)
├── docs/
│   ├── SPEC.md           # 詳細仕様書（挙動・数値・内部仕様）
│   ├── images/           # README / 仕様書用スクリーンショット・キャラクタ画像
│   └── editor/           # Web ステージマップエディタ (index.html / editor.js / style.css)
├── src/
│   ├── main.s            # エントリ・RAM定義・メインループ・NMI ハンドラ
│   ├── header.s          # iNES ヘッダ (Mapper 0 / NROM-256, 水平ミラーリング)
│   ├── ppu.s             # PPU 初期化・ステージ別パレット管理
│   ├── controller.s      # コントローラ入力・エッジ検出・16bit LFSR 乱数
│   ├── scroll.s          # 縦スクロール制御・背景地形ストリーミング描画
│   ├── player.s          # 自機4形態・ミサイル/レーザー/サーベル・B範囲攻撃
│   ├── enemy.s           # 敵編隊スポーン・味方支援機・合体判定・被弾処理
│   ├── boss.s            # 中ボス/紅蓮のMS の AI・狂乱モード・荷電粒子ビーム・撃破演出
│   ├── state.s           # タイトル・ブリーフィング・ワープ・エンディング・ボス戦モード・OAM描画
│   └── sound.s           # APU サウンドエンジン (BGM シーケンサ & SFX)
├── docs/
│   ├── SPEC.md               # 内部技術仕様書 (メモリマップ、APU、数式)
│   ├── editor/               # Web ステージエディタ (index.html / manual.html / editor.js)
│   ├── audio-editor/         # Web 楽曲エディタ (index.html / manual.html / audio-editor.js)
│   └── character-editor/     # Web キャラクターエディタ (index.html / manual.html / character-editor.js)
├── assets/
│   ├── chr.s             # CHR-ROM タイルパターンデータ (tools/gen_chr.py により生成)
│   ├── stages.s          # 全4ステージマップデータ (LVLMAP01 互換)
│   ├── drums.s           # DPCM ドラムサンプルデータ
│   └── music_*.s         # BGM シーケンスデータ (stage / boss / title / gameover / clear)
└── tools/
    ├── gen_chr.py            # スプライト・背景・フォント CHR-ROM 生成スクリプト
    ├── gen_music.py          # BGM データ生成スクリプト
    ├── verify_game.py        # 6502/PPU 全4面通し自動検証テストスイート
    ├── test_boss_mode.py     # ボス戦専用モード検証
    ├── test_saber_stances.py # サーベル構え検証
    ├── render_screens.py     # PPU スクリーンショット出力スクリプト
    ├── render_readme_shots.py # README 用の高解像度スクリーンショット生成
    └── font.s                # ASCII フォント元データ
```

## Web 開発支援ツール (GitHub Pages)

ブラウザ上で直接動作する3つの公式Webツールを **[GitHub Pages](https://mitsutaka-kusakabe.github.io/nes-shooting/)** にて公開しています。  
インストール不要で、PCのWebブラウザからすぐに利用可能です。

🌐 **[Web ツール ポータルを開く](https://mitsutaka-kusakabe.github.io/nes-shooting/)**

1. **[Web キャラクターエディタ](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/character-editor/)** ｜ **[📖 取扱説明書](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/character-editor/manual.html)**
   - **公開URL**: https://mitsutaka-kusakabe.github.io/nes-shooting/docs/character-editor/
   - **画像ドラッグ＆ドロップ ＆ NES自動減色**: 一般のPNGイラストから最適なNES3色＋透明を抽出し、8x8タイルへ自動分解。
   - **スプライト CHR 容量メーター**: 256タイルのハードウェア上限を常時監視し、容量超過を防止。
   - **8スプライト制限警告**: 水平スキャンライン上のスプライト重なり枚数を解析し、チラつき発生ラインを警告。
   - **アニメーションタイムライン**: `idle`, `fly`, `attack`, `damage`, `destroy` のステート管理とオニオンスキン描画。
   - **AABB当たり判定設定**: 食らい判定 (Hurtbox) / 攻撃判定 (Hitbox) をドラッグ＆リサイズで設定（実機コード互換の半幅・半高を出力）。
   - **ca65 デュアル出力**: `character_data.s` (OAMメタスプライト・判定テーブル) と `character_tiles.s` (CHR-ROM 2bpp ビットマップ) を分離出力。
   - **`characters.json` 完全連携**: プロジェクトの保存・再編集、およびステージエディタへのキャラクターグラフィック供給。

2. **[Web ステージエディタ](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/editor/)** ｜ **[📖 取扱説明書](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/editor/manual.html)**
   - **公開URL**: https://mitsutaka-kusakabe.github.io/nes-shooting/docs/editor/
   - 全4面のメタ行地形デザインおよび 3機編隊スポナー間隔、敵弾速度、ボス狂乱突進HP閾値のカスタマイズ。
   - **BGM同期プレビュー**: `nes-audio-player.js` と連携し、BGMを再生しながら自機がスクロールして敵・イベントの到達タイミングを視覚的にプレビュー（中ボス・大ボスの自動曲切り替え対応）。
   - **💾 拡張設定入り .nes の書き出し**: 編集した設定をそのまま埋め込んだ `.nes` ROM のワンクリック書き出し。
   - **📤 ca65 ASM 出力**: 編集したマップおよびパラメータを `assets/stages.s` 用の ca65 アセンブラソースとして出力し、プロジェクトの標準仕様へ恒久適用可能。
   - **👾 キャラインポート**: キャラクターエディタで保存した `characters.json` をロードし、タイムライン上に自機・支援機・敵・ボスをリアルタイムアニメーション表示。
   - **↺ 標準配置に戻す**: いつでも実機ROM本来のデフォルト地形にワンクリック復元。

3. **[Web 楽曲エディタ (NES Audio)](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/audio-editor/)** ｜ **[📖 取扱説明書](https://mitsutaka-kusakabe.github.io/nes-shooting/docs/audio-editor/manual.html)**
   - **公開URL**: https://mitsutaka-kusakabe.github.io/nes-shooting/docs/audio-editor/
   - ファミコン 2A03 APU (Pulse 1, Pulse 2, Triangle, DMCドラム) のリアルタイム Web Audio 合成エディタ。
   - ピアノロール＆16ステップドラムグリッドによる直感的な作曲。
   - `ca65` アセンブラ用 `.byte` 出力/読込、および `.nesbgm.json` プロジェクト保存対応。
   - 組み込みプリセット（Stage 1, Boss, Title, Game Over）の試聴・編集が可能。

## ライセンス

MIT
