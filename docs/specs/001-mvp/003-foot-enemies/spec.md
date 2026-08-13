# foot-enemies — 仕様

## 1. 目的と背景

netdiver の徒歩パートに雑魚敵 2 種(突進型・射撃型)を置き、プレイヤーと敵の間で被弾と撃破が双方向に成立する状態にする。企画書 7.(敵・ボス)が定める 2 種の役割と、企画書 5. が定める「敵の攻撃が満たすべき条件」(予備動作・弾速・同時数)を、`foot-player`(unit #2)が定数化した上限(`CombatLimits`)の内側で実装する。

本単位までで「撃つ・避ける・倒される」のやり取りが閉じ、`analysis-ability`(unit #4)が扱う撃破時の解析の起点(撃破のシグナル)が用意される。

グラフィックは placeholder(単色矩形)とする。unit #2 と同じく、ゲームロジックを先に完成させるためである。

## 2. スコープ

### 対象(やること)

- 雑魚敵の共通の基底(体力・被弾・撃破のシグナル)
- 突進型の敵(接近 → 予備動作 → 突進 → 硬直の状態遷移と、突進中だけの攻撃判定)
- 射撃型の敵(定点から、予備動作 → 発射 → 待機の周期で撃つ)
- 敵弾(`EnemyProjectile`)
- プレイヤーの弾による敵の被弾(`Hurtbox`)
- 敵の数値の 1 箇所への集約(`EnemyStats`)
- 敵の攻撃が `CombatLimits` の上限の内側にあることの検査
- 敵の確認用の仮ステージと、「同時に対処を要求する攻撃は 2 つまで」の配置規約
- 上記の振る舞いを検証するテスト

### 対象外(やらないこと)

- 撃破時の解析の演出と能力の取得(第 3 の武器枠) — 理由: `analysis-ability`(unit #4)の範囲。本単位は撃破のシグナル(`defeated`)を公開するところまでとする
- 敵の動的な出現(スポナー・ウェーブ) — 理由: 出現の仕組みはステージを作る `foot-stage-boss`(unit #5)の範囲。本単位は仮ステージのシーンへ直接配置する
- ボス — 理由: `foot-stage-boss`(unit #5)の範囲
- 飛行型の雑魚敵・ギミック敵 — 理由: 企画書 7. が拡張時の追加と定めている。MVP は雑魚敵 2 種に限る
- 本番のステージ(`TileMapLayer`・`Parallax2D`) — 理由: `foot-stage-boss`(unit #5)の範囲
- 既存の `dev_stage.tscn` への敵の追加 — 理由: `DevStage` は子ノードの許可リストをテストで固定しており(unit #2)、敵を足すと凍結済み単位のテストの改訂が要る。敵の確認用に別の仮ステージを新設する
- `Projectile`(プレイヤーの弾)の変更 — 理由: unit #2 の凍結済みの契約(`docs/specs/001-mvp/002-foot-player/spec.md` §5.6)である。被弾の適用は敵側で受け取る形にして、この契約に触れない
- `PlayerStats` の数値項目に 0 を設定したときの退化 — 理由: unit #2 が持ち越した既知の不具合であり、その契約(同 §6.1)の変更を伴う。本単位の範囲外とする
- 効果音・ドット絵 — 理由: unit #2 と同じく別の作業で制作して placeholder と差し替える

## 3. 前提(未検証の賭け)

- **敵弾の弾速 120 px/s と突進速度 150 px/s で「見てから移動を始めても間に合う」が成立する** — 検証方法: 仮ステージで実際に操作し、予備動作を見てから回避できるかを確かめる / 状態: 未検証。算出の根拠は unit #2 の `CombatLimits`(同 §6.2)にあり、そこでも未検証の前提として挙げられている
- **`CombatLimits.ENEMY_BULLET_MAX_SPEED`(150.0)は `PlayerStats.move_speed`(100.0)に依存して算出されている** — 検証方法: 移動速度を変える変更が入ったとき、`combat_limits.gd` の算出根拠のコメントに従って上限を再計算する / 状態: **検証済み**(unit #2 の `tasks.md` の `## Implementation Notes` に記録がある)。本単位はこの上限を消費するだけで、値を変えない
- **突進型の体力 30・射撃型の体力 20 が「主武器で 3 発 / 2 発、副武器で 1 発」の粒度として成立する** — 検証方法: 仮ステージで実際に撃って撃破までの手応えを確かめる / 状態: 未検証
- **`Hurtbox`(`Area2D`)がプレイヤーの弾(`Projectile`、`Area2D`)を `area_entered` で検出でき、同じフレームで `Projectile` 自身の `body_entered` による解放と両立する** — 検証方法: 敵をシーンツリーへ載せて弾を当て、体力が減ることと弾が解放されることの両方を検証する / 状態: 未検証。unit #2 の申し送りは「`Projectile` は mask に載るすべての body で解放される」ことだけを保証しており、`Area2D` 同士の検出の順序は確かめていない
- **`Area2D` の重なりの通知は 1 物理フレーム遅れる** — 検証方法: unit #2 で実測済み / 状態: **検証済み**(同 `tasks.md` の `## Implementation Notes`)。接触の位置・時刻を検証するテストは 2 フレーム分を上限に取る
- **`monitoring` の切り替えで攻撃判定の有効・無効を制御できる** — 検証方法: 突進中だけダメージが入り、それ以外では入らないことをテストで検証する / 状態: 未検証

## 4. 用語定義

| 用語 | 定義 |
| ---- | ---- |
| 予備動作 | 攻撃の前に敵が取る、目視で識別できる待ちの時間。`telegraph_time` |
| 突進 | 突進型が予備動作の後に行う、直線的で高速な移動。この間だけ攻撃判定を持つ |
| 硬直 | 突進の後、次の行動へ移るまでの待ちの時間。撃破の機会になる。`recover_time` |
| 索敵範囲 | 敵がプレイヤーを行動の対象と見なす距離。`detect_range` |
| 突進の到達距離 | 1 回の突進で進む距離。`attack_speed * attack_duration` |
| 攻撃判定 | 敵がプレイヤーへダメージを与える領域。`Attackbox`(突進型)と `EnemyProjectile`(射撃型) |
| 被弾判定 | 敵がプレイヤーの弾からダメージを受ける領域。`Hurtbox` |
| 脅威の圏 | 配置規約の検査に使う、プレイヤーの初期位置を中心とする半径 160px の円 |
| 標的 | 敵が距離と向きを測る相手。`Enemy.target`。仮ステージでは `Player` を指す |

## 5. 公開インターフェース(API)

### 5.1 `Enemy`(`CharacterBody2D`、2 種の共通の基底)

```gdscript
class_name Enemy extends CharacterBody2D
signal defeated(kind: int)                        # EnemyKind.Kind
@export var stats: EnemyStats
@export var target: Node2D                        # 標的。テストのための差し替え口でもある
var hp: int
var is_defeated: bool
func take_damage(amount: int) -> void
func kind() -> int                                # EnemyKind.Kind。派生クラスが返す
```

- **事前条件**: `take_damage()` の `amount` は正。0 以下が渡された場合は `push_error` を出し、状態を変えない
- **事後条件**: `take_damage()` は `hp` を `amount` だけ減らし、0 を下回らせない
- **不変条件**: `0 <= hp <= stats.max_hp`
- `hp` が 0 になった最初の 1 回だけ `defeated` を発火し、`is_defeated` を真にしてから自身を解放する(`queue_free()`)
- `is_defeated` が真になった後の `take_damage()` は状態を変えず、`defeated` を再び発火しない
- **`stats` の検査**: `_ready()` で `stats` が未設定なら `push_error` を出し、`EnemyStats.new()` へフォールバックする。数値項目が §6.1 の不変条件を満たさない場合は項目名と現在値を添えて `push_error` を出す(値は補正しない)。`Player._ready()`(unit #2 §5.1)と同じ形
- **エラー**: いずれも `push_error` で表出する。例外・戻り値による表出は行わない
- 重力に従う。`_physics_process` の重力は `EnemyStats.gravity` から読む(`PlayerStats` の値や定数を直書きしない)
- **placeholder と衝突形状**: `ColorRect` と `CollisionShape2D` をともに 16×16px とし、ノードの原点を矩形の中心に置く。`Hurtbox` の形状は本体の衝突形状と同じ矩形とし、本体からはみ出させない(はみ出すと、弾の解放(本体との接触)と被弾(`Hurtbox`)の片方だけが成立しうる)
- **標的の解決**: `@export var target: Node2D` を持ち、標的を外から注入する。仮ステージはシーンの宣言(`[node]` のプロパティ)で `Player` を指す。**これはテストが標的を差し替えるための公開点であり、契約の一部である**(unit #2 の `Player.input_source` と同じ位置づけ)
- **標的が不在のフレーム**: `target` が `null`(または解放済み)のとき、`push_error` を出さず、標的までの距離を `INF` として `Brain` へ渡す。異常ではなく想定内の状態として扱うのは、シーン構成を検証するテストが敵を単体で生成する経路を正常な使い方に含めるためである
- **標的を失った時点の状態で挙動が分かれる**: `IDLE` の間に失った場合は索敵範囲・突進の到達距離のいずれも満たさないため `IDLE` に留まり、水平には動かない(§7 1.15)。**`TELEGRAPH` 以降の途中で失った場合は、進行中の状態遷移を最後まで完走する**(距離の変化で遷移を打ち切らない。突進型は §7 2.7、射撃型は §7 4.11)
- **標的が不在のまま攻撃のフレームに達したときは、その回の攻撃を取りやめる**。突進型は `ChargerBrain` が距離 `INF` を見て `CHARGE` を飛ばし `RECOVER` へ移る(§7 2.11)。射撃型は `ShooterBrain` が真を返して `COOLDOWN` へ移り、`ShooterEnemy` が弾の生成だけを取りやめる(§7 4.13)。突進型を `Brain` 側で閉じるのは、突進が状態遷移そのものを変える一方、射撃は弾を出すか出さないかだけの差だからである。向きが決まらないまま `Vector2.ZERO` を `EnemyProjectile.launch()` へ渡すと §5.7 の事前条件に反し、解放済みノードの位置を読むと実行時エラーになるためである。最後に観測した向きを保持する案は採らない(`Brain` に状態変数が増え、到達可能な状態の表が広がる)
- **`kind()` の基底実装**: `Enemy` を直接生成した場合に備え、基底は `EnemyKind.Kind.CHARGER` を返す。派生クラスが必ず上書きする

### 5.2 `ChargerEnemy`(`Enemy`)

```gdscript
class_name ChargerEnemy extends Enemy
var brain: ChargerBrain                           # テストのための公開点(契約の一部)
```

- `ChargerBrain` を 1 つ持ち、毎物理フレーム `target` までの距離を算出して `update()` に渡す(`target` が `null` なら `INF`)
- `ChargerBrain.state` に応じて水平の速度を決める。`IDLE` では距離が `stats.detect_range` 以下のときだけ `stats.move_speed` でプレイヤーへ接近し(範囲外では停止)、`CHARGE` では突進を始めた時点の向きへ `stats.attack_speed` で進み、`TELEGRAPH` と `RECOVER` では停止する
- `Attackbox`(子の `Area2D`)の `monitoring` を `brain.is_attack_active` に一致させる。**`is_defeated` が真になった後はこの一致より撃破時の停止が優先し、`monitoring` を偽に保つ**(§7 3.5・3.10)
- `_ready()` で `Attackbox.damage` に `stats.attack_damage` を代入する(シーンへ値を焼き込まない。§7 8.1)
- `kind()` は `EnemyKind.Kind.CHARGER` を返す

### 5.3 `ShooterEnemy`(`Enemy`)

```gdscript
class_name ShooterEnemy extends Enemy
@export var projectile_scene: PackedScene
var brain: ShooterBrain                           # テストのための公開点(契約の一部)
```

- `ShooterBrain` を 1 つ持ち、毎物理フレーム `target` までの距離を算出して `update()` に渡す(`target` が `null` なら `INF`)。戻り値が真のフレームで敵弾を 1 発生成し、`target` へ向かう単位ベクトルの向きへ発射する
- 水平には移動しない(重力にのみ従う)
- 敵弾は**自分の親(`get_parent()`)へ追加する**。自分の子にすると、弾が発射元と一緒に動いてしまう(unit #2 の `Player` が同じ理由で `get_parent()` を選んでいる)。発射位置は敵自身の位置とし、`add_child()` して位置を決めてから `launch()` を呼ぶ(§5.7 の事前条件)
- `projectile_scene` が未設定の場合は `push_error` を出し、弾を生成しない(`Player`(unit #2)の同名の扱いに揃える)
- `kind()` は `EnemyKind.Kind.SHOOTER` を返す

### 5.4 `ChargerBrain`(`RefCounted`、純ロジック)

```gdscript
class_name ChargerBrain extends RefCounted
func _init(stats: EnemyStats) -> void
func update(delta: float, distance_to_target: float) -> void
var state: int                                    # EnemyState.State
var is_attack_active: bool
```

- **状態遷移**: `IDLE` →(距離が突進の到達距離以下)→ `TELEGRAPH` →(`telegraph_time` 経過。距離が有限なら `CHARGE`、`INF` なら `RECOVER`)→ `CHARGE` →(`attack_duration` 経過)→ `RECOVER` →(`recover_time` 経過)→ `IDLE`
- **`IDLE` から出る条件は距離だけで決まる**。`detect_range`(索敵範囲)は遷移の条件に使わず、接近するかどうかの判断にのみ効く。接近は `ChargerBrain` の出力(`state`・`is_attack_active`)に現れず、`ChargerEnemy` が §7 3.1・3.2 として持つ
- **`TELEGRAPH` へ移る条件**: 距離が突進の到達距離(`attack_speed * attack_duration`)以下であること。索敵範囲ではなく到達距離を条件にするのは、届かない位置から突進を始めないためである
- **`is_attack_active`**: `state` が `CHARGE` のときだけ真
- **事前条件**: `update()` の `delta` は正、`distance_to_target` は 0 以上。満たさない場合は `push_error` を出し、状態を変えずに返る
- **事後条件**: 状態の滞在時間の判定は `delta` を足す**前**に行う。同じ `delta` を 2 つの状態へ数えない(unit #2 の `Health`・`SecondaryWeapon` と同じ形)
- **不変条件**: `state` は `EnemyState.State` の 4 値(`IDLE` / `TELEGRAPH` / `CHARGE` / `RECOVER`)のいずれか
- **ロジックの所在**: 滞在時間の計測と遷移の判断は `ChargerBrain` が持つ。`ChargerEnemy` は速度への写像と攻撃判定の切り替えだけを行う

### 5.5 `ShooterBrain`(`RefCounted`、純ロジック)

```gdscript
class_name ShooterBrain extends RefCounted
func _init(stats: EnemyStats) -> void
func update(delta: float, distance_to_target: float) -> bool   # true = このフレームで発射する
var state: int                                    # EnemyState.State
```

- **状態遷移**: `IDLE` →(距離が `detect_range` 以下)→ `TELEGRAPH` →(`telegraph_time` 経過。この 1 フレームだけ真を返す)→ `COOLDOWN` →(`recover_time` 経過)→ `IDLE`
- **事前条件・事後条件・不変条件**: `ChargerBrain`(§5.4)と同じ。`state` の値域は 3 値(`IDLE` / `TELEGRAPH` / `COOLDOWN`)
- 真を返すのは `TELEGRAPH` を抜ける 1 フレームだけであり、`COOLDOWN` の間は常に偽を返す

### 5.6 `Hurtbox`(`Area2D`)

```gdscript
class_name Hurtbox extends Area2D
```

- レイヤ 4(敵)、mask 3(プレイヤーの弾)
- `area_entered` で相手が `damage` プロパティを持つときだけ、所有者(親)の `take_damage(相手の damage)` を呼ぶ
- **`Projectile` を型で見ない**理由: `DamageZone`(unit #2 §5.8)が `has_method(&"take_damage")` で `Player` への静的な依存を避けたのと同じ形にする
- **弾の解放は行わない**。`Projectile` 自身が mask 上の body(レイヤ 4 の `Enemy`)との接触で解放するため、二重に `queue_free()` しない(unit #2 の申し送り)
- **事前条件**: 親が `take_damage(amount: int)` を持つこと。持たない場合は `push_error` を出し、何もしない

### 5.7 `EnemyProjectile`(`Area2D`)

```gdscript
class_name EnemyProjectile extends Area2D
func launch(direction: Vector2, speed: float, damage: int, max_distance: float) -> void
var damage: int
```

- レイヤ 5(敵の弾)、mask 1(地形)+ 2(プレイヤー)
- `launch()` の後、毎フレーム `direction` を正規化した向きへ `speed` で進む
- 地形に触れたら自身を解放する。プレイヤーに触れたら `take_damage(damage)` を呼んでから自身を解放する
- 発射位置からの移動距離が `max_distance` を超えると自身を解放する
- **`direction` が `Vector2`(任意方向)である理由**: 射撃型はプレイヤーへ向けて撃つため、`Projectile`(unit #2 §5.6)の `Vector2i`(8 方向)へ丸めると近距離で明後日の方向へ飛ぶ
- **事前条件**: `direction` は `Vector2.ZERO` でないこと。`speed > 0`、`damage > 0`、`max_distance > 0`。満たさない場合は `push_error` を出し、状態を変えずに返る
- **不変条件**: `damage` は `launch()` で決まり、以後変わらない
- **射程の基準は `launch()` を呼んだ時点の位置**(unit #2 の申し送り)。発射位置を決めてから `launch()` を呼ぶ
- **テストのための公開点**: `frames_moved: int` を公開する。`Projectile`(unit #2)が同じ理由で持つ公開点であり、契約の一部として扱う

### 5.8 `EnemyDevStage`(敵の確認用の仮ステージ)

`StaticBody2D` + `CollisionShape2D` の矩形(床・壁)と `Player`・`ChargerEnemy`・`ShooterEnemy` を配置したシーン。

- `player.died` を受けて `get_tree().reload_current_scene()` を呼ぶ(`DevStage`(unit #2 §5.7)と同じ形。接続はシーンの `[connection]` で宣言する)
- **既存の `dev_stage.tscn` は変更しない**
- 各敵の `target` にシーンの宣言で `Player` を指す(`_ready()` で検索しない。§5.1)
- 敵の配置は §7 Requirement 9 の配置規約を満たす
- **`run/main_scene` は変更しない**(`res://main.tscn` のまま)。起動は `godot --path <プロジェクトのルート> res://src/stage/enemy_dev_stage.tscn` で行い、その手順を `docs/testing.md` へ追記する

### 5.9 `Attackbox`(`Area2D`、突進の攻撃判定)

```gdscript
class_name Attackbox extends Area2D
@export var damage: int
func arm() -> void                                # 与済みの記録を落とす
```

- layer は持たず、mask 2(プレイヤー)
- `monitoring` が真の間に `body_entered` で相手が `take_damage` を持つとき、`take_damage(damage)` を 1 回だけ呼ぶ
- **与済みの記録は `Attackbox` が持つ**。`ChargerEnemy` は `CHARGE` へ入るたびに `arm()` を呼んで記録を落とす。記録の所在を `Attackbox` に置くのは、判定の有無を知っているのが `Attackbox` 自身だからである(貧血な領域にしない)
- **事前条件**: `damage` は正。`arm()` は `monitoring` を真にする前に呼ぶ
- 所有者が撃破された後(`Enemy.is_defeated` が真)は `monitoring` を偽に保つ。`ChargerBrain` の `is_attack_active` が真のままでもこちらが優先する(§7 3.10)
- **エラー**: 相手が `take_damage` を持たない場合は何もしない(`push_error` を出さない)。mask 2 にはプレイヤー以外が載らないため、異常ではなく想定内の素通りとして扱う
- `DamageZone`(unit #2 §5.8)と同じく、相手を型ではなくメソッドの有無で見る

## 6. データ構造

### 6.1 `EnemyStats`(`Resource`)

敵の手触りを決める数値を 1 箇所に集約する。`PlayerStats`(unit #2 §6.1)と同じ方針。2 種の敵はこの型のインスタンス(既定値)を分けて持つ。

```gdscript
class_name EnemyStats extends Resource
@export var max_hp: int = 30
@export var gravity: float = 600.0
@export var move_speed: float = 40.0
@export var detect_range: float = 128.0
@export var telegraph_time: float = 0.4
@export var attack_damage: int = 15
@export var attack_speed: float = 150.0
@export var attack_duration: float = 0.6
@export var recover_time: float = 0.8
@export var bullet_max_distance: float = 0.0
```

**2 種の既定値**:

| 項目 | 突進型 | 射撃型 | 根拠 |
| ---- | -----: | -----: | ---- |
| `max_hp` | 30 | 20 | 主武器(`primary_damage` = 10)で 3 発 / 2 発、副武器(`secondary_damage` = 50)で 1 発。副武器の使いどころが成立する粒度 |
| `gravity` | 600.0 | 600.0 | `PlayerStats.gravity` と揃える。同じ地形の上で落ち方が違うと配置の見当がつかない |
| `move_speed` | 40.0 | 0.0 | プレイヤー(100.0)の 0.4 倍。企画書 2. の「重い機動」。射撃型は定点のため 0.0(移動しないことを表す) |
| `detect_range` | 128.0 | 160.0 | 射撃型は画面の半分(320px の半分)で反応し「距離を取って撃つ」(企画書 7.)。突進型は、検知から予備動作の開始(突進の到達距離 90px)まで `(128 - 90) / 40` = 約 0.95 秒の接近が見える長さにし、企画書 7.「接近して攻撃する」を振る舞いとして表す |
| `telegraph_time` | 0.4 | 0.4 | `CombatLimits.ENEMY_TELEGRAPH_MIN_TIME`(0.4)と同値。企画書 5.「予備動作を目視で識別でき、見てから移動を始めても間に合う」 |
| `attack_damage` | 15 | 10 | `PlayerStats.max_health` = 100 の根拠表が示す「1 発 10〜20、5〜10 発で撃破」の粒度 |
| `attack_speed` | 150.0 | 120.0 | `CombatLimits.ENEMY_BULLET_MAX_SPEED`(150.0)の内側。弾は余裕を残して 120.0、突進は上限そのもの |
| `attack_duration` | 0.6 | 0.0 | 突進の到達距離 `150.0 * 0.6` = 90px。射撃型は突進を持たないため 0.0 |
| `recover_time` | 0.8 | 1.5 | 突進型の硬直 0.8 秒は主武器 0.12 秒間隔で 6 発(60 ダメージ)が入る長さで、撃破の機会になる。射撃型は発射の周期の待ち |
| `bullet_max_distance` | 0.0 | 216.0 | 弾速 120 px/s で 1.8 秒。発射の周期(`telegraph_time` 0.4 + `recover_time` 1.5 = 1.9 秒)より短いため、1 体の射撃型から同時に 2 発が存在しない。画面幅 320px のおよそ 3 分の 2(216 / 320 = 0.675)で、画面を横切る前に消える。突進型は弾を持たないため 0.0 |

- **不変条件**: `max_hp`・`gravity`・`detect_range`・`telegraph_time`・`attack_damage`・`attack_speed` は正。`move_speed`・`attack_duration`・`recover_time`・`bullet_max_distance` は 0 以上とし、**0 は「その振る舞いを持たない」ことを表す**(射撃型の `move_speed`・`attack_duration`、突進型の `bullet_max_distance`)。満たさない値が設定された場合は `Enemy._ready()` の検査で `push_error` を出す
- **既定値の実体は `.tres` に置く**(`src/enemy/charger_stats.tres` / `shooter_stats.tres`)。理由は**編集点の一元化**であり、値の共有・非共有とは無関係である(共有を断つのは `resource_local_to_scene` の有無であって、ファイルが外部か埋め込みかではない。unit #2 の `player.tscn` の申し送りも同じことを述べている)
- **`.tres` は種別ごとに 1 個を全個体で共有する**。`resource_local_to_scene` は使わない。実行時に個体差を与える要件が本単位に無く、複製すると調整のたびに個体ごとの差分を追う必要が生じるためである。同じ種別の敵を 2 体置いた場合、一方の `stats` の項目を変えると他方も変わる
- **`telegraph_time >= CombatLimits.ENEMY_TELEGRAPH_MIN_TIME` と `attack_speed <= CombatLimits.ENEMY_BULLET_MAX_SPEED`** は企画書 5. の条件であり、テストで固定する(§7 Requirement 7)

### 6.2 `EnemyState`

```gdscript
class_name EnemyState extends RefCounted
enum State { IDLE, TELEGRAPH, CHARGE, COOLDOWN, RECOVER }
```

- `ChargerBrain` は `IDLE` / `TELEGRAPH` / `CHARGE` / `RECOVER` を、`ShooterBrain` は `IDLE` / `TELEGRAPH` / `COOLDOWN` を使う
- **1 つの enum を共有する理由**: 撃破時の解析(unit #4)が敵の状態を読む可能性があり、種別ごとに別の enum を置くと読み替えが要る

### 6.3 `EnemyKind`

```gdscript
class_name EnemyKind extends RefCounted
enum Kind { CHARGER, SHOOTER }
```

- `Enemy.defeated(kind)` の引数の型。`analysis-ability`(unit #4)が撃破した敵の種別で分岐するための接点

### 6.4 衝突レイヤの割り当て

unit #2 §6.5 が確定させた表のうち、本単位が使う行を埋める。**割り当ては変えない。**

| ノード | layer | mask |
| ---- | ----: | ---- |
| `Enemy`(`CharacterBody2D`) | 4(敵) | 1(地形) |
| `Hurtbox`(`Area2D`) | 4(敵) | 3(プレイヤーの弾) |
| `Attackbox`(突進の攻撃判定、`Area2D`) | なし | 2(プレイヤー) |
| `EnemyProjectile`(`Area2D`) | 5(敵の弾) | 1(地形)+ 2(プレイヤー) |

- `Attackbox` が layer を持たないのは、`DamageZone`(unit #2 §5.8)と同じ扱いにするためである。レイヤ 5 は「敵の弾」であり、近接の判定に使うと表の意味が崩れる

### 6.5 ファイルの配置

```
src/enemy/      charger_stats.tres, shooter_stats.tres,
                enemy.gd, charger_enemy.tscn, charger_enemy.gd,
                shooter_enemy.tscn, shooter_enemy.gd, enemy_stats.gd,
                charger_brain.gd, shooter_brain.gd, enemy_state.gd, enemy_kind.gd,
                hurtbox.tscn, hurtbox.gd
src/weapon/     enemy_projectile.tscn, enemy_projectile.gd
src/stage/      enemy_dev_stage.tscn, enemy_dev_stage.gd
tests/enemy/    ...
tests/weapon/   ...
tests/stage/    ...
```

- 企画書 12.「プレイヤー・敵・武器・ステージ・ネット空間区間をそれぞれシーン化して再利用可能にする」に沿う
- テストの配置は `docs/testing.md` の規約(実装のディレクトリ構成を写す)に従う
- 敵弾を `src/weapon/` へ置くのは、プレイヤーの弾(`projectile.gd`)と同じ関心だからである

## 7. 振る舞い(受け入れ基準)

### Requirement 1: 敵の共通の体力と撃破

**対象**: §5.1 `Enemy` / §5.2 `ChargerEnemy` / §5.3 `ShooterEnemy` / §6.1 `EnemyStats` / §6.3 `EnemyKind`

**受け入れ基準**:

**検証の形式**: 1.1〜1.11 と 1.23 は敵をツリーへ載せずに直接呼んで検証する(物理フレーム不要)。1.12・1.13 は `instantiate()` + `auto_free()` でシーンの構成を読む。1.14〜1.22 はツリーへ載せて物理フレームを進める。1.21 は `target` に位置を制御できるスタブ(`Node2D`)を注入し、規定のフレーム数を過ぎたら索敵範囲の外へ動かして移動を打ち切ることで、消化したフレーム数と変位を対応付ける(unit #2 の `input_source` スタブと同じ形。`docs/testing.md`「消化したフレーム数をアサーションで確かめる」)。

1.1. システムは、`hp` の初期値を `stats.max_hp` としなければならない。(常時)
1.2. 正の `amount` で `take_damage()` が呼ばれたとき、システムは `hp` を `amount` だけ減らさなければならない。(イベント)
1.3. システムは、`hp` を 0 未満にしてはならない。(常時)
1.4. `hp` が 0 になったとき、システムは `defeated` を撃破した敵の種別を引数にして 1 回だけ発火しなければならない。(イベント)
1.5. `hp` が 0 になったとき、システムは `is_defeated` を真にしなければならない。(イベント)
1.6. `is_defeated` が真の状態で `take_damage()` が呼ばれた場合、システムは `hp` を変えず `defeated` を発火してはならない。(異常系)
1.7. `amount` が 0 以下の値で `take_damage()` が呼ばれた場合、システムは `push_error` を出し `hp` を変えずに返らなければならない。(異常系)
1.8. `stats` が未設定のまま `_ready()` が呼ばれた場合、システムは `push_error` を出し、既定値の `EnemyStats` へフォールバックしなければならない。(異常系)
1.9. `stats` の数値項目が §6.1 の不変条件を満たさない状態で `_ready()` が呼ばれた場合、システムは項目名と現在値を添えて `push_error` を出さなければならない(値は補正しない)。(異常系)
1.10. `hp` が 0 になったとき、システムは `defeated` を発火し `is_defeated` を真にした**後で**自身を解放しなければならない(解放より先に発火する)。(イベント)
1.11. システムは、突進型の `kind()` を `EnemyKind.Kind.CHARGER`、射撃型の `kind()` を `EnemyKind.Kind.SHOOTER` としなければならない。(常時)
1.12. システムは、`ColorRect` と `CollisionShape2D` をともに 16×16px とし、ノードの原点を矩形の中心に置かなければならない。(常時)
1.13. システムは、`Hurtbox` の形状を本体の衝突形状と同じ矩形とし、本体の外へはみ出させてはならない。(常時)
1.14. `target` が `null` または解放済みの状態で物理フレームが進む場合、システムは `push_error` を出さず、標的までの距離を `INF` として扱わなければならない。(異常系)
1.15. `brain.state` が `IDLE` の状態で `target` が `null` である間、システムは水平の速度を 0 とし、`state` を `IDLE` のまま保たなければならない(`IDLE` 以外の状態で標的を失った場合は 2.7 が優先する)。(状態)
1.16. システムは、`target` を外から代入できる公開点として保たなければならない(内部で標的を検索して上書きしない)。(常時)
1.17. `is_on_floor()` が偽の間、システムは垂直の速度を毎物理フレーム `stats.gravity * delta` だけ増やさなければならない。(状態)
1.18. `is_on_floor()` が真の間、システムは垂直の速度を 0 としなければならない(接地中に重力が蓄積しないようにする)。(状態)
1.19. システムは、`_physics_process` で速度を決めた後に `move_and_slide()` を呼ばなければならない。(常時)
1.20. システムは、`ChargerBrain.update()`・`ShooterBrain.update()` の中で `move_and_slide()` を呼んではならない。(常時)
1.21. 水平の速度を持つ敵がシーンツリーの上で 3 物理フレームぶん進んだとき、システムは水平の位置をその速度と `Engine.physics_ticks_per_second` から定まる値だけ変えなければならない(許容差 0.001)。(イベント)
1.22. システムは、`brain` を外から読める公開点として持たなければならない。(常時)
1.23. `Enemy` を直接生成した場合、システムは `kind()` に `EnemyKind.Kind.CHARGER` を返させなければならない。(常時)

### Requirement 2: 突進型の状態遷移

**対象**: §5.4 `ChargerBrain` / §6.2 `EnemyState`

**受け入れ基準**:

**検証の形式**: `ChargerBrain` は `RefCounted` であり、`update()` を直接呼んで `state` と `is_attack_active` を検証する(物理フレーム不要)。滞在時間の定数は 2 進で厳密に表せる値を使う(unit #2 の申し送り)。

2.1. システムは、`state` の初期値を `IDLE` としなければならない。(常時)
2.2. `IDLE` の状態で距離が突進の到達距離(`attack_speed * attack_duration`)より大きい間、システムは `state` を `IDLE` のまま保たなければならない。(状態)
2.3. `IDLE` の状態で距離が突進の到達距離以下になったとき、システムは `state` を `TELEGRAPH` にしなければならない。(イベント)
2.4. `TELEGRAPH` の状態で滞在時間が `telegraph_time` に達し、かつ `distance_to_target` が有限のとき、システムは `state` を `CHARGE` にしなければならない。(イベント)
2.5. `CHARGE` の状態で滞在時間が `attack_duration` に達したとき、システムは `state` を `RECOVER` にしなければならない。(イベント)
2.6. `RECOVER` の状態で滞在時間が `recover_time` に達したとき、システムは `state` を `IDLE` にしなければならない。(イベント)
2.7. `TELEGRAPH`・`CHARGE`・`RECOVER` の間、システムは距離の変化によって滞在時間の満了より前に遷移させてはならない(満了時の遷移先が距離で変わることは 2.11 が定める)。(状態)
2.8. システムは、`is_attack_active` を `state` が `CHARGE` のときだけ真としなければならない。(常時)
2.9. 状態が遷移したフレームにおいて、システムは消化した `delta` を遷移先の滞在時間へ数えてはならない。(状態)
2.10. `delta` が 0 以下、または `distance_to_target` が負の値で `update()` が呼ばれた場合、システムは `push_error` を出し `state` と `is_attack_active` を変えずに返らなければならない。(異常系)
2.11. `TELEGRAPH` の状態で滞在時間が `telegraph_time` に達したとき、`distance_to_target` が `INF` の場合、システムは `push_error` を出さず `state` を `RECOVER` にしなければならない(標的を失った回の突進を取りやめる)。(異常系)

### Requirement 3: 突進型の移動と攻撃判定

**対象**: §5.2 `ChargerEnemy` / §5.9 `Attackbox` / §6.4 衝突レイヤの割り当て

**受け入れ基準**:

3.1. `IDLE` の状態で距離が `detect_range` 以下のとき、システムは水平の速度を `stats.move_speed` で標的の側へ向けなければならない。(イベント)
3.2. `IDLE` の状態で距離が `detect_range` より大きいとき、システムは水平の速度を 0 としなければならない。(イベント)
3.3. `TELEGRAPH` と `RECOVER` の間、システムは水平の速度を 0 としなければならない。(状態)
3.4. `CHARGE` の間、システムは水平の速度を、突進を始めた時点の標的の側の向きへ `stats.attack_speed` としなければならない(突進中に向きを変えない)。(状態)
3.5. `is_defeated` が偽の間、システムは `Attackbox` の `monitoring` を `brain.is_attack_active` に一致させなければならない(撃破された後は 3.10 が支配する)。(状態)
3.6. `CHARGE` の間に `Attackbox` がプレイヤーに触れたとき、システムはプレイヤーの `take_damage(stats.attack_damage)` を 1 回だけ呼ばなければならない。(イベント)
3.7. 1 回の突進の間にプレイヤーへ触れ続ける場合、システムはダメージを 2 回以上与えてはならない。(状態)
3.8. 新たに `CHARGE` へ入ったとき、システムはダメージを与済みとする記録を落とし、再びダメージを与えられる状態にしなければならない。(イベント)
3.9. `Attackbox` が触れた相手が `take_damage` を持たない場合、システムは何もしてはならない。(異常系)
3.10. `is_defeated` が真になったとき、システムは同じ物理フレームのうちに `Attackbox` の `monitoring` を偽にしなければならない(撃破された敵が解放までの間にダメージを与えない)。(イベント)

### Requirement 4: 射撃型の状態遷移と発射

**対象**: §5.5 `ShooterBrain` / §5.3 `ShooterEnemy`

**受け入れ基準**:

4.1. システムは、`state` の初期値を `IDLE` としなければならない。(常時)
4.2. `IDLE` の状態で距離が `detect_range` 以下になったとき、システムは `state` を `TELEGRAPH` にしなければならない。(イベント)
4.3. `TELEGRAPH` の状態で滞在時間が `telegraph_time` に達したとき、システムは真を返し、`state` を `COOLDOWN` にしなければならない。(イベント)
4.4. `COOLDOWN` の間、システムは偽を返し続けなければならない。(状態)
4.5. `COOLDOWN` の状態で滞在時間が `recover_time` に達したとき、システムは `state` を `IDLE` にしなければならない。(イベント)
4.6. システムは、真を返すフレームを `TELEGRAPH` を抜ける 1 フレームだけに限らなければならない。(常時)
4.7. `update()` が真を返したフレームで `target` が存在し、かつ `projectile_scene` が設定されているとき、システムは敵弾を 1 発生成し、標的へ向かう単位ベクトルの向きへ `stats.attack_speed`・`stats.attack_damage`・`stats.bullet_max_distance` で発射しなければならない。(イベント)
4.8. システムは、射撃型の水平の速度を常に 0 としなければならない。(常時)
4.9. `projectile_scene` が未設定の状態で発射のフレームに達した場合、システムは `push_error` を出し、弾を生成してはならない。(異常系)
4.10. `delta` が 0 以下、または `distance_to_target` が負の値で `update()` が呼ばれた場合、システムは `push_error` を出し `state` を変えず偽を返さなければならない。(異常系)
4.11. `TELEGRAPH`・`COOLDOWN` の間、システムは距離の変化によって滞在時間の満了より前に遷移させてはならない。(状態)
4.12. 状態が遷移したフレームにおいて、システムは消化した `delta` を遷移先の滞在時間へ数えてはならない。(状態)
4.13. `update()` が真を返したフレームで `target` が `null` または解放済みの場合、システムは弾を生成せず、`push_error` を出さずに `COOLDOWN` へ移らなければならない。(異常系)
4.14. システムは、敵弾を自分の親(`get_parent()`)へ追加し、発射位置を敵自身の位置に決めてから `launch()` を呼ばなければならない(`launch()` の後に位置を動かさない)。(常時)

### Requirement 5: 敵弾

**対象**: §5.7 `EnemyProjectile` / §6.4 衝突レイヤの割り当て

**受け入れ基準**:

**検証の形式**: 距離・速さ・射程を検証するテストには斜めの方向のケースを必ず含める(unit #2 の申し送り。軸方向だけでは距離の算出の変異が素通りする)。

5.1. `launch()` が呼ばれたとき、システムは毎物理フレーム `direction` を正規化した向きへ `speed * delta` だけ進まなければならない。(イベント)
5.2. `launch()` を呼んだ時点の位置からの移動距離が `max_distance` を超えたとき、システムは自身を解放しなければならない。(イベント)
5.3. 敵弾が地形に触れたとき、システムは自身を解放しなければならない。(イベント)
5.4. 敵弾がプレイヤーに触れたとき、システムはプレイヤーの `take_damage(damage)` を呼んでから自身を解放しなければならない。(イベント)
5.5. システムは、`damage` を `launch()` で受け取った値に固定し、以後変えてはならない。(常時)
5.6. `direction` が `Vector2.ZERO`、または `speed`・`damage`・`max_distance` のいずれかが 0 以下の状態で `launch()` が呼ばれた場合、システムは `push_error` を出し、`damage` を含む状態を変えずに返らなければならない。(異常系)
5.7. システムは、`frames_moved` を `launch()` の後に進めた物理フレーム数としなければならない。(常時)
5.8. `launch()` が呼ばれていない間、システムは移動してはならない。(状態)

### Requirement 6: プレイヤーの弾による被弾

**対象**: §5.6 `Hurtbox` / §5.1 `Enemy`

**受け入れ基準**:

6.1. `Hurtbox` に `damage` プロパティを持つ領域が入ったとき、システムは親の `take_damage(相手の damage)` を呼ばなければならない。(イベント)
6.2. `Hurtbox` に入った領域が `damage` プロパティを持たない場合、システムは何もしてはならない。(異常系)
6.3. システムは、`Hurtbox` から弾を解放してはならない(弾の解放は弾自身が行う)。(常時)
6.4. プレイヤーの弾が敵に当たったとき、システムは敵の `hp` を弾の `damage` だけ減らし、かつ弾を解放しなければならない。(イベント)
6.5. 親が `take_damage` を持たない状態で領域が入った場合、システムは `push_error` を出し、何もしてはならない。(異常系)
6.6. 主武器の弾(`primary_damage` = 10)が突進型に 3 発当たったとき、システムは `defeated` を発火しなければならない。(イベント)

### Requirement 7: 敵の攻撃の上限への準拠

**対象**: §6.1 `EnemyStats` / unit #2 §6.2 `CombatLimits`

**受け入れ基準**:

7.1. システムは、2 種の敵の `telegraph_time` を `CombatLimits.ENEMY_TELEGRAPH_MIN_TIME` 以上としなければならない。(常時)
7.2. システムは、2 種の敵の `attack_speed` を `CombatLimits.ENEMY_BULLET_MAX_SPEED` 以下としなければならない。(常時)
7.3. システムは、`CombatLimits` の 2 つの定数を変更してはならない。(常時)

### Requirement 8: 敵の数値の集約

**対象**: §6.1 `EnemyStats`

**受け入れ基準**:

8.1. システムは、敵の手触りを決める数値を `EnemyStats` の項目としてのみ保持しなければならない(実装のコードへ直書きしない)。(常時)
8.2. システムは、種別ごとに 1 個の `EnemyStats` を全個体で共有しなければならない(`resource_local_to_scene` を使わない)。(常時)
8.3. `move_speed`・`attack_duration`・`bullet_max_distance` に 0.0 が設定されたとき、システムはこれを「その振る舞いを持たない」として扱い、`push_error` を出してはならない。(イベント)
8.4. 0 を許す項目(`move_speed`・`attack_duration`・`bullet_max_distance`)以外の数値項目に 0 以下が設定された状態で `_ready()` が呼ばれた場合、システムは `push_error` を出さなければならない。検査の対象は `get_property_list()` から導き、0 を許す項目名の集合だけを実装が持たなければならない(項目名を固定で列挙しない)。(異常系)
8.5. システムは、突進型・射撃型の既定値を §6.1 の表のとおりとしなければならない。(常時)
8.6. システムは、射撃型の弾の寿命(`bullet_max_distance / attack_speed`)を、発射の周期(`telegraph_time + recover_time`)より短くしなければならない(1 体の射撃型から同時に 2 発を存在させない)。(常時)
8.7. システムは、既定値の実体を `.tres` として持ち、シーンへ埋め込むサブリソースにしてはならない。(常時)

### Requirement 9: 仮ステージと配置規約

**対象**: §5.8 `EnemyDevStage` / §5.3 `ShooterEnemy` / §6.5 ファイルの配置

**受け入れ基準**:

**検証の形式**: シーンの構成を検証するテストはツリーへ載せない(`instantiate()` + `auto_free()` だけで位置・レイヤ・子ノードの型を読む。unit #2 の申し送り)。

9.1. システムは、床・壁と `Player`・`ChargerEnemy`・`ShooterEnemy` を配置したシーンを 1 つ持たなければならない。(常時)
9.2. システムは、プレイヤーの初期位置から敵の位置までの距離が `160 + その敵の detect_range` 以下となる敵を、2 体までとしなければならない(索敵範囲の円が脅威の圏と交わる敵の数)。(常時)
9.3. `player.died` が発火したとき、システムは現在のシーンを再読込しなければならない。(イベント)**この基準は自動テストでは検証せず**、`godot --path <プロジェクトのルート> res://src/stage/enemy_dev_stage.tscn` で起動して目視で確認し、結果を `tasks.md` の `## Implementation Notes` に記録する(理由: gdUnit4 のテストツリーで `reload_current_scene()` を呼ぶと、テストの実行そのものが読み込むシーンを差し替える。unit #2 の 7.2 と同じ扱い)。
9.4. システムは、`died` の接続をシーンの `[connection]` として宣言しなければならない(`_ready()` で接続しない)。(常時)
9.5. システムは、既存の `dev_stage.tscn` を変更してはならない。(常時)
9.6. システムは、敵の出現を動的に行う仕組み(スポナー)を持ってはならない。(常時)
9.7. システムは、`run/main_scene` を `res://main.tscn` から変更してはならない。(常時)
9.8. システムは、`docs/testing.md` に `enemy_dev_stage.tscn` の起動方法を追記しなければならない(既存の「仮ステージを目視で確認する」の節に並べる)。(常時)
9.9. システムは、`enemy_dev_stage.tscn` の各敵の `target` をシーンの宣言で `Player` ノードへ指さなければならない(`_ready()` で検索しない)。(常時)
9.10. システムは、`shooter_enemy.tscn` の `projectile_scene` に `enemy_projectile.tscn` を設定しなければならない。(常時)
9.11. システムは、§6.5 のファイルの配置とテストの配置の規約(`docs/testing.md`)に従わなければならない。(常時)

### Requirement 10: 衝突レイヤの割り当て

**対象**: §6.4 衝突レイヤの割り当て

**受け入れ基準**:

10.1. システムは、`Enemy` の layer を 4、mask を 1 としなければならない。(常時)
10.2. システムは、`Hurtbox` の layer を 4、mask を 3 としなければならない。(常時)
10.3. システムは、`Attackbox` の layer を 0(なし)、mask を 2 としなければならない。(常時)
10.4. システムは、`EnemyProjectile` の layer を 5、mask を 1(地形)と 2(プレイヤー)としなければならない。(常時)
10.5. システムは、unit #2 §6.5 が定めたレイヤ 1〜3 の割り当てを変更してはならない。(常時)

## 8. 実現方針(要点のみ)

- **純ロジックと配線を分ける**: 状態遷移(`ChargerBrain`・`ShooterBrain`)を `RefCounted` に切り出し、`update()` を直接呼ぶテストで検証する。ノード(`ChargerEnemy`・`ShooterEnemy`)は速度への写像と攻撃判定の切り替えだけを持つ。unit #2 の `PrimaryWeapon`・`SecondaryWeapon`・`Health` と同じ分業である。
- **凍結済みの契約に触れない**: `Projectile`(unit #2 §5.6)は変更せず、被弾の適用を敵側(`Hurtbox`)で受け取る。弾の解放は `Projectile` 自身の `body_entered` に任せる。
- **相手を型ではなくメソッド・プロパティの有無で見る**: `Attackbox` と `EnemyProjectile` は `has_method(&"take_damage")` で、`Hurtbox` は `damage` プロパティの有無で相手を判別する。`DamageZone`(unit #2 §5.8)と同じ形で、単位を跨ぐ静的な依存を作らない。
- **滞在時間の判定は `delta` を足す前に行う**: 同じ `delta` を 2 つの状態へ数えると、予備動作から攻撃までが `telegraph_time` より短くなる。unit #2 の `Health`・`SecondaryWeapon` が採った形に揃える。
- **`move_and_slide()` は `_physics_process` の中だけで呼ぶ**: unit #2 が実測で確かめた検証済みの前提(テスト本体から呼ぶと描画フレームの `delta` が使われ、100 px/s・3 回で期待 5.0px に対し 2.37px・10.58px と割れた。同 spec §3)に従う。`Brain` は純ロジックであり移動を行わない(§7 1.19・1.20)。
- **用語集は持たない**: プロジェクトに `docs/glossary.md` が無いため、既存コードの語彙(`stats`・`take_damage`・`damage`)に合わせる。
- **`EnemyState` の 5 値を 2 種で共有する**: 種別ごとに enum を分けると unit #4 が読み替えを要する。使わない値を持つことを許す。

## 9. 参考資料

- 企画書 5.(プレイヤー)・6.(武器)・7.(敵・ボス)・12.(技術)— workspace リポジトリの `4_artifacts/netdiver/issues/01_game-design-doc/game-design-doc.md`
- `docs/specs/001-mvp/roadmap.md` 1.1「3. `foot-enemies`」(範囲と完了条件)、同 4.(凍結済み unit の相互参照の読み替え)
- `docs/specs/001-mvp/002-foot-player/spec.md` §5.6(`Projectile`)・§6.1(`PlayerStats`)・§6.2(`CombatLimits`)・§6.5(衝突レイヤ)
- `docs/specs/001-mvp/002-foot-player/tasks.md` の `## Implementation Notes`(弾の解放・`frames_moved`・引数の検査の非対称・`Area2D` の通知の遅れ)
- `docs/testing.md`(テストの配置と命名、物理フレームを進めるテストの規約)
