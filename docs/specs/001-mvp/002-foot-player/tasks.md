# foot-player — 実装タスク

> 仕様の詳細は同じディレクトリの仕様文書 spec.md を参照する。
> このファイルには仕様を転記しない。

## File Structure Plan

| ファイルパス | 区分 | 責務 |
| ------------ | ---- | ---- |
| `src/player/player_stats.gd` | 新規 | 手触りを決める数値を `@export` で 1 箇所に集約する `Resource` |
| `src/player/player_command.gd` | 新規 | 1 フレーム分の入力の意図を表す値 |
| `src/player/player_input.gd` | 新規 | `Input` を読んで `PlayerCommand` を作る static。`Input` を触る唯一の場所 |
| `src/player/player.gd` | 新規 | 速度の計算・射撃方向の決定・武器と体力の更新を行う `CharacterBody2D` |
| `src/player/player.tscn` | 新規 | `Player` + placeholder の `ColorRect` + `CollisionShape2D` |
| `src/player/aim_resolver.gd` | 新規 | 8 方向の射撃方向を決める純粋関数 |
| `src/player/health.gd` | 新規 | 体力・待機時間の計測・自動回復・枯渇のエッジ検出 |
| `src/weapon/primary_weapon.gd` | 新規 | 主武器の発射間隔の管理 |
| `src/weapon/secondary_weapon.gd` | 新規 | 副武器のチャージとクールダウンの管理 |
| `src/weapon/projectile.gd` | 新規 | 直進・地形との衝突・射程超過での解放を行う `Area2D` |
| `src/weapon/projectile.tscn` | 新規 | `Projectile` + placeholder の `ColorRect` + `CollisionShape2D` |
| `src/weapon/combat_limits.gd` | 新規 | 敵の攻撃が満たすべき上限の定数 |
| `src/stage/dev_stage.gd` | 新規 | `player.died` を受けて現在のシーンを再読込する |
| `src/stage/dev_stage.tscn` | 新規 | 床・段差 3 段・壁 2 と `Player`・`DamageZone` を配置した動作確認用の仮ステージ |
| `src/stage/damage_zone.gd` | 新規 | 触れているプレイヤーへ 1 秒に 1 回ダメージを与える `Area2D` |
| `src/stage/damage_zone.tscn` | 新規 | `DamageZone` + `CollisionShape2D` + placeholder の `ColorRect` |
| `project.godot` | 変更 | `[input]` の 7 アクションと `[layer_names]` の 2d_physics のレイヤ名を追加する。`run/main_scene` は変更しない |
| `docs/testing.md` | 変更 | `tests/harness/` が配置の規約の例外であること・サンプルの位置づけ・仮ステージの起動方法を追記する |
| `tests/player/player_move_test.gd` | 新規 | 移動・ジャンプ・向きの速度計算のテスト |
| `tests/player/player_scene_test.gd` | 新規 | `input_source` を差し替えてシーンツリー上で物理フレームを進めるテスト |
| `tests/player/player_weapon_test.gd` | 新規 | `Player` に統合した主武器・副武器の発射のテスト |
| `tests/player/player_health_test.gd` | 新規 | `Player` に統合した被弾・`died` の中継のテスト |
| `tests/player/aim_resolver_test.gd` | 新規 | `AimResolver` のテスト |
| `tests/player/health_test.gd` | 新規 | `Health` のテスト |
| `tests/player/player_stats_test.gd` | 新規 | `PlayerStats` の既定値と検証のテスト |
| `tests/weapon/primary_weapon_test.gd` | 新規 | `PrimaryWeapon` のテスト |
| `tests/weapon/secondary_weapon_test.gd` | 新規 | `SecondaryWeapon` のテスト |
| `tests/weapon/projectile_test.gd` | 新規 | `Projectile` の移動・衝突・射程・異常系のテスト |
| `tests/weapon/combat_limits_test.gd` | 新規 | `CombatLimits` の定数のテスト |
| `tests/stage/dev_stage_test.gd` | 新規 | 仮ステージの構成・レイヤ・`died` の接続のテスト |
| `tests/stage/damage_zone_test.gd` | 新規 | `DamageZone` の周期的なダメージのテスト |

削除対象はない(本単位は既存の置換・廃止を伴わない)。`addons/gdUnit4/` と `reports/` は生成物であり、この計画には載せない。

`tests/stage/` は spec.md §6.6 の一覧に明示されていないが、同節が定める「実装のディレクトリ構成を写す」規約(`docs/testing.md`)から `src/stage/` に対応して決まる。

### 分解時に埋めた仕様の空白(実装者への申し送り)

spec.md が定めておらず、実装に必要なため本分解で決めた事項。**契約の変更ではなく、契約から一意に決まらない実装の選択**である。統括の確認が付いた時点で変わる可能性がある。

- **`Player` が弾のシーンを参照する手段**: `@export var projectile_scene: PackedScene` を持たせ、`player.tscn` で `res://src/weapon/projectile.tscn` を設定する(タスク 5.3)。spec.md §5.1 の公開 API には現れないが、値の出どころを 1 箇所にする §6.1 の方針に沿う。
- **生成した弾を追加する先**: `get_parent()`(親が無い場合は自身)。自身へ追加すると弾がプレイヤーと一緒に動き、要件 5.1 が成立しない(タスク 5.3)。
- **`Player` の `collision_mask`**: 1(地形)。spec.md §6.5 は `Player` の layer(2)しか定めていないが、mask に 1 が無いと要件 9.1 の床の上に立てない(タスク 1.3)。
- **`DamageZone` の 1 回目のダメージの位置**: 接触した瞬間に 1 回目を与え、以後 1 秒ごとに与える(タスク 7.2)。要件 9.3 は周期だけを定め、起点を定めていない。
- **`PlayerStats` の値の検証を置く場所**: `Player._ready()`(タスク 2.3)。spec.md §6.1 は「0 以下が設定された場合は `_ready()` の検証で `push_error` を出す」と書くが、`PlayerStats` は `Resource` であり `_ready()` を持たない。§5.1 の `stats` の事前条件(未設定なら `_ready()` で `push_error`)と同じ場所を指すものとして読む。

## タスク一覧

- [x] 1. 入力の契約と `Callable` 差し替えの成立確認(リスク先行)

  spec.md §3 の未検証の前提のうち「`Callable` を差し替える形の入力の注入が Godot 4.7.1 の headless で機能する」を最初に確かめる。この前提が崩れると要件 8 と、要件 1.9 を含む検証方法の大半が組み替えになるため、他のどのタスクよりも前に置く。分解時に一時プロジェクトで予備検証を済ませており(`godot --headless --script` で、static メソッドを `Callable` の既定値にできること・差し替えた `Callable` が `_physics_process` 経由で速度に反映されることを確認した)、本タスクはそれを **gdUnit4 のテストツリー上で**再現することが目的である。予備検証は差し替え先に lambda を使ったが、テストでは lambda を使わない(1.3 の実装の要点を参照。差し替え自体は lambda でも成立するが、キャプチャが値コピーのため呼び出し回数を観測できない)。

  - [x] 1.1 `PlayerStats`(`Resource`)と `PlayerCommand` を新規作成し、既定値と不変条件をテストで固定する
    _Requirements: 10.1_
    _Boundary: PlayerStats_
    - 対象ファイル: `src/player/player_stats.gd`(新規), `src/player/player_command.gd`(新規), `tests/player/player_stats_test.gd`(新規)
    - 仕様参照: spec.md §6.1、§6.3
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 1.2 (P) `project.godot` に 7 つの入力アクションと 2d_physics のレイヤ名を追加する。`PlayerInput.read()` を実装する(この関数自体はテストしない)
    _Requirements: 8.1_
    _Boundary: ProjectConfig_
    _Depends: 1.1_
    - 対象ファイル: `project.godot`(変更), `src/player/player_input.gd`(新規)
    - 仕様参照: spec.md §5.2 のアクション表、§6.5 のレイヤ割り当て
    - 実装の要点: `PlayerInput.read()` の戻り値の型は 1.1 が作る `PlayerCommand` であり、`(P)` は 1.1 の完了後に他の (P) タスクと並行できることを意味する(1.1 より先には走らせない)
    - 検証コマンド: `ng=0; for a in move_left move_right aim_up aim_down jump fire_primary fire_secondary; do grep -q "^$a=" project.godot || { echo "NG: $a"; ng=1; }; done; test $ng -eq 0 && echo OK`(7 件すべてが定義されていること。欠落は全件を報告する)、`grep -q 'run/main_scene="res://main.tscn"' project.godot && echo OK`(要件 9.6 の前提を壊していないこと)
  - [x] 1.3 `Player` の骨格(`input_source`・`apply_command()` の水平移動・`_physics_process` からの `move_and_slide()`)と `player.tscn` を作り、シーンツリー上で `input_source` を差し替えて 3 物理フレーム進め、水平の位置を検証する
    _Requirements: 1.1, 1.9, 1.10, 8.2, 8.3, 8.4, 8.5_
    _Boundary: Player_
    _Depends: 1.1, 1.2_
    - 対象ファイル: `src/player/player.gd`(新規), `src/player/player.tscn`(新規), `tests/player/player_scene_test.gd`(新規)
    - 仕様参照: spec.md §5.1、§7 Requirement 8、§8「`move_and_slide()` を `_physics_process` に置き、`apply_command()` から出す」
    - 実装の要点(タスク固有):
      - `var input_source: Callable = PlayerInput.read` の形で static メソッドを既定値にできることは検証済み(`is_valid()` が真、`get_method()` が `"read"`)。ただし `get_object()` はクラスのインスタンスではなく**スクリプト(GDScript)リソース**を返す。8.3 の検証はこの点を踏まえて書く
      - **注入する `Callable` には、状態を持つオブジェクトのメソッドを渡す(lambda を使わない)**。GDScript の lambda はローカル変数を**値コピーで捕捉**するため、lambda の中で呼び出し回数を数えても外側の変数に反映されず、呼び出し回数を観測できない
      - **`Player._physics_process` は毎フレーム無条件に動く**。`tests/harness/scene_test.gd` の `frames_to_move` に相当する停止機構は `Player` 側に無く、`await await_millis(500)` では約 30 物理フレームが進む。3 フレームぶんの変位を得るには、**注入側が 4 回目以降の呼び出しで `move_x = 0.0` を返す**ようにする
      - アサーションは 2 つ行う。注入したオブジェクトの呼び出し回数(3 回以上。待ちが足りずフレームを消化しなかった場合と区別する)と、水平の位置。期待値は `move_speed / Engine.physics_ticks_per_second * 3` で算出し、実数を直書きしない(`docs/testing.md`「物理フレームを進めるテスト」)
      - 1.10 は `player.tscn` を読み込んで、`ColorRect` の `size` と `CollisionShape2D` の `shape.size` がともに `Vector2(12, 32)` であること、原点が矩形の中心にあること(`ColorRect` の `position` が `Vector2(-6, -16)`、`CollisionShape2D` の `position` が `Vector2.ZERO`)を検証する
      - 8.4・8.5 は `player.gd` の静的な検査で示す(`_physics_process` の中に `move_and_slide()` があり、`apply_command()` の中に無いこと)
      - `Player` の `collision_layer` は 2、`collision_mask` は 1(File Structure Plan の申し送りを参照)
      - ツリーへ載せたノードは `auto_free()` と対にする(`docs/testing.md`)
    - 検証コマンド: `make test TESTS=res://tests/player`、`grep -n 'move_and_slide' src/player/player.gd > /tmp/mas.txt; cat /tmp/mas.txt`(出現が `_physics_process` の中の 1 箇所だけであること)

- [x] 2. 移動・ジャンプ・向きの速度計算
  - [x] 2.1 `move_x` による水平の速度の停止と `facing` の更新を実装する
    _Requirements: 1.2, 1.6, 1.7_
    _Boundary: Player_
    _Depends: 1.3_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_move_test.gd`(新規)
    - 仕様参照: spec.md §5.1、§7 Requirement 1
    - 実装の要点: `apply_command()` を直接呼び `velocity` を検証する(物理フレーム不要・ツリーへ載せない)。`stats` はテストが `PlayerStats.new()` を作って代入する
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 2.2 重力の加算・ジャンプ・接地中の垂直の速度の 0 化を実装する
    _Requirements: 1.3, 1.4, 1.5, 1.11_
    _Boundary: Player_
    _Depends: 2.1_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_move_test.gd`(変更)
    - 仕様参照: spec.md §5.1「接地状態を引数で受け取る理由」、§7 Requirement 1
    - 実装の要点: 1.4(接地 + ジャンプ)と 1.5(非接地 + ジャンプ)は分岐の両側であり、個別のテストケースを割り当てる。1.11 は接地 + ジャンプ無しの分岐
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 2.3 異常系を実装する。`delta <= 0.0` での `apply_command()` と、0 以下の値を持つ `PlayerStats` の検証
    _Requirements: 1.8, 10.3_
    _Boundary: Player_
    _Depends: 2.2_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_move_test.gd`(変更)
    - 仕様参照: spec.md §5.1「エラー」「事前条件」、§6.1「不変条件」、§7 Requirement 1.8・10.3
    - 実装の要点(タスク固有):
      - `push_error` は `await assert_error(func() -> void: ...).is_push_error("<文言>")` で検証する(gdUnit4 v6.2.0 に実在。`GdUnitTestSuite.assert_error`)。既定の `report_push_errors` は false のため、`push_error` を出しただけではテストは落ちない。1.8 は「速度が変わらないこと」も併せて検証する
      - 10.3 の検査は `Player._ready()` に置く(`PlayerStats` は `Resource` であり `_ready()` を持たない。spec.md §6.1 の「`_ready()` の検証」は §5.1 の `stats` の事前条件と同じ場所を指すものとして読む)。`stats` 未設定時に `PlayerStats.new()` へ退避する挙動も同じ場所で実装する
    - 検証コマンド: `make test TESTS=res://tests/player`

- [x] 3. (P) 射撃方向の決定
  - [x] 3.1 `AimResolver.resolve()` を純粋関数として実装し、8 方向・入力なし・地上での下方向の落としを検証する
    _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
    _Boundary: AimResolver_
    - 対象ファイル: `src/player/aim_resolver.gd`(新規), `tests/player/aim_resolver_test.gd`(新規)
    - 仕様参照: spec.md §5.3、§7 Requirement 2
    - 実装の要点: 2.4(接地 + 下)と 2.5(非接地 + 下)は分岐の両側であり、個別のテストケースを割り当てる。2.1 は 8 方向を網羅する入力の組で確かめる
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 3.2 `facing` が -1・1 以外で呼ばれた場合の異常系を実装する
    _Requirements: 2.7_
    _Boundary: AimResolver_
    _Depends: 3.1_
    - 対象ファイル: `src/player/aim_resolver.gd`(変更), `tests/player/aim_resolver_test.gd`(変更)
    - 仕様参照: spec.md §5.3「事前条件」
    - 実装の要点: `await assert_error(...)` で `push_error` を、戻り値で `Vector2i(1, 0)` を検証する
    - 検証コマンド: `make test TESTS=res://tests/player`

- [x] 4. (P) 弾体
  - [x] 4.1 `Projectile` と `projectile.tscn` を新規作成し、`launch()` 後の直進と衝突レイヤ・マスクを検証する
    _Requirements: 5.1, 5.4, 5.6_
    _Boundary: Projectile_
    - 対象ファイル: `src/weapon/projectile.gd`(新規), `src/weapon/projectile.tscn`(新規), `tests/weapon/projectile_test.gd`(新規)
    - 仕様参照: spec.md §5.6、§6.5、§7 Requirement 5
    - 実装の要点(タスク固有):
      - 移動は `_physics_process` で行い、テストはシーンツリーへ載せて `await await_millis()` で待ち、消化フレーム数と変位の両方を検証する(`docs/testing.md`「物理フレームを進めるテスト」)
      - 5.4 は `collision_layer`・`collision_mask` の整数値(レイヤ 3 → 4、マスク 1 と 4 → 9)を直接アサーションする
      - 5.6 は `launch()` のシグネチャに `max_distance` があること、および `projectile.gd` が `PlayerStats` を参照しないこと(`grep`)で示す
    - 検証コマンド: `make test TESTS=res://tests/weapon`、`grep -c 'PlayerStats' src/weapon/projectile.gd`(0 であること)
  - [x] 4.2 地形との衝突と射程超過での解放を実装する
    _Requirements: 5.2, 5.3_
    _Boundary: Projectile_
    _Depends: 4.1_
    - 対象ファイル: `src/weapon/projectile.gd`(変更), `tests/weapon/projectile_test.gd`(変更)
    - 仕様参照: spec.md §5.6
    - 実装の要点: 地形は `StaticBody2D`(`PhysicsBody2D`)であり `Area2D` ではないため、検出は `body_entered` を使う(`area_entered` では発火しない)。テストは `StaticBody2D`(layer 1)を弾の進路に置いて解放を確かめる。解放の確認は `is_instance_valid()` で行い、`queue_free()` の反映を待つ
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [x] 4.3 `launch()` の異常系(`direction` が `Vector2i.ZERO`、`speed`・`damage`・`max_distance` が 0 以下)を実装する
    _Requirements: 5.5_
    _Boundary: Projectile_
    _Depends: 4.2_
    - 対象ファイル: `src/weapon/projectile.gd`(変更), `tests/weapon/projectile_test.gd`(変更)
    - 仕様参照: spec.md §5.6「事前条件」、§7 Requirement 5.5
    - 実装の要点: 4 つの異常な引数それぞれに個別のテストケースを割り当て、`push_error` と「弾が進まないこと」の両方を検証する
    - 検証コマンド: `make test TESTS=res://tests/weapon`

- [x] 5. 武器と発射

  `PrimaryWeapon`・`SecondaryWeapon` を単体で確定させてから `Player` へ統合する。統合は `AimResolver`(タスク 3)と `Projectile`(タスク 4)の両方に依存する。

  - [x] 5.1 (P) `PrimaryWeapon` を実装する。生成直後は発射可能で、以後は `interval` 以上の間隔でのみ真を返す
    _Requirements: 3.6_
    _Boundary: PrimaryWeapon_
    - 対象ファイル: `src/weapon/primary_weapon.gd`(新規), `tests/weapon/primary_weapon_test.gd`(新規)
    - 仕様参照: spec.md §5.4
    - 実装の要点: `tick()` と `try_fire()` を直接呼ぶ純粋な状態機械であり、物理フレームは不要。連続するフレームで真を返す間隔が `interval` 以上であること(§5.4 の事後条件)も検証する
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [x] 5.2 (P) `SecondaryWeapon` を実装する。チャージの進行・完了時の発射・未完了での中断・クールダウンの経過
    _Requirements: 4.1, 4.3, 4.4, 4.5, 4.6_
    _Boundary: SecondaryWeapon_
    - 対象ファイル: `src/weapon/secondary_weapon.gd`(新規), `tests/weapon/secondary_weapon_test.gd`(新規)
    - 仕様参照: spec.md §5.5
    - 実装の要点: 4.4(完了して離す → 真を返す)と 4.3(未完了で離す → 偽を返しクールダウンに入らない)は分岐の両側であり、個別のテストケースを割り当てる。本サブタスクでは `update()` の戻り値と状態変数までを検証し、要件 4.2 の弾の生成は 5.3 で検証する
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [x] 5.3 `Player` へ両武器を統合し、コマンドに応じた弾の生成と `fired` の発火を実装する
    _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 4.2, 4.7, 4.8_
    _Boundary: Player_
    _Depends: 2.3, 3.2, 4.3, 5.1, 5.2_
    - 対象ファイル: `src/player/player.gd`(変更), `src/player/player.tscn`(変更), `tests/player/player_weapon_test.gd`(新規)
    - 仕様参照: spec.md §5.1、§6.1、§7 Requirement 3・4
    - 実装の要点(タスク固有):
      - 弾のシーンは `@export var projectile_scene: PackedScene`(`player.tscn` で設定)、追加先は `get_parent()`(File Structure Plan の申し送りを参照)
      - 3.1・4.2 の「弾を 1 発生成」は、生成先の子ノード数の増分と `fired` の発火の両方で検証する(`assert_signal`)。3.7・4.8 は `fired` の `is_secondary` の値で区別する
      - 3.3・4.7 は生成された `Projectile` に渡った `damage` と `speed` を検証する。値は `stats` から取り、`player.gd` へ直書きしない(要件 10.2)
      - 3.2(間隔未満で撃たない)と 3.5(押していないと撃たない)は分岐の別側であり、個別のテストケースを割り当てる
      - 3.4 は、`facing` と `aim_y` を変えたコマンドで生成された `Projectile` の進行方向が `AimResolver.resolve()` の戻り値と一致することで検証する(`Player` が方向を独自に計算していないこと)
    - 検証コマンド: `make test TESTS=res://tests/player`

- [x] 6. 体力と自動回復
  - [x] 6.1 (P) `Health` を実装する。範囲の強制・被弾・待機時間・自動回復・上限での停止
    _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
    _Boundary: Health_
    - 対象ファイル: `src/player/health.gd`(新規), `tests/player/health_test.gd`(新規)
    - 仕様参照: spec.md §6.4
    - 実装の要点: `tick(delta)` を直接呼ぶ純粋な状態機械であり、物理フレームは不要。回復の端数は内部の float に蓄積し、1 以上になった分だけ `current` へ移す(6.4 は端数の切り捨てを含めて検証する)
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 6.2 枯渇のエッジ検出と枯渇後の凍結、`take_damage()` の異常系を実装する
    _Requirements: 6.6, 6.8, 6.9_
    _Boundary: Health_
    _Depends: 6.1_
    - 対象ファイル: `src/player/health.gd`(変更), `tests/player/health_test.gd`(変更)
    - 仕様参照: spec.md §6.4「`depleted` のエッジ検出は `Health` が持つ」
    - 実装の要点: 6.6 は `assert_signal` で発火回数がちょうど 1 回であることを検証する(0 になった後の追加の `take_damage()` で増えないこと)。6.9 は `await assert_error(...)` で `push_error` と状態不変の両方を検証する
    - 検証コマンド: `make test TESTS=res://tests/player`
  - [x] 6.3 `Player` へ `Health` を統合し、`take_damage()` の委譲・`tick()` の呼び出し・`depleted` から `died` への中継を実装する
    _Requirements: 6.7_
    _Boundary: Player_
    _Depends: 5.3, 6.2_
    - 対象ファイル: `src/player/player.gd`(変更), `tests/player/player_health_test.gd`(新規)
    - 仕様参照: spec.md §5.1「`died` の発火」、§6.4「ロジックの所在」
    - 実装の要点: `Player` は待機時間・経過時間を自分で持たない。`health` の生成は `stats` の確定後(`_ready()`)に行い、`apply_command()` から `health.tick(delta)` を呼ぶ
    - 検証コマンド: `make test TESTS=res://tests/player`

- [ ] 7. 仮ステージ
  - [x] 7.1 `dev_stage.tscn` を新規作成し、床・段差 3 段・壁 2 を `StaticBody2D` と `CollisionShape2D` で構成する
    _Requirements: 9.1, 9.2, 9.4, 9.5, 9.6_
    _Boundary: DevStage_
    _Depends: 1.3_
    - 対象ファイル: `src/stage/dev_stage.tscn`(新規), `src/stage/dev_stage.gd`(新規), `tests/stage/dev_stage_test.gd`(新規)
    - 仕様参照: spec.md §5.7、§6.5、§7 Requirement 9
    - 実装の要点(タスク固有):
      - 段差は `Step1`・`Step2`・`Step3` と名付け、9.2 は隣り合う段の `global_position.y` の差の絶対値が 32.0 以下であることで検証する
      - 9.4 は、読み込んだシーンの全ノードに `TileMapLayer` が無いこと(再帰探索)で検証する
      - 9.5 は各 `StaticBody2D` の `collision_layer` が 1、`Player` の `collision_layer` が 2 であることをアサーションする
      - 9.6 は `project.godot` の `run/main_scene` が `res://main.tscn` のままであることで検証する
    - 検証コマンド: `make test TESTS=res://tests/stage`、`grep -c 'TileMapLayer' src/stage/dev_stage.tscn`(0 であること)、`grep -q 'run/main_scene="res://main.tscn"' project.godot && echo OK`
  - [x] 7.2 `DamageZone` を実装し、触れている間 1 秒に 1 回ダメージを与える
    _Requirements: 9.3_
    _Boundary: DamageZone_
    _Depends: 6.3, 7.1_
    - 対象ファイル: `src/stage/damage_zone.gd`(新規), `src/stage/damage_zone.tscn`(新規), `src/stage/dev_stage.tscn`(変更), `tests/stage/damage_zone_test.gd`(新規)
    - 仕様参照: spec.md §5.8、§6.5「`DamageZone`: layer は使わず、mask は 2」
    - 実装の要点(タスク固有):
      - 接触した瞬間に 1 回目を与え、以後 1 秒ごとに与える(File Structure Plan の申し送りを参照)
      - **テストでは `Player` を接地させる**。`Player._physics_process` は毎フレーム重力を加えるため、床が無いと 1.5 秒で約 675px 落下して領域から抜け、実装が正しくても 2 回目のダメージが入らない。`StaticBody2D`(`collision_layer` = 1)の床を領域の内側に置き、その上に `Player` を立たせる
      - テストは `Player` と `DamageZone` を重ねてツリーへ載せ、`await await_millis(1500)` の後に体力が `damage` の 2 回分だけ減っていることで検証する(周期の境界 0.0 秒と 1.0 秒の中間で判定し、次の 2.0 秒との間に 0.5 秒の余裕を取る)。`regen_delay` は 3.0 秒であり、この待ちの間に自動回復は始まらない
    - 検証コマンド: `make test TESTS=res://tests/stage`
  - [x] 7.3 `player.died` を `DevStage` の再読込の処理へ接続する。再開位置を切り替える状態を持たない
    _Requirements: 7.1, 7.3_
    _Boundary: DevStage_
    _Depends: 7.2_
    - 対象ファイル: `src/stage/dev_stage.gd`(変更), `src/stage/dev_stage.tscn`(変更), `tests/stage/dev_stage_test.gd`(変更)
    - 仕様参照: spec.md §5.7、§7 Requirement 7
    - 実装の要点: 7.1 はシーンを読み込んで `player.get_signal_connection_list("died")` の件数と接続先が `DevStage` であることで検証する(`reload_current_scene()` 自体はここでは呼ばせない)。7.3 の主たる確認は、読み込んだ `DevStage` が再開位置を保持する変数・子ノードを持たないこと(`get_property_list()` と子ノードの走査)をテストで示すことである。下の grep は補助であり、英語 3 語に当たらない命名を見落とすため単独の根拠にしない
    - 検証コマンド: `make test TESTS=res://tests/stage`、`grep -niE 'checkpoint|respawn|spawn_point' src/stage/dev_stage.gd src/stage/dev_stage.tscn > /tmp/retry.txt; test ! -s /tmp/retry.txt && echo OK`(補助)
  - [x] 7.4 リトライを実行時に目視で確認する(自動テストでは検証しない)
    _Requirements: 7.2_
    _Boundary: DevStage_
    _Depends: 7.3_
    - 対象ファイル: なし(既存の `src/stage/dev_stage.tscn` の実行時確認)
    - 仕様参照: spec.md §7 Requirement 7.2(自動テストにしない理由を含む)
    - 実装の要点: ダメージ領域に留まって体力を 0 にし、プレイヤーの位置が初期位置へ戻り体力が `max_health` に戻ることを確認する。確認できた事実は `## Implementation Notes` に記録する。この 1 件だけが人手の確認であり、`make test` には現れない
    - 検証コマンド: `godot res://src/stage/dev_stage.tscn`(目視。headless では確認できない)

- [ ] 8. 敵の設計の上限・数値の集約・文書の更新
  - [x] 8.1 (P) `CombatLimits` を新規作成し、敵弾の弾速の上限と予備動作の下限を定数として定義する
    _Requirements: 10.4_
    _Boundary: CombatLimits_
    - 対象ファイル: `src/weapon/combat_limits.gd`(新規), `tests/weapon/combat_limits_test.gd`(新規)
    - 仕様参照: spec.md §6.2
    - 実装の要点: 値は `foot-enemies`(unit #3)が参照する上限であり、本単位のコードからは使われない。テストは定数の値そのものを固定する
    - 検証コマンド: `make test TESTS=res://tests/weapon`
  - [x] 8.2 `PlayerStats` の値が実装のコードへ直書きされていないことを確認し、見つかったものを `stats` 経由の参照へ置き換える
    _Requirements: 10.2_
    _Boundary: PlayerStats_
    _Depends: 5.3, 6.3, 7.3_
    - 対象ファイル: `src/player/player.gd`(変更), `src/weapon/primary_weapon.gd`(必要に応じて変更), `src/weapon/secondary_weapon.gd`(必要に応じて変更), `src/weapon/projectile.gd`(必要に応じて変更)
    - 仕様参照: spec.md §6.1、§7 Requirement 10.2
    - 実装の要点(タスク固有):
      - 本サブタスクの境界は「数値の集約」という横断的な関心であり、対象は `src/` 配下の実装コード全体に及ぶ。`PrimaryWeapon`・`SecondaryWeapon`・`Projectile` は値を引数で受け取る設計であり、直書きが残っていれば設計違反である
      - 機械検査の対象は `PlayerStats` の既定値のうち**小数の 11 項目(重複する 400.0 を除いて 10 種のリテラル)**とする。整数の 3 個(`max_health` = 100、`primary_damage` = 10、`secondary_damage` = 50)は無関係な整数と衝突して誤検出が多いため grep から外し、要件 3.3・4.7・6.x のテスト(値が `stats` 経由で流れることを検証する)で担保する
      - 無関係な小数リテラルが偶然一致した場合は、その旨と根拠を `## Implementation Notes` に記録してから除外する(判定を黙って緩めない)
    - 検証コマンド: `grep -rnE '(^|[^0-9.])(100\.0|600\.0|240\.0|3\.0|20\.0|0\.12|400\.0|0\.8|2\.0|300\.0)([^0-9]|$)' --include='*.gd' src > /tmp/hardcoded.txt; grep -v '^src/player/player_stats.gd:' /tmp/hardcoded.txt > /tmp/hardcoded2.txt; test ! -s /tmp/hardcoded2.txt && echo OK || cat /tmp/hardcoded2.txt`
  - [x] 8.3 `docs/testing.md` に `tests/harness/` の位置づけと仮ステージの起動方法を追記する
    _Requirements: 9.7, 11.1, 11.2, 11.3_
    _Boundary: Docs_
    _Depends: 7.4_
    - 対象ファイル: `docs/testing.md`(変更)
    - 仕様参照: spec.md §6.6「本単位が更新する文書」、§7 Requirement 9.7・11
    - 実装の要点: `tests/harness/` が「実装のディレクトリ構成を写す」規約の例外であることと理由、サンプルが基盤自体の動作を示すもので実装に対応しないこと、仮ステージの起動方法(`godot res://src/stage/dev_stage.tscn`)の 3 点を書く。11.3 は既存のサンプル 2 本を削除・移動しないことの確認である
    - 検証コマンド: `grep -q 'tests/harness' docs/testing.md && grep -q 'res://src/stage/dev_stage.tscn' docs/testing.md && echo OK`、`test -f tests/harness/logic_test.gd && test -f tests/harness/scene_test.gd && echo OK`、`make test > /tmp/alltests.txt 2>&1; rc=$?; grep -E 'skipped|orphans' /tmp/alltests.txt; test $rc -eq 0 && echo OK`(本単位の最後のサブタスクとして全テストを通しで実行し、統計行の `skipped` と `orphans` が 0 であることを確かめる。unit #1 の学習により、判定は `tee` を挟まずファイルへリダイレクトしてから `grep` する)

## Implementation Notes

(このセクションは dev-implement が実装中の学習・選択した知識 port・横断的な気付き・レビューを通過した境界外変更の申告を追記する領域)

- 知識 port: `docs/dev/ports` が存在しないため、注入なしで進める(`ports.py --skill dev-implement` が「port ルートが存在しない」を返す)。
- **`@export` の有無はテストから検証できる**(タスク 1.1)。`get_property_list()` の `usage` に `PROPERTY_USAGE_EDITOR` ビットが立つ。実測で `@export var` は usage=4102、素の `var` は usage=4096 であり、`@export` を外すとテストが落ちる。
- **新規スクリプトを足すと Godot が `.gd.uid` を生成する**(タスク 1.1)。`.gitignore` の対象外で追跡されるため、スクリプトと `.uid` を対にしてステージする。
- **テストスイートは `GdUnitTestSuite`(`Node` 派生)**(タスク 1.1)。ループ変数に `name` を使うと組み込みプロパティを隠すため、別名にする。
- **`class_name` を足した直後は `.godot/global_script_class_cache.cfg` が古い**(タスク 1.2)。`godot --headless --path . --import` を先に走らせないと `--script` 実行で「Identifier not declared」になる。`make test` は毎回インポートするためこの問題を踏まない。
- **衝突レイヤ名を `project.godot` に定義済み**(タスク 1.2): `2d_physics/layer_1..5` = `terrain` / `player` / `player_projectile` / `enemy` / `enemy_projectile`。
- **入力は `physical_keycode` で登録した**(タスク 1.2)。キーボードレイアウトに依存させないため。`InputEventKey.new()` の既定 `device` は 16 なので、エディタ生成物に合わせて -1 を明示する必要がある。
- **`Input.is_action_just_pressed()` は物理フレームと描画フレームで別々に判定される**(タスク 1.2)。`PlayerInput.read()` は `_physics_process` からのみ呼ぶこと。`_process` からも呼ぶと `jump_pressed` の取りこぼしが起きる。
- **spec §3 の未検証の前提「`Callable` の差し替えによる入力の注入が Godot 4.7.1 の headless で機能する」は成立した**(タスク 1.3、gdUnit4 のテストツリー上で実測)。`var input_source: Callable = PlayerInput.read` を宣言でき、`get_object()` は `PlayerInput` の GDScript リソースを返す。注入した `Callable` の呼び出し回数 30・最終位置 5.0px(期待値 `move_speed / physics_ticks_per_second * 3` と一致)。要件 8 と検証方法の組み替えは不要。
- **注入用スタブは `GDScript.new()` + `source_code` で作る**(タスク 1.3、`tests/harness/scene_test.gd` と同じ形)。lambda はローカル変数を値コピーで捕捉するため呼び出し回数を観測できない。状態(`call_count` / `move_frames`)を持つ `RefCounted` のメソッドを渡し、**規定回数を超えたら既定値の `PlayerCommand` を返す**ようにする(`await await_millis(500)` では約 30 物理フレームが進むため)。動的スクリプトからグローバルな `class_name` は解決できる。
- **`Player` に `frames_to_move` 相当の停止機構は無い**(タスク 1.3、spec §5.1 の責務に無いため)。物理フレームを使う後続テストは注入側で入力を止めること。
- **`player.tscn` のノード名**(タスク 1.3): `Placeholder`(`ColorRect`)と `CollisionShape2D`。テストがこの名前で参照している。`stats` は埋め込みサブリソースで、`resource_local_to_scene` を付けていないため複数インスタンス化すると共有される。
- **`facing` の算出は `signi()` ではなく `int(signf())` を使った**(タスク 2.1)。spec §7 1.6 は `signi(move_x)` と書くが、`signi()` は int を取るため float を渡すと切り捨てが挟まり、実測で `signi(0.5) = 0`・`signi(0.9) = 0` となって §5.1 の不変条件(`facing` は -1 または 1)を破る。§5.2 の事後条件が保証する定義域 {-1.0, 0.0, 1.0} では両者は完全に一致するため、契約内の振る舞いに差はない。ゼロ判定も `is_zero_approx()` を使う。
- **`delta <= 0.0` の早期 return を足すとき(タスク 2.3)は、水平・垂直の両方を変えずに返る必要がある**(タスク 2.1・2.2 の申し送り)。現在の実装は `velocity.x` の代入が `apply_command()` の先頭にあるため、ガードは関数の最初に置く(`facing` の更新もガードより後ろになる)。
- **境界外変更(タスク 2.2、レビュー通過)**: `tests/player/player_scene_test.gd` の統合テストから `y == 0` のアサーションを外した。重力(要件 1.3)を足すと足場の無いノードは落下するため、要件 1.9 が定めない垂直の固定と両立しない。水平の期待値の算出・許容差 0.001・消化フレーム数のアサーションはそのまま維持し、代わりに `position.y > 0`(落下していること)を足した。
- **`await assert_error(...).is_push_error(...)` は文言の完全一致で照合する**(タスク 2.3。`GdUnitGodotErrorAssertImpl._has_log_entry` が `GdObjects.equals` を使う)。`%s` の float は `0.0` / `-250.0`、int は `0` と描画される。**`await` を必ず付けること。** `assert_error(...).is_success()` は「callable の実行中に一切のエラーが無い」ことを見る。`add_child()` は同期で `_ready()` まで走り物理フレームは進まないため、足場の無い `Player` でも安定する。
- **`Player._ready()` が 2 つの検査を持つ**(タスク 2.3): `stats` 未設定 → `push_error` + `PlayerStats.new()` へフォールバック、`stats` の数値項目に 0 以下 → 項目名と現在値を添えて `push_error`。検査対象は `get_property_list()` を `PROPERTY_USAGE_SCRIPT_VARIABLE & PROPERTY_USAGE_EDITOR` と `TYPE_FLOAT / TYPE_INT` で絞って導出している。**`PlayerStats` に「0 を許す数値項目」や `@export_storage` の項目を足すとこの検査が誤検出・見落としをする。**
- **`apply_command()` の先頭に `delta <= 0.0` のガードがある**(タスク 2.3)。後続タスクが処理を足すときは、ガードより後ろに置くこと。
- **分岐の条件に複合述語があるときは、フラグごとに到達可能な出力の表を厳密比較で回す**(タスク 3.1 のレビューで [Critical] 1 件。自己修復 1 回で解消)。`if is_on_floor and direction.y > 0:` の片側(下向き)だけを厳密比較しても、条件を `if is_on_floor:` へ広げる変異が素通りした(接地時の上撃ち・斜め上撃ちが未検証だった)。総当たりループが弱いアサーション(非 ZERO・範囲内)しか持たないと穴を塞げない。**後続の `PrimaryWeapon`・`SecondaryWeapon`・`Health` の状態分岐でも同じ穴が出やすい。**
- **事後条件は集合への所属で表せる**(タスク 3.1)。`assert_array(EIGHT_DIRECTIONS).contains([direction])` は「非 ZERO・範囲内」より厳密に強い。`contains` は期待値を配列で受け、`Array[Vector2i]` の const と併用できる。
- **gdUnit4 の統計の `failures` は失敗ケース数ではなく失敗アサーション数**(タスク 3.1)。ループ内で複数落ちると 1 ケースでも複数に数えられる。
- **`Projectile` に `frames_moved: int` を公開した(spec §5.6 に無い契約の追加。レビュー通過)**(タスク 4.1)。`Player.input_source` と同じ「テストのための公開点」である。`Engine.get_physics_frames()` の差分や `await physics_frame` の待機回数では、ツリーへの追加時刻とフレーム境界の関係で 1 フレームずれるため(実測: awaited=10 に対し node_frames=9 になる回がある)、「待ちが足りずに進まなかった」と「進まないことが正しい」を区別できない。`tests/harness/scene_test.gd` の `frames_to_move` と同じ形。**`foot-enemies`(unit #3)以降が `Projectile` を再利用するときは、この公開点も契約の一部として扱うこと。**
- **`projectile.tscn` の placeholder と衝突矩形は 4×4px、原点は矩形の中心**(タスク 4.1。spec が定めていない決定)。根拠: タイル 16px の 1/4、`Player` 12×32px と同じ「偶数寸法・原点は矩形中心」の流儀、`snap_2d_transforms_to_pixel = true` の下で中心合わせのオフセット(±2)を整数に保つため。**弾の当たり判定の寸法はタスク 4.2 の地形衝突と unit #3 の被弾判定に効く。**
- **衝突ビットの換算**(タスク 4.1、Godot 4.7.1 で実測確認): レイヤ番号は 1 始まり、`collision_layer`/`collision_mask` は 0 始まりのビットマスク。layer 3 → `1 << 2` = 4。mask 1 と 4 → `(1 << 0) | (1 << 3)` = 9。
- **`launch()` の第 3 引数はメンバ `damage` と同名**(spec §5.6 のシグネチャどおり)。`@warning_ignore("shadowed_variable")` + `self.damage = damage` で解決している。
- **異常系のテストは、実装の定数・文言をテストから参照しない**(タスク 3.1・3.2)。エラー文言と退避先の値はテスト側に二重に持つ。実装の定数を参照するとアサーションが自明化し、文言の退行を検出できない(実測: 文言だけを書き換える変異でテスト 6 件が落ちる形になっている)。
- **事前条件のガードは関数の先頭に置く**(タスク 3.2)。「入力の有無で分岐する」ドリフトとの差がテストで観測できる。この差を縛るには、異常な引数を入力の総当たりと組み合わせて厳密比較する表が要る。
- **`assert_error(...)` はループの中でも `await` ごとに独立して評価できる**(タスク 3.2)。1 テストケース内で異常値を回して複数回 `await ...is_push_error(...)` する形が使える(引数を取るテストケースを書かない規約と両立する)。正常系に `is_success()` を置くと、ガードが広がりすぎる変異(条件の反転・範囲の拡大)を検出できる。
- **`assert_vector()` は `Vector2i` に対応する**(タスク 3.1)。`append_failure_message()` は `GdUnitVectorAssert` / `GdUnitArrayAssert` / `GdUnitIntAssert` のいずれも自身の型を返すため、型注釈付きのチェーンが書ける。ループ内のアサーションに入力の組を添えると失敗時に特定できる。
- **`Player` のツリー上のテストは足場を持たないため毎回落下する**(タスク 2.2)。垂直方向の値を固定したい後続テストは、仮の足場(`StaticBody2D`・layer 1)を置くか、消化フレーム数から算出すること。
- **`is_on_floor` は `apply_command()` の引数であり、基底 `CharacterBody2D.is_on_floor()` をシャドウする**(タスク 2.2)。メソッド側を呼ぶとツリー外のテストで常に非接地になる。メソッドの呼び出しは `_physics_process` の 1 箇所だけに保つこと。
- **`Area2D` の重なりの通知は 1 物理フレーム遅れる**(タスク 4.2、実測)。矩形の縁が重なった位置 10.0 に対し、`body_entered` による解放は 15.0(5 フレーム目)で起きる。最初に重なるのは 4 フレーム目であり、遅れはちょうど 1 フレーム。接触位置を検証するテストは「重なりに届くまでに最大 1 フレーム + 通知の遅れ 1 フレーム」= 2 フレーム分を上限に取ること。**接触位置を 1 フレーム幅で挟むと実装が正しくても落ちる。**
- **射程の基準は `launch()` を呼んだ時点の位置**(タスク 4.2)。`launch()` の doc コメントに事前条件として明記した。**発射位置を決めてから `launch()` を呼ぶこと。** 生成 → `add_child` → `launch()` → 位置設定 の順に書くと、移動分が射程から差し引かれて要件 5.3 が沈黙のうちに壊れる(タスク 5.3 の `Player` からの生成で踏みやすい)。
- **距離を検証するテストは斜めを軸方向と別のケースにする**(タスク 4.2 のレビューで [Critical] 1 件)。`position.distance_to(_launch_position)` を `absf(position.x - _launch_position.x)` へ置き換える変異が、軸方向(`Vector2i(1, 0)`)のケースだけでは 13/13 素通りした(斜めでは射程が √2 倍になる = 要件 5.3 違反)。斜めのケースを 1 件足して変異が落ちることを実測で確認済み。**8 方向が中核の本単位では、距離・速さ・射程を検証するテストに斜めのケースを必ず含めること。**
- **`Projectile` は mask に載るすべての body で解放される**(タスク 4.2)。`_on_body_entered` は body の種別を見ない。`projectile.tscn` の mask は 1(地形)と 4(敵)であり、spec §5.6 は地形しか書いていないが、敵に当たった弾も解放される。**`foot-enemies`(unit #3)が被弾処理を足すときは、この解放が既にあることを前提にすること**(二重に `queue_free()` しない)。
- **拒否時に「状態を変えていない」ことをアサーションに含める**(タスク 4.3)。`launch()` の異常系で `damage` が 0 のままであることを検証すると、「ガードを関数の先頭に置く」規律が変異で観測できる(ガードを代入の後ろへ移す変異が落ちる)。**異常値の表に負値を含めること**: 0 だけだと代入が起きても既定値の 0 と区別できず素通りする。後続の `PrimaryWeapon`・`SecondaryWeapon`・`Health` の異常系でも同じ形を採ること。
- **`launch()` は複数の引数が同時に異常でも、最初に検出した 1 件だけを `push_error` して返る**(タスク 4.3)。spec §5.6 は評価の順序を定めておらず、順序を契約として固定しないためテストを置いていない(レビューの [Nit] を意図的に見送り)。**タスク 5.3 で `Player` が複数の異常値を渡すと 1 件しかエラーが出ない。**
- **時間を扱うテストの定数は 2 進で厳密に表せる値にする**(タスク 5.1)。`interval = 0.25`・`delta = 0.0625`・境界のすぐ内側 `0.2490234375`(= `0.25 - 2^-10`)。累積の丸め誤差が出ないため「発射するフレーム番号の厳密な表」(`[1, 5, 9, 13]`)が書け、これが「余りを繰り越す」変異を単独で捕らえる。0.1・0.05 では `>=` の境界ケースが再現せずフレークする。**`SecondaryWeapon`・`Health` の時間を扱うテストでも同じ形を採ること。**
- **事後条件を揺らぎのある delta で検証するときは、テスト側の累計も実装と同じ順序で足す**(タスク 5.1)。全体の累計の差分を取ると最下位ビットの差で `>= interval` が偽になりフレークする。上限(`interval + 最大 delta`)も併せて見ると、待ちを長くする変異が捕まる。
- **`_init()` の引数が実際に使われていることは、長短 2 つのインスタンスを同じ入力で比較して検証する**(タスク 5.1)。値の直書き変異はこの 1 ケースでしか落ちない。タスク 8.2(数値の集約)の検査対象でもある。
- **`PrimaryWeapon._init()` は引数を検査しない**(タスク 5.1、レビュー通過)。spec §5.4 は他の型(§5.3・§5.6・§6.4)と違い事前条件を定めておらず、`interval` の 0 以下の検査は `Player._ready()` にある。`Projectile.launch()`(ガードあり)との非対称はこの差に由来する。**`foot-enemies`(unit #3)が `Player` 以外から `PrimaryWeapon` を生成すると、この検査は効かない。**
- **`tick()` に `delta <= 0.0` のガードは置いていない**(タスク 5.1、レビュー通過)。spec §5.1 が `Player.apply_command()` のエラーとして定めた事項であり、§5.4 には無い。唯一の呼び出し側 `Player.apply_command()` が関数先頭で弾くため非正の delta は届かない。
- **要件 ID をコードコメントへ書かない**(タスク 5.1 でオーケストレーターが 1 件是正)。dev-implement 13.(中間生成物の ID を残さない)に反する。テストコメントで「なぜ上限も見るか」を述べる際に要件番号を引きたくなるが、意図は番号ではなく振る舞いの言葉で書くこと。
- **spec が定めていない決定(タスク 5.2、レビュー通過): クールダウンが明けたフレームでは充電を始めない。** `update()` はクールダウンの処理の後に `return false` する。同じ delta を冷却と充電の両方へ数えると、発射から次の発射までが `cooldown + charge_time` より短くなるため。§5.5 は 1 フレーム内での delta の按分順序を定めておらず、契約から一意に決まらない実装の選択である。**タスク 5.3 で `Player` が毎フレーム `update()` を呼ぶとき、発射の周期は「充電 + 1 フレーム(離す)+ クールダウン + 1 フレーム」になる**(押しっぱなしでクールダウンを跨ぐと 1 フレーム分の充電が失われる)。
- **`SecondaryWeapon` は「離したフレーム」を状態変数で覚えない**(タスク 5.2)。`charge_ratio > 0` が「押していた」ことを表すため、`held == false` の分岐だけで要件 4.3・4.4 の両側が成り立つ。状態変数を増やさないほうが、到達可能な状態 4 × `held` 2 = 8 行の表が閉じる。
- **到達可能な状態 × 入力の表は `[戻り値, 状態変数...]` の混在型 `Array` を 1 回の `assert_array(...).is_equal()` で厳密比較する**(タスク 5.2)。gdUnit4 の `assert_array` は混在型でも要素ごとに比較でき、`append_failure_message` で行を特定できる。**タスク 6 系(`Health`)の状態分岐でも同じ形を採ること。**
- **しきい値の変異を塞ぐには、境界のすぐ内側の値の「比」を 1.0 に十分近づける必要がある**(タスク 5.2 のレビューで [Nit] 1 件、是正済み)。`charge_time - 2^-10` は比が 0.996 にしかならず、完了判定を `< 0.999` へ緩める変異を素通りさせた。`charge_time - 2^-20`(比 `1 - 2^-18`、2 進で厳密)を足して塞いだ。**「境界のすぐ内側」は絶対値ではなく比で考えること。**
- **`charge_time` が 0 だと `delta / 0.0` が `INF` になり `minf` で 1.0 に丸まる**(タスク 5.2、Godot 4.7.1 headless で実測)。エラーにも NaN にもならず「1 フレームで満充電」に退化する(負値なら `charge_ratio` が負のまま一生発射しない)。`Player._ready()` の検査は `push_error` を出すだけで値を補正しないため、0 の `stats` が実行時に届くと沈黙して常時即発射になる。**タスク 8.2 の観測点。**
- **テストは既定値のままの `stats` に頼らない**(タスク 1.3 のレビュー指摘)。`move_speed` を既定の 100.0 のままで検証すると、実装が `stats` を読まず 100.0 を直書きしても緑になる。`PlayerStats.new()` に既定と異なる値(例: 250.0)を入れて `player.stats` へ差し替えてから検証すると、要件 10.2(値の出どころの一本化)の退行も捕捉できる。後続の `Player` 系タスク(2.1〜2.3・5.3・6.3)はこの形を採ること。
- **「既定値と別の値を入れる」だけでは足りない。判定に使う入力がしきい値を跨ぐ必要がある**(タスク 5.3 のレビューで [Critical] 1 件。再投入 1 回で解消)。主武器の間隔を既定 0.12 に対して 0.25 で検証していたが、「間隔未満」に使う delta が 0.0625 で、既定値と設定値の**両方に対して同じ側**にあったため、`PrimaryWeapon.new(0.12)`(既定値の直書き)への変異が `tests/player` 全 71 ケースを素通りした。既定と設定値の間にある 2 進で厳密な値(0.1875 = 3/16)を「未満側」に置き、「ちょうど」の側(0.1875 + 0.0625 = 0.25)も固定して塞いだ。**タスク 6.3(`regen_delay`・`regen_per_second`)でも同じ穴が出る。**
- **「その値を使う経路をテストが 1 度も踏んでいない」穴は、別値の設定だけでは見えない**(タスク 5.3)。`secondary_cooldown` は `Player` からクールダウンを踏むテストが 1 件も無く、既定値の直書きが素通りしていた。`stats` の各項目について「その項目が結果を変えるケースが存在するか」を数えること。
- **spec が定めていない決定(タスク 5.3、レビュー通過): `projectile_scene` が未設定なら `push_error` を出して弾を生成せず `fired` も発火しない。** `stats` 未設定の扱いと違い意味のある代替値を持てないため、フォールバックしない。
- **`Player` の武器は `_ready()` ではなく初回の `apply_command()` で遅延生成する**(タスク 5.3、レビュー通過)。`apply_command()` はツリーへ載せずに呼べる契約であり(既存 `player_move_test.gd` がそう呼ぶ)、`_ready()` で作ると `_ready()` を通らない経路で null になる。**この結果、最初の `apply_command()` より後に `stats` を差し替えても `primary_interval`・`secondary_charge_time`・`secondary_cooldown` は古い値のまま残る**(`damage`・`speed`・`bullet_max_distance` は毎発 `stats` から読むため追従する)。タスク 6.3 の `Health` は `_ready()` 生成と定められており、`Player` の中で生成時期が非対称になる。実行時に `stats` を差し替える機能が要るなら、差し替え時に武器を作り直す口を別途足すこと。
- **`AimResolver.resolve()` は `facing` を x・y の両成分が 0 のときだけ使う**(タスク 5.3、実測で等価変異)。`move_x != 0` のフレームでは `facing` の更新と方向の決定の順序が振る舞いを変えない。**順序に依存する根拠をコメントへ書かないこと**(書くと成立しない Why not がコードに残る)。
- **gdUnit4 v6.2 の `assert_signal(...).is_not_emitted(name)` は引数まで一致したときだけ「発火した」と見なす**(タスク 5.3)。引数を省くと「引数なしの発火」としか照合されず、2 引数のシグナルでは常に成立する。非発火の検証は期待引数を添えるか、`fired.connect()` で発火列を控えて厳密比較すること。`monitor_signals(node, false)` は発火の**前**に呼ぶ(第 2 引数を `false` にしないと二重 `auto_free` になる)。
- **物理フレームで「射程の内側」を確かめるテストは、待ちの間の移動距離に対して射程を数倍取る**(タスク 5.3 のレビューで [Nit] 1 件、是正済み)。倍率が 2 倍程度だとランナーの遅延で実装が正しくても落ちる。
- **`Player` の発射の周期を検証するテストは、ツリーへ載せる前に `apply_command()` を直接呼ぶ**(タスク 5.3)。ツリーへ載せると `_physics_process` が毎フレーム武器を更新して間隔・充電の状態が動く。物理フレームが要る検証(方向・速さ・射程)は「先に全弾を発射 → 容器をツリーへ載せる → 1 回だけ待つ」順にすると、待ちが 1 回で済み発射位置も揃う。
- **`Health` の待機時間の判定は delta を足す**前**に行う**(タスク 6.1)。`tick()` は `_elapsed_since_damage < _regen_delay` が真なら加算して即 return するため、待機を消化したフレームは回復に使わない。同じ delta を待機と回復の両方へ数えると、被弾から回復の開始までが `regen_delay` より短くなる。§6.4 は 1 フレーム内での delta の按分順序を定めておらず、`SecondaryWeapon`(タスク 5.2)の「クールダウンが明けたフレームでは充電を始めない」と同じ形の選択である。**この結果、被弾から最初の回復までは `regen_delay` + 1 フレームかかる。**
- **回復の端数は被弾でゼロに戻す**(タスク 6.1)。`take_damage()` が `_regen_remainder = 0.0` を行う。持ち越すと被弾のたびに回復の 1 点目が早まる。§6.4 は端数の蓄積しか定めておらず、被弾時の扱いは契約から一意に決まらない。
- **`Health._init()` は引数を検査しない**(タスク 6.1)。§6.4 が事前条件を定めるのは `take_damage()` だけであり、`max_value`・`regen_delay`・`regen_per_second` の 0 以下の検査は `Player._ready()` にある(`PrimaryWeapon` と同じ非対称。タスク 5.1 の申し送りを参照)。**`Player` 以外から `Health` を生成するとこの検査は効かない。**
- **`is_depleted` と `depleted` はタスク 6.1 では宣言だけで、書き込みも発火もしない**(要件 6.6・6.8 はタスク 6.2 の範囲)。到達可能な状態 × delta の表(`TICK_TABLE`)は現時点で `is_depleted` を全行 false に固定しているため、**6.2 で枯渇状態を足すときは表に枯渇の行を足すこと**(足さないと凍結の分岐が表の外に出る)。
- **タスク 6.2 は `test_take_damage_never_raises_the_current_above_the_maximum` を書き換えること**(タスク 6.1 の申し送り)。このテストは `take_damage(-20)` で `clampi` の上限側を踏んでいるが、6.2 が「`amount` が 0 以下なら `push_error` して状態を変えない」ガードを関数の先頭に置くと上限側が到達不能になる。`current` は `MAX_VALUE` のままなので**テストは緑のまま素通りし、検証対象が消えたことに気付けない**。6.2 では異常系のテストへ作り替え、上限の強制は `tick()` 側(`test_regen_stops_at_the_maximum`)が担う形にする。
- **`Health` のテスト定数は `PlayerStats` の既定値とすべて別にした**(タスク 6.1)。`max_value=40` / `regen_delay=0.5` / `regen_per_second=8.0`(既定は 100 / 3.0 / 20.0)。`_init()` の 3 引数それぞれについて、既定と異なる値を入れた対のインスタンスを同じ入力で比較するテストを 1 件ずつ置いてある(値の直書き変異はこの形でしか落ちない。タスク 5.1 の申し送り)。
- **変異で検証した**(タスク 6.1、`tests/player/health_test.gd` 16 ケースに対して実測): 上限の `mini()` を外す → 4 件失敗、被弾時の端数リセットを外す → 1 件失敗、待機を消化したフレームでも回復する → 17 件失敗、しきい値を `regen_delay * 0.999` へ緩める → 2 件失敗。しきい値の変異が落ちるのは「境界のすぐ内側」を比 `1 - 2^-19`(`0.49999904632568359375`)で取っているため(タスク 5.2 の申し送りの形)。
- **`depleted` の発火回数は `Array` へ控えて数える**(タスク 6.2)。gdUnit4 の `assert_signal` は `Object` を要求し `Health`(`RefCounted`)には使えない。lambda のローカル変数は値コピーで捕捉されるが(タスク 1.3 の申し送り)、`Array` は参照として捕捉されるため `emissions.append(true)` は外側から読める。`assert_array(emissions).is_equal([true])` で「ちょうど 1 回」を厳密比較する。
- **`take_damage()` の引数の検査は枯渇の判定より前に置く**(タスク 6.2、spec が定めていない決定)。§6.4 は評価順序を定めていないが、枯渇後でも呼び出し側の誤り(0 以下の `amount`)は知らせるべきだと判断した。**枯渇済みの `Health` へ 0 を渡すと `push_error` が出る。**
- **異常系のテストは「体力が変わらない」だけでは足りず「待機の計測が戻らない」ことも見る**(タスク 6.2)。`amount = 0` は引いても体力が変わらないため、`current` だけを見るとガードを外す変異が素通りする。被弾 → `NEARLY_REGEN_DELAY` まで待つ → 拒否 → 残り 1 フレーム分の `tick()` で回復が始まる、という並びで計測の連続性を固定した。
- **変異で検証した**(タスク 6.2、`tests/player` 93 ケースに対して実測): `tick()` の枯渇ガードを外す → 1 件失敗、`amount <= 0` のガードを外す → 6 件失敗、`take_damage()` の枯渇ガードを外す → 1 件失敗。**枯渇ガードの 2 件はいずれも 1 件でしか落ちない**(`test_a_depleted_health_does_not_change_state` と `TICK_TABLE` の `DEPLETED` 行)。タスク 6.3 で `Player` 側へ処理を足すとき、この 2 本を壊さないこと。
- **`health` は `_ready()` と、`apply_command()`・`take_damage()` の両方から `_ensure_health()` で作る**(タスク 6.3、spec が定めていない決定)。タスク 6.3 は `_ready()` 生成と定めるが、`apply_command()` はツリーへ載せずに呼べる契約であり(既存 `tests/player/player_move_test.gd` がそう呼ぶ)、`_ready()` だけで作ると `health` が null になって `health.tick(delta)` が落ちる。null ガードで読み飛ばす案は採らなかった: `take_damage()` が黙って無視され、`Player` の体力が「ツリーに載せたかどうか」で変わるため。武器の遅延生成(タスク 5.3)と同じ形に揃え、`_ready()` からも呼んで「ツリーへ載せた直後に `health` がある」ことは保つ。**この結果、最初の `apply_command()`・`take_damage()` より後に `stats` を差し替えても `max_health`・`regen_delay`・`regen_per_second` は古い値のまま残る**(武器と同じ制約)。
- **`health.tick(delta)` は `delta <= 0.0` のガードより後ろに置く**(タスク 6.3)。前に置く変異は「体力が変わらない」だけを見るテストでは素通りする: 負の delta で `Health` の端数 `_regen_remainder` が負に汚れても、`floori(負) <= 0` で早期 return するため `current` が動かない。**拒否した delta の影響は「その後の正常な delta での回復量」で見ること**(タスク 6.2 の「待機の計測が戻らないことも見る」と同じ形)。
- **変異で検証した**(タスク 6.3、`tests/player` 105 ケースに対して実測): `Health.new()` へ既定値(100 / 3.0 / 20.0)を直書き → 11 件失敗、`health.tick(delta)` の呼び出しを削除 → 1 件失敗、`died.emit()` を削除 → 2 件失敗、`tick` を `delta` ガードより前へ移動 → 2 件失敗。しきい値の跨ぎは、待機を設定 0.5 / 既定 3.0 に対して経過 1.0 秒で判定し、回復量を設定 8.0 / 既定 20.0 に対して 8 フレーム(4 点 / 10 点)で判定して作った。
- **`Player.died` の発火回数も `Array` へ控えて数える**(タスク 6.3)。`Player` は `Object` なので `assert_signal` を使えるが、`is_not_emitted()` は引数まで一致したときだけ発火と見なす落とし穴があり(タスク 5.3 の申し送り)、「ちょうど 1 回」の厳密比較には `Array` のほうが素直である。`Health`(`RefCounted`)側と形も揃う。
- **`dev_stage.tscn` の座標(タスク 7.1、spec が定めていない決定)**: 基準解像度 320×180 の中へ収めた。床は `position = (160, 100)`・320×16px(上面 y=92)、段差は `Step1` (180, 76)・`Step2` (228, 52)・`Step3` (276, 28) の 48×16px で**隣り合う段の差は 24px**(上限 32px に対して余裕 8px)、壁は `WallLeft` (8, 38)・`WallRight` (312, 38) の 16×108px、`Player` は (48, 60) で床の上に落ちる。**タスク 7.2 の `DamageZone` は床の上面 y=92 より上、壁の内側(x は 16〜304)へ置くこと。**
- **地形にも placeholder の `ColorRect` を付けた**(タスク 7.1、spec §5.7 は `StaticBody2D` + `CollisionShape2D` しか書いていない)。タスク 7.4 の目視確認(プレイヤーの位置が初期位置へ戻ること)は、地形が見えないと成立しないため。`player.tscn` と同じ `Placeholder` という名前・原点中心のオフセットに揃えている。
- **`StaticBody2D` の `collision_mask` は既定(1)のままにした**(タスク 7.1)。spec §6.5 は地形の layer しか定めておらず、静的な地形は自分から何も検出しないため mask は振る舞いに効かない。**テストは `collision_layer` だけを固定している。**
- **シーンの構成を検証するテストはツリーへ載せない**(タスク 7.1)。`DEV_STAGE_SCENE.instantiate()` + `auto_free()` だけで `position`・`collision_layer`・子ノードの型を読める。`add_child()` すると `Player._ready()` と `_physics_process` が走って位置が変わるため、初期位置を検証するテストが壊れる。
- **`run/main_scene` の検証は `ProjectSettings.get_setting("application/run/main_scene")` で行う**(タスク 7.1)。tasks.md の検証コマンドは `project.godot` への `grep` だが、テストからは設定値そのものを読むほうが直接的である(grep は commit 前の補助として併走させている)。期待値 `res://main.tscn` はテスト側に定数として持ち、実装から参照しない。
- **`Callable` は `RefCounted` の所有者を強く参照しない**(タスク 7.2、実測)。`player.input_source = _make_idle_input().read` と書くとスタブが即座に解放され、`_physics_process` が `Attempt to call function 'null::read (Callable)' on a null instance` を毎フレーム出す(1 回の実行で 283 件)。**入力を差し替えるテストはスタブをスイートのメンバ(`Array`)に抱えること。** 既存の `tests/player/player_scene_test.gd` はローカル変数がテスト関数の実行中ずっと生きているため踏んでいない。
- **`DamageZone` はプレイヤーを型ではなくメソッドの有無で見る**(タスク 7.2、spec が定めていない決定)。`body.has_method(&"take_damage")` で弾き、`Player` へ静的に依存しない。mask が 2 なので実際に入るのはプレイヤーだけだが、`foot-enemies`(unit #3)がレイヤを増やしても壊れない。
- **周期の剰余は繰り越す**(タスク 7.2)。`while elapsed >= DAMAGE_INTERVAL` で減算するため、1 フレームが周期より長い環境でも与える回数が減らない。`body_exited` で `_elapsed` から取り除くので、出入りのたびに周期は接触からやり直しになる。
- **「領域の外」は真上に取らない**(タスク 7.2、テストが 1 度落ちた)。プレイヤーは足場が無いと落下するため、領域の真上へ置くと落下の途中で通り抜けて `body_entered` が発火する。**横へずらして床の上に立たせること**(実装は `OUTSIDE_POSITION = (80, -40)`、領域は x が -32〜32)。離脱の検証は逆に領域側を遠くへ動かしている。
- **`dev_stage.tscn` の `DamageZone` は `position = (112, 76)`**(タスク 7.2)。64×32px なので x が 80〜144、y が 60〜92 を覆い、床の上面(y=92)に接する。プレイヤーの開始位置 (48, 60) からは右へ歩くと入る。**タスク 7.4 の目視確認はこの位置に留まって体力を 0 にする。**
- **`died` の接続は `dev_stage.tscn` の `[connection]` で行い、`_ready()` では繋がない**(タスク 7.3、spec が定めていない決定)。シーンの宣言に置くと `instantiate()` した時点で接続が存在し、テストがツリーへ載せずに `get_signal_connection_list("died")` を読める。`_ready()` で繋ぐと `add_child()` が要り、`Player._physics_process` が走って初期位置を検証する別のテストと干渉する。
- **`DevStage` はスクリプト変数を 1 つも持たない**(タスク 7.3)。テストは `get_property_list()` の `PROPERTY_USAGE_SCRIPT_VARIABLE` が 0 件であることと、子ノードが地形 6・`DamageZone`・`Player` の許可リストに収まることの 2 つで再開位置の不在を示している。**`DevStage` に変数や子ノードを足すとこのテストが落ちる**(意図した追加なら許可リストを更新すること)。
- **`CombatLimits` の値は本単位のコードから参照しない**(タスク 8.1)。`foot-enemies`(unit #3)が超えてはならない上限であり、定数の値そのものをテストで固定している。加えて「上限の速さの弾が画面の半分(160px)を進む時間 > 回避に要する 0.46 秒」を 1 件置き、値を緩める変異を捕らえる。**`ENEMY_BULLET_MAX_SPEED` の値は `PlayerStats.move_speed`(100.0)に依存して算出されている**ため、移動速度を変えるならこの上限も再計算すること。
- **タスク 8.2 の機械検査は直書きを 1 件も検出しなかった**(小数 10 種の grep、`src` 全体、`player_stats.gd` を除外して 0 件)。置き換えた箇所は無い。除外した無関係な小数リテラルも無い。整数の 3 個(100 / 10 / 50)も別途 `src` 全体を grep し、`combat_limits.gd` の算出根拠のコメント中の「100 px/s」1 件だけで、実行されるコードには無いことを確認した。
- **`DamageZone.DAMAGE_INTERVAL = 1.0` と `damage = 15` は `PlayerStats` の値ではない**(タスク 8.2 の判定)。周期 1 秒は spec §5.8・要件 9.3 が `DamageZone` の契約として定めた値であり、ダメージ量は `DamageZone` 自身の `@export` である。`PlayerStats` にこれらに対応する項目は無いため、集約の対象外である(1.0 が検査対象の 10 種に含まれないのは偶然ではない)。
- **`src/stage/` の 2 本もタスク 8.2 の検査に掛かっている**(タスク 8.2)。tasks.md の「対象ファイル」は `src/player/` と `src/weapon/` しか挙げていないが、検証コマンドは `src` 全体を走査するため `dev_stage.gd`・`damage_zone.gd` も範囲に入る。どちらも `PlayerStats` の値を持たない。
- **grep は「値が `stats` から流れていること」を示さない**(タスク 8.2)。直書きが無いことの裏取りとして `player.gd` の 14 項目すべてが `stats.<項目名>` 経由で読まれていることを目視で確認した(`move_speed`・`gravity`・`jump_speed`・`max_health`・`regen_delay`・`regen_per_second`・`primary_interval`・`primary_damage`・`primary_bullet_speed`・`secondary_charge_time`・`secondary_cooldown`・`secondary_damage`・`secondary_bullet_speed`・`bullet_max_distance`)。実質の担保はタスク 5.3・6.3 の変異検証(既定値の直書きで 11 件失敗)にある。
- **`charge_time` が 0 のときの退化(タスク 5.2 の申し送り)は 8.2 では解消していない**。直書きの問題ではなく `Player._ready()` の検査が `push_error` を出すだけで値を補正しないことに由来する。要件 10.2 の範囲外であり、契約(§6.1 の不変条件は「0 以下が設定された場合は `push_error`」までしか定めない)も変えていない。**補正が要るなら spec の変更を伴う。**
- **リトライの目視確認は期待どおりに動作した**(タスク 7.4、2026-08-13 に人手で実施)。環境は Godot 4.7.1.stable.official(`Metal 4.0 - Forward+`、Apple M2、macOS)、起動は worktree のルートで `godot --path . res://src/stage/dev_stage.tscn`。右へ歩いて赤い半透明の矩形(`DamageZone`)へ入りそのまま留まると、体力が 0 になった時点でシーンが読み直され、プレイヤーが左端の初期位置へ戻って落下し直し、体力も `max_health` へ戻った(要件 7.2)。実行中に `push_error` などのエラー出力は出なかった。**この 1 件だけが `make test` に現れない確認であり、`DevStage` の再読込の経路を変えたら再実施が要る。**
- **`docs/testing.md` への追記は 2 箇所に分けた**(タスク 8.3)。仮ステージの起動は `## 実行` の末尾に `### 仮ステージを目視で確認する` として、`tests/harness/` の例外は `## 配置と命名` の末尾(サンプルの案内の直後)に `### tests/harness/ は配置の規約の例外` として置いた。規約そのものの記述(`<実装のディレクトリ構成を写したパス>`)は変えず、例外を後ろに足す形にしている。起動コマンドは実測に合わせて `godot --path <プロジェクトのルート> res://src/stage/dev_stage.tscn` と書き、**`--headless` では目視にならないこと**を明記した。
- **`tests/harness/` の 2 本は削除・移動しない**(タスク 8.3、要件 11.3)。`git status` で無変更を確認済み。文書側にも「削除・移動しない」「ここに実装対応のテストを足さない」「例外はこの 1 ディレクトリだけ」の 3 点を書いた。
- **`docs/specs/002-foot-player/tasks.md` の末尾に混入していたツールのマークアップ(`</content>` と `</invoke>` の 2 行)を削除した**(タスク 6.1)。commit `6e7ac9e` までに紛れ込んでいたもので、仕様・タスクの内容ではない。
- **`DamageZone` の再進入は「周期を引き継ぐ」形にした**(最終検証パネルの Minor 2 への対応)。修正前は `_on_body_exited` が経過時間を捨てていたため、1 秒に 3 回出入りすると 3 回ダメージが入った。要件 9.3 は「触れている**間**、1 秒に 1 回」であり、**再進入の扱いを spec は定めていない**。採った設計: 領域を出た body の経過時間を `_cooling` へ移し、外にいる間も周期だけは進める(ダメージは与えない)。周期が満ちる前に戻ってきたら残りを引き継ぎ、接触時の 1 回は与えない。周期が満ちたら忘れ、次の接触は初めてと同じ扱い(即座に 1 回)になる。理由は 2 つ:(1)出入りの反復で周期より速くダメージが入る抜け道を塞ぐ、(2)しばらく離れてから戻ったときは接触の手応え(即座の 1 回)を残す。**周期を凍結する案(外にいる間は時間を進めない)は採らなかった** — 10 秒離れて戻っても接触の 1 回が出ず、要件 9.3 の「1 秒に 1 回」より遅くなるため。回復側の挙動は変えていない(外ではダメージを与えないため、`body_exited` の後に `regen_delay` を経て回復が始まる 7.4 の目視確認と整合する)。
- **入力アクション 7 件の定義に回帰テストを置いた**(最終検証パネルの Minor 1 への対応、要件 8.1)。タスク 1.2 の検証は `grep` のワンライナーだけで、`make test` は 1 件消えても緑のままだった。`tests/player/player_input_test.gd` を新設し、`InputMap.has_action()` で 7 件を検査して欠落を全件報告する。変異(`project.godot` の `jump=` を改名)でこのテストだけが落ちることを確認済み。
