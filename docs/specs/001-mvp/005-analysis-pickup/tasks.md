# analysis-pickup — 実装タスク

> 仕様の詳細は同じディレクトリの仕様文書 spec.md を参照する。
> このファイルには仕様を転記しない。

## File Structure Plan

| ファイルパス | 区分 | 責務 |
| ------------ | ---- | ---- |
| `src/ability/analysis_fragment.gd` | 新規 | 撃破位置に静止し、触れた相手の `grant_upgrade()` を呼んで自身を解放する `Area2D` |
| `src/ability/analysis_fragment.tscn` | 新規 | `AnalysisFragment` + 8×8px の `ColorRect`(原点を中心)+ 同寸の当たり判定。レイヤ 0・マスク 2 |
| `src/ability/spread_resolver.gd` | 作り直し | 射撃方向とその左右 20 度を `Array[Vector2]` で返す static の純粋関数(8 方向の環を捨てて回転で導く) |
| `src/stage/analysis_dev_stage.gd` | 作り直し | 撃破 → 写せる種別の判定 → 断片の生成の配線と、`died` の遅延再読込 |
| `src/stage/analysis_dev_stage.tscn` | 変更 | 床・壁と `Player` 1・`ShooterEnemy` 1・`ChargerEnemy` 1。`pulse_scene` の宣言を `fragment_scene` へ差し替える 2 行のみ(座標・ノード構成・色は unit #4 のまま 9.2〜9.7 を満たす) |
| `src/player/player.gd` | 変更 | 第 3 の枠を撤去し、`is_primary_upgraded`・`grant_upgrade()`・`spread_fired`・副武器の tint を足す |
| `src/player/player_stats.gd` | 変更 | `ability_*` の 4 項目を削除し、unit #2 の 14 項目へ戻す |
| `src/weapon/projectile.gd` | 変更 | `launch()` の `direction` を `Vector2` へ広げ、乖離の理由を doc コメントへ残す |
| `docs/testing.md` | 変更 | 「仮ステージを目視で確認する」を解析の仮ステージ 1 つ分へ書き換える |
| `src/ability/ability_slot.gd` (+`.uid`) | 削除 | 第 3 の枠の状態機械。枠の撤去で参照ゼロになる |
| `src/ability/analysis_pulse.gd` (+`.uid`) | 削除 | 撃破位置からプレイヤーへ飛ぶ演出。取得の形が変わり引き継ぐ先が無い |
| `src/ability/analysis_pulse.tscn` | 削除 | 同上のシーン |
| `src/stage/analysis_overwrite_dev_stage.tscn` | 削除 | 上書きの確認用の 2 つ目の仮ステージ。冪等な強化では見るものが無い |
| `tests/ability/analysis_fragment_test.gd` | 新規 | 断片の振る舞い(接触・解放・静止・「しないこと」)のテスト |
| `tests/ability/analysis_fragment_scene_test.gd` | 新規 | `analysis_fragment.tscn` の構成(寸法・原点・色・レイヤ・マスク)のテスト |
| `tests/ability/spread_resolver_test.gd` | 作り直し | 20 度の 3 方向・角度・長さ・状態の不在・異常系のテスト |
| `tests/weapon/projectile_direction_test.gd` | 新規(§6.7 に無い。理由は下記) | `launch()` の `Vector2` 化と、8 方向の外の向きでの発射のテスト |
| `tests/player/player_upgrade_test.gd` | 新規 | `grant_upgrade()`・`is_primary_upgraded`・死亡でのリセットのテスト |
| `tests/player/player_spread_test.gd` | 作り直し | 強化中の主武器の 3 発・`fired`/`spread_fired`・異常系のテスト |
| `tests/player/player_secondary_tint_test.gd` | 新規(§6.7 に無い。理由は下記) | 強化中の副武器の弾の `modulate` と、据え置きの数値のテスト |
| `tests/stage/analysis_dev_stage_test.gd` | 作り直し | ハンドラの振る舞い(生成・位置・親・種別の分岐・異常系)のテスト |
| `tests/stage/analysis_dev_stage_scene_test.gd` | 作り直し | シーンの構成・配置規約・`[connection]` と `binds`・`fragment_scene` のテスト |
| `tests/ability/ability_slot_test.gd` (+`.uid`) | 削除 | 削除する契約のテスト |
| `tests/ability/analysis_pulse_test.gd` (+`.uid`) | 削除 | 同上 |
| `tests/ability/analysis_pulse_scene_test.gd` (+`.uid`) | 削除 | 同上 |
| `tests/player/player_ability_test.gd` (+`.uid`) | 削除 | 同上 |
| `tests/player/player_ability_stats_test.gd` (+`.uid`) | 削除 | 同上 |
| `tests/player/player_takeover_test.gd` (+`.uid`) | 削除 | 同上(第 3 の枠による副武器の占有) |
| `tests/stage/analysis_overwrite_dev_stage_test.gd` (+`.uid`) | 削除 | 同上(2 つ目の仮ステージ) |
| `src/ability/ability_analysis.gd` | 流用(変更しない) | 種別で分岐する唯一の場所。枠に依存しないため名前ごと流用する |
| `tests/ability/ability_analysis_test.gd` | 流用(変更しない) | 8.6〜8.8 はこのスイートが既に固定している |
| `src/weapon/projectile.tscn` | 流用(変更しない) | 拡散の弾も強化中の副武器の弾もこのシーンを使う(弾のシーンを増やさない) |
| `src/player/player.tscn` | 流用(変更しない) | 5.11 が `upgraded_secondary_tint` の上書きを禁じる。行を足さない |

`.gd` を足すと Godot が `.gd.uid` を生成して追跡対象になるため、スクリプトと `.uid` を対にしてステージする(unit #2・#3 の申し送り)。削除するときも対で消す。`addons/gdUnit4/` と `reports/` は生成物であり、この計画に載せない。

### spec.md §6.7 から変えた点(2 件。どちらもテストファイルの追加)

- **`tests/weapon/projectile_direction_test.gd` を足す。** 要件 2 は 9 件すべてが `Projectile.launch()` の契約であるが、その正本である `tests/weapon/projectile_test.gd` は要件 11.9・11.10 が変更を禁じている。`docs/testing.md`「配置と命名」は実装のディレクトリ構成を写すことを課すため、`src/weapon/projectile.gd` の振る舞いのテストは `tests/weapon/` に置くほかない。既存スイートを変えずに新しい契約を固定する手段として、同じディレクトリへ別ファイルを足す(既存テストの追加は 11.9 の禁じる「変更」に当たらない)。
- **`tests/player/player_secondary_tint_test.gd` を足す。** §6.7 は `Player` 側の新設テストを `player_upgrade_test.gd` 1 本としているが、既存の `tests/player/` は `player_move_test.gd`・`player_weapon_test.gd`・`player_health_test.gd`・`player_scene_test.gd` と**観点で分ける慣行**を持ち、unit #4 も `player_ability_test.gd`・`player_takeover_test.gd`・`player_spread_test.gd` の 3 本に分けた。それに揃え、強化の状態(要件 3・6)と副武器の見た目(要件 5)を別スイートにする。要件 3(9 件)・要件 5(11 件)・要件 6(5 件)の 25 件を 1 本に収めると、unit #4 の同種のスイート(265〜559 行)の倍近くになり、レビューの単位としても大きすぎる。

いずれも §6.7 が「ファイルごとの区分と責務の計画(File Structure Plan)はここで定めない(タスク分解の責務)」と委ねている範囲であり、契約の変更ではない。

### 変更してよい既存ファイル

**上の表に現れるファイルと、本単位の workdir(`docs/specs/001-mvp/005-analysis-pickup/`)の中だけ**である(workdir はタスク 6.2 が目視の記録を `## Implementation Notes` へ追記するため対象に含む)。

### 凍結の正本(タスク 7.1 が git の差分で検査する)

差分の基点は本単位の作業ブランチの分岐元 `01c1d0e` とする。

| 凍結の対象 | 要件 | 手段 |
| ---- | ---- | ---- |
| `project.godot`(`[input]` 7 アクション・`[layer_names]` 1〜5・`run/main_scene`) | 11.2・11.7・9.13 | `git diff 01c1d0e -- project.godot` が空 |
| `src/player/player_command.gd`・`player_input.gd`・`aim_resolver.gd`・`health.gd` | 11.1・11.4 | 同上 |
| `src/weapon/primary_weapon.gd`・`secondary_weapon.gd`・`enemy_projectile.gd`・`projectile.tscn` | 11.4・11.5 | 同上 |
| `src/enemy/` の全ファイル(`Enemy.defeated` の引数を含む) | 11.6 | 同上 |
| `src/stage/dev_stage.tscn`・`dev_stage.gd`・`enemy_dev_stage.tscn`・`enemy_dev_stage.gd`・`damage_zone.*` | 9.12 | 同上 |
| `src/player/player.tscn` | 5.11 | 同上 |
| `src/ability/ability_analysis.gd` | 10.9 | 同上 |
| unit #1〜#4 の `spec.md` と `tasks.md` | 11.8 | 同上 |
| unit #1〜#3 の既存テスト(`tests/harness/`・`tests/enemy/`・`tests/weapon/` の既存 5 本・`tests/stage/dev_stage_test.gd`・`enemy_dev_stage_test.gd`・`tests/player/` の unit #2 由来 8 本)と `tests/ability/ability_analysis_test.gd` | 11.9・10.9 | `git diff --diff-filter=MDR 01c1d0e -- <上記>` が空 |
| `fired` のシグナル宣言(`player.gd` は変更するため差分では固定できない) | 11.3 | 宣言行の完全一致 + 4.4・5.2 の振る舞いのテスト |
| `PlayerStats` の既存 14 項目の既定値(同上) | 11.12 | 既存の `tests/player/player_stats_test.gd` が変更なしで緑のまま |
| `Projectile` の `push_error` の文言・引数の名前と並び・レイヤ・射程・解放(同上) | 2.7・2.8・2.9・11.10 | 既存の `tests/weapon/projectile_test.gd` が変更なしで緑のまま |

**`tests/weapon/` への新規追加(`projectile_direction_test.gd`)は `--diff-filter=MDR` に現れない**(追加は `A`)。11.9 が禁じるのは既存テストの変更・削除・改名であり、追加は含まない。

### 分解時に埋めた仕様の空白(実装者への申し送り)

spec.md が定めておらず、実装に必要なため本分解で決めた事項。**契約の変更ではなく、契約から一意に決まらない実装の選択**である。

- **撤去を expand → migrate → contract の 3 段に並べる。** 第 3 の枠の撤去は `Player`・`PlayerStats`・`AbilitySlot`・`AnalysisPulse`・仮ステージ・テスト 7 本へ同時に波及し、単一の垂直スライスでは検証を緑に保てない(垂直スライス優先の例外。`dev-decompose/SKILL.md` Step 3)。タスク 1 が新形式(断片)を旧形式の隣に足し(expand)、タスク 2 が仮ステージの配線を断片へ移し(migrate)、タスク 3 が旧形式を削除する(contract)。**順序を入れ替えると必ず赤になる**:
  - `analysis_dev_stage.gd` は `Player.grant_ability()` を静的型付きで呼ぶため、タスク 2.2 より先に 3.1 を実行するとパースエラーになる。
  - `analysis_dev_stage.tscn` と `analysis_overwrite_dev_stage.tscn` は `analysis_pulse.tscn` を `ext_resource` で参照するため、2.1・2.2 より先に 3.4 を実行すると読み込みが壊れる。
  - `Player._spawn_spread()` は `SpreadResolver.resolve()` の戻り値を `Array[Vector2i]` として受けるため、3.1 より先に 4.1 を実行すると型が合わない。
  - **`tests/ability/ability_slot_test.gd` は `PlayerStats.ability_cooldown` と `ability_uses` を読む**(番人のケース `test_the_values_used_here_differ_from_the_defaults`)。そのため `AbilitySlot` の削除(3.2)を `PlayerStats` の 4 項目の削除(3.3)より**先**に置く。逆順にすると `tests/ability` が `Invalid access to property 'ability_cooldown'` で赤になる(隔離した複製で実測済み)。**この赤は `tests/player` に絞った検証コマンドでは見えない**ため、タスク 3 の各サブタスクの検証コマンドは `make test`(全体)とする。
- **削除するテストと作り直すテストの扱いを分ける。** `player_ability_test.gd`・`player_takeover_test.gd`・`player_ability_stats_test.gd`・`ability_slot_test.gd`・`analysis_pulse_test.gd`・`analysis_pulse_scene_test.gd`・`analysis_overwrite_dev_stage_test.gd` の 7 本は二度と作らない。`player_spread_test.gd` と `analysis_dev_stage_scene_test.gd` は**削除するコミットと作り直すコミットが分かれる**(同じパスへ後のタスクが新しい内容を書く)。中間のコミットでその契約が一時的に無検証になるが、各コミットは緑であり、次のタスクが同じフェーズの中で埋める。
- **`spread_resolver.gd` はタスク 3 で消さない。** 3.1 で呼び出し側が消えても、既存の `spread_resolver_test.gd` が緑のまま残るため、無検証の期間を作らずに 4.1 まで持ち越せる。
- **`is_primary_upgraded` の裏に置く非公開の状態の名前**: 実装者が決めてよい。契約は「getter だけを持ち、外からの代入が状態へ届かない」ことだけである(spec.md §5.3)。
- **`grant_upgrade()` と `_ensure_*` の関係**: `_ready()` に依存させない(要件 3.6)。既存の `_ensure_weapons()` は `_primary_weapon != null` で早期 return するため、そこへ素朴に足すと生成が隠れる(unit #4 が `ability_slot` で踏んだ落とし穴)。
- **`projectile_scene` 未設定時の `push_error` の回数**: 仕様は定めていない(1 回でも 3 回でもよい)。**テストで回数を固定しない**(unit #4 の申し送りを引き継ぐ)。
- **拡散の 3 発の生成の順**: `SpreadResolver.resolve()` の戻り値の並びと同じにする(要件 4.6 が `spread_fired` の `directions` を「生成した 3 発と同じ順」と定めるため、生成順と配列の順を一致させるほかない)。
- **`modulate` を設定する場所**: 弾を生成して `launch()` する経路の中で、副武器かつ強化中のときだけ設定する。主武器の経路では触らない(要件 5.7 が `Color.WHITE` のままを求めるため、既定に任せる)。
- **仮ステージの床・壁・アクタの座標**: unit #4 の `analysis_dev_stage.tscn` の値をそのまま残す(spec.md §8 の表と一致する。床 320×16 を (160, 100)、左壁・右壁 16×108 を (8, 38) と (312, 38)、`Player` (48, 76)、`ShooterEnemy` (160, 84)、`ChargerEnemy` (248, 84))。要件 9.2〜9.7 はこの配置で満たされるため、**シーンの構造の変更は `pulse_scene` → `fragment_scene` の宣言だけ**である。
- **ステージのハンドラ名**: `_on_enemy_defeated`・`_on_player_died` を据え置く。`[connection]` の `method=` を変える理由が無く、既存のシーンの宣言をそのまま使える。
- **`analysis_dev_stage.gd` は `EnemyKind` という語をソースに含めてはならない。** 変更しない `tests/ability/ability_analysis_test.gd::test_the_analysis_dev_stage_source_does_not_name_the_enemy_kind` がこれを検査している(要件 8.5 の静的な側)。`src/player/` の全 `.gd` も同じ検査を受ける。
- **`ext_resource` の `uid=`**: 既存の `.tscn` に揃えて書かない(unit #3・#4 の申し送り)。

### 全タスク共通の実装の規律(知識 port `mutation-discipline`)

**「緑であること」は「欠陥を捕らえられること」を意味しない。** 各サブタスクの「実装の要点」に、その項目が変異で死ぬ形を書いてある。レビューは変異を実際に注入して実測する(読んで判断しない)。復元に破壊的な git 操作を使わず、`cp` で退避して `cp` で戻す。

1. **各数値項目は、テストが既定と別の値へ差し替えて渡す。** 既定値のまま渡すと、実装が値を直書きしても緑になる。テストが使う値が既定と一致しないことを固定する番人のケースを 1 本置く。
2. **分岐は両側にケースを割り当てる。** 「強化中」と「強化していない」、「写せる種別」と「写せない種別」、「`grant_upgrade()` を持つ相手」と「持たない相手」はいずれも両側を観測する。
3. **「しないこと」を静的な検査だけで示さない。** ソースの文字列を見る検査は等価な別解を素通りさせる(代入を禁じる正規表現は `set(...)` を通す)。必ず振る舞い側のケースと対にする。
4. **同期で駆動するヘルパを使うタスクは、実フレーム(実時間)で駆動するケースを 1 本は持つ。**
5. **拒否する呼び出しには、成功する呼び出しと別の値を渡す。** あわせて状態が初期値でないところで拒否させる。
6. **境界を厳密比較するガードには「境界のすぐ外」の値を 1 つ置く。**
7. **等価変異をテストで固定しようとしない。** 見つけたら `## Implementation Notes` に記録だけして対処しない。
8. **参照先の中身を見ない検査は、参照を差し替える誤りを検出しない。** `fragment_scene` は「設定されていること」だけでなく、解決してルートの型まで見る。
9. **同種の複数インスタンスを繋ぐ宣言は、「解決した先が当のインスタンス自身であること」まで見る。**
10. **担当外の要件を先回りして実装しない。** 要件の割り当てに矛盾を見つけたら、黙って解消せず申告する。

## タスク一覧

- [ ] 1. 断片(`AnalysisFragment`)の新設 — expand 段

  取得の新形式を、旧形式(第 3 の枠と演出)の隣に足す。この段だけで検証が緑になる。断片は相手を `has_method()` で見るため、`Player.grant_upgrade()` がまだ無くても成立する(テストはスタブで駆動する)。

  - [x] 1.1 (P) `AnalysisFragment` の接触と解放を実装する
    _Requirements: 7.1, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.16, 7.17, 7.18_
    _Boundary: AnalysisFragment_
    - 対象ファイル: `src/ability/analysis_fragment.gd`(新規), `tests/ability/analysis_fragment_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§7 Requirement 7
    - 実装の要点(タスク固有):
      - 7.4・7.6 は**分岐の両側**である。`grant_upgrade()` を持つスタブと持たないスタブの 2 つを用意し、前者では呼ばれて解放され、後者では呼ばれず解放もされず `push_error` も出ないことを見る。**片側だけを観測すると「常に解放する」「常に何もしない」変異が素通りする**
      - 7.7 は「既に強化を持つ相手」でも解放されることを見る。スタブに `grant_upgrade()` の呼び出し回数を持たせ、2 回目の接触でも呼ばれて解放されることを固定する(相手の状態を断片が読まないことの担保)
      - 7.18(`body_entered` で受ける)は、**`Area2D` のスタブを近づけても何も起きないこと**と、`CharacterBody2D` のスタブでは起きることの対で示す。`area_entered` で実装した場合に前者が落ちる。ソースの文字列を見る検査だけにしない(規律 3)
      - 7.8・7.9 は実フレームで駆動する(規律 4)。ツリーへ載せて `await await_millis()` で待ち、**位置が 1 度も変わらないこと**と**解放されていないこと**を見る。待ちが足りずにフレームを消化しなかった場合と区別するため、同じシーンに置いた観測用ノードで消化フレーム数を数える
      - 7.10 は `queue_free()` の使用を示す。`free()` との違いは「接触のコールバックの中では解放されず、その次のフレームで解放される」ことに現れるため、接触の直後に `is_instance_valid()` が真であり、1 フレーム後に偽であることの 2 点で見る(ソースの文字列だけで示さない)
      - 7.11 は `src/ability/analysis_fragment.gd` のソースに `Player` という語が現れないことの静的な検査と、**`Player` を継承しないスタブで 7.4 が成立すること**の対で示す(規律 3)
      - 7.16 は接触の前後で `Engine.time_scale` と `SceneTree.paused` が変わらないことを見る。テストの後で必ず元へ戻す
      - 7.17 は `get_property_list()` を走査して、スクリプト変数に種別を表す項目が 1 つも無いことを見る(名前を固定で列挙すると、別名の項目を足しても落ちない)
      - `Area2D` の重なりの通知は 1 物理フレーム遅れる(spec.md §3)。接触を検証するケースは 2 フレーム分を上限に取る
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [x] 1.2 `analysis_fragment.tscn` を作り、構成を固定する
    _Requirements: 7.2, 7.3, 7.12, 7.13, 7.14_
    _Boundary: AnalysisFragment_
    _Depends: 1.1_
    - 対象ファイル: `src/ability/analysis_fragment.tscn`(新規), `tests/ability/analysis_fragment_scene_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§6.4、§6.6、§7 Requirement 7
    - 実装の要点(タスク固有):
      - シーンをツリーへ載せない(`instantiate()` + `auto_free()` だけで読む。unit #2 の申し送り)
      - 7.2・7.3 はレイヤとマスクを**別々に**見る。マスクはプレイヤーのレイヤ(2)**だけ**であることを、値の完全一致で固定する(`has` 相当の非排他な検査だと、他のレイヤを足す変異が素通りする)
      - 7.12・7.13 は `ColorRect` の `size` と `position`、`CollisionShape2D` の `shape.size` と `position` の 4 点で見る。原点が中心であることは `position == -size * 0.5`(`ColorRect`)と `position == Vector2.ZERO`(`CollisionShape2D`)で示す。`ColorRect` が**ちょうど 1 枚**であることも数えて固定する
      - 7.14 の比較の対象は spec.md §7 7.14 が列挙する 9 つのシーンである。**`dev_stage.tscn` の足場 `Step1`〜`Step3` の色 `Color(0.32, 0.36, 0.44, 1)` を取りこぼさない**(unit #4 の申し送り。取りこぼすとこの色を選んだときに違反したまま緑になる)。色の一覧をテスト側に定数で書き写すのではなく、**各 `.tscn` を実際に読み込んで `ColorRect` を再帰的に集める**(規律 8。書き写すと、後で `.tscn` の色が変わったときに検査が古いまま残る)。集めた色が 0 件でないことを先に固定する(走査の空振りと区別する)
      - 7.15(強化中の副武器の弾の描画色との相違)は**このタスクでは扱わない**。`Player.upgraded_secondary_tint` がまだ存在せず、値を書き写すと参照を解決しない検査になる。タスク 5.3 が `Player` 側から解決して対にする
    - 検証コマンド: `make test TESTS=res://tests/ability`

- [ ] 2. 仮ステージを断片の配線へ作り直す — migrate 段

  撃破の配線を、演出を経てステージが取得を配る形から、断片を撃破位置へ置くだけの形へ移す。この段で `analysis_dev_stage.gd` から `Player.grant_ability()` と `AnalysisPulse` への参照が消え、タスク 3 の削除が可能になる。

  - [ ] 2.1 (P) 2 つ目の仮ステージとそのテストを削除する
    _Requirements: 9.14_
    _Boundary: AnalysisDevStage_
    - 対象ファイル: `src/stage/analysis_overwrite_dev_stage.tscn`(削除), `tests/stage/analysis_overwrite_dev_stage_test.gd`(削除), `tests/stage/analysis_overwrite_dev_stage_test.gd.uid`(削除)
    - 仕様参照: spec.md §5.6、§8「仮ステージを 1 つに統合する」、§7 Requirement 9
    - 実装の要点(タスク固有):
      - **使用ゼロを確認してから削除する**: `analysis_overwrite_dev_stage` を指す参照が `src/`・`tests/`・`docs/`・`project.godot`・`main.tscn` に無いことを削除の前に確かめる(`docs/testing.md` は残るが、その書き換えはタスク 6.1 が持つ。この時点では起動方法の記述が残ることを許す)
      - 紐づく生成物を消し忘れない: `.tscn` に `.uid` は付かないが、テストの `.gd` には付く
      - 削除の後に `make test` の統計行の `orphans`・`skipped`・`failures`・`errors` がすべて 0 であることを確かめる
    - 検証コマンド: `make test`

  - [ ] 2.2 `AnalysisDevStage` のハンドラを断片の生成へ作り直す
    _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10, 8.15, 9.10_
    _Boundary: AnalysisDevStage_
    _Depends: 1.2, 2.1_
    - 対象ファイル: `src/stage/analysis_dev_stage.gd`(作り直し), `src/stage/analysis_dev_stage.tscn`(変更。`pulse_scene` の宣言を `fragment_scene` へ差し替える 2 行のみ), `tests/stage/analysis_dev_stage_test.gd`(作り直し), `tests/stage/analysis_dev_stage_scene_test.gd`(削除。タスク 2.3 が同じパスへ作り直す), `tests/stage/analysis_dev_stage_scene_test.gd.uid`(削除)
    - 仕様参照: spec.md §5.5、§5.6、§6.3、§7 Requirement 8
    - 実装の要点(タスク固有):
      - **`@export var pulse_scene` と `_on_pulse_arrived()` と `_player()` を消す**。8.15 は `_player()` の不在をソースで見る検査と、**写せる種別の撃破の後に(取得していないのに)`Player` の状態が変わらないこと**の振る舞いで対にする(規律 3)
      - 8.1・8.4 は**分岐の両側**である。射撃型で断片が 1 つ増え、突進型で 1 つも増えないことを、それぞれ独立のケースで見る。**「増えない側」だけを見ると「常に生成しない」変異が素通りする**。加える数も固定する(1 つであること)
      - 8.2 は**ステージ自身を原点でない位置へ置いた状態**で見る(`global_position` と `position` を取り違える変異を落とす)。unit #4 のテストが使った `STAGE_POSITION` のような非ゼロの座標を採る
      - 8.3 は断片の `get_parent()` がステージであることに加え、**撃破された敵を `queue_free()` した後のフレームでも断片が生きていること**で見る(敵の子にする変異は、この 2 点目でしか落ちない)
      - 8.5 は `AbilityAnalysis.is_transferable()` への委譲である。ソースに `EnemyKind` が現れないことは**変更しない `tests/ability/ability_analysis_test.gd` が既に検査している**(`test_the_analysis_dev_stage_source_does_not_name_the_enemy_kind`)。本サブタスクはその検査を緑に保つ責任を持ち、同ファイルを変更しない
      - **8.6・8.7・8.8 は `AbilityAnalysis` の契約であり、変更しない `tests/ability/ability_analysis_test.gd` が既に固定している**(`test_the_shooter_kind_is_transferable`・`test_the_charger_kind_is_not_transferable`・`test_a_value_below_the_kinds_pushes_an_error`・`test_a_value_above_the_kinds_pushes_an_error` 等)。本サブタスクは実装を書かず、**該当のケースが実在して緑であることを確認する**。同ファイルへ手を入れない(要件 10.9)
      - 8.9・8.10 は**分岐の両側**である。`fragment_scene` を未設定にして、写せる種別では `push_error` が出て子が増えず、写せない種別では `push_error` が出ないことを対で見る。「未設定なら常に `push_error`」という変異は後者で落ちる
      - 8.14 の `binds` の解決(`get_node()`)は 2.3 が構成の側から固定するが、**ハンドラが受け取った `NodePath` を実際に解決して位置を読むこと**は本サブタスクが振る舞いで示す。同種の 2 体を置いた作業用のステージを組み、それぞれの撃破で断片が**当のインスタンスの位置**へ出ることを見る(規律 9。unit #4 の `test_the_start_of_the_pulse_follows_the_bound_node_path` に相当する)
      - 9.10 は「ハンドラの呼び出しの中で再読込を走らせない」ことである。`call_deferred` へ置き換える変異を静的な検査だけで示さない(規律 3)。unit #4 の `test_the_handler_runs_no_reload_inside_its_own_call` と同じ形で、ハンドラを直接呼んだ直後に現在のシーンが差し替わっていないことを見る
      - `.tscn` の変更は `ext_resource` の 1 行(`analysis_pulse.tscn` → `analysis_fragment.tscn`)と、ルートノードの `pulse_scene = ...` → `fragment_scene = ...` の 1 行だけに限る。座標・ノード構成・色に触れない
    - 検証コマンド: `make test TESTS=res://tests/stage`(その後 `make test` で全体を確かめる)

  - [ ] 2.3 `analysis_dev_stage.tscn` の構成と配置規約を固定する
    _Requirements: 8.11, 8.12, 8.13, 8.14, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.11_
    _Boundary: AnalysisDevStage_
    _Depends: 2.2_
    - 対象ファイル: `tests/stage/analysis_dev_stage_scene_test.gd`(作り直し), `src/stage/analysis_dev_stage.tscn`(変更。検査が落ちた場合のみ)
    - 仕様参照: spec.md §5.6、§8「仮ステージを 1 つに統合する」、§7 Requirement 9
    - 実装の要点(タスク固有):
      - シーンをツリーへ載せない(`instantiate()` + `auto_free()` だけで読む)。ただし 9.11 の「スポナーを持たない」は、載せて一定時間走らせて敵が増えないことの振る舞いと対にする(規律 3。unit #4 の `test_no_enemy_appears_while_the_stage_runs` に相当する)
      - 8.11・8.12 は対で置く。**「`fragment_scene` が設定されていること」だけを見る検査は、参照を別のシーンへ差し替える変異を通す**(規律 8)。`fragment_scene.instantiate()` してルートが `AnalysisFragment` であることまで見る。あわせて、ルートの `PackedScene` 型の `@export` が `fragment_scene` **だけ**であることを `get_property_list()` から見る(`pulse_scene` の消し残りを落とす)
      - 8.13・8.14 は `[connection]` の宣言を `Node.get_signal_connection_list()` から読む。**接続が敵の数だけあること**・**`method` がステージのハンドラであること**・**`binds` の引数が 1 つで、それを `get_node()` で解決した先が当の敵自身であること**の 3 点を見る(規律 9)。`_ready()` で接続する変異は、ツリーへ載せずに `instantiate()` しただけの状態で接続が読めることによって落ちる
      - 9.1 は「解析の確認用の仮ステージが 1 つだけ」である。`src/stage/` を走査して `AnalysisDevStage` をルートに持つ `.tscn` が 1 つであることを見る(ファイル名を固定で列挙すると、3 つ目を足しても落ちない)
      - 9.2・9.3・9.4 は unit #4 のスイートの形を引き継ぐ。9.3 の閾値は敵ごとの `detect_range` から算出し(射撃型 160・突進型 128)、テスト側に距離の期待値を書き写さない。9.4 は奥の敵の距離が**その敵自身の** `detect_range` より大きいことを見る
      - **9.5 は unit #4 の `[Nit]` を閉じる。** unit #4 のスイートは「床の上に立つ」を垂直方向でしか見ておらず、床を水平方向に縮めても緑のまま通った。本スイートは各アクタの**水平方向の範囲**(位置 ± `ColorRect` の幅の半分)が床の水平方向の範囲に収まることを見る。落ちることを確かめるため、床の `ColorRect` の `offset_left`/`offset_right` を一時的に縮める変異を注入して実測する
      - 9.6 は垂直方向で床と重ならないことを見る(9.5 とは別のケースにする。1 つにまとめると片方の軸を消す変異が素通りする)
      - 9.7 は幅 320px 以内であることと `Camera2D` が 1 つも無いことの 2 点。ノードを再帰的に走査して型で見る(名前で見ない)
      - 9.8 は各敵の `target` が `Player` ノードを指すことを、**`instantiate()` しただけの状態**で見る(`_ready()` で検索する変異を落とす)。解決した先がステージの `Player` そのものであることまで見る(規律 9)
      - 9.9 は `died` の接続が宣言として読めることを見る。9.10 の振る舞いの側は 2.2 が持つ
      - `.tscn` は 2.2 で `fragment_scene` へ差し替え済みであり、**座標・ノード構成・色は unit #4 のままで 9.2〜9.7 を満たす**(spec.md §8 の表と一致する)。検査が落ちた場合だけ `.tscn` を直す
    - 検証コマンド: `make test TESTS=res://tests/stage`

- [ ] 3. 第 3 の武器枠と解析の演出の撤去 — contract 段

  旧形式を削除する。**3.1 → 3.2 → 3.3 の順を崩さない**(3.1 が `Player` から参照を落とさない限り `AbilitySlot` を消せず、3.2 が `ability_slot_test.gd` を消さない限り `PlayerStats` の 4 項目を消せない)。各サブタスクは削除するコードと、それを検証していたテストを**同じコミットで**消し、途中で赤を作らない。削除の波及は 1 ディレクトリに収まらないため、**検証コマンドは絞らず `make test`(全体)とする**。

  - [ ] 3.1 `Player` から第 3 の枠を撤去する
    _Requirements: 10.3_
    _Boundary: Player_
    _Depends: 2.2_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_ability_test.gd`(削除), `tests/player/player_ability_test.gd.uid`(削除), `tests/player/player_takeover_test.gd`(削除), `tests/player/player_takeover_test.gd.uid`(削除), `tests/player/player_spread_test.gd`(削除。タスク 5.2 が同じパスへ作り直す), `tests/player/player_spread_test.gd.uid`(削除)
    - 仕様参照: spec.md §5.3「削除する(unit #4 の追加分)」、§7 Requirement 10
    - 実装の要点(タスク固有):
      - 消すのは `signal ability_fired`・`var ability_slot`・`func grant_ability()`・`func _ensure_ability_slot()` とその**2 箇所の呼び出し**(`grant_ability()` の中と `_ensure_weapons()` の冒頭)および `_ensure_weapons()` 冒頭の説明コメント(「生成を `_ensure_ability_slot()` に分ける: …」)・`_spawn_spread()`・`_update_weapons()` の中の枠の占有(`is_slot_empty`・`ability_slot.update()`・`secondary_held and is_slot_empty`)、および `_launch_projectile()` を `_spawn_projectile()` から分けている理由のコメント。`_launch_projectile()` 自体は残す(副武器の tint をタスク 5.3 がここへ足す)
      - **`cmd.secondary_held` をそのまま `_secondary_weapon.update()` へ渡す形に戻す**。要件 5.10 の振る舞いの検証はタスク 5.3 が持つが、素の通し方に戻すのは本サブタスクである
      - `SpreadResolver` への参照が `src/` から消える。`src/ability/spread_resolver.gd` は**消さない**(タスク 4.1 が作り直す。既存の `spread_resolver_test.gd` が緑のまま残り、無検証の期間ができない)
      - 変更しない `tests/player/player_weapon_test.gd`(unit #2)が緑のまま通ることを確かめる。ここが赤になるのは、副武器への通し方を戻し損ねたことを意味する
      - `tests/player/player_move_test.gd`・`player_health_test.gd`・`player_scene_test.gd`・`player_stats_test.gd` も同じく変更なしで緑であること
    - 検証コマンド: `make test`(タスク 3 の削除は `tests/player` の外へ波及しうるため、絞らず全体で確かめる)

  - [ ] 3.2 `AbilitySlot` を削除する
    _Requirements: 10.1_
    _Boundary: AbilitySlot_
    _Depends: 3.1_
    - 対象ファイル: `src/ability/ability_slot.gd`(削除), `src/ability/ability_slot.gd.uid`(削除), `tests/ability/ability_slot_test.gd`(削除), `tests/ability/ability_slot_test.gd.uid`(削除)
    - 仕様参照: spec.md §5.3、§6.2「0 や「空」の概念を持たない」、§7 Requirement 10
    - 実装の要点(タスク固有):
      - **3.3(`PlayerStats` の 4 項目の削除)より先に実行する。** `tests/ability/ability_slot_test.gd` の番人のケースが `PlayerStats.ability_cooldown` と `ability_uses` を読んでおり、逆順にすると `tests/ability` が赤になる(本ファイル冒頭「順序を入れ替えると必ず赤になる」の 4 件目)
      - **使用ゼロを確認してから削除する**: `AbilitySlot`・`ability_slot` を指す参照が `src/`・`tests/`・`.tscn`・`.tres` に無いことを削除の前に確かめる(3.1 の後であれば 0 件になる)
      - `.gd` と `.gd.uid` を対で消す
      - 削除の後に `make test` の統計行の `orphans`・`skipped`・`failures`・`errors` がすべて 0 であることを確かめる
    - 検証コマンド: `make test`

  - [ ] 3.3 `PlayerStats` から `ability_*` の 4 項目を削除する
    _Requirements: 10.4, 10.5, 11.11, 11.12_
    _Boundary: PlayerStats_
    _Depends: 3.2_
    - 対象ファイル: `src/player/player_stats.gd`(変更), `tests/player/player_ability_stats_test.gd`(削除), `tests/player/player_ability_stats_test.gd.uid`(削除)
    - 仕様参照: spec.md §6.5、§7 Requirement 10・11
    - 実装の要点(タスク固有):
      - **3.2 の後に実行する。** この時点で `PlayerStats.ability_*` を読む残りのファイルは、本サブタスクが同時に消す `tests/player/player_ability_stats_test.gd` だけである(`player_ability_test.gd`・`player_takeover_test.gd`・`player_spread_test.gd` は 3.1 が、`analysis_dev_stage_test.gd` は 2.2 の作り直しが、`ability_slot_test.gd` は 3.2 が既に落としている)。**削除の前に `grep -rn '\.ability_' src tests` で残りの参照を数え、1 ファイルだけであることを確かめる**
      - 既存 14 項目の行に触れない。削除は 4 行と、それを区切る空行だけである
      - 10.5・11.11・11.12 は**変更しない `tests/player/player_stats_test.gd` が緑のまま通ること**で担保する。同スイートは 14 項目の固定リスト `STAT_NAMES` を走査し、既定値を 1 つずつ見ている
      - 10.5(「14 項目ちょうど」)は非排他な検査だけにしない。`tests/player/player_stats_test.gd` は `contains` で見ており、**15 項目目を足しても緑になる**。本サブタスクは項目を減らす側なので現状では落ちないが、この弱さは要件 10.6 の grep(タスク 3.5)が `ability_*` の識別子の不在で補う。**この弱さを `player_stats_test.gd` の改訂で塞ごうとしない**(要件 11.9 が変更を禁じている)。等価でない検出力の欠陥として `## Implementation Notes` に記録する
      - **削除に伴って落ちる検出力をもう 1 件記録する**(規律 7 の「対処しないと決めた変異は記録に残す」)。消す `tests/player/player_ability_stats_test.gd` の `test_ready_checks_an_ability_stat_the_implementation_cannot_know_by_name` は、`PlayerStats` を継承して実装が知りようのない項目を足し、`Player._report_non_positive_stats()` が `get_property_list()` から導いていることを固定する**リポジトリ内で唯一のケース**である(`tests/player/player_move_test.gd` は 14 項目の固定リストしか見ていない)。削除後は、同関数を固定 14 項目の列挙へ書き換える変異を誰も落とせなくなる。要件 10.7 が削除を命じているため対処はしないが、変異の内容と理由を `## Implementation Notes` へ残す
      - `Player._report_non_positive_stats()` は `get_property_list()` から導いており、項目を減らすだけで検査の対象も減る。`player.gd` を変更しない
    - 検証コマンド: `make test`

  - [ ] 3.4 (P) `AnalysisPulse` とそのシーンを削除する
    _Requirements: 10.2_
    _Boundary: AnalysisPulse_
    _Depends: 2.2_
    - 対象ファイル: `src/ability/analysis_pulse.gd`(削除), `src/ability/analysis_pulse.gd.uid`(削除), `src/ability/analysis_pulse.tscn`(削除), `tests/ability/analysis_pulse_test.gd`(削除), `tests/ability/analysis_pulse_test.gd.uid`(削除), `tests/ability/analysis_pulse_scene_test.gd`(削除), `tests/ability/analysis_pulse_scene_test.gd.uid`(削除)
    - 仕様参照: spec.md §8「`AnalysisPulse` を削除し、演出をアイテムの出現そのものに置く」、§7 Requirement 10
    - 実装の要点(タスク固有):
      - **使用ゼロを確認してから削除する**: `AnalysisPulse`・`analysis_pulse` を指す参照が `src/`・`tests/`・`.tscn`(とくに `ext_resource`)に無いことを削除の前に確かめる。2.1(2 つ目のシーンの削除)と 2.2(1 つ目のシーンの `ext_resource` の差し替え)の両方が済んでいないと 0 件にならない
      - 紐づく生成物を消し忘れない: `.gd`・`.gd.uid`・`.tscn` の 3 点と、テスト 2 本の `.gd`・`.gd.uid`
      - 削除の後に `make test` の統計行の `orphans`・`skipped`・`failures`・`errors` がすべて 0 であることを確かめる
    - 検証コマンド: `make test`

  - [ ] 3.5 撤去の完了を識別子と統計行で検査する
    _Requirements: 10.6, 10.7, 10.8, 10.9, 10.10_
    _Boundary: Player_
    _Depends: 3.3, 3.4_
    - 対象ファイル: `src/`(検査のみ), `tests/`(検査のみ), `docs/specs/001-mvp/005-analysis-pickup/tasks.md`(検査の結果を `## Implementation Notes` へ追記する)
    - 仕様参照: spec.md §7 Requirement 10
    - 実装の要点(タスク固有):
      - 10.6 は `src/` 配下の `.gd`・`.tscn`・`.tres` を対象に、`AbilitySlot`・`AnalysisPulse`・`ability_slot`・`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`・`ability_fired`・`grant_ability` の 9 語がいずれも 0 件であることを確かめる。`ability_analysis`・`AbilityAnalysis`・`src/ability/` のディレクトリ名は**残すもの**であり、検索語に含めない(部分一致で誤検出しない語を選ぶ)
      - 10.7 は**要件 10.7 が列挙する 7 本**のテストが実在しないことを確かめる。2.1・3.1・3.2・3.3・3.4 が消すのは合計 8 本であり、`tests/player/player_spread_test.gd`(3.1 が消し 5.2 が作り直す)は 7 本に含まれない。この 1 本を混ぜて数えない
      - **10.8 は静的な検査だけで示さない**(規律 3)。「第 3 の枠を表す状態を持たない」ことの振る舞い側は、要件 4.8(強化していない間の主武器は 1 発)・5.1/5.10(副武器が常に素通し)がタスク 5.2・5.3 で固定する。本サブタスクでは `Player.get_property_list()` と `get_signal_list()` に枠を表す項目・シグナルが無いことを見る静的な側だけを置き、その旨を記録に残す
      - 10.9 は `git diff 01c1d0e -- src/ability/ability_analysis.gd tests/ability/ability_analysis_test.gd` が空であることで示す
      - 10.10 は `make test` の統計行を読む。**この時点でのスイート数・ケース数を `## Implementation Notes` に記録する**。見込みは **31 suites**。基線 37 に対する各サブタスクの増減は 1.1 +1 / 1.2 +1 / 2.1 −1 / 2.2 −1 / 2.3 +1 / 3.1 −3 / 3.2 −1 / 3.3 −1 / 3.4 −2 であり、総和が 31 になる(`tests/player/player_spread_test.gd` は 3.1 で消えたまま、5.2 が作り直すまで戻らない)。ずれた場合は消しすぎ・消し漏れの兆候として原因を突き止める
    - 検証コマンド: `make test`

- [ ] 4. 拡散の方向と弾の向きの型

  強化が使う 2 つの契約を先に確定させる(契約先行)。4.1 と 4.2 は触るファイルが独立で並行できる。どちらもタスク 5 の先行依存になる。

  - [ ] 4.1 (P) `SpreadResolver` を 20 度の回転で作り直す
    _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13_
    _Boundary: SpreadResolver_
    _Depends: 3.1_
    - 対象ファイル: `src/ability/spread_resolver.gd`(作り直し), `tests/ability/spread_resolver_test.gd`(作り直し)
    - 仕様参照: spec.md §5.1、§6.1、§7 Requirement 1
    - 実装の要点(タスク固有):
      - **`CLOCKWISE_RING` を捨てる**。20 度は 8 方向の格子に載らず、環の隣接では表せない。`Vector2(direction).normalized()` を `deg_to_rad(SPREAD_DEGREES)` だけ回して導く。画面座標(y は下向き)では `Vector2.rotated()` の正の角が時計回りに対応するため、2 番目(反時計回り)は負の角である
      - 事前条件の検査は 8 方向の集合への所属で行う(環を消しても、妥当な引数の集合としての 8 方向は残る)
      - 1.1〜1.8 は **8 方向すべてを回すケース**で示す(1 方向だけだと回す向きを取り違える実装が素通りする)
      - **1.3 と 1.4 は回る向きが逆の 2 つの分岐である。** 片方だけを見ると、符号を反転する変異が半分のケースで緑になる。両方の期待値を同じケースで対にして比較する。角度は `Vector2.angle_to()` で測り、**符号込みで**比較する(絶対値で比較すると符号の反転が落ちない)
      - 1.6(2 番目と 3 番目の間が 40 度)は 1.3・1.4 とは独立のケースにする。両方を 0 度回す変異は 1.5・1.7 では落ちず、ここで落ちる
      - **1.10 は「20 度」という値そのものを検査の対象として読む唯一のケースである**(spec.md §7 の「検証の形式」が明示的に許している)。`SpreadResolver.SPREAD_DEGREES == 20.0` を見る。あわせて `src/player/player_stats.gd` と `src/player/player.gd` に `20` という拡散の角度が現れないことを見る(1 箇所に持つことの担保)。**それ以外のケースは `SPREAD_DEGREES` を期待値として参照せず、テスト側の自前の値(20.0)を使う**
      - 1.11 の異常系の表には `Vector2i.ZERO` に加えて **`(2, 0)`・`(0, -2)`・`(1, 2)` のような「8 方向のすぐ外」**を入れる(規律 6。境界を `abs(x) <= 1` から `abs(x) < 2` へ緩める変異を落とす)。戻り値が空の配列であることも併せて見る。`push_error` の文言はテスト側に複製を持つ(実装の定数を参照すると自己成就する)
      - 1.12 は同じ引数で 2 回呼んで**戻り値の配列が値として等しく、かつ別のインスタンスであること**を見る(内部の配列をそのまま返して呼び出し側に書き換えられる形を避ける)
      - 1.13 は「照準は 8 方向のまま」である。`resolve()` の引数の型が `Vector2i` であることを `get_method_list()` から読み、`src/player/aim_resolver.gd` が `01c1d0e` から変わっていないことと対にする。振る舞い側の対は要件 4.4(`fired` の `direction` が 8 方向)であり、タスク 5.2 が持つ
      - 浮動小数の比較は `assert_float(...).is_equal_approx(..., <許容>)` か `assert_vector(...).is_equal_approx(...)` を使う。許容は 0.001 を目安にする
    - 検証コマンド: `make test TESTS=res://tests/ability`

  - [ ] 4.2 (P) `Projectile.launch()` の `direction` を `Vector2` へ広げる
    _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.8, 2.9, 11.10_
    _Boundary: Projectile_
    - 対象ファイル: `src/weapon/projectile.gd`(変更), `tests/weapon/projectile_direction_test.gd`(新規)
    - 仕様参照: spec.md §5.2、§8「`Projectile.launch()` の `direction` を `Vector2` へ広げ、凍結済み文書との乖離を残す」、§7 Requirement 2
    - 実装の要点(タスク固有):
      - 変えるのは**シグネチャの型 1 箇所と、ゼロの検査の比較対象**だけである(`direction == Vector2i.ZERO` は `direction` が `Vector2` になると型が合わない。`direction.is_zero_approx()` か `direction == Vector2.ZERO` へ替える)。`_velocity = Vector2(direction).normalized() * speed` は `Vector2(...)` の包みが不要になるが、残しても同じ結果になる
      - **`ZERO_DIRECTION_ERROR` の文言と `INVALID_LAUNCH_VALUE_ERROR_FORMAT` を変えない**(要件 2.7。理由と反映はタスク 4.3)
      - **11.10 は `tests/weapon/projectile_test.gd` が変更なしで緑のまま通ることで示す。** 同スイートは文言を自分の定数として持ち、`_launch_parameter_names()` が `get_method_list()` の `name` だけを読む(型を見ない)
      - 2.1 は `get_method_list()` の第 1 引数の `type` が `TYPE_VECTOR2` であることを見る。**`TYPE_VECTOR2I` でないこと**も別のアサーションで見る(型を読み違える検査を避ける)
      - 2.2 と 2.3 は**分岐ではなく 2 つの入力の族**である。2.2 は 8 方向すべてを `Vector2i` の値として渡し、2.3 は水平から 20 度(`Vector2.RIGHT.rotated(deg_to_rad(20.0))`)と 8 方向の中間の複数の向きを渡す。**2.2 だけを見ると、内部で 8 方向へ丸める変異が素通りする**
      - 2.4 は斜めの向き(`Vector2i(1, 1)`)と 20 度の向きの両方で、実測の変位から求めた速さが `speed` と一致することを見る。**`speed` を既定の 400.0 と別の値にする**(規律 1)。変位は `frames_moved` から算出する(`速度 / Engine.physics_ticks_per_second * frames_moved`)。実フレームで駆動する(規律 4)
      - 2.5 は `Vector2.ZERO` を渡して `push_error` が出て弾が進まないことを見る。**`Vector2i.ZERO` を渡した場合も同じであること**を別のケースで見る(暗黙変換の後にゼロのガードが働くこと。spec.md §3 で実測済み)。あわせて `speed`・`damage`・`max_distance` を成功する呼び出しと別の値にし、拒否の後も `damage` が初期値のままであることを見る(規律 5)
      - 2.6 は長さが 1 未満の向き(`Vector2(0.3, 0.0)`)と、8 方向から外れた長い向き(`Vector2(3.0, 1.0)`)を渡して、どちらも進むことを見る。**進む向きが正規化された向きであること**まで見る
      - 2.8 は引数の名前と並びを `get_method_list()` から読み、`["direction", "speed", "damage", "max_distance"]` と完全一致することを見る
      - 2.9 は `projectile.tscn` の `collision_layer`・`collision_mask` と、`git diff 01c1d0e -- src/weapon/projectile.tscn` が空であることで示す。地形との衝突・射程・解放は `tests/weapon/projectile_test.gd` が変更なしで緑であることで示す
      - 弾は `auto_free()` に渡す。ツリーへ載せたものも対にする(`orphans` を 0 に保つ)
    - 検証コマンド: `make test TESTS=res://tests/weapon`

  - [ ] 4.3 凍結済み文書との乖離を doc コメントとコミットログへ反映する
    _Requirements: 2.7_
    _Boundary: Projectile_
    _Depends: 4.2_
    - 対象ファイル: `src/weapon/projectile.gd`(変更。`launch()` の doc コメントのみ)
    - 仕様参照: spec.md §8「凍結済み文書との乖離」(反映先 3 つ)
    - 実装の要点(タスク固有):
      - **spec.md §8 が定める 3 つの反映先のうち、(2) と (3) を本サブタスクが果たす**。(1) はタスク 4.2 が新設した `tests/weapon/projectile_direction_test.gd` であり、既に済んでいる。3 つを個別に確認して記録する:
        1. **テストコード(What の正本)** — `tests/weapon/projectile_direction_test.gd` が「8 方向の外の向きで発射できる」を固定していること(4.2 で完了。本サブタスクは確認のみ)
        2. **`Projectile.launch()` の doc コメント(Why not の正本)** — 型を `Vector2i` から `Vector2` へ広げたこと、および `push_error` の文言だけが `Vector2i.ZERO` を指したまま残る理由(凍結済みの `tests/weapon/projectile_test.gd` が文言を自分の定数として固定しており、unit #1〜#3 のテストを変更しないという決定がその改訂を許さない)を書く。あわせて、文言の訂正はそのテストを改訂する後続の作業単位で行うことを書く
        3. **コミットログ(Why の正本)** — 本サブタスクのコミットの本文に、なぜ型を広げたかを書く(20 度は 8 方向の格子に載らない。拡散専用の弾クラスを新設する案はレイヤ・射程・地形との衝突の扱いを 2 箇所に分ける。角度を 45 度に戻す案は人間が退けた決定である)
      - **凍結済みの unit #2 `spec.md` §5.6 は直さない**(要件 11.8)。乖離を残すこと自体が spec.md §8 の決定である
      - doc コメントの追記だけであり、振る舞いを変えない。`make test` が変更なしで緑であることを確かめる
    - 検証コマンド: `make test TESTS=res://tests/weapon`

- [ ] 5. 強化の状態と、強化中の主武器・副武器

  取得した強化を `Player` が保持し、主武器を拡散へ、副武器の弾の色を変える。3 つのサブタスクはいずれも `src/player/player.gd` を触るため並行できない(順に実行する)。

  - [ ] 5.1 強化の状態(`is_primary_upgraded`・`grant_upgrade()`)と死亡でのリセットを入れる
    _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 6.1, 6.2, 6.4, 6.5_
    _Boundary: Player_
    _Depends: 3.3_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_upgrade_test.gd`(新規)
    - 仕様参照: spec.md §5.3「`is_primary_upgraded`」「`grant_upgrade()`」「強化のリセット」、§6.2、§8「`is_primary_upgraded` を getter だけのプロパティにする」、§7 Requirement 3・6
    - 実装の要点(タスク固有):
      - **`is_primary_upgraded` は getter だけを持ち、非公開の状態から導く**。`_on_health_depleted()` で非公開の状態を偽へ戻してから `died.emit()` する
      - **3.5 は「拒否」ではなく「無効化」である。** GDScript は getter だけのプロパティへの代入をパースエラーにも実行時エラーにもせず黙って無視する(spec.md §3 で実測済み)。テストは**代入の後に値が変わっていないこと**を見る。経路を 2 つ置く: 静的に型が分かる直接の代入(`player.is_primary_upgraded = true`)と `player.set("is_primary_upgraded", true)`。**「強化を持つ状態で偽を代入する」ケースも置く**(規律 5。偽の状態で真を代入する側だけだと、代入を無視する実装と「常に偽を返す」実装を区別できない)
      - 3.1・3.2 は分岐の両側である(生成直後は偽、`grant_upgrade()` の後は真)
      - 3.3(冪等)は 2 回呼んで真のままであることを見る。**1 回目と 2 回目の間に体力を減らさない**(6.1 と混ざる)
      - 3.4 は実フレームで駆動する(規律 4)。ツリーへ載せて `await await_millis()` で待ち、消化フレーム数を数えたうえで真のままであることを見る
      - 3.6 はツリーへ載せていない `Player`(`Player.new()` と `player.tscn` の `instantiate()` の両方)で `grant_upgrade()` が呼べることを見る。`_ready()` を通らない経路で null になる状態を持たせない
      - 3.7 は体力を減らした状態・満タンの状態のどちらでも `grant_upgrade()` が真にすることを見る(体力を見る変異を落とす)
      - 3.9 は `get_property_list()` を走査して、強化の種類・残り回数・残り時間を表すスクリプト変数が無いことを見る。あわせて `is_primary_upgraded` の型が `TYPE_BOOL` であることを見る
      - 3.8 は `PlayerCommand` の項目が 5 つちょうどであることと、`project.godot` の `[input]` が `01c1d0e` から変わっていないことで示す。振る舞い側の対として、**`grant_upgrade()` を入力なしで(`PlayerCommand` を触らずに)呼べること**を 3.2 のケースが示す
      - 6.1・6.2 は `take_damage()` から観測する。**`died` を受けたハンドラの中で `is_primary_upgraded` が既に偽であること**を見る(順序を入れ替える変異は、シグナルの受け手から読んだときにしか落ちない)
      - 6.5 は分岐の両側である。体力が 0 に達しない被弾では真のまま、0 に達すると偽になる。**`max_health` を既定の 100 と別の値へ差し替え、与えるダメージも既定と別にする**(規律 1)
      - 6.4 は「`Player` 自身が `Health.depleted` の経路で行う」ことである。仮ステージの再読込に依存しないことは、**ツリーへ載せていない `Player` でも 6.1 が成立すること**で示す(規律 3。ソースの文字列を見る検査だけにしない)
      - 6.3(死亡の後に主武器が 1 発へ戻ること)は**このタスクでは扱わない**。拡散の分岐がまだ無く、いま検証すると恒真になる(規律 10。担当外の要件を先回りしない)。タスク 5.2 が持つ
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 5.2 強化中の主武器を拡散の 3 発にする
    _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 4.14, 6.3_
    _Boundary: Player_
    _Depends: 4.1, 4.2, 5.1_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_spread_test.gd`(作り直し)
    - 仕様参照: spec.md §5.1、§5.3「強化中の主武器」、§6.1、§6.5、§7 Requirement 4
    - 実装の要点(タスク固有):
      - `signal spread_fired(directions: Array[Vector2])` を足す。`fired` の宣言行に触れない(要件 11.3)
      - **`_launch_projectile()` の `direction` の引数の型を `Vector2i` から `Vector2` へ広げる。** 3.1 はこの関数を残し、型も `Vector2i` のまま据え置いている。拡散の 3 方向は `Array[Vector2]` であり、広げないと渡せない。**`fired` の `direction` は `Vector2i` のままである**(要件 11.3・4.4)ため、2 つを取り違えない: 8 方向を運ぶのが `fired`、実際に弾へ渡す向きが `Vector2` である
      - 4.1・4.8 は**分岐の両側**である。強化中は 3 発、強化していない間は 1 発。**強化していない側で `spread_fired` が出ないこと**も見る(「常に 3 発」「常に発火」の変異を落とす)
      - 4.2・4.6 の期待値は `SpreadResolver.resolve(射撃方向)` から取る(spec.md §7 の「検証の形式」がこの形を明示的に許している)。**並びまで一致させる**(順序を入れ替える変異を落とす)。生成した弾の実際の進行方向は、実フレームで走らせた後の変位の向きから読む(`_velocity` は非公開)
      - 4.3 は `stats.primary_damage`・`stats.primary_bullet_speed`・`stats.bullet_max_distance` の 3 つを**すべて既定と別の値へ差し替えて**渡す(規律 1)。とくに `primary_bullet_speed`(既定 400.0)と `bullet_max_distance`(既定 400.0)は**既定値どうしが同値**であり、既定のままだと取り違える変異が素通りする。`damage` は生成した弾の `damage` から読み、`speed` は変位から、`max_distance` は解放されるまでのフレーム数から読む
      - 4.4・4.5・4.7 はシグナルの回数と順序である。`fired` を 1 回・`spread_fired` を 1 回・`fired` が先。**受け手を 1 つのオブジェクトにまとめて発火の順を記録する**(別々の受け手だと順序が読めない)。`fired` の `direction` が 8 方向(`Vector2i`)であり `is_secondary` が偽であることも見る
      - 4.9 は連射間隔が強化の有無で変わらないことである。`primary_interval` を既定の 0.12 と別の値(フレーム数の整数倍になる値)へ差し替え、**強化中と強化していない間で発射のフレームが一致すること**を見る
      - 4.10 は副武器の発射で `spread_fired` が出ないことである(強化中でも)。5.3 が扱う副武器の見た目とは別のケースにする
      - 4.11・4.12 は `projectile_scene` を未設定にして見る。**`push_error` の回数を固定しない**(仕様が定めていない)。弾が 1 つも増えないこと・`fired` も `spread_fired` も出ないことを見る
      - 4.13 は親を持つ `Player` では親へ、親を持たない `Player` では自身へ載ることの両側を見る
      - 4.14 は生成した 3 発の `collision_layer` が 3(`1 << 2`)、`collision_mask` が 1 と 4(`(1 << 0) | (1 << 3)`)であることを見る。値の完全一致で固定する
      - **6.3 はここで扱う。** 強化を得た `Player` を `take_damage()` で倒し、その後の主武器の発射で弾が 1 発だけ生成されることを見る。5.1 の 6.1(状態が偽になる)とは別の観測点であり、**状態のリセットが発射の分岐にも及ぶこと**を示す
      - 少なくとも 1 本は実フレーム(実時間)で駆動する(規律 4)。同期のヘルパだけで組むと、`_update_weapons()` が毎フレーム呼ばれる配線を 1 度も見ないままになる
      - 弾は `auto_free()` に渡す。3 発 × 複数ケースで `orphans` が出やすい
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 5.3 強化中の副武器の弾に `upgraded_secondary_tint` を掛ける
    _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11, 7.15_
    _Boundary: Player_
    _Depends: 5.2_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_secondary_tint_test.gd`(新規)
    - 仕様参照: spec.md §5.3「強化中の副武器」、§6.4、§7 Requirement 5・7(7.15)
    - 実装の要点(タスク固有):
      - `@export var upgraded_secondary_tint: Color = Color(0.35, 0.88, 1, 1)` を `Player` へ足す。**既定値をスクリプト側にだけ置き、`player.tscn` に行を足さない**(要件 5.11)
      - 5.3・5.4 は**分岐の両側**である。強化中の副武器の弾は `modulate == upgraded_secondary_tint`、強化していない間は `Color.WHITE`。**片側だけを見ると「常に掛ける」「常に掛けない」変異が素通りする**
      - **5.3 のテストは `upgraded_secondary_tint` を既定と別の値へ差し替えて渡す**(規律 1)。既定のまま渡すと、実装が色を直書きしても緑になる。差し替えた値が既定と一致しないことを固定する番人のケースを 1 本置く
      - 5.5 は既定値が `Color.WHITE` と異なることを見る。ここは既定値そのものが検査の対象であり、差し替えない
      - 5.6 は**描画色**の比較である。`src/weapon/projectile.tscn` を読み込んで `ColorRect` の `color` を取り、既定の `upgraded_secondary_tint` を掛けた色が元の色と異なることを見る。色の値をテスト側に書き写さず、`.tscn` から解決する(規律 8)
      - **7.15 はここで閉じる。** `src/ability/analysis_fragment.tscn` の `ColorRect` の `color` と、上で求めた強化中の副武器の弾の描画色が異なることを見る。どちらも `.tscn` から解決し、値を書き写さない(規律 8)
      - 5.7 は主武器の弾(強化中・強化していない間の両方)の `modulate` が `Color.WHITE` のままであることを見る。**両方を見る**(強化中だけを見ると、主武器にも掛ける変異が半分のケースで緑になる)
      - 5.1・5.10 は副武器への入力の素通しである。`cmd.secondary_held` を渡したフレームと渡さないフレームを混ぜた列を与え、**強化中と強化していない間で副武器の発射フレームが一致すること**を見る。unit #4 の占有(`ability_slot.is_empty` による切り替え)が残っていれば、この一致が破れる
      - 5.2 は強化中でも副武器の弾が 1 発であり、`fired(direction, true)` が 1 回出ることを見る(拡散が副武器にも及ぶ変異を落とす)
      - 5.8 は `secondary_charge_time`・`secondary_cooldown`・`secondary_damage`・`secondary_bullet_speed` の 4 つを**すべて既定と別の値へ差し替え**、強化中と強化していない間で観測値が一致することを見る(規律 1)。`secondary_bullet_speed` の既定 300.0 は他の項目と衝突しないが、`secondary_damage` の既定 50 は差し替える。充電時間とクールダウンはフレーム数の整数倍になる値を採る
      - 5.9 は `upgraded_secondary_tint` が `Player` の `@export`(`PROPERTY_USAGE_EDITOR` かつ `PROPERTY_USAGE_SCRIPT_VARIABLE`)であることと、`PlayerStats.get_property_list()` に同名の項目が無いことの 2 点で見る
      - **5.11 は参照を解決して見る**(規律 8)。`Player.new()` の `upgraded_secondary_tint` と `player.tscn` の `instantiate()` の `upgraded_secondary_tint` が等しいことを見る。あわせて `src/player/player.tscn` のテキストに `upgraded_secondary_tint` という語が現れないことと、`git diff 01c1d0e -- src/player/player.tscn` が空であることで示す(片方だけだと、シーンに同じ値を書いた変異が前者を通る)
      - 少なくとも 1 本は実フレームで駆動する(規律 4)
    - 検証コマンド: `make test TESTS=res://tests/player`

- [ ] 6. ドキュメント反映と目視での確認

  - [ ] 6.1 `docs/testing.md` の「仮ステージを目視で確認する」を書き換える
    _Requirements: 9.15, 9.16, 9.17, 9.19_
    _Boundary: docs_
    _Depends: 2.3_
    - 対象ファイル: `docs/testing.md`(変更。「仮ステージを目視で確認する」の節のみ)
    - 仕様参照: spec.md §2、§8「仮ステージを 1 つに統合する」、§7 Requirement 9
    - 実装の要点(タスク固有):
      - 9.15 は「解析の確認用の仮ステージが 2 つある」ことを述べた段落と、`analysis_overwrite_dev_stage.tscn` の起動コマンドのブロックを取り除く
      - 9.19 は第 3 の武器枠(残り回数・空枠への復帰・`ability_uses` への復帰)と解析の演出(撃破位置からプレイヤーへ飛ぶ表示)に言及する記述を取り除く。**「取得から使い切りまでの一連(撃破・演出の到達・拡散弾の発射・空枠への復帰)」という記述が該当する**
      - 9.16 は `analysis_dev_stage.tscn` 1 つの起動コマンドと、そこで確かめることを書く。**確かめることは要件 12 の 7 件と 1 対 1 に対応させる**: 射撃型の撃破で断片が出る(12.1)/ 突進型では出ない(12.2)/ 触れると断片が消えて主武器が 3 発の拡散になる(12.3)/ 強化中の副武器の弾の色が変わる(12.4)/ 断片を放置しても消えず落ちない(12.5)/ 死亡して再読込されると 1 発へ戻る(12.6)/ 撃破から取得を経て拡散で次の敵を倒すまで操作が止まらない(12.7)。件数が 7 に満たない書き方をしない
      - 9.17 は「実行」「終了コード」「配置と命名」「書き方」「CI」の各節に触れないことである。**変更を「仮ステージを目視で確認する」の節に閉じる**。`dev_stage.tscn` と `enemy_dev_stage.tscn` の記述も残す(用途が違うことの説明を含む)
      - 節の末尾の 3 つの箇条書き(`--headless` では確認できない / `run/main_scene` は変わらない / 目視の記録を `## Implementation Notes` へ残す)は残す
      - `git diff 01c1d0e -- docs/testing.md` を読み、差分が当該の節の中だけに収まっていることを確かめる
    - 検証コマンド: `git diff 01c1d0e -- docs/testing.md`(差分が「仮ステージを目視で確認する」の節に収まること)、`make test`

  - [ ] 6.2 仮ステージを起動して目視で確認し、結果を記録する
    _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_
    _Boundary: AnalysisDevStage_
    _Depends: 3.5, 5.3, 6.1_
    - 対象ファイル: `docs/specs/001-mvp/005-analysis-pickup/tasks.md`(変更。`## Implementation Notes` への追記のみ)
    - 仕様参照: spec.md §7 Requirement 12(検証の形式)、§3 前提
    - 実装の要点(タスク固有):
      - **本サブタスクは自動テストを書かない。** 要件 12 の 7 件は自動テストで検証しないと spec.md が定めている(`--headless` では画面が出ず目視にならない)
      - `godot --path <プロジェクトのルート> res://src/stage/analysis_dev_stage.tscn` を GUI の Godot で起動する。`make test` の経路とは別である
      - 7 件を順に確かめ、**いつ・どの環境(OS・Godot の版)で・何を確認したか**を `## Implementation Notes` へ記録する。記録しないと確認した事実が残らない
      - **12.3 では 20 度の広がりが 8 方向のどの向きでも見て取れることを記録する**(spec.md §3 の未検証の前提「拡散の角度 20 度が『拡散』として成立し、8 方向の照準と両立する」の判断材料になる)
      - **12.7 では所要時間と、強化が報酬に感じられたかを記録する**(同じく §3 の前提の判断材料)
      - §3 の未検証の前提 3 件(20 度の成立 / 毎秒 250 の火力で難度が崩れないか / 時間で消えない断片が「取りに行く」動機になるか)について、観測した所感を記録する。**崩れていた場合も自分で調整せず、記録して報告する**(調整の要否は人間が決める。`PlayerStats` の主武器の値ではなく拡散の角度・弾数で調整するのが spec.md の方針である)
      - 12.6(死亡してシーンが再読込された後に主武器が 1 発へ戻る)は、5.2 の 6.3 が自動テストで固定した状態のリセットとは別の経路(実機の再読込)の確認である。両方が同じ結果になることを見る
    - 検証コマンド: `godot --path . res://src/stage/analysis_dev_stage.tscn`(GUI。目視)

- [ ] 7. 凍結済みの契約の非変更の横断検査

  - [ ] 7.1 凍結対象が変わっていないことを git の差分で検査する
    _Requirements: 9.12, 9.13, 9.18, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9_
    _Boundary: repository_
    _Depends: 6.2_
    - 対象ファイル: `project.godot`(検査のみ), `src/`(検査のみ), `tests/`(検査のみ), `docs/specs/001-mvp/001-test-harness/`・`002-foot-player/`・`003-foot-enemies/`・`004-analysis-ability/`(検査のみ), `docs/specs/001-mvp/005-analysis-pickup/tasks.md`(検査の結果を `## Implementation Notes` へ追記する)
    - 仕様参照: spec.md §7 Requirement 9(9.12・9.13・9.18)・Requirement 11、本ファイルの「凍結の正本」の表
    - 実装の要点(タスク固有):
      - **正本は本ファイルの「凍結の正本」の表である。** 差分の基点は `01c1d0e`
      - 11.1・11.2・11.4・11.5・11.6・11.7・9.12・9.13 は `git diff 01c1d0e -- <対象>` が空であることで示す。対象は表のとおり(`project.godot`・`src/player/player_command.gd`・`player_input.gd`・`aim_resolver.gd`・`health.gd`・`src/weapon/primary_weapon.gd`・`secondary_weapon.gd`・`enemy_projectile.gd`・`projectile.tscn`・`src/enemy/`・`src/stage/dev_stage.*`・`enemy_dev_stage.*`・`damage_zone.*`・`src/player/player.tscn`)
      - 11.8 は `git diff 01c1d0e -- docs/specs/001-mvp/001-test-harness docs/specs/001-mvp/002-foot-player docs/specs/001-mvp/003-foot-enemies docs/specs/001-mvp/004-analysis-ability` が空であることで示す
      - **11.9 は `--diff-filter=MDR` を使う**(変更・削除・改名だけを見る。本単位が `tests/weapon/` へ足した新規ファイルは `A` であり、11.9 が禁じる「変更」に当たらない)。対象は unit #1〜#3 の既存テストと `tests/ability/ability_analysis_test.gd`。**unit #4 が足したテストのうち削除した 7 本は 11.9 の対象外である**(要件 10.7 が削除を命じている)。対象のパスを列挙するときにこの 7 本を含めない
      - 11.3 は `git diff` では固定できない(`player.gd` を変更するため)。`src/player/player.gd` の `signal fired(direction: Vector2i, is_secondary: bool)` の宣言行が `01c1d0e` の版と文字列として完全一致することを見る。振る舞い側の対はタスク 5.2 の 4.4 と 5.3 の 5.2 が持つ
      - 9.18 は本単位が足した・作り直したテストが `docs/testing.md`「配置と命名」に従うことである。`tests/` 直下にあり、実装のディレクトリ構成を写したパスにあり、ファイル名が `_test.gd` で終わり、テストケース名が `test_` で始まることを確かめる。**引数を取るテストケースが 1 つも無いこと**もあわせて確かめる(`skipped` が 0 であることの根拠)
      - 最後に `make test` を全体で走らせ、統計行の `orphans`・`skipped`・`failures`・`errors` がすべて 0 であることと、スイート数・ケース数を `## Implementation Notes` へ記録する(基線は 594 cases / 37 suites。削除 7 本・新設 5 本で 35 suites になる見込み)
      - 差分が見つかった場合は、その差分が本単位の計画に含まれるかを「凍結の正本」の表と照合する。含まれないなら**戻さずに報告する**(意図せぬ変更の原因を人間が判断する)
    - 検証コマンド: `make test`、`git diff --stat 01c1d0e`

## Implementation Notes

### 注入した知識 port

`python3 .claude/skills/dev-core/scripts/ports.py --skill dev-implement --root docs/dev/ports` の走査結果は 1 件。

| name | パス | condition | 判定 |
| ---- | ---- | --------- | ---- |
| `mutation-discipline` | `docs/dev/ports/mutation-discipline.md` | 常時 | 全サブタスクへ注入する(`inject` に dev-implement があり `condition: 常時`)。本ファイル「全タスク共通の実装の規律」も同 port を指している |

`_Knowledge:` 注記を持つサブタスクは無い。条件付き port も存在しないため、全サブタスクで注入は上の 1 件である。

### 実装前の基線

- `make test`: 594 test cases / 37 suites / errors 0 / failures 0 / flaky 0 / skipped 0 / orphans 0(実測)。
- `check.py`(`--def .claude/skills/flow-sdd/workflow.json --ports-root docs/dev/ports`): error 0 / warning 0。

### タスク 1.1 の学習

- **静止した `CharacterBody2D` を重ねて置くだけで `body_entered` は届く**(実測)。移動も `move_and_slide()` も要らない。通知は 1〜2 物理フレーム目に来る。後続の接触系のタスクはこの形で駆動できる。
- **「操作を止めない」(`SceneTree.paused`)の検出力は、同期の接触(`body_entered.emit()`)で、しかも両方向で見る。**
  - 停止を**立てる**変異(`paused = true` の挿入)は、実フレームで駆動するケースを待ちへ変えるため、失敗ではなく **120 秒のタイムアウト(exit 124)** として現れる。同期の接触のケースを実フレームのケースより**前**に置くと、そのケースが FAILED として報告される。
  - 停止を**落とす**変異(`paused = false` の挿入)は、既定(偽)のところでしか観測していないと**一切現れない**(規律 1)。既定のところでの接触と `paused = true` を置いたところでの接触の 2 つを 1 ケースに並べると、どちらの向きも同じケースが落とす。
  - `Engine.time_scale` は物理を止めないため実フレームのままでよい(非対称の理由)。ただし既定と別の値(0.5)から始める点は同じ。
  - 停止のケースはポーズを観測した直後に**テスト本体で**元へ戻す(`after_test()` の復元だけに頼ると、同じスイートの後続のケースが物理フレームを消化できなくなる)。
- 断片はシーンを持たなくても振る舞いを検証できる。テストは `collision_layer`/`collision_mask`/当たり判定をテスト側で組み立て、シーンの契約(1.2)を先取りしない。
- レビューの `[FYI]`: 既存の `tests/ability/analysis_pulse_test.gd` の `_assert_the_time_stays_untouched()` も `paused` を既定側だけで見ており、同じ穴を持つ。ただし同スイートはタスク 3.4 で削除されるため対処しない。

### タスク 1.2 の学習

- **シーンの寸法・原点を見る検査は「値」と「親」を対にする。** `position == Vector2.ZERO` を保ったまま、ずらした中間ノードの下へ移す変異は、値だけの検査を素通りする。後続のシーン検証タスク(2.3 等)でも、`position` を見るなら「その `position` の基準がどのノードか」を同じケースで固定する。
- **`ColorRect.position` は矩形の左上、`CollisionShape2D.position` は形の中心を指す。** ゆえに「原点が中心」の表し方が前者は `-size * 0.5`、後者は `Vector2.ZERO` と非対称になる。同じ式で書こうとすると誤る。
- 7.14 の比較対象 9 シーンから読める相異なる色は **8 色**(プレイヤー・突進型・射撃型・味方の弾・敵弾・ダメージ帯・床壁・足場)。断片の色 `Color(0.85, 0.45, 0.95, 1)` はいずれとも一致しない。テストは下限 8 を番人に持ち、9 シーンのどれか 1 つを一覧から落とすと落ちる。
- **`analysis_fragment_scene_test.gd` は 7.14 の比較のために `src/stage/analysis_dev_stage.tscn` を `load()` する。** そのため `analysis_dev_stage.tscn` の `ext_resource` が壊れると本スイートも赤になる。タスク 3.4(`analysis_pulse.tscn` の削除)は 2.2(`ext_resource` の差し替え)より後でなければならないという既存の順序制約が、この経路からも効く。
- ツリーへ載せずに `ColorRect` の `size`/`position` を読む形は、anchors が既定の 0 かつ親が `Area2D` で anchorable rect が 0 のため、載せたときの値と一致する(レビューの `[FYI]`)。
- レビューの `[FYI]`: ヘルパ `_placeholder()`/`_collision_shape()` は件数のアサーションが失敗しても添字へ進むため、0 件のときは失敗メッセージでなく実行時エラーになる(gdUnit4 は赤にするため検出力は落ちない)。

