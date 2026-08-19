# analysis-ability — 壁打ちの調査ログと契約のドラフト

`spec.md` の生成前に、既存コードの実シグネチャの確認と契約のドラフトを行った記録である。
確定した `spec.md` が生成された時点で、本書は経緯の記録になる。

## 1. 人間から得た回答(Q1〜Q8)

| 問い | 回答 |
| :- | :- |
| Q1. 解析の対象の種別 | 射撃型(`EnemyKind.Kind.SHOOTER`)のみ |
| Q2. 能力の効果 | 拡散弾(射撃方向とその左右隣の 3 方向へ同時に撃つ) |
| Q3. 第 3 の枠の入力 | `fire_secondary` を共有し、能力を持つ間だけ副武器の枠が能力へ切り替わる |
| Q4. 使用の制約 | 有限回数で使い切ると空枠へ戻る / 副武器と同程度のクールダウン / 数値は `PlayerStats` へ |
| Q5. 演出 | 0.3〜0.5 秒の遅延・操作を止めない・撃破位置からプレイヤーへ飛ぶ単色矩形。HUD は新設しない |
| Q6. 取得と置き換え | 同種別の再取得は上書き / 初期は空枠で無反応(`push_error` を出さない) / 対象外の種別では枠が変化しない / 使い切りは空枠へ戻り初期状態と区別しない |
| Q7. 仮ステージ | `analysis_dev_stage.tscn` を新設する |
| Q8. 配線 | 仮ステージが各敵の `defeated` を受けて中継する(Autoload を増やさない) |

**企画書の扱い**: 企画書 6. は「武器の追加・**切り替え**として扱う」と両方の扱いを挙げ、「第 3 の枠に加える」形を**暫定**としている。Q3=B は企画書が示す扱いのうち「切り替え」を採り、暫定を動かす決定である(企画書に反する決定ではない)。企画書 5. の「操作を 4 つに限る」原則はそのまま保たれる。企画書本体の更新は workspace 側で行う。

## 2. 既存コードの実シグネチャ(確認済み)

- `Enemy.defeated(kind: int)` は `queue_free()` より**先に**発火する(`src/enemy/enemy.gd:65-66`)。`tests/enemy/enemy_test.gd::test_defeated_is_emitted_before_the_enemy_is_released` が固定済み。**受け手のハンドラの中で撃破された敵の `global_position` を読める。**
- `Player.fired(direction: Vector2i, is_secondary: bool)` の発火点は `player.gd:140` の 1 箇所のみ。実装側の受け手は無く、観測しているのは `tests/player/player_weapon_test.gd` だけ。
- `SecondaryWeapon.update(held, delta)` は、充電が満ちた状態で `held=false` を受けたフレームに真を返す(`secondary_weapon.gd:40-49`)。`charge_ratio` は unit #2 §5.5 が「演出と UI のため」と定める公開の**読み取り**点。
- `PlayerStats` の項目追加は unit #2 のテストを壊さない(`test_player_stats_exposes_every_stat_to_the_inspector` は `contains`(非排他)、`test_player_stats_defaults_are_all_positive` は固定リスト `STAT_NAMES` を走査する)。
- `Player._report_non_positive_stats()` は `get_property_list()` の全数値項目に `> 0` を課す。`Enemy` の `ZERO_ALLOWED_STAT_NAMES` に相当する仕組みは `PlayerStats` に無い。
- `AimResolver.resolve()` の事後条件は「8 方向のいずれか。`Vector2i.ZERO` を返さない」。
- `tests/stage/enemy_dev_stage_test.gd` は `EnemyDevStage` の子を 5 つで厳密に固定し、`PackedScene` 参照を 2 件に限り、スクリプトが変数を持たないことまで検査する。**拡張すると unit #3 の凍結済み要件の実行形が壊れる**(Q7 で新設を選んだ根拠)。

## 3. 壁打ちで決めた点

### 3.1 拡散弾の発射の形 → 押下の縁で即発射 + クールダウン(選択 1 として人間へ差し戻す)

`AbilitySlot` が押下の縁を自前で検出することで、`PlayerCommand` に `secondary_pressed` を足さずに済む(凍結済み unit #2 §6.3 を変更しない)。

### 3.2 枠の切り替え時の副武器の扱い → 「ボタンを離した」として扱う(選択 2 として人間へ差し戻す)

占有の間、`Player` は副武器へ `update(false, delta)` を渡す。結果として:

- 充電が満ちていないぶんは捨てられる(`SecondaryWeapon` 自身の規律どおり)
- クールダウンは占有中も実時間で進む(取得でクールダウンを踏み倒せない)
- `SecondaryWeapon` にも `charge_ratio` にも書き込まない(凍結済み契約に触れない)
- **占有の開始のフレームに限り、満ちていた充電が 1 発として発射されうる**

### 3.3 使い切って空枠へ戻ったときの副武器 → その時点の状態のまま再開する

3.2 の帰結。占有中も時間が進むため、「どこから再開するか」を別に定める必要が無い。

### 3.4 `Player.fired` の扱い → 第 3 の枠では発火させず、`ability_fired` を新設する

`fired(direction, is_secondary)` は bool 1 個であり 3 つ目の枠を表せない。引数を増やすと凍結済み unit #2 §5.1 の意味が変わる。第 3 の枠は `ability_fired(directions: Array[Vector2i])` を **1 回**発火する(1 回の発射で 3 発、という能力の単位に一致する)。

`directions` を配列で運ぶため、3 方向の内容そのものをテストが固定できる(定数へ縮退させる変異を落とす。unit #3 の申し送り 4.3)。「能力の弾を副武器として出す」変異は、`fired` が発火することと `ability_fired` が発火しないことの**両方**で落ちる。

### 3.5 凍結済み契約の拡張の範囲(Q3=B の前提で取り直した結果)

| 凍結済みの契約 | 前ターンの想定 | Q3=B での結論 |
| :- | :- | :- |
| `PlayerInput`(unit #2 §5.2、7 アクション) | 拡張(8 個目を追加) | **拡張不要**(新しい入力アクションが要らない) |
| `PlayerCommand`(同 §6.3、5 項目) | 拡張(1 項目を追加) | **拡張不要**(押下の縁は `AbilitySlot` が検出する) |
| `Player.fired`(同 §5.1) | 引数の拡張を検討 | **拡張不要**(第 3 の枠は別のシグナルで表す) |
| `PlayerStats`(同 §6.1、14 項目) | 拡張 | **拡張が必要**(4 項目を追加) |
| `Player`(同 §5.1) | 拡張 | **拡張が必要**(シグナル 1・公開の状態 1・関数 1 を追加) |
| `SecondaryWeapon`(同 §5.5) | 変更不要 | **変更不要**(切り替えを「離した」として扱うため) |
| `Projectile`(同 §5.6) | 変更不要 | **変更不要**(能力の弾として流用する) |
| 衝突レイヤ(同 §6.5 / unit #3 §6.4) | 追加不要 | **追加不要**(能力の弾は layer 3 / mask 1・4) |
| `Enemy.defeated`(unit #3 §5.1) | 変更不要 | **変更不要**(位置はハンドラの中で敵ノードから読む) |

## 4. 契約のドラフト

### 4.1 `AbilitySlot`(`RefCounted`、純ロジック)

```gdscript
class_name AbilitySlot extends RefCounted

var remaining_uses: int      # 0 なら空
var is_empty: bool           # remaining_uses == 0

func _init(cooldown: float) -> void
func grant(uses: int) -> void
func update(held: bool, delta: float) -> bool
```

- `_init()` は引数を検査しない(値の出どころは `PlayerStats`。`PrimaryWeapon`・`SecondaryWeapon` と同じ規律)。生成直後は空。
- `grant(uses)` は残り回数を `uses` で**上書き**し、クールダウンを明けた状態にする(取得の直後の 1 発目で待たされない。生成直後の `PrimaryWeapon` と同じ)。事前条件: `uses` は正。0 以下なら `push_error` を出し状態を変えない。
- `update(held, delta)` は、押下の縁(前フレームが偽・今フレームが真)でクールダウンが明けており残り回数が正のとき、残り回数を 1 減らしクールダウンを数え直して真を返す。それ以外は偽。**空のフレームでも押下の状態は記録する**(記録しないと、取得の時点で押しっぱなしのボタンが縁と誤認されて暴発する)。`delta` を検査しないのは `Player.apply_command()` が既に弾いているため。
- 事後条件: `remaining_uses >= 0`。真を返す間隔は常に `cooldown` 以上。真を返した直後は残り回数が 1 減っている。

### 4.2 `SpreadResolver`(static、純粋関数)

```gdscript
class_name SpreadResolver extends RefCounted
static func resolve(direction: Vector2i) -> Array[Vector2i]
```

- 8 方向を時計回りに並べた環の上で、`direction` とその両隣を返す。並びは `[中央, 反時計回りの隣, 時計回りの隣]` に固定する。
- 事前条件: `direction` は 8 方向のいずれか。違反なら `push_error` を出し**空の配列**を返す。
- 事後条件: 戻り値は 3 要素、相異なる 8 方向、`Vector2i.ZERO` を含まない。
- `AimResolver.resolve()` の事後条件により、実際の経路では事前条件を破れない。

### 4.3 `AbilityAnalysis`(static、純粋関数)

```gdscript
class_name AbilityAnalysis extends RefCounted
static func is_transferable(kind: int) -> bool
```

- `SHOOTER` なら真、`CHARGER` なら偽、`EnemyKind.Kind` に無い値なら `push_error` を出し偽。
- 種別で分岐する**唯一の場所**とする。`Player` を `src/enemy/` へ静的に依存させない(`Attackbox` が `Player` を型で見ない規律と同じ)。両方の種別にテストのケースを割り当てる(unit #3 の申し送り 4.2・4.3)。

### 4.4 `AnalysisPulse`(`Node2D`、演出)

```gdscript
class_name AnalysisPulse extends Node2D
signal arrived(kind: int)
@export var flight_time: float
func launch(kind: int, from: Vector2, to: Node2D) -> void
```

- `launch()` の後、毎物理フレームで経過時間を進め、位置を `from` から `to.global_position` へ比 `経過 / flight_time` で補間する。**標的の現在位置へ補間する**(発射時の位置を目標にすると、動いている標的から離れて着く)。
- 経過が `flight_time` に達したら `arrived(kind)` を発火して自己解放する。
- 位置の更新は `_physics_process` の中だけで行う(既存の弾と同じ規律)。当たり判定を持たない(`Node2D` + `ColorRect`)。時間を止める処理を持たない(操作を止めない)。
- 事前条件: `flight_time` は正、`to` は有効。違反なら `push_error` を出し、`arrived` を発火せずに自己解放する。
- 標的が到達前に無効になったら、`arrived` を発火せずに自己解放する。
- 複数の演出が同時に飛ぶことを許す。到達順に `grant` が走り、後の到達が前の取得を上書きする(Q6)。

### 4.5 `Player`(unit #2 §5.1 の拡張)

```gdscript
signal ability_fired(directions: Array[Vector2i])   # 追加
var ability_slot: AbilitySlot                       # 追加(公開の観測点)
func grant_ability() -> void                        # 追加
```

- `grant_ability()` は `ability_slot.grant(stats.ability_uses)` を呼ぶ。事後条件: `remaining_uses == stats.ability_uses`、クールダウンは明けた状態。**種別を引数に取らない**(判断は `AbilityAnalysis` にある)。
- `_update_weapons()` の拡張:
  - 第 3 の枠は毎フレーム `ability_slot.update(cmd.secondary_held, delta)` を受ける(空でも呼ぶ)。
  - 枠が空でない間、副武器へは `update(false, delta)` を渡す(3.2)。
  - 真を返したフレームで `SpreadResolver.resolve(direction)` の 3 方向へ `Projectile` を 3 発生成し、`ability_fired(directions)` を 1 回発火する。弾には `ability_damage`・`ability_bullet_speed`・既存の `bullet_max_distance` を与える。
  - **第 3 の枠の発射で `fired` を発火しない**(3.4)。
- 主武器の振る舞いは変えない(枠の占有は副武器の側だけに効く)。

### 4.6 `AnalysisDevStage`(`Node2D`、解析の確認用の仮ステージ)

```gdscript
class_name AnalysisDevStage extends Node2D
@export var pulse_scene: PackedScene
```

- `_ready()` で `Enemy` である子ノードを走査し、各 `defeated` を自分のハンドラへその敵を bind して接続する。宣言(`[connection]`)で接続しない理由: ハンドラは撃破位置を必要とし、`defeated` は種別しか運ばないため敵ごとの bind が要る(unit #3 の 9.4 との非対称は、この技術的な理由による)。
- ハンドラは撃破された敵の `global_position` を始点に `AnalysisPulse` を生成し、`Player` へ向けて `launch()` する。**ここでは種別で分岐しない**(解析はどちらの種別でも走る)。
- `pulse.arrived(kind)` を受け、`AbilityAnalysis.is_transferable(kind)` が真のときだけ `player.grant_ability()` を呼ぶ。
- `player.died` は `[connection]` で宣言し、`get_tree().reload_current_scene.call_deferred()` を呼ぶ(unit #3 の申し送り)。
- 敵の動的な出現(スポナー)を持たない。「同時に対処を要求する攻撃は 2 つまで」の配置規約に従う。

### 4.7 `PlayerStats` の拡張(unit #2 §6.1)

```gdscript
@export var ability_uses: int = 3
@export var ability_cooldown: float = 1.5
@export var ability_damage: int = 20
@export var ability_bullet_speed: float = 300.0
```

| 項目 | 既定値 | 根拠 |
| :- | -: | :- |
| `ability_uses` | 3 | 1 種の資源として使い切るまでを数秒に収める。企画書 13. の「後半ほど手数が増えて難度の設計が崩れる」を、置き換えに加えて消費でも抑える |
| `ability_cooldown` | 1.5 | 副武器の実質周期(充電 0.8 + クールダウン 2.0 = 2.8 秒)より短いが連射ではない。3 発を約 3 秒で使い切る |
| `ability_damage` | 20 | 主武器 10・副武器 50 の間。3 方向すべてが当たる近距離で 60、1 方向なら主武器 2 発分 |
| `ability_bullet_speed` | 300.0 | 副武器と同じ。主武器の 400 より遅く、拡散の広がりを目で追える |

- 射程は既存の `bullet_max_distance`(400.0)を流用し、項目を増やさない。
- **不変条件**: 追加する 4 項目もすべて正。**0 に意味を持たせる項目を作らない**(`Player._report_non_positive_stats()` が全数値項目に `> 0` を課しており、0 を許す仕組みが `PlayerStats` に無い。unit #2 の申し送りにある退化を持ち込まない)。
- 演出の数値(`flight_time = 0.4`)は `PlayerStats` に置かず `AnalysisPulse` の `@export` とする。プレイヤーの手触りではなく解析の見え方であるため。

### 4.8 ファイルの配置(案)

```
src/ability/    ability_slot.gd, spread_resolver.gd, ability_analysis.gd,
                analysis_pulse.gd, analysis_pulse.tscn
src/stage/      analysis_dev_stage.gd, analysis_dev_stage.tscn
tests/ability/  ability_slot_test.gd, spread_resolver_test.gd,
                ability_analysis_test.gd, analysis_pulse_test.gd
tests/stage/    analysis_dev_stage_test.gd
```

変更する既存ファイル: `src/player/player.gd`、`src/player/player_stats.gd`、`docs/testing.md`(新しい仮ステージの起動方法)。
弾のシーンは新設せず `src/weapon/projectile.tscn` を流用する。

## 5. 人間の判断が残っている選択

1. 拡散弾の発射の形(押下の縁で即発射 / 副武器と同じくチャージして離す)
2. 枠の切り替え時の副武器の扱い(「離した」として扱う / 凍結する / 作り直す)
3. 写せない種別(突進型)を撃破したときに演出を出すか(出す / 出さない)

## 6. 新しく採用した前提(未検証)

- 追加する 4 項目の既定値が、取得が報酬に感じられ、かつ難度を崩さない粒度として成立する — 検証方法: `analysis_dev_stage.tscn` で実際に撃って確かめる / 状態: 未検証
- 演出の飛翔 0.4 秒が「撃破と取得が繋がって見える」長さとして成立する — 検証方法: 同上 / 状態: 未検証
- 拡散の 3 方向が 8 方向の環の隣接(45 度刻み)で「拡散」として成立する — 検証方法: 同上 / 状態: 未検証
- `Enemy` の子を `_ready()` で走査して `defeated` を bind 付きで接続する形が、`[connection]` の宣言と同じだけ検査可能である — 検証方法: 全 `Enemy` の子について接続の有無をテストで確かめる / 状態: 未検証
