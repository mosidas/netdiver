#!/usr/bin/env python3
"""Aseprite CLI が書き出した JSON から Godot の SpriteFrames リソース(.tres)を生成する。

Aseprite 側は `--data ... --list-tags` で書き出すこと(--list-tags がないと
JSON に frameTags が入らず、タグをアニメーション名に使えない)。

実行例:
  python3 ase_json_to_spriteframes.py \
      assets/sprites/enemy_drone_idle.json \
      assets/sprites/enemy_drone_idle.tres \
      --texture res://assets/sprites/enemy_drone_idle.png
"""

import argparse
import json
from pathlib import Path


def build_tres(data: dict, texture_path: str) -> str:
    frames = data["frames"]
    tags = data["meta"].get("frameTags") or [
        {"name": "default", "from": 0, "to": len(frames) - 1, "direction": "forward"}
    ]

    # AtlasTexture はタグ間で共有せず、参照されるフレームだけ定義する
    used = sorted({i for t in tags for i in range(t["from"], t["to"] + 1)})
    subs = []
    for i in used:
        f = frames[i]["frame"]
        subs.append(
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]\n'
            f'atlas = ExtResource("1_tex")\n'
            f'region = Rect2({f["x"]}, {f["y"]}, {f["w"]}, {f["h"]})\n'
        )

    anims = []
    for t in tags:
        idx = list(range(t["from"], t["to"] + 1))
        if t.get("direction") == "reverse":
            idx.reverse()
        elif t.get("direction") == "pingpong" and len(idx) > 2:
            idx = idx + idx[-2:0:-1]

        # Godot は speed(FPS)と frame ごとの相対 duration で表現する。
        # 最短フレームを 1.0 の基準にし、他はその倍率で表す。
        durations = [max(1, frames[i].get("duration", 100)) for i in idx]
        base_ms = min(durations)
        entries = ",\n".join(
            f'{{\n"duration": {d / base_ms:.6g},\n"texture": SubResource("AtlasTexture_{i}")\n}}'
            for i, d in zip(idx, durations)
        )
        anims.append(
            "{\n"
            f'"frames": [{entries}],\n'
            '"loop": true,\n'
            f'"name": &"{t["name"]}",\n'
            f'"speed": {1000.0 / base_ms:.6g}\n'
            "}"
        )

    load_steps = len(subs) + 2  # ext_resource 1 + sub_resources + resource 本体
    head = f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n\n'
    ext = f'[ext_resource type="Texture2D" path="{texture_path}" id="1_tex"]\n\n'
    body = "\n".join(subs)
    res = "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
    return head + ext + body + res


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("json_path", type=Path)
    ap.add_argument("tres_path", type=Path)
    ap.add_argument("--texture", required=True, help="res:// から始まるテクスチャのパス")
    args = ap.parse_args()

    data = json.loads(args.json_path.read_text())
    args.tres_path.write_text(build_tres(data, args.texture))

    tags = data["meta"].get("frameTags") or []
    names = ", ".join(t["name"] for t in tags) or "default"
    print(f"wrote {args.tres_path} (frames={len(data['frames'])}, animations={names})")


if __name__ == "__main__":
    main()
