# foot-enemies — 実装タスク

> 仕様の詳細は同じディレクトリの仕様文書 spec.md を参照する。
> このファイルには仕様を転記しない。

## File Structure Plan

| ファイルパス | 区分 | 責務 |
| ------------ | ---- | ---- |
| `src/enemy/enemy_stats.gd` | 新規 | 敵の手触りを決める数値を `@export` で 1 箇所に集約する `Resource` |
| `src/enemy/charger_stats.tres` | 新規 | 突進型の既定値の実体(種別ごとに 1 個を全個体で共有する) |
| `src/enemy/shooter_stats.tres` | 新規 | 射撃型の既定値の実体(同上) |
| `src/enemy/enemy_state.gd` | 新規 | 2 種の敵が共有する状態の enum |
| `src/enemy/enemy_kind.gd` | 新規 | 敵の種別の enum(`defeated` の引数の型) |
| `src/enemy/enemy.gd` | 新規 | 体力・撃破・重力・標的の解決を持つ `CharacterBody2D` の基底 |
| `src/enemy/hurtbox.gd` | 新規 | 入ってきた領域の `damage` を親の `take_damage()` へ渡す `Area2D` |
| `src/enemy/hurtbox.tscn` | 新規 | `Hurtbox` + `CollisionShape2D`(本体と同じ矩形。2 種の敵が共有する) |
| `src/enemy/attackbox.gd` | 新規 | 突進中だけプレイヤーへ 1 回だけダメージを与える `Area2D`(与済みの記録を持つ) |
| `src/enemy/charger_brain.gd` | 新規 | 突進型の状態遷移(`RefCounted`、純ロジック) |
| `src/enemy/charger_enemy.gd` | 新規 | `ChargerBrain` の状態を水平の速度と `Attackbox` の `monitoring` へ写す |
| `src/enemy/charger_enemy.tscn` | 新規 | `ChargerEnemy` + placeholder + `CollisionShape2D` + `Hurtbox` + `Attackbox` |
| `src/enemy/shooter_brain.gd` | 新規 | 射撃型の状態遷移(`RefCounted`、純ロジック) |
| `src/enemy/shooter_enemy.gd` | 新規 | `ShooterBrain` が真を返したフレームで敵弾を生成・発射する |
| `src/enemy/shooter_enemy.tscn` | 新規 | `ShooterEnemy` + placeholder + `CollisionShape2D` + `Hurtbox` + `projectile_scene` の設定 |
| `src/weapon/enemy_projectile.gd` | 新規 | 任意方向へ直進し、地形・プレイヤー・射程超過で解放される `Area2D` |
| `src/weapon/enemy_projectile.tscn` | 新規 | `EnemyProjectile` + placeholder + `CollisionShape2D` |
| `src/stage/enemy_dev_stage.gd` | 新規 | `player.died` を受けて現在のシーンを再読込する |
| `src/stage/enemy_dev_stage.tscn` | 新規 | 床・壁と `Player`・`ChargerEnemy`・`ShooterEnemy` を配置した敵の確認用の仮ステージ |
| `docs/testing.md` | 変更 | `enemy_dev_stage.tscn` の起動方法を「仮ステージを目視で確認する」の節へ追記する |
| `tests/enemy/enemy_stats_test.gd` | 新規 | `EnemyStats` の既定値・0 の意味・`CombatLimits` への準拠のテスト |
| `tests/enemy/enemy_test.gd` | 新規 | `Enemy` の体力・撃破・`stats` の検査・重力・標的の解決のテスト |
| `tests/enemy/hurtbox_test.gd` | 新規 | `Hurtbox` の被弾の中継と異常系のテスト |
| `tests/enemy/charger_brain_test.gd` | 新規 | `ChargerBrain` の状態遷移のテスト |
| `tests/enemy/charger_enemy_test.gd` | 新規 | 突進型の速度への写像・`Attackbox`・シーン構成のテスト |
| `tests/enemy/shooter_brain_test.gd` | 新規 | `ShooterBrain` の状態遷移のテスト |
| `tests/enemy/shooter_enemy_test.gd` | 新規 | 射撃型の発射・シーン構成・異常系のテスト |
| `tests/weapon/enemy_projectile_test.gd` | 新規 | `EnemyProjectile` の移動・射程・衝突・異常系のテスト |
| `tests/stage/enemy_dev_stage_test.gd` | 新規 | 仮ステージの構成・配置規約・`died` の接続のテスト |

削除対象はない(本単位は既存の置換・廃止を伴わない)。`addons/gdUnit4/` と `reports/` は生成物であり、この計画には載せない。`.gd` を足すと Godot が `.gd.uid` を生成し追跡対象になるため、スクリプトと `.uid` を対にしてステージする(unit #2 の申し送り)。

**変更してはならない既存ファイル**(要件 9.5・10.5・7.3・スコープ外): `src/stage/dev_stage.tscn`、`src/weapon/combat_limits.gd`、`src/weapon/projectile.gd` / `projectile.tscn`、`src/player/` 一式、`project.godot`。タスク 6.4 が内容ハッシュで確認する。

### 分解時に埋めた仕様の空白(実装者への申し送り)

spec.md が定めておらず、実装に必要なため本分解で決めた事項。**契約の変更ではなく、契約から一意に決まらない実装の選択**である。

- **`Attackbox` のファイルの置き場所**: `src/enemy/attackbox.gd`。spec.md §5.9 は `class_name Attackbox` を定めるが、§6.5 のファイルの一覧に対応する行が無い。`Attackbox` は突進型だけが持ち、`charger_enemy.tscn` の子ノードとして宣言するため、`hurtbox.tscn` のような単体のシーンは作らない(2 種で共有する `Hurtbox` と非対称なのはこの理由による)。
- **`Enemy` 単体のシーンを作らない**: §6.5 に `enemy.tscn` が無い。基底の物理(重力・接地)を検証するタスク 2.3 は `charger_enemy.tscn` を器として使う。
- **`charger_enemy.gd` を 2 段階で作る**: タスク 2.3 では `kind()` と placeholder・衝突形状だけを持つ骨格として作り、`brain` と速度への写像はタスク 3.3 で足す。被弾(§3 の未検証の前提)の確認を状態遷移より前に置くためである。
- **衝突ビットの整数値**(unit #2 の実測に基づく換算。レイヤ番号は 1 始まり、プロパティは 0 始まりのビットマスク): `Enemy` は layer 8・mask 1、`Hurtbox` は layer 8・mask 4、`Attackbox` は layer 0・mask 2、`EnemyProjectile` は layer 16・mask 3。

## タスク一覧

- [ ] 1. 共有の型と数値の確定(契約先行)

  タスク 3・4・5 は並行して進められるが、いずれも `EnemyStats` と 2 つの enum を共有する。Step 4(契約先行)に従い、共有する契約を最初に確定させる。

  - [x] 1.1 `EnemyStats`(`Resource`)と `EnemyState`・`EnemyKind` の enum、2 種の `.tres` を作り、既定値・0 の意味・`CombatLimits` への準拠をテストで固定する
    _Requirements: 7.1, 7.2, 7.3, 8.2, 8.5, 8.6, 8.7_
    _Boundary: EnemyStats_
    - 対象ファイル: `src/enemy/enemy_stats.gd`(新規), `src/enemy/enemy_state.gd`(新規), `src/enemy/enemy_kind.gd`(新規), `src/enemy/charger_stats.tres`(新規), `src/enemy/shooter_stats.tres`(新規), `tests/enemy/enemy_stats_test.gd`(新規)
    - 仕様参照: spec.md §6.1、§6.2、§6.3、§7 Requirement 7・8
    - 実装の要点(タスク固有):
      - 8.5 は `.tres` を読み込んで 10 項目 × 2 種を厳密比較する。値をテスト側に定数として持ち、実装から参照しない(unit #2 の申し送り「異常系のテストは実装の定数をテストから参照しない」と同じ理由で、値の退行を検出できるようにする)
      - 8.7 は `.tres` が外部ファイルとして存在すること(`ResourceLoader.exists()`)と、`charger_enemy.tscn` / `shooter_enemy.tscn` が埋め込みサブリソースを持たないことで示す。シーン側の検証はタスク 2.3・5.3 で対象のシーンが揃ってから足してよい
      - 8.2 は `load()` を 2 回行って同一インスタンスであること(`assert_object(a).is_same(b)`)と、`resource_local_to_scene` が偽であることで示す
      - 8.6 は 2 つの `.tres` の値から算出する不等式で示す(射撃型は成立、突進型は弾を持たないため対象外)
      - 7.1・7.2 は `CombatLimits` の定数と 2 種の値を比較する。7.3 は `src/weapon/combat_limits.gd` を変更しないことであり、検証コマンドの内容ハッシュで示す(既存の `tests/weapon/combat_limits_test.gd` が値そのものを固定している)
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`test "$(git hash-object src/weapon/combat_limits.gd)" = "34f2402a38e7a55fcd1f642216fa4a8d658e6d15" && echo OK`

- [ ] 2. 敵の基底とプレイヤーの弾による被弾(リスク先行の垂直スライス)

  spec.md §3 の未検証の前提のうち最も重いもの(`Hurtbox` の `area_entered` による検出と、同じフレームの `Projectile` 自身による解放が両立すること)を、状態遷移より前に確かめる。この前提が崩れると要件 6 と §5.6 の設計が組み替えになる。「プレイヤーが撃つ → 敵の体力が減る → 撃破される」を縦に貫くスライスとして進める。

  - [ ] 2.1 `Enemy` の体力・被弾・撃破のシグナルと `kind()` の基底実装を作る
    _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.10, 1.23_
    _Boundary: Enemy_
    _Depends: 1.1_
    - 対象ファイル: `src/enemy/enemy.gd`(新規), `tests/enemy/enemy_test.gd`(新規)
    - 仕様参照: spec.md §5.1、§7 Requirement 1
    - 実装の要点(タスク固有):
      - このサブタスクの検証はツリーへ載せずに直接呼ぶ(spec.md §7 Requirement 1 の「検証の形式」)。`stats` はテストが `EnemyStats.new()` を作って代入し、**既定値のままにしない**(既定値だと実装が値を直書きしても緑になる。unit #2 の申し送り)
      - 1.4 と 1.6 は分岐の両側であり、個別のテストケースを割り当てる。発火回数は `Array` へ控えて厳密比較する(`assert_signal` の `is_not_emitted()` は引数まで一致したときだけ発火と見なす。unit #2 の申し送り)
      - 1.10 は「解放より先に発火する」順序の要求である。`defeated` の受け手の中で `is_instance_valid()` と `is_defeated` を読むことで順序を固定する
      - 1.7 は `await assert_error(func() -> void: ...).is_push_error("<文言>")` で検証し、`hp` が変わらないことも併せて見る。異常値の表に負値と 0 の両方を入れる(unit #2 の申し送り)
      - 1.23 は `Enemy.new()` を直接生成して `kind()` を読む
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 2.2 `stats` の未設定と不変条件違反の検査を `_ready()` に置く
    _Requirements: 1.8, 1.9, 8.3, 8.4_
    _Boundary: Enemy_
    _Depends: 2.1_
    - 対象ファイル: `src/enemy/enemy.gd`(変更), `tests/enemy/enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.1「`stats` の検査」、§6.1「不変条件」、§7 Requirement 1.8・1.9・8.3・8.4
    - 実装の要点(タスク固有):
      - 8.4 は「項目名を固定で列挙しない」ことを求める。`get_property_list()` を `PROPERTY_USAGE_SCRIPT_VARIABLE` と `PROPERTY_USAGE_EDITOR` の両ビット・`TYPE_FLOAT` / `TYPE_INT` で絞り、**0 を許す項目名の集合だけ**を実装が持つ(`Player._ready()` の既存実装が近い形を持つが、あちらは 0 を一切許さない。写すのではなく、許可集合を持つ形へ変える)
      - 8.3 と 8.4 は分岐の両側である。0 を許す 3 項目に 0.0 を入れて `push_error` が**出ない**こと(`assert_error(...).is_success()`)と、それ以外の項目に 0 と負値を入れて出ることの両方に個別のテストケースを割り当てる
      - 1.8 のフォールバックは値を代入する側であり、1.9 は代入しない(値は補正しない)。この非対称をテストで固定する
      - `_ready()` を通す必要があるため、`Enemy.new()` を `add_child()` する(`add_child()` は同期で `_ready()` まで走り物理フレームは進まない。unit #2 の申し送り)。`auto_free()` と対にする
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 2.3 `charger_enemy.tscn` の骨格(placeholder・衝突形状・レイヤ)と `Enemy` の物理(重力・接地・`move_and_slide()`)・標的の解決を実装する
    _Requirements: 1.12, 1.14, 1.16, 1.17, 1.18, 1.19, 10.1_
    _Boundary: Enemy_
    _Depends: 2.2_
    - 対象ファイル: `src/enemy/enemy.gd`(変更), `src/enemy/charger_enemy.gd`(新規), `src/enemy/charger_enemy.tscn`(新規), `tests/enemy/enemy_test.gd`(変更), `tests/enemy/charger_enemy_test.gd`(新規)
    - 仕様参照: spec.md §5.1「重力に従う」「placeholder と衝突形状」「標的の解決」「標的が不在のフレーム」、§6.4、§7 Requirement 1
    - 実装の要点(タスク固有):
      - この時点の `charger_enemy.gd` は `kind()` と `stats` の割り当てだけを持つ骨格でよい(`brain` はタスク 3.3 で足す。File Structure Plan の申し送りを参照)
      - 1.12 は `instantiate()` + `auto_free()` でシーンを読み、`ColorRect` の `size` と `CollisionShape2D` の `shape.size` がともに 16×16px、原点が矩形の中心にあること(`ColorRect` の `position` が `Vector2(-8, -8)`、`CollisionShape2D` の `position` が `Vector2.ZERO`)で検証する。ノード名は `player.tscn` に倣って `Placeholder` とする
      - 1.17 と 1.18 は分岐の両側である。接地側は `StaticBody2D`(layer 1)の床を置いて立たせる。非接地側は床を置かない
      - 1.14 は `target` を `null` にした場合と、`queue_free()` 済みのノードを指した場合の 2 経路に個別のテストケースを割り当て、`assert_error(...).is_success()` で `push_error` が出ないことを見る
      - 1.16 は `target` が `@export` であること(`get_property_list()` の `PROPERTY_USAGE_EDITOR` ビット)と、代入した値が物理フレームを跨いで保たれること(内部で検索して上書きしないこと)で示す
      - 1.19 は `enemy.gd` の静的な検査で示す(`_physics_process` の中に `move_and_slide()` があり、速度の決定より後ろにあること)
      - 10.1 は `collision_layer` = 8、`collision_mask` = 1 の整数値を直接アサーションする(File Structure Plan の換算を参照)
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`grep -n 'move_and_slide' src/enemy/enemy.gd`(出現が `_physics_process` の中の 1 箇所だけであること)
  - [ ] 2.4 `Hurtbox` を実装して `charger_enemy.tscn` へ組み込み、プレイヤーの弾で被弾・撃破されることを検証する
    _Requirements: 1.13, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 10.2_
    _Boundary: Hurtbox_
    _Depends: 2.3_
    - 対象ファイル: `src/enemy/hurtbox.gd`(新規), `src/enemy/hurtbox.tscn`(新規), `src/enemy/charger_enemy.tscn`(変更), `tests/enemy/hurtbox_test.gd`(新規)
    - 仕様参照: spec.md §5.6、§6.4、§7 Requirement 6、§3 の未検証の前提(`area_entered` と `body_entered` の両立)
    - 実装の要点(タスク固有):
      - 6.4 が §3 の未検証の前提そのものである。`Projectile` を実際に発射して当て、**敵の `hp` が減ること**と**弾が解放されること**の両方を 1 つのテストで確かめる。両立しない場合は実装を進めず、観測した挙動を `## Implementation Notes` へ記録してから停止し、上流(spec.md §5.6)の判断を仰ぐ
      - `Area2D` の重なりの通知は 1 物理フレーム遅れる(unit #2 の実測)。接触の時刻を検証するテストは 2 フレーム分を上限に取る
      - 6.3 は「`Hurtbox` から弾を解放しない」ことである。`hurtbox.gd` に `queue_free()` が現れないことの静的な検査と、`Hurtbox` だけを単体で置いて `damage` を持つダミーの `Area2D` を入れ、そのダミーが解放されないことの 2 つで示す
      - 6.1 と 6.2 は分岐の両側であり、個別のテストケースを割り当てる。6.5 は親が `take_damage` を持たない場合であり、`Node2D` を親にしたダミーで検証する
      - 6.6 は主武器の弾 3 発ぶんの `take_damage(10)` を突進型の `.tres` の `max_hp` に対して与え、`defeated` の発火を見る。既定の `.tres` を使うためここでは値を差し替えない(要件 8.5 が値を固定している)
      - 1.13 は `Hurtbox` の `CollisionShape2D` の `shape.size` と `position` が本体のものと一致すること(はみ出さないこと)で検証する
      - 10.2 は `Hurtbox` の `collision_layer` = 8、`collision_mask` = 4 の整数値を直接アサーションする
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`grep -c 'queue_free' src/enemy/hurtbox.gd`(0 であること)

- [ ] 3. 突進型(状態遷移 → 移動 → 攻撃判定)

  - [ ] 3.1 (P) `ChargerBrain` の状態遷移(正常系)を実装する
    _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.8, 2.9_
    _Boundary: ChargerBrain_
    _Depends: 1.1_
    - 対象ファイル: `src/enemy/charger_brain.gd`(新規), `tests/enemy/charger_brain_test.gd`(新規)
    - 仕様参照: spec.md §5.4、§7 Requirement 2
    - 実装の要点(タスク固有):
      - `RefCounted` の純ロジックであり、`update()` を直接呼ぶ(物理フレーム不要)。時間の定数は 2 進で厳密に表せる値を使い、「境界のすぐ内側」は絶対値ではなく**比**で近づける(unit #2 の申し送り。`telegraph_time - 2^-20` の形)
      - 到達可能な状態 × 距離の表を `[state, is_attack_active]` の混在型 `Array` で 1 回の `assert_array(...).is_equal()` に掛ける(unit #2 の申し送り)。2.8 は表の全行で担保する
      - 2.3 は「突進の到達距離以下」が条件であり `detect_range` ではない。**`detect_range` と到達距離の両方を跨ぐ距離**でテストを組み、条件を `detect_range` へ差し替える変異が落ちることを確かめる(既定値では 128.0 と 90.0 で別の値になる)
      - 2.9 は遷移したフレームの `delta` を遷移先へ数えないことである。遷移の直後に「残り 1 フレームで満了する」入力を与え、満了が 1 フレーム遅れることで観測する
      - `stats` は `EnemyStats.new()` に既定と異なる値を入れて渡し、`_init()` の引数が実際に使われていることを長短 2 つのインスタンスの比較で示す(unit #2 の申し送り)
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 3.2 `ChargerBrain` の異常系(引数の検査・距離による打ち切りの禁止・標的の不在)を実装する
    _Requirements: 2.7, 2.10, 2.11_
    _Boundary: ChargerBrain_
    _Depends: 3.1_
    - 対象ファイル: `src/enemy/charger_brain.gd`(変更), `tests/enemy/charger_brain_test.gd`(変更)
    - 仕様参照: spec.md §5.4「事前条件」、§5.1「標的が不在のまま攻撃のフレームに達したとき」、§7 Requirement 2.7・2.10・2.11
    - 実装の要点(タスク固有):
      - 2.10 のガードは関数の先頭に置く(unit #2 の申し送り)。`delta` の異常値と `distance_to_target` の異常値それぞれに個別のテストケースを割り当て、`state` と `is_attack_active` が変わらないことも見る
      - 2.11 と 2.4 は `TELEGRAPH` 満了時の分岐の両側である(有限 → `CHARGE`、`INF` → `RECOVER`)。個別のテストケースを割り当てる。`INF` は事前条件の「0 以上」を満たすため `push_error` を出さない — この非対称をテストで固定する
      - 2.7 は `TELEGRAPH`・`CHARGE`・`RECOVER` の 3 状態それぞれについて、滞在中に距離を大きく振っても満了まで遷移しないことで示す
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 3.3 `ChargerEnemy` に `brain` を持たせ、状態を水平の速度へ写す
    _Requirements: 1.15, 1.21, 1.22, 3.1, 3.2, 3.3, 3.4_
    _Boundary: ChargerEnemy_
    _Depends: 2.4, 3.2_
    - 対象ファイル: `src/enemy/charger_enemy.gd`(変更), `tests/enemy/charger_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.2、§5.4「ロジックの所在」、§7 Requirement 3.1〜3.4・1.15・1.21・1.22
    - 実装の要点(タスク固有):
      - 3.1 と 3.2 は `IDLE` における `detect_range` の分岐の両側であり、個別のテストケースを割り当てる。接近の向き(標的が左/右)も両側を見る
      - 3.4 は「突進を始めた時点の向きを保つ」ことである。`CHARGE` の途中で標的を反対側へ動かし、速度の符号が変わらないことで示す
      - 1.15 は `IDLE` で `target` を `null` にした場合であり、`state` が `IDLE` のまま・水平の速度が 0 であることを見る。`TELEGRAPH` 以降で失った場合(2.7・2.11)と混同しない
      - 1.21 は `target` に位置を制御できるスタブ(`Node2D`)を注入し、規定のフレーム数を過ぎたら索敵範囲の外へ動かして移動を打ち切る形で検証する(spec.md §7 Requirement 1 の「検証の形式」)。期待値は `速度 / Engine.physics_ticks_per_second * フレーム数` で算出し、実数を直書きしない。消化フレーム数も併せてアサーションする
      - 注入するスタブはスイートのメンバに抱える(`Callable` / ノードの参照が切れて毎フレーム null 参照のエラーが出る事故を避ける。unit #2 の申し送り)
      - 1.22 は `brain` が外から読める公開点であることの検証であり、射撃型でも同じ形で見る(タスク 5.3)
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 3.4 `Attackbox` を実装し、突進中だけ 1 回だけダメージを与える
    _Requirements: 3.5, 3.6, 3.7, 3.8, 3.9, 10.3_
    _Boundary: Attackbox_
    _Depends: 3.3_
    - 対象ファイル: `src/enemy/attackbox.gd`(新規), `src/enemy/charger_enemy.tscn`(変更), `src/enemy/charger_enemy.gd`(変更), `tests/enemy/charger_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.9、§5.2「`_ready()` で `Attackbox.damage` に `stats.attack_damage` を代入する」、§6.4、§7 Requirement 3.5〜3.9・10.3
    - 実装の要点(タスク固有):
      - 与済みの記録は `Attackbox` が持ち、`ChargerEnemy` は `CHARGE` へ入るたびに `arm()` を呼ぶ。3.7(触れ続けても 2 回目が入らない)と 3.8(次の突進では入る)は分岐の両側であり、個別のテストケースを割り当てる
      - 3.5 は `monitoring` が `brain.is_attack_active` に一致することであり、`CHARGE` の間と `CHARGE` 以外の少なくとも 2 状態で見る
      - 3.9 は `take_damage` を持たない相手であり、`push_error` を出さない(`assert_error(...).is_success()`)。`Hurtbox` の 6.5(`push_error` を出す)との非対称をテストで固定する
      - `damage` はシーンへ焼き込まず `_ready()` で `stats.attack_damage` から代入する(要件 8.1 の対象。タスク 6.4 の検査に掛かる)。テストは `stats` に既定と異なる値を入れて、その値が相手へ届くことを見る
      - 10.3 は `collision_layer` = 0、`collision_mask` = 2 の整数値を直接アサーションする
      - 相手の検出は `body_entered`(プレイヤーは `CharacterBody2D`)であり、`area_entered` ではない
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 3.5 撃破された後に `Attackbox` の `monitoring` を偽に保つ
    _Requirements: 3.10_
    _Boundary: ChargerEnemy_
    _Depends: 3.4_
    - 対象ファイル: `src/enemy/attackbox.gd`(変更), `src/enemy/charger_enemy.gd`(変更), `tests/enemy/charger_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.2「`is_defeated` が真になった後は…優先する」、§5.9、§7 Requirement 3.10
    - 実装の要点: 3.5 と 3.10 は優先順位が逆転する分岐であり、**`is_attack_active` が真のまま撃破される**状況(`CHARGE` の最中に `take_damage()` で `hp` を 0 にする)を作って、同じ物理フレームのうちに `monitoring` が偽になることを見る。解放(`queue_free()`)の反映を待つ前に読む必要があるため、`is_instance_valid()` の確認と併せて組む
    - 検証コマンド: `make test TESTS=res://tests/enemy`

- [ ] 4. (P) 敵弾

  `EnemyProjectile` は `EnemyStats` にも `Enemy` にも依存せず(値はすべて `launch()` の引数で受け取る)、タスク 1 の完了を待たずに始められる。

  - [ ] 4.1 `EnemyProjectile` と `enemy_projectile.tscn` を作り、`launch()` 後の直進・射程・衝突レイヤを検証する
    _Requirements: 5.1, 5.2, 5.7, 5.8, 10.4_
    _Boundary: EnemyProjectile_
    - 対象ファイル: `src/weapon/enemy_projectile.gd`(新規), `src/weapon/enemy_projectile.tscn`(新規), `tests/weapon/enemy_projectile_test.gd`(新規)
    - 仕様参照: spec.md §5.7、§6.4、§7 Requirement 5
    - 実装の要点(タスク固有):
      - **距離・速さ・射程のテストに斜めの方向のケースを必ず含める**(unit #2 の実測: 軸方向だけだと `distance_to()` を `absf(x の差)` へ置き換える変異が全ケース素通りした)
      - 移動は `_physics_process` で行い、テストはツリーへ載せて `await await_millis()` で待ち、`frames_moved` と変位の両方を検証する(`docs/testing.md`「物理フレームを進めるテスト」)
      - 射程の基準は `launch()` を呼んだ時点の位置である。テストも実装も「`add_child()` → 位置を決める → `launch()`」の順に書く(unit #2 の申し送り)
      - 5.8(`launch()` 前は移動しない)と 5.1 は分岐の両側である。5.8 はツリーへ載せて待ってから位置が動いていないことと `frames_moved` が進んでいることの両方を見る(待ちが足りなかった場合と区別する)
      - `direction` は `Vector2`(任意方向)であり `Vector2i` ではない。非正規化のベクトルを渡して、速さが `speed` になることを見る
      - 10.4 は `collision_layer` = 16、`collision_mask` = 3 の整数値を直接アサーションする。placeholder と衝突矩形は `projectile.tscn` に倣って 4×4px・原点は矩形の中心とする
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [ ] 4.2 地形とプレイヤーへの衝突を実装する
    _Requirements: 5.3, 5.4_
    _Boundary: EnemyProjectile_
    _Depends: 4.1_
    - 対象ファイル: `src/weapon/enemy_projectile.gd`(変更), `tests/weapon/enemy_projectile_test.gd`(変更)
    - 仕様参照: spec.md §5.7、§8「相手を型ではなくメソッド・プロパティの有無で見る」
    - 実装の要点(タスク固有):
      - 地形(`StaticBody2D`)もプレイヤー(`CharacterBody2D`)も `PhysicsBody2D` であり、検出は `body_entered` を使う。相手は型ではなく `has_method(&"take_damage")` で見分け、`Player` へ静的に依存しない
      - 5.3(地形 → ダメージなしで解放)と 5.4(プレイヤー → `take_damage()` してから解放)は分岐の両側であり、個別のテストケースを割り当てる。解放の確認は `is_instance_valid()` で行い、`queue_free()` の反映を待つ
      - 5.4 のダメージ量は `launch()` で受け取った値であり、`stats` や定数から読み直さない
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [ ] 4.3 `launch()` の異常系を実装する
    _Requirements: 5.5, 5.6_
    _Boundary: EnemyProjectile_
    _Depends: 4.2_
    - 対象ファイル: `src/weapon/enemy_projectile.gd`(変更), `tests/weapon/enemy_projectile_test.gd`(変更)
    - 仕様参照: spec.md §5.7「事前条件」「不変条件」、§7 Requirement 5.5・5.6
    - 実装の要点(タスク固有): 4 つの異常な引数それぞれに個別のテストケースを割り当て、`push_error`・弾が進まないこと・**`damage` が変わらないこと**の 3 つを見る(ガードを代入の後ろへ移す変異を捕らえる。unit #2 の申し送り)。異常値の表に負値と 0 の両方を入れる。5.5 は正常系でも見る(`launch()` の後に `damage` を書き換える経路が無いこと)
    - 検証コマンド: `make test TESTS=res://tests/weapon`

- [ ] 5. 射撃型(状態遷移 → 発射)

  - [ ] 5.1 (P) `ShooterBrain` の状態遷移を実装する
    _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.11, 4.12_
    _Boundary: ShooterBrain_
    _Depends: 1.1_
    - 対象ファイル: `src/enemy/shooter_brain.gd`(新規), `tests/enemy/shooter_brain_test.gd`(新規)
    - 仕様参照: spec.md §5.5、§7 Requirement 4.1〜4.6・4.11・4.12
    - 実装の要点(タスク固有):
      - `ChargerBrain`(タスク 3.1)と同じ形で組む(2 進で厳密な時間の定数、到達可能な状態 × 入力の表、`_init()` の引数が使われていることの検証)
      - 4.6(真を返すのは 1 フレームだけ)は、`TELEGRAPH` の満了フレームの前後を含む連続したフレーム列の戻り値を `Array` に並べて厳密比較する。4.3・4.4 はこの列で同時に担保される
      - 4.2 の条件は `detect_range` である(突進型が到達距離を使うのと異なる)。**両方の値を跨ぐ距離**でテストを組み、条件を取り違える変異が落ちるようにする
      - 4.11・4.12 は `ChargerBrain` の 2.7・2.9 と同じ形で見る
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 5.2 `ShooterBrain` の引数の異常系を実装する
    _Requirements: 4.10_
    _Boundary: ShooterBrain_
    _Depends: 5.1_
    - 対象ファイル: `src/enemy/shooter_brain.gd`(変更), `tests/enemy/shooter_brain_test.gd`(変更)
    - 仕様参照: spec.md §5.5「事前条件・事後条件・不変条件」、§7 Requirement 4.10
    - 実装の要点: ガードは関数の先頭に置く。`delta` と `distance_to_target` それぞれに個別のテストケースを割り当て、`push_error`・戻り値が偽であること・`state` が変わらないことを見る。`INF` は正常な入力であり弾かない(4.13 の経路)
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 5.3 `ShooterEnemy` と `shooter_enemy.tscn` を作り、敵弾の生成と発射を実装する
    _Requirements: 1.11, 1.22, 4.7, 4.8, 4.14, 9.10_
    _Boundary: ShooterEnemy_
    _Depends: 2.4, 4.3, 5.2_
    - 対象ファイル: `src/enemy/shooter_enemy.gd`(新規), `src/enemy/shooter_enemy.tscn`(新規), `tests/enemy/shooter_enemy_test.gd`(新規), `tests/enemy/enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.3、§7 Requirement 4.7・4.8・4.14・1.11・1.22・9.10
    - 実装の要点(タスク固有):
      - `shooter_enemy.tscn` は `charger_enemy.tscn` と同じ placeholder・衝突形状・`Hurtbox` を持ち、`Attackbox` は持たない。`stats` に `shooter_stats.tres`、`projectile_scene` に `enemy_projectile.tscn` を設定する(9.10)
      - 4.7 は生成先の子ノード数の増分と、生成された `EnemyProjectile` に渡った向き・速さ・ダメージ・射程の 4 つで検証する。値は `stats` から読み、実装へ直書きしない。向きは標的への単位ベクトルであり、**斜めの配置**のケースを含める
      - 4.14 は「親へ追加し、位置を決めてから `launch()` を呼ぶ」順序の要求である。敵自身を親のあるノードの下に置き、生成された弾の親と `launch()` 時点の位置(射程の基準)の両方を見る
      - 4.8 は射撃型が水平に動かないことであり、標的を索敵範囲の内外に置いた両方で位置の x が変わらないことを見る
      - 1.11 は 2 種の `kind()` を並べて検証する(突進型は既に存在する)。1.22 は `brain` の公開点であり、突進型(タスク 3.3)と同じ形で見る
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [ ] 5.4 発射の異常系(`projectile_scene` の未設定・標的の不在)を実装する
    _Requirements: 4.9, 4.13_
    _Boundary: ShooterEnemy_
    _Depends: 5.3_
    - 対象ファイル: `src/enemy/shooter_enemy.gd`(変更), `tests/enemy/shooter_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.3「`projectile_scene` が未設定の場合」、§5.1「標的が不在のまま攻撃のフレームに達したとき」、§7 Requirement 4.9・4.13
    - 実装の要点(タスク固有):
      - **人間が確定済みの判断(spec は改訂しない)**: 受け入れ基準 4.9 と 4.13 は条件が重なり、両方が成立する状態(`projectile_scene` が未設定 **かつ** 標的が不在)で `push_error` の要否について逆のことを述べる。**実装では 4.9 を優先し、両方が成立する場合も `push_error` を出す**。弾を生成しない点は両者一致するため、差はログの 1 行に限られる。**この選択を推測で入れ替えないこと**
      - テストケースは 3 つに分ける: (a) `projectile_scene` 未設定・標的あり → `push_error` + 弾なし、(b) `projectile_scene` 設定済み・標的なし → `push_error` なし(`assert_error(...).is_success()`)+ 弾なし + `COOLDOWN` へ移る、(c) 両方が成立 → `push_error` + 弾なし(上の確定済みの判断)
      - いずれの経路でも `ShooterBrain` の状態は進む(発射を取りやめても周期は止まらない)。(b) は `COOLDOWN` への遷移を明示的に見る
      - 標的の不在は `null` と解放済みの 2 経路がある。少なくとも `null` を (b) で、解放済みを別ケースで見る
    - 検証コマンド: `make test TESTS=res://tests/enemy`

- [ ] 6. 仮ステージ・文書・横断の検査

  - [ ] 6.1 `enemy_dev_stage.tscn` を作り、配置規約と `died` の接続を検証する
    _Requirements: 9.1, 9.2, 9.4, 9.5, 9.6, 9.7, 9.9, 9.11_
    _Boundary: EnemyDevStage_
    _Depends: 3.5, 5.4_
    - 対象ファイル: `src/stage/enemy_dev_stage.gd`(新規), `src/stage/enemy_dev_stage.tscn`(新規), `tests/stage/enemy_dev_stage_test.gd`(新規)
    - 仕様参照: spec.md §5.8、§6.5、§7 Requirement 9
    - 実装の要点(タスク固有):
      - シーンの構成を検証するテストは**ツリーへ載せない**(`instantiate()` + `auto_free()` だけで位置・レイヤ・子ノードの型を読む。`add_child()` すると `_ready()` と `_physics_process` が走って初期位置が変わる。unit #2 の申し送り)
      - 9.2 は「`Player` の初期位置から敵までの距離 ≤ 160 + その敵の `detect_range`」を満たす敵の数を数え、2 以下であることで検証する。判定に使う `detect_range` は各敵の `stats` から読む(テストへ直書きしない)。座標は unit #2 と同じ基準解像度 320×180 の中へ収める
      - 9.4 は `[connection]` の宣言であり、`get_signal_connection_list("died")` を `instantiate()` した時点で読めることで示す(`_ready()` で接続すると読めない)
      - 9.5 と 9.6 は「しないこと」の要求である。9.5 は検証コマンドの内容ハッシュ、9.6 はシーンの全ノードを再帰的に走査してスポナーに相当するノード・スクリプト変数が無いことで示す
      - 9.7 は `ProjectSettings.get_setting("application/run/main_scene")` が `res://main.tscn` のままであることで示す(期待値はテスト側に定数として持つ)
      - 9.9 は各敵の `target` が `Player` ノードを指していることを、ツリーへ載せずに読んで検証する
      - 9.11 は File Structure Plan の全ファイルが規約どおりのパスに存在することであり、検証コマンドの存在確認で示す
    - 検証コマンド: `make test TESTS=res://tests/stage`、`test "$(git hash-object src/stage/dev_stage.tscn)" = "8c8d95cdce4d0e0ba78ab942db1c75d27651680e" && echo OK`、`ng=0; for f in src/enemy/enemy_stats.gd src/enemy/enemy_state.gd src/enemy/enemy_kind.gd src/enemy/enemy.gd src/enemy/charger_brain.gd src/enemy/charger_enemy.gd src/enemy/charger_enemy.tscn src/enemy/shooter_brain.gd src/enemy/shooter_enemy.gd src/enemy/shooter_enemy.tscn src/enemy/hurtbox.gd src/enemy/hurtbox.tscn src/enemy/attackbox.gd src/enemy/charger_stats.tres src/enemy/shooter_stats.tres src/weapon/enemy_projectile.gd src/weapon/enemy_projectile.tscn src/stage/enemy_dev_stage.gd src/stage/enemy_dev_stage.tscn; do test -f "$f" || { echo "NG: $f"; ng=1; }; done; test $ng -eq 0 && echo OK`
  - [ ] 6.2 リトライ(`died` からのシーン再読込)を実行時に目視で確認する(自動テストでは検証しない)
    _Requirements: 9.3_
    _Boundary: EnemyDevStage_
    _Depends: 6.1_
    - 対象ファイル: なし(`src/stage/enemy_dev_stage.tscn` の実行時確認)
    - 仕様参照: spec.md §7 Requirement 9.3(自動テストにしない理由を含む)
    - 実装の要点: 敵の攻撃を受け続けてプレイヤーの体力を 0 にし、シーンが読み直されて初期位置と体力が戻ることを確認する。あわせて spec.md §3 の未検証の前提のうち手触りに関わるもの(弾速 120 px/s・突進速度 150 px/s で「見てから移動を始めても間に合う」か、体力 30 / 20 の撃破の粒度)も同じ実行で観察する。**確認できた事実(いつ・どの環境で・何を確認したか)を `## Implementation Notes` に記録する**。`make test` には現れないため、記録しないと確認した事実が残らない
    - 検証コマンド: `godot --path <プロジェクトのルート> res://src/stage/enemy_dev_stage.tscn`(目視。`--headless` では確認できない)
  - [ ] 6.3 `docs/testing.md` に `enemy_dev_stage.tscn` の起動方法を追記する
    _Requirements: 9.8_
    _Boundary: Docs_
    _Depends: 6.2_
    - 対象ファイル: `docs/testing.md`(変更)
    - 仕様参照: spec.md §5.8「`run/main_scene` は変更しない」、§7 Requirement 9.8
    - 実装の要点: 既存の `### 仮ステージを目視で確認する` の節に並べる形で追記し、既存の `dev_stage.tscn` の記述と規約そのものの記述は変えない。2 つの仮ステージの用途の違い(プレイヤー単体の確認 / 敵との戦闘の確認)を 1 行で示す
    - 検証コマンド: `grep -q 'res://src/stage/enemy_dev_stage.tscn' docs/testing.md && grep -q 'res://src/stage/dev_stage.tscn' docs/testing.md && echo OK`
  - [ ] 6.4 数値の直書き・純ロジックの分離・凍結済みの割り当ての 3 点を横断的に検査する
    _Requirements: 1.20, 8.1, 10.5_
    _Boundary: EnemyStats_
    _Depends: 6.3_
    - 対象ファイル: `src/enemy/enemy.gd`(必要に応じて変更), `src/enemy/charger_enemy.gd`(必要に応じて変更), `src/enemy/shooter_enemy.gd`(必要に応じて変更), `src/enemy/charger_brain.gd`(必要に応じて変更), `src/enemy/shooter_brain.gd`(必要に応じて変更), `src/enemy/attackbox.gd`(必要に応じて変更)
    - 仕様参照: spec.md §6.1「既定値の実体」、§8「純ロジックと配線を分ける」、§7 Requirement 8.1・1.20・10.5
    - 実装の要点(タスク固有):
      - 本サブタスクの境界は「数値の集約」という横断的な関心であり、対象は `src/` 配下の実装コード全体に及ぶ。検査対象は `EnemyStats` の既定値のうち**小数のリテラル**とし、整数(30 / 20 / 15 / 10)は無関係な整数と衝突して誤検出が多いため grep から外す(unit #2 と同じ判断。整数は要件 4.7・3.6・6.6 のテストが「値が `stats` 経由で流れること」で担保する)
      - `enemy_stats.gd`・`combat_limits.gd`・`player_stats.gd` は検査から除外する(値の定義そのもの、および unit #2 の集約先)。`.tres` は grep の対象外(`--include='*.gd'`)であり、値の実体として正しい置き場所である
      - 無関係な小数リテラルが偶然一致した場合は、その旨と根拠を `## Implementation Notes` に記録してから除外する(判定を黙って緩めない)
      - 1.20 は `move_and_slide()` が 2 つの `*_brain.gd` に現れないことと、`src/enemy/` 全体で `enemy.gd` の `_physics_process` の 1 箇所だけであることで示す
      - 10.5 は unit #2 が定めたレイヤ 1〜3 の割り当てを変えないことであり、`project.godot` のレイヤ名 5 行と `player.tscn`・`projectile.tscn` の内容ハッシュで示す。最後に全テストを通しで実行し、統計行の `skipped` と `orphans` が 0 であることを確かめる
    - 検証コマンド: `grep -rnE '(^|[^0-9.])(600\.0|40\.0|128\.0|160\.0|0\.4|150\.0|120\.0|0\.6|0\.8|1\.5|216\.0)([^0-9]|$)' --include='*.gd' src > /tmp/enemy_hardcoded.txt; grep -vE '^src/(enemy/enemy_stats|weapon/combat_limits|player/player_stats)\.gd:' /tmp/enemy_hardcoded.txt > /tmp/enemy_hardcoded2.txt; test ! -s /tmp/enemy_hardcoded2.txt && echo OK || cat /tmp/enemy_hardcoded2.txt`、`grep -n 'move_and_slide' src/enemy/*.gd`(`enemy.gd` の 1 箇所だけであること)、`test "$(git hash-object src/player/player.tscn)" = "fe63929182dae747175248c211e7174294959a27" && test "$(git hash-object src/weapon/projectile.tscn)" = "df9e5f40471d007eedd282e7b5d9513444094acd" && echo OK`、`make test > /tmp/alltests.txt 2>&1; rc=$?; grep -E 'skipped|orphans' /tmp/alltests.txt; test $rc -eq 0 && echo OK`

## Implementation Notes

### 知識 port の選択

`docs/dev/ports/` が存在しないため、注入する知識 port は**なし**(`ports.py --skill dev-implement --root docs/dev/ports` の結果)。

### 実装開始時の基準点

- `make test` の基線: 186 test cases / 0 errors / 0 failures / 0 skipped / 0 orphans(実装開始前に実測)。
- 凍結対象の内容ハッシュは実装開始時点で tasks.md の期待値と一致することを確認済み(`combat_limits.gd` / `dev_stage.tscn` / `player.tscn` / `projectile.tscn`)。
- テストの書き方の規約は `docs/testing.md` にある(物理フレームを進めるテスト・仮ステージの目視確認の節)。既存の `tests/` 配下の同種のテストを手本にする。

### 実装中の学習

- **`EnemyStats` のスクリプト側の既定値は突進型の値に揃えた**(タスク 1.1)。`.tres` の 10 項目がすべてスクリプトの既定値と同値になるため、`charger_stats.tres` から行を削除してもテストが緑のまま(レビューの変異 M9 で実測)。読み込み後の値は表どおりで要件 8.5 の観点では実害が無く、スクリプト側の既定値は `test_enemy_stats_script_defaults` が別に固定しているため、そのままにした。**`charger_stats.tres` を編集するときは「行が消えても気付けない」ことを念頭に置くこと。**
- **`assert_object(a).is_same(b)` は 8.2 の担保にならない**(タスク 1.1)。`ResourceLoader.load()` は既定でキャッシュを返すため、どう実装しても真になる。8.2 を実際に守っているのは `resource_local_to_scene` が偽であることのアサーションであり、変異(`.tres` に `resource_local_to_scene = true` を足す)はそちらで落ちる。
- **要件 8.7 のシーン側の検証(埋め込みサブリソースを持たないこと)はタスク 1.1 では行っていない**。対象のシーンが未作成のため、タスク 2.3(`charger_enemy.tscn`)・5.3(`shooter_enemy.tscn`)で足すこと。タスク 1.1 の実装の要点が明示的に繰り延べを許容している。
- **前セッションの中断からの復旧**(タスク 1.1)。成果物はステージ済み・未コミットで、レビューを通していなかった。本セッションで correctness 観点のレビューを実施して `APPROVED`(Critical / Major / Minor なし、変異 20 種中 19 種を検出)を得てからコミットした。破棄してやり直さなかったのは、10 項目 × 2 種の値を spec.md §6.1 の表と 1 行ずつ突き合わせて一致を確認できたためである。
