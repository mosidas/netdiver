# foot-player — 仕様

## 1. 目的と背景

netdiver の徒歩パートで、プレイヤーが操作する自機を作る。企画書 5.(プレイヤー)と 6.(武器)が定める操作・射撃・体力の振る舞いを、動作確認用の仮ステージの上で 1 往復動かせる状態にする。

本単位が定める数値と設計は、以降の単位の前提になる。敵の攻撃が満たすべき上限(企画書 5.)は本単位で定数として定め、`foot-enemies`(unit #3)が参照する。衝突レイヤの割り当ても本単位で確定させる。

グラフィックは placeholder(単色矩形)とする。ゲームロジックを先に完成させ、コアループが面白いかを早い段階で確認するためである。

## 2. スコープ

### 対象(やること)

- `CharacterBody2D` による左右移動・ジャンプ
- 8 方向の射撃方向の決定
- 主武器(連射・弾数無限)と副武器(チャージショット)
- 弾体(`Area2D`)と地形との衝突
- 体力・被弾・自動回復・体力 0 でのリトライ
- 入力アクションの定義と読み取り
- 動作確認用の仮ステージ(床・段差・壁・ダメージ領域)
- 上記の振る舞いを検証するテスト
- `docs/testing.md` の更新。`tests/harness/` が配置の規約の例外であることと、サンプルの位置づけを明記する(`docs/specs/001-test-harness/spec.md` §2 が本単位へ持ち越した判断)

### 対象外(やらないこと)

- 敵・敵弾 — 理由: `foot-enemies`(unit #3)の範囲。本単位は体力を減らす手段として仮ステージにダメージ領域を 1 つ置くだけにする
- 解析による能力取得(第 3 の武器枠) — 理由: `analysis-ability`(unit #4)の範囲
- `TileMapLayer` による本番のステージと `Parallax2D` の背景 — 理由: `foot-stage-boss`(unit #5)の範囲。本単位の仮ステージは `StaticBody2D` の矩形で作る
- シーン遷移・タイトル・リザルト — 理由: `game-flow`(unit #7)の範囲。リトライは現在のシーンの再読込で行う
- ドット絵のスプライトとアニメーション — 理由: 別の作業で制作して placeholder と差し替える
- 効果音 — 理由: 企画書 11. に方向性はあるが、コアループの成立確認に必要ない
- `PlayerInput.read()` のテスト — 理由: headless では `InputEvent` がエンジンを通らず、テストが常に成立してしまう(`docs/testing.md` の禁止事項)

## 3. 前提(未検証の賭け)

- **表の数値(§6.1)が「重い機動の撃ち合い」(企画書 2.)として成立する** — 検証方法: 仮ステージで実際に操作し、移動・ジャンプ・射撃の手触りを確かめる / 状態: 未検証。**数値は 1 箇所に集約して調整しやすくする**(§6.1)。とくに移動速度・ジャンプの高さ・自動回復の速度は、実際に動かしてから変える前提の値である
- **敵弾の弾速の上限 150 px/s で「移動で回避できる」が成立する** — 検証方法: `foot-enemies`(unit #3)で実際の敵弾を置いて回避できるかを確かめる / 状態: 未検証。算出の根拠は §6.2 に示す
- **`ColorRect` の placeholder と `CollisionShape2D` の矩形の位置がずれない** — 検証方法: 仮ステージで表示と当たり判定の境界を目視で確かめる / 状態: 未検証
- **`Callable` を差し替える形の入力の注入が、Godot 4.7.1 の headless で機能する** — 検証方法: テストから `input_source` を差し替えて `_physics_process` を経た移動を検証する / 状態: 未検証
- **`move_and_slide()` を物理フレームの中で呼ぶ必要がある** — 検証方法: unit #1 で実測済み(テスト本体から呼ぶと描画フレームの delta が使われ、100 px/s・3 回で期待 5.0px に対し 2.37px・10.58px と割れた) / 状態: **検証済み**。記録は `docs/testing.md` の「物理フレームを進めるテスト」と `docs/specs/001-test-harness/tasks.md` の `## Implementation Notes` にある

## 4. 用語定義

| 用語 | 定義 |
| ---- | ---- |
| コマンド | 1 フレーム分の入力の意図を表す値。`PlayerCommand` |
| 射撃方向 | 8 方向のいずれか。`Vector2i` の x・y がそれぞれ -1 / 0 / 1 で、両方 0 にはならない |
| 向き | プレイヤーが最後に左右の入力を受けた方向。`facing`(-1 または 1) |
| チャージ | 副武器のボタンを押し続けて発射の準備が進む状態 |
| 待機時間 | 最後の被弾から自動回復が始まるまでの時間 |
| ダメージ領域 | 仮ステージに置く `Area2D`。触れると体力が減る。敵の代わりに体力の振る舞いを確認するために置く |

## 5. 公開インターフェース(API)

### 5.1 `Player`(`CharacterBody2D`)

```gdscript
class_name Player extends CharacterBody2D

signal died
signal fired(direction: Vector2i, is_secondary: bool)

@export var stats: PlayerStats
var health: Health
var facing: int                                  # -1 または 1。初期値は 1
var input_source: Callable                       # 既定は PlayerInput.read

func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void
func take_damage(amount: int) -> void
```

- **`apply_command()` の責務**: 速度の計算・射撃方向の決定・武器の状態の更新・弾の生成・体力の更新をすべて行う。**`move_and_slide()` は呼ばない**
- **`_physics_process(delta)` の責務**: `input_source.call()` でコマンドを得て `apply_command(cmd, delta, is_on_floor())` へ渡し、その後に `move_and_slide()` を呼ぶだけ
- **接地状態を引数で受け取る理由**: 重力とジャンプの判定は接地状態に依存する。`is_on_floor()` をメソッドの中で呼ぶと、ツリーに載せていないノードでは常に偽になり、地上の振る舞いをテストできない。引数にすると、速度の計算が「コマンド・`delta`・`stats`・接地状態・現在の速度」だけで決まり、物理フレームなしで検証できる
- **`move_and_slide()` を `apply_command()` の外に置く理由**: 物理フレームの外で呼ぶと Godot が描画フレームの delta を使い、同じ入力でも結果が定まらない(§3 の検証済みの前提)。速度の計算を純粋に検証できるようにし、移動の結果は `_physics_process` を経た統合テストで確かめる
- **`input_source` を公開する理由**: headless では `InputEvent` がエンジンを通らず、`Input` を使ったテストが常に成立してしまう(`docs/testing.md` の禁止事項)。**テストが入力を差し替えるための公開点**であり、契約の一部として明示する。既定値は `PlayerInput.read` であり、実行時の振る舞いは変わらない
- **`died` の発火**: `health.depleted`(§6.4)を中継する。エッジの検出は `Health` が持ち、`Player` は保持状態を持たない
- **placeholder の寸法**: `ColorRect` と `CollisionShape2D`(`RectangleShape2D`)をともに **12×32px** とし、ノードの原点を矩形の中心に置く。企画書 11. の「キャラクター高は 24〜32px」の上端に取り、タイル(16px)より細くして段差の角に引っかかりにくくする
- **事前条件**: `stats` が設定されていること。未設定の場合は `_ready()` で `push_error` を出し、`PlayerStats.new()`(既定値)を使う
- **事後条件**: `apply_command()` の後、`velocity` は「コマンド・`delta`・`stats`・`is_on_floor`・呼び出し前の `velocity`」から一意に決まる
- **エラー**: `apply_command()` に `delta <= 0.0` が渡された場合は `push_error` を出し、速度を変えずに返る

### 5.2 `PlayerInput`(static)

```gdscript
class_name PlayerInput
static func read() -> PlayerCommand
```

`project.godot` の `[input]` に次の 7 アクションを追加する。

| アクション | 既定のキー | 用途 |
| ---------- | ---------- | ---- |
| `move_left` | A / ← | 左移動と射撃方向の左成分 |
| `move_right` | D / → | 右移動と射撃方向の右成分 |
| `aim_up` | W / ↑ | 射撃方向の上成分(移動には効かない) |
| `aim_down` | S / ↓ | 射撃方向の下成分(移動には効かない) |
| `jump` | Space | ジャンプ |
| `fire_primary` | J | 主武器 |
| `fire_secondary` | K | 副武器 |

- **事後条件**: 戻り値の `move_x` と `aim_y` は -1.0 / 0.0 / 1.0 のいずれか。`jump_pressed` はそのフレームで押された場合にだけ真
- **この関数はテストしない**(§2 の対象外)

### 5.3 `AimResolver`(static、純粋関数)

```gdscript
class_name AimResolver
static func resolve(move_x: float, aim_y: float, facing: int, is_on_floor: bool) -> Vector2i
```

- 入力の x 成分は `signi(move_x)`、y 成分は `signi(aim_y)`(上が -1)
- **`is_on_floor` が真のとき、y 成分が正(下)なら 0 にする**。地上で真下へ撃っても地面に当たるだけであり、斜め下の入力を水平へ寄せる
- x・y の両方が 0 になった場合は `Vector2i(facing, 0)` を返す
- **事後条件**: 戻り値は 8 方向のいずれか。`Vector2i.ZERO` を返さない
- **事前条件**: `facing` は -1 または 1。それ以外が渡された場合は `push_error` を出し `Vector2i(1, 0)` を返す

### 5.4 `PrimaryWeapon`

```gdscript
class_name PrimaryWeapon extends RefCounted

func _init(interval: float) -> void
func tick(delta: float) -> void
func try_fire() -> bool
```

- `tick()` が経過時間を進め、`try_fire()` は前回の発射から `interval` 以上が経っていれば真を返して経過時間を 0 に戻す。満たさなければ偽を返し、状態を変えない
- **初期状態**: 生成直後の経過時間は `interval` 以上とする。最初の入力で待たされないため
- **事後条件**: 連続するフレームで `try_fire()` が真を返す間隔は、常に `interval` 以上である

### 5.5 `SecondaryWeapon`

```gdscript
class_name SecondaryWeapon extends RefCounted

func _init(charge_time: float, cooldown: float) -> void
func update(held: bool, delta: float) -> bool
var charge_ratio: float          # 0.0〜1.0。演出と UI のため
var is_cooling_down: bool
```

- `update()` は毎フレーム呼ばれ、チャージの進行とクールダウンの経過の**両方**を進める
- `is_cooling_down` が偽でボタンが押されている間、`charge_ratio` が増え、`charge_time` で 1.0 に達する
- **ボタンを離したフレームに、`charge_ratio` が 1.0 に達していれば真(発射)を返し、クールダウンに入る**
- **チャージが未完了のまま離した場合は偽を返し、クールダウンに入らない**。`charge_ratio` は 0.0 に戻る
- クールダウン中はボタンを押しても `charge_ratio` が増えない。発射から `cooldown` が経過した時点で `is_cooling_down` が偽に戻る
- **事後条件**: `update()` が真を返した直後は `is_cooling_down` が真で `charge_ratio` が 0.0

### 5.6 `Projectile`(`Area2D`)

```gdscript
class_name Projectile extends Area2D
func launch(direction: Vector2i, speed: float, damage: int, max_distance: float) -> void
var damage: int
```

- `launch()` の後、毎フレーム `direction` を正規化した向きへ `speed` で進む
- 地形(レイヤ 1)に触れるか、**発射位置からの移動距離が `max_distance` を超える**と自身を解放する
- **`max_distance` を引数で受け取る理由**: `speed`・`damage` と同じく、値の出どころを `PlayerStats` に一本化するため。`Projectile` は `PlayerStats` を参照せず、呼び出し側(`Player`)が `stats.bullet_max_distance` を渡す。既定値の 400px は基準解像度の対角(367px)より長く、画面内で弾が消えない
- **事前条件**: `direction` は `Vector2i.ZERO` でないこと。`speed > 0`、`damage > 0`、`max_distance > 0`
- **不変条件**: `damage` は生成時に決まり、以後変わらない

### 5.7 `DevStage`(仮ステージ)

`StaticBody2D` + `CollisionShape2D` の矩形(床 1・段差 3 段・壁 2)と `Player` と `DamageZone` を配置したシーン。

- `player.died` を受けて `get_tree().reload_current_scene()` を呼ぶ
- **`TileMapLayer` を使わない**。本番のステージは `foot-stage-boss`(unit #5)で作る

### 5.8 `DamageZone`(`Area2D`)

```gdscript
class_name DamageZone extends Area2D
@export var damage: int = 15
```

- プレイヤー(レイヤ 2)が触れている間、**1 秒に 1 回** `player.take_damage(damage)` を呼ぶ
- 敵が入るまでの間、体力の減少・自動回復・リトライを実行時に確認するために置く

## 6. データ構造

### 6.1 `PlayerStats`(`Resource`)

手触りを決める数値を 1 箇所に集約する。`Resource` にするのは、インスペクタから調整でき、テストからも生成できるためである。

```gdscript
class_name PlayerStats extends Resource
@export var move_speed: float = 100.0
@export var gravity: float = 600.0
@export var jump_speed: float = 240.0
@export var max_health: int = 100
@export var regen_delay: float = 3.0
@export var regen_per_second: float = 20.0
@export var primary_interval: float = 0.12
@export var primary_damage: int = 10
@export var primary_bullet_speed: float = 400.0
@export var secondary_charge_time: float = 0.8
@export var secondary_cooldown: float = 2.0
@export var secondary_damage: int = 50
@export var secondary_bullet_speed: float = 300.0
@export var bullet_max_distance: float = 400.0
```

| 項目 | 既定値 | 根拠 |
| ---- | -----: | ---- |
| `move_speed` | 100.0 | 画面幅(320px)を 3.2 秒で横断。企画書 2. の「重い機動」に合わせてやや遅め |
| `gravity` / `jump_speed` | 600.0 / 240.0 | 最高到達点 48px(3 タイル)、上昇 0.4 秒・滞空 0.8 秒。企画書 4. の「縦方向の登り」で 3 タイルを越えられる |
| `max_health` | 100 | 敵の攻撃 1 発を 10〜20 に置いて、5〜10 発で撃破される粒度 |
| `regen_delay` / `regen_per_second` | 3.0 / 20.0 | 連続被弾中は回復せず、離脱して 3 秒で回復が始まる。0 から満タンまで 5 秒。企画書 5. の「難度を回復速度という一つの数値で調整する」の調整点 |
| `primary_interval` | 0.12 | 毎秒 8.3 発。企画書 6.「自動小銃相当」 |
| `secondary_charge_time` / `secondary_cooldown` | 0.8 / 2.0 | 企画書 6.「撃った後は一定時間使えない」。連発できない長さ |
| `secondary_damage` | 50 | 主武器の 5 倍。チャージ 0.8 秒 + クールダウン 2.0 秒の対価 |
| `bullet_max_distance` | 400.0 | 基準解像度の対角(√(320²+180²) = 367px)より長い。画面内で弾が消えない |

- **不変条件**: すべての値は正。0 以下が設定された場合は `_ready()` の検証で `push_error` を出す

### 6.2 `CombatLimits`

敵の攻撃が満たすべき上限。使うのは `foot-enemies`(unit #3)だが、根拠(企画書 5.)が本単位の移動速度に依存するため、ここで定義する。

```gdscript
class_name CombatLimits extends RefCounted
const ENEMY_BULLET_MAX_SPEED: float = 150.0
const ENEMY_TELEGRAPH_MIN_TIME: float = 0.4
```

- **算出の根拠**: プレイヤーの移動速度 100 px/s、反応に 0.3 秒、1 タイル(16px)の回避に 0.16 秒。合計 0.46 秒。弾が画面の半分(160px)を進む時間がこれを上回る必要があり、上限は 348 px/s。余裕を取って 150 px/s とする
- **不変条件**: この 2 つの値は敵の設計の上限であり、`foot-enemies` 以降の単位が超えてはならない

### 6.3 `PlayerCommand`

```gdscript
class_name PlayerCommand extends RefCounted
var move_x: float          # -1.0 / 0.0 / 1.0
var aim_y: float           # -1.0(上) / 0.0 / 1.0(下)
var jump_pressed: bool
var primary_held: bool
var secondary_held: bool
```

- **不変条件**: `move_x` と `aim_y` は -1.0 / 0.0 / 1.0 のいずれか
- **`aim_y` が移動に効かない理由**: 企画書 5. は操作を 4 つ(左右移動・ジャンプ・主武器・副武器)に限る。上下の入力を移動に使うと操作が増えるが、射撃方向の縦成分にだけ使えば「方向入力・ジャンプ・主武器・副武器」の枠に収まり、8 方向射撃が成立する

### 6.4 `Health`

```gdscript
class_name Health extends RefCounted

signal depleted                     # 体力が 0 になった最初の 1 回だけ発火する

func _init(max_value: int, regen_delay: float, regen_per_second: float) -> void
func take_damage(amount: int) -> void
func tick(delta: float) -> void
var current: int
var is_depleted: bool
```

- **不変条件**: `0 <= current <= max_value`。この範囲は `take_damage()` と `tick()` の内部で強制する
- **ロジックの所在**: 待機時間の計測と回復の進行は `Health` が持つ。`Player` は `tick()` を呼ぶだけで、経過時間を自分で持たない
- **回復の端数**: `current` は整数だが回復は毎秒 20 の連続量なので、内部に float の蓄積を持ち、1 以上になった分を `current` へ移す
- **事前条件**: `take_damage()` の `amount` は正。0 以下が渡された場合は `push_error` を出し、状態を変えない
- **`is_depleted` が真になった後**: `take_damage()` と `tick()` は状態を変えない(死亡後の回復も追加ダメージも起きない)
- **`depleted` のエッジ検出は `Health` が持つ**。`current` が 0 になった最初の 1 回だけ発火し、以後は何度 `take_damage()` を呼んでも発火しない。`Player` は `depleted` を `died` へ中継するだけで、保持状態を持たない

### 6.5 衝突レイヤの割り当て

本単位で確定させる。**後続の単位もこの割り当てを使う。**

| レイヤ | 用途 | 本単位で使う |
| -----: | ---- | ------------ |
| 1 | 地形 | ○ |
| 2 | プレイヤー | ○ |
| 3 | プレイヤーの弾 | ○ |
| 4 | 敵 | unit #3 |
| 5 | 敵の弾 | unit #3 |

- プレイヤーの弾: layer 3、mask は 1(地形)と 4(敵)
- `DamageZone`: layer は使わず、mask は 2(プレイヤー)

### 6.6 ファイルの配置

```
src/player/     player.tscn, player.gd, player_command.gd, player_input.gd,
                player_stats.gd, health.gd, aim_resolver.gd
src/weapon/     projectile.tscn, projectile.gd, primary_weapon.gd, secondary_weapon.gd,
                combat_limits.gd
src/stage/      dev_stage.tscn, dev_stage.gd, damage_zone.tscn, damage_zone.gd
tests/player/   ...
tests/weapon/   ...
```

- 企画書 12.「プレイヤー・敵・武器・ステージ・ネット空間区間をそれぞれシーン化して再利用可能にする」に沿う
- テストの配置は `docs/testing.md` の規約(実装のディレクトリ構成を写す)に従う
- **本単位が更新する文書**: `docs/testing.md`。`tests/harness/` が配置の規約の例外であること、サンプルの位置づけ、仮ステージの起動方法を追記する(内容は §7 Requirement 11 が定める)

## 7. 振る舞い(受け入れ基準)

### Requirement 1: 移動とジャンプ

**対象**: §5.1 `Player` / §6.1 `PlayerStats` / §6.3 `PlayerCommand`

**受け入れ基準**:

**検証の形式**: 1.1〜1.8 は `apply_command()` を直接呼び、`velocity` を検証する(物理フレーム不要)。1.9 はノードをシーンツリーへ載せ、`input_source` を差し替えて物理フレームを進め、位置を検証する。

1.1. `move_x` が -1.0 または 1.0 のコマンドが渡されたとき、システムは水平の速度を `move_x * move_speed` としなければならない。(イベント)
1.2. `move_x` が 0.0 のコマンドが渡されたとき、システムは水平の速度を 0 としなければならない。(イベント)
1.3. `is_on_floor` が偽で `apply_command()` が呼ばれる間、システムは垂直の速度を毎フレーム `gravity * delta` だけ増やさなければならない。(状態)
1.4. `is_on_floor` が真の状態で `jump_pressed` が真のコマンドが渡されたとき、システムは垂直の速度を `-jump_speed` としなければならない。(イベント)
1.5. `is_on_floor` が偽の状態で `jump_pressed` が真のコマンドが渡された場合、システムは垂直の速度を `gravity * delta` の加算以外に変えてはならない。(異常系)
1.6. `move_x` が 0 でないコマンドが渡されたとき、システムは `facing` を `signi(move_x)` に更新しなければならない。(イベント)
1.7. `move_x` が 0.0 のコマンドが渡されたとき、システムは `facing` を変えてはならない。(イベント)
1.8. `delta` が 0 以下の値で `apply_command()` が呼ばれた場合、システムは速度を変えずに返らなければならない。(異常系)
1.9. `input_source` を差し替えたプレイヤーがシーンツリーの上で 3 物理フレームぶん右へ移動したとき、システムは水平の位置を `move_speed / Engine.physics_ticks_per_second * 3` だけ増やさなければならない(許容差 0.001)。(イベント)
1.10. システムは、`ColorRect` と `CollisionShape2D` をともに 12×32px とし、ノードの原点を矩形の中心に置かなければならない。(常時)
1.11. `is_on_floor` が真で `jump_pressed` が偽のコマンドが渡されたとき、システムは垂直の速度を 0 としなければならない(接地中に重力が蓄積しないようにする)。(イベント)

### Requirement 2: 射撃方向の決定

**対象**: §5.3 `AimResolver`

**受け入れ基準**:

2.1. システムは、8 方向のいずれかを返さなければならない(`Vector2i.ZERO` を返さない)。(常時)
2.2. `move_x` と `aim_y` の両方が 0.0 のとき、システムは `Vector2i(facing, 0)` を返さなければならない。(イベント)
2.3. `move_x` が 1.0 で `aim_y` が -1.0 のとき、システムは `Vector2i(1, -1)` を返さなければならない。(イベント)
2.4. `is_on_floor` が真で `aim_y` が 1.0(下)のとき、システムは y 成分を 0 とした方向を返さなければならない。(イベント)
2.5. `is_on_floor` が偽で `aim_y` が 1.0(下)のとき、システムは y 成分を 1 とした方向を返さなければならない。(イベント)
2.6. `is_on_floor` が真で `move_x` が 0.0・`aim_y` が 1.0 のとき、システムは `Vector2i(facing, 0)` を返さなければならない(下の成分を落とした結果が両方 0 になるため)。(イベント)
2.7. `facing` が -1 でも 1 でもない値で呼ばれた場合、システムは `Vector2i(1, 0)` を返さなければならない。(異常系)

### Requirement 3: 主武器

**対象**: §5.4 `PrimaryWeapon` / §5.1 `Player`

**受け入れ基準**:

3.1. `primary_held` が真のコマンドが渡され、前回の発射から `primary_interval` 以上が経過しているとき、システムは弾を 1 発生成し `fired` を発火しなければならない。(イベント)
3.2. `primary_held` が真でも前回の発射から `primary_interval` 未満しか経過していない間、システムは弾を生成してはならない。(状態)
3.3. システムは、主武器の弾に `primary_damage` と `primary_bullet_speed` を設定しなければならない。(常時)
3.4. システムは、主武器の弾を §5.3 が返した方向へ発射しなければならない。(常時)
3.5. `primary_held` が偽のコマンドが渡されたとき、システムは弾を生成してはならない。(イベント)
3.6. 生成直後の `PrimaryWeapon` に対して `try_fire()` が呼ばれたとき、システムは真を返さなければならない(最初の入力で待たされない)。(イベント)
3.7. 主武器を発射したとき、システムは `fired` の `is_secondary` を偽としなければならない。(イベント)

### Requirement 4: 副武器

**対象**: §5.5 `SecondaryWeapon` / §5.1 `Player`

**受け入れ基準**:

4.1. `is_cooling_down` が偽で `secondary_held` が真である間、システムは `charge_ratio` を毎フレーム `delta / secondary_charge_time` だけ増やさなければならない(上限 1.0)。(状態)
4.2. `charge_ratio` が 1.0 に達した状態で `secondary_held` が偽になったとき、システムは弾を 1 発生成し `fired` を発火しなければならない。(イベント)
4.3. `charge_ratio` が 1.0 未満の状態で `secondary_held` が偽になった場合、システムは弾を生成せず、クールダウンに入らず、`charge_ratio` を 0.0 に戻さなければならない。(異常系)
4.4. 発射した直後、システムは `is_cooling_down` を真とし `charge_ratio` を 0.0 としなければならない。(イベント)
4.5. `is_cooling_down` が真である間、システムは `secondary_held` が真でも `charge_ratio` を増やしてはならない。(状態)
4.6. 発射から `secondary_cooldown` が経過したとき、システムは `is_cooling_down` を偽としなければならない。(イベント)
4.7. システムは、副武器の弾に `secondary_damage` と `secondary_bullet_speed` を設定しなければならない。(常時)
4.8. 副武器を発射したとき、システムは `fired` の `is_secondary` を真としなければならない。(イベント)

### Requirement 5: 弾体

**対象**: §5.6 `Projectile` / §6.5 衝突レイヤの割り当て

**受け入れ基準**:

5.1. `launch()` の後、システムは弾を指定された方向へ毎フレーム `speed * delta` だけ進めなければならない。(常時)
5.2. 弾が地形(レイヤ 1)に触れたとき、システムは弾を解放しなければならない。(イベント)
5.3. 弾の発射位置からの移動距離が `max_distance` を超えたとき、システムは弾を解放しなければならない。(イベント)
5.4. システムは、プレイヤーの弾の衝突レイヤを 3、マスクを 1 と 4 としなければならない。(常時)
5.5. `direction` が `Vector2i.ZERO`、`speed` が 0 以下、`damage` が 0 以下、または `max_distance` が 0 以下で `launch()` が呼ばれた場合、システムは弾を進めてはならない。(異常系)
5.6. システムは、`max_distance` を `launch()` の引数として受け取らなければならない(`Projectile` が `PlayerStats` を参照せず、値の出どころを `PlayerStats` に一本化する)。(常時)

### Requirement 6: 体力と自動回復

**対象**: §6.4 `Health` / §5.1 `Player`

**受け入れ基準**:

6.1. システムは、体力を 0 以上 `max_health` 以下に保たなければならない。(常時)
6.2. `take_damage(amount)` が呼ばれたとき、システムは体力を `amount` だけ減らし、待機時間の計測を最初からやり直さなければならない。(イベント)
6.3. 最後の被弾から `regen_delay` が経過していない間、システムは体力を回復してはならない。(状態)
6.4. 最後の被弾から `regen_delay` が経過した後、システムは体力を毎秒 `regen_per_second` だけ回復しなければならない。(状態)
6.5. 体力が `max_health` に達したとき、システムはそれ以上回復してはならない。(イベント)
6.6. 体力が 0 になったとき、システムは `Health.depleted` を**ちょうど 1 回**発火しなければならない。体力が 0 の状態で再度 `take_damage()` が呼ばれても発火してはならない。(イベント)
6.7. `Health.depleted` が発火したとき、システムは `Player.died` を発火しなければならない。(イベント)
6.8. 体力が 0 になった後、システムは `take_damage()` と `tick()` で状態を変えてはならない。(状態)
6.9. `take_damage()` に 0 以下の値が渡された場合、システムは状態を変えてはならない。(異常系)

### Requirement 7: リトライ

**対象**: §5.7 `DevStage` / §5.1 `Player`

**受け入れ基準**:

7.1. システムは、`player.died` を `DevStage` の再読込の処理へ接続しなければならない(接続の有無をシグナルの接続数で検証する)。(常時)
7.2. `player.died` が発火したとき、システムは `get_tree().reload_current_scene()` を呼ばなければならない。**この基準は自動テストでは検証せず、`godot res://src/stage/dev_stage.tscn` で仮ステージを起動し、ダメージ領域に留まって体力を 0 にしたあと、プレイヤーの位置が初期位置に戻り体力が `max_health` に戻ることを目視で確認する**(理由: gdUnit4 のテストツリーで呼ぶと、テストの実行そのものが読み込むシーンを差し替えてしまう)。(イベント)
7.3. システムは、リトライの再開位置をステージの先頭以外に切り替える状態・ノード・設定を持ってはならない。(常時)

### Requirement 8: 入力の読み取り

**対象**: §5.2 `PlayerInput` / §5.1 `Player`

**受け入れ基準**:

8.1. システムは、`project.godot` に `move_left`・`move_right`・`aim_up`・`aim_down`・`jump`・`fire_primary`・`fire_secondary` の 7 アクションを定義しなければならない。(常時)
8.2. システムは、`Player.input_source` を差し替え可能な公開点として持たなければならない。(常時)
8.3. `input_source` が差し替えられていない間、システムは `PlayerInput.read` を使わなければならない。(状態)
8.4. システムは、`_physics_process` で `apply_command()` を呼んだ後に `move_and_slide()` を呼ばなければならない。(常時)
8.5. システムは、`apply_command()` の中で `move_and_slide()` を呼んではならない。(常時)

### Requirement 9: 仮ステージ

**対象**: §5.7 `DevStage` / §5.8 `DamageZone` / §6.5 衝突レイヤの割り当て

**受け入れ基準**:

9.1. システムは、床・段差 3 段・壁を `StaticBody2D` と `CollisionShape2D` で構成しなければならない。(常時)
9.2. システムは、段差 1 段の高さを **32px(2 タイル)以下**としなければならない。最高到達点の 48px と同じ高さにすると、頂点で垂直の速度が 0 になる位置へ乗ることを要求して余裕が無くなる。(常時)
9.3. プレイヤーが `DamageZone` に触れている間、システムは 1 秒に 1 回 `take_damage(damage)` を呼ばなければならない。(状態)
9.4. システムは、仮ステージに `TileMapLayer` を使ってはならない。(常時)
9.5. システムは、仮ステージの `StaticBody2D` の衝突レイヤを 1、`Player` の衝突レイヤを 2 としなければならない。(常時)
9.6. システムは、`project.godot` の `run/main_scene` を変更してはならない。仮ステージは `godot res://src/stage/dev_stage.tscn` でシーン単体を起動して確認する。`run/main_scene` を差し替えると、`docs/asset-pipeline.md` が定める `godot -- <出力パス>`(`main.tscn` のビューポートを PNG へ保存して終了する)が仮ステージを起動して終了しなくなる。(常時)
9.7. システムは、仮ステージの起動方法(`godot res://src/stage/dev_stage.tscn`)を `docs/testing.md` に記載しなければならない。(常時)

### Requirement 10: 数値の集約と敵の設計の上限

**対象**: §6.1 `PlayerStats` / §6.2 `CombatLimits`

**受け入れ基準**:

10.1. システムは、手触りを決める数値を `PlayerStats` の 1 箇所に集約し、`@export` で調整できるようにしなければならない。(常時)
10.2. システムは、`PlayerStats` の値を実装のコードへ直書きしてはならない。(常時)
10.3. `PlayerStats` に 0 以下の値が設定された場合、システムは `push_error` を出さなければならない。(異常系)
10.4. システムは、敵弾の弾速の上限 150 px/s と予備動作の下限 0.4 秒を `CombatLimits` の定数として定義しなければならない。(常時)

### Requirement 11: テストの規約の文書の更新

**対象**: §6.6 ファイルの配置(「本単位が更新する文書」)

`docs/specs/001-test-harness/spec.md` §2 が本単位へ持ち越した 2 件の判断に対応する。

**受け入れ基準**:

11.1. システムは、`docs/testing.md` に `tests/harness/` が配置の規約(実装のディレクトリ構成を写す)の例外であることと、その理由を記載しなければならない。(常時)
11.2. システムは、`docs/testing.md` に `tests/harness/` のサンプルが基盤自体の動作を示すものであり、実装に対応しないことを記載しなければならない。(常時)
11.3. システムは、`tests/harness/logic_test.gd` と `tests/harness/scene_test.gd` を削除・移動してはならない。(常時)

## 8. 実現方針(要点のみ)

- **入力の読み取りとロジックを分ける**。`PlayerInput.read()` → `PlayerCommand` → `Player.apply_command()` の 3 段にし、`PlayerInput` だけが `Input` を触る。headless では `InputEvent` がエンジンを通らないため、これ以外の分け方ではロジックを検証できない(`docs/testing.md` の禁止事項)。
- **`move_and_slide()` を `_physics_process` に置き、`apply_command()` から出す**。unit #1 で、物理フレームの外から呼ぶと描画フレームの delta が使われて結果が割れることを実測している。テストは (a) `apply_command()` を直接呼んで速度を検証する形と、(b) ノードをツリーへ載せ `input_source` を差し替えて物理フレームを進め、位置を検証する形の 2 通りになる。
- **接地状態を `apply_command()` の引数にする**。壁打ちで合意した形は `apply_command(cmd, delta)` だったが、`is_on_floor()` をメソッドの中で呼ぶとツリー外のノードでは常に偽になり、地上の振る舞い(ジャンプ・重力の停止)を物理フレームなしに検証できない。引数を 1 つ増やして速度の計算を純粋に保つ判断を採った。
- **`Health` を `Player` から分ける**。待機時間の計測と回復の進行を `Health` が持つことで、体力の振る舞いを物理フレームなしで検証できる。
- **`AimResolver` を純粋関数にする**。8 方向の決定は入力・向き・接地の 3 つだけに依存し、ノードの状態を持たない。
- **数値を `Resource` に集約する**。§3 のとおり、表の値は実際に動かしてから変える前提である。`@export` にすることで、コードを触らずインスペクタから調整できる。
- **`CombatLimits` を本単位で定義する**。値の根拠がプレイヤーの移動速度に依存するため、敵を作る単位ではなくここに置く。
- 本リポジトリは用語集(`docs/glossary.md`)を持たないため、契約に付ける名前は Godot の語彙と企画書の用語に合わせた。

## 9. 参考資料

- 企画書 5.(プレイヤー)・6.(武器)・12.(技術方針): workspace リポジトリの `4_artifacts/netdiver/issues/01_game-design-doc/game-design-doc.md`
- 本単位の位置づけと完了条件: `docs/specs/roadmap.md`
- テストの書き方と headless の制約: `docs/testing.md`
- `move_and_slide()` と物理フレームの実測: `docs/testing.md` の「物理フレームを進めるテスト」と `docs/specs/001-test-harness/tasks.md` の `## Implementation Notes`
