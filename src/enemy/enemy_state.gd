class_name EnemyState
extends RefCounted

## 敵の状態。2 種で 1 つの enum を共有する。
##
## 種別ごとに別の enum を置かないのは、撃破時の解析が敵の状態を読むときに読み替えを
## 要らなくするためである。突進型は IDLE / TELEGRAPH / CHARGE / RECOVER を、
## 射撃型は IDLE / TELEGRAPH / COOLDOWN を使う。
enum State { IDLE, TELEGRAPH, CHARGE, COOLDOWN, RECOVER }
