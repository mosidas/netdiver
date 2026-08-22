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

  - [x] 2.1 (P) 2 つ目の仮ステージとそのテストを削除する
    _Requirements: 9.14_
    _Boundary: AnalysisDevStage_
    - 対象ファイル: `src/stage/analysis_overwrite_dev_stage.tscn`(削除), `tests/stage/analysis_overwrite_dev_stage_test.gd`(削除), `tests/stage/analysis_overwrite_dev_stage_test.gd.uid`(削除)
    - 仕様参照: spec.md §5.6、§8「仮ステージを 1 つに統合する」、§7 Requirement 9
    - 実装の要点(タスク固有):
      - **使用ゼロを確認してから削除する**: `analysis_overwrite_dev_stage` を指す参照が `src/`・`tests/`・`docs/`・`project.godot`・`main.tscn` に無いことを削除の前に確かめる(`docs/testing.md` は残るが、その書き換えはタスク 6.1 が持つ。この時点では起動方法の記述が残ることを許す)
      - 紐づく生成物を消し忘れない: `.tscn` に `.uid` は付かないが、テストの `.gd` には付く
      - 削除の後に `make test` の統計行の `orphans`・`skipped`・`failures`・`errors` がすべて 0 であることを確かめる
    - 検証コマンド: `make test`

  - [x] 2.2 `AnalysisDevStage` のハンドラを断片の生成へ作り直す
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

  - [x] 2.3 `analysis_dev_stage.tscn` の構成と配置規約を固定する
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

  - [x] 3.1 `Player` から第 3 の枠を撤去する
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

  - [x] 3.2 `AbilitySlot` を削除する
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

  - [x] 3.3 `PlayerStats` から `ability_*` の 4 項目を削除する
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

  - [x] 3.4 (P) `AnalysisPulse` とそのシーンを削除する
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

  - [x] 3.5 撤去の完了を識別子と統計行で検査する
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

  - [x] 4.1 (P) `SpreadResolver` を 20 度の回転で作り直す
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

  - [x] 4.2 (P) `Projectile.launch()` の `direction` を `Vector2` へ広げる
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

  - [x] 4.3 凍結済み文書との乖離を doc コメントとコミットログへ反映する
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

  - [x] 5.1 強化の状態(`is_primary_upgraded`・`grant_upgrade()`)と死亡でのリセットを入れる
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

  - [x] 5.2 強化中の主武器を拡散の 3 発にする
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

  - [x] 5.3 強化中の副武器の弾に `upgraded_secondary_tint` を掛ける
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

  - [x] 6.1 `docs/testing.md` の「仮ステージを目視で確認する」を書き換える
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

  - [x] 6.2 仮ステージを起動して目視で確認し、結果を記録する
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

  - [x] 7.1 凍結対象が変わっていないことを git の差分で検査する
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

- [ ] 8. 最終検証パネルの NO-GO の解消(dev-implement 14. の修正タスク)

  2026-08-22 の最終検証パネルが返した `[Critical]` 5 件を閉じる。**人間の承認済みの範囲**は「テストのケース追加 4 件 + 実装 1 行の遅延化 1 件」であり、`spec.md` は変更しない・凍結済み文書は変更しない・unit #1〜#3 のテストは変更しない・拡散の角度と弾数と威力は調整しない。指摘の本文は `## Implementation Notes` の `### 最終検証パネルの結果(2026-08-22)— NO-GO` にある。

  **1 サブタスク = 1 コミット**とする(打ち切りで失う範囲を限るため)。各サブタスクは、修正前に変異を仕掛けて生存を実測し、修正後に同じ変異で死亡することを実測して `## Implementation Notes` へ記録する(規律の正本は本ファイルの「全タスク共通の実装の規律」)。

  - [ ] 8.1 `Player` のスクリプト変数をちょうどの個数で固定する(C1)
    _Requirements: 3.9_
    _Boundary: Player_
    _Depends: 7.1_
    - 対象ファイル: `tests/player/player_upgrade_test.gd`(変更。ケースと定数の追加のみ。既存ケースを弱めない)
    - 仕様参照: spec.md §6.2「主武器の強化の状態(`Player`)」、§7 Requirement 3(3.9)
    - 実装の要点(タスク固有):
      - 現状の 3.9 の検査は名前の拒否リスト(13 語)と `upgrad` を含む項目の型しか見ておらず、リストに当たらない名前の状態(例: 残り回数)を素通りする
      - **同スイートが 3.8 で既に使っている「ちょうどの個数」の形**(`_script_variables(command).size()` を定数と突き合わせる)を `Player` へ適用する。ヘルパ `_script_variables()` は同スイートに実在する
      - `Player` のスクリプト変数は 10 個である(`stats`・`projectile_scene`・`upgraded_secondary_tint`・`health`・`facing`・`is_primary_upgraded`・`input_source`・`_is_primary_upgraded`・`_primary_weapon`・`_secondary_weapon`)。**期待する名前の集合も並びとして固定する**: 個数だけだと、1 つ消して 1 つ足す変異が素通りする
      - 名前の拒否リストの検査は**残す**(個数の検査と目的が違う。既存の項目を残り回数つきの意味へ改名する変異は個数では落ちない)
      - 変異で確かめる(規律): `src/player/player.gd` へ `var _burst_budget: int = 999` を足すと落ちること。修正前は `make test` が緑のまま生存することも先に実測する
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 8.2 `PlayerStats` の項目数と `ability_*` の不在を新設スイートで固定する(C2)
    _Requirements: 10.4, 10.5, 10.6_
    _Boundary: PlayerStats_
    _Depends: 7.1_
    - 対象ファイル: `tests/player/player_stats_removal_test.gd`(新規。`.uid` と対でステージする)
    - 仕様参照: spec.md §6.5「`PlayerStats`(unit #2 §6.1 の 14 項目へ戻す)」、§7 Requirement 10(10.4・10.5・10.6)
    - 実装の要点(タスク固有):
      - **凍結済みの `tests/player/player_stats_test.gd` を改訂しない**(要件 11.9・11.11)。`tests/weapon/projectile_direction_test.gd` と同じ手段で、同じディレクトリへ別のスイートを足す(追加は 11.9 の禁じる「変更」に当たらない)
      - 10.5 は `@export`(`PROPERTY_USAGE_EDITOR` かつ `PROPERTY_USAGE_SCRIPT_VARIABLE`)の項目が **14 個ちょうど**であることと、その並びが unit #2 の 14 項目と一致することで見る。凍結スイートの `contains()` は非排他であり、15 個目を足す変異を素通りする
      - 10.6 は `src/` 配下の `.gd`・`.tscn`・`.tres` を走査し、9 語(`AbilitySlot`・`AnalysisPulse`・`ability_slot`・`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`・`ability_fired`・`grant_ability`)が 1 件も現れないことで見る。**現状はリポジトリ内に自動の検査が無く、実装時の 1 度の grep にしか依存していない**
      - **走査が空振りしていないことを陽性対照で固定する**(規律)。走査したファイルが 0 件でないこと、および必ず存在する語(`PlayerStats`)が 1 件以上見つかることを同じ走査で確かめる。空振りのまま緑になると、検査が何も見ていない
      - 10.4 は削除した 4 項目(`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`)が `PlayerStats` の項目に無いことで見る(10.5 の並びの一致と対で置く)
      - 走査の対象に `tests/` を含めない: このスイート自身が 9 語を字面で持つため、自己成就で落ちる
      - 変異で確かめる(規律): `src/player/player_stats.gd` の末尾へ `@export var ability_uses: int = 3` を足すと落ちること(10.5 と 10.6 の両方が落ちる)
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 8.3 境界のすぐ外の向きを拒否しないことを固定する(C3)
    _Requirements: 2.6_
    _Boundary: Projectile_
    _Depends: 7.1_
    - 対象ファイル: `tests/weapon/projectile_direction_test.gd`(変更。定数とケースの追加のみ)
    - 仕様参照: spec.md §5.2「`Projectile`」、§7 Requirement 2(2.6)
    - 実装の要点(タスク固有):
      - 現状の `UNNORMALIZED_DIRECTIONS` は `Vector2(0.3, 0.0)`・`Vector2(3.0, 1.0)` の 2 件で、どちらも `CMP_EPSILON`(1e-5)より十分大きい。**境界のすぐ外の値を 1 つも置いていない**(規律 6)
      - `Vector2(0.000001, 0.0)` を足す。この値は `Vector2.ZERO` と等しくないが `is_zero_approx()` は真を返すため、ガードを `is_zero_approx()` へ変える変異がここで落ちる(パネルが隔離複製で実測済み)
      - **境界のすぐ外であること自体を番人のケースで固定する**: `is_zero_approx()` が真であり、かつ `== Vector2.ZERO` が偽であることを見る。定数を大きな値へ書き換える変更はここで気付く
      - `_assert_travelled_along()` は `direction.normalized()` を期待値に使うため、極小の向きでも進んだ向きまで見られる(`Vector2(0.000001, 0.0).normalized()` は `(1, 0)`。実測済み)
      - 変異で確かめる(規律): `src/weapon/projectile.gd` の `if direction == Vector2.ZERO:` を `if direction.is_zero_approx():` へ変えると落ちること
    - 検証コマンド: `make test TESTS=res://tests/weapon`

  - [ ] 8.4 `fired` のシグナル宣言を読む検査を置く(C4)
    _Requirements: 11.3_
    _Boundary: Player_
    _Depends: 7.1_
    - 対象ファイル: `tests/player/player_upgrade_test.gd`(変更。ケースと定数の追加のみ)
    - 仕様参照: spec.md §5.3「`Player`」、§7 Requirement 11(11.3)、本ファイルの「凍結の正本」の表の 11.3 の行
    - 実装の要点(タスク固有):
      - GDScript はシグナルの宣言型を発火時に強制しないため、**振る舞い側のケースは値の型しか観測できない**。宣言を `direction: Vector2` へ変える変異は全体緑のまま生存する(パネルが実測)
      - `Object.get_signal_list()` の `fired` の要素は `args` に宣言どおりの `name` と `type` を持つ(`direction` が `TYPE_VECTOR2I`、`is_secondary` が `TYPE_BOOL`。実測済み)。これを読むケースを置く
      - 引数の**名前・型・並び・個数**の 4 つを固定する(個数を見ないと、3 つ目を足す変異が素通りする)
      - 同スイートは既に `[input]` 節の sha256 で凍結の検査を持っており、置き場として整合する
      - 実装の宣言行を文字列として読む形は採らない: 型を検査したいのであって字面ではなく、`get_signal_list()` のほうが空白・書式の揺れに強い
      - 変異で確かめる(規律): `src/player/player.gd:11` の `direction: Vector2i` を `direction: Vector2` へ変えると落ちること。`is_secondary: bool` を `int` へ変えても落ちること
    - 検証コマンド: `make test TESTS=res://tests/player`

  - [ ] 8.5 断片の追加を遅らせ、テストを遅延の後の観測へ改める(C5)
    _Requirements: 8.1, 8.2, 8.3_
    _Boundary: AnalysisDevStage_
    _Depends: 7.1_
    - 対象ファイル: `src/stage/analysis_dev_stage.gd`(変更), `tests/stage/analysis_dev_stage_test.gd`(変更)
    - 仕様参照: spec.md §5.6「`AnalysisDevStage`」、§7 Requirement 8(8.1・8.2・8.3)
    - 実装の要点(タスク固有):
      - 実機では写せる種別の撃破のたびに `ERROR: Can't change this state while flushing queries.` が 1 回出る(8/8 回で再現)。`defeated` は `Hurtbox.body_entered` から届くため、ハンドラは**物理コールバックの最中に走る**。そこで `Area2D` を木へ載せると、走査の最中に監視の状態を変えることになる
      - **`spec.md` §5.6 と要件 8.1・8.3 は追加の時期を定めていない**。定めているのは「ステージ自身の子として追加してから位置を置く」という順序であり、遅延して追加しても判定内容は変わらない。**したがって契約の変更に当たらない**(人間の確定済みの判断)
      - 同じファイルの `_on_player_died()` が同一の危険を理由に既に `call_deferred` を採っている。**同じ対処を採るのがプロジェクト自身の規律と整合する**
      - **位置は遅延の前に読む**: 撃破された敵は `defeated` の直後に `queue_free()` されるため、遅延した先で `enemy.global_position` を読める保証が無い。撃破時点の値が要件 8.2 の言う「撃破された敵の `global_position`」である
      - **生成も遅延の中で行う**: ステージがこのフレームで解放された場合、遅延した呼び出しは丸ごと捨てられ、木に載らない断片が孤児として残らない(`orphans` を 0 に保つ。要件 10.10)
      - **`push_error`(要件 8.9)は同期のまま**にする: `fragment_scene` の未設定はハンドラの呼び出しの中で報せる。遅らせると `assert_error()` の窓の外へ出る
      - `src/stage/analysis_dev_stage.gd` に `EnemyKind` の語と `PICKUP_SYMBOLS`(`_player(`・`Player`・`grant_upgrade`・`grant_ability`)を書かない(既存の静的検査が禁じている)
      - テストは 8.1・8.3 を「遅延の後に子が 1 つ増える」形へ改める。**あわせて「ハンドラ自身の呼び出しの中では増えない」ことを直接観測するケースを 1 本置く**(`test_the_handler_runs_no_reload_inside_its_own_call` と同型。これが無いと同期の追加へ戻す変異が落ちない)
      - 断片が出ないことを見る側のケース(8.4・8.9・8.10)も**遅延の後まで見る**: 同期の時点だけを見ると、遅れて出る実装を「出ない」と誤って読む
      - 変異で確かめる(規律): 遅延を同期の `add_child()` へ戻すと落ちること。位置の読み取りを遅延の中へ移すと落ちること(敵が解放済みで読めない)
    - 検証コマンド: `make test TESTS=res://tests/stage`、`make test`、`godot --path . res://src/stage/analysis_dev_stage.tscn`(GUI。`ERROR` が 0 件であること)

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

### タスク 2.1 の学習

- **`.tscn` を消す前にヘッダの `uid=` の有無を見ると、確認すべき範囲が決まる。** `analysis_overwrite_dev_stage.tscn` はヘッダに `uid=` を持たなかった(`[gd_scene load_steps=7 format=3]`)ため、uid 経由の参照は原理的に無く、パス文字列の検索だけで参照ゼロを結論づけられた。
- 削除した 2 つ目のシーンは `src/stage/analysis_dev_stage.gd` を `ext_resource` で参照していた(**2 つのシーンが 1 つのスクリプトを共有していた**)。スクリプトは 1 つ目のシーンが引き続き使うため残す。
- 削除の巻き添えは統計の**差分**で検出できる。消したスイートの `func test_` の実数(21)とケース数の減少幅が一致することを見る。
- タスク 6.1 へ: `docs/testing.md` に 2 つ目のシーンの起動方法が残っている(実ファイルは既に無い)。6.1 は「消えたファイルへの案内」を取り除く作業になる。

### タスク 2.2 の学習

- **`Player` を継承する記録用スタブが 8.15 の検出の要である。** ランタイム生成の `GDScript`(`extends Player`)を `.new()` で作り、`grant_upgrade()`/`grant_ability()` の呼び出しを配列へ控えて木へ載せる。型で子を引く実装(`child is Player`)を捕らえるには受け手が本物の `Player` 型である必要がある一方、スタブ側で名前を定義するため、**タスク 3.1 が `Player.grant_ability()` を消してもこのスイートは壊れない**(消えた識別子を参照していない)。`set_physics_process(false)` を立てれば、当たり形状を持たない `.new()` 生成でも実行時のエラーは出ない。
- **静的検査は「禁止」だけでなく「委譲の存在」も見ないと穴が残る。** 種別の名前を出さない直値比較(`kind != 1`)は禁止側の検査(`EnemyKind` を含まないこと)を素通りした。`AbilityAnalysis.is_transferable(` を含むことを見るケースで初めて落ちた。
- **ガードの順序が要件そのものである**(8.9 と 8.10)。種別の判定 → `fragment_scene` の判定の順にしないと 8.10 が壊れる。順序を入れ替える変異は 8.10 のケース 1 本でしか落ちない。
- レビューの `[Nit]`: 新スイートの `PICKUP_SYMBOLS` が `"Player"` を含むため、ステージのソースは doc コメントであっても `Player` の語を書けない。8.15 が禁じるのは「プレイヤーを引いて呼ぶ処理」であって語の言及ではないため、将来の doc コメントで誤って赤になりうる。現状は緑のため対処しない。
- レビューの `[FYI]`(等価変異。規律 7 により記録のみ): 8.5 の静的検査は文字列包含の代理であり、`AbilityAnalysis.is_transferable()` を呼びつつ**加えて**独自の種別比較を書く変異は 2 つの静的検査を両方すり抜ける。定義済みの 2 種別については振る舞いの 2 ケースが挙動を縛るため実害は残らないと判断した。

### タスク 2.3 の学習

- **`PackedScene` の `@export` は値ではなく `get_property_list()` の `class_name` で数える。** `node.get(name) is PackedScene` で集めると、宣言が残ったまま値だけ外された `@export`(消し残り)を見落とす。実測では `pulse_scene` を値なしで復活させる変異がこの区別なしでは生存した。
- **`ColorRect.global_position` はツリーへ載せなくても親の `Node2D` の変換まで解決される。** `instantiate()` しただけの状態で床・アクタの大域の矩形を読める(タスク 1.2 の知見が `size`/`position` だけでなく `global_position` にも及ぶ)。
- **水平と垂直を別ケースに分けると、片方の軸だけを壊す変異がどちらのケースを落としたかで区別できる。** 床を横に縮める変異は水平ケースのみ、アクタを浮かせる変異は垂直ケースのみを落とした。unit #4 の `[Nit]`(床を水平に縮めても緑)はこれで閉じた。
- **`.tscn` を検査するスイートの変異は、ステージの `.tscn` の外にあることがある。** 「アクタの見た目だけが床へ沈む」変異の宣言先は `player.tscn` である。ステージの `.tscn` だけを変異させる計画だと、この観点は測れないまま「生存ゼロ」と報告してしまう。
- 検査はすべて現行の `.tscn` に対して最初から緑であり、`.tscn` は変更していない(unit #4 の座標・構成・色のままで 9.2〜9.7 を満たすという分解時の見立てが実測で確認された)。
- **等価変異域(規律 7 により記録のみ、対処しない)**: 9.3(脅威の圏内は 2 体まで)は、敵が 2 体しか居ない現在の配置では 9.2 の体数の検査に構造的に含意される。「3 体目を足す」変異は実際には 9.2 の体数アサーション(`EXPECTED_ENEMY_COUNT == 2`)が殺しており、閾値のロジックが殺したのではない。9.2 を破らずに 9.3 だけを落とすことはできない。
- レビューの `[Nit]`: 9.5(水平)は各アクタの `ColorRect` だけを見ており、当たり矩形の水平方向を見ていない(9.6 は当たりと見た目の両方を見る)。`CollisionShape2D.position.x` を横へずらす変異は生存する。タスク定義の要点に従った形であり要件違反ではないため対処しない。
- レビューの `[Nit]`: `test_no_enemy_appears_while_the_stage_runs` の観測時間 200ms は、射撃型の `telegraph_time` 0.4 と弾速 120 に暗黙に依存する。本単位では stats を触らないため実害はない。

### タスク 3.1 の学習

- **`Player` から枠を落とした後、`src/` の中で `stats.ability_*` を読む箇所は無くなった**(宣言のみ `src/player/player_stats.gd` に残る。実測)。タスク 3.3 は宣言の削除だけで足りる。
- `AbilitySlot` を参照するのは `src/ability/ability_slot.gd` 自身と `tests/ability/ability_slot_test.gd` だけになった(タスク 3.2 への申し送り)。
- `SpreadResolver` を参照するのは `src/ability/spread_resolver.gd` 自身と `tests/ability/spread_resolver_test.gd` だけになった。据え置いたので無検証の期間は生じていない(タスク 4.1 への申し送り)。
- **「副武器の素通しへ戻す」の検出力は、変更しない unit #2 のスイートが持つ。** `_secondary_weapon.update(cmd.secondary_held, delta)` を `update(false, delta)` にする変異で `tests/player/player_weapon_test.gd` の 5 ケースが落ちることを実測した。本単位が新しいテストを足さなくても、戻し損ねは既存スイートが捕らえる。
- レビューの `[FYI]`: `tests/stage/analysis_dev_stage_test.gd` の記録用スタブ(`extends Player`)が宣言する `grant_ability()` は、基底から同名メソッドが消えたためオーバーライドでなく新規メソッドになった。GDScript ではエラーにならず同スイートは緑のまま。
- リポジトリのルートに GDScript の formatter 設定(gdformat/gdlint)は無く、CI にも整形ステップが無い。既存ファイルの体裁(タブ・トップレベル定義間の空行 2 行)へ合わせる。

### タスク 3.2 の学習

- **削除タスクの検算式**: 「ケース数の減少幅 == 削除したスイートの `func test_` の実数」「スイート数の減少幅 == 削除したテストファイル数」。これで消しすぎ・消し足りない・参照の宙吊りの 3 つの失敗モードを検出できる。
- **`.uid` の中身(`uid://...`)を検索語にする確認が有効。** `.uid` は `.tscn` の `ext_resource` から参照されうるため、識別子名の検索だけでは宙吊りを見落とす。
- **`.godot/global_script_class_cache.cfg` に削除したクラスのエントリが残る。** これは `.gitignore` 済みの生成物であり、以降の削除タスクでこのキャッシュのヒットを参照残存と誤判定しない。
- 3.3 への申し送り: `src/player/player_stats.gd` の `ability_*` 4 項目を読む箇所は、これでテスト側だけになったはず。削除前に `ability_uses|ability_cooldown|ability_damage|ability_bullet_speed` を `src`・`tests` で再検索し、残る読み手が同時削除対象のテストに限られることを確かめる。

### タスク 3.3 の学習

- 削除は 4 宣言と区切りの空行だけで足りた。既存 14 項目は HEAD とバイト単位で同一であり、`src/player/player.gd` は変更していない(`_report_non_positive_stats()` は `get_property_list()` から導くため、項目が減れば検査対象も自動で減る)。
- 11.12 の検出力は、変更しない `tests/player/player_stats_test.gd` が単独で持つ。`regen_delay` の既定値を 3.0 → 4.0 にする変異で `test_player_stats_health_defaults` が落ちることを実測した。

#### 対処しないと決めた検出力の欠陥(規律 7 により記録のみ)

1. **要件 10.5(「14 項目ちょうど」)は非排他な検査しか無い。** `tests/player/player_stats_test.gd` は `assert_array(...).contains(STAT_NAMES)` で「含むこと」だけを見るため、**`PlayerStats` に 15 項目目を足す変異は全体が緑のまま生存する**。要件 11.9 が同スイートを凍結しているため改訂で塞げない(塞ぐと要件違反になる)。タスク 3.5 の grep は `ability_*` の 4 語については補うが、**別名の 15 項目目は捕らえられない**。等価変異ではない、残る欠陥である。
2. **削除で失われた検出力。** 消した `tests/player/player_ability_stats_test.gd` の `test_ready_checks_an_ability_stat_the_implementation_cannot_know_by_name` は、`PlayerStats` を継承して実装が名前で知りようのない項目を足し、`Player._report_non_positive_stats()` が `stats.get_property_list()` から検査対象を導いていることを固定する**リポジトリ内で唯一のケース**だった(`tests/player/player_move_test.gd` は 14 項目の固定リストしか見ていない)。削除後に生存する変異は「同関数を 14 項目の名前を固定で列挙して回すループへ書き換える」。要件 10.7 が削除を命じているため対処しない。**後続で `PlayerStats` に項目を足す・派生させる作業が入る場合、`Player` の検査が新項目を素通りする退行を誰も捕らえられない**ことを前提にすること。

### タスク 3.4 の学習

- `analysis_pulse.tscn` はヘッダに `uid=` を持たなかった(`[gd_scene load_steps=2 format=3]`)。**unit #4 期に生成されたシーンにはシーン uid が振られていない個体がある**ため、「ヘッダを見てから確認範囲を決める」手順が有効。
- **削除タスクの検算式は 3.1〜3.4 の 4 回連続で成立した。** 削除の巻き添えと消し漏れの両方向のずれをこの式が捕らえる。
- 削除の後、`tests/ability/analysis_fragment_scene_test.gd`(`analysis_dev_stage.tscn` を `load()` する)と `tests/stage/analysis_dev_stage_scene_test.gd` が緑であることを確認した。2.2 の `ext_resource` 差し替えが済んだ後に削除するという順序制約は守られている。

### タスク 3.5 の撤去の検査(実測)

| 要件 | 検査 | 結果 |
| ---- | ---- | ---- |
| 10.6 | `src/` の `.gd`/`.tscn`/`.tres` 41 ファイル(`.gd` 28 / `.tscn` 11 / `.tres` 2)に対し 9 語(`AbilitySlot`・`AnalysisPulse`・`ability_slot`・`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`・`ability_fired`・`grant_ability`)を検索 | 0 件。**偽陰性の排除**として同じ glob で残すべき語(`AbilityAnalysis`・`ability_analysis`)の陽性対照を取り 3 件ヒットすることを確認 |
| 10.7 | spec.md が列挙する 7 本のテストの不在(`tests/player/player_spread_test.gd` は列挙に含まれない) | 7 本すべて不在。`.uid` の取り残しも無し(`git ls-files` で二重確認) |
| 10.8 | **静的な側のみ**。`Player` の宣言と `player.tscn` に枠を表す項目・シグナルが無いこと | スクリプト変数 7・シグナル 2(`died`・`fired`)。武器のフィールドは `_primary_weapon`・`_secondary_weapon` の 2 つちょうど |
| 10.9 | `git diff 01c1d0e -- src/ability/ability_analysis.gd tests/ability/ability_analysis_test.gd` | 0 バイト(空)。両ファイルは現存し非零サイズであり「両方消えていて差分が空」ではないことも確認 |
| 10.10 | `make test` の統計行 | **486 cases / 31 suites / errors 0 / failures 0 / flaky 0 / skipped 0 / orphans 0 / exit 0**。見込みの 31 suites と一致(基線 37 + 各サブタスクの増減の総和) |

#### 10.8 を静的側だけに留めた記録(規律 3 に対する意図的な部分検査)

- **振る舞い側は本サブタスクでは扱わない。** 「第 3 の枠を表す状態を持たない」ことの振る舞いは、要件 4.8(強化していない間の主武器は 1 発)・5.1/5.10(副武器が常に素通し)が担い、**タスク 5.2・5.3 が固定する**。
- **手段を実行時実測からソース読解へ替えた。** `get_property_list()`/`get_signal_list()` を実測するには `class_name Player` を解決するスクリプトを `res://` 配下(= リポジトリの中)に置く必要があり、「検査タスクはファイルを変更しない」制約と両立しないためである。レビューが独立に確認したところ、`src/player/player.gd` には動的プロパティ(`_get_property_list()`/`_set`/`_get`)・`add_user_signal()`・スクリプトの継承(`extends CharacterBody2D` = エンジン型直下)のいずれも無く、**この場合に限り静的読解は実行時実測と同じ被覆を持つ**。
- **静的側だけで残る穴(5.2・5.3 への申し送り)**: (a) `set("<名前>", ...)`・`set_meta()` による動的な状態の付与は宣言を読む形では原理的に捕らえられない。(b) 枠が `Player` の外(ステージ・HUD・オートロード等)に置かれる形は見ていない。(c) 既存フィールドの再利用で枠を表す形(武器を配列で持ち 3 要素目を使う等)は、実行時に発射経路が 2 系統ちょうどであることを観測していない。**5.2・5.3 の振る舞いケースでは「主武器・副武器の 2 系統以外の発射が起きないこと」を実際に駆動して観測する**(`fired` の `is_secondary` が true/false の両側のみを取る形が規律 2 とも噛み合う)。
- レビューの `[FYI]`: 10.8 の振る舞い側は現時点で `tests/player/player_spread_test.gd` が不在のため未検証区間にある。ただし変更しない `tests/player/player_weapon_test.gd`(unit #2 由来)が主武器・副武器の発射挙動を押さえており、完全に無防備ではない。

### タスク 4.1 の学習

- **画面座標(y は下向き)では `Vector2.rotated()` の正の角が時計回りに対応する。** ゆえに 2 番目(反時計回り)は負の角である。実装は `center.rotated(-offset)` を 2 番目に置く。
- **1.10 の「呼び出し側に 20 を置かない」は、数値 `20` の走査ではなく字面(`SPREAD_DEGREES`/`spread_degrees`/`deg_to_rad`/`rotated(`)の走査で行った。** 理由は `player_stats.gd` の `regen_per_second` が既に `20.0` であり、数値だけでは拡散の角度と区別できないためである。**タスク 5.2 が `player.gd` に拡散の発射を足すときは、`SpreadResolver.resolve()` の戻り値を順に撃つだけにする**(角度の再計算を `player.gd` に書くとこのケースが落ちる)。
- レビューの `[FYI]`(残る穴): 字面走査は `player.gd` に回転済みのベクトル定数(例 `Vector2(0.9397, -0.342)`)を直書きする形を捕らえられない。振る舞い側の対(`SPREAD_DEGREES` が実際に `resolve()` の角度を決めること)が効いているため本タスクでは実害なしと判断した。**5.2 が `Player` 側の振る舞いを固定するときに併せて確認する**。
- 1.13(照準は 8 方向のまま)は静的な検査 2 つ(`resolve()` の引数型と `src/player/aim_resolver.gd` の sha256)で固定している。**振る舞い側の対(要件 4.4 の `fired` の `direction` が 8 方向)はタスク 5.2 が必ず持つこと**(規律 3)。
- 凍結の照合に使った `src/player/aim_resolver.gd` の sha256 は `fdc1323f0c696e46898f9241bee351feebd3d5dd54978203faf43c1d3048cea9`(`01c1d0e` 時点)。レビューが独立に照合済み。**後続の unit が同ファイルへ手を入れる場合はこの定数の更新が要る**。
- **等価変異(規律 7 により記録のみ)**: 事前条件のガードで `absi(x) <= 1` と `absi(x) < 2` は整数では完全に同値であり、原理的に落とせない。実際に緩む形(`absi(x) <= 2` 相当)を注入して落ちることを確かめた。
- gdUnit4 には `is_not_equal_approx` が無い。「近くない」ことは `assert_float(absf(angle)).is_greater(<許容>)` で書く。
- `SpreadResolver.new().get_method_list()` は static な `resolve` を含み、`args[0]["type"]` が `TYPE_VECTOR2I`(6)として読める(Godot 4.7.1 で実測)。

### タスク 4.2 の学習

- **`direction == Vector2.ZERO` を採った**(`is_zero_approx()` ではない)。凍結済みの `EnemyProjectile.launch()` が同じ形であり、2 種の弾の契約が字面まで揃う。`is_zero_approx()` は長さ 1e-5 未満の非ゼロを弾くため、要件 2.6(短さを理由に拒否しない)に対して字義どおりには外れる。**等価変異(規律 7)として、この選択を固定するテスト(極小の非ゼロ向き)は意図的に置いていない。**
- **「2.2 の 8 方向だけでは丸めの変異が素通りする」ことを実測した。** `direction.sign().normalized()` へ置き換える変異は、軸と斜めが不動点になるため 2.2 のケースを緑のまま通し、2.3(20 度・65 度等)のケースだけが落ちる。
- **`Vector2` 型の実引数を `Vector2i` の仮引数へ渡す誤りは、GDScript の静的解析ではパースエラーにならず実行時にケースが失敗する形で現れる**(切り捨てで `(0,0)` になりゼロのガードに掛かる)。スイート全体がパースエラーで落ちるわけではないので、RED の切り分けは通常どおり行える。
- 拡散(タスク 5.x)で使う 20 度は `Vector2.RIGHT.rotated(deg_to_rad(20.0))` で作れる。65 度・112.5 度・200 度・-20 度でも変位が正規化された向きと 0.001 の許容差で一致することを実機で確認した。
- 速さを実測の変位から戻すアサーションの許容差は 0.01 で安定した(float32 の累積誤差の実測は 1e-3 程度)。
- **タスク 4.3 への申し送り(必須)**: `launch()` の `##` doc コメントは今も「`direction` は `Vector2i.ZERO` 以外」と書いており、実装(`Vector2.ZERO`)と食い違っている。4.3 は型を広げたことと文言据え置きの理由に加え、**この事前条件の記述の訂正**も行う。
- レビューの `[Nit]`: 新スイートは凍結スイートと `_assert_stays_in_place`・`_frame_step`・文言定数・レイヤ定数を重複して持つ。共通ヘルパへの抽出は凍結側の改訂を要するため現時点では許容する。

### タスク 4.3 の学習(凍結済み文書との乖離の反映)

spec.md §8 が定める反映先 3 つの確認結果:

1. **テストコード(What の正本)** — 4.2 が新設した `tests/weapon/projectile_direction_test.gd` の `test_launch_moves_along_directions_off_the_eight_axes` ほかが「8 方向の外の向きで発射できる」を固定している(確認のみ)。
2. **`Projectile.launch()` の doc コメント(Why not の正本)** — 型の選択の理由・専用の弾クラスに分けない理由・文言据え置きの理由・訂正を行う時期を追記し、事前条件の記述を `Vector2i.ZERO` → `Vector2.ZERO` へ訂正した。中間生成物の ID・後方参照は書かず、コードとテストの事実だけで自己完結させた。
3. **コミットログ(Why の正本)** — 型を広げた理由(整数の格子では 20 度の向きを表せない)と、退けた 2 案(拡散専用の弾クラスの新設はレイヤ・射程・地形との衝突の扱いを 2 箇所に分ける / 角度を 45 度に戻す案は人間が退けた決定)をコミット本文へ残した。

- **凍結済みの unit #2 `spec.md` §5.6 は直していない**(要件 11.8)。乖離を残すこと自体が §8 の決定である。
- レビューの `[Nit]`(残る不正確さ。記録のみ): doc コメントは文言据え置きの理由を `tests/weapon/projectile_test.gd` 1 本に帰しているが、**同じ文言の複製は 4.2 が新設した非凍結の `tests/weapon/projectile_direction_test.gd` にもある**。文言を訂正する後続の作業単位は 2 本を同時に直す必要がある。
- レビューの `[FYI]`(本単位の対象外): `src/weapon/combat_limits.gd` に「unit #3」という中間生成物への後方参照が残っている。恒久情報の配置規約に照らすと是正候補だが、本単位の境界の外である。

### タスク 5.1 の学習

- **`is_primary_upgraded` は getter だけのプロパティ + 非公開の `_is_primary_upgraded` で実装した。** 代入は GDScript が黙って捨てるため(spec.md §3 で実測済み)、テストは「拒否されること」ではなく**代入の後に値が変わっていないこと**を見る。偽へ真を代入する側と真へ偽を代入する側の 2 方向を同じケースに並べる(片側だけだと「常に偽を返す」実装と区別できない)。
- **6.2(リセットが `died` より先)は、シグナルの受け手の中から読まないと落とせない。** `died.connect()` したラムダで `is_primary_upgraded` を控え、`[false]` であることを見る。`take_damage()` の呼び出しから戻った後に読む形だと、`died.emit()` → リセットの順に入れ替える変異が素通りする。
- **6.4(シーンの再読込に依存しない)の振る舞い側は、ツリーへ載せていない `Player` で 6.1 が成立することで示した。** `Player.new()` に `stats` だけ与えれば `take_damage()` → `_on_health_depleted()` の経路は `_ready()` を通らずに走る。
- 3.8 の `[input]` の凍結は、アクション名の集合の一致だけでは足りない(既存のアクションへイベントを足す変更を通す)。`[input]` 節の sha256(`d2a56d5042922b1126b62ced4112b5e8a566eea7583c965b80894997020ab982`、`01c1d0e` 時点)を併せて見る。**後続の unit が `[input]` へ手を入れる場合はこの定数の更新が要る**(タスク 4.1 の `aim_resolver.gd` の sha256 と同じ扱い)。
- `test_the_upgrade_state_is_a_single_bool` は「`upgrad` を含み bool でない」検査から `PROPERTY_USAGE_EDITOR` の項目を除いている。タスク 5.3 が足す `@export var upgraded_secondary_tint: Color` を通すためであり、spec.md §5.3(見え方であって状態ではない)と整合する。`@export` で残り回数を持ち込む形は語の拒否リスト側が捕らえる。

#### 対処しないと決めた検出力の欠陥(規律 7 により記録のみ)

1. **3.9 の検出力は名前の拒否リスト(`FORBIDDEN_STATE_TOKENS` 13 語)と `upgrad` を含む項目の型検査に依存する。** どちらにも当たらない名前(例 `_shots_left`・`_ttl`・`_burst_budget`)で残り回数・残り時間を持ち込む変異は生存する。タスク 1.1 の 7.17 が戒めた「名前を固定で列挙する」形と同型の弱さである。要点が指示した `get_property_list()` 走査の範囲内であり要件違反ではないため対処しない。**実質の担保はタスク 5.2・5.3 の振る舞い側**(発射経路が主武器・副武器の 2 系統ちょうどであることの実駆動での観測)に移る。
2. **6.5 に「境界のすぐ外」(体力を残り 1 まで削る)のケースが無い**(規律 6)。リセットを `Health.depleted` の経路に置いたため `Player` 側に閾値比較のガードが存在せず、現時点では規律 6 の対象となるガードが無い。ただし将来 `take_damage()` 側で `health.current <= 0` を見る形へ移す変異(`<= 1` へ緩める形を含む)は現在のケース群では落ちない。

- レビューの `[Nit]`(対処しない): テストのコメントに要件 ID(`要件 3.8`)と仕様の節番号(`§6.2`)が残っている。dev-implement 13. の「コードに中間生成物の ID を残さない」に照らすと是正候補だが、同形の参照は `tests/player/player_input_test.gd`・`src/enemy/charger_enemy.gd`・本単位の `tests/ability/spread_resolver_test.gd` に既にあり、**リポジトリの確立した慣行**であって本タスクが持ち込んだ後退ではない。本単位の中だけ体裁を変えると不揃いになるため揃えたまま残す。
- レビューの `[FYI]`: タスク 3.5 が 5.2・5.3 へ申し送った 10.8 の静的側の穴 3 件((a) `set()`/`set_meta()` による動的な状態 (b) `Player` の外に置かれた枠 (c) 既存フィールドの再利用)は、本サブタスクでは担当外のため扱っていない。**宿題は 5.2・5.3 に開いたまま**である。
- **本サブタスクのレビューは変異注入を実行せず静的読解で判定した**(前セッションの打ち切りで実装者の `MUTATION_CHECK` 申告が失われたため、レビュアーが 13 要件それぞれについて「否定の変異を落とすケース」を差分から名指しできるかを静的に照合する形へ替えた)。実測は最終検証パネルの test 観点が行う。

### タスク 5.2 の学習

- **`fired` の `direction` の型は、型を宣言しない受け手でなければ観測できない。** `func(direction: Vector2i, ...)` の lambda で受けると値が黙って変換されて届くため、`Vector2` を載せる変異が読めない。`Variant` 引数のメソッドで受けて `typeof()` を見る形にする。タスク 4.1 が申し送った要件 1.13 の振る舞い側の対はこのケースが持つ。
- **`_launch_projectile()` の型を `Vector2` へ広げても既存の呼び出し側は変えずに済む。** `_spawn_projectile()` は `Vector2i` を渡し続けており暗黙変換で通る(タスク 4.2 の学習が `Player` 側でも成立)。`fired` が 8 方向(`Vector2i`)を運び、`_launch_projectile()` が実際の向き(`Vector2`)を受けるという役割分担が 2 つのシグネチャに現れている。
- **タスク 3.5 が 5.2・5.3 へ申し送った 10.8 の宿題のうち (c)(既存フィールドの再利用による第 3 の枠)を閉じた。** 両武器を同じフレーム列で駆動し「そのフレームに増えた弾の数 == 3 × 主武器の発射回数 + 1 × 副武器の発射回数」を毎フレーム観測するケースが、`fired` を出さずに弾だけ生成する第 3 の経路を差として捕らえる。**(a) `set()`/`set_meta()` による動的な状態と (b) `Player` の外に置かれた枠は依然として未検証であり、5.3 への宿題として残る**(発射経路の外に置かれた状態は発射の観測に現れないため)。
- **タスク 4.1 の `[FYI]`(回転済みベクトルの直書き)の現状**: 角度の計算を `deg_to_rad`/`rotated()` の形で `player.gd` へ複製する変異は 4.1 の字面走査が落とすことを実測した。ただし**数値だけを直書きする形**(`Vector2(0.9397, -0.342)` 等)は字面走査を素通りし、戻り値が同じなら本スイートの振る舞いケースも通る。等価変異(規律 7)として記録のみとし対処しない。

#### 対処しないと決めた検出力の欠陥(規律 7 により記録のみ)

1. **`_spawn_spread()` は `SpreadResolver.resolve()` が空の配列を返した場合、ループを 1 度も回さずに `fired` と `spread_fired` を発火する**(弾 0 発で発火 = spec.md §5.3「弾を生成できなかった場合はどちらのシグナルも発火しない」に字義どおりには外れる)。`AimResolver.resolve()` の事後条件(8 方向のいずれかを返し `Vector2i.ZERO` を返さない。unit #2 §5.3)が呼び出し経路でこれを到達不能にするため、到達しない防御を足さず、それを固定するテストも置かない。**後続で `_update_weapons()` へ 8 方向の外の向きが流れる変更が入る場合は、この経路が先に問題になる。**
2. **拡散の弾の生成位置**(`projectile.global_position = global_position` を `launch()` より先に置くこと)は本スイートでは固定されていない。テストの `Player` が常に原点にいるため、代入を消す変異が原点では無害になる。要件 4.x の受け入れ基準に生成位置は含まれず、当該行は本タスクで変更していない(シグネチャの型のみ)ため対処しない。

- レビューの `[FYI]`: `_spawn_spread()` のループ内 `if not _launch_projectile(...): return` は、途中で失敗すると「弾を 1〜2 発だけ生成してシグナルを出さない」状態になりうる。現状の失敗要因は `projectile_scene == null` だけで 3 回とも同じ判定になるため到達不能。**将来 `_launch_projectile()` に別の失敗要因を足すときは部分生成の扱いを決める必要がある。**
- レビューの `[Nit]`(対処しない): `src/player/player.gd` の doc コメントが「20 度」という角度の値を文字で持つ。`tests/ability/spread_resolver_test.gd` の字面走査は数値の 20 を意図的に見ないため検査は通るが、`SpreadResolver.SPREAD_DEGREES` を変えたときにこのコメントだけが古くなる。
- レビューの `[Nit]`(実測で解消済み): 生成した弾を直接 `auto_free()` に渡していないが、弾の親である容器と親なしケースの `Player` 自身が `auto_free()` されており `orphans` は 0。

### タスク 5.3 の学習

- **タスク 3.5 が 5.2・5.3 へ申し送った 10.8 の宿題のうち (a)(`set()`/`set_meta()` による動的な状態)と (b)(`Player` の外に置かれた枠)を閉じた。これで 3.5 が残した 3 件はすべて閉じた。** (a) は `get_meta_list()` が空であることを、発射を駆動した**後に**見る形で実測する(GDScript は `_set()` を持たないオブジェクトへの `set("<未宣言>", ...)` を捨てるため、動的な状態が入る余地はメタに限られる)。(b) はツリーにも親にも属さない `Player` 単独で副武器の発射と色の付与が成立することと、`project.godot` に `[autoload]` 節が無いことを同じケースに対で置いた。
- **「2 つの色が異なること」を課す要件(7.15)の変異は、既定の色を『描画色が相手の色に一致する値』へ倒す形で作る。** `Color` の成分は 1 を超えてよいため、`upgraded_secondary_tint` を `Color(0.85, 0.5294118, 2.7142857, 1)` にすると、弾の placeholder `Color(1, 0.85, 0.35, 1)` との積が断片の `Color(0.85, 0.45, 0.95, 1)` と float32 で 5.96e-08 まで一致する。**成分 > 1 を使って初めて 7.15 を単独で否定できる**(白へ倒す変異は 5.5・5.6 を先に壊すため 7.15 のケースを落とさない)。後続の単位が断片色・弾色を変えた場合は、この形で変異を再構成すること。
- **`_launch_projectile()` の戻り値を `bool` から `Projectile` へ変えた。** 見た目の調整には弾そのものが要るためである。`_spawn_spread()` の失敗判定は `== null` の比較へ替えた(`not <Object>` の暗黙変換に頼らない)。要件 4.11・4.12 の振る舞いは変わっていない(`push_error` の回数・生成順も不変)。
- 色の比較は `Color` 用の gdUnit4 のアサーションが無いため、`assert_bool(a == b)`(厳密)と `is_equal_approx()`(近さ)を使い分ける。
- 凍結の照合に使った `src/player/player.tscn` の sha256 は `c1ff5528021fd94707275d72618d64bf9d614501b0b14b6e0905b49be42fcabd`(`01c1d0e` 時点)。**後続の unit が同ファイルへ手を入れる場合はこの定数の更新が要る**(4.1 の `aim_resolver.gd`・5.1 の `[input]` と同じ扱い)。
- **申告の運用上の学び(レビューが `[Critical]` として捕らえた)**: 変異の実測結果を漏れなく `MUTATION_CHECK` へ載せるには、**要件 ID の一覧を先に並べてから 1 行ずつ埋める**必要がある。本タスクは 7.15 を実測しながら申告の行を落とし、レビューで初めて欠落が捕らえられた(実装ではなく報告の欠陥)。

#### 対処しないと決めた検出力の欠陥(規律 7 により記録のみ)

1. **`_spawn_projectile()` の色を掛けるガードから `is_secondary` を落とす変異は生存する。** 強化中の主武器は `_spawn_spread()` を通り `_spawn_projectile()` へ来ないため、現在の呼び出し経路では両者の差が到達不能である。ガードは契約(主武器には掛けない)を局所で表すために残す。**将来「強化中でも主武器が 1 発を撃つ」経路を足す場合、このガードが 5.7 を守る唯一の場所になる。**
2. **5.6 だけを落とし 5.5 を通す変異は境界内では作れない。** 弾の placeholder `Color(1, 0.85, 0.35, 1)` の全成分が非零のため、白でない tint は必ず描画色を変える。等価変異域として記録のみ。

### タスク 6.1 の学習

- **差分が節の中に収まることは、ハンクの数と位置で機械的に確かめられる。** `git diff 01c1d0e -- docs/testing.md` はハンク 1 つ(`@@ -72,19 +72,23 @@`)のみであり、節の範囲(「### 仮ステージを目視で確認する」から次の見出しの直前まで)の内側に完全に収まる。他の節への差分は 0。
- **7 項目のリストと節末の共通の 3 箇条書きの間に導入文を 1 行置いた**(「どの仮ステージにも共通して、次のことに注意する。」)。空行だけで区切ると Markdown 上で 1 つのリストへ融合し、読み手が 10 項目と取り違える。3 箇条書き自体は 1 文字も変えていない。
- **除去の確認は語の検索で行う。** `analysis_overwrite_dev_stage`・`ability_uses`・`空枠`・`残り回数`・`演出`・`第 3`・`枠`・`飛翔`・`上書き` がファイル全体で 0 件であることを確かめた(要件 9.15・9.19)。
- レビューの `[Nit]` を反映し、12.3(20 度の広がり)と 12.7(所要時間・報酬感)の括弧内を「あわせて見る」から「あわせて記録する」へ改めた。spec.md が求めているのは記録であり、タスク 6.2 の実施者が取りこぼしにくくなる。
- タスク 6.2 へ: 目視の 7 項目は要件 12 の 12.1〜12.7 と同じ順に並べてある。**記録も同じ順に取ると要件と突き合わせやすい。** 起動コマンドは `godot --path <プロジェクトのルート> res://src/stage/analysis_dev_stage.tscn` の 1 本のみになった。
- タスク 7.1 へ: 本タスクの差分は `docs/testing.md` の 1 ファイルに閉じており、凍結対象(`project.godot`・`src/`・`tests/`・unit #1〜#4 の spec/tasks)には現れない。

### タスク 6.2 の目視の記録

**いつ**: 2026-08-21。
**どの環境で**: macOS(Darwin 25.5.0 / arm64 / Apple M2)、Godot 4.7.1.stable.official.a13da4feb、Metal 4.0 Forward+、ウィンドウは既定の 1280×720(内部解像度 320×180 / integer stretch)。`--headless` ではない GUI の実行である。

**どうやって**: 非対話のセッションからは OS 経由のキー入力を出せない(macOS の System Events が権限エラーになり、`cliclick` も無い)。そのため次の手順を採った。

1. `rsync -a --exclude .git --exclude reports --exclude .godot ./ /tmp/nv/` でプロジェクトを複製し、**複製の側にだけ**計測用のオートロード `visual_probe.gd` を置いた(`project.godot` の `[autoload]` へ 1 行)。**作業ツリーは 1 バイトも変えていない**。
2. 入力は `Input.parse_input_event()` + `Input.flush_buffered_events()` で流した。`PlayerInput.read()` の本来の経路(`Input.get_axis`・`is_action_pressed`)をそのまま通る。キーは `physical_keycode`(A=65 D=68 W=87 S=83 Space=32 J=74 K=75)。押している間は毎物理フレーム押下を送り直す(ウィンドウのフォーカスが外れるとエンジンが押下状態を落とすため)。
3. 描画は `RenderingServer.frame_post_draw` を待って `get_viewport().get_texture().get_image()` を受け、`Image.INTERPOLATE_NEAREST` で 4 倍に拡大して PNG に保存した(320×180 のままでは読めない)。
4. シーンの再読込を跨ぐ観測(12.6)のため、計測スクリプトはシーンの中ではなくオートロードに置いた。
5. 観測は 3 回の起動に分けた(1 回目に環境側の停止でウィンドウが応答しなくなったため、監視犬タイマーで 240 秒の上限を入れ、区間を分けた)。

**入力は台本であって人間の操作ではない。** 手触り(面白いか・報酬に感じるか)の最終判断は人間に残る。以下は観測できた事実と、そこから言える範囲の判断である。

| 要件 | 確認したこと | 結果 |
| ---- | ------------ | ---- |
| 12.1 | 射撃型を撃破すると撃破位置に断片が現れる | **成立**。主武器 2 発(27 物理フレーム / 469 ms)で撃破。断片が 1 つ、`(160, 84)` = 撃破位置と**差 0**。親は `AnalysisDevStage`。色 `Color(0.85, 0.45, 0.95, 1)`・寸法 8×8。画面上でも紫の小さな四角として床の上に見える(`01_fragment_appeared.png`) |
| 12.2 | 突進型を撃破しても断片は現れない | **成立**。拡散で撃破(2 物理フレーム / 93 ms)。撃破直後も 1 秒後も断片は 0 個 |
| 12.3 | 触れると断片が消え、主武器が 3 発の拡散になる | **成立**。断片へ歩いて 1044〜1059 ms で取得、断片は 0 個になり `is_primary_upgraded` が真。取得前の発射は 1 発、取得後は 3 発。**8 方向すべてで測って、中央からの角度が -20.00 度 / +20.00 度、外側どうしが 40.00 度**(下向きの 3 方向は跳んでから撃った。接地中は照準の下成分が水平へ落ちるため)。画面でも 3 発が縦に開いた扇として読める(`07_spread_*.png`) |
| 12.4 | 強化中の副武器の弾の色が変わる | **成立**。`modulate` が `Color(0.35, 0.88, 1, 1)`、描画色が `Color(0.35, 0.748, 0.35, 1)`。強化前の金 `Color(1, 0.85, 0.35, 1)` から**緑へ変わったことが一目で分かる**(`08_secondary_tinted.png`)。断片の紫とも別の色相であり取り違えない |
| 12.5 | 断片を 10 秒以上放置しても同じ位置にある | **成立**。12.8 秒放置してずれ `(0, 0)`・生存。1 秒ごとに 12 回測ってすべて `(160, 84)` |
| 12.6 | 死亡して再読込されると主武器が 1 発へ戻る | **成立**。`died` の直後に `is_primary_upgraded` が偽、1 フレームでシーンが差し替わり、Player は `(48, 76)`・体力満タン・強化なしで復帰。敵 2 体と断片 0 個の初期状態。再読込後の主武器の発射は **1 発**。5.2 の 6.3 が自動テストで固定した状態のリセットと同じ結果になった |
| 12.7 | 撃破 → 取得 → 拡散で次の敵を倒すまで操作が止まらない | **成立**。通しで **5.0 秒**(撃破 0.5 秒 → 断片へ歩く 1.0 秒 → 突進型を拡散で 0.1 秒)。区間ごとの最大フレーム間隔は 26.2 / 33.2 / 33.3 ms(60 fps の 16.7 ms に対して 2 フレーム分。画面の保存を含む区間は計測から外してある)。停止・引っかかりは観測されなかった |

#### spec.md §3 の未検証の前提 3 件についての所見

1. **「拡散の角度 20 度が『拡散』として成立し、8 方向の照準と両立する」→ 成立していると判断する。** 根拠: (a) 8 方向すべてで角度が設計どおり(±20.00 度 / 外側どうし 40.00 度)。(b) 画面上で 3 発が明確に分かれた扇として読め、45 度のときの「三方向撃ち」に見える広がりとは異なる(`07_spread_right.png` では、水平に約 30px 進んだ時点で 3 発が縦に約 14px ずつ離れている)。(c) 照準そのものは `Vector2i` の 8 方向のままで、連続角にはなっていない。
   - **ただし付随する観測**: 接地して**水平**に撃つと、下へ 20 度回った 1 発は**約 33〜41px で床に当たって消える**(実測 5 物理フレーム。幾何でも、弾の中心が床の上面まで 14px しかないため 14 / sin20° ≒ 41px)。射撃型との交戦距離(112px)では、下の 1 発は床へ、上の 1 発は敵の上を越えるため、**当たるのは中央の 1 発だけ**になる。3 発すべてが当たるのは相手との距離が**およそ 23px 以内**(敵の高さ 16px の半分 ÷ sin20°)のときに限られる。**これは仕様の欠陥ではなく、20 度という角度が持つ性質**であり、数値の調整の要否は人間の判断に残す(自分では調整していない)。
2. **「毎秒約 250 の火力でも難度が崩れない」→ 崩れていないと判断する。** 根拠: 上の幾何により、毎秒 250 は**至近距離でだけ届く上限**であって通常の交戦距離での火力ではない。実測でも、突進型(体力 30)を倒せたのは相手が約 8px まで寄った瞬間で、そこでは 1 斉射(3 発 × 10)で沈む(2 物理フレーム)。ただしその接近を許すまでに Player は体力 100 → 75 を失っており、**「密着すれば 1 斉射で沈むが、密着するには被弾する」という交換になっている**。spec.md §3 が想定した「至近距離で 3 発すべてが当たる」状況は再現したが、難度が崩れる兆候(遠距離から一方的に押し切れる)は観測されなかった。
3. **「時間で消えず落ちもしない断片が『取りに行く』動機として成立する」→ 機構としては成立している。動機としての成立は人間の判断に残す。** 根拠: 12.8 秒の放置でずれ 0・消滅なしを実測し、撃破位置(112px 先)まで歩いて約 1.0 秒で取得できた。取りに行く経路に待ち時間も操作の中断も無い。**面白いか・報酬に感じるかは台本入力では測れない**(この計測は人間の操作ではない)。12.7 の通し 5.0 秒という所要時間だけを事実として残す。

**3 件のいずれも崩れていない**ため、`PlayerStats` の値にも拡散の角度・弾数にも手を入れていない。

#### 目視でだけ見つかった実行時の指摘(コードは直していない)

- **写せる種別を撃破するたび、エンジンの ERROR が 1 回出る。** 文言は `Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.`(`area_set_shape_disabled`)。バックトレースは `hurtbox._on_area_entered` → `enemy.take_damage` → `analysis_dev_stage._on_enemy_defeated:38`(= `add_child(fragment)`)である。**弾が敵に当たって撃破が起きる経路は物理コールバックの最中**であり、そこで `CollisionShape2D` を持つ `Area2D` を木へ載せると、形状の `disabled` を物理サーバへ反映できずエンジンが拒否する。
  - **機能への影響は観測されなかった**: 断片は正しい位置に出て、当たり判定も効き、接触で強化が渡って解放される(12.1・12.3 が実測で成立している)。既定の `disabled` は偽であり、反映に失敗した値も偽なので結果が変わらないためである。
  - **unit #4 では起きなかった**。`AnalysisPulse` は `CollisionShape2D` を持たない素の `Node2D` だったため、この経路を踏まなかった。**本単位が断片を `Area2D` にしたことで新しく現れた**。
  - **自動テストでは捕らえられない**: `tests/stage/analysis_dev_stage_test.gd` は `_on_enemy_defeated()` を直接呼ぶため、物理コールバックの最中という条件が再現しない。
  - **直していない理由**: 解消するには `add_child()` を `add_child.call_deferred()` にするほかないが、それは spec.md §5.6(「ステージ自身の子として**追加してから** `global_position` へ置く」)と要件 8.1・8.3 の同期的な検証を変えることになる。**承認済みの契約の変更に当たるため、自分で直さず記録と報告に留める**(規律 10・`dev-implement` 13.)。

### タスク 7.1 の凍結の検査(実測)

差分の基点は `01c1d0e`(本単位の作業ブランチの分岐元)。**本タスクは `project.godot`・`src/`・`tests/` を 1 バイトも変更していない**(検査のみ。実行後に `git status --porcelain` が空であることを確認した)。

**偽陰性の排除の方針**: 空の差分は「変わっていない」とも「対象パスの綴りを間違えて 0 件になった」とも読める。そこで各行で **対象パスが `01c1d0e` にも現在にも追跡対象として実在すること**を `git ls-files` と `git ls-tree -r --name-only 01c1d0e` の件数の一致で示した。あわせて 2 つの対照を取った。

- **陽性対照**(同じ手段が実在の変更を検出すること): `src/player/player.gd` 10419 バイト / `docs/testing.md` 3193 バイト / `src/weapon/projectile.gd` 3034 バイト / `src/stage/analysis_dev_stage.tscn` 1115 バイトの差分を検出した。
- **陰性対照**(綴りを崩すと実在の確認が落ちること): `project.godott`・`src/player/helth.gd`・`src/enemyy`・`docs/specs/001-mvp/004-analysis-abilty` はいずれも `changed=0` かつ `tracked=0` になり、`tracked>0` の行とは区別できた。

#### 「凍結の正本」の表との 1 対 1 の対応

| # | 凍結の対象(表の行) | 要件 | 手段 | 実測 |
| - | ---- | ---- | ---- | ---- |
| 1 | `project.godot` | 11.2・11.7・9.13 | `git diff 01c1d0e -- project.godot` | 0 ファイル / 0 バイト。tracked 1(基点も 1)。全体の sha256 が基点と同一(`9e19d198058639d1fd29491f7d41d9d4cd85cdab24093e73ff4ba446e04c2d7d`) |
| 2 | `player_command.gd`・`player_input.gd`・`aim_resolver.gd`・`health.gd` | 11.1・11.4 | 同上(`.gd` と `.gd.uid` の 8 パス) | 0 ファイル / 0 バイト。tracked 8(基点も 8) |
| 3 | `primary_weapon.gd`・`secondary_weapon.gd`・`enemy_projectile.gd`・`projectile.tscn` | 11.4・11.5 | 同上(`.uid` を含む 7 パス) | 0 ファイル / 0 バイト。tracked 7(基点も 7) |
| 4 | `src/enemy/` の全ファイル | 11.6 | 同上(ディレクトリ指定) | 0 ファイル / 0 バイト。tracked 25(基点も 25) |
| 5 | `dev_stage.*`・`enemy_dev_stage.*`・`damage_zone.*` | 9.12 | 同上(9 パス) | 0 ファイル / 0 バイト。tracked 9(基点も 9) |
| 6 | `src/player/player.tscn` | 5.11 | 同上 | 0 ファイル / 0 バイト。tracked 1。sha256 はタスク 5.3 の記録と一致 |
| 7 | `src/ability/ability_analysis.gd` | 10.9 | 同上(`.uid` を含む 2 パス) | 0 ファイル / 0 バイト。tracked 2 |
| 8 | unit #1〜#4 の `spec.md` と `tasks.md` | 11.8 | 同上(4 ディレクトリ) | 0 ファイル / 0 バイト。tracked 13。**4 ディレクトリを個別にも数え**、3 / 3 / 3 / 4 と分布することを確かめた(1 つだけ綴りを誤っても総数では気づけないため) |
| 9 | unit #1〜#3 の既存テスト 24 本 + `ability_analysis_test.gd` | 11.9・10.9 | `git diff --diff-filter=MDR 01c1d0e -- <25 パス>` | 0 ファイル / 0 バイト。25 本すべてが基点にも現在にも実在。対の `.gd.uid` 25 本も 0。フィルタ無し(`A` も含む)でも 0 |
| 10 | `fired` のシグナル宣言行 | 11.3 | 宣言行の完全一致 | **一致**(53 バイト / sha256 `c6c6303ed00ffece09ac81945b7426da8d44915983a20b6ddeb11e2f81fc2d92` が基点と同一)。`^signal fired` の宣言は基点・現在とも 1 本 |
| 11 | `PlayerStats` の既存 14 項目の既定値 | 11.12 | `player_stats_test.gd` が変更なしで緑 | 変更 0(#9 に含む)。12 ケース / failures 0 / errors 0 / skipped 0 |
| 12 | `Projectile` の文言・引数・レイヤ・射程・解放 | 2.7・2.8・2.9・11.10 | `projectile_test.gd` が変更なしで緑 | 変更 0(#9 に含む)。19 ケース / failures 0 / errors 0 / skipped 0。`projectile.tscn` の差分も 0(#3) |

**#9 の対象から除いたもの**: 要件 10.7 が削除を命じた unit #4 の 7 本(`ability_slot_test.gd`・`analysis_pulse_test.gd`・`analysis_pulse_scene_test.gd`・`player_ability_test.gd`・`player_ability_stats_test.gd`・`player_takeover_test.gd`・`analysis_overwrite_dev_stage_test.gd`)は列挙に含めていない(いずれも現在 `git ls-files` で 0 件 = 削除済み)。`tests/weapon/` へ本単位が足した `projectile_direction_test.gd` は `A` であり `--diff-filter=MDR` に現れない。**#9 の陽性対照**として、同じ配列に変更済みの `tests/player/player_spread_test.gd` を 1 本混ぜると `MDR` が 1 件を返すことを確かめた(検出力のあるコマンドで 0 件だったこと)。

- 表に無いが unit #2 由来の `tests/stage/damage_zone_test.gd` も併せて見た(`MDR` 0 件 / tracked 1)。要件 11.9 の列挙には含まれないため、上の 1 対 1 の対応には数えていない。
- 11.2 の `[input]` は 7 アクション(`move_left`・`move_right`・`aim_up`・`aim_down`・`jump`・`fire_primary`・`fire_secondary`)、11.7 の `[layer_names]` は 1〜5 が `terrain`・`player`・`player_projectile`・`enemy`・`enemy_projectile`、9.13 の `run/main_scene` は `res://main.tscn` であることを実値でも確かめた(ファイル全体の sha256 一致に加えた冗長な確認)。

#### 9.18(配置と命名)

対象は**本単位が足した・作り直したテスト**である。名前を書き写さず `git diff --diff-filter=AM --name-only 01c1d0e -- 'tests/*_test.gd'` から導出した **9 スイート / 135 ケース**(`analysis_fragment_test`・`analysis_fragment_scene_test`・`spread_resolver_test`・`player_upgrade_test`・`player_spread_test`・`player_secondary_tint_test`・`analysis_dev_stage_test`・`analysis_dev_stage_scene_test`・`projectile_direction_test`)。`docs/testing.md`「配置と命名」の 3 条と、同「書き方」の「引数を取るテストケースを書かない」を照合した。

| 検査 | 結果 |
| ---- | ---- |
| `tests/` 以下にのみ置く | 9 本すべて `tests/` 直下。`src/` 配下の `*_test.gd` は 0 件 |
| 実装のディレクトリ構成を写したパス | 9 本すべて、対応する `src/<同名ディレクトリ>` が実在(`src/ability`・`src/player`・`src/stage`・`src/weapon`) |
| ファイル名の接尾辞 `_test.gd` | 9 本すべて適合 |
| テストケース名の接頭辞 `test_` | 135 ケースすべて `func test_` で始まる |
| **引数を取るテストケースが 1 つも無い** | **0 件**。本単位の 9 本だけでなく `tests/` 全体を走査しても 0 件 |

**引数の検査の偽陰性の排除**: 「0 件」が式の壊れによるものでないことを、`func test_bad(timeout := 100) -> void:` を含む合成ファイルを同じ式に掛けて確かめた(合成側は正しく検出された)。これが `make test` の `skipped` が 0 である根拠と対応する。

リポジトリ全体のスイートの配置は `tests/ability` 4 / `tests/enemy` 7 / `tests/harness` 2 / `tests/player` 11 / `tests/stage` 5 / `tests/weapon` 6 の **計 35**。

#### `make test` の統計行(全体)

**553 test cases / 35 suites / errors 0 / failures 0 / flaky 0 / skipped 0 / orphans 0 / exit 0**(実行時間 52s 397ms)。`orphans`・`skipped`・`failures`・`errors` はすべて 0 である。

- **見込みの 35 suites と一致した。** 基線 37 に対し、要件 10.7 の削除 7 本と本単位の新設 5 本(`analysis_fragment_test`・`analysis_fragment_scene_test`・`projectile_direction_test`・`player_upgrade_test`・`player_secondary_tint_test`)で 37 − 7 + 5 = 35。作り直した 4 本(`spread_resolver_test`・`player_spread_test`・`analysis_dev_stage_test`・`analysis_dev_stage_scene_test`)は同じパスへ戻るため増減しない。
- ケース数は基線 594 に対し 553(−41)。タスク 5.3・6.1 の時点の記録と同じ値であり、6.2(目視のみ)と 7.1(検査のみ)がテストを変えていないことと整合する。

#### 差分の照合の結論

`git diff --stat 01c1d0e` に現れる 51 ファイルはすべて「凍結の正本」の表の外側、かつ **File Structure Plan と「変更してよい既存ファイル」の範囲内**である(`src/ability/`・`src/player/player.gd`・`player_stats.gd`・`src/stage/analysis_*`・`src/weapon/projectile.gd`・`tests/` の該当分・`docs/testing.md`・本単位の workdir・`docs/specs/001-mvp/roadmap.md` と `state.json`)。**計画に含まれない差分は 1 件も見つからなかったため、戻さずに報告する事象は無い。**

- **レビューの `[Nit]` を反映した補足**: 末尾の `docs/specs/001-mvp/roadmap.md` と `docs/specs/001-mvp/state.json` の 2 つは、厳密には「変更してよい既存ファイル」の定義(本ファイルの表と本単位の workdir)のどちらにも当たらない。両者は SDD の台帳であり、`git log 01c1d0e..HEAD -- <2 ファイル>` が示すとおり本単位の作成時のコミット `f1bfca1` 1 件のみに由来する(実装タスクが触れたものではない)。凍結の正本の表にも要件 11.8(unit #1〜#4 に限定)にも現れないため、要件違反ではない。

#### 検査そのものの学び(後続の検査タスクへ)

- **`git diff` の空は「差分なし」と「パスが実在しない」を区別しない。** 対象パスの実在の件数を基点側と現在側の両方で数える手順を、空を結論づける前に必ず置く。
- **シェルの語の分割で対象パスが 1 本に潰れる事故を実際に踏んだ。** `FROZEN="a b c"; set -- $FROZEN` は zsh では分割されず、25 本のつもりが 1 本(存在しないパス)になり `MDR` が 0 件を返した。**実在の確認を先に置いていたため「対象パス数: 1」で即座に気づけた**。検査スクリプトは対象パス数を先に出力し、期待する本数と突き合わせること。配列(`FROZEN=(...)`)で渡せば起きない。
- **タスク 5.1 が記録した `[input]` 節の sha256 は、シェルの `awk | shasum` では再現しない。** テスト側の `_input_section()` は行を `"\n".join()` するため**末尾に改行が付かない**のに対し、`awk` の `print` は最終行にも改行を付ける。この 1 バイトで値が変わる。同じ抽出(ヘッダ `[input]` の行を含め、次の `[` の行の直前まで、末尾に改行を付けない)を Python で再現して `d2a56d5…` と一致することを確認した。**後続の unit がこの定数を更新するときは、テスト側の抽出と同じ形で計算すること**(ファイル全体の sha256 とは別物である)。
- タスク 4.1 の `aim_resolver.gd`(`fdc1323f…`)とタスク 5.3 の `player.tscn`(`c1ff5528…`)の sha256 も現在の値と一致した。3 つの sha256 定数はいずれもテストの中で実行時に検査されており、上の 553 ケースの緑に含まれる(`spread_resolver_test.gd`・`player_upgrade_test.gd`・`player_secondary_tint_test.gd`)。**git の差分と実行時の検査が、同じ凍結を独立な 2 経路で押さえている。**

### 統計行の推移(基線 594 cases / 37 suites)

| 時点 | cases | suites |
| ---- | ----- | ------ |
| 基線 | 594 | 37 |
| 1.1 の後 | 606 | 38 |
| 1.2 の後 | 616 | 39 |
| 2.1 の後 | 595 | 38 |
| 2.2 の後 | 578 | 37 |
| 2.3 の後 | 598 | 38 |
| 3.1 の後 | 554 | 35 |
| 3.2 の後 | 525 | 34 |
| 3.3 の後 | 516 | 33 |
| 3.4 の後 | 486 | 31 |
| 3.5 の後 | 486 | 31 |(検査のみ。変更なし)
| 4.1 の後 | 492 | 31 |
| 4.2 の後 | 502 | 32 |
| 4.3 の後 | 502 | 32 |(doc コメントのみ。変更なし)
| 5.1 の後 | 518 | 33 |
| 5.2 の後 | 538 | 34 |
| 5.3 の後 | 553 | 35 |
| 6.1 の後 | 553 | 35 |(ドキュメントのみ。変更なし)
| 7.1 の後 | 553 | 35 |(6.2 は目視のみ・7.1 は検査のみ。どちらもテストを変えていない。見込みの 35 suites と一致)

### 最終検証パネルの結果(2026-08-22)— **NO-GO**

事前ゲート(dev-implement 14.1)は通過している。全 19 サブタスクが `[x]`、`_Blocked:` なし、`check.py`(`--def .claude/skills/flow-sdd/workflow.json --ports-root docs/dev/ports`)が **error 0 / warning 3**(行数超過のみ。`tasks.md` 790 行・`player_spread_test.gd` 685 行・`analysis_dev_stage_scene_test.gd` 614 行)。パネル実行前の `make test` は **553 cases / 35 suites / errors 0 / failures 0 / flaky 0 / skipped 0 / orphans 0 / exit 0**。

| 観点 | 実行場所 | VERDICT | Critical | UNVERIFIED |
| ---- | ---- | ---- | ---- | ---- |
| requirements-conformance | 隔離複製 `/tmp/nv-panel/reqconf` | APPROVED | 0 | なし |
| security | 隔離複製 `/tmp/nv-panel/security` | APPROVED | 0 | なし |
| structure | 隔離複製 `/tmp/nv-panel/structure` | APPROVED | 0 | なし |
| **test** | 隔離複製 `/tmp/nv-panel/test` | **REJECTED** | **4** | なし |
| **runtime-smoke** | 隔離複製 `/tmp/nv-panel/runtime` | **REJECTED** | **1** | なし |

**merge の判定**: dev-implement 14.2 の「1 観点でも `REJECTED` なら全体 NO-GO(多数決にしない)」により **NO-GO**。`UNVERIFIED` はどの観点も「なし」であるため、未検証起因ではなく**欠陥起因の NO-GO** である。

#### 観点の選び方と排他の根拠

- 固定 3 観点(requirements-conformance・security・test)に、実行時挙動に影響する変更であるため **runtime-smoke を必須で追加**した。あわせて `player.gd` の大幅な書き換えと 2 クラスの撤去があるため **structure** を追加した。
- **accessibility は該当なしと判断した**(widget UI・テキスト・フォーカス可能要素・WCAG の適用面を持たないため)。**visual-conformance は独立の観点として立てず、その実体(要件 7.12〜7.15 の色の相違・9.2〜9.7 の配置・要件 12 の見え方)を runtime-smoke の観察項目 8 として担当させた**。理由は、このプロジェクトが配色トークン体系を持たず視覚の正本が spec.md §6.4 の色の相違の要件そのものであること、および独立に立てると GUI の起動が二重になることである。**この縮退は本パネルの被覆の限界として記録する**。
- 排他(`runtime-verification.md` §3.1): 5 観点すべてに**体ごとの隔離した複製**を用意し、同時に投入した。§3.1 の 3 条件を事前に確認済み — (1) git 管理下で作業ツリーがクリーン、(2) 複製で `make test` が成立することを実測、(3) 専有資源(固定ポート・ソケット・DB)を使わず、レポート出力先は複製ごとに分かれる。
- **検証の後、元の作業ツリーは 1 バイトも変わっていない**(`git status --porcelain` が空、`HEAD` は `08522c0` のまま。5 観点すべてが独立に確認し、パネル撤去後にも確認した)。

#### Critical 5 件

**C1(test / 要件 3.9)— 強化の残り回数を持ち込む変異が全体緑のまま生存する。**
変異: `src/player/player.gd` へ `var _burst_budget: int = 999` を足し、`grant_upgrade()` で戻し、`_spawn_spread()` で減らして 0 で強化を落とす(= 残り回数つきの強化)。`make test` は 553 cases / failures 0 / exit 0 のまま。
落ちない理由: 3.9 を検証すると主張する `tests/player/player_upgrade_test.gd::test_the_upgrade_state_is_a_single_bool` は `FORBIDDEN_STATE_TOKENS`(13 語)の**名前の拒否リスト**と `upgrad` を含む項目の型しか見ておらず、リストに当たらない名前を素通りする。
**等価変異ではない**: `Player` のスクリプト変数は有限(10 個)であり、同じスイートが要件 3.8 で既に使っている「ちょうどの個数」の形(`test_the_player_command_keeps_exactly_five_fields` が `_script_variables(command).size()).is_equal(COMMAND_FIELD_COUNT)`)をそのまま `Player` へ適用すれば落とせる。ヘルパ `_script_variables()` は同スイートに実在する。新設スイートのため要件 11.9 とも衝突しない。
本ファイル「タスク 5.1 の学習 > 対処しないと決めた検出力の欠陥 1」は同じ生存を申告しているが、**「要点が指示した走査の範囲内だから対処しない」は検出力の欠落を正当化しない**とパネルが判定した。

**C2(test / 要件 10.5・10.6・10.4)— `PlayerStats` に 15 項目目を足す変異が全体緑のまま生存する。**
変異: `src/player/player_stats.gd` の末尾へ `@export var ability_uses: int = 3`。`make test` 553 cases / failures 0 / exit 0。
落ちない理由: 凍結済みの `tests/player/player_stats_test.gd:87` は `assert_array(_editor_visible_property_names(stats)).contains(STAT_NAMES)` の**非排他な検査**である。さらに要件 10.6(`src/` に `ability_*` の識別子を残さない)は**タスク 3.5 が実装時に 1 度 grep しただけ**で、リポジトリ内に自動の検査が無い(`tests/` 全体を検索して 0 件であることを独立に確認した)。
**等価変異ではない**: 塞げないのは既存スイートの改訂だけであり、本単位が `tests/weapon/projectile_direction_test.gd` を新設したのと同じ理屈で、新しいスイートに「`@export` の項目数 == 14」「`src/` 配下に 9 語が 0 件」の 2 ケースを足せば落とせる。
本ファイル「タスク 3.3 の学習 > 対処しないと決めた検出力の欠陥 1」の「要件 11.9 が凍結しているため塞げない」という記述は、**既存スイートの改訂に限れば正しいが、新設スイートという手段を見落としている**。

**C3(test / 要件 2.6)— 短さを理由に拒否しない契約を否定する変異が生存する。**
変異: `src/weapon/projectile.gd:56` の `if direction == Vector2.ZERO:` を `if direction.is_zero_approx():` へ。`make test TESTS=res://tests/weapon` は 84 cases / failures 0 / exit 0(生存)。
落ちない理由: `tests/weapon/projectile_direction_test.gd:46` の `UNNORMALIZED_DIRECTIONS = [Vector2(0.3, 0.0), Vector2(3.0, 1.0)]` はどちらも `CMP_EPSILON`(1e-5)より十分大きく、**境界のすぐ外(規律 6)を 1 つも置いていない**。
**等価変異ではない(実測)**: 複製に 1 ケースだけの検査用スイートを置き `projectile.launch(Vector2(0.000001, 0.0), 260.0, 11, 600.0)` で駆動したところ、元の実装では PASSED(弾が進む)、変異では FAILED(`frames_moved == 0`)となり、変異は 1 ケースで死ぬ。
本ファイル「タスク 4.2 の学習」の 1 件目が「等価変異(規律 7)として固定するテストを意図的に置いていない」と記しているが、**実測はこれを否定する**。

**C4(test / 要件 11.3)— `fired` のシグナル宣言の型を変える変異が全体緑のまま生存する。**
変異: `src/player/player.gd:11` の `signal fired(direction: Vector2i, is_secondary: bool)` を `direction: Vector2` へ。`make test` 553 cases / failures 0 / exit 0。
落ちない理由: GDScript はシグナルの宣言型を発火時に強制しないため、`_spawn_spread()`/`_spawn_projectile()` が渡す実引数は `Vector2i` のままであり、振る舞い側の対(`tests/player/player_spread_test.gd::test_the_fired_direction_stays_an_eight_way_vector2i_while_upgraded`)は**値の型**しか観測していない。`tests/` 全体に `get_signal_list` を読む検査も `signal fired` の宣言行を読む検査も存在しない(独立に確認した)。
**宣言そのものの凍結は「凍結の正本」の表どおりタスク 7.1 の 1 回きりの手作業の照合に置かれており、退行を捕らえるテストが無い。** 本単位は同種の凍結を `aim_resolver.gd`・`[input]` 節・`player.tscn` の 3 つについて sha256 のケースとして自動化しており、**`fired` だけがその形を持たない**。

**C5(runtime-smoke / 実行時のエラー 0 件)— 写せる種別の撃破のたびにエンジンの ERROR が 1 回出る。**
`ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.` / `at: area_set_shape_disabled (godot_physics_server_2d.cpp:354)` / `[0] _on_enemy_defeated (res://src/stage/analysis_dev_stage.gd:38)` `[1] take_damage (res://src/enemy/enemy.gd:65)` `[2] _on_area_entered (res://src/enemy/hurtbox.gd:33)`
**独立に起動した 8 回すべてで再現**(各回とも `grep -c '^ERROR'` = 1、文言は完全に同一)。`main.tscn` の起動では ERROR 0 件。
**原因の同定は推定でなく実測**: 複製で `add_child(fragment)` を `call_deferred` 経由へ差し替える変異を注入したところ、同じ台本で ERROR が 0 件になった。
これは `runtime-verification.md` §2 の共通の検証項目「console・サーバログにエラーが 0 件」に反する。**機能上の破綻は観測されなかった**(断片は撃破位置に正しく出る・当たり判定が効く・接触で解放される)が、本観点の合格基準は「エラー 0 件」であり立証できないため不合格である。

#### 最終検証の照合(COVERAGE の集約)

`_Requirements:` に現れる **142 件すべてが 1 つ以上の観点で照合され、未照合は 0 件**である(requirements-conformance が 142 件を全件照合し、test が 30 件の変異で、runtime-smoke が要件 12 の 7 件と視覚の識別性を実行時に照合した)。以下は ID → 照合した対象 → 立証の手段。

| ID | 照合した対象 | 立証の手段 |
| -- | ---- | ---- |
| 1.1 | `spread_resolver_test::test_resolve_returns_three_elements_for_every_direction` ほか | テスト緑 |
| 1.2 | 同 `::test_resolve_returns_the_normalized_argument_first_for_every_direction` | テスト緑 |
| 1.3 | 同 `::test_resolve_turns_the_second_and_third_to_opposite_sides_for_every_direction`(符号込み) | テスト緑 + **変異 M1 死亡**(回転の符号の入れ替えで 24 failures) |
| 1.4 | 同上(もう片側の符号) | テスト緑 + 変異 M1 死亡 |
| 1.5 | 同 `::test_resolve_returns_unit_vectors_for_every_direction` | テスト緑 |
| 1.6 | 同 `::test_resolve_separates_the_second_and_third_by_forty_degrees`(1.3/1.4 と独立のケース) | テスト緑 |
| 1.7 | 同 `::test_resolve_returns_distinct_directions_for_every_direction` | テスト緑 |
| 1.8 | 同 `::test_resolve_never_returns_the_zero_vector` | テスト緑 |
| 1.9 | 上記全ケースが `EIGHT_DIRECTIONS` 8 件を走査 + `::test_the_direction_table_covers_the_eight_directions` | テスト緑 |
| 1.10 | 同 `::test_spread_degrees_is_twenty` + `::test_the_spread_angle_is_not_built_outside_the_resolver` | テスト緑 + **変異 M2 死亡**(`player.gd` へ角度の自前計算を複製) |
| 1.11 | 同 `::test_resolve_returns_an_empty_array_for_an_invalid_direction` ほか(`ZERO`・`(2,0)`・`(0,-2)`・`(1,2)`・`(-2,-1)`) | テスト緑 |
| 1.12 | 同 `::test_resolve_returns_a_separate_array_on_each_call` | テスト緑 |
| 1.13 | 同 `::test_resolve_takes_a_vector2i_argument` + `aim_resolver.gd` の sha256 + `player_spread_test` の振る舞い | テスト緑 + **変異 M3 死亡** |
| 2.1 | `projectile_direction_test::test_launch_declares_the_direction_as_a_float_vector` | テスト緑 |
| 2.2 | 同 `::test_launch_moves_along_every_direction_given_as_vector2i`(8 方向) | テスト緑 |
| 2.3 | 同 `::test_launch_moves_along_directions_off_the_eight_axes`(20 度・65 度等) | テスト緑 |
| 2.4 | 同 `::test_launch_keeps_the_speed_on_a_diagonal_and_an_off_axis_direction` | テスト緑 + **変異 M6 死亡**(`.normalized()` の削除で 10 failures) |
| 2.5 | 同 `::test_launch_rejects_a_zero_vector2_direction` + `::..._vector2i_...` | テスト緑 |
| 2.6 | 同 `::test_launch_accepts_directions_that_are_not_unit_length` | **変異 M5 生存 → C3(欠陥)** |
| 2.7 | `projectile.gd` の `ZERO_DIRECTION_ERROR` が据え置き + 凍結 `projectile_test.gd` 19 ケース緑 | `git diff` + テスト緑 |
| 2.8 | `projectile_direction_test::test_launch_keeps_the_parameter_names_and_order` | テスト緑 + **変異 M4 死亡**(引数の改名) |
| 2.9 | 同 `::test_projectile_scene_keeps_its_collision_layer_and_mask` + `git diff` 空 | `git diff` + テスト緑 |
| 3.1 | `player_upgrade_test::test_a_new_player_is_not_upgraded`(3 経路) | テスト緑 |
| 3.2 | 同 `::test_grant_upgrade_makes_the_player_upgraded` | テスト緑 |
| 3.3 | 同 `::test_grant_upgrade_is_idempotent` | テスト緑 |
| 3.4 | 同 `::test_the_upgrade_survives_the_passage_of_physics_frames`(実フレーム) | テスト緑 |
| 3.5 | 同 `::test_assigning_the_property_directly_does_not_change_it` ほか(両方向) | テスト緑 + **変異 M8 死亡**(setter の追加) |
| 3.6 | 同 `::test_grant_upgrade_works_on_a_player_outside_the_tree` | テスト緑 |
| 3.7 | 同 `::test_grant_upgrade_does_not_inspect_the_health` | テスト緑 |
| 3.8 | 同 `::test_the_player_command_keeps_exactly_five_fields` + `[input]` 節の sha256 | テスト緑 + `git diff` 空 |
| 3.9 | 同 `::test_the_upgrade_state_is_a_single_bool` | **変異 M7 生存 → C1(欠陥)** |
| 4.1 | `player_spread_test::test_the_upgraded_primary_spawns_three_projectiles_on_the_frames_it_fires` | テスト緑 |
| 4.2 | 同 `::test_the_spread_flies_in_the_resolver_directions_at_the_stats_speed`(8 方向) | テスト緑 + **変異 M12 死亡**(生成順の入れ替えで 16 failures) |
| 4.3 | 同 `::..._carry_the_primary_damage_from_stats` ほか 3 項目を差し替え | テスト緑 + **変異 M10 死亡**(`bullet_max_distance` の既定値への固定) |
| 4.4 | 同 `::test_the_fired_direction_stays_an_eight_way_vector2i_while_upgraded` | テスト緑(型の宣言の側は C4 を参照) |
| 4.5 | 同 `::test_the_upgraded_shot_emits_fired_then_spread_fired_once` | テスト緑 |
| 4.6 | 同 `::test_the_spread_fired_directions_match_the_spawned_projectiles_in_order` | テスト緑 + 変異 M12 死亡 |
| 4.7 | 同 `::test_the_upgraded_shot_emits_fired_then_spread_fired_once`(順序) | テスト緑 + **変異 M11 死亡**(発火順の入れ替え) |
| 4.8 | 同 `::test_the_plain_primary_spawns_one_projectile_...` + `::..._emits_fired_without_spread_fired` | テスト緑 + **変異 M9 死亡**(常に拡散側へ倒すと 22 failures) |
| 4.9 | 同 `::test_the_firing_frames_do_not_change_with_the_upgrade` | テスト緑 |
| 4.10 | 同 `::test_the_secondary_weapon_does_not_emit_spread_fired` | テスト緑 |
| 4.11 | 同 `::test_the_upgraded_shot_without_a_projectile_scene_reports_and_emits_nothing` | テスト緑 |
| 4.12 | 同上(`events` が空・子が増えない) | テスト緑 |
| 4.13 | 同 `::..._added_to_the_parent_of_the_player` + `::..._added_to_the_player_when_it_has_no_parent` | テスト緑 |
| 4.14 | 同 `::test_the_spread_projectiles_keep_the_collision_layers_of_the_projectile` | テスト緑 |
| 5.1 | `player_secondary_tint_test::test_the_secondary_firing_frames_do_not_change_with_the_upgrade` | テスト緑 |
| 5.2 | 同 `::test_the_upgraded_secondary_spawns_one_projectile_and_emits_fired_once` | テスト緑 |
| 5.3 | 同 `::test_the_upgraded_secondary_projectile_carries_the_tint`(既定と別の値 + 番人) | テスト緑 |
| 5.4 | 同 `::test_the_plain_secondary_projectile_stays_white` | テスト緑 + **変異 M14 死亡**(常に色を掛ける) |
| 5.5 | 同 `::test_the_default_tint_differs_from_white` | テスト緑 |
| 5.6 | 同 `::test_the_tinted_secondary_projectile_renders_in_another_color`(`.tscn` から解決) | テスト緑 |
| 5.7 | 同 `::test_the_primary_projectiles_stay_white_with_and_without_the_upgrade` | **変異 M13 生存 = 等価変異**(強化中の主武器は `_spawn_projectile()` を通らず差が到達不能。実測で確認) |
| 5.8 | 同 `::test_the_secondary_numbers_do_not_change_with_the_upgrade`(4 項目を差し替え) | テスト緑 + **変異 M15 死亡**(`secondary_damage` の既定値への固定) |
| 5.9 | 同 `::test_the_tint_is_an_export_of_the_player_and_not_of_the_stats` | テスト緑 |
| 5.10 | 同上 + `player_spread_test::test_every_spawned_projectile_belongs_to_the_primary_or_the_secondary_weapon` | テスト緑 |
| 5.11 | 同 `::test_the_tint_default_is_the_same_from_the_script_and_from_the_scene` + `player.tscn` の sha256 | テスト緑 + `git diff` 空 |
| 6.1 | `player_upgrade_test::test_reaching_zero_health_clears_the_upgrade`(`max_health` を差し替え) | テスト緑 |
| 6.2 | 同 `::test_the_upgrade_is_already_cleared_when_died_is_received`(受け手の中で観測) | テスト緑 + **変異 M16 死亡**(`died.emit()` を先に置く) |
| 6.3 | `player_spread_test::test_the_primary_returns_to_one_projectile_after_the_health_reaches_zero` | テスト緑 |
| 6.4 | `player_upgrade_test::test_reaching_zero_health_clears_the_upgrade_outside_the_tree` | テスト緑 |
| 6.5 | 同 `::test_damage_that_leaves_health_keeps_the_upgrade` | テスト緑 + **変異 M17 死亡**(無条件に強化を落とす) |
| 7.1 | `analysis_fragment_test::test_the_fragment_is_an_area` | テスト緑 |
| 7.2 | `analysis_fragment_scene_test::test_the_scene_masks_the_player_layer_only` | テスト緑 + **変異 M20 死亡**(`collision_mask` を 2 → 6) |
| 7.3 | 同 `::test_the_scene_puts_the_fragment_on_no_collision_layer` | テスト緑 |
| 7.4 | `analysis_fragment_test::test_a_body_with_grant_upgrade_takes_the_fragment_and_releases_it` | テスト緑 |
| 7.5 | 同上(接触後に `is_instance_valid()` が偽) | テスト緑 |
| 7.6 | 同 `::test_a_body_without_grant_upgrade_leaves_the_fragment_in_place` ほか | テスト緑 + **変異 M18 死亡**(ガードを外して常に解放) |
| 7.7 | 同 `::test_a_body_that_already_holds_the_upgrade_takes_another_fragment` | テスト緑 |
| 7.8 | 同 `::test_the_fragment_stays_where_it_was_left_while_the_frames_pass`(実フレーム) | テスト緑 |
| 7.9 | 同上(毎フレームの位置を観測) | テスト緑 |
| 7.10 | 同 `::test_the_fragment_outlives_the_contact_callback_and_is_gone_one_frame_later` | テスト緑 + **変異 M21 死亡**(`queue_free()` → `free()` で 7 failures + 7 errors) |
| 7.11 | 同 `::test_the_fragment_source_does_not_name_the_player` + `Player` を継承しないスタブでの 7.4 | テスト緑 |
| 7.12 | `analysis_fragment_scene_test::test_the_placeholder_measures_eight_by_eight_pixels` ほか 3 本 | テスト緑 |
| 7.13 | 同 `::test_the_collision_shape_*`(`position == Vector2.ZERO`) | テスト緑 |
| 7.14 | 同 `::test_the_placeholder_color_is_absent_from_the_existing_placeholder_colors`(9 シーンを `load()`) | テスト緑 + 実行時の画面の色の実測 |
| 7.15 | `player_secondary_tint_test::test_the_fragment_color_differs_from_the_tinted_secondary_projectile` | テスト緑 + 実行時の画面の色の実測(紫 vs 緑) |
| 7.16 | `analysis_fragment_test::test_taking_the_fragment_leaves_the_pause_untouched` ほか | テスト緑 |
| 7.17 | 同 `::test_the_fragment_holds_no_script_variable` | テスト緑 |
| 7.18 | 同 `::test_an_area_that_offers_grant_upgrade_does_not_take_the_fragment` | テスト緑 + **変異 M19 死亡**(`body_entered` → `area_entered` で 14 failures) |
| 8.1 | `analysis_dev_stage_test::test_the_defeat_of_a_transferable_kind_adds_one_fragment_to_the_stage` | テスト緑 + 実行時に断片の出現を実測 |
| 8.2 | 同 `::test_the_fragment_appears_at_the_global_position_of_the_defeated_enemy` | テスト緑 + **変異 M24 死亡**(`global_position` → `position` で 3 failures) |
| 8.3 | 同 `::test_the_fragment_outlives_the_defeated_enemy` | テスト緑 |
| 8.4 | 同 `::test_the_defeat_of_a_non_transferable_kind_adds_no_fragment` | テスト緑 + 実行時に突進型で断片 0 個を実測 |
| 8.5 | 同 `::test_the_stage_source_delegates_the_transferable_judgement` | **変異 M22 死亡。ただし落ちたのは静的検査 1 本のみ**(振る舞いの 2 ケースは緑。[Nit] 参照) |
| 8.6 | 凍結 `ability_analysis_test::test_the_shooter_kind_is_transferable` | テスト緑 + `git diff` 空 |
| 8.7 | 同 `::test_the_charger_kind_is_not_transferable` | テスト緑 + `git diff` 空 |
| 8.8 | 同 `::test_a_value_below/above_the_kinds_pushes_an_error` ほか | テスト緑 + `git diff` 空 |
| 8.9 | `analysis_dev_stage_test::test_a_transferable_defeat_without_a_fragment_scene_pushes_an_error` | テスト緑 |
| 8.10 | 同 `::test_a_non_transferable_defeat_without_a_fragment_scene_pushes_no_error` | テスト緑 + **変異 M23 死亡**(ガードの順序の入れ替え) |
| 8.11 | `analysis_dev_stage_scene_test::test_the_stage_root_declares_exactly_one_packed_scene_export` | テスト緑 |
| 8.12 | 同 `::test_the_declared_fragment_scene_instantiates_an_analysis_fragment` | テスト緑 + **変異 M26 死亡**(参照を `player.tscn` へ差し替え。規律 8 が効いた) |
| 8.13 | 同 `::test_every_enemy_defeat_is_wired_to_the_stage_and_binds_its_own_path` | テスト緑 |
| 8.14 | 同上(`get_bound_arguments()` の解決先が当の敵自身) | テスト緑 |
| 8.15 | `analysis_dev_stage_test::test_a_transferable_defeat_calls_nothing_on_the_player` + 静的検査 | テスト緑 + **変異 M28 死亡**(振る舞い・静的の両方が落ちた) |
| 9.1 | `analysis_dev_stage_scene_test::test_the_project_holds_exactly_one_analysis_dev_stage_scene` | テスト緑 |
| 9.2 | 同 `::test_the_stage_places_terrain_and_the_three_actors` ほか | テスト緑 + 実行時の初期配置の実測 |
| 9.3 | 同 `::test_at_most_two_enemies_stand_inside_the_threat_ring` | **変異 M27 死亡**(3 体目の追加で 9.3 のケース自体も落ちた。下の訂正を参照) |
| 9.4 | 同 `::test_the_far_enemy_starts_outside_its_own_detect_range` | テスト緑 |
| 9.5 | 同 `::test_every_actor_fits_inside_the_floor_horizontally` | テスト緑 + 実行時の画面の実測 |
| 9.6 | 同 `::test_every_actor_stands_on_top_of_the_floor` | テスト緑 + 実行時の画面の実測 |
| 9.7 | 同 `::test_the_stage_fits_the_base_resolution_in_width` + `::test_the_stage_holds_no_camera` | テスト緑 + 実行時に全体が 320×180 に収まることを実測 |
| 9.8 | 同 `::test_every_enemy_targets_the_player_by_the_scene_declaration` | テスト緑 |
| 9.9 | 同 `::test_the_player_death_is_wired_to_the_stage_by_the_scene_declaration` | テスト緑 |
| 9.10 | `analysis_dev_stage_test::test_the_handler_runs_no_reload_inside_its_own_call` | テスト緑 + **変異 M29 死亡**(同期呼び出しへ) |
| 9.11 | `analysis_dev_stage_scene_test::test_no_enemy_appears_while_the_stage_runs` ほか | テスト緑 |
| 9.12 | `git diff 01c1d0e -- src/stage/dev_stage.* enemy_dev_stage.*` が空 | `git diff` |
| 9.13 | `git diff 01c1d0e -- project.godot` が空(`run/main_scene` 不変) | `git diff` |
| 9.14 | `--diff-filter=D` に `analysis_overwrite_dev_stage.tscn` と対のテスト | `git diff` |
| 9.15 | `docs/testing.md` から 2 つ目の仮ステージの段落と起動コマンドが消え、語の検索が 0 件 | `git diff` + grep |
| 9.16 | `docs/testing.md:75-88` の 7 つの箇条書きが 12.1〜12.7 と同順で 1 対 1 | 文書の読解 |
| 9.17 | 差分がハンク 1 つ(`@@ -72,19 +72,23 @@`)で当該の節の内側に収まる | `git diff` + 見出しの行番号 |
| 9.18 | 9 スイート / 135 ケースが配置・命名・引数なしの 4 条を満たす | ファイル一覧 + `skipped 0` |
| 9.19 | `残り回数`・`空枠`・`演出`・`第 3`・`ability_uses`・`飛翔`・`上書き` が 0 件 | grep |
| 10.1 | `--diff-filter=D` に `ability_slot.gd`(+`.uid`)と対のテスト | `git diff` |
| 10.2 | 同フィルタに `analysis_pulse.gd`・`.tscn` と対のテスト 2 本 | `git diff` |
| 10.3 | `player.gd` 全文と `src/` の 9 語の検索が 0 件 | ソース読解 + grep |
| 10.4 | `player_stats.gd` の差分が 4 行の削除のみ | `git diff` の逐行確認 |
| 10.5 | `grep -c '^@export' src/player/player_stats.gd` = 14 + 凍結スイート緑 | **変異 M25 生存 → C2(欠陥)** |
| 10.6 | `src/` の `.gd`/`.tscn`/`.tres` に 9 語が 0 件(陽性対照つき) | grep(**自動の検査は不在。C2 を参照**) |
| 10.7 | `--diff-filter=D` の tests 側が要件 10.7 の列挙 7 本ちょうど(過不足 0) | `git diff` と spec.md の 1 対 1 照合 |
| 10.8 | `player.gd` の武器フィールド 2・シグナル 3 + 振る舞い側 2 ケース | ソース読解 + テスト緑 |
| 10.9 | `git diff 01c1d0e -- ability_analysis.gd ability_analysis_test.gd` が空 | `git diff` + テスト緑 |
| 10.10 | `make test` の統計行 553 / 35 / 全 0 / exit 0 | 実行 |
| 11.1 | `git diff 01c1d0e -- player_command.gd` が空 | `git diff` |
| 11.2 | 同 `-- project.godot` が空 + `[input]` 節の sha256 のケース | `git diff` + テスト緑 |
| 11.3 | 宣言行が `01c1d0e` と文字列として完全一致 | `git show` の比較(**退行を捕らえるテストが無い → C4**) |
| 11.4 | 同 `-- primary_weapon.gd secondary_weapon.gd aim_resolver.gd health.gd` が空 | `git diff` |
| 11.5 | 同 `-- enemy_projectile.gd` が空 | `git diff` |
| 11.6 | 同 `-- src/enemy/` が空 | `git diff` |
| 11.7 | 同 `-- project.godot` が空(`[layer_names]` 1〜5 不変) | `git diff` |
| 11.8 | 同 `-- 001〜004 の 4 ディレクトリ` が空 | `git diff` |
| 11.9 | `--diff-filter=MDR -- tests/` に unit #1〜#3 の既存テストが 1 本も現れない | `git diff --diff-filter=MDR` |
| 11.10 | `projectile_test.gd` が MDR に現れず 19 ケース緑 | `git diff` + テスト緑 |
| 11.11 | `player_stats_test.gd` が MDR に現れず 12 ケース緑 | `git diff` + テスト緑 |
| 11.12 | 同スイートが 14 項目の既定値を 1 つずつ検査して緑 | `git diff` + テスト緑 |
| 12.1 | 撃破前の射撃型 `(160.0, 84.0)` と断片の `global_position` が**差 (0,0)**、親は `AnalysisDevStage` | **実行時の実測**(runtime-smoke が独立に観察) |
| 12.2 | 突進型の撃破の前後を毎フレーム監視し断片は最大 0 個、撃破 2 秒後も 0 個 | **実行時の実測** |
| 12.3 | 接触で `fragments=1→0`・`is_primary_upgraded=false→true`、以後 3 発。**8 方向すべてで中央 ±20.00 度** | **実行時の実測** |
| 12.4 | 強化前の描画ピクセル `(1.0,0.851,0.349)` → 強化後 `(0.349,0.749,0.349)` | **実行時の実測**(画面のピクセル) |
| 12.5 | 12.0 秒放置して `fragments=1`、位置のずれ `(0,0)` | **実行時の実測** |
| 12.6 | hp 0 → 再読込 → プレイヤー `(48,76)`・敵 2 体・断片 0 個で復帰、主武器は **1 発** | **実行時の実測** |
| 12.7 | 通し **1.28 秒**、同区間 224 フレームで**最大フレーム間隔 16.7ms・40ms 超が 0 件** | **実行時の実測** |

#### 変異検査の実測(30 件 / 死亡 25・生存 5)

- **死亡 25 件**: 上の表の「変異 M… 死亡」の行(M1〜M4・M6・M8〜M12・M14〜M24・M26〜M29)。要件 1〜11 の 11 グループすべてで 1 件以上が死亡した。
- **生存 5 件**: M5(2.6)・M7(3.9)・M13(5.7)・M25(10.5/10.6/10.4)・M27 相当の宣言型(11.3)。
  - **等価変異 1 件**: M13(5.7)。強化中の主武器は `_spawn_spread()` を通り `_spawn_projectile()` へ来ないため、`is_secondary and` の有無の差が現在の呼び出し経路では到達不能。本ファイル「タスク 5.3 の学習」の申告どおりであることが実測で確認された。
  - **等価でない生存 4 件**: C1〜C4。いずれも実測または有限性の議論で「落とせる」ことが示された。
- **要件 12 は変異注入の対象外**(spec.md §7 が自動テストで検証しないと定めており、変異を掛ける相手のテストが存在しない)。
- 手順の規律: 30 件すべて `cp` での退避 → 書き換え → 実行 → `cp` での復元 → sha256 での復元の確認、を守った(復元は 30 回すべて基線値に一致)。復元後の `make test` は 553 / 35 / 全 0 / exit 0 を再現し、複製と元の作業ツリーの `diff -r` は差分 0 であった。

#### 本ファイルの既存の記録に対する訂正(パネルの実測が上書きするもの)

1. **「タスク 4.2 の学習」1 件目** — `direction == Vector2.ZERO` の選択を「等価変異」としたのは誤り。極小の非ゼロ向き 1 ケースで落とせる(C3)。
2. **「タスク 3.3 の学習 > 欠陥 1」** — 「要件 11.9 が凍結しているため塞げない」は**既存スイートの改訂に限れば**正しいが、新設スイートでの排他的な検査は 11.9 に触れずに置ける(C2)。
3. **「タスク 5.1 の学習 > 欠陥 1」** — 「要点が指示した走査の範囲内であり要件違反ではない」は、検出力の欠落を正当化しない。3.8 が使う「ちょうどの個数」の形が 3.9 にも適用できる(C1)。
4. **「タスク 2.3 の学習 > 等価変異域」** — 9.3 について「9.2 の体数アサーションが殺しており閾値のロジックが殺したのではない」は実測と食い違う。3 体目を足す変異では **9.3 のケース自体も落ちた**。含意関係の結論(9.2 を破らずに 9.3 だけを落とせない)は正しい。
5. **「凍結の正本」の表の 11.3 の行** — 「宣言行の完全一致 + 4.4・5.2 の振る舞いのテスト」の後半は**宣言の型を観測できない**(実測)。この行の凍結は 1 回きりの手作業の照合だけに依存している(C4)。

### 凍結文書との乖離(最終検証パネルが返した DRIFT)

中間生成物の本文は書き換えず、判定・根拠・置き場の候補だけを転記する(dev-implement 14.2)。

1. **unit #2 `spec.md` §5.6 の `launch(direction: Vector2i, ...)` と実装の `Vector2`。** **実装が正しい**(本単位の spec.md §5.2・§8 が型の拡張を人間の確定済みの決定として明記し、要件 2.1 が課している)。置き場: 既に (1) `tests/weapon/projectile_direction_test.gd`、(2) `projectile.gd` の doc コメント、(3) コミット `e88713f` の本文へ反映済み。追加の対処は不要。
2. **`ZERO_DIRECTION_ERROR` の文言が `Vector2i.ZERO` を指したまま、検査は `Vector2.ZERO`。** **実装が正しく文言だけが古い**(要件 2.7 が据え置きを課している)。置き場: `projectile.gd` の doc コメントに理由と訂正の時期が記載済み。**申し送り**: 同じ文言の複製は非凍結の `tests/weapon/projectile_direction_test.gd` にもあり、訂正する単位は 2 本を同時に直す必要がある。
3. **本ファイル「変更してよい既存ファイル」の定義に `docs/specs/001-mvp/roadmap.md`・`state.json` が入っていない。** **定義のほうが不完全**(両者は SDD の台帳であり unit の作成そのもの = コミット `f1bfca1` が必ず触る。実装タスクは 1 件も触れていない)。置き場: 後続 unit の tasks.md、または `.claude/skills/flow-sdd` 側で「SDD の台帳は境界の定義から除く」ことを明示する。
4. **spec.md §5.6 と要件 8.1・8.3 の検証の形が、実機で必ず物理コールバックの最中に走る `add_child()` を同期に要求している(C5)。** **実行時の観察が正しい**。根拠: (a) ERROR が 8/8 回で決定的に再現、(b) 追加を遅延させる変異で ERROR が消える、(c) **同じファイルの `_on_player_died()` が同一の危険(物理コールバック中の `CollisionObject2D` の操作)を理由に既に `call_deferred` を採っており、プロジェクト自身の規律と矛盾している**。
   - **なお spec.md §5.6 は「いつ」追加するかを定めておらず、主眼は「敵の子にしない(ステージの子にする)」ことである**。`add_child.call_deferred(fragment)` でもステージの子であることは保たれる。したがって**契約そのものより、要件 8.1・8.3 を検証するテストの形(ハンドラを同期に呼んで即座に子を数える)のほうが強く縛っている**可能性がある。この読みの当否は人間の判断に委ねる。
   - 置き場の候補: (1) spec.md §5.6 に追加の時期を定める一文と要件 8.1・8.3 の検証の形の追記(契約の正本)、(2) `analysis_dev_stage.gd` の `_on_enemy_defeated()` の doc コメント(Why not の正本。`_on_player_died()` に同型の記述が既にある)、(3) `tests/stage/analysis_dev_stage_test.gd` を「遅延の後に子が 1 つ増える」形へ改める(What の正本)。

### 最終検証パネルの `[Nit]`(対応を見送ったもの)

いずれも本単位の受け入れ基準に反しないため、パネルの判定には数えていない。

- **8.5 の検出力が静的検査に片寄っている**(test)。`AbilityAnalysis.is_transferable(kind)` を `kind != 1` の直値比較へ置き換える変異で落ちたのは、ソースの文字列を見る 1 ケースだけだった。現状の 2 種別では実害は無いが、種別が増えたときに文字列検査だけが番人になる。
- **`PICKUP_SYMBOLS` の `"grant_ability"` が死んだ検査になっている**(structure)。撤去済みの識別子であり、以後どの変異も落とさない。同配列の `"Player"` は字面を禁じるため、ステージの doc コメントで `Player` に言及できない副作用を持つ。
- **`_spawn_spread()` のループ内の早期 return** が「1〜2 発だけ生成してシグナルを出さない」状態を許すように読める(structure)。実際には失敗要因が `projectile_scene == null` だけで 1 回の呼び出しの中で不変のため 0 発か 3 発にしかならない。unit #4 と同形で本単位が持ち込んだ後退ではない。
- **`SpreadResolver.EIGHT_DIRECTIONS` が非公開で足りる**(structure)。参照は同ファイルの事前条件のガードだけで、テストは意図的に自前の複製を持つ。前身の `CLOCKWISE_RING` も公開だったため後退ではない。
- **中間生成物の ID が `tests/` の 5 箇所のコメントに残る**(structure)。基線 `01c1d0e` の凍結済みファイルに同形が 16 件あり、**既存の慣行の継続**であって本単位が持ち込んだ後退ではない。**`src/` については本単位の追加分がゼロ**。
- **`projectile_direction_test.gd:194` の `PlayerStats.new()` が `auto_free()` を通っていない**(structure)。`Resource` は参照カウントで解放されるため `orphans` は 0 のままだが、本単位の他の 5 スイートは一貫して `auto_free()` としており体裁が揃っていない。
- **`check.py` の warning 3 件はいずれも分割不要**(structure の意味判断)。`tasks.md` は完了と同時に凍結され以後変更されない。`player_spread_test.gd` は全ケースが要件 4 という 1 つの関心に属し、生成ヘルパを全群が共有する。`analysis_dev_stage_scene_test.gd` は継ぎ目が弱いながら実在するが、分割の費用(走査ヘルパの複製、または 1 つの `.tscn` に 3 本目のスイート)が利得を上回る。
- **断片の 8×8 は敵の 16×16 の 1/4 の面積で、320×180 の等倍では小さい**(runtime-smoke)。spec.md §5.4 のとおりであり情報提供に留まる。
- **gdUnit4 の取得がアーカイブの sha256 を固定していない / CI に `permissions:` の明示が無い / action がタグ参照**(security)。いずれも既存事項であり、**本単位は `scripts/`・`.github/`・`.claude/`・`project.godot`・`addons/` を 1 行も変更していない**。別の作業単位として起票する価値はある。

