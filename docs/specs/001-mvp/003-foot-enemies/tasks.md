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

**変更してはならない既存ファイル**(要件 9.5・10.5・7.3・スコープ外)と、それを実際に検査するタスク:

| ファイル | 検査するタスク | 手段 |
| ---- | ---- | ---- |
| `src/weapon/combat_limits.gd` | 1.1 | 内容ハッシュ |
| `src/stage/dev_stage.tscn` | 6.1 | 内容ハッシュ(要件 9.5) |
| `src/player/player.tscn` | 6.4 | 内容ハッシュ |
| `src/weapon/projectile.tscn` | 6.4 | 内容ハッシュ |
| `src/weapon/projectile.gd` | 6.4 | 内容ハッシュ |
| `project.godot` | 6.4 | レイヤ名 3 行の照合(要件 10.5。ファイル全体のハッシュは使わない — 理由はタスク 6.4 の実装の要点) |
| `src/player/` の残り(`player.gd`・`player_stats.gd` 等) | 6.4 | 既存テストの通しの実行が緑のまま(内容ハッシュでは固定しない) |

以前この節は「タスク 6.4 が内容ハッシュで確認する」と一括で述べていたが、6.4 の検証コマンドが実際にハッシュしていたのは `player.tscn` と `projectile.tscn` の 2 つだけで、`projectile.gd` と `project.godot` に対応する検査は存在しなかった。宣言と実体を上の表で一致させた。

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
      - 8.7 のうち本サブタスクで示すのは `.tres` が外部ファイルとして存在すること(`ResourceLoader.exists()`)までとする。**シーン側(埋め込みサブリソースを持たないこと)はタスク 2.3・5.3 が担う**(対象のシーンが本サブタスクの時点で存在しないため)。8.7 は 1.1・2.3・5.3 の 3 タスクに割り当ててあり、本サブタスクの完了は 8.7 の充足を意味しない
      - 8.2 は **`resource_local_to_scene` が偽であること**で示す。`load()` を 2 回行って同一インスタンスであること(`assert_object(a).is_same(b)`)は担保にならない — `ResourceLoader.load()` は既定でキャッシュを返すため、どう実装しても真になる(タスク 1.1 の実装中に実測。`## Implementation Notes` を参照)。実装済みの `enemy_stats_test.gd` は `resource_local_to_scene` のアサーションを持つため**手戻りは不要**であり、この要点の記述だけを実測に合わせて是正した
      - 8.6 は 2 つの `.tres` の値から算出する不等式で示す(射撃型は成立、突進型は弾を持たないため対象外)
      - 7.1・7.2 は `CombatLimits` の定数と 2 種の値を比較する。7.3 は `src/weapon/combat_limits.gd` を変更しないことであり、検証コマンドの内容ハッシュで示す(既存の `tests/weapon/combat_limits_test.gd` が値そのものを固定している)
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`test "$(git hash-object src/weapon/combat_limits.gd)" = "34f2402a38e7a55fcd1f642216fa4a8d658e6d15" && echo OK`

- [ ] 2. 敵の基底とプレイヤーの弾による被弾(リスク先行の垂直スライス)

  spec.md §3 の未検証の前提のうち最も重いもの(`Hurtbox` の `area_entered` による検出と、同じフレームの `Projectile` 自身による解放が両立すること)を、状態遷移より前に確かめる。この前提が崩れると要件 6 と §5.6 の設計が組み替えになる。「プレイヤーが撃つ → 敵の体力が減る → 撃破される」を縦に貫くスライスとして進める。

  - [x] 2.1 `Enemy` の体力・被弾・撃破のシグナルと `kind()` の基底実装を作る
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
  - [x] 2.2 `stats` の未設定と不変条件違反の検査を `_ready()` に置く
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
  - [x] 2.3 `charger_enemy.tscn` の骨格(placeholder・衝突形状・レイヤ)と `Enemy` の物理(重力・接地・`move_and_slide()`)・標的の解決を実装する
    _Requirements: 1.12, 1.14, 1.16, 1.17, 1.18, 1.19, 8.7, 10.1_
    _Boundary: Enemy_
    _Depends: 2.2_
    - 対象ファイル: `src/enemy/enemy.gd`(変更), `src/enemy/charger_enemy.gd`(新規), `src/enemy/charger_enemy.tscn`(新規), `tests/enemy/enemy_test.gd`(変更), `tests/enemy/charger_enemy_test.gd`(新規)
    - 仕様参照: spec.md §5.1「重力に従う」「placeholder と衝突形状」「標的の解決」「標的が不在のフレーム」、§6.4、§7 Requirement 1
    - 実装の要点(タスク固有):
      - この時点の `charger_enemy.gd` は `kind()` と `stats` の割り当てだけを持つ骨格でよい(`brain` はタスク 3.3 で足す。File Structure Plan の申し送りを参照)
      - 1.12 は `instantiate()` + `auto_free()` でシーンを読み、`ColorRect` の `size` と `CollisionShape2D` の `shape.size` がともに 16×16px、原点が矩形の中心にあること(`ColorRect` の `position` が `Vector2(-8, -8)`、`CollisionShape2D` の `position` が `Vector2.ZERO`)で検証する。ノード名は `player.tscn` に倣って `Placeholder` とする
      - 1.17 と 1.18 は分岐の両側である。接地側は `StaticBody2D`(layer 1)の床を置いて立たせる。非接地側は床を置かない
      - 1.14 は 2 つの節から成り、本サブタスクが担うのは**前半節(`push_error` を出さない)だけ**である。`target` を `null` にした場合と、`queue_free()` 済みのノードを指した場合の 2 経路に個別のテストケースを割り当て、`assert_error(...).is_success()` で `push_error` が出ないことを見る。**後半節(標的までの距離を `INF` として扱う)はタスク 3.3 が担う** — この時点の `charger_enemy.gd` は `brain` を持たない骨格であり、距離が `Brain` へ渡る経路がまだ存在しないためである
      - 8.7 のシーン側の節(既定値をシーンへ埋め込むサブリソースにしない)を `charger_enemy.tscn` について示す。`instantiate()` した `ChargerEnemy` の `stats.resource_path` が `res://src/enemy/charger_stats.tres` と厳密一致することでアサーションする(埋め込みサブリソースの `resource_path` は `res://src/enemy/charger_enemy.tscn::Resource_xxxx` の形になり、この比較で落ちる)。あわせて検証コマンドの `grep` で `[sub_resource type="Resource"]` が 0 件であることを見る(`CollisionShape2D` の `RectangleShape2D` は別型のため誤検出しない)。タスク 1.1 の `## Implementation Notes` が繰り延べを明記した部分がこれである
      - 1.16 は `target` が `@export` であること(`get_property_list()` の `PROPERTY_USAGE_EDITOR` ビット)と、代入した値が物理フレームを跨いで保たれること(内部で検索して上書きしないこと)で示す
      - 1.19 は `enemy.gd` の静的な検査で示す(`_physics_process` の中に `move_and_slide()` があり、速度の決定より後ろにあること)
      - 10.1 は `collision_layer` = 8、`collision_mask` = 1 の整数値を直接アサーションする(File Structure Plan の換算を参照)
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`grep -n 'move_and_slide' src/enemy/enemy.gd`(出現が `_physics_process` の中の 1 箇所だけであること)、`test "$(grep -c 'sub_resource type="Resource"' src/enemy/charger_enemy.tscn)" = 0 && echo OK`
  - [x] 2.4 `Hurtbox` を実装して `charger_enemy.tscn` へ組み込み、プレイヤーの弾で被弾・撃破されることを検証する
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
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`test "$(grep -c 'queue_free' src/enemy/hurtbox.gd)" = 0 && echo OK`

- [ ] 3. 突進型(状態遷移 → 移動 → 攻撃判定)

  - [x] 3.1 (P) `ChargerBrain` の状態遷移(正常系)を実装する
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
  - [x] 3.2 `ChargerBrain` の異常系(引数の検査・距離による打ち切りの禁止・標的の不在)を実装する
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
  - [x] 3.3 `ChargerEnemy` に `brain` を持たせ、状態を水平の速度へ写す
    _Requirements: 1.14, 1.15, 1.21, 1.22, 3.1, 3.2, 3.3, 3.4_
    _Boundary: ChargerEnemy_
    _Depends: 2.4, 3.2_
    - 対象ファイル: `src/enemy/charger_enemy.gd`(変更), `tests/enemy/charger_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.2、§5.4「ロジックの所在」、§5.1「標的が不在のフレーム」、§7 Requirement 3.1〜3.4・1.14・1.15・1.21・1.22
    - 実装の要点(タスク固有):
      - 3.1 と 3.2 は `IDLE` における `detect_range` の分岐の両側であり、個別のテストケースを割り当てる。接近の向き(標的が左/右)も両側を見る
      - 3.4 は「突進を始めた時点の向きを保つ」ことである。`CHARGE` の途中で標的を反対側へ動かし、速度の符号が変わらないことで示す
      - 1.15 は `IDLE` で `target` を `null` にした場合であり、`state` が `IDLE` のまま・水平の速度が 0 であることを見る。`TELEGRAPH` 以降で失った場合(2.7・2.11)と混同しない
      - **1.14 の後半節(標的までの距離を `INF` として扱う)を本サブタスクで固定する**(前半節の `push_error` はタスク 2.3 が担う)。`target` を突進の到達距離(`attack_speed * attack_duration` = 90px)の内側に置いて `TELEGRAPH` へ入れ、満了より前に `target` を失わせ、満了フレームで `brain.state` が `RECOVER`(`CHARGE` ではない)になることを見る。**`null` にする経路と `queue_free()` 済みにする経路の 2 つに個別のテストケースを割り当てる**
      - この形を取る理由は、`INF` を巨大な有限値(例 `1e9`)へ置き換える実装を落とすためである。有限値だと 2.4 の分岐(距離が有限 → `CHARGE`)へ進み、`RECOVER` のアサーションが落ちる。タスク 2.3 の「`push_error` が出ない」だけでは有限値の実装が素通りする。射撃型では同じ変異を捕らえられない(4.11 により `TELEGRAPH` は距離によらず完走し、`COOLDOWN` へ移る点が `INF` でも有限値でも変わらないため)。突進型のこのケースが `INF` を要求する唯一の観測点である
      - 解放済みの経路は、`queue_free()` の反映を待ってから(`is_instance_valid()` が偽になったことを確認してから)満了させる。待たずに進めると `null` 経路と区別がつかない
      - 1.21 は `target` に位置を制御できるスタブ(`Node2D`)を注入し、規定のフレーム数を過ぎたら索敵範囲の外へ動かして移動を打ち切る形で検証する(spec.md §7 Requirement 1 の「検証の形式」)。期待値は `速度 / Engine.physics_ticks_per_second * フレーム数` で算出し、実数を直書きしない。消化フレーム数も併せてアサーションする
      - **1.21 の初期配置は突進の到達距離(90px)より外・`detect_range`(128px)より内に取る**。到達距離の内側に置くと `IDLE` から即座に `TELEGRAPH` へ入って水平の速度が 0 になり(3.3)、移動そのものが起きない。索敵範囲の外に置くと 3.2 で停止する。`IDLE` のまま水平に動く状態はこの帯だけである
      - 注入するスタブはスイートのメンバに抱える(`Callable` / ノードの参照が切れて毎フレーム null 参照のエラーが出る事故を避ける。unit #2 の申し送り)
      - 1.22 は `brain` が外から読める公開点であることの検証であり、射撃型でも同じ形で見る(タスク 5.3)
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [x] 3.4 `Attackbox` を実装し、突進中だけ 1 回だけダメージを与える
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
  - [x] 3.5 撃破された後に `Attackbox` の `monitoring` を偽に保つ
    _Requirements: 3.10_
    _Boundary: ChargerEnemy_
    _Depends: 3.4_
    - 対象ファイル: `src/enemy/attackbox.gd`(変更), `src/enemy/charger_enemy.gd`(変更), `tests/enemy/charger_enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.2「`is_defeated` が真になった後は…優先する」、§5.9、§7 Requirement 3.10
    - 実装の要点: 3.5 と 3.10 は優先順位が逆転する分岐であり、**`is_attack_active` が真のまま撃破される**状況(`CHARGE` の最中に `take_damage()` で `hp` を 0 にする)を作って、同じ物理フレームのうちに `monitoring` が偽になることを見る。解放(`queue_free()`)の反映を待つ前に読む必要があるため、`is_instance_valid()` の確認と併せて組む
    - 検証コマンド: `make test TESTS=res://tests/enemy`

- [ ] 4. (P) 敵弾

  `EnemyProjectile` は `EnemyStats` にも `Enemy` にも依存せず(値はすべて `launch()` の引数で受け取る)、タスク 1 の完了を待たずに始められる。

  - [x] 4.1 `EnemyProjectile` と `enemy_projectile.tscn` を作り、`launch()` 後の直進・射程・衝突レイヤを検証する
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
  - [x] 4.2 地形とプレイヤーへの衝突を実装する
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
  - [x] 4.3 `launch()` の異常系を実装する
    _Requirements: 5.5, 5.6_
    _Boundary: EnemyProjectile_
    _Depends: 4.2_
    - 対象ファイル: `src/weapon/enemy_projectile.gd`(変更), `tests/weapon/enemy_projectile_test.gd`(変更)
    - 仕様参照: spec.md §5.7「事前条件」「不変条件」、§7 Requirement 5.5・5.6
    - 実装の要点(タスク固有): 4 つの異常な引数それぞれに個別のテストケースを割り当て、`push_error`・弾が進まないこと・**`damage` が変わらないこと**の 3 つを見る(ガードを代入の後ろへ移す変異を捕らえる。unit #2 の申し送り)。異常値の表に負値と 0 の両方を入れる。5.5 は正常系でも見る(`launch()` の後に `damage` を書き換える経路が無いこと)
    - 検証コマンド: `make test TESTS=res://tests/weapon`

- [ ] 5. 射撃型(状態遷移 → 発射)

  - [x] 5.1 (P) `ShooterBrain` の状態遷移を実装する
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
  - [x] 5.2 `ShooterBrain` の引数の異常系を実装する
    _Requirements: 4.10_
    _Boundary: ShooterBrain_
    _Depends: 5.1_
    - 対象ファイル: `src/enemy/shooter_brain.gd`(変更), `tests/enemy/shooter_brain_test.gd`(変更)
    - 仕様参照: spec.md §5.5「事前条件・事後条件・不変条件」、§7 Requirement 4.10
    - 実装の要点: ガードは関数の先頭に置く。`delta` と `distance_to_target` それぞれに個別のテストケースを割り当て、`push_error`・戻り値が偽であること・`state` が変わらないことを見る。`INF` は正常な入力であり弾かない(4.13 の経路)
    - 検証コマンド: `make test TESTS=res://tests/enemy`
  - [x] 5.3 `ShooterEnemy` と `shooter_enemy.tscn` を作り、敵弾の生成と発射を実装する
    _Requirements: 1.11, 1.22, 4.7, 4.8, 4.14, 8.7, 9.10_
    _Boundary: ShooterEnemy_
    _Depends: 2.4, 4.3, 5.2_
    - 対象ファイル: `src/enemy/shooter_enemy.gd`(新規), `src/enemy/shooter_enemy.tscn`(新規), `tests/enemy/shooter_enemy_test.gd`(新規), `tests/enemy/enemy_test.gd`(変更)
    - 仕様参照: spec.md §5.3、§6.1「既定値の実体」、§7 Requirement 4.7・4.8・4.14・1.11・1.22・8.7・9.10
    - 実装の要点(タスク固有):
      - `shooter_enemy.tscn` は `charger_enemy.tscn` と同じ placeholder・衝突形状・`Hurtbox` を持ち、`Attackbox` は持たない。`stats` に `shooter_stats.tres`、`projectile_scene` に `enemy_projectile.tscn` を設定する(9.10)
      - 4.7 は生成先の子ノード数の増分と、生成された `EnemyProjectile` に渡った向き・速さ・ダメージ・射程の 4 つで検証する。値は `stats` から読み、実装へ直書きしない。向きは標的への単位ベクトルであり、**斜めの配置**のケースを含める
      - 4.14 は「親へ追加し、位置を決めてから `launch()` を呼ぶ」順序の要求である。敵自身を親のあるノードの下に置き、生成された弾の親と `launch()` 時点の位置(射程の基準)の両方を見る
      - 4.8 は射撃型が水平に動かないことであり、標的を索敵範囲の内外に置いた両方で位置の x が変わらないことを見る
      - 1.11 は 2 種の `kind()` を並べて検証する(突進型は既に存在する)。1.22 は `brain` の公開点であり、突進型(タスク 3.3)と同じ形で見る
      - 8.7 のシーン側の節を `shooter_enemy.tscn` について示す(タスク 2.3 が `charger_enemy.tscn` に対して行うのと同じ形)。`instantiate()` した `ShooterEnemy` の `stats.resource_path` が `res://src/enemy/shooter_stats.tres` と厳密一致することでアサーションし、検証コマンドの `grep` で `[sub_resource type="Resource"]` が 0 件であることを見る。これで 8.7 は 1.1(`.tres` の実在)・2.3・5.3(2 つのシーンの非埋め込み)で閉じる
    - 検証コマンド: `make test TESTS=res://tests/enemy`、`test "$(grep -c 'sub_resource type="Resource"' src/enemy/shooter_enemy.tscn)" = 0 && echo OK`
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
      - 9.11 は spec.md §6.5 の**実装の配置**と `docs/testing.md` の**テストの配置**の両方を求める。検証コマンドの存在確認に `src/` 配下 19 ファイルだけでなく **`tests/` 配下 9 ファイル**(`tests/enemy/` 7 本・`tests/weapon/` 1 本・`tests/stage/` 1 本)も並べる。実装の側だけを見ると「テストの配置規約に従う」半分が未検査のまま通る
    - 検証コマンド: `make test TESTS=res://tests/stage`、`test "$(git hash-object src/stage/dev_stage.tscn)" = "8c8d95cdce4d0e0ba78ab942db1c75d27651680e" && echo OK`、`ng=0; for f in src/enemy/enemy_stats.gd src/enemy/enemy_state.gd src/enemy/enemy_kind.gd src/enemy/enemy.gd src/enemy/charger_brain.gd src/enemy/charger_enemy.gd src/enemy/charger_enemy.tscn src/enemy/shooter_brain.gd src/enemy/shooter_enemy.gd src/enemy/shooter_enemy.tscn src/enemy/hurtbox.gd src/enemy/hurtbox.tscn src/enemy/attackbox.gd src/enemy/charger_stats.tres src/enemy/shooter_stats.tres src/weapon/enemy_projectile.gd src/weapon/enemy_projectile.tscn src/stage/enemy_dev_stage.gd src/stage/enemy_dev_stage.tscn tests/enemy/enemy_stats_test.gd tests/enemy/enemy_test.gd tests/enemy/hurtbox_test.gd tests/enemy/charger_brain_test.gd tests/enemy/charger_enemy_test.gd tests/enemy/shooter_brain_test.gd tests/enemy/shooter_enemy_test.gd tests/weapon/enemy_projectile_test.gd tests/stage/enemy_dev_stage_test.gd; do test -f "$f" || { echo "NG: $f"; ng=1; }; done; test $ng -eq 0 && echo OK`
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
      - **検査する値を tasks.md へ列挙しない**。検証コマンドは 2 つの `.tres`(spec.md §6.1 が「既定値の実体」と定める置き場所)から小数の値を抽出して grep のパターンを組み立てる。値を tasks.md に複製すると、spec.md §6.1 と `.tres` の値が改訂されたとき検査だけが古い値を見続け、**新しい値の直書きを素通りさせる**方向に壊れる(検査が緑のまま無力化するため、壊れたことに気付けない)。抽出が 0 件になった場合は `NG` を出して落とす(パターンが空になると grep が全行に一致し、逆に常時 `NG` になるため)
      - `0.0` を抽出から外すのは、それが「その振る舞いを持たない」ことを表す標識であり(spec.md §6.1 の不変条件)、手触りの数値ではないためである。`0.0` は初期化・ゼロ比較として実装コードのあらゆる箇所に現れ、誤検出が検査の意味を失わせる。整数を外すのと同じ理由による
      - `enemy_stats.gd`・`combat_limits.gd`・`player_stats.gd` は検査から除外する(値の定義そのもの、および unit #2 の集約先)。`.tres` は grep の対象外(`--include='*.gd'`)であり、値の実体として正しい置き場所である
      - 無関係な小数リテラルが偶然一致した場合は、その旨と根拠を `## Implementation Notes` に記録してから除外する(判定を黙って緩めない)
      - 1.20 は `move_and_slide()` が 2 つの `*_brain.gd` に現れないことと、`src/enemy/` 全体で `enemy.gd` の `_physics_process` の 1 箇所だけであることで示す
      - **10.5 は `project.godot` のレイヤ名を直接照合する**。要件が凍結するのはレイヤ 1〜3 の割り当てであり、`2d_physics/layer_1="terrain"`・`layer_2="player"`・`layer_3="player_projectile"` の 3 行が原文のまま実在することを検証コマンドで示す(レイヤ 4・5 は本単位が使う行であり 10.5 の対象外)。**期待値はこのタスクが持ち、`project.godot` から読み直さない**(読み直すと変更後の値と比較して常に一致する)。ファイル全体の内容ハッシュを使わないのは、Godot が無関係な設定行を書き戻したときに 10.5 と無関係な失敗を出すためである
      - あわせて `player.tscn`・`projectile.tscn`・`projectile.gd` の内容ハッシュを照合する(File Structure Plan の「変更してはならない既存ファイル」のうち、他のタスクが照合していないもの)。最後に全テストを通しで実行し、統計行の `skipped` と `orphans` が 0 であることを確かめる
    - 検証コマンド:
      - 数値の直書き(8.1。パターンを `.tres` から導出する): `vals=$(grep -hoE '^[a-z_]+ = [0-9]+\.[0-9]+$' src/enemy/charger_stats.tres src/enemy/shooter_stats.tres | grep -oE '[0-9]+\.[0-9]+$' | grep -vx '0.0' | sort -u); if [ -z "$vals" ]; then echo "NG: .tres から小数の既定値を抽出できない"; else pat=$(printf '%s\n' "$vals" | sed 's/\./\\./g' | paste -sd '|' -); grep -rnE "(^|[^0-9.])($pat)([^0-9]|$)" --include='*.gd' src | grep -vE '^src/(enemy/enemy_stats|weapon/combat_limits|player/player_stats)\.gd:' > /tmp/enemy_hardcoded.txt; test ! -s /tmp/enemy_hardcoded.txt && echo OK || cat /tmp/enemy_hardcoded.txt; fi`
      - 純ロジックの分離(1.20): `grep -n 'move_and_slide' src/enemy/*.gd`(`enemy.gd` の 1 箇所だけであること)
      - レイヤ 1〜3 の割り当て(10.5): `grep -qx '2d_physics/layer_1="terrain"' project.godot && grep -qx '2d_physics/layer_2="player"' project.godot && grep -qx '2d_physics/layer_3="player_projectile"' project.godot && echo OK`
      - 凍結済みファイルの内容ハッシュ(10.5・9.5 の周辺): `test "$(git hash-object src/player/player.tscn)" = "fe63929182dae747175248c211e7174294959a27" && test "$(git hash-object src/weapon/projectile.tscn)" = "df9e5f40471d007eedd282e7b5d9513444094acd" && test "$(git hash-object src/weapon/projectile.gd)" = "30bee3344b85b08e26187e5ca028f0a71972da0a" && echo OK`
      - `.tres` の行の欠落(上のパターン導出が縮退していないこと): `n=$(grep -cE '^@export var ' src/enemy/enemy_stats.gd); ng=0; for t in charger_stats shooter_stats; do m=$(grep -cE '^[a-z_]+ = [0-9-]' src/enemy/$t.tres); test "$m" = "$n" || { echo "NG: $t.tres の値 $m 行が enemy_stats.gd の項目 $n 個と一致しない"; ng=1; }; done; test $ng -eq 0 && echo OK`
      - 通しの実行(`skipped` と `orphans` が 0 であることまで機械判定する): `make test > /tmp/alltests.txt 2>&1; rc=$?; s=$(grep -oE '[0-9]+ skipped' /tmp/alltests.txt | tail -1 | grep -oE '^[0-9]+'); o=$(grep -oE '[0-9]+ orphans' /tmp/alltests.txt | tail -1 | grep -oE '^[0-9]+'); echo "rc=$rc skipped=$s orphans=$o"; test "$rc" -eq 0 && test "$s" = 0 && test "$o" = 0 && echo OK`

## Implementation Notes

### 実装中の学習(タスク 2.3 以降)

- **接地中の `velocity.y = 0` は「フレームの終わりの値」では固定できない**(タスク 2.3)。`move_and_slide()` が床との衝突で垂直の速度を自分で 0 へ戻すため、`_update_velocity()` から接地の分岐を消して重力を足し続ける変異が、`await` の後に `velocity.y == 0.0` を見るテストを素通りする。**速度の決定(`_update_velocity(DELTA)`)だけを同期で呼んで観測する**形にして検出できるようになった。**「移動の直前に決めた速度」を検証する後続の場面(3.3 の水平速度、4.1)で同じ落とし穴に当たること。**
- **`_update_velocity(delta)` を派生の拡張点として基底に置いた**(タスク 2.3)。`ChargerEnemy`(タスク 3.3)は `super._update_velocity(delta)` を呼んでから水平の速度を足す。`move_and_slide()` は基底の `_physics_process` だけが持ち、派生には持たせない(要件 1.20 の担保に効く)。
- **シーンが指す `.tres` は全個体で共有される**(タスク 2.3)。物理を検証するテストで `enemy.stats.gravity` を直接書き換えると他のテストへ波及するため、`EnemyStats.new()` を作って `stats` ごと差し替える(`tests/enemy/enemy_test.gd` の `_create_embodied_enemy()`)。**`.tres` 由来の数値を変えるテストは後続でも同じ形を採ること。**
- **Godot 4.7 では解放済みオブジェクトの参照は `== null` が真を返す**(タスク 2.3 で実測)。`is_instance_valid(target)` を `target == null` へ弱める変異は等価であり、テストでは区別できない。ガードそのものを削除する変異は検出される。
- **`push_error` を出さないことの検証は、実際に標的を扱う関数を包む**(タスク 2.3)。`_physics_process()` を包むだけでは、標的の扱いが `target_distance()` にあるうちは `target_distance()` へ `push_error` を足す変異が素通りする(レビューが実測)。戻り値は `Array` へ控えて `assert_error(...).is_success()` の外から読む(lambda はローカル変数を値コピーで捕捉するため)。
- **実装のソースを読む静的な検査は、関数の本体だけを取り出す**(タスク 2.3)。「次の `func ` 行まで」を本体と見なすと、次の関数へ付けた列 0 のコメントまで混ざり、コメントの語がアサーションを揺らす(順序の変異が素通りしうる)。`\t` で始まる行だけを拾う形に是正した。

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
- **`is_instance_valid()` だけでは「解放より先に発火する」順序を固定できない**(タスク 2.1)。`queue_free()` は実際の解放をフレーム末尾へ遅らせるため、シグナルの受け手の中で読む `is_instance_valid()` は `queue_free()` 済みでも真を返す。1 回目のレビューで、`queue_free()` を `defeated.emit()` の前へ移す変異が全テスト緑のまま素通りすることが実測された。**順序を固定するのは `is_queued_for_deletion()` が偽であることのアサーション**であり、これを観測配列へ足して解消した。タスク 2.1 の実装の要点は「`is_instance_valid()` と `is_defeated` を読むことで順序を固定する」と書いているが、実測ではその 2 つだけでは固定できない。**後続タスク(3.5 の撃破直後の `monitoring`、6.1 等)で同種の順序を見るときは `is_queued_for_deletion()` を併せて観測すること。**
- **解放の反映を待つテストは `await await_idle_frame()` で足りる**(タスク 2.1)。`await await_millis(100)` から置き換え、`queue_free()` を削除する変異で落ちること(弱体化でないこと)をレビューが実測で確認した。`docs/testing.md` の「物理フレームを進めるテスト」が `await_millis()` を規定しているのは `move_and_slide()` の変位を安定させる文脈であり、解放キューの反映待ちには当たらない。物理フレームを進める 2.3・3.3・4.1 のテストでは従来どおり `await_millis()` + 消化フレーム数のアサーションが要る。
- **前セッションの中断からの復旧**(タスク 2.1)。成果物 4 ファイルはステージ済み・未コミットで、レビューを通していなかった。本セッションでレビューへ通したところ 1 回目が上記の `[Critical]` 1 件で `REJECTED`、テスト 1 行の追加で再レビューが `APPROVED`(変異 11 種すべてを検出)。**実装 `src/enemy/enemy.gd` は 1 バイトも変えずに活かした** — 9 要件すべてを満たしていると 2 回のレビューが判定し、不足はテスト側の 1 点だけだったためである。
- **人間が確定済みの判断: 0 を許す項目は `move_speed`・`attack_duration`・`bullet_max_distance` の 3 項目とし、`recover_time` に 0.0 を入れたときは `push_error` を出す**(タスク 2.2)。spec.md §6.1 の不変条件は 0 を許す項目として `move_speed`・`attack_duration`・`bullet_max_distance`・`recover_time` の **4 項目**を挙げており、受け入れ基準 8.3 / 8.4 が挙げる **3 項目**と食い違う。**受け入れ基準の側(3 項目)を正とし、§6.1 の 4 項目目の `recover_time` を誤りと見なす**。根拠は 4 つ。(a) 8.3 / 8.4 が受け入れ基準であり、検証の対象として一次の記述である。(b) `.tres` の `recover_time` は突進型 0.8・射撃型 1.5 で、どちらの解釈でも既定値の挙動は変わらない(この判断は出荷される値の振る舞いを変えない)。(c) `recover_time` = 0 は「硬直を持たない」ではなく攻撃の周期が縮退することを意味し、0 を「その振る舞いを持たない」と読む §6.1 の枠に収まらない。(d) **要件 8.6 は「射撃型の弾の寿命(`bullet_max_distance / attack_speed`)を発射の周期(`telegraph_time + recover_time`)より短くする」を常時の要件としている。`recover_time` = 0 を許すと周期が `telegraph_time` の 0.4 秒だけになり、既定値の弾の寿命 1.8 秒がこれを上回って 8.6 が破れる。** spec.md は改訂しない(人間の判断)。**最終検証パネルへ申し送る。** 実装の `ZERO_ALLOWED_STAT_NAMES` は 3 項目であり、この判断のとおりで手戻りは無い。テスト側の `POSITIVE_STAT_NAMES` に `recover_time` が漏れていたため追加した(変異「`ZERO_ALLOWED_STAT_NAMES` へ `recover_time` を足す」が素通りしていた)。
- **8.4 の「項目名を固定で列挙しない」は、実装が名前で持ちようのない項目でしか示せない**(タスク 2.2)。10 項目すべてを個別に検証しても、実装が同じ 10 項目を固定で並べていれば全ケースが緑になる。テストは `EnemyStats` を継承する内部クラス(`@export var unknown_stat`)を作って `stats` へ入れ、その項目にも `push_error` が出ることで導出を示す。Godot 4 の内部クラスでも `@export` は `PROPERTY_USAGE_EDITOR` を立てるため、この形が成立することを実測した。変異(`get_property_list()` の結果を既知の 10 項目で `filter()` する)がこのケースだけで落ちることも実測した。**同種の「固定の列挙でないこと」を示す場面(タスク 6.4 の横断的な検査)で同じ形を使えること。** 同じ内部クラスに `@export` を付けない `var internal_stat` を足し、その項目に `push_error` が出ないこと(`is_success()`)も併せて固定した(`PROPERTY_USAGE_EDITOR` のビット検査を外す変異はこのケースだけで落ちる)。
- **`assert_error(...).is_push_error(...)` は「その文言が出たこと」しか見ない**(タスク 2.2)。余分な `push_error` も、複数の違反のうち後ろのものを報告しないことも、この 1 本では捕らえられない。`is_push_error()` を 2 回続けて呼ぶこともできない(呼ぶたびに `Callable` を再実行するため、`add_child()` を 2 度呼ぶことになる)。**過剰報告は `is_success()` を使うケースで、報告の打ち切りは「宣言の順で後ろにある項目を壊して、その項目の文言を見る」形で捕らえる。** タスク 2.2 では `detect_range`(前)と `recover_time`(後ろ)を同時に 0.0 にして後者の文言をアサーションした。後続タスクで複数の `push_error` を出す実装を検証するときも同じ形を採ること。
- **`hp` の初期化は `stats` の setter に置いてある**(タスク 2.1)。`_ready()` ではないため、ツリーへ載せずに `take_damage()` を呼ぶ経路でも体力が満ちる。タスク 2.2 の 1.8(`stats` 未設定 → `EnemyStats.new()` へフォールバック)は `stats` へ代入するだけで `hp` も満たされる。**この setter を外して `_ready()` で満たす形へ変えると 1.8 の順序が問題になる。**
- **spec.md §3 の未検証の前提が解消した**(タスク 2.4)。`Hurtbox` の `area_entered` による被弾の検出と、同じ接触で `Projectile` 自身が `body_entered` により解放されることは**両立する**。`tests/enemy/hurtbox_test.gd` の `test_a_player_projectile_reduces_the_hp_and_is_released_by_itself` が実弾を飛ばして、敵の `hp` が減ることと弾が解放されることの両方を 1 つのテストで実測した。この単位で最も重い賭け(崩れると要件 6 と §5.6 の設計が組み替えになる)は成立側で確定であり、**タスク 2.4 の「両立しない場合は停止して上流の判断を仰ぐ」経路には入らなかった**。
- **人間が確定済みの判断に準じた解釈: 受け入れ基準 6.2 と 6.5 が重なる状態では 6.2 を優先し、`push_error` を出さない**(タスク 2.4。条件付き承認の範囲で処理し、最終検証パネルへ申し送る)。6.2 は「`Hurtbox` に入った領域が `damage` プロパティを持たない場合、何もしてはならない」、6.5 は「親が `take_damage` を持たない状態で領域が入った場合、`push_error` を出し、何もしてはならない」と述べる。**両方が成立する状態(`damage` を持たない領域が入り、かつ親が `take_damage` を持たない)で、`push_error` の要否について逆のことを述べる**。実装は `damage` の検査を外側に置き、この状態では黙って返る。根拠は 4 つ。(a) §5.6 の本文が「相手が `damage` プロパティを持つ**ときだけ**、所有者の `take_damage(...)` を呼ぶ」と書き、`damage` の検査を外側の条件として置いている。親の検査は同じ節が「**事前条件**」と呼ぶものであり、事前条件は呼び出しを試みるときに評価される — 呼び出しを試みない経路で事前条件違反を報告するのは、事前条件という概念の適用範囲の外である。(b) 6.5 の条件「領域が入った場合」は `damage` の有無に触れておらず、6.2 の「入った領域が `damage` を持たない場合」の方が特定的である。特定的な規定が一般的な規定に優先する。(c) 6.2 の「何もしてはならない」を厳密に読めば `push_error` も「何か」に当たり、6.2 の側は自己完結して読める。(d) 6.5 の趣旨は配線の誤り(親が受け手でない)を開発者に知らせることであり、その誤りは `damage` を持つ領域が入った時点で必ず露見する — 6.2 側で黙っても検出可能性は失われない。**既定値の挙動は変わらない**: 出荷される `charger_enemy.tscn`・`shooter_enemy.tscn` では `Hurtbox` の親が必ず `take_damage` を持つ `Enemy` であり、この重なりは配線を誤った木でしか作れない。`test_hurtbox_pushes_no_error_for_an_area_without_a_damage_property` がこの選択を固定している。**射撃型で `Hurtbox` を共有するタスク 5.3 でも同じ解釈を採ること。**
- **`queue_free` の静的な検査は単独では要件 6.3 を担保しない**(タスク 2.4。レビューが変異で実測)。`area.queue_free()` を `area.queue_free.call_deferred()` へ書き換える変異は、ソースの文字列を見る検査(`assert_str(source).not_contains("free(")` とタスクの検証コマンドの `grep -c 'queue_free'`)を素通りする。落とすのは振る舞い側のテスト(`Hurtbox` にダミーの領域を入れ、そのダミーが解放されないことを見る `test_hurtbox_does_not_release_the_area_that_entered_it`)だけである。**「しないこと」を静的な検査だけで示さない。振る舞い側のテストと対にすること**(タスク 6.4 の横断的な検査、9.5・9.6 の「しないこと」の要求でも同じ)。
- **`Brain` の滞在時間の判定は「判定 → 加算」の順に置いた**(タスク 3.1。既存の `Health.tick()` と同形)。結果として次の 2 つの性質が出る。**`ShooterBrain`(タスク 5.1)も同じ形で組み、`ChargerEnemy`(3.3)・`ShooterEnemy`(5.3)の期待フレーム数もこの性質で算出すること。**
  - ある状態は「累積が満了に達した**次の**フレーム」で遷移する(要件 2.9 / 4.12 の「遷移したフレームの `delta` を遷移先へ数えない」がこれで成立する)。
  - **遷移が起きたフレームの `delta` は遷移元にも遷移先にも数えられず捨てられる**。各状態の実滞在は `ceil(duration / delta) + 1` フレームになり、既定値・60fps では予備動作が 0.4 秒ではなく約 0.4167 秒になる。spec.md §5.4 の事後条件が禁じるのは「同じ `delta` を 2 つの状態へ数える」ことだけであり、この形は禁止に触れない。予備動作が `telegraph_time` より**短くなる方向へはずれない**ため、要件 7(`CombatLimits.ENEMY_TELEGRAPH_MIN_TIME`)に対しても安全側である。
- **到達距離は `attack_speed * attack_duration` の積であり、長短の比較テストは両方の因子について要る**(タスク 3.1)。片方だけだと「もう一方だけを見る実装」が素通りする。**同じ形の積・商が条件に現れる場面(要件 8.6 の弾の寿命、タスク 3.3 の移動距離)で同じ注意が要る。**
- **`_init()` に渡す `EnemyStats` は既定値と離した値にする**(タスク 3.1)。索敵範囲 16.0 に対して到達距離 4.0 と離してあるため、条件を `detect_range` へ差し替える変異が中間の距離 6.0 の行で落ちる。**両方の値を跨ぐ距離を必ずテストに含めること**(タスク 5.1 の 4.2 も同じ)。
- **異常系の文言のアサーションは、テスト側にリテラルの複製を持つ**(タスク 3.2。レビューが実測)。テストが実装の定数(`ChargerBrain.INVALID_DELTA_ERROR_FORMAT` 等)を参照して期待値を組み立てると**アサーションが自己成就し、実装側の文言を無意味な文字列へ差し替える変異が全テスト緑のまま素通りする**(1 文字だけ変える変異も同様)。テスト側へ複製すれば期待値の表は `const` にでき、`const` 配列の中の `FORMAT % 値` の畳み込みも Godot 4.7 で通る。既存の `tests/enemy/enemy_test.gd`・`hurtbox_test.gd`・`tests/weapon/projectile_test.gd`・`tests/player/player_move_test.gd` はすべてこの形である。**タスク 5.2 の `ShooterBrain` は「同じ形で組む」と指示されているため、是正後の `charger_brain_test.gd` を手本にすること。**
- **`INF` の判定は「巨大な有限値のしきい値」へ置き換えられる**(タスク 3.2)。`is_finite()` で書くだけでは足りず、`distance_to_target < 1e9` への変異が素通りする。**有限だが桁の大きい距離(`1.0e30`)で満了させて `CHARGE` になること**を見て初めて落ちる。同じ観測点をタスク 3.3(要件 1.14 の後半節)でも `ChargerEnemy` 側に置くこと。なお `ShooterBrain` は満了時に距離で分岐しないため 5.2 には要らない。
- **満了時の分岐は `is_finite()` で書き、`is_inf()` の否定にしない**(タスク 3.2)。仕様の範囲では等価変異(差が出るのは NAN のときだけで spec.md は NAN を定めていない)だが、有限でも `INF` でもない値を突進側へ流さない。事前条件の検査に NAN の判定は入れていない — 受け入れ基準 2.10 の条件は「`delta` が 0 以下、または距離が負」であり `NAN` はどちらにも当たらない(`NAN <= 0.0` も `NAN < 0.0` も偽)。**要求の外へ広げるとテストで固定できないガードが残るため、意図的に足していない。**
- **複数行の lambda を `assert_error(...)` の引数へ直接書けない**(タスク 3.2。Godot 4.7 で実測)。閉じ括弧の字下げが戻せず「Unindent doesn't match」のパースエラーになる。`var f: Callable = func() -> void:` で変数へ置いてから渡すこと。
- **前セッションの中断からの復旧**(タスク 3.3)。成果物 2 ファイルはステージ済み・未コミットで、レビューを通していなかった(前セッションは変異注入の途中でハーネスに打ち切られ、判定が出ていない)。本セッションで correctness 観点のレビューを最初からやり直し、`APPROVED`(Critical / Major / Minor なし、変異 9 種すべてを検出)を得てからコミットした。**破棄してやり直さず活かした**のは、実装・テストのいずれもタスク 3.3 の「実装の要点」の各項(`INF` の観測点・向きの保持・1.21 の期待値の算出・スタブのメンバ保持)に 1 項ずつ対応がついており、`make test TESTS=res://tests/enemy` が緑だったためである。
- **「速度を 0 にする」ことの検証は、非ゼロの速度を作ってから条件を外す**(タスク 3.3。レビューが変異で実測)。生成直後の敵は `velocity.x` が 0 であるため、「索敵範囲の外なら停止する」ケース(3.2)を新品の敵に 1 フレームだけ与える形では、`velocity.x = 0.0` の代入そのものを `pass` へ落とす変異が素通りする。落とすのは接近で速度を持たせてから標的を失わせるケース(1.15)と、打ち切りの後も動き続けることが変位に出る 1.21 のケースである。**「停止する」ことを見る後続の場面(3.5 の撃破後、4.8 の射撃型の水平速度)でも、直前に非ゼロの速度を作ってから観測すること。**
- **`_update_velocity()` を同期で駆動するテストは `set_physics_process(false)` と対にする**(タスク 3.3)。自動の物理フレームを止めないと、同期で進めたフレーム数と `Brain` の滞在時間の対応が崩れ、`TELEGRAPH` の満了フレームがテストの意図とずれる。`tests/enemy/charger_enemy_test.gd` の `_create_driven_charger()` がこの形である。あわせて「指定の状態へ入るまで」ではなく **「指定の状態から出るまで」進める**ヘルパ(`_advance_out_of_state()`)を使うこと — 「入るまで」だと遷移先を取り違える実装が別の状態を経由して同じ状態へ達し、素通りする。無限ループ避けの上限(`MAX_DRIVEN_FRAMES`)を必ず持たせる。
- **基底の `_update_velocity()` を上書きする派生は、`super` の呼び忘れを基底のテストが検出する**(タスク 3.3 でレビューが実測)。`tests/enemy/enemy_test.gd` の重力・接地のテストは器として `charger_enemy.tscn` を使うため、`ChargerEnemy._update_velocity()` から `super._update_velocity(delta)` を消す変異が 3 件落ちる。**`ShooterEnemy`(タスク 5.3)も同じ拡張点を使い、同じ検出経路に乗せること**(器を `shooter_enemy.tscn` に取り替えたテストを別途足すのではなく、基底の物理は 1 つのシーンで担保されている点を意識する)。
- **標的のスタブで移動を打ち切るテストは、スタブを敵より後にツリーへ載せる**(タスク 3.3)。物理フレームは木の順に走るため、先に載せると敵が距離を読む前にスタブが退き、打ち切りが 1 フレーム早まって期待変位(`速度 / physics_ticks_per_second * フレーム数`)と合わなくなる。`tests/enemy/charger_enemy_test.gd` の `test_the_charger_covers_the_ground_its_move_speed_defines` がこの順で組んである。**同じ形を使うタスク 5.3 の 4.8(射撃型が水平に動かないこと)でも順序に注意すること。**
- **`IDLE` のまま水平に動く帯は「到達距離より外・索敵範囲より内」だけである**(タスク 3.3)。テスト用の `EnemyStats` は `attack_speed * attack_duration`(到達距離)と `detect_range` を必ず別の値に取り、その中央へ標的を置く。2 つが同値だと、遷移の条件(到達距離)と移動の条件(索敵範囲)を取り違える実装が素通りする。
- **標的と敵の x が厳密に一致するフレームでは突進の向きが 0 に縮退する**(タスク 3.3。レビューが観点外の FYI として指摘)。`ChargerEnemy._target_direction()` は `signf()` で側を求めるため、その回の突進が水平に動かない。spec.md は「標的の側」が定まらない場合の振る舞いを定めておらず、受け入れ基準 3.4 の範囲外であるため是正していない。**タスク 6.2 の目視確認で違和感が出た場合は上流(spec.md §5.2)へ差し戻す候補**として残す。
- **`Attackbox` の有効・無効は `_update_velocity()` へ混ぜず、`ChargerEnemy._physics_process()` の上書きから `_sync_attackbox()` を呼ぶ形にした**(タスク 3.4)。基底の `_update_velocity()` は「移動のために速度を決める」拡張点であり(`enemy.gd` のコメント)、攻撃判定の切り替えを混ぜると 3.1〜3.4 のケースが副作用を持つ。同期で駆動するテストは `_step()`(`_update_velocity(DELTA)` + `_sync_attackbox()`)で 1 フレームを再現する。
- **`monitoring` の切り替えは「配線の有無」しか落とせない**(タスク 3.4。レビューが変異で実測)。`ChargerEnemy._physics_process()` から `_sync_attackbox()` の呼び出しを消す変異を落とすのは実フレームの統合テスト `test_the_charge_damages_a_player_body_it_runs_into` ただ 1 本である(他の 128 ケースは全緑のまま素通りする)。同期で駆動するケースのヘルパ `_step()` が `_update_velocity` → `_sync_attackbox` の順を**テスト側にハードコードしている**ためで、**`_sync_attackbox()` を `super(delta)` の前へ移す変異(`monitoring` が `brain` の状態に 1 フレーム遅れ、`RECOVER` の 1 フレーム目に攻撃判定が生きる)は 3.4 の時点ではどのテストも落とさなかった**(レビューの Minor 1 件。是正はタスク 3.5 で行った — 下の項を参照)。
- **`Area2D.monitoring` の切り替えは重なりを同期に再評価しない**(タスク 3.4。レビューが変異で実測)。そのため spec.md §5.9 の事前条件「`arm()` は `monitoring` を真にする前に呼ぶ」は、順序を入れ替えた実装(縁の判定を退避して保存した形)と**等価変異**になり、テストで区別できない。同じく `Attackbox._on_body_entered()` の `_has_dealt = true` を `body.call()` の後ろへ移す変異も、`take_damage()` から同期に再入する経路が無いため等価である。**いずれも実装は正しい順序で書いてあるが、テストで固定しようとしないこと**(申し送り「到達しない防御をテストで固定しようとしない」と同じ扱い)。
- **`Attackbox` の与済みの記録の縁は `monitoring` の偽→真で取っている**(タスク 3.4)。専用のフラグを増やしていないため、**`is_defeated` により `monitoring` を偽へ強制する分岐を `_sync_attackbox()` へ足すときは、`arm()` の呼び出しが縁の内側に閉じたままになる形(撃破後は早期 return する)を採ること。** 強制を代入の後ろに置くと、`is_attack_active` が真のまま毎フレーム「偽→真の縁」と誤認して `arm()` を呼び続ける。
- **突進の当たりを実フレームで見るテストは重力を落として組む**(タスク 3.4)。`charger_enemy_test.gd` の `FLOATING_GRAVITY = 1.0` がこれで、既定の重力のままだと突進が届く前に敵が矩形の高さぶん落ちて当たらず、「当たらないことが原因の緑」になる。あわせて硬直を長く取り(`LONG_RECOVER_TIME = 4.0`)、待ち時間が揺れても 2 回目の突進が始まらないようにしてある。レビューが 3 連続実行 + 8 コア全負荷の下で実測し、所要 1.493〜1.505 秒・判定は常に緑(`RECOVER` へ入る下限 48 フレーム = 0.80 秒に対し 1.5 秒待ち、`RECOVER` を抜ける上限は 4.8 秒)。**同じ形の実フレームの当たり判定のテスト(タスク 4.2 の敵弾、6.1)でも、下限と上限の両方の余裕を算術で示してから定数を決めること。**
- **同じ `SubResource` を 2 つの `CollisionShape2D` が指すと、形状を突き合わせるアサーションが恒真になる**(タスク 3.4。レビューが FYI として指摘)。`charger_enemy.tscn` は本体と `Attackbox` で `RectangleShape2D_charger` を共有しており、`assert_vector(attack_shape.size).is_equal(body_shape.size)` は片方を変えても落ちない。同じ位置のアサーション(`position` の比較)は別ノードのプロパティであり有効。**形状の値そのものを固定したい場合はテスト側の定数と比較すること。**
- **`Attackbox` の `damage` はシーンに既定値を書かず、`ChargerEnemy._ready()` が `stats.attack_damage` から代入する**(タスク 3.4)。テスト側の `EnemyStats` は `attack_damage` を既定の 15 と別の 23 にしてあり、シーンへ焼き込む変異・実装へ直書きする変異が 6 ケースで落ちる。**射撃型(タスク 5.3)の `attack_damage` も同じく `stats` 経由で流すこと。**
- **`charger_enemy.tscn` の `ext_resource` に `uid=` を書いていない**(タスク 3.4)。既存の `.tscn` はいずれも `path=` だけで `uid=` を持たないため、記法を揃えた(Godot はパスで解決するため実害はない)。**Godot エディタでシーンを保存すると `uid=` が書き戻される**ため、その差分が出たときは記法の揺れであって意味の変更ではない。
- **`Attackbox` の形状は本体の `RectangleShape2D`(16×16)を共有している**(タスク 3.4)。spec.md は攻撃判定の形状を定めていないが、§5.1 が本体・placeholder・`Hurtbox` を 16×16 に揃えており、突進の当たりだけ別の大きさにする根拠が無い。`[sub_resource type="RectangleShape2D"]` の共有は要件 8.7 の検査(`type="Resource"` の 0 件)に掛からない。
- **物理フレームの中では `Area2D` の重なりの通知が `_physics_process` より先に走る**(タスク 3.5。レビューが実測)。Godot の `SceneTree` は `physics_process_internal` グループ(`Area2D` が `area_entered` / `body_entered` を flush する層)を通常の `physics_process` グループより**先に**通知し、`queue_free()` の反映(削除キューの flush)はさらにその後に来る。したがって `Hurtbox` の被弾で撃破されたフレームの並びは **`area_entered` → `take_damage()` → `defeated` → `_on_defeated()` → `disarm()` → `ChargerEnemy._physics_process()` → `_sync_attackbox()`** であり、**撃破された同じフレームの中で `_sync_attackbox()` がもう 1 回走る**。`ChargerEnemy._sync_attackbox()` の `if is_defeated: return` は到達しない防御では**なく**、これを外すと実フレームでフレーム末尾の `monitoring` が `true` へ戻る(実測: 撃破フレームの観測が `[is_defeated=true, monitoring=false]` から `[true, true]` へ変わる)。**「撃破・解放の直後に何かをしない」ことを実装する後続の場面(タスク 6.1)でも、`queue_free()` を呼んだフレームの残りで自分の `_physics_process` がもう 1 回走ることを前提に組むこと。**
- **撃破を `_physics_process` の `is_defeated` の監視で検知すると 1 フレーム遅れる**(タスク 3.5)。上の順序により被弾は `_physics_process` より前に起きるため、監視で拾うと次のフレームまで攻撃判定が生きたままになる。`ChargerEnemy._ready()` で `defeated.connect(_on_defeated)` と自己接続する形を採った。変異(接続を削除して `_sync_attackbox()` の中で閉じる)は `test_the_attackbox_closes_in_the_frame_the_charger_is_defeated` が落とす。
- **「同じ物理フレームのうちに」を固定しているのは `set_deferred` を弾くアサーションである**(タスク 3.5)。`Attackbox.disarm()` を `monitoring = false` から `set_deferred("monitoring", false)` へ変える変異は、`take_damage()` の直後に `await` を挟まず `monitoring` を読む 2 本のケースだけが落とす。**撃破・解放の直後の状態を見るテストでは `await` を入れないこと**(入れると `set_deferred` 相当の実装を素通りさせる)。順序そのものの固定はタスク 2.1 の申し送りどおり `is_queued_for_deletion()` で行う。
- **タスク 3.4 のレビューが出した Minor(`_sync_attackbox()` を `super(delta)` の前へ移す変異をどのテストも落とさない)はタスク 3.5 で閉じた**。是正は実フレームで毎フレームの `[brain.state, monitoring]` を記録する観測ノード(`AttackboxObserver`)であり、この変異はこのケース 1 本だけが落とす。なお**観測ノードを敵より先にツリーへ載せても検出は失われない**(レビューが実測)。`state` と `monitoring` を同じスナップショットで読む限り 1 フレームのずれは読む位置によらず対の不整合として現れるためである。**同型の観測ノードを使う後続のケースでも、順序に頼らず「対の整合」で見ること。**
- **`assert_array(...).contains([...])` は witness として有効である**(タスク 3.5。レビューが実測)。到達不能な値を期待に足すと落ちるため、列挙した状態が実際に観測されたことを示せている。状態が 1 つしか現れないと対の整合が自明に成立するため、**毎フレームの整合を見るテストには必ず「複数の状態を通った」ことの witness を付けること。**
- **`Attackbox.disarm()` を経由するか `monitoring` を直接代入するかは等価変異である**(タスク 3.5)。開閉の口を 1 箇所へ寄せる設計上の選択であり、テストで区別できない。タスク 3.4 の申し送りと同じく、**等価変異をテストで固定しようとしないこと。**
- **射程の基準を検証するテストは「`add_child()` → 位置を決める → `launch()`」の順でしか固定できない**(タスク 4.1。レビューが変異で実測)。位置を `add_child()` より前に決めると `_ready()` の時点でも同じ値が読めるため、`_launch_position = position` を `launch()` から `_ready()` へ移す変異(spec.md §5.7 が名指しで警告する誤実装)が**全ケース緑のまま素通りする**。1 回目のレビューはこの穴で `REJECTED`、テスト 2 行の順序の入れ替えだけで閉じた(実装は 1 バイトも変えていない)。**同じ穴は「位置を原点から動かすケース」でしか観測できない** — 原点のままのケースをいくら足しても `_ready()` 時点と `launch()` 時点の値が一致するため落ちない。**タスク 5.3 の要件 4.14(`get_parent()` へ追加 → 位置を決める → `launch()`)は同型であり、`ShooterEnemy` のテストでも敵の位置をツリーへ載せた後に決めること。** なお手本の `tests/weapon/projectile_test.gd`(unit #2、凍結対象)は「位置 → `add_child()`」の順のままで同じ穴を残している(本単位の境界外のため是正していない。最終検証パネルへ申し送る)。
- **`Vector2i` への丸めの変異は、成分が分数の向きでしか落ちない**(タスク 4.1)。斜め `Vector2(1, -1)` は `Vector2i` でも同じ角度になるため素通りする。`Vector2(3.0, -1.5)` のような非正規化かつ分数の向きを 1 ケース置き、正規化(速さが `speed` になる)と丸めないこと(角度が保たれる)を 1 本で固定した。**タスク 5.3 の要件 4.7(標的への単位ベクトル)でも、斜めの配置は 45 度以外に取ること。**
- **`enemy_projectile_test.gd` の `SPEED` = 120.0 と `SHORT_MAX_DISTANCE` = 30.0 の組は意図を持つ**(タスク 4.1。レビューが実測)。60Hz で 1 フレームちょうど 2.0px(float で誤差なし)進み、15 フレーム目に移動距離がちょうど 30.0 になるため、射程の判定を `>` から `>=` へ変える変異が落ちる。**待ちの余裕が足りない場合は `WAIT_MILLIS` だけを上げること**(速度・射程を動かすとこの性質が壊れる)。現行は `WAIT_MILLIS` = 700 で、下限(射程で解放される 16 フレーム = 266.7ms)に対し 2.62 倍、上限(`MAX_DISTANCE` 400px 到達の 200 フレーム = 3333ms)に対し 4.76 倍。タスク 3.4 の申し送り「下限と上限の両方の余裕を算術で示してから定数を決める」に従った。
- **`frames_moved += 1` を `_physics_process` の末尾(解放の判定の後)へ移す変異は等価である**(タスク 4.1)。`queue_free()` は実行を打ち切らないため解放フレームでも加算が走り、生存中の弾のカウントも変わらない。**テストで区別しようとしないこと。**
- **`get_parent()` が `null` になる経路は `area_entered` の受け手には存在しない**(タスク 2.4)。`_on_area_entered()` はシグナル経由でしか呼ばれず、そのときノードは必ずツリー上にあるため、`owner_node == null` の節を落とす変異は等価変異でありテストで捕らえられない(レビューが実測。変異 22 種のうちこの 1 種だけが未検出)。ガードは防御として残してあるが、**到達しない防御をテストで固定しようとしないこと**。
- **分岐の両側のスタブは、判別に使う性質だけを変えて他を揃える**(タスク 4.2。レビューが 2 ラウンドで実測)。当初は `RecordingBody`(`CharacterBody2D` + `take_damage` 持ち)と地形・素の body(`StaticBody2D` + `take_damage` 無し)で**型とメソッドの有無が完全に相関**しており、`has_method(&"take_damage")` を `body is CharacterBody2D` へ置き換える変異(spec.md §8 が禁じる「型で見る」実装)が 68 ケース全緑のまま素通りした(`body is Player` への変異は落ちる)。**`test_enemy_projectile_pushes_no_error_for_a_body_without_take_damage` の相手を `CharacterBody2D` へ変える 1 語の是正**で相関が切れ、この変異が `Invalid call. Nonexistent function 'take_damage' in base 'CharacterBody2D'` で落ちるようになった(実装は 1 バイトも変えていない)。**`Hurtbox` の `damage` プロパティの有無による判別や、タスク 5.3・6.x で同型の判別を書くときも、判別に使う性質だけが違うスタブを 1 つ置くこと。** なお型で**絞り込む**変異(`body is CharacterBody2D and has_method(...)`)は mask に載りうる body の範囲で等価であり、固定しようとしない。
- **「常に真になるガード」の変異は 1 経路で漏れなく捕まる**(タスク 4.2)。ガードの削除・`body is PhysicsBody2D`・`has_method(&"queue_free")` の 3 種は、失敗するケースの組が完全に一致した(地形のケース + 上記の no-error のケース)。**`take_damage` を持たない相手を `assert_error(...).is_success()` で包むケースが 1 本あれば、この系統は網羅できる。**
- **`Area2D` の接触位置で「接触が原因の解放」を示す帯は、実測でフレーム番号まで確定できる**(タスク 4.2)。`SPEED` 120.0 / 60Hz(1 フレーム 2.0px)・矩形の縁 x = 11.0 の組で、重なりは 6 フレーム目・解放は 7 フレーム目(x = 14.0、116.7ms)であることをレビューが実測した(帯 `(11.0, 15.0]` に 1.0px の余裕)。**接触位置の帯は「フレーム数のアサーション」の代わりとして機能する**(x = 2.0 × フレーム数のため)。速度・寸法を動かすとこの性質が壊れるため、余裕が足りない場合は `WAIT_MILLIS` だけを上げること(タスク 4.1 の申し送りと同じ)。
- **ガードのしきい値の緩みは「境界のすぐ外」の値を表へ 1 行足すまで落ちない**(タスク 5.2。レビューが実測)。異常な距離が `-1.0` の 1 値だけだったため、`distance_to_target < 0.0` を **`< -0.0001` へ緩める変異**(受け入れ基準 4.10 に文字どおり違反する)と、**報告する値を実引数から定数 `-1.0` へ固定する変異**がどちらも 30 ケース全緑で素通りした。`SMALLEST_NEGATIVE_DISTANCE = -2^-20` を異常な引数の表へ 1 行足すだけで両方が落ちる。正の側(`delta <= 0.0001` へ広げる変異)も同様で、`SMALLEST_DELTA = 2^-20` を受理する 1 ケースで閉じた。時間と索敵範囲は `1 ± 2^-20` の比で境界を持っていたのに、**距離と `delta` の下端だけこの作法から外れていた**。タスク 4.3 の同型の申し送り(特殊値と厳密比較するガード)が一般論では読み流されたことになる。
- **申し送り(範囲外・最終検証パネルまたはタスク 6.4 へ): `ChargerBrain` が同じ 2 つの穴を持つ**(タスク 5.2 のレビューが実測)。`src/enemy/charger_brain.gd` へ `distance_to_target < -0.0001` と `delta <= 0.0001` を**同時に注入**しても `make test TESTS=res://tests/enemy/charger_brain_test.gd` は **36 ケース 0 failures のまま通る**。実装の振る舞いに欠陥は無く(距離は `distance_to()` か `INF` で作られるため負値は到達せず、`delta` は 1/60 秒でしきい値の帯に入らない)、不足はテストの検出力である。タスク 3.2 は承認済み・コミット済みであり、5.2 のコミットで手を入れると 1 コミットが 2 つの `_Boundary_` に跨るため、本ターンでは是正していない。是正は定数 1 行 + 表 1 行 + ケース 1 本で足りる。
- **拒否のときに「滞在時間を変えない」ことは、滞在時間が 0 でない状態で拒否させないと観測できない**(タスク 5.2。レビューが実測)。ガードへ `_elapsed = 0.0` を足す変異は、滞在時間 0 の状態から始めるケースでは **no-op になって素通りする**。`_brain_primed_to_fire()`(予備動作の満了にちょうど達した `Brain`)を作り、拒否の後 1 フレーム進めて真が返ることを見る形で閉じた。**`delta` の異常は「引く」・距離の異常は「足す」方向にずれるため 2 本の個別ケースを持っていたが、「0 へ戻す」変異はそのどちらの向きでもなく、この 2 本では捕らえられない。** 同種の「拒否したら状態を変えない」を書くタスク 5.4 でも、**満了に達した状態で拒否させること**。
- **人間が確定済みの判断に準ずる読み: `ShooterBrain` は `TELEGRAPH` の満了時に距離で分岐しない**(タスク 5.1。レビューが spec.md の本文から 5 点の根拠で追認)。標的が不在(距離 `INF`)でも真を返して `COOLDOWN` へ入る。`ChargerBrain` の `is_finite()` の分岐(2.4 / 2.11)を移植**しない**。根拠は 4 つ。(a) spec.md §5.5 の状態遷移は距離の条件を持たず、**同じ書式の §5.4 は分岐を明示している**(書き分けは意図的)。(b) 受け入れ基準 4.3 は無条件だが、対応する 2.4 は「かつ距離が有限のとき」を持ち `INF` の側を 2.11 が定める — **射撃型には 2.11 に相当する基準が無い**。(c) 要件 4.13 は「真を返したフレームで `target` が `null` の場合」を前提に「`COOLDOWN` へ移らなければならない」と述べており、真を返さない実装ではこの規定が空虚になる。(d) §5.5 は状態の値域を 3 値と明記しており、`RECOVER` へ逃がす分岐は不変条件に反する。`test_the_telegraph_ends_even_when_the_target_is_absent` がこれを固定し、`is_finite()` を持ち込む変異をこの 1 本だけが落とす。
- **`Brain` の `IDLE` の遷移条件は、距離の「両端」(`INF` と 0.0)を与えないと述語が緩む**(タスク 5.1。レビューが変異で実測)。索敵範囲の内・外・境界の 3 値だけでは、`or is_inf(distance_to_target)` を足す変異(**標的が居ない間ずっと予備動作を繰り返す**)と `and distance_to_target > 0.0` を足す変異(下端を除く)がいずれも全ケール緑のまま素通りした。`INF` は `ShooterEnemy` が標的を失った間に渡す**出荷時の常用の経路**であり、要件 1.15 に反する。`test_the_brain_stays_idle_while_the_target_is_absent`(1 周期ぶん `INF` を与えて `[戻り値, state]` の列を厳密比較)と `test_the_brain_telegraphs_at_a_zero_distance` で閉じた。手本の `charger_brain_test.gd` は同型のケースを持っており、「同じ形で組む」から漏れていた。**`ChargerBrain` を手本に写す後続でも、手本のケースの一覧と突き合わせること。**
- **戻り値を持つ `Brain` の観測は `[戻り値, state]` の対を毎フレーム並べる**(タスク 5.1)。別々のアサーションで見ると「真を返すが `COOLDOWN` へ移らない」「移るが真を返さない」の片方だけを壊す変異が、対応の崩れとして現れない。タスク 3.5 の申し送り(順序に頼らず対の整合で見る)と同じ考え方。
- **テスト側の定数が「両方を跨ぐ」という性質は、コメントではなくアサーションで持つ**(タスク 5.1)。`shooter_brain_test.gd` は `ATTACK_REACH` を `ATTACK_SPEED * ATTACK_DURATION` の積から導き、`FAR_DISTANCE` が `DETECT_RANGE` と `ATTACK_REACH` の間にあることを当該ケースの冒頭でアサーションする。手で複製した値のままだと、因子を動かしたときに跨がなくなったことに気付けないまま緑になる。
- **`ShooterBrain` の 1 周は既定の `FRAME_DELTA` = 0.125・`telegraph_time` = 0.25・`recover_time` = 0.75 で 11 フレーム**(タスク 5.1)。予備動作 3 フレーム(1〜3)→ 4 フレーム目に真 → 待機 7 フレーム(4〜10)→ 11 フレーム目に `IDLE` → 12 フレーム目から次の予備動作 → 15 フレーム目に 2 回目の真。満了に要するフレーム数は `ceil(duration / delta) + 2`(タスク 3.1 の「判定 → 加算」の性質による)。**タスク 5.3 の `ShooterEnemy` の期待フレーム数はこの並びから算出すること。**
- **前セッションの中断からの復旧(タスク 4.3)。活かしたが、実装に 1 行の欠陥が残っていた**。成果物 2 ファイルは未コミットで、レビューを通していなかった(前セッションは dev-reviewer を起動した直後に打ち切られ、判定が出ていない)。**前セッションが「緑」と報告した `make test TESTS=res://tests/weapon` は本セッションの再実行では赤**であり(1 ケース・4 アサーション失敗)、`speed <= 0.0` のガードに `return` が欠けていた(手本の `src/weapon/projectile.gd:47` は持っている)。**中断からの復旧では、前セッションの検証結果の報告を信用せず必ず再実行すること。** テスト側はこの欠陥を正しく検出しており、実装の `return` 1 行を足して緑に戻した上でレビューを最初からやり直した。
- **「拒否したら状態を変えない」ことは、拒否する呼び出しに成功時と別の値を渡さないと観測できない**(タスク 4.3。レビューが 2 ラウンドで実測)。要件 5.6 の「状態を変えずに返る」は `damage` だけでなく射程の基準(`_max_distance` / `_launch_position`)も含むが、拒否する再 `launch()` に成功時と同じ `MAX_DISTANCE` を渡していたため、**射程の代入だけをガードの前へ移す変異が全 74 ケース緑のまま素通り**していた。`SHORT_MAX_DISTANCE`(拒否の時点で既に超えている値)へ差し替えるだけで閉じた。**同種の「拒否したら状態を変えない」を書く後続(タスク 5.2・5.4)でも、拒否する呼び出しには成功時と別の値を渡すこと。**
- **特殊値と厳密比較するガードは、「境界のすぐ外」の値を 1 つ置かないと述語がしきい値へ緩む**(タスク 4.3。レビューが実測)。`direction == Vector2.ZERO` の事前条件に対し、テストの向きが `(1,0)`・`(1,-1)`・`(3,-1.5)` の 3 つだけだったため、`is_zero_approx()`・`length() < 0.001`・**`direction.x == 0.0`** の 3 変異がいずれも素通りした。正常系の境界のケースへ `SMALLEST_DIRECTION = Vector2(0.0, -0.000003)` を置いて 3 種とも落ちるようになった(x 成分を 0 に取るのが `direction.x == 0.0` の変異を、各成分を `CMP_EPSILON` = 1e-5 未満に取るのが近さの判定を落とす)。**`direction.x == 0` の向きは標的が真上・真下にいる射撃型が実際に作る**ため、タスク 5.3 の 4.7 でも真上・真下の配置を 1 ケース置くこと。タスク 3.2 の `INF` の申し送り(特殊値の判定はしきい値へ置き換えられる)と同型である。
- **`WAIT_MILLIS` の値はテストの強度の指標にならない**(タスク 4.3。レビューが実測)。`WAIT_MILLIS` を 700 → 0 にしても `res://tests/weapon` の 74 ケースは全緑になる(`await await_millis(0)` でも gdUnit の実行の中で物理フレームが消化される)。強度を担保しているのは「消化フレーム数から期待値を算出する」設計と witness であって待ち時間そのものではない。**定数を下げる方向の変異は弱体化の検出に使えない**(上げる方向はタスク 4.1 の申し送りどおり安全)。
- **`launch()` の複数の事前条件のうちどれを報告するかは仕様が定めていない**(タスク 4.3)。最初の違反で `return` する実装ではガードの順序を入れ替える変異が等価であり、テストで固定しようとしないこと。タスク 2.2 の「宣言の順で後ろの項目を壊して文言を見る」形は、複数の `push_error` を出す `EnemyStats` の検査に固有である。
- **`queue_free()` は同じフレームのシグナルの配送を打ち切らないため、1 発の弾が複数の相手へダメージを与えうる**(タスク 4.2。レビューが実測: 同じ位置に `take_damage` を持つ body を 2 つ置くと両方が受けた)。受け入れ基準 5.4 はこれを禁じておらず、出荷するシーンでは mask に載る `take_damage` 持ちがプレイヤー 1 体だけのため実害はない。`Attackbox` の与済みの記録は「1 回の突進が複数フレームに跨る」ためのものであり、弾には対応する要求が無い。**要求の無い防御を足さないこと**(申し送り「到達しない防御をテストで固定しようとしない」と同じ扱い)。
- **発射を `_physics_process` から呼ぶ配線は、実フレームで撃たせるケース 1 本だけが落とす**(タスク 5.3。変異で実測)。`ShooterEnemy._physics_process()` から `_advance_brain(delta)` の呼び出しを消す変異は、同期で駆動する 16 ケースが全緑のまま素通りした(テスト側の `_step()` が `_update_velocity` → `_advance_brain` の順を持っているため、実装の中の配線を観測していない)。タスク 3.4 で `_sync_attackbox()` について実測された穴と同型であり、`test_the_shooter_fires_from_its_own_physics_frames`(実フレームで 1 発撃たせ、`brain.state` が `COOLDOWN` であることを witness にする)を足して閉じた。**同期で駆動するヘルパを使う後続のタスク(5.4・6.1)でも、実フレームで駆動するケースを 1 本は持つこと。**
- **実フレームで弾の数を見るテストは射程を長い値へ差し替える**(タスク 5.3)。テスト用の `bullet_max_distance` は射程の境界をフレーム数で押さえるために 24.0(1 フレーム 2.0px で 12 フレーム)と短く取ってあり、そのままだと待ちの 600ms の間に弾が射程で解放され、生成された弾を数えるアサーションが 0 件になる(「撃っていない」と区別できない)。当該ケースだけ `LONG_BULLET_MAX_DISTANCE` = 400.0 へ差し替えてある。
- **発射位置を決める前に `launch()` を呼ぶ変異は、敵の位置が射程より遠い配置でしか落ちない**(タスク 5.3。タスク 4.1 の申し送りの実地版)。この変異では `_launch_position` が原点のままになるため、敵の位置の長さが射程を超えていれば弾が 1 フレーム目で解放される。`SPAWN_POSITION` = `Vector2(20.0, -48.0)`(長さ 52.0)は射程 24.0 より遠く、`test_the_shot_carries_the_bullet_max_distance_from_the_stats` がこの変異を落とす。**敵の位置を原点の近くへ動かすとこの検出が失われる。**
- **標的を静止させたままのケースだけでは、距離が `Brain` へ流れていることも「距離は発射の条件でない」ことも固定できない**(タスク 5.3。レビューが変異で実測し、テスト 2 本の追加で閉じた)。(a) `brain.update()` の第 2 引数を定数 `0.0` へ置き換える変異(**標的が画面外でも撃ち続ける**)は、索敵範囲の外へ標的を置いて 1 周ぶん回し、**弾が 0 発**で `state` が `IDLE` のままであることを見るケース(`test_the_shooter_holds_its_fire_while_the_target_is_out_of_the_detect_range`)だけが落とす。`target_distance()` が `INF` を返すことを見るケースは、その値が `Brain` へ渡ることを見ていない。(b) 発射の条件へ距離を足す変異(`... and distance <= stats.detect_range`)は、**予備動作の途中で標的を索敵範囲の外へ動かしてから発射のフレームを進める**ケース(`test_a_target_that_leaves_the_detect_range_mid_telegraph_still_draws_the_shot`)だけが落とす。要件 4.7 の発射の条件は距離を含まず、4.11 と spec.md §5.1(`TELEGRAPH` 以降で標的を失っても完走する)がこれを裏書きする。既定値(索敵範囲 160・予備動作 0.4 秒・プレイヤーの速度 100)では日常的に起きる経路である。**同じケースは「向きを予備動作へ入った時点で控える」変異の観測点にもなる**(退いた後の位置を指すことを見る)。**標的を動かす経路を持つ後続(5.4・6.1)でも、静止した配置だけで組まないこと。**
- **「常に 0」の要求は、到達できる状態すべてを開始時点に持つフレームで観測しないと枝が抜ける**(タスク 5.3。レビューが変異で実測)。`velocity.x = 0.0` を `if brain.state == EnemyState.State.IDLE:` で囲う変異は、新品の敵に 1 フレームだけ与えるケース(`IDLE` の枝しか通らない)を素通りする。`_update_velocity()` は `brain` を進める**前**に走るため、観測したい状態はそのフレームの**開始時点**の状態である。予備動作は 1 フレーム、待機は `ceil(telegraph_time / delta) + 2` フレーム進めてから観測する形で閉じた(タスク 3.3 の申し送り「非ゼロの速度を作ってから観測する」と対で必要である)。
- **要件 8.7 のシーン側は、整形の正しい埋め込みサブリソースをアサーションで落とせている**(タスク 5.3。レビューが実測)。`shooter_enemy.tscn` の `stats` を `[sub_resource type="Resource" id=...]` + `script = ExtResource(enemy_stats.gd)` + 10 項目(`load_steps` も合わせる)へ差し替える変異は、クラッシュせず `test_shooter_scene_reads_the_stats_from_the_shared_file` が 1 failure で落ちる。**実装者が最初に観測した rc=134(クラッシュ)は、手で書いた `.tscn` が宣言順と `load_steps` を満たしていなかったことに由来する誤りであり、8.7 の検出は `grep` の検証コマンドだけに頼っていない**(`resource_path` の厳密一致が本体で、`grep` は二重の網である)。**`.tscn` を手で変異させて検出力を測るときは、宣言順(`ext_resource` → `sub_resource` → `node`)と `load_steps` を必ず整えること**(整えないと「落ちた」のが変異の検出なのかパースの失敗なのか区別できない)。
- **`ShooterEnemy` が渡す向きを正規化するかどうかは等価変異である**(タスク 5.3)。`EnemyProjectile.launch()` が受け取った向きを自分で正規化するため、`_target_direction()` が単位ベクトルを返しても差分ベクトルを返しても弾の振る舞いは同じになる。受け入れ基準 4.7 の「単位ベクトル」は実装の意図としては守っているが、**テストで固定しようとしないこと**(申し送り「等価変異をテストで固定しようとしない」と同じ扱い)。丸め(`Vector2i`)・親の座標系での測定は別の変異であり、`SHOT_TABLE` の斜め(45 度以外)と真上・真下の配置が落とす。
