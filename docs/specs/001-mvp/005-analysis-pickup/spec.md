# analysis-pickup — 仕様

## 1. 目的と背景

解析で得るものを、撃破した位置に残る**取得アイテム(断片)**として作り直す。断片はプレイヤーへ吸われず、プレイヤーが取りに行く。触れると**主武器**が拡散へ変わり、その強化は時間で切れず、プレイヤーが倒れるまで持続する。副武器は強化中も同じように撃て、強化を受けていることが弾の見た目で分かる。

`analysis-ability`(unit #4)は同じ企画意図を「撃破位置からプレイヤーへ飛ぶ演出 + 第 3 の武器枠 + 残り回数」で実装した。実機で操作した結果、取得の形(吸収ではなく撃破位置に残す)・強化の対象(第 3 の枠ではなく主武器)・強化の持続(有限回数ではなく時間無制限)を変える判断が出た。**本単位はその機構を置き換え、第 3 の武器枠と付随するコードを撤去する**(廃止を別の作業へ残さない)。

企画書は操作を左右移動・ジャンプ・主武器・副武器の 4 つに限り、武器の枠を 2 つに固定する(企画書 5.・6.)。第 3 の枠の撤去はこの原則へ戻す変更であり、取得のためのボタンも置かない(触れるだけで加わる)。

グラフィックは placeholder(単色矩形)とする。unit #2〜#4 と同じく、ゲームロジックを先に完成させるためである。

## 2. スコープ

### 対象(やること)

- 撃破位置に残る断片(`AnalysisFragment`)と、触れたときの強化の付与
- 主武器の強化の状態(取得・保持・プレイヤーの死亡によるリセット)
- 拡散の 3 方向の決定(射撃方向とその左右 20 度)
- 弾が 8 方向の外を向けるようにするための `Projectile.launch()` の引数の型の拡張
- 強化中の副武器の弾の見た目の変化
- 解析で写せる敵の種別の判定(unit #4 の `AbilityAnalysis` を変更せずに流用する)
- 撃破から断片の出現までの配線と、確認用の仮ステージ 1 つ
- **unit #4 が導入した第 3 の武器枠と、それに付随して不要になるコード・シーン・テストの削除**
- `docs/testing.md`「仮ステージを目視で確認する」の節の書き換え(解析の確認用の仮ステージが 2 つから 1 つになるため)
- 上記の振る舞いを検証するテスト

### 対象外(やらないこと)

- 2 種目以降の強化 — 理由: roadmap `docs/specs/001-mvp/roadmap.md` §1.1 が本単位の範囲を「主武器の強化 1 種」と定めている。種別の分岐は `AbilityAnalysis` に用意済みであり、写せる種別が増える場合は後続で足す
- 突進型から写す強化 — 理由: 突進の制御をプレイヤーへ写すと実質的に回避行動が増える。企画書 5. は回避行動の不在を前提に敵の攻撃の条件を定めており、unit #2 の `CombatLimits` の算出根拠もそこに依存する(unit #4 §2 と同じ理由)
- 強化中であることの HUD 表示 — 理由: このプロジェクトは UI ノードを 1 つも持たない。強化の表出は主武器の弾数と副武器の弾の色に置く(§5.3・§7 Requirement 5)
- 断片の寿命・落下・プレイヤーへの吸引 — 理由: 断片は時間で消えず、重力を持たず撃破位置に静止し、プレイヤーへ吸われない。人間が確定済みの判断であり、これらの機構を作らないこと自体が仕様である(§7 7.8・7.9)
- チェックポイントからの復帰と進行の保存 — 理由: `game-flow`(unit #8)の範囲であり、roadmap §3 がセーブ・進行管理の作り込みをスコープ外としている。実機のリトライはシーンの再読込であり、強化のリセットはその経路に依存させない(§5.3)
- `PlayerStats` への強化専用の数値項目の追加 — 理由: 強化中の威力・連射間隔・弾速は主武器の値を据え置く(人間が確定済み)。項目を足す理由が無い
- カメラ追従(`Camera2D`)の導入と、基準解像度より広い仮ステージ — 理由: このプロジェクトは `Camera2D` を 1 つも持たない。カメラは本番のステージを作る `foot-stage-boss`(unit #6)が必要とする資産であり、仮ステージの都合で前倒しすると、その設計を目視確認の要求だけで決めることになる(unit #4 §2 と同じ理由)
- 敵の動的な出現(スポナー) — 理由: `foot-stage-boss`(unit #6)の範囲。本単位の仮ステージはシーンへ直接配置する
- 大域の解析イベント(Autoload)の導入 — 理由: このプロジェクトは `project.godot` に `[autoload]` を持たない。撃破から断片の出現までの配線は仮ステージが中継する形で足り、大域状態を持ち込むとテストの隔離が難しくなる
- 既存の `dev_stage.tscn` と `enemy_dev_stage.tscn` の変更 — 理由: どちらも子ノードの構成をテストで固定した凍結済み単位の成果であり、変更するとその改訂が要る
- `PlayerCommand`・`PlayerInput`・`project.godot` の `[input]` の変更 — 理由: 取得のためのボタンを置かない(企画書 5.)。強化は入力を増やさずに主武器の弾数を変える
- `EnemyProjectile`・`PrimaryWeapon`・`SecondaryWeapon`・`AimResolver`・`Health` の変更 — 理由: 強化はこれらの状態機械の外側(弾の生成)で成立する
- unit #3 の `tests/stage/enemy_dev_stage_test.gd` への `[Nit]` 2 件の適用 — 理由: 凍結済み単位のテストであり、変更するとその改訂が要る。2 件は**本単位が作る仮ステージのテストに限って閉じる**(人間が確定済み。§7 7.14・9.5)
- `docs/glossary.md` の新設 — 理由: 用語集を作る作業は roadmap の unit の範囲に無い。プロジェクトが用語集を持たない場合は既存コードの語彙に合わせる(`.claude/skills/dev-core/references/durable-info.md` 5.2)。採用した識別子と企画書の語の対応は §8 に残す
- 効果音・ドット絵 — 理由: unit #2〜#4 と同じく別の作業で制作して placeholder と差し替える

## 3. 前提(未検証の賭け)

- **拡散の角度 20 度が「拡散」として成立し、8 方向の照準と両立する** — 検証方法: 仮ステージで実際に撃って目で確かめる / 状態: 未検証。角度を 8 方向の環の刻み(45 度)より小さくするのは、unit #4 の実機確認で 45 度の広がりが「拡散」ではなく「三方向撃ち」に見えたためである。照準そのものは 8 方向のまま変えない(企画書 5.)
- **強化中の主武器を「3 発 × `primary_damage` 10・連射間隔 0.12 秒の据え置き」としても難度が崩れない** — 検証方法: 同上 / 状態: 未検証。至近距離で 3 発すべてが当たると毎秒約 250 の火力になる(雑魚敵の体力は 20・30)。据え置きは人間が確定済みの判断であり、崩れた場合は `PlayerStats` の主武器の値ではなく拡散の角度・弾数で調整する
- **断片が時間で消えず落下もしないことが、「取りに行く」動機として成立する** — 検証方法: 同上 / 状態: 未検証
- **`Vector2i` の実引数を `Vector2` の引数へ渡せ、既存の呼び出し側を書き換えずに済む** — 検証方法: Godot 4.7.1 で実測 / 状態: **検証済み**。`func launch(direction: Vector2, ...)` に対し `launch(Vector2i(1, 0), ...)`・`launch(Vector2i.ZERO, ...)`・`Vector2i` 型の変数のいずれも暗黙変換で通り、警告もパースエラーも出ない。`Vector2i.ZERO` を渡した場合は関数の内側で `Vector2.ZERO` と等しくなり、ゼロの事前条件のガードがそのまま働く
- **`Projectile.launch()` の `push_error` の文言を据え置けば、凍結済みの `tests/weapon/projectile_test.gd` は緑のまま通る** — 検証方法: 既存テストの読み取りで確認済み / 状態: **検証済み**。同スイートは文言を自分の定数として持ち(`ZERO_DIRECTION_ERROR`)、引数は `_launch_parameter_names()` が `get_method_list()` の `name` だけを読む(型を見ない)
- **`PlayerStats` から `ability_*` の 4 項目を削除しても unit #2 のテストは緑のまま通る** — 検証方法: 既存テストの読み取りで確認済み / 状態: **検証済み**。`tests/player/player_stats_test.gd` は 14 項目の固定リスト `STAT_NAMES` を走査し、インスペクタへの露出は非排他の `contains` で見る
- **getter だけを持つプロパティへの代入を、GDScript は拒否せず黙って無視する** — 検証方法: Godot 4.7.1 で実測 / 状態: **検証済み**。getter だけを持つ `is_up` に対し、型が静的に分かる経路(`var r: RO = RO.new()`)からの直接の代入も `set("is_up", ...)` も、パースエラー・実行時エラー・警告のいずれも出さずに値を変えなかった。**「読み取り専用」は代入を拒否することではなく、代入が状態へ届かないことを指す**(§5.3・§6.2・§7 3.5)
- **乗算の `modulate` では基の色より明るい色を作れない** — 検証方法: Godot 4.7.1 で実測 / 状態: **検証済み**。弾の placeholder は `Color(1, 0.85, 0.35)` であり、成分が 1 以下の tint を掛けて得られる色は必ずこれ以下になる。強化中の副武器の弾の色は、この制約の中で最も見分けの付く緑を採る(§6.4)
- **`Enemy.defeated` の発火の時点で、撃破された敵はまだツリーにいて `global_position` を読める** — 検証方法: unit #3 で実測済み / 状態: **検証済み**(`src/enemy/enemy.gd` は `defeated.emit()` の後に `queue_free()` を呼び、`tests/enemy/enemy_test.gd::test_defeated_is_emitted_before_the_enemy_is_released` が固定している)
- **`[connection]` の `binds` で敵ごとの束縛を宣言でき、`load()` → `instantiate()` で復元される** — 検証方法: unit #4 で実測済み / 状態: **検証済み**(unit #4 §3。`.tscn` 上の書式は `binds= [NodePath("...")]`)
- **`Area2D` の重なりの通知は 1 物理フレーム遅れる** — 検証方法: unit #2 で実測済み / 状態: **検証済み**。断片への接触を検証するテストは 2 フレーム分を上限に取る

## 4. 用語定義

| 用語 | 定義 |
| ---- | ---- |
| 解析 | 敵を撃破したときに自動で走り、その敵の制御を読み取る手続き(企画書 5.)。プレイヤーの操作を伴わない |
| 写せる | 読み取った手続きが、プレイヤーの強化として加わりうること。種別ごとに決まる(unit #4 §4 と同じ) |
| 断片 | 写せる敵を撃破した位置に残る取得物。触れると強化が加わる。`AnalysisFragment` |
| 強化 | 主武器が拡散へ変わっている状態。時間で切れず、プレイヤーが倒れるまで持続する |
| 拡散 | 1 回の発射で、射撃方向とその左右 20 度の 3 方向へ同時に撃つこと |
| 射撃方向 | 8 方向のいずれか。`AimResolver.resolve()` が返す `Vector2i`(unit #2 §5.3) |
| 描画色 | `ColorRect` の `color` に、それを含むノードの `modulate` を掛けた色 |
| 脅威の圏 | 配置規約の検査に使う、プレイヤーの初期位置を中心とする半径 160px の円(unit #3 §4・unit #4 §4 と同じ定義) |

## 5. 公開インターフェース(API)

### 5.1 `SpreadResolver`(static、純粋関数)— unit #4 §5.2 の作り直し

```gdscript
class_name SpreadResolver extends RefCounted

const SPREAD_DEGREES: float = 20.0

static func resolve(direction: Vector2i) -> Array[Vector2]
```

- `direction` の向きと、そこから左右へ `SPREAD_DEGREES` 度ずつ回した向きを `[中央, 反時計回り, 時計回り]` の順で返す。並びは unit #4 の `[中央, 反時計回りの隣, 時計回りの隣]` を引き継ぐ。
- 画面座標(y は下向き)であり、`Vector2.rotated()` の正の角は時計回りに対応する。
- **戻り値の型が `Array[Vector2i]` から `Array[Vector2]` へ変わる**: 20 度は 8 方向の格子に載らない。8 方向の環の隣接(45 度刻み)で作る unit #4 の実装は流用できず、中身を作り直す。
- **事前条件**: `direction` は 8 方向のいずれか(x・y がそれぞれ -1 / 0 / 1 で、両方 0 ではない)。違反した場合は `push_error` を出し、**空の配列**を返す。
- **事後条件**: 戻り値は 3 要素。すべて長さ 1 の向きであり、`Vector2.ZERO` を含まない。1 番目と 2 番目の角は -20 度、1 番目と 3 番目の角は +20 度、2 番目と 3 番目の角は 40 度。
- **状態を持たない**: 同じ引数には常に同じ戻り値を返す。
- **拡散の角度をここ 1 箇所に持つ**: `SPREAD_DEGREES` を公開定数として持ち、`PlayerStats` にも呼び出し側にも同じ値を置かない。強化専用の数値項目を `PlayerStats` へ足さないという決定(§2)の帰結である。
- `AimResolver.resolve()` の事後条件(8 方向のいずれかを返し `Vector2i.ZERO` を返さない。unit #2 §5.3)により、実際の呼び出し経路では事前条件を破れない。検査を置くのは、この関数を直接呼ぶ経路(テスト・将来の呼び出し側)のためである。
- **照準は 8 方向のまま**: 引数は `Vector2i` の 8 方向であり続ける。拡散は 1 つの射撃方向から派生する弾の広がりであって、プレイヤーが選べる方向ではない(企画書 5.「照準を連続角にしない」)。

### 5.2 `Projectile`(`Area2D`)— unit #2 §5.6 の拡張

```gdscript
class_name Projectile extends Area2D

var damage: int
var frames_moved: int

func launch(direction: Vector2, speed: float, damage: int, max_distance: float) -> void
```

- **`direction` の型を `Vector2i` から `Vector2` へ広げる**。それ以外(引数の名前・並び・個数、`damage`・`frames_moved`、地形との衝突、射程の測り方、解放のしかた)は変えない。
- **既存の呼び出し側を書き換えない**: `Vector2i` の実引数は暗黙変換で通る(§3 で実測済み)。`Vector2(dir)` を明示的に書く必要はないが、書いても同じ結果になる。
- **事前条件**: `direction` は `Vector2.ZERO` 以外、`speed`・`damage`・`max_distance` は正。違反した場合は `push_error` を出し、弾を進めずに返る。
- **長さが 0 でない限り拒否しない**: 短さや 8 方向からのずれを検査しない(`EnemyProjectile` と同じ扱い。unit #3)。
- **ゼロの向きを拒否するときの `push_error` の文言を変えない**。凍結済みの `tests/weapon/projectile_test.gd` が文言を自分の定数として固定しており、変更するとそのテストの改訂が要る(§2 で変更しないと決めている)。**その結果、文言だけが `Vector2i.ZERO` を指したまま残る**。この乖離の扱いは §8 に記す。
- **事後条件**: 渡された向きを正規化して `speed` を掛けた速度で進む。斜めの向きでも速さが `speed` を超えない。

### 5.3 `Player`(`CharacterBody2D`)— unit #2 §5.1 の拡張、unit #4 の追加分の撤去

```gdscript
class_name Player extends CharacterBody2D

signal died                                              # unit #2。変えない
signal fired(direction: Vector2i, is_secondary: bool)    # unit #2。変えない
signal spread_fired(directions: Array[Vector2])          # 追加

@export var stats: PlayerStats                           # unit #2。変えない
@export var projectile_scene: PackedScene                # unit #2。変えない
@export var upgraded_secondary_tint: Color               # 追加

var health: Health                                       # unit #2。変えない
var facing: int                                          # unit #2。変えない
var input_source: Callable                               # unit #2。変えない
var is_primary_upgraded: bool                            # 追加。読み取り専用

func apply_command(cmd: PlayerCommand, delta: float, is_on_floor: bool) -> void   # unit #2。変えない
func take_damage(amount: int) -> void                                             # unit #2。変えない
func grant_upgrade() -> void                                                      # 追加
```

**削除する**(unit #4 の追加分): `signal ability_fired(directions: Array[Vector2i])`・`var ability_slot: AbilitySlot`・`func grant_ability()`、および副武器の枠を第 3 の枠が占有する処理。

- **`is_primary_upgraded`**: 主武器が拡散へ変わっているか。**getter だけを持ち、非公開の状態から導くプロパティ**とし、外からの書き込みが状態へ届かないようにする。状態を変えるのは `grant_upgrade()` と体力の枯渇の経路だけである。
  - **拒否ではなく無効化である**: Godot 4.7.1 の GDScript は、getter だけを持つプロパティへの代入をパースエラーにも実行時エラーにもせず、**黙って無視する**(§3 で実測済み)。呼び出し側は誤った代入に気付けないが、状態は壊れない。不変条件(§6.2)はこの意味で成立する
- **`grant_upgrade()`**: 主武器へ強化を加える。
  - **引数を取らない**: 写せるかどうかの判断は `AbilityAnalysis`(§5.5)にあり、`Player` は判断の結果だけを受け取る。強化は MVP では 1 種であり、種類を表す引数を置かない
  - **事前条件**: なし。体力の状態を検査しない
  - **事後条件**: `is_primary_upgraded == true`
  - **冪等**: 既に強化を持つ状態で呼ばれても状態が変わらない。断片は消費されるが強化は変わらない(人間が確定済み)
  - ツリーへ載せていない `Player` に対しても呼べる(`_ready()` を通らない経路で null になる状態を持たない)
- **強化のリセット**: 体力が 0 に達したとき(`Health.depleted` の経路)、`is_primary_upgraded` を偽に戻してから `died` を発火する。
  - **`Player` 自身が持つ**: 実機のリトライはシーンの再読込で自動的に初期化されるが、その経路はテストから駆動できない。リセットを `Player` の契約に置くことで、`take_damage()` から観測できる形になる
  - 時間の経過ではリセットしない(強化は時間で切れない)
- **強化中の主武器**: `PrimaryWeapon.try_fire()` が真を返したフレームで、`SpreadResolver.resolve(射撃方向)` の 3 方向へ `Projectile` を 3 発生成し、`fired(射撃方向, false)` を 1 回、`spread_fired(directions)` を 1 回、この順で発火する。
  - 3 発には `stats.primary_damage`・`stats.primary_bullet_speed`・`stats.bullet_max_distance` を渡す(強化専用の数値を持たない)
  - **`fired` は 1 回の発射につき 1 回、中心の 8 方向を載せて発火する**: `fired(direction: Vector2i, is_secondary: bool)` は凍結済みの unit #2 §5.1 の契約であり、引数を変えない。強化しても「主武器が 1 回撃った」という意味は変わらないため、発火の回数と `direction` の意味を据え置く
  - **拡散の 3 方向は `spread_fired` が運ぶ**: `fired` の `direction` は `Vector2i` であり 20 度の向きを表せない。方向の内容そのものを読みたい受け手のために別のシグナルを置く
  - 弾を生成できなかった場合はどちらのシグナルも発火しない(unit #2 の `_spawn_projectile()` が `fired` を出さずに返るのと同じ扱い)
- **強化中の副武器**: 入力・充電・クールダウン・威力・弾速のいずれも変えない。`cmd.secondary_held` をそのまま副武器へ渡す(第 3 の枠による占有は撤去する)。
  - **見た目だけを変える**: 強化中に生成した副武器の弾の `modulate` に `upgraded_secondary_tint` を設定する。強化していない間は既定の `Color.WHITE` のままにする
  - **主武器の弾には掛けない**: 主武器の強化は弾数で表れており、色を重ねる必要がない
- **`upgraded_secondary_tint` を `PlayerStats` に置かない**: 手触りを決める数値ではなく見え方であり、`Player` の `@export` として持つ(unit #4 が `AnalysisPulse.flight_time` を `PlayerStats` へ置かなかったのと同じ理由)。
  - **既定値はスクリプト側に 1 つだけ置き、`player.tscn` で上書きしない**: `projectile_scene` のような外部リソースの参照ではなく値そのものであり、シーンにも既定値を持たせると値の出どころが 2 つに分かれる。スクリプト側に置くことで、`Player.new()` から作った場合と `player.tscn` から生成した場合とで観測値が変わらない(型付きの `@export var c: Color` を初期化しない場合の暗黙の既定は `Color(0, 0, 0, 1)` であり、`Color.WHITE` と異なるという契約は満たすが、意図した色にならない)
- **武器の枠は 2 つに固定する**: 第 3 の枠を表す状態を持たない(企画書 6.)。

### 5.4 `AnalysisFragment`(`Area2D`、撃破位置に残る断片)

```gdscript
class_name AnalysisFragment extends Area2D
```

公開のメソッド・シグナル・プロパティを持たない。契約は**当たり判定の構成と、触れられたときの振る舞い**である。

- **衝突の構成**: `collision_layer` を 0、`collision_mask` をプレイヤーのレイヤ(2)だけとする。断片は誰にも拾われず、プレイヤーだけを検知する。
- **触れられたとき**: `body_entered` を受け、触れた物体が `grant_upgrade()` を持つなら、それを呼び、自身を解放する。
  - **`area_entered` を使わない**: プレイヤーは `CharacterBody2D` であって `Area2D` ではない(`Attackbox` と同じ理由。unit #3 §5.9)。`area_entered` で実装しても `Area2D` のスタブを使うテストは通ってしまうため、どちらの信号で受けるかを契約に含める
  - **相手を型で見ない**: `has_method()` で判定し、`Player` へ静的に依存しない(`Attackbox` が `Player` を型で見ない規律と同じ。unit #3 §5.9)
  - `grant_upgrade()` を持たない物体が触れた場合は、解放せず `push_error` も出さない。マスクにはプレイヤーしか載らないため、素通りは異常ではなく想定内である(`Attackbox` と同じ扱い)
  - 既に強化を持つ相手が触れた場合も同じに扱う。断片は消費され、強化の状態は `grant_upgrade()` の冪等性によって変わらない(§5.3)
- **時間で消えない**: 寿命を持たず、`Timer` も経過時間も持たない。
- **落ちない**: 重力を持たず、`_physics_process` で位置を動かさない。撃破位置に静止する。
- **吸われない**: プレイヤーへ向かって移動しない。プレイヤーが取りに行く。
- **種別を持たない**: 写せるかどうかの判断は生成する側(§5.6)が済ませており、断片は「触れると強化が加わるもの」1 種だけである。
- **placeholder**: `ColorRect` を 1 枚だけ持ち、寸法は **8×8px**、ノードの原点を矩形の中心に置く。弾(4×4px)より大きく、敵(16×16px)より小さくして、置かれているものが弾でも敵でもないことを大きさで区別する。当たり判定も同じ 8×8px とする。色は既存の placeholder のいずれとも重ならない値にする(§6.4)。
- **操作を止めない**: `Engine.time_scale` にも `SceneTree.paused` にも触れない。干渉は操作を伴わない(企画書 5.)。
- 解放に `queue_free()` を使い `free()` を使わない: 物理コールバックの最中の解放は物理サーバの走査を壊す(unit #2 §5.6 と同じ)。

### 5.5 `AbilityAnalysis`(static、純粋関数)— unit #4 §5.3 から流用。**変更しない**

```gdscript
class_name AbilityAnalysis extends RefCounted
static func is_transferable(kind: int) -> bool
```

- 撃破した敵の種別から、プレイヤーへ写せる手続きを持つかを返す。`EnemyKind.Kind.SHOOTER` なら真、`EnemyKind.Kind.CHARGER` なら偽。
- **事前条件**: `kind` は `EnemyKind.Kind` の値。違反した場合は `push_error` を出し偽を返す。
- **状態を持たない**: 同じ引数には常に同じ戻り値を返す。
- **ここが種別で分岐する唯一の場所である**。本単位でも `Player` も断片も仮ステージも種別を見ない。第 3 の枠が無くなっても、「写せる種別か」という問い自体は変わらないため、実装もテストもそのまま流用する。

### 5.6 `AnalysisDevStage`(`Node2D`、解析の確認用の仮ステージ)— unit #4 §5.6 の作り直し

```gdscript
class_name AnalysisDevStage extends Node2D
@export var fragment_scene: PackedScene
```

**削除する**: `@export var pulse_scene: PackedScene`。

撃破から断片の出現・取得までを実行時に確かめるための場。unit #2 の `DevStage`(プレイヤー単体)と unit #3 の `EnemyDevStage`(敵との戦闘)とは別に置き、どちらも変更しない。

- **シーンは 1 つだけ持つ**(`analysis_dev_stage.tscn`。射撃型 1・突進型 1)。unit #4 が持っていた 2 つ目のシーン `analysis_overwrite_dev_stage.tscn` は**削除する**。上書きの確認は第 3 の枠の残り回数を見るためのものであり、強化が真偽 1 つになった本単位では確かめるものが無くなる(再取得は冪等であり、目視で区別できる変化を起こさない)。
- 各敵の `defeated` を**シーンの `[connection]` として宣言**し、`binds` にその敵を指す `NodePath` を持たせる。`NodePath` は**ステージ(接続の受け手)から `get_node()` で解決できる相対のパス**とする。ハンドラは `[kind, NodePath]` を受け取り、解決した敵の `global_position` を読む。
- ハンドラは `AbilityAnalysis.is_transferable(kind)` が真のときだけ断片を生成し、**ステージ自身の子として**追加してから、撃破された敵の `global_position` へ置く。撃破された敵の子にしない: 敵は `defeated` の直後に解放されるため、子にすると断片も一緒に消える。
- **写せない種別では何もしない**。断片が出ないこと自体が「この敵からは写せない」ことの表出である。
- **事前条件**: 写せる種別の撃破を受けるとき、`fragment_scene` が設定されていること。未設定の場合は `push_error` を出し、断片を生成せずに返る(`Player.projectile_scene`・`ShooterEnemy.projectile_scene` と同じ表出のしかた)。写せない種別の撃破では `fragment_scene` の設定にかかわらず `push_error` を出さない(生成を試みないため)。
- **取得の配線を持たない**: 断片が触れた相手の `grant_upgrade()` を直接呼ぶため(§5.4)、ステージは取得に関与しない。unit #4 のステージが持っていた「演出の到達を受けて `player.grant_ability()` を呼ぶ」経路と、そのためにプレイヤーを引く処理は無くなる。
- `player.died` を `[connection]` で宣言し、`get_tree().reload_current_scene.call_deferred()` を呼ぶ。直接呼ばない理由は unit #3 の申し送りにある: `died` は敵の攻撃の当たり(物理コールバック)から届くため、その最中に現在のシーンを差し替えると物理サーバの走査を壊す。
- 各敵の `target` をシーンの宣言で `Player` ノードへ指す(`_ready()` で検索しない)。
- 敵の動的な出現(スポナー)を持たない。
- `fragment_scene` はシーンの宣言で与える(値の出どころを 1 箇所にする)。

## 6. データ構造

### 6.1 拡散の 3 方向(`SpreadResolver` の出力)

| 位置 | 内容 |
| ---- | ---- |
| 1 番目 | 射撃方向を正規化した向き |
| 2 番目 | 1 番目を反時計回りに `SPREAD_DEGREES` 度回した向き |
| 3 番目 | 1 番目を時計回りに `SPREAD_DEGREES` 度回した向き |

- **不変条件**: 3 要素。すべて長さ 1 で `Vector2.ZERO` を含まない。3 要素は互いに異なる。
- **不変条件**: 引数が 8 方向のいずれかであること。`AimResolver` の事後条件が呼び出し経路でこれを保証し、直接の呼び出しにはガードが働く。
- **8 方向の環を持たない**: unit #4 は隣り合いを 8 方向の環(45 度刻み)で表していたが、20 度は環に載らない。回転で導くため環そのものが不要になる。8 方向は「引数として妥当な値の集合」としてだけ残る。
- **ロジックの所在**: 拡散の角度と 3 方向の並びは `SpreadResolver` だけが持つ。`Player` は戻り値を順に撃つだけで、隣り合いも角度も自分で組み立てない。

### 6.2 主武器の強化の状態(`Player`)

| 項目 | 型 | 意味 |
| ---- | -- | ---- |
| `is_primary_upgraded` | `bool`(読み取り専用) | 主武器が拡散へ変わっているか |

- **不変条件**: 状態は真偽の 2 値だけを取る。強化の種類・残り回数・残り時間を持たない。
- **不変条件**: 外からの書き込みが状態へ届かない(代入は黙って捨てられる。§5.3)。真になるのは `grant_upgrade()` の呼び出しだけ、偽になるのは体力が 0 に達したときだけである。
- **0 や「空」の概念を持たない**: unit #4 の `AbilitySlot.remaining_uses` が持っていた「残り回数 0 = 空」という段階は無くなる。強化は使い切らない。
- **ロジックの所在**: 強化の有無で発射を分けるのは `Player` の `_update_weapons()` だけである。断片も仮ステージも強化の状態を読まない。

### 6.3 `EnemyKind.Kind` との対応(`AbilityAnalysis`)— unit #4 §6.3 から変更しない

| 種別 | 写せるか | 撃破位置に断片が出るか |
| ---- | -------- | ---------------------- |
| `EnemyKind.Kind.SHOOTER` | 写せる | 出る |
| `EnemyKind.Kind.CHARGER` | 写せない | 出ない |

- 射撃型を対象にする理由は unit #4 §6.3 と同じ(突進型の制御は移動であり、写すと実質的に回避行動が増える)。
- **ロジックの所在**: この対応表は `AbilityAnalysis` だけが持つ。

### 6.4 見た目の値

| 対象 | 項目 | 既定値 | 描画色 | 根拠 |
| ---- | ---- | ------ | ------ | ---- |
| `AnalysisFragment` の `ColorRect` | `color` | `Color(0.85, 0.45, 0.95, 1)` | 同左 | 既存の placeholder のいずれとも重ならない紫。プレイヤー(水色)・突進型(赤)・射撃型(青)・味方の弾(金)・敵弾(桃)・ダメージ帯(赤)・地形(灰)のどれとも別の色相を取る |
| `Player.upgraded_secondary_tint` | `modulate` に設定する色 | `Color(0.35, 0.88, 1, 1)` | `Color(0.35, 0.748, 0.35, 1)` | 弾の placeholder `Color(1, 0.85, 0.35)` に掛けた結果が緑になる。乗算では基の色より明るくできないため(§3)、金から最も見分けの付く方向へ倒す |

- **不変条件**: `upgraded_secondary_tint` は `Color.WHITE` と異なる。等しいと「見た目が変わる」という契約(企画書 6.)が成立しない。
- **不変条件**: 断片の色と、強化中の副武器の弾の描画色は互いに異なる。
- 演出の値を `PlayerStats` に置かない理由は unit #4 §6.4 と同じ(手触りを決める数値ではなく見え方だからである)。
- **unit #4 の `AnalysisPulse` の色 `Color(0.55, 0.95, 0.6)` は使わない**。演出そのものを削除するため、その色を引き継ぐ先が無い。断片に別の色相を与えるのは、強化中の副武器の弾(緑)と見分けるためである。

### 6.5 `PlayerStats`(unit #2 §6.1 の 14 項目へ戻す)

unit #4 が追加した 4 項目(`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`)を**削除**し、unit #2 が定めた 14 項目だけにする。既定値は変えない。

| 強化が使う項目 | 既定値 | 出どころ |
| -------------- | -----: | -------- |
| `primary_damage` | 10 | unit #2 §6.1。拡散の 3 発それぞれに渡す |
| `primary_interval` | 0.12 | unit #2 §6.1。強化しても変えない |
| `primary_bullet_speed` | 400.0 | unit #2 §6.1。拡散の 3 発それぞれに渡す |
| `bullet_max_distance` | 400.0 | unit #2 §6.1。拡散の 3 発それぞれに渡す |

- **不変条件**: 14 項目はすべて正。`Player._report_non_positive_stats()` が `get_property_list()` の全数値項目に `> 0` を課す規律を保つ。
- **強化専用の数値項目を持たない**: 威力・連射間隔・弾速を主武器の値のまま据え置くという決定(人間が確定済み)の帰結である。拡散の角度は `SpreadResolver` が持つ(§5.1)。

### 6.6 衝突レイヤの割り当て

`project.godot` の `[layer_names]` は変更しない。断片は既存のレイヤの組み合わせだけで成立する。

| 対象 | レイヤ | マスク | 出どころ |
| ---- | -----: | -----: | -------- |
| 拡散の弾(`Projectile` を流用) | 3 | 1(地形)・4(敵) | unit #2 §6.5 |
| 強化中の副武器の弾(`Projectile` を流用) | 3 | 1(地形)・4(敵) | unit #2 §6.5 |
| `AnalysisFragment` | (なし。0) | 2(プレイヤー) | 本単位 |

- 断片を**どのレイヤにも載せない**理由: 載せると、プレイヤーの弾(マスク 1・4)・敵の弾(マスク 1・2)・敵の攻撃判定の走査に現れうる。断片は誰にも当たらず、自分からプレイヤーを検知するだけでよい。

### 6.7 ファイルの配置

```
新設        src/ability/    analysis_fragment.gd, analysis_fragment.tscn
            tests/ability/  analysis_fragment_test.gd, analysis_fragment_scene_test.gd
            tests/player/   player_upgrade_test.gd

作り直し    src/ability/    spread_resolver.gd
            src/stage/      analysis_dev_stage.gd, analysis_dev_stage.tscn
            tests/ability/  spread_resolver_test.gd
            tests/player/   player_spread_test.gd
            tests/stage/    analysis_dev_stage_test.gd, analysis_dev_stage_scene_test.gd

変更        src/player/     player.gd, player_stats.gd
            src/weapon/     projectile.gd
            docs/           testing.md

削除        src/ability/    ability_slot.gd, analysis_pulse.gd, analysis_pulse.tscn
            src/stage/      analysis_overwrite_dev_stage.tscn
            tests/ability/  ability_slot_test.gd, analysis_pulse_test.gd,
                            analysis_pulse_scene_test.gd
            tests/player/   player_ability_test.gd, player_ability_stats_test.gd,
                            player_takeover_test.gd
            tests/stage/    analysis_overwrite_dev_stage_test.gd

流用        src/ability/    ability_analysis.gd(変更しない)
            tests/ability/  ability_analysis_test.gd(変更しない)
            src/weapon/     projectile.tscn(弾のシーンを新設しない)
```

- `.gd` に付随する `.uid` は同じ扱いとする(新設は増え、削除は消える)。
- 解析と強化に属するものを `src/ability/` にまとめる(unit #4 §6.7 の配置を引き継ぐ)。第 3 の枠が無くなってもディレクトリの意味(解析で得るものを置く場所)は変わらない。
- 弾のシーンを新設しない。拡散の弾も強化中の副武器の弾も `src/weapon/projectile.tscn` を流用し、見た目の違いは `modulate` で作る(§6.4)。
- テストの配置は `docs/testing.md` の規約(実装のディレクトリ構成を写す)に従う。
- ファイルごとの区分と責務の計画(File Structure Plan)はここで定めない(タスク分解の責務)。

## 7. 振る舞い(受け入れ基準)

**検証の形式**: シーンの構成を検証するテストはツリーへ載せない(`instantiate()` + `auto_free()` だけで位置・接続・子ノードの型を読む。unit #2 の申し送り)。数値を扱うテストは、既定値と一致する値を渡さない(実装が値を直書きしても緑になるため。unit #3 の申し送り)。実装の定数を参照して期待値を組み立てない(アサーションが自明になるため。unit #2 の申し送り)。

**「実装の定数を参照しない」の適用範囲**: この規律は、検証対象自身の定数・文言をテストが写して期待値にすることを禁じる。**別の契約の出力を期待値に使うことは禁じない**(4.2・4.6 が `Player` の期待値を `SpreadResolver.resolve()` から取る形は許す。`SpreadResolver` 自体は Requirement 1 が独立に固定するため、両方が同時に壊れない限り検出力は落ちない)。ただし拡散の角度 20 度そのものは、テストが `SpreadResolver.SPREAD_DEGREES` を**期待値として**参照せず、自前の値として持つ(1.10 のように定数の存在と値そのものを検査する場合は、検査の対象として読んでよい)。

### Requirement 1: 拡散の方向

**対象**: §5.1 `SpreadResolver` / §6.1 拡散の 3 方向

**受け入れ基準**:

1.1. システムは、`resolve()` の戻り値を 3 要素の `Array[Vector2]` としなければならない。(常時)
1.2. システムは、戻り値の 1 番目を、引数の向きを正規化したものとしなければならない。(常時)
1.3. システムは、戻り値の 2 番目を、1 番目から反時計回りに 20 度回した向きとしなければならない(画面座標。y は下向き)。(常時)
1.4. システムは、戻り値の 3 番目を、1 番目から時計回りに 20 度回した向きとしなければならない。(常時)
1.5. システムは、戻り値の 3 要素をすべて長さ 1 の向きとしなければならない。(常時)
1.6. システムは、戻り値の 2 番目と 3 番目の間の角を 40 度としなければならない。(常時)
1.7. システムは、戻り値の 3 要素を互いに異なる向きとしなければならない。(常時)
1.8. システムは、戻り値に `Vector2.ZERO` を含めてはならない。(常時)
1.9. システムは、8 方向のいずれを渡された場合も 1.1〜1.8 を満たさなければならない。(常時)
1.10. システムは、拡散の角度 20 度を `SpreadResolver` の公開定数として 1 箇所に持たなければならない(`PlayerStats` にも呼び出し側にも同じ値を置いてはならない)。(常時)
1.11. `direction` が `Vector2i.ZERO` である場合、または x・y のいずれかが -1 / 0 / 1 のいずれでもない場合、システムは `push_error` を出し空の配列を返さなければならない。(異常系)
1.12. システムは、同じ引数に対して常に同じ戻り値を返さなければならない(状態を持ってはならない)。(常時)
1.13. システムは、`AimResolver.resolve()` が返す射撃方向を 8 方向のまま保たなければならない(拡散の角度を照準へ持ち込んではならない)。(常時)

### Requirement 2: 弾の発射方向の型

**対象**: §5.2 `Projectile`

**受け入れ基準**:

2.1. システムは、`launch()` の第 1 引数の型を `Vector2` としなければならない。(常時)
2.2. 8 方向のいずれかを `Vector2i` の値として渡されたとき、システムは型を広げる前と同じ向き・同じ速さで弾を進めなければならない。(イベント)
2.3. 8 方向のいずれでもない向き(水平から 20 度など)を渡されたとき、システムはその向きへ弾を進めなければならない。(イベント)
2.4. システムは、渡された向きを正規化して速さを掛けなければならない(斜めの向きで速さが `speed` を超えてはならない)。(常時)
2.5. `direction` が `Vector2.ZERO` である場合、システムは `push_error` を出し弾を進めてはならない。(異常系)
2.6. システムは、長さが 0 でない向きを、8 方向からのずれや短さを理由に拒否してはならない。(常時)
2.7. システムは、`direction` が `Vector2.ZERO` のときの `push_error` の文言を unit #2 の実装のまま変えてはならない(凍結済みの `tests/weapon/projectile_test.gd` が固定している)。(常時)
2.8. システムは、`launch()` の引数の名前と並び(`direction`・`speed`・`damage`・`max_distance`)を変えてはならない。(常時)
2.9. システムは、`Projectile` の衝突レイヤ・マスク・地形との衝突・射程の測り方・解放のしかたを変えてはならない。(常時)

### Requirement 3: 強化の取得と保持

**対象**: §5.3 `Player.grant_upgrade()`・`is_primary_upgraded` / §6.2 主武器の強化の状態

**受け入れ基準**:

3.1. システムは、生成直後の `Player` の `is_primary_upgraded` を偽としなければならない。(常時)
3.2. `grant_upgrade()` が呼ばれたとき、システムは `is_primary_upgraded` を真としなければならない。(イベント)
3.3. `is_primary_upgraded` が真である状態で `grant_upgrade()` が呼ばれたとき、システムは状態を変えてはならない(冪等)。(イベント)
3.4. システムは、`is_primary_upgraded` を時間の経過で偽に戻してはならない。(常時)
3.5. 外部から `is_primary_upgraded` へ直接代入した場合、または `set("is_primary_upgraded", ...)` を呼ばれた場合、システムは値を変えてはならない。(異常系)
3.6. システムは、ツリーへ載せていない `Player` に対しても `grant_upgrade()` を呼べるようにしなければならない。(常時)
3.7. システムは、`grant_upgrade()` で体力の状態を検査してはならない。(常時)
3.8. システムは、強化を取得するための入力(`project.godot` の `[input]` のアクション・`PlayerCommand` の項目)を追加してはならない。(常時)
3.9. システムは、強化の種類・残り回数・残り時間を表す状態を持ってはならない(真偽の 2 値だけを持つ)。(常時)

### Requirement 4: 強化中の主武器の発射

**対象**: §5.3 `Player` / §5.1 `SpreadResolver` / §5.2 `Projectile` / §6.5 `PlayerStats`

**受け入れ基準**:

4.1. `is_primary_upgraded` が真である状態で主武器が発射したとき、システムは弾を 3 発生成しなければならない。(イベント)
4.2. システムは、3 発の方向を `SpreadResolver.resolve(射撃方向)` の 3 要素と同じ順で一致させなければならない。(常時)
4.3. システムは、3 発に `stats.primary_damage`・`stats.primary_bullet_speed`・`stats.bullet_max_distance` を渡さなければならない。(常時)
4.4. `is_primary_upgraded` が真である状態で主武器が発射したとき、システムは `fired` を 1 回だけ発火し、その `direction` を射撃方向(8 方向)、`is_secondary` を偽としなければならない。(イベント)
4.5. `is_primary_upgraded` が真である状態で主武器が発射したとき、システムは `spread_fired` を 1 回だけ発火しなければならない。(イベント)
4.6. システムは、`spread_fired` の `directions` を、生成した 3 発の方向と同じ順で一致させなければならない。(常時)
4.7. システムは、`fired` を `spread_fired` より先に発火しなければならない。(常時)
4.8. `is_primary_upgraded` が偽である間、システムは主武器の発射で弾を 1 発だけ生成し、`spread_fired` を発火してはならない。(状態)
4.9. システムは、主武器の発射間隔を `is_primary_upgraded` によって変えてはならない。(常時)
4.10. 副武器で発射したとき、システムは `spread_fired` を発火してはならない。(イベント)
4.11. `projectile_scene` が未設定の場合、システムは `push_error` を出し弾を生成してはならない。(異常系)
4.12. `projectile_scene` が未設定で弾を生成できなかった場合、システムは `fired` も `spread_fired` も発火してはならない。(異常系)
4.13. システムは、拡散の弾をプレイヤーの子ノードにしてはならない(親へ載せる。親が無いときだけ自身へ載せる)。(常時)
4.14. システムは、拡散の弾の衝突レイヤを 3、マスクを 1 と 4 としなければならない(`Projectile` の流用によって満たす)。(常時)

### Requirement 5: 強化中の副武器

**対象**: §5.3 `Player` / §6.4 見た目の値 / unit #2 §5.5 `SecondaryWeapon`

**受け入れ基準**:

5.1. `is_primary_upgraded` が真である間も、システムは `cmd.secondary_held` をそのまま副武器へ渡さなければならない。(状態)
5.2. `is_primary_upgraded` が真である状態で副武器が発射したとき、システムは弾を 1 発生成し `fired(direction, true)` を 1 回発火しなければならない。(イベント)
5.3. システムは、`is_primary_upgraded` が真である間に生成した副武器の弾の `modulate` を `upgraded_secondary_tint` としなければならない。(状態)
5.4. `is_primary_upgraded` が偽である間、システムは生成した副武器の弾の `modulate` を `Color.WHITE` としなければならない。(状態)
5.5. システムは、`upgraded_secondary_tint` の既定値を `Color.WHITE` と異なる値としなければならない。(常時)
5.6. システムは、`upgraded_secondary_tint` を掛けた副武器の弾の描画色を、掛けていないときの描画色と異なる値としなければならない。(常時)
5.7. システムは、主武器の弾(強化の有無によらず)の `modulate` を `Color.WHITE` のままとしなければならない。(常時)
5.8. システムは、副武器の充電時間・クールダウン・威力・弾速を `is_primary_upgraded` によって変えてはならない。(常時)
5.9. システムは、`upgraded_secondary_tint` を `Player` の `@export` として持たなければならない(`PlayerStats` に置いてはならない)。(常時)
5.10. システムは、副武器の入力を主武器の強化へ移す処理(枠の占有)を持ってはならない。(常時)
5.11. システムは、`upgraded_secondary_tint` の既定値を `Player` のスクリプト側に持たせ、`player.tscn` で上書きしてはならない(`Player.new()` から作った場合と `player.tscn` から生成した場合とで値が一致しなければならない)。(常時)

### Requirement 6: プレイヤーの死亡による強化のリセット

**対象**: §5.3 `Player` / §6.2 主武器の強化の状態 / unit #2 §6.4 `Health`

**受け入れ基準**:

6.1. プレイヤーの体力が 0 に達したとき、システムは `is_primary_upgraded` を偽にしなければならない。(イベント)
6.2. システムは、`is_primary_upgraded` を偽にしてから `died` を発火しなければならない。(常時)
6.3. 体力が 0 に達した後、システムは主武器の発射で弾を 1 発だけ生成しなければならない(強化の解除が状態だけでなく発射にも及ぶ)。(状態)
6.4. システムは、強化のリセットを `Player` 自身が `Health.depleted` の経路で行わなければならない(シーンの再読込に依存してはならない)。(常時)
6.5. システムは、体力が 0 に達していない間、被弾によって `is_primary_upgraded` を変えてはならない。(状態)

### Requirement 7: 撃破位置に残る断片

**対象**: §5.4 `AnalysisFragment` / §6.4 見た目の値 / §6.6 衝突レイヤの割り当て

**受け入れ基準**:

7.1. システムは、`AnalysisFragment` を `Area2D` としなければならない。(常時)
7.2. システムは、`AnalysisFragment` の衝突マスクをプレイヤーのレイヤ(2)だけとしなければならない。(常時)
7.3. システムは、`AnalysisFragment` の衝突レイヤを 0 としなければならない(他の当たり判定に拾わせない)。(常時)
7.4. `grant_upgrade()` を持つ物体が触れたとき、システムはその物体の `grant_upgrade()` を呼ばなければならない。(イベント)
7.5. `grant_upgrade()` を持つ物体が触れたとき、システムは断片を解放しなければならない。(イベント)
7.6. `grant_upgrade()` を持たない物体が触れた場合、システムは断片を解放してはならず、`push_error` を出してはならない。(異常系)
7.7. 既に強化を持つ物体が触れたとき、システムは断片を解放しなければならない(強化の状態は変わらない)。(イベント)
7.8. システムは、時間の経過で断片を解放してはならない。(常時)
7.9. システムは、時間の経過で断片の位置を変えてはならない(重力を持たず、プレイヤーへ向かって移動しない)。(常時)
7.10. システムは、断片の解放に `queue_free()` を使わなければならない(`free()` を使ってはならない)。(常時)
7.11. システムは、断片が `Player` を型として静的に参照してはならない(`has_method()` で判定する)。(常時)
7.12. システムは、断片のシーンに `ColorRect` を 1 枚だけ持たせ、その寸法を 8×8px、原点を矩形の中心としなければならない。(常時)
7.13. システムは、断片の当たり判定の寸法を 8×8px とし、原点を中心としなければならない。(常時)
7.14. システムは、断片の `ColorRect` の色を、既存の placeholder が使う色のいずれとも異なる値としなければならない。比較の対象は `player.tscn`・`charger_enemy.tscn`・`shooter_enemy.tscn`・`projectile.tscn`・`enemy_projectile.tscn`・`damage_zone.tscn` が持つ `ColorRect` の色と、`dev_stage.tscn`・`enemy_dev_stage.tscn`・`analysis_dev_stage.tscn` の地形が持つ `ColorRect` の色とする。(常時)
7.15. システムは、断片の `ColorRect` の色を、強化中の副武器の弾の描画色と異なる値としなければならない。(常時)
7.16. システムは、断片に `Engine.time_scale` と `SceneTree.paused` を変更させてはならない(操作を止めない)。(常時)
7.17. システムは、断片に強化の種類を表す状態を持たせてはならない。(常時)
7.18. システムは、断片への接触を `body_entered` で受け取らなければならない(`area_entered` で受け取ってはならない)。(常時)

### Requirement 8: 断片の生成と写せる種別の判定

**対象**: §5.6 `AnalysisDevStage` / §5.5 `AbilityAnalysis` / §6.3 `EnemyKind.Kind` との対応

**受け入れ基準**:

8.1. 写せる種別の敵の `defeated` が届いたとき、システムは断片を 1 つ生成しなければならない。(イベント)
8.2. システムは、生成した断片の `global_position` を、撃破された敵の `global_position` としなければならない。(常時)
8.3. システムは、生成した断片をステージ自身の子として追加しなければならない(撃破された敵の子にしてはならない)。(常時)
8.4. 写せない種別の敵の `defeated` が届いたとき、システムは断片を生成してはならない。(イベント)
8.5. システムは、写せるかどうかの判定を `AbilityAnalysis.is_transferable()` に委ねなければならない(種別による分岐を `AbilityAnalysis` の外に置いてはならない)。(常時)
8.6. `EnemyKind.Kind.SHOOTER` が渡されたとき、システムは `AbilityAnalysis.is_transferable()` に真を返させなければならない。(イベント)
8.7. `EnemyKind.Kind.CHARGER` が渡されたとき、システムは `AbilityAnalysis.is_transferable()` に偽を返させなければならない。(イベント)
8.8. `EnemyKind.Kind` に存在しない値が渡された場合、システムは `AbilityAnalysis.is_transferable()` に `push_error` を出させ、偽を返させなければならない。(異常系)
8.9. `fragment_scene` が未設定の状態で写せる種別の `defeated` が届いた場合、システムは `push_error` を出し断片を生成してはならない。(異常系)
8.10. `fragment_scene` が未設定であっても、写せない種別の `defeated` が届いた場合、システムは `push_error` を出してはならない。(異常系)
8.11. システムは、`fragment_scene` をシーンの宣言で設定しなければならない。(常時)
8.12. システムは、`fragment_scene` が指すシーンのルートを `AnalysisFragment` としなければならない。(常時)
8.13. システムは、各敵の `defeated` を `[connection]` の宣言でステージのハンドラへ接続しなければならない(`_ready()` で接続してはならない)。(常時)
8.14. システムは、各 `defeated` の接続の `binds` に、その敵自身をステージから `get_node()` で解決できる相対の `NodePath` を持たせなければならない。(常時)
8.15. システムは、ステージから断片の取得へ関与する処理(プレイヤーを引いて `grant_upgrade()` を呼ぶ処理)を持ってはならない。(常時)

### Requirement 9: 仮ステージと目視の手順の文書

**対象**: §5.6 `AnalysisDevStage` / §6.7 ファイルの配置

**受け入れ基準**:

9.1. システムは、解析の確認用の仮ステージを 1 つだけ持たなければならない。(常時)
9.2. システムは、その仮ステージに、床・壁と `Player` 1 体・`ShooterEnemy` 1 体・`ChargerEnemy` 1 体を配置しなければならない(敵は合計 2 体であり、これを超えてはならない)。(常時)
9.3. システムは、プレイヤーの初期位置から敵の位置までの距離が `160 + その敵の detect_range` 以下となる敵を、2 体までとしなければならない(企画書 5.「同時に対処を要求する攻撃は 2 つまで」の、unit #3 §7 9.2 と同じ形の検査)。(常時)
9.4. システムは、プレイヤーから遠いほうの敵の初期位置を、その敵の `detect_range` より遠くに置かなければならない(手前の敵を先に相手にできる配置にする)。(常時)
9.5. システムは、`Player`・`ShooterEnemy`・`ChargerEnemy` の水平方向の範囲を、床の水平方向の範囲に収めなければならない。(常時)
9.6. システムは、`Player`・`ShooterEnemy`・`ChargerEnemy` を床の上に置かなければならない(垂直方向で床と重ならない)。(常時)
9.7. システムは、仮ステージの幅を基準解像度(320px)に収め、`Camera2D` を置いてはならない。(常時)
9.8. システムは、各敵の `target` をシーンの宣言で `Player` ノードへ指さなければならない(`_ready()` で検索してはならない)。(常時)
9.9. システムは、`player.died` の接続をシーンの `[connection]` として宣言しなければならない。(常時)
9.10. `player.died` が届いたとき、システムは現在のシーンの再読込をそのハンドラの呼び出しの中で走らせてはならない(`call_deferred` で遅らせる)。(イベント)
9.11. システムは、敵の出現を動的に行う仕組み(スポナー)を持ってはならない。(常時)
9.12. システムは、既存の `dev_stage.tscn` と `enemy_dev_stage.tscn` を変更してはならない。(常時)
9.13. システムは、`project.godot` の `run/main_scene` を `res://main.tscn` から変更してはならない。(常時)
9.14. システムは、`analysis_overwrite_dev_stage.tscn` と、それを検証するテストを削除しなければならない。(常時)
9.15. システムは、`docs/testing.md`「仮ステージを目視で確認する」の節から、解析の確認用の仮ステージが 2 つあることを述べた記述と、2 つ目のシーンの起動方法を取り除かなければならない。(常時)
9.16. システムは、`docs/testing.md`「仮ステージを目視で確認する」の節に、解析の確認用の仮ステージ 1 つの起動コマンドと、そこで確かめることを書かなければならない。(常時)
9.17. システムは、`docs/testing.md` の他の節(実行・終了コード・配置と命名・書き方・CI)を変更してはならない。(常時)
9.18. システムは、テストの配置と命名の規約(`docs/testing.md`「配置と命名」)に従わなければならない。(常時)
9.19. システムは、`docs/testing.md`「仮ステージを目視で確認する」の節から、第 3 の武器枠(残り回数・空枠への復帰)と解析の演出(撃破位置からプレイヤーへ飛ぶ表示)に言及する記述を取り除かなければならない。(常時)

### Requirement 10: 第 3 の武器枠の撤去

**対象**: §5.3 `Player` / §6.5 `PlayerStats` / §6.7 ファイルの配置

**受け入れ基準**:

10.1. システムは、`AbilitySlot` とそのテストを削除しなければならない。(常時)
10.2. システムは、`AnalysisPulse`・そのシーン・そのテストを削除しなければならない。(常時)
10.3. システムは、`Player` から `ability_slot`・`grant_ability()`・`ability_fired` を削除しなければならない。(常時)
10.4. システムは、`PlayerStats` から `ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed` を削除しなければならない。(常時)
10.5. システムは、`PlayerStats` の `@export` を unit #2 が定めた 14 項目ちょうどとしなければならない。(常時)
10.6. システムは、`src/` の下に `AbilitySlot`・`AnalysisPulse`・`ability_slot`・`ability_uses`・`ability_cooldown`・`ability_damage`・`ability_bullet_speed`・`ability_fired`・`grant_ability` のいずれの識別子も残してはならない。(常時)
10.7. システムは、削除した契約を検証していたテスト(`tests/ability/ability_slot_test.gd`・`tests/ability/analysis_pulse_test.gd`・`tests/ability/analysis_pulse_scene_test.gd`・`tests/player/player_ability_test.gd`・`tests/player/player_ability_stats_test.gd`・`tests/player/player_takeover_test.gd`・`tests/stage/analysis_overwrite_dev_stage_test.gd`)を削除しなければならない。(常時)
10.8. システムは、武器の枠を主武器・副武器の 2 つに限らなければならない(第 3 の枠を表す状態を持ってはならない)。(常時)
10.9. システムは、`AbilityAnalysis` と `tests/ability/ability_analysis_test.gd` を変更してはならない(第 3 の枠の撤去に巻き込んではならない)。(常時)
10.10. システムは、削除の後も `make test` の統計行の `orphans`・`skipped`・`failures`・`errors` をすべて 0 に保たなければならない。(常時)

### Requirement 11: 凍結済みの契約の非変更

**対象**: unit #2 §5.1・§5.2・§5.3・§5.4・§5.5・§5.6・§6.1・§6.3・§6.4・§6.5 / unit #3 §5.1・§6.3 / unit #4 §5.3

**受け入れ基準**:

11.1. システムは、`PlayerCommand` の 5 項目(`move_x`・`aim_y`・`jump_pressed`・`primary_held`・`secondary_held`)を変更してはならない。(常時)
11.2. システムは、`project.godot` の `[input]` の 7 アクションを変更してはならない。(常時)
11.3. システムは、`fired` の引数(`direction: Vector2i`・`is_secondary: bool`)を変更してはならない。(常時)
11.4. システムは、`PrimaryWeapon`・`SecondaryWeapon`・`AimResolver`・`Health` を変更してはならない。(常時)
11.5. システムは、`EnemyProjectile` を変更してはならない。(常時)
11.6. システムは、`Enemy.defeated` の引数を変更してはならない。(常時)
11.7. システムは、`project.godot` の `[layer_names]` のレイヤ 1〜5 の割り当てを変更してはならない。(常時)
11.8. システムは、unit #1〜#4 の `spec.md` と `tasks.md` を変更してはならない。(常時)
11.9. システムは、unit #1〜#3 の既存のテスト(`tests/harness/`・`tests/player/` の unit #2 由来分・`tests/enemy/`・`tests/weapon/`・`tests/stage/dev_stage_test.gd`・`tests/stage/enemy_dev_stage_test.gd`)を変更してはならない。(常時)
11.10. `Projectile.launch()` の `direction` の型を広げた後も、システムは `tests/weapon/projectile_test.gd` の全ケースを変更せずに通さなければならない。(常時)
11.11. `PlayerStats` から 4 項目を削除した後も、システムは `tests/player/player_stats_test.gd` の全ケースを変更せずに通さなければならない。(常時)
11.12. システムは、`PlayerStats` の既存 14 項目の既定値を変更してはならない。(常時)

### Requirement 12: 目視でしか確認できない振る舞い

**対象**: §5.4 `AnalysisFragment` / §5.6 `AnalysisDevStage` / §3 前提

**受け入れ基準**:

**検証の形式**: 本要件の各基準は**自動テストでは検証せず**、`godot --path <プロジェクトのルート> res://src/stage/analysis_dev_stage.tscn` で仮ステージを起動して目視で確認し、結果(いつ・どの環境で・何を確認したか)を `tasks.md` の `## Implementation Notes` に記録する。

12.1. 射撃型を撃破したとき、システムはその撃破位置に断片を表示しなければならない。(イベント)
12.2. 突進型を撃破したとき、システムは断片を表示してはならない。(イベント)
12.3. 断片に触れたとき、システムは断片を消し、主武器の弾を 3 発へ変えなければならない。20 度の広がりが 8 方向のどの向きでも見て取れることを記録する(§3 の前提の判断材料にする)。(イベント)
12.4. 強化中に副武器を撃ったとき、システムは強化前と異なる色の弾を表示しなければならない。(イベント)
12.5. 断片を 10 秒以上放置したとき、システムは断片を同じ位置に表示し続けなければならない(時間で消えず、落ちない)。(状態)
12.6. 強化を得た状態でプレイヤーが死亡してシーンが再読込されたとき、システムは主武器の弾を 1 発へ戻さなければならない。(イベント)
12.7. 撃破から取得を経て拡散で次の敵を倒すまでを通しで操作したとき、システムは操作を止めてはならない。所要時間と、強化が報酬に感じられたかを記録する。(イベント)

## 8. 実現方針(要点のみ)

- **企画書の語と識別子の対応。** このプロジェクトは用語集(`docs/glossary.md`)を持たないため、契約の命名は既存コードの語彙に合わせた(`.claude/skills/dev-core/references/durable-info.md` 5.2)。企画書の「断片」は `AnalysisFragment`、「強化」は `Player.is_primary_upgraded` と `grant_upgrade()`、「解析」は既存の `src/ability/`・`AbilityAnalysis` に対応する。unit #4 が使った `ability`(能力)は第 3 の武器枠と結び付いた語であり、枠を撤去する本単位では**強化を指す語として使わない**。ただし `AbilityAnalysis` は「写せる種別か」を返す関数であって枠に依存しないため、名前ごと流用する。

- **`Projectile.launch()` の `direction` を `Vector2` へ広げ、凍結済み文書との乖離を残す。** 20 度は 8 方向の格子に載らないため、`Vector2i` のままでは拡散の弾を撃てない。案は 3 つあった。(a) 型を広げる、(b) 拡散専用の弾クラスを新設する、(c) 角度を 45 度(8 方向の環の隣接)に戻す。(c) は人間が退けた決定であり、(b) はレイヤ・射程・地形との衝突の扱いが同じものを 2 つに分ける。**(a) を採った**(人間が確定済み)。副次的な利点として、unit #3 の `EnemyProjectile.launch()` が既に `Vector2` を取るため、2 種の弾の契約が揃う。
  - **凍結済み文書との乖離**: unit #2 `spec.md` §5.6 は `func launch(direction: Vector2i, ...)` と「`direction` は `Vector2i.ZERO` でないこと」を記す。凍結済みの中間生成物は変更しないため、この記述と実装が食い違う。
  - **さらに、`push_error` の文言だけが `Vector2i.ZERO` を指したまま残る。** 凍結済みの `tests/weapon/projectile_test.gd` が文言を自分の定数として固定しており、unit #1〜#3 のテストを変更しないという決定(§2)がこれを許さない。文言の訂正は、そのテストを改訂する後続の作業単位で行う。
  - **反映先**(恒久情報の配置規約に従う): (1) **テストコード**へ — 本単位が足す拡散のテストが「8 方向の外の向きで発射できる」という新しい契約を固定する(What の正本)。(2) **`Projectile.launch()` の doc コメント**へ — 型を広げたこと、および文言を据え置いた理由(凍結済みのテストが固定している)を書く(Why not の正本)。(3) **コミットログ**へ — なぜ型を広げたかを書く(Why の正本)。凍結済みの unit #2 `spec.md` は直さない。反映の実行は実装フェーズのタスクとする。

- **強化のリセットを `Player` が `Health.depleted` の経路で行う。** 実機のリトライはシーンの再読込であり、そこでは `Player` ごと作り直されるため強化は自然に消える。しかしその経路はテストから駆動できない(gdUnit のテストツリーで `reload_current_scene()` を呼ぶとテストの実行そのものが読み込むシーンを差し替える。unit #3・unit #4 の申し送り)。リセットを `Player` の契約に置くと `take_damage()` から観測でき、かつ実機の振る舞いは変わらない(再読込でも消える)。仮ステージ側にリセットを持たせる案は、後続のステージが同じ処理を書き写すことになるため退けた。

- **断片が触れた相手の `grant_upgrade()` を直接呼び、ステージは取得に関与しない。** unit #4 は「演出の到達 → ステージが `player.grant_ability()` を呼ぶ」形だった。断片は動的に生成されるためシーンの `[connection]` で宣言できず、ステージが実行時に接続する処理が要る。断片が自分で相手を検知して呼べば、その配線が丸ごと不要になり、断片を置くどのステージでも同じに動く。相手を `has_method()` で見ることで `src/ability/` から `src/player/` への静的な依存も生まれない(`Attackbox` と同じ規律。unit #3 §5.9)。

- **種別の分岐は `AbilityAnalysis` 1 箇所に閉じたままにする。** 断片を出すかどうかの判断はステージのハンドラが `AbilityAnalysis.is_transferable()` へ委ねる。断片自身に種別を持たせない: 強化は MVP では 1 種であり、種類を運ぶ引数は「1 種しか無いものを毎回同じ値で渡す」ことになる。写せる種別が増える段階で、断片へ種類を持たせるか断片の種類を増やすかを決める。

- **`AnalysisPulse` を削除し、演出をアイテムの出現そのものに置く。** 撃破位置からプレイヤーへ飛ぶ演出は「吸収」の見え方であり、本単位が変える取得の形(プレイヤーが取りに行く)と噛み合わない。飛翔の途中に取得の可否を判断する中間状態も無くなるため、`flight_time`・標的の追随・到達の発火といった契約が丸ごと不要になる。撃破した位置に断片が現れること自体が、解析が走ったことの表出になる。

- **見た目の変化を `modulate` で作り、弾のシーンを増やさない。** 強化中の副武器の弾に別の見た目を与える方法は 2 つあった。(a) 色だけが違う弾のシーンをもう 1 つ持つ、(b) 生成した弾へ `modulate` を掛ける。(a) はレイヤ・マスク・寸法・スクリプトの設定を 2 箇所に持つことになり、片方だけが変わる余地を作る。**(b) を採った**。代償は、乗算では基の色より明るい色を作れないことである(弾の placeholder は `Color(1, 0.85, 0.35)` であり、青の成分を 0.35 より上げられない)。この制約の中で最も見分けの付く緑を既定値に採った(§6.4)。将来スプライトへ差し替えても `modulate` はそのまま効く。

- **`fired` を拡張せず `spread_fired` を新設する。** `fired(direction: Vector2i, is_secondary: bool)` は凍結済みの unit #2 §5.1 の契約であり、引数を変えると既存の受け手にとって意味が変わる。20 度の向きは `Vector2i` で表せないため、方向の内容を読みたい受け手のために別のシグナルを置く。分けたことで「拡散の弾を副武器として出す」変異が、`fired` の `is_secondary` が偽であることと `spread_fired` が発火することの両方で落ちる。unit #4 の `ability_fired(directions: Array[Vector2i])` は、要素の型も意味(第 3 の枠の発射)も変わるため置き換える。

- **仮ステージを 1 つに統合する。** unit #4 は 2 つ持っていた。2 つ目(`analysis_overwrite_dev_stage.tscn`、射撃型 2 体)は「同種別の再取得で残り回数が満タンへ戻る」ことを見るための場だったが、強化が真偽 1 つになった本単位では再取得が冪等であり、目視で区別できる変化を起こさない。**確かめたいこと(射撃型の撃破で断片が出る / 突進型では出ない / 触れると拡散になる / 副武器の色が変わる / 死亡で戻る)は 1 つのシーンにすべて収まる。** 敵の体数の上限(§7 9.3 が課す「脅威の圏に入る敵は 2 体まで」)は射撃型 1・突進型 1 で満たす。この統合により `docs/testing.md` の「仮ステージを目視で確認する」の節も 2 つ分の記述から 1 つ分へ戻る(§7 9.15・9.16)。
  9.2〜9.7 を同時に満たす配置は unit #4 の 1 つ目のシーンと同じでよい(実装はこの値を採ってよい)。

  | `Player` | 手前の敵 | 奥の敵 | 距離と閾値 |
  | -------- | -------- | ------ | ---------- |
  | (48, 76) | `ShooterEnemy` (160, 84) | `ChargerEnemy` (248, 84) | 手前 ≈112.3 ≤ 320、奥 ≈200.2 ≤ 288 → 圏内 2 体。奥は `detect_range` 128 より遠い |

- **`[Nit]` 2 件を、本単位が作る仮ステージのテストに限って閉じる。** unit #4 の `tasks.md` が記録のみで残した 2 件である。(1)「床の上に立つ」の検査が垂直方向しか見ず、床を水平方向に縮めてもテストが緑のまま通る。(2) 新しい仮ステージの地形の色を誰も固定しておらず、色の重なりの検査(unit #4 §7 4.16)が事実上破れてもテストに現れない。本単位は前者を §7 9.5、後者を §7 7.14(比較の対象一覧に `analysis_dev_stage.tscn` の地形を含める)で閉じる。**unit #3 の `tests/stage/enemy_dev_stage_test.gd` には同じ弱さが残るが、そこには触れない**(凍結済み単位のテストであり、変更するとその改訂が要る。人間が確定済み)。

- **拡散の角度を `SpreadResolver` の公開定数に置く。** `PlayerStats` へ置く案は、強化専用の数値項目を足さないという決定(人間が確定済み)に反する。呼び出し側(`Player`)へ置く案は、角度を知る場所と 3 方向を組み立てる場所が分かれる。角度と並びを 1 つのクラスに閉じることで、拡散の形を変える作業が 1 ファイルで済む。

- **`is_primary_upgraded` を getter だけのプロパティにする。** 公開の可変フィールドにすると、外から任意に強化を付け外しでき、「取得と死亡だけが状態を変える」という不変条件を破れる。getter だけを持たせて非公開の状態から導けば、外からの代入は状態へ届かない(`AbilitySlot.is_empty` が採っていた形と同じ)。**ただし GDScript はこの代入を拒否しない**: Godot 4.7.1 では、静的に型が分かる経路でもパースエラー・実行時エラー・警告のいずれも出さず、代入を黙って無視する(§3 で実測済み)。したがってこれは「型で表現不能にする」対策ではなく、「不正な書き込みが状態へ届かない」対策である。呼び出し側が誤りに気付けない点は残るが、状態を壊せないことのほうを優先した。

## 9. 参考資料

- roadmap: `docs/specs/001-mvp/roadmap.md` §1.1「#### 5. `analysis-pickup`」・§4(凍結済み unit の相互参照の読み替え)
- unit #2 の契約: `docs/specs/001-mvp/002-foot-player/spec.md`(§5.1 `Player`・§5.2 `PlayerInput`・§5.3 `AimResolver`・§5.4 `PrimaryWeapon`・§5.5 `SecondaryWeapon`・§5.6 `Projectile`・§6.1 `PlayerStats`・§6.3 `PlayerCommand`・§6.4 `Health`・§6.5 衝突レイヤ)
- unit #3 の契約: `docs/specs/001-mvp/003-foot-enemies/spec.md`(§5.1 `Enemy`・§5.3 `ShooterEnemy`・§5.9 `Attackbox`・§6.3 `EnemyKind`・§7 Requirement 9)
- unit #4 の契約と申し送り: `docs/specs/001-mvp/004-analysis-ability/spec.md`(§5.2 `SpreadResolver`・§5.3 `AbilityAnalysis`・§5.4 `AnalysisPulse`・§5.6 `AnalysisDevStage`・§6.3・§6.5)と `tasks.md` の `## Implementation Notes`(`binds` の書式・`node_paths` の必要性・`[Nit]` 2 件)
- テストの規約: `docs/testing.md`
- 恒久情報の配置規約: `.claude/skills/dev-core/references/durable-info.md`
- 企画書(workspace リポジトリ `4_artifacts/netdiver/issues/01_game-design-doc/game-design-doc.md`): 3.(世界観と解析の位置づけ)・5.(干渉は操作を伴わない / 操作を 4 つに限る / 照準は 8 方向)・6.(武器の枠は 2 つ / 副武器は強化中も使える)・9.(MVP)・13.(能力の種類と同時に持てる数の暫定)
