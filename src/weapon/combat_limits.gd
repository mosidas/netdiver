class_name CombatLimits
extends RefCounted

## 敵の攻撃が満たすべき上限。
##
## 使うのは foot-enemies(unit #3)だが、値の根拠がプレイヤーの移動速度に依存するため
## ここに置く。本単位のコードからは参照しない。

## 敵弾の弾速の上限。
##
## 算出: プレイヤーの移動速度 100 px/s、反応に 0.3 秒、1 タイル(16px)の回避に 0.16 秒で
## 合計 0.46 秒。弾が画面の半分(160px)を進む時間がこれを上回る必要があり上限は 348 px/s。
## 余裕を取って 150 px/s とする
const ENEMY_BULLET_MAX_SPEED: float = 150.0

## 敵の攻撃の予備動作の下限。回避に要する 0.46 秒に対し、気付いてから動き出す猶予を残す
const ENEMY_TELEGRAPH_MIN_TIME: float = 0.4
