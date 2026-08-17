class_name AbilitySlot
extends RefCounted

## 第 3 の武器枠の残り回数とクールダウンを進める状態機械。
##
## ノードにしない: 経過時間は呼び出し側が `update()` で進めるため、物理フレームを必要としない。

const INVALID_USES_ERROR_FORMAT: String = (
	"AbilitySlot.grant(): uses は正でなければならない(現在値: %s)。状態を変えずに返る"
)

var remaining_uses: int = 0

## 残り回数から導く。独立した状態として持たない: 独立して持つと、
## 残り回数と食い違う状態を作れてしまう
var is_empty: bool:
	get:
		return remaining_uses <= 0

var _cooldown: float
var _cooldown_elapsed: float = 0.0

## 独立した状態として持つ: 呼び出し側は前フレームの入力を持たず、縁の検出は
## この状態機械に閉じる
var _was_held: bool = false


## 引数の検査を持たない: `cooldown` の出どころは `PlayerStats` であり、0 以下の値は
## `Player._ready()` が検査する
func _init(cooldown: float) -> void:
	_cooldown = cooldown


## 残り回数を `uses` で上書きする。
##
## 事前条件: `uses` は正。事後条件: `remaining_uses == uses`。
## 直後の押下の縁で `update()` が真を返しうる
func grant(uses: int) -> void:
	if uses <= 0:
		push_error(INVALID_USES_ERROR_FORMAT % uses)
		return

	# 加算しない: 保持するのは直近に取得した 1 種だけであり、取得のたびに置き換わる
	remaining_uses = uses
	# 経過を 0 に戻さない: 戻すと取得の直後の 1 発目が 1 回分待たされる
	_cooldown_elapsed = _cooldown


## 1 フレーム分進め、このフレームで発射するなら真を返す。
##
## 事後条件: 真を返す間隔は常に `cooldown` 以上
func update(held: bool, delta: float) -> bool:
	_cooldown_elapsed += delta

	var is_edge: bool = held and not _was_held
	# 発射しないフレームでも記録を飛ばさない: 飛ばすと、押しっぱなしのボタンが
	# 後のフレームで縁と誤認され、意図しない 1 発が出る
	_was_held = held

	if not is_edge:
		return false

	if _cooldown_elapsed < _cooldown:
		return false

	# 余りを繰り越さない: 繰り越すと発射の間隔が cooldown より短くなり、事後条件を破る
	_cooldown_elapsed = 0.0
	remaining_uses -= 1
	return true
