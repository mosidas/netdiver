# analysis-ability — 実装タスク

> 仕様の詳細は同じディレクトリの仕様文書 spec.md を参照する。
> このファイルには仕様を転記しない。

## File Structure Plan

| ファイルパス | 区分 | 責務 |
| ------------ | ---- | ---- |
| `src/ability/spread_resolver.gd` | 新規 | 8 方向の環から中央と左右の隣の 3 方向を返す static の純粋関数 |
| `src/ability/ability_analysis.gd` | 新規 | 敵の種別から写せるかを返す static の純粋関数(種別で分岐する唯一の場所) |
| `src/ability/ability_slot.gd` | 新規 | 第 3 の武器枠の状態(残り回数・クールダウン・押下の縁)を持つ `RefCounted` |
| `src/ability/analysis_pulse.gd` | 新規 | 撃破位置から標的へ補間で飛び、3 つの経路のいずれかで自身を解放する `Node2D` |
| `src/ability/analysis_pulse.tscn` | 新規 | `AnalysisPulse` + 6×6px の `ColorRect`(原点を矩形の中心)。当たり判定を持たない |
| `src/stage/analysis_dev_stage.gd` | 新規 | 撃破 → 演出 → 到達 → 取得の配線と `died` の再読込(2 つのシーンで共有する) |
| `src/stage/analysis_dev_stage.tscn` | 新規 | 床・壁と `Player` 1・`ShooterEnemy` 1・`ChargerEnemy` 1 を置いた仮ステージ |
| `src/stage/analysis_overwrite_dev_stage.tscn` | 新規 | 床・壁と `Player` 1・`ShooterEnemy` 2 を置いた仮ステージ(上書きの確認用) |
| `src/player/player.gd` | 変更 | 第 3 の枠(`ability_slot`・`grant_ability()`・`ability_fired`)と副武器の占有を足す |
| `src/player/player_stats.gd` | 変更 | 能力の 4 項目を `@export` で足す |
| `docs/testing.md` | 変更 | 「仮ステージを目視で確認する」へ 2 つの仮ステージの起動方法と用途の違いを追記する |
| `tests/ability/spread_resolver_test.gd` | 新規 | 拡散の 3 方向・環の隣接・異常系のテスト |
| `tests/ability/ability_analysis_test.gd` | 新規 | 種別の判定・状態を持たないこと・異常系のテスト |
| `tests/ability/ability_slot_test.gd` | 新規 | 残り回数・クールダウン・押下の縁・空の枠のテスト |
| `tests/ability/analysis_pulse_test.gd` | 新規 | 演出の補間・到達・自己解放の 3 経路・「しないこと」のテスト |
| `tests/ability/analysis_pulse_scene_test.gd` | 新規 | `analysis_pulse.tscn` の構成(寸法・原点・色・当たり判定の不在)のテスト |
| `tests/player/player_ability_stats_test.gd` | 新規 | `PlayerStats` の追加 4 項目の既定値・0 の扱い・射程の非追加のテスト |
| `tests/player/player_ability_test.gd` | 新規 | `grant_ability()` と `ability_slot` の生成のテスト |
| `tests/player/player_takeover_test.gd` | 新規 | 枠の占有と副武器の切り替えのテスト |
| `tests/player/player_spread_test.gd` | 新規 | 拡散弾 3 発の生成・`ability_fired`・異常系のテスト |
| `tests/stage/analysis_dev_stage_test.gd` | 新規 | 仮ステージのハンドラの振る舞い(配線・分岐・異常系)のテスト |
| `tests/stage/analysis_dev_stage_scene_test.gd` | 新規 | 1 つ目のシーンの構成・配置規約・`[connection]` と `binds` のテスト |
| `tests/stage/analysis_overwrite_dev_stage_test.gd` | 新規 | 2 つ目のシーンの構成・配置規約・スクリプトの共有のテスト |

削除対象はない(本単位は既存の置換・廃止を伴わない)。`addons/gdUnit4/` と `reports/` は生成物であり、この計画には載せない。`.gd` を足すと Godot が `.gd.uid` を生成して追跡対象になるため、スクリプトと `.uid` を対にしてステージする(unit #2・#3 の申し送り)。

**変更してよい既存ファイルは、上の表の「変更」3 行(`src/player/player.gd`・`src/player/player_stats.gd`・`docs/testing.md`)と、本単位の workdir(`docs/specs/001-mvp/004-analysis-ability/`)の中だけ**である(spec.md §6.7 が変更対象を 3 つに限っている。workdir はタスク 6.2・6.3 が目視の記録を `## Implementation Notes` へ追記するため対象に含む)。

機械で検査するのはタスク 7.1 であり、手段は git の差分である。**下の表が凍結の正本**であり、7.1 のコマンドが見る範囲(`src` / `tests` / `project.godot` / `docs/specs/001-mvp/001〜003`)はこの表を過不足なく覆う。表に無い追跡済みファイル(`main.tscn`・`Makefile`・`scripts/` 等)は要件 10 と 9.21・9.22 の凍結対象ではないが、本単位は変更する理由を持たない。

| 凍結の対象 | 検査するタスク | 手段 |
| ---- | ---- | ---- |
| `tests/` の既存 25 本(要件 10.8) | 7.1 | `git diff --diff-filter=MDR` が空 |
| `project.godot`(要件 10.2・10.6・9.22) | 7.1 | 同上 |
| `src/` の既存(`player.gd`・`player_stats.gd` を除く。要件 10.1・10.4・10.5・9.21) | 7.1 | 同上 |
| unit #1〜#3 の `spec.md` / `tasks.md`(要件 10.7) | 7.1 | 同上 |
| `fired` のシグナル宣言(要件 10.3。`player.gd` は変更するため差分では固定できない) | 7.1 | 宣言行の完全一致 + 6.7 / 6.8 の振る舞いのテスト |
| `PlayerStats` の既存 14 項目の既定値(要件 8.7。同上) | 7.1 | 既存の `tests/player/player_stats_test.gd` が緑のまま |

差分の基点は unit #3 を統合したコミット `5b4e240` とする(本単位の作業ブランチはここから分岐している)。

### 分解時に埋めた仕様の空白(実装者への申し送り)

spec.md が定めておらず、実装に必要なため本分解で決めた事項。**契約の変更ではなく、契約から一意に決まらない実装の選択**である。

- **テストファイルの分割**: 上の表の 12 本に分ける。`docs/testing.md`「配置と命名」は 1 実装 1 テストを課しておらず、既存の `tests/player/` が `player_move_test.gd`・`player_weapon_test.gd`・`player_health_test.gd`・`player_scene_test.gd` と観点で分ける慣行を持つため、それに揃えた。要件 10.8 が既存のテストの変更を禁じるため、`PlayerStats` の追加 4 項目も既存の `player_stats_test.gd` ではなく新しい `player_ability_stats_test.gd` で扱う。
- **`ability_slot` の生成の場所**: `_ready()` に置かない(要件 7.9 がツリーへ載せない `Player` でも `grant_ability()` を呼べることを求める)。既存の `_ensure_weapons()` は `_primary_weapon != null` で早期 return するため、そこへ素朴に足すと `ability_slot` の生成が隠れる。生成を漏らさない形にすること。
- **`projectile_scene` が未設定のときの `push_error` の回数**: 仕様は定めていない(1 回でも 3 回でもよい)。**テストで回数を固定しない**。
- **拡散弾 3 発の生成の順**: `SpreadResolver.resolve()` の戻り値の並びと同じにする(要件 6.6 が `ability_fired` の `directions` を「生成した 3 発と同じ順」と定めるため、生成順と配列の順を一致させるほかない)。
- **`AnalysisPulse` の `ColorRect` の色の具体値**: 実装者が選ぶ。制約は要件 4.16 だけである。既存の値は `player.tscn`(0.35, 0.78, 0.9, 1)・`charger_enemy.tscn`(0.9, 0.36, 0.31, 1)・`shooter_enemy.tscn`(0.36, 0.55, 0.9, 1)・`projectile.tscn`(1, 0.85, 0.35, 1)・`enemy_projectile.tscn`(1, 0.35, 0.45, 1)・`damage_zone.tscn`(0.85, 0.25, 0.3, 0.55)・**仮ステージの地形は 2 色**(床と壁が (0.24, 0.26, 0.32, 1)、`dev_stage.tscn` の足場 `Step1`〜`Step3` が (0.32, 0.36, 0.44, 1))。**足場の色を取りこぼさない** — 取りこぼすと (0.32, 0.36, 0.44, 1) を選んだときに要件 4.16 に違反したままテストが緑になる。
- **仮ステージの床・壁**: unit #3 の `enemy_dev_stage.tscn` と同じノード構成・同じ色・同じ寸法(床 320×16 を (160, 100)、左壁 16×108 を (8, 38)、右壁 16×108 を (312, 38))を写す。spec.md §8 が「同じ床・壁を使う」と述べており、座標は §8 の表を採る。
- **ハンドラ名**: 実装者が決めてよいが、2 つのシーンで同じ名前を使う(要件 9.7 がスクリプトの共有を課すため、`[connection]` の `method=` も一致する)。
- **`ext_resource` の `uid=`**: 既存の `.tscn` に揃えて書かない(unit #3 の申し送り。Godot エディタで保存すると書き戻されるが、それは記法の揺れであって意味の変更ではない)。

### 全タスク共通の実装の規律(unit #3 からの申し送り)

- **各数値項目は、テストが既定と別の値へ差し替えて渡す。** 既定値のまま渡すと、実装が値を直書きしても緑になる。要件 8.6(直書きの禁止)の担保はここに置き、grep には置かない(grep は整数のリテラルを捕らえられない)。
- **分岐は両側にケースを割り当てる。** 片側だけを観測するテストは、分岐を消す変異を捕らえない。とくに「基底の既定と一致する側だけを観測する」形(unit #3 で 2 度出た欠陥)を作らない。
- **「しないこと」を静的な検査だけで示さない。** ソースの文字列を見る検査は等価な別解(`call_deferred` 化など)を素通りさせる。必ず振る舞い側のケースと対にする。
- **同期で駆動するヘルパを使うタスクは、実フレームで駆動するケースを 1 本は持つ。** ヘルパが呼び出しの順をテスト側に持つと、実装の中の配線を観測できない。
- **拒否する呼び出しには、成功する呼び出しと別の値を渡す。** 同じ値だと「状態を変えない」ことが観測できない。
- **境界を厳密比較するガードには「境界のすぐ外」の値を 1 つ置く。** 置かないと述語がしきい値へ緩む変異を捕らえられない。
- **等価変異をテストで固定しようとしない**(到達しない防御・ガードの順序など)。

## タスク一覧

- [x] 1. (P) 共有の契約の確定(契約先行)

  タスク 2〜5 が共有する契約(3 方向の並び・種別の対応表・能力の 4 項目)を最初に確定させる。3 つのサブタスクは触るファイルが互いに独立で並行できる。

  - [x] 1.1 (P) `SpreadResolver` の 3 方向を実装する
    _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_
    _Boundary: SpreadResolver_
    - 対象ファイル: `src/ability/spread_resolver.gd`(新規), `tests/ability/spread_resolver_test.gd`(新規)
    - 仕様参照: spec.md §5.2、§6.2、§7 Requirement 2
    - 実装の要点(タスク固有):
      - 2.1〜2.6 は **8 方向すべてを回すケース**で示す(1 方向だけだと環の回り方を取り違える実装が素通りする)。環の折り返し(`(1,0)` の手前が `(1,-1)`、`(1,-1)` の先が `(1,0)`)を含む 2 方向は個別のケースにも置き、期待値をテスト側の定数として持つ
      - 2.3 と 2.4 は**回る向きが逆の 2 つの分岐**である。片方だけを見ると、環を逆順に並べる変異が半分のケースで緑になる。両方の期待値を同じケースで対にして比較する
      - 2.7 は異常系の表で回す。表には `Vector2i.ZERO` に加えて **`(2, 0)`・`(0, -2)`・`(1, 2)` のような「8 方向のすぐ外」**を入れる(境界を `abs(x) <= 1` から `abs(x) < 2` へ緩める変異を落とす)。戻り値が空の配列であることも併せて見る
      - 2.8 は同じ引数で 2 回呼んで**戻り値の配列が値として等しく、かつ別のインスタンスであること**を見る(内部の配列をそのまま返して呼び出し側に書き換えられる形を避ける)
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 1.2 (P) `AbilityAnalysis` の種別の判定を実装する
    _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
    _Boundary: AbilityAnalysis_
    - 対象ファイル: `src/ability/ability_analysis.gd`(新規), `tests/ability/ability_analysis_test.gd`(新規)
    - 仕様参照: spec.md §5.3、§6.3、§7 Requirement 3
    - 実装の要点(タスク固有):
      - 3.1(真)と 3.2(偽)は**分岐の両側**であり、個別のケースを割り当てる。`EnemyKind.Kind.CHARGER` は 0、`SHOOTER` は 1 であり、**偽を返す側だけを見ると「常に偽を返す」変異が素通りする**
      - 3.3 の異常系の表には **`-1` と `2`(enum の値域のすぐ外の両側)**を入れる。`push_error` の文言はテスト側に複製を持つ(実装の定数を参照すると自己成就する。unit #3 の申し送り)
      - 3.5「種別による分岐を `AbilityAnalysis` の外に置いてはならない」は静的な検査だけで示さない。`src/player/` と `src/stage/analysis_dev_stage.gd` が `EnemyKind` を参照しないことを確かめる検査に加えて、**振る舞い側の対**として要件 9.12(ハンドラが種別で分岐せず両方の種別で演出を生成する)と 7.7(突進型の到達で枠が変わらない)をタスク 5.1 が持つ。本サブタスクでは静的な検査の側だけを置き、その旨をコメントに残す
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 1.3 (P) `PlayerStats` へ能力の 4 項目を足す
    _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.7_
    _Boundary: PlayerStats_
    - 対象ファイル: `src/player/player_stats.gd`(変更), `tests/player/player_ability_stats_test.gd`(新規)
    - 仕様参照: spec.md §6.5、§7 Requirement 8
    - 実装の要点(タスク固有):
      - 既存 14 項目の行に触れない。追加は 4 行だけであり、要件 8.7 は既存の `tests/player/player_stats_test.gd` が緑のままであることで担保する(このファイルは要件 10.8 により変更しない)
      - 8.4 は **`Player._report_non_positive_stats()` を通した振る舞い**で示す。4 項目それぞれに 0 を入れた `PlayerStats` を `Player` へ渡し、その項目名の `push_error` が出ることを見る(`Enemy` の `ZERO_ALLOWED_STAT_NAMES` に相当する除外がこの 4 項目に無いことの証明)。項目名を固定で列挙する形にしない — 4 項目すべてを個別に検証しても、実装が同じ 4 項目を並べていれば全ケースが緑になる。unit #3 のタスク 2.2 と同じく、`PlayerStats` を継承して `@export var unknown_stat` を持つ内部クラスを 1 つ置き、その項目にも `push_error` が出ることで導出を示す
      - 8.5 は「`ability_` で始まる項目が 4 つだけであること」を `get_property_list()` から数えて示す(名前を固定で列挙すると、5 つ目を足しても落ちない)
      - **このサブタスクは `src/player/player.gd` を変更しない**。既存の `_report_non_positive_stats()` は `get_property_list()` から導いており、項目を足すだけで検査に載る。テストは `player.gd` を読むだけである(タスク 4 と並行しても衝突しない)
    - 検証コマンド: `make test TESTS=res://tests/player`

- [x] 2. (P) `AbilitySlot`(第 3 の枠の状態機械)

  第 3 の枠の残り回数・クールダウン・押下の縁をすべてこのクラスに閉じる。`Player` は戻り値を読むだけになる(spec.md §5.1「ロジックの所在」)。3 つのサブタスクは同じファイルを触るため順に進める。

  - [x] 2.1 生成直後の状態と `grant()` の上書きを実装する
    _Requirements: 1.1, 1.2, 1.3, 1.13, 1.15_
    _Boundary: AbilitySlot_
    - 対象ファイル: `src/ability/ability_slot.gd`(新規), `tests/ability/ability_slot_test.gd`(新規)
    - 仕様参照: spec.md §5.1、§6.1、§7 Requirement 1
    - 実装の要点(タスク固有):
      - `_init(cooldown)` に渡す値は**既定値と離した値**にする(`PlayerStats.ability_cooldown` の 1.5 を使わない)。1 フレームの `delta` の整数倍に取ると、後続の 2.2 でクールダウンの境界をフレーム数で押さえられる
      - 1.3(置き換えであり加算でない)は、**1 回目と 2 回目で別の `uses` を渡す**ことで示す。同じ値を 2 回渡すと、加算する実装と置き換える実装が区別できない。かつ「2 回目のほうが小さい `uses`」を 1 ケース置く(`max()` で合成する変異を落とす)
      - 1.13 の異常系の表には **0 と負の両方**を入れる(unit #2 の申し送り)。かつ**残り回数が正である状態で拒否させ**、`remaining_uses` が直前の値のまま変わらないことを見る(残り回数 0 の状態で拒否させると、状態を 0 へ落とす変異が no-op になって素通りする。unit #3 タスク 5.2 の申し送り)
      - 1.15 は `remaining_uses` を外から書き換えられない設計であることではなく、**`grant()` と `update()` の両方の後で `is_empty == (remaining_uses <= 0)` が保たれること**で示す。`is_empty` を独立の `bool` として持つ変異は、`grant()` の直後だけを見ても落ちない
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 2.2 押下の縁とクールダウンを実装する
    _Requirements: 1.4, 1.5, 1.6, 1.7, 1.8_
    _Boundary: AbilitySlot_
    _Depends: 2.1_
    - 対象ファイル: `src/ability/ability_slot.gd`(変更), `tests/ability/ability_slot_test.gd`(変更)
    - 仕様参照: spec.md §5.1、§7 Requirement 1
    - 実装の要点(タスク固有):
      - `update()` は 3 つの条件(押下の縁・クールダウンが明けている・残り回数が正)の**論理積**である。1.5 は 3 つがすべて真のケース、1.6 は縁でないケース、1.7 はクールダウン中のケース、1.9(タスク 2.3)は残りが 0 のケースであり、**条件ごとに 1 つだけ偽にしたケース**を置くこと(3 つ同時に偽にすると、条件を 1 つ削る変異が落ちない)
      - 1.6 は `held` が真で始まる列(`[true, true, true]`)を与え、**戻り値の列を配列で厳密比較する**(`[真, 偽, 偽]`)。1 本のアサーションに畳まない
      - 1.7 と 1.8 は境界の両側である。クールダウンをちょうど満たすフレーム数と、その 1 つ手前のフレーム数の**2 ケース**を置き、`cooldown` の比較を `>=` から `>` へ変える変異が落ちることを見る。`_init()` に渡す `cooldown` を `delta` の整数倍に取ると、この境界がフレーム数で厳密に決まる
      - 1.4 は「`grant()` の直後の押下の縁」であり、1.7 と**逆向きの分岐**である。`grant()` がクールダウンを明けた状態に置かない変異(初期値 0 のまま)は、このケースだけが落とす
      - `update()` を 1 フレームずつ回すヘルパを持たせ、**戻り値と `remaining_uses` の対を毎フレーム並べて比較する**(別々のアサーションで見ると「真を返すが減らない」「減るが真を返さない」の片方だけを壊す変異が対応の崩れとして現れない。unit #3 タスク 5.1 の申し送り)
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 2.3 空の枠でも押下を記録する振る舞いを実装する
    _Requirements: 1.9, 1.10, 1.11, 1.12, 1.14_
    _Boundary: AbilitySlot_
    _Depends: 2.2_
    - 対象ファイル: `src/ability/ability_slot.gd`(変更), `tests/ability/ability_slot_test.gd`(変更)
    - 仕様参照: spec.md §5.1、§6.1、§7 Requirement 1
    - 実装の要点(タスク固有):
      - **1.10 と 1.11 は本単位で最も欠陥が出やすい 1 フレーム単位の契約である**(上流からの申し送り 2)。どちらも**両側**にケースを割り当てる。
        - 1.10: (a) 空の間 `held = true` を 3 フレーム与えてから `grant()` し、次のフレームも `held = true` のまま → 偽。(b) 同じ列で `held` をいったん偽に落としてから真にする → 真。**(a) だけだと「常に偽を返す」変異が、(b) だけだと「記録しない」変異が素通りする**
        - 1.11: `grant()` を `held = true` の最中に呼ぶ。以降 `held = true` のまま数フレーム進めて**戻り値の列がすべて偽**であること、その後 `held = false` を 1 フレーム挟んで `held = true` にすると**真**になることを、1 つの列の中で対にして見る
      - 1.9 は「残り 0 の間は真を返さず、`remaining_uses` と `is_empty` も変えない」であり、**縁を何度も与えて** `remaining_uses` が負へ進まないこと(1.14)と併せて見る。`remaining_uses -= 1` をガードの外へ出す変異はここで落ちる
      - 1.12 は「残り 1 → 発射 → 0 かつ `is_empty` が真」。**残り 1 の状態を `grant(1)` で作らない**(`grant()` の引数と最終値が一致すると、減算しない変異が素通りする)。`grant(3)` から 2 回撃って残り 1 を作ること
      - 1.14 は「0 未満にしない」。`max(0, ...)` を持たない実装でも 1.9 のガードがあれば満たされるため、**ガードを外した変異が落ちるケース**(残り 0 で縁を 5 フレーム与えて `remaining_uses == 0`)を明示的に置く
      - このサブタスクの完了時点で `AbilitySlot` の 15 基準がすべて緑であること。タスク 4 はこの状態機械を前提に組む
    - 検証コマンド: `make test TESTS=res://tests/ability`

- [x] 3. (P) `AnalysisPulse`(解析の演出)

  撃破位置からプレイヤーへ飛ぶ placeholder。**3 つの経路で自己解放する**契約(到達・標的の消失・事前条件違反)を持つ(上流からの申し送り 1)。

  - [x] 3.1 演出の補間と到達を実装する
    _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.12, 4.13, 8.8, 8.9_
    _Boundary: AnalysisPulse_
    - 対象ファイル: `src/ability/analysis_pulse.gd`(新規), `tests/ability/analysis_pulse_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§6.4、§7 Requirement 4、§7 Requirement 8(8.8・8.9)
    - 実装の要点(タスク固有):
      - 8.8 は `flight_time` が `AnalysisPulse` の `@export` であること(`get_property_list()` の `PROPERTY_USAGE_EDITOR` が立つ)と、**`PlayerStats` 側に `flight_time` が無いこと**の両方で見る。前者だけだと両方に置く実装が素通りする
      - 8.9 は既定値 0.4 を固定する 1 ケースで見る。**それ以外のすべてのケースは `flight_time` を既定と別の値へ差し替える**(既定のままだと、`flight_time` を無視して 0.4 を直書きする実装が緑になる)。差し替える値は `1 / Engine.physics_ticks_per_second` の整数倍に取り、到達フレームを算術で決める
      - 4.2 と 4.3 は**同じ分岐の両側ではなく、片方が他方を含む**。標的を動かさないケースだけでは「発射時の位置を目標に固定する」変異が落ちない。**標的を毎フレーム動かすケースを必ず 1 本置き**、到達点が「到達時点の標的の位置」と一致すること(発射時の位置とは一致しないこと)を両方アサーションする
      - 4.1 は `launch()` の**直後**(物理フレームを 1 つも進めない時点)で位置が `from` であること。`from` を原点にしない(原点だと `_ready()` の時点の値と区別できない。unit #3 タスク 4.1 の申し送りと同型)
      - 4.4 と 4.7 は境界の両側である。到達フレームの 1 つ手前で `arrived` が 0 回、到達フレームで 1 回であることを**発火回数の配列**で見る。到達後にさらにフレームを進めても 1 回のままであること(4.4 の「1 回だけ」)も併せて見る
      - 4.5 は `launch()` に渡した `kind` が `arrived` の引数として返ること。**`EnemyKind.Kind.SHOOTER`(1)と `CHARGER`(0)の両方**を渡すケースを置く(片方だけだと定数を返す変異が素通りする)
      - 4.12 は「位置の更新を `_physics_process` の中だけで行う」。`_process` へ移す変異を落とすため、**`set_physics_process(false)` にしたまま待って位置が動かないこと**を見る。あわせて実フレームで駆動するケースを 1 本持ち、テスト側のヘルパが `_physics_process` を代行していないことを担保する
      - 4.13 は 2 つの演出を同時に飛ばし、**`flight_time` を互いに別の値**にして到達の順と回数が独立であることを見る(同じ値だと共有状態を持つ実装が区別できない)
      - 4.6 の「解放」の観測は `await await_idle_frame()` の後に `is_instance_valid()` を読む形で足りる(unit #3 タスク 2.1 の申し送り)。順序(発火が解放より先)は `arrived` の受け手の中で `is_queued_for_deletion()` が偽であることを控えて固定する
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 3.2 (P) 残る 2 つの自己解放の経路と「しないこと」を実装する
    _Requirements: 4.8, 4.9, 4.11, 4.14_
    _Boundary: AnalysisPulse_
    _Depends: 3.1_
    - 対象ファイル: `src/ability/analysis_pulse.gd`(変更), `tests/ability/analysis_pulse_test.gd`(変更)
    - 仕様参照: spec.md §5.4、§7 Requirement 4
    - 実装の要点(タスク固有):
      - **3 つの経路それぞれに独立のケースを割り当て、1 本のテストが 3 つを同時に通さないこと**(上流からの申し送り 1)。各ケースは `[arrived の発火回数, 解放されたか, push_error の有無]` の 3 つ組を観測する。
        - 経路 A(到達。タスク 3.1 が持つ): `[1, 解放, なし]`
        - 経路 B(標的の消失。4.8): `[0, 解放, なし]` — `push_error` が**出ないこと**を `assert_error(...).is_success()` で見る。標的の消失は戦闘の途中で普通に起きるため報告しない(spec.md §5.4 異常系)
        - 経路 C(事前条件違反。4.9): `[0, 解放, あり]`
      - 経路 C は **`flight_time <= 0` と `to` が無効の 2 通り**に分ける。`flight_time` は 0 と負の両方を表に入れる。どちらのガードを消す変異も、対応する 1 ケースだけが落ちる形にすること
      - 経路 B は「到達より**前**に」標的が無効になる場合である。到達フレームちょうどで無効にするケースと、途中のフレームで無効にするケースの 2 つを置く(前者は「到達の判定と標的の有効性の判定の順序」を固定する)
      - 4.14(`queue_free()` を使い `free()` を使わない)は静的な検査だけで示さない。**3 経路すべてで、解放が同じ物理フレームの中で即座に起きていないこと**(解放の直後に `is_instance_valid()` が真で、`await await_idle_frame()` の後に偽)を見る。`free()` へ変える変異はこの対で落ちる
      - 4.11(`Engine.time_scale` と `SceneTree.paused` を変更しない)も静的な検査だけで示さない。**`Engine.time_scale` を既定と別の値へ設定してから** 3 経路を通し、通した後も同じ値であること・`get_tree().paused` が偽のままであることを見る(既定値のまま見ると、既定値へ代入する変異が素通りする)。テストの後で必ず元へ戻す
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 3.3 (P) `analysis_pulse.tscn` を作る
    _Requirements: 4.10, 4.15, 4.16_
    _Boundary: AnalysisPulse_
    _Depends: 3.1_
    - 対象ファイル: `src/ability/analysis_pulse.tscn`(新規), `tests/ability/analysis_pulse_scene_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§6.7、§7 Requirement 4
    - 実装の要点(タスク固有):
      - シーンの構成を検証するテストは**ツリーへ載せない**(`instantiate()` + `auto_free()` だけで読む。spec.md §7 の「検証の形式」)
      - 4.15 は `ColorRect` が **1 枚だけ**であること(木を再帰で走査して数える)・`size` が (6, 6) であること・`position` が (-3, -3) であること(原点が矩形の中心)。3 つを別のアサーションに分ける
      - 4.16 は**既存の色を .tscn から読んで比較する**(テスト側に値を複製しない)。比較の対象は spec.md §7 4.16 が挙げる 6 つのシーンと**仮ステージの地形**である。地形はタスク 5.2 の完成前でも既存の `src/stage/enemy_dev_stage.tscn` と `src/stage/dev_stage.tscn` から読める(新しい仮ステージは同じ色を写すため)。**`dev_stage.tscn` の足場の色を取りこぼさない**(上の「分解時に埋めた仕様の空白」を参照)。**「6 つのうちどれとも異なる」ではなく「読み出した色の集合に含まれない」形**で書く(将来 placeholder が増えたときに追随する)
      - 4.10(`CollisionObject2D` の子孫を含めない)は木を再帰で走査して 0 件であることを見る。あわせて**振る舞い側の対**として、`Area2D` を 1 つ持つスタブを同じ走査に掛けると 1 件になることを 1 ケース置く(走査そのものが常に 0 を返す変異を落とす)
      - `[ext_resource]` に `uid=` を書かない(既存の `.tscn` と記法を揃える)
    - 検証コマンド: `make test TESTS=res://tests/ability`

- [ ] 4. `Player` の第 3 の枠(占有と拡散弾)

  撃破の配線を除いた「能力を持ってから撃ち切るまで」を縦に貫くスライス。3 つのサブタスクはいずれも `src/player/player.gd` を触るため順に進める。

  - [ ] 4.1 `ability_slot` の生成と `grant_ability()` を実装する
    _Requirements: 7.1, 7.2, 7.3, 7.5, 7.9, 7.10, 8.6_
    _Boundary: Player_
    _Depends: 1.3, 2.3_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_ability_test.gd`(新規)
    - 仕様参照: spec.md §5.5、§7 Requirement 7、§7 Requirement 8(8.6)
    - 実装の要点(タスク固有):
      - テストの `PlayerStats` は **4 項目すべてを既定と別の値**へ差し替える(`ability_uses` を 3 以外、`ability_cooldown` を 1.5 以外)。既定のままだと 7.1・7.10 が実装の直書きで緑になる(要件 8.6 の担保)
      - 7.9 は **`instantiate()` した `Player` をツリーへ載せずに** `grant_ability()` を呼び、`ability_slot` が null にならず `remaining_uses` が満ちることで示す。`_ready()` に生成を置く変異はこのケースだけが落とす
      - 7.2(置き換えであり加算でない)は、**1 回目と 2 回目の間に 1 回撃たせて残り回数を減らしてから** 2 回目を呼ぶ(減らさずに 2 回呼ぶと、加算する実装でも上限で頭打ちになって区別できない場合がある)
      - 7.3(直後にクールダウンが明けている)は、**1 回撃ってクールダウン中にしてから** `grant_ability()` を呼び、次のフレームの押下の縁で撃てることで示す。空の状態から `grant_ability()` を呼ぶケースだけだと、クールダウンを明けない変異が「そもそも初期値が明けている」ために素通りする
      - 7.10 は `AbilitySlot` の `cooldown` に `stats.ability_cooldown` が渡ること。**`ability_cooldown` を `secondary_cooldown` や `primary_interval` と別の値**に取り、他の項目を渡す変異が落ちる形にする
      - 7.5(0 になったときに初期状態と区別しない)は、使い切った枠と生成直後の枠で `remaining_uses` と `is_empty` が一致することを見る
      - `ability_slot` の生成の場所は上の「分解時に埋めた仕様の空白」を参照する。**`_ready()` を通らない経路で null にならない**ことがこのサブタスクの核である
      - `fired` のシグナル宣言(要件 10.3)と既存 14 項目に触れない
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 4.2 枠の占有と副武器の切り替えを実装する
    _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11, 10.9_
    _Boundary: Player_
    _Depends: 4.1_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_takeover_test.gd`(新規)
    - 仕様参照: spec.md §5.5、§8、§7 Requirement 5、§7 Requirement 10(10.9)
    - 実装の要点(タスク固有):
      - **`_secondary_weapon` は非公開のままにする**(spec.md §5.5 が追加する観測点は `ability_slot` だけであり、公開点を増やすと unit #2 の契約の外へ出る)。したがって「副武器へ何を渡したか」は `fired(direction, true)` の発火**フレーム**でしか観測できない。以下の 4 本の 1 フレーム単位の契約は、そのフレームのずれを検出できる形で組むこと(上流からの申し送り 2)。
      - **5.1 / 5.2(占有の判定は `ability_slot.update()` を呼ぶ直前の `is_empty` で行う)は両側**:
        - 空のフレーム(5.1): `secondary_held` を保持し続けて充電が満ち、離したフレームで `fired(_, true)` が 1 回出る
        - 占有中のフレーム(5.2): 同じ入力の列を与えても `fired(_, true)` が出ない(5.8)
      - **5.11(最後の 1 回を撃ったフレームで副武器へ偽を渡す)の観測手順**: テストの `secondary_charge_time` を **1 フレームの `delta` ちょうど**に取る。最後の 1 回が出るフレーム N で `secondary_held = true` のまま次のフレーム N+1 で `false` にすると、
        - 正しい実装: フレーム N で副武器は偽を受け取るため充電が始まらず、N+1 でも `fired(_, true)` は出ない
        - 欠陥のある実装(`update()` の**後**の `is_empty` で判定する): フレーム N で副武器が真を受け取り充電が 1.0 に達し、N+1 の解放で `fired(_, true)` が 1 回出る
        この差を「N+1 での `fired(_, true)` の回数が 0 であること」で固定する。**1 つの押下が第 3 の枠と副武器の両方を動かす**欠陥はこのケースだけが落とす
      - **5.3(空のフレームも `ability_slot.update()` を呼ぶ)** は `ability_slot`(spec.md §5.5 が公開する観測点)を直接読んで示す。空の枠のまま `secondary_held = true` を数フレーム与えてから `grant_ability()` を呼び、`secondary_held` を真のまま数フレーム進める → `player.ability_slot.remaining_uses` が付与した値のまま減らないこと(要件 1.11 が `Player` の経路でも成立すること)。空のフレームで `update()` を呼ばない変異は、押しっぱなしのボタンが縁と誤認されて残り回数が減るためここで落ちる。**拡散弾の発射で観測しない** — 弾の生成はタスク 4.3 で入るため、4.2 の時点では恒真になる
      - **5.4** は占有が終わった次のフレーム以降で 5.1 のケースが再び成立することを見る(1 本の列の中で「空 → 占有 → 空」を通す)
      - **5.5 と 5.6 は分岐の両側**である。占有が始まるフレームの直前に `charge_ratio` を 1.0 に到達させたケース(→ `fired(_, true)` が 1 回)と、満たないケース(→ 0 回)を置く。5.6 の「充電が捨てられる」ことは、占有が終わった直後に `secondary_held` を偽にしても弾が出ないことで示す(持ち越す変異はここで落ちる)
      - **5.7(占有中もクールダウンが実時間で進む)も両側**。副武器を 1 発撃ってクールダウンを始めてから `grant_ability()` し、(a) `secondary_cooldown` を超えるフレーム数だけ占有を続けてから空に戻す → 直後の充電で撃てる、(b) 超えないフレーム数で戻す → 撃てない。`secondary_cooldown` は既定の 2.0 と別の値に取る
      - **5.9(主武器が占有の影響を受けない)** は、占有中と非占有中で `primary_held` に対する `fired(_, false)` の発火フレームが一致することで示す
      - **5.10(`charge_ratio`・`is_cooling_down` へ書き込まない)** は静的な検査だけで示さない。`player.gd` に `charge_ratio` / `is_cooling_down` への代入が現れないことの検査を置いたうえで、**振る舞い側の対**を 5.6(捨てられる)と 5.7(実時間で進む)が担う旨をコメントに残す
      - **10.9** は `make test TESTS=res://tests/player` が既存のテストを 1 行も変えずに緑であることで担保する。既存の `tests/player/player_weapon_test.gd` は空枠でしか駆動しないため、この単位の変更で落ちてはならない。落ちた場合は占有の判定が空枠にも効いている
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 4.3 拡散弾の発射と `ability_fired` を実装する
    _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10, 6.11, 6.12, 6.13, 7.4, 8.6_
    _Boundary: Player_
    _Depends: 1.1, 4.2_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_spread_test.gd`(新規)
    - 仕様参照: spec.md §5.5、§5.2、§6.6、§7 Requirement 6、§7 Requirement 7(7.4)
    - 実装の要点(タスク固有):
      - 6.3・6.4 は `ability_damage`・`ability_bullet_speed`・`bullet_max_distance` を**すべて既定と別の値**へ差し替えて渡す。とくに `ability_bullet_speed` は既定 300.0 が `secondary_bullet_speed` の 300.0 と**同値**であるため、既定のままだと副武器の値を渡す変異が素通りする(要件 8.6 の担保の核)。同様に `ability_damage` は `primary_damage`・`secondary_damage` のどちらとも別の値に取る
      - 6.2・6.6 は `SpreadResolver.resolve()` の戻り値と**同じ順**で一致すること。射撃方向は**環の折り返しをまたぐ方向を 1 つ含む 3 方向以上**で回す(1 方向だけだと並びを取り違える実装が素通りする)
      - **6.7 と 6.8 は分岐の両側**である。第 3 の枠で撃ったフレームで `fired` が 0 回・`ability_fired` が 1 回、主武器/副武器で撃ったフレームで `fired` が 1 回・`ability_fired` が 0 回。4 つの観測をすべて置く(片側だけだと「両方発火する」変異が落ちない)
      - 6.9・6.10・6.11 は `projectile_scene` を null にしたケース。`push_error` が出ること・弾が 0 発・`ability_fired` が 0 回・**`remaining_uses` が 1 減っていること**の 4 つを同じケースで見る。6.11 は「取り消してはならない」であり、取り消す変異はこの 1 つの観測だけが落とす。`push_error` の**回数はアサーションしない**(仕様が定めていない)
      - 6.1 の「3 発」は、生成先のコンテナの子の数の**増分**で数える(既にある子と混ぜない)。6.12 は `Player` の子が増えないことと親の子が 3 つ増えることの対で見る。親が無い場合に自身へ載せるケースも 1 本置く(既存の `_spawn_projectile()` と同じ扱い)
      - 6.13(レイヤ 3 / マスク 1・4)は `projectile.tscn` の流用によって満たす。生成した 3 発の `collision_layer` / `collision_mask` を読んで固定する(`Projectile` を変更しないことは要件 10.4 でありタスク 7.1 が検査する)
      - **7.4** は空の枠のまま `secondary_held` を与え続けるケース。弾が 0 発であることと、`assert_error(...).is_success()` で `push_error` が出ないことの両方を見る
      - 実フレームで駆動するケースを 1 本持ち、`apply_command()` を同期で呼ぶヘルパだけに頼らない(unit #3 タスク 5.3 の申し送り)
    - 検証コマンド: `make test TESTS=res://tests/player`

- [ ] 5. 解析の確認用の仮ステージと配線

  撃破 → 演出 → 到達 → 取得を end-to-end で繋ぐスライス。配線の実装は 1 つのスクリプトに閉じ、2 つのシーンで共有する(spec.md §5.6・§8)。

  - [ ] 5.1 `AnalysisDevStage` の配線を実装する
    _Requirements: 7.6, 7.7, 7.8, 9.10, 9.11, 9.12, 9.13, 9.17, 9.19_
    _Boundary: AnalysisDevStage_
    _Depends: 1.2, 3.2, 4.1_
    - 対象ファイル: `src/stage/analysis_dev_stage.gd`(新規), `tests/stage/analysis_dev_stage_test.gd`(新規)
    - 仕様参照: spec.md §5.6、§7 Requirement 9、§7 Requirement 7(7.6〜7.8)
    - 実装の要点(タスク固有):
      - このサブタスクは**ハンドラの振る舞い**だけを扱う(シーンの構成はタスク 5.2・5.3)。テストはステージのスクリプトを付けた `Node2D` をツリーへ載せ、スタブの敵と `Player` を子として置いてハンドラを直接呼ぶ
      - ハンドラは `[kind, NodePath]` を受け取り、`NodePath` を**ステージから `get_node()` で解決**して `global_position` を読む(生のノード参照ではなく `NodePath` として往復する。spec.md §3 の検証済みの前提)
      - **9.12(種別で分岐しない)は両側**。`SHOOTER` と `CHARGER` の**両方**で演出が 1 つ生成されることを見る。片方だけだと「常に生成する」実装と「片方だけ生成する」実装が区別できない
      - **9.13 / 7.6 / 7.7 / 7.8 は分岐の両側**。`arrived(SHOOTER)` で `grant_ability()` が呼ばれ、`arrived(CHARGER)` で呼ばれないこと。7.8 は**能力を持っている状態**で `arrived(CHARGER)` を届け、`remaining_uses` が直前の値のまま変わらないことを見る(空の状態で確かめると、枠を空にする変異が no-op になって素通りする)。`remaining_uses` は `ability_uses` の既定 3 と別の値に取る
      - 9.11 は生成した演出が**ステージ自身の子**であること。撃破された敵の子にする変異は、敵を `queue_free()` した後に演出が残っていることの対で落とす
      - 9.10 は演出の始点が**撃破された敵の `global_position`**であること。敵を原点から離れた位置に置き、ステージ自身の位置も原点から動かす(`position` と `global_position` を取り違える実装を落とす)。標的が `Player` であることも併せて見る
      - 9.17 は `pulse_scene` が未設定のケース。`push_error` が出ることと、ステージの子が増えないことの両方を見る。文言はテスト側に複製を持つ
      - 9.19 は unit #3 の `test_the_handler_runs_no_reload_inside_its_own_call` と同型。`died` のハンドラの呼び出しの中で再読込が走らないこと(`call_deferred` で遅れること)を見る
      - **`EnemyKind` を参照しない**(要件 3.5。判定は `AbilityAnalysis` に委ねる)。テストのスタブが `defeated` 相当の値を渡す形にする
    - 検証コマンド: `make test TESTS=res://tests/stage`

  - [ ] 5.2 (P) `analysis_dev_stage.tscn` を作る
    _Requirements: 9.1, 9.2, 9.4, 9.5, 9.6, 9.8, 9.9, 9.14, 9.15, 9.16, 9.18, 9.20_
    _Boundary: AnalysisDevStage_
    _Depends: 3.3, 5.1_
    - 対象ファイル: `src/stage/analysis_dev_stage.tscn`(新規), `tests/stage/analysis_dev_stage_scene_test.gd`(新規)
    - 仕様参照: spec.md §5.6、§6.7、§8(配置の表)、§7 Requirement 9
    - 実装の要点(タスク固有):
      - シーンの構成を検証するテストは**ツリーへ載せない**(`load()` → `instantiate()` → `auto_free()`)。unit #3 の `tests/stage/enemy_dev_stage_test.gd` を手本にする
      - 配置は spec.md §8 の表の値を採る(`Player` (48, 76)・`ShooterEnemy` (160, 84)・`ChargerEnemy` (248, 84))。床・壁は unit #3 の `enemy_dev_stage.tscn` を写す
      - **9.8 / 9.9(`[connection]` の宣言と `binds`)** は本単位で最も技術的な確認点である。検証は敵の `get_signal_connection_list(&"defeated")` から `callable` を取り、(a) `callable.get_object()` がステージと同一、(b) メソッド名が一致、(c) `callable.get_bound_arguments()` が 1 要素の `NodePath`、(d) **`stage.get_node(その NodePath)` がその敵と同一**、の 4 つで見る。(d) を落とすと、すべての接続が同じ敵を指す誤りが素通りする。`get_node()` は相対パスならツリーへ載せていないノードでも解決できる
      - 9.14 は `target` が**シーンの宣言**で `Player` を指すこと。`[node]` ヘッダに `node_paths=PackedStringArray("target")` が要る(unit #3 の申し送り。この 1 語が無いと `instantiate()` 後に静かに `null` になる)。`assert_object(enemy.target).is_same(player)` で見ると「宣言であること」まで同じ 1 本で固定される
      - 9.4 / 9.5 は unit #3 の距離の検査と同じ形。**閾値は `160 + その敵の detect_range`** であり、種別ごとに `stats` から読む(定数を直書きしない)。9.5 は「遠いほうの敵が自分の `detect_range` より遠い」ことであり、9.4 とは別のアサーションにする
      - 9.2 は種別ごとの体数(射撃型 1・突進型 1)を直接固定する。9.4 の距離の検査だけに依存させない
      - 9.16 は `pulse_scene` を `instantiate()` してルートが `AnalysisPulse` であることを見る。9.15 は `pulse_scene` が null でないこと
      - 9.18(`player.died` の `[connection]`)は unit #3 の `tests/stage/enemy_dev_stage_test.gd` の `died` の接続検査と同型。`player.get_signal_connection_list(&"died")` が 1 件で、`callable.get_object()` がステージ・メソッド名が一致することを見る(接続を `_ready()` で作る実装はツリーへ載せない検証で 0 件になって落ちる)
      - 9.6 は全アクターと地形が x = 0〜320 に収まること・木に `Camera2D` が 1 つも無いこと
      - 9.20 は木にスポナー相当のノード・スクリプトが無いことと、**振る舞い側の対**として実フレームを進めても敵の数が増えないことを見る(unit #3 の同名のテストを手本にする)
      - `[ext_resource]` に `uid=` を書かない
    - 検証コマンド: `make test TESTS=res://tests/stage`

  - [ ] 5.3 (P) `analysis_overwrite_dev_stage.tscn` を作る
    _Requirements: 9.1, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.14, 9.15, 9.16, 9.18, 9.20_
    _Boundary: AnalysisDevStage_
    _Depends: 3.3, 5.1_
    - 対象ファイル: `src/stage/analysis_overwrite_dev_stage.tscn`(新規), `tests/stage/analysis_overwrite_dev_stage_test.gd`(新規)
    - 仕様参照: spec.md §5.6、§6.7、§8(配置の表)、§7 Requirement 9
    - 実装の要点(タスク固有):
      - 配置は spec.md §8 の表の値を採る(`Player` (48, 76)・`ShooterEnemy` (160, 84)・`ShooterEnemy2` (248, 84))。**新しいスクリプトを作らない**(要件 9.7)
      - **9.7** は 2 つのシーンのルートのスクリプトが**同一のリソース**であること(`get_script()` の比較。`ResourceLoader` はキャッシュを返すため同一性の比較で足りる)と、`src/stage/` に `analysis_` で始まる `.gd` が 1 本しか無いことの両方で見る
      - 9.3 は射撃型 2 体・突進型 0 体を直接固定する。9.4 の閾値は 2 体とも `160 + 160 = 320`
      - 9.8 / 9.9 の `binds` の検証は 5.2 と同じ 4 点。**2 体の敵がそれぞれ自分自身を指す**ことが要点であり、(d)(`get_node()` で解決した先が当の敵)を必ず置く。1 つ目のシーンでは種別が違うため取り違えに気付けるが、**このシーンは同種別 2 体であり、両方が同じ敵を指す誤りは (d) でしか落ちない**
      - 9.18(`player.died` の `[connection]`)・9.14・9.15・9.16・9.6・9.20 は 5.2 と同じ形で置く。共通のアサーションを 5.2 のテストから写す場合も、**期待値(座標・体数・種別)はこのシーンのものへ差し替える**。**9.16 を省かない** — このシーンの `pulse_scene` が別の `PackedScene` を指す誤りは、9.15(null でない)だけでは落ちない
    - 検証コマンド: `make test TESTS=res://tests/stage`

- [ ] 6. ドキュメント反映と目視での確認

  自動テストに載せられない振る舞い(spec.md §7 Requirement 11)を仮ステージの起動で確かめ、記録を残す。

  - [ ] 6.1 `docs/testing.md` へ 2 つの仮ステージを追記する
    _Requirements: 9.23_
    _Boundary: docs_
    _Depends: 5.2, 5.3_
    - 対象ファイル: `docs/testing.md`(変更)
    - 仕様参照: spec.md §7 9.23、§5.6(用途の違いの表)
    - 実装の要点(タスク固有):
      - 追記先は「仮ステージを目視で確認する」の節。既存の `dev_stage.tscn`・`enemy_dev_stage.tscn` の記述に触れず、**2 つそれぞれの起動コマンドと用途の違い**を足す(1 つ目は取得から使い切りまでと写せない種別、2 つ目は同種別の再取得による上書き)
      - 既存の記述と同じ形式(コードブロックの `godot --path <プロジェクトのルート> res://src/stage/<シーン>.tscn`)に揃える
      - このファイルは spec.md §6.7 が挙げる「本単位が変更する既存ファイル」の 1 つであり、他の節を変更しない
    - 検証コマンド: `git diff --stat -- docs/testing.md`(変更が `docs/testing.md` の 1 ファイルに閉じることを確認する)

  - [ ] 6.2 `analysis_dev_stage.tscn` を起動して 6 項目を目視で確かめる
    _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_
    _Boundary: AnalysisDevStage_
    _Depends: 4.3, 5.2, 6.1_
    - 対象ファイル: `docs/specs/001-mvp/004-analysis-ability/tasks.md`(`## Implementation Notes` へ記録を追記)
    - 仕様参照: spec.md §7 Requirement 11(検証の形式)、§3 前提
    - 実装の要点(タスク固有):
      - **GUI の Godot が要る**(`--headless` では目視にならない。`docs/testing.md`)。実行できない環境の場合は自動テストで代替せず、`_Blocked:` を付けて停止し、その旨を報告する
      - 記録には「いつ・どの環境で・何を確認したか」を書く(`docs/testing.md` の規約)。**11.2 は所要時間と、その間に操作が止まらなかったことを数値で記録する**(spec.md §3 の 4 項目の既定値の妥当性はこの記録をもとに判断する)
      - 11.3 は「矩形が消えた時点」と「第 3 の枠が使えるようになった時点」の一致を記録する。11.4 は 8 方向のうち少なくとも 3 方向で確かめる
      - 11.5 は副武器のチャージを満たしたまま演出を到達させる(要件 5.5 の実機での確認。人間が承認済みの代償が実際に起きることを見る)
      - 11.6 は突進型の撃破で**演出は出るが残り回数は変わらない**ことの両方を見る
      - 11.1(飛翔中の死亡で演出が残らないこと)は gdUnit のテストツリーで `reload_current_scene()` を呼べないため自動テストにしない(unit #3 §7 9.3 と同じ扱い)
      - §3 の未検証の前提(4 項目の既定値・飛翔 0.4 秒・8 方向の隣接による拡散)について、成立したか・調整が要るかの所見を併せて記録する。**調整が要る場合も本単位では値を変えず、上流への申し送りとして残す**
    - 検証コマンド: `godot --path . res://src/stage/analysis_dev_stage.tscn`

  - [ ] 6.3 `analysis_overwrite_dev_stage.tscn` を起動して上書きを目視で確かめる
    _Requirements: 11.7_
    _Boundary: AnalysisDevStage_
    _Depends: 4.3, 5.3, 6.1_
    - 対象ファイル: `docs/specs/001-mvp/004-analysis-ability/tasks.md`(`## Implementation Notes` へ記録を追記)
    - 仕様参照: spec.md §7 11.7、§5.6(シーンの用途の表)
    - 実装の要点(タスク固有):
      - **拡散弾を 1 回以上撃って残り回数を減らした状態から** 2 体目の射撃型を撃破する(減らさずに撃破すると、上書きと加算が区別できない)
      - 記録には「撃破の直前の残り回数」と「到達の直後の残り回数」を数値で書く。到達の直後が `ability_uses` の値に戻っていること(加算されていないこと)がこの確認の要点である
      - 6.2 と同じく GUI の Godot が要る
    - 検証コマンド: `godot --path . res://src/stage/analysis_overwrite_dev_stage.tscn`

- [ ] 7. 凍結済みの契約の非変更の横断検査

  spec.md §6.7 は本単位が変更する既存ファイルを 3 つに限っている。実装が終わった時点で、それ以外の追跡済みファイルが 1 つも変わっていないことを機械で示す。

  - [ ] 7.1 凍結の対象が変わっていないことを検査する
    _Requirements: 9.21, 9.22, 9.24, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9_
    _Boundary: repository_
    _Depends: 4.3, 5.3, 6.1_
    - 対象ファイル: (新規・変更なし。検証のみ。差分が出た場合は原因のファイルを戻す)
    - 仕様参照: spec.md §6.7、§7 Requirement 10、§7 9.21・9.22・9.24
    - 実装の要点(タスク固有):
      - **手段は git の差分である**(内容ハッシュを 20 個並べない)。基点は unit #3 を統合したコミット `5b4e240`。`--diff-filter=MDR` により新規追加(A)を除外するため、`tests/` や `src/` をディレクトリごと指定できる
      - 10.1(`PlayerCommand`)・10.2 と 10.6 と 9.22(`project.godot`)・10.4(`PrimaryWeapon`・`SecondaryWeapon`・`Projectile`)・10.5(`Enemy.defeated`)・10.7(unit #1〜#3 の文書)・10.8(既存のテスト)・9.21(既存の 2 つの仮ステージ)は、この 1 つのコマンドがまとめて示す
      - **10.3(`fired` の引数)と 8.7(既存 14 項目の既定値)は差分では固定できない**(`player.gd` と `player_stats.gd` は変更するため)。10.3 は宣言行の完全一致で、8.7 は既存の `tests/player/player_stats_test.gd` が緑のままであることで示す。あわせて **6.7 / 6.8 の振る舞いのテスト**(タスク 4.3)が `fired` の意味の非変更を担保する旨をコミット本文に記す
      - 9.24(ファイルの配置)は、実装が `src/ability/` と `src/stage/` に、テストが `tests/ability/`・`tests/player/`・`tests/stage/` にあり、`src/` の下にテストが 1 本も無いことで示す
      - 10.9 は `make test` の全体が緑であることで示す。**判定基準を緩めて緑にしない**(既存のテストの削除・スキップ・弱体化を行わない)。unit #3 の完了時点の基線は 407 test cases / 0 errors / 0 failures / 0 skipped / 0 orphans であり、本単位の追加分だけ件数が増えていること・skipped と orphans が 0 のままであることを確認する
      - 差分が出た場合は `git revert` ではなく、当該の変更が本単位の受け入れ基準に必要だったかを判断する。必要だった場合は spec.md §6.7 との矛盾であり、**自分で spec.md を直さず上流へ差し戻す**
    - 検証コマンド: `test -z "$(git diff --name-only --diff-filter=MDR 5b4e240 -- src tests project.godot docs/specs/001-mvp/001-test-harness docs/specs/001-mvp/002-foot-player docs/specs/001-mvp/003-foot-enemies ':!src/player/player.gd' ':!src/player/player_stats.gd')" && echo FROZEN_OK`、`grep -qx 'signal fired(direction: Vector2i, is_secondary: bool)' src/player/player.gd && echo SIGNAL_OK`、`test -z "$(find src -name '*_test.gd')" && echo LAYOUT_OK`、`make test`

## Implementation Notes

(このセクションは dev-implement が実装中の学習・選択した知識 port・横断的な気付き・レビューを通過した境界外変更の申告を追記する領域。初期は空でよい)

### 知識 port の選択

`docs/dev/ports/` が存在しないため、注入する知識 port は**なし**(`ports.py --skill dev-decompose --root docs/dev/ports` の結果)。

### 実装開始時の基準点

- unit #3 の完了時点の `make test` の基線: 407 test cases / 25 test suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans(PR #10 のマージ後と本単位の Step 0 の 2 回、独立に実測した値。**実装開始時に再実測して基線を更新すること** — 前セッションの報告を信用せず再実行する、が unit #3 の申し送りである)。
- **実装開始時に再実測した基線(2026-08-17、Godot 4.7.1.stable.official、macOS/darwin 25.5.0)**: 407 test cases / 25 test suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / 実行時間 40s。上の値と一致したため基線を据え置く。
- 凍結の検査(タスク 7.1 の 1 つ目のコマンド)は実装開始時点で空を返すことを確認済み。
- GUI の Godot が使える環境である(`godot --version` = 4.7.1.stable.official.a13da4feb)。タスク 6.2・6.3 の目視は実行できる見込み。
- テストの書き方の規約は `docs/testing.md` にある。既存の `tests/` 配下の同種のテストを手本にする(シーン構成は `tests/stage/enemy_dev_stage_test.gd`、武器の振る舞いは `tests/player/player_weapon_test.gd`、純ロジックは `tests/enemy/charger_brain_test.gd`)。

### タスクを跨ぐ申し送り

- **変異注入で実装を一時的に書き換えるときは `git checkout` / `git restore` を使わない。** このプロジェクトの hook がこれらを破壊的な git 操作として拒否する。`cp` で退避 → 書き換え → 退避ファイルから `cp` で復元し、`git status --short` が空であることで復元を確認する。
- **`Array[Vector2i]` を返す関数から `return []` は Godot 4.7.1 で通る**(空の型付き配列へ変換される)。異常系の戻り値はこの形でよい。
- **`assert_array(X).contains(spread)`(gdUnit4)は単一の配列引数を要素列へ展開する**(`GdUnitArrayAssertImpl._extract_variadic_value()`)。「`spread` の全要素が X に含まれる」の意味で効き、空振りしない。
- **`push_error` の文言はテスト側に定数の複製を持つ**(実装の定数を参照すると自己成就する)。書式は既存の `AimResolver` に揃える(`...(現在値: %s)。<復帰の説明>`)。
- **タスク 1.1 の成果**: 8 方向の環は `SpreadResolver.CLOCKWISE_RING`(`const Array[Vector2i]`)が唯一の正本である。後続で環そのものが要る場合はここを読む(spec.md §6.2 をコードで持つ唯一の場所)。
- **実装が存在しない状態で `class_name` を参照するテストを走らせると、gdUnit4 は assertion の失敗ではなく終了コード 134(探索中のスクリプトエラー)でクラッシュする。** RED を失敗として観測したい場合は、先に最小のスタブを置いてから実行する。
- **タスク 1.2 の成果と 5.1 への申し送り**: `tests/ability/ability_analysis_test.gd` の `test_the_analysis_dev_stage_source_does_not_name_the_enemy_kind` は、`src/stage/analysis_dev_stage.gd` が**無い間はその不在を `assert_bool(FileAccess.file_exists(...)).is_false()` で固定**する形になっている。5.1 でこのファイルを作った時点で検査は自動的に `not_contains("EnemyKind")` の経路へ入る(テスト側の書き換えは不要)が、**5.1 では空振り経路を通っていないことを一度確認すること**。
- **要件 3.5 の振る舞い側の対はタスク 5.1 が持つ**(9.12 = ハンドラが種別で分岐せず両方の種別で演出を生成する、7.7 = 突進型の到達で枠が変わらない)。1.2 は静的な検査の側だけを置いた。
- **タスク 1.3 の成果と後続への申し送り**:
  - 4 項目は `bullet_max_distance` の**後ろ**に足した(差分を純粋な追記に保つため)。`player.gd` は無変更である。
  - `Player._report_non_positive_stats()` は `PROPERTY_USAGE_EDITOR` かつ `PROPERTY_USAGE_SCRIPT_VARIABLE` で絞るため、**`@export` を付けない内部項目は検査に載らない**。
  - **`assert_error(...).is_push_error()` は `await` を付け忘れると常に緑になる。** `add_child()` が引き起こす `_ready()` の `push_error` を捕まえられる。
  - `PlayerStats` を継承した内部クラス(`@export var unknown_stat`)で「項目名を列挙していないこと」を示す型は `Player` でも機能する。タスク 4.x でも同じ手が使える。
- **タスク 2.1 の成果と 2.2・2.3 への申し送り**:
  - テストの定数は `FRAME_DELTA = 0.0625`(2 進で厳密)・`COOLDOWN = 0.25`(= 4 × FRAME_DELTA、既定の 1.5 と離してある)。発射ヘルパ `_fire()` は「4 フレーム離す → 押す」であり、**2.2 が押下の縁とクールダウンを入れても既存 17 ケースは緑のまま通る想定**で組んである。既存ケースの書き換えは不要な見込み。
  - `update()` は現時点で `_delta` を読まない(引数名が `_delta` なのは未使用引数のため)。**2.2 で経過を累積する時点で `delta` へ戻すこと**(spec.md §5.1 の署名の表記に揃う唯一のタイミング)。
  - **1.9・1.14 は現時点で確実に RED になる**(レビュアーが probe で実測: 空の枠でも `update()` が真を返し、押下を 5 フレーム与えると `remaining_uses` が -5 まで潜る)。2.3 は「残り 0 で縁を 5 フレーム与えて `remaining_uses == 0`」のケースを先に書けば RED を観測できる。
  - **レビューで 1 度 REJECTED になった原因**: `update()` に 1.9・1.14 のガードを先取りで入れたこと。無検証の分岐が src に残り、かつ後続タスクが RED から入れなくなる。**このタスク列では「担当外の要件を先回りして実装しない」ことを守ること。**
  - `test_the_values_used_here_differ_from_the_defaults` が「テストの使う値が `PlayerStats` の既定と一致しないこと」を固定している。既定値を動かす変更が来たらこのケースが番人になる。
  - Godot 4.7.1 のこのプロジェクトでは `UNUSED_PARAMETER` 警告は `--check-only` / `--import` / `make test` のいずれでも出力されない(`project.godot` に `debug/gdscript/warnings/*` の設定が無い)。
- **タスク 2.2 の成果と 2.3 への申し送り**:
  - **押しっぱなしの列を `[true, true, true]` の 3 フレームだけにすると「縁を見ない」変異が落ちない。** 3 フレームはすべてクールダウンの内側に収まり、縁を消した実装でも `[真, 偽, 偽]` を返すためである。**押しっぱなしのままクールダウンの境界を跨ぐ長さの列**(このテストでは `[true] × 6`)を別に置いて初めて落ちる。同じ形の条件を後続で足すときは「境界を跨ぐ長さ」を確かめること。
  - クールダウンの数え方は「`update()` の先頭で `delta` を足してから比較する」形である。したがって**発射したフレームから数えて `cooldown / delta` フレーム後がちょうど境界**になる(`COOLDOWN` 0.25・`FRAME_DELTA` 0.0625 なら 4 フレーム後)。フレーム数を数える列を書くときはこの数え方に合わせる。
  - 既存の `_fire()`(4 フレーム離す → 押す)は発射フレームから 5 フレーム後の押下であり境界の外側にある。2.3 でも引き続き使える。
  - **1.10(空でも `held` を記録する)は、現時点で残り回数のガードが一切ないため副作用的に成立している。** 2.3 でガードを足すときは `_was_held = held` より**後ろ**に置く必要がある。したがって 1.10 単体のテストは 2.3 で最初から緑になりうる。**これを「RED が出ない = 先取り」と誤読しないこと**(レビュアーからの申し送り)。
  - `test_the_cooldown_measures_elapsed_time_rather_than_frame_count`(1 フレームだけ `COOLDOWN` を渡す)が「`delta` を読んでいること」を固定している。フレーム数で数える実装はここで落ちる。
  - レポートの失敗ケース名は `python3` で `reports/report_1/results.xml` の `testcase` を走査すると一覧できる(色付きのコンソール出力を grep するより確実)。
- **タスク 2.3 の成果とタスク 4 への申し送り**:
  - `update()` の実装は「`_was_held = held` → 縁の判定 → **`is_empty` のガード** → クールダウンの判定 → 減算」の順である。**`is_empty` のガードを `_was_held = held` より前へ出すと 1.10 / 1.11 が落ちる**(レビュアーが変異注入で実測)。この 5 行の位置は 1 フレーム単位の契約そのものであり、後続で `update()` に手を入れる場合はこの順を崩さないこと。
  - 1.12 は、タスク定義の例示(`grant(3)` から 2 回撃つ)ではなく `SPEND_DOWN_USES = 4` から 4 発撃ち下ろす形にした。`PlayerStats.ability_uses` の既定が 3 であり、`grant(3)` は同スイートの `test_the_values_used_here_differ_from_the_defaults` が課す「既定値と離す」規律と衝突するため。**タスク 4 で `ability_uses` を差し替えるときも 3 を使わないこと。**
  - 変異注入の実測(レビュアー): (a) `is_empty` ガードの削除 → 4 件失敗、(b) ガードを `_was_held = held` の前へ移動 → 2 件失敗、(c) ガードを `remaining_uses < 0` へ緩め + `maxi(0, ...)` で clamp → 2 件失敗。1.9 と 1.14 は独立に固定されている。
  - タスク 2 の完了時点で `make test` 全体は **469 test cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans**(基線 407 + 本単位の追加 62)。
- **タスク 3.1 の成果と 3.2・3.3・5.1 への申し送り**:
  - **座標系は global を使う。** `launch(kind, from, to)` は `global_position = from` を置き、補間先は `to.global_position` である。タスク 5.1 の配線では撃破位置を **global** で渡すこと(`enemy.global_position`)。
  - **`flight_time` を `1 / Engine.physics_ticks_per_second` の整数倍に取っても、フレーム数によっては累積が `flight_time` に届かない**(倍精度の丸め)。60 Hz では **6・7・12〜15・24〜30 フレームが該当し、4・8・16・20 は厳密に一致する**(実装者は 24 までと報告したが、レビュアーの独立の再現でもっと広いことが判明した)。**境界をフレーム数で数えるテストを書くときはこのリストのフレーム数を避けること。** 本スイートは 4 と 8 を使い、その前提を `test_the_flight_times_are_reached_by_accumulating_the_frame_delta` で明示的に固定している。
  - **`minf(progress, 1.0)` の clamp は 4.3 のために要る**。既定 0.4 と 60 Hz の組は整数倍でないため、最後のフレームの経過が `flight_time` を超え、clamp が無いと標的を通り越した点で到達する。
  - **テストのフレーム駆動は 2 系統ある。** 手で回すケースは `add_child()` の直後に `set_physics_process(false)` を呼ぶヘルパ `_add_hand_driven()` を通し、エンジンの物理フレームと手で回すフレームが混ざらないようにしてある。実フレームのケースだけ `set_physics_process` を触らない。3.2 で経路を足すときも同じヘルパを使えば到達フレームを数えられる。
  - **`_is_flying`(発射から到達までの間だけ真)は「未発射」と「到達済み」を止めるためだけの状態**である。3.2 が標的の消失・事前条件違反の経路を足すときは、この旗を落としてから `queue_free()` する形に揃えると発火回数の契約が崩れない。**`if not _is_flying: return` は現時点で「到達後」の側だけが観測されている**(レビュアーの指摘)。3.2 で 4.9 の経路を足すときに「launch 前」の側のケースを併せて置くこと。
  - **`AnalysisPulse` のソースに文字列 `PlayerStats` を書かない**(コメントも不可)。`test_the_pulse_does_not_read_the_player_stats` がソースを見る。ただしこの 1 本は静的検査のみで等価な別解(`load("res://src/player/player_stats.gd")`)を素通りさせるため、8.8 の実体は `test_the_pulse_exports_the_flight_time` と `test_the_player_stats_does_not_hold_the_flight_time` の対が押さえている。
  - 本タスクの時点で `AnalysisPulse` は `.tscn` を持たないため、テストは `AnalysisPulse.new()` で生成している。3.3 でシーンができた後もこのスイートは `.new()` のままでよい。
  - レビュアーが 11 種の変異注入を実測し、すべて死亡することを確認した(境界の緩め・標的位置の凍結・状態の共有・`_process` への移動・`flight_time` の直書き・`launch` の位置設定の削除・emit と解放の順の入替・定数 `kind`・解放の削除・`PlayerStats` への `flight_time` 追加)。
  - タスク 3.1 の完了時点で `make test` 全体は **485 test cases / 30 test suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans**。
- **タスク 3.2 の成果と 3.3・5.1 への申し送り**:
  - **`launch()` に届く「無効な標的」は `null` だけである。** Godot 4.7.1 は解放済みのオブジェクトを `to: Node2D` の引数の型検査で弾き(`The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class.`)、関数の本体へ入らない。さらにラムダが解放済みの値を捕らえると呼び出し時に `null` へ差し替える(`Lambda capture at index 0 was freed. Passed "null" instead.`)。レビュアーが使い捨てプロジェクトで独立に再現済み。したがって 4.9 のテストは `null` の 1 形だけでよい。**5.1 の配線でも、撃破した敵をそのまま渡す経路は「解放済み」ではなく「その物理フレームではまだ有効」であることを前提にしてよい。** 飛行中に敵が消える場合は経路 B(4.8)が受ける。
  - **`_physics_process` の 3 つのガードの順は契約そのものである**: `_is_flying` → **標的の有効性** → 到達の判定。標的の判定を到達より後ろへ動かすと、標的が消えたフレームでも `arrived` が出る(受け手が居ない)。この順を崩さないこと。
  - **4.8(標的の消失は報告しない)と 4.9(事前条件違反は報告する)の非対称**が契約である。消失の経路に `push_error` を足す変異は経路 B の 2 ケースが落とす。
  - `AnalysisPulse` の `push_error` の文言は `INVALID_FLIGHT_TIME_ERROR_FORMAT` と `INVALID_TARGET_ERROR` の 2 つ。テスト側は文言の複製を持つ。
  - `Engine.time_scale` を触るケースは `before_test()` で控えて `after_test()` で戻す形にした(本スイートに初めて `before_test`/`after_test` を置いた)。同じスイートに実フレームで駆動するケース(`await_millis`)があるため、戻し漏れは他のケースを壊す。
  - レビュアーが 13 種の変異注入を独立に実測し、すべて死亡することを確認した。**等価変異が 1 つある**(消失の経路の `_is_flying = false` の単独削除は `queue_free()` が残る限りフレーム終端で解放されるため落ちない)。記録のみで対処しない。
  - タスク 3.2 の完了時点で `make test` 全体は **492 test cases / 30 test suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans**。
- **タスク 3.3 の成果と 5.2・5.3・6.2 への申し送り**:
  - **`AnalysisPulse` の `ColorRect` の色は `Color(0.55, 0.95, 0.6, 1)`(緑)**である。既存 8 色のどれとも系統が違う。
  - 4.16 の比較は 8 つのシーンを `instantiate()` して `ColorRect` を再帰で集め、**色の集合の非包含**で書いてある。比較対象は `tests/ability/analysis_pulse_scene_test.gd` 冒頭の `EXISTING_PLACEHOLDER_SCENE_PATHS`(8 本の固定リスト)。レビュアーが集合の実体を probe で数え、spec.md §7 4.16 の 6 シーン + 地形 2 色を過不足なく覆うことを確認した。**タスク 5.2・5.3 の新しい仮ステージが新しい色を持つ場合だけこの定数へ追記すること**(既存と同じ色を写す限り追随は不要)。
  - 地形の 2 色の取りこぼしの番人として `test_the_compared_colors_cover_both_terrain_colors_of_the_dev_stages` を置いた。足場の色を `dev_stage.tscn` から読み、集合に含まれることと足場が床と別の色であること(番人が空振りしていないこと)を対で見ている。レビュアーが「比較の配列から `dev_stage.tscn` を落とし、かつ色を足場色にする」複合変異でこの番人が落ちることを実測した。
  - `.tscn` に `.uid` は生成されなかった(Godot 4.7.1 はシーンの uid を `[gd_scene]` 行に持つ)。`[ext_resource]` に `uid=` は書いていない。**タスク 6.2・6.3 でエディタを使う場合は保存し直さないこと**(保存すると `uid=` が書き戻される。差分に混ざったら記法の揺れとして扱う)。
  - `main.tscn` の `Background`(0.05, 0.058, 0.086, 1)は spec.md §7 4.16 が比較対象を明示的に限定しているため対象外である(選んだ色はこれとも重ならない)。
  - タスク 3.3 の完了時点で `make test` 全体は **499 test cases / 31 test suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans**。
- **レビューが見つけた 3.4 の生存変異(記録のみ、本単位では対処しない)**: `AbilityAnalysis` に「不正値を 1 度受け取ったら以降は常に偽」というラッチ型の状態を入れると、ケースの実行順の都合で 1.2 のスイートは全緑のまま通る。実装は `static` の純粋関数であり 3.4 を満たすため欠陥ではないが、将来 `AbilityAnalysis` に手を入れる場合は「異常値を挟んだ前後で**真を返す側**も対にして見る」形へ足すと閉じる。
