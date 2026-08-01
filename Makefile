# ピクセルアートのビルド。
# art_src/*.aseprite を Aseprite CLI で書き出し、Godot の SpriteFrames まで生成する。
#
#   make            スプライトシート・JSON・SpriteFrames を生成する
#   make clean      生成物を削除する
#
# Aseprite の場所が違う環境では ASEPRITE を上書きする:
#   make ASEPRITE=/Applications/Aseprite.app/Contents/MacOS/aseprite

ASEPRITE ?= /Users/shota/Library/Application Support/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite
PYTHON ?= python3

SRC_DIR := art_src
OUT_DIR := assets/sprites

SOURCES := $(wildcard $(SRC_DIR)/*.aseprite)
TARGETS := $(patsubst $(SRC_DIR)/%.aseprite,$(OUT_DIR)/%.tres,$(SOURCES))

.PHONY: all clean
all: $(TARGETS)

# --list-tags を付けないと JSON に frameTags が入らず、タグ名をアニメーション名に使えない。
# .png はこのルールの副産物として同時に生成される。
$(OUT_DIR)/%.json: $(SRC_DIR)/%.aseprite
	@mkdir -p $(OUT_DIR)
	"$(ASEPRITE)" -b $< \
		--sheet $(OUT_DIR)/$*.png --sheet-type horizontal \
		--data $@ --format json-array \
		--list-tags --list-layers

$(OUT_DIR)/%.tres: $(OUT_DIR)/%.json
	$(PYTHON) $(SRC_DIR)/scripts/ase_json_to_spriteframes.py $< $@ \
		--texture res://$(OUT_DIR)/$*.png

clean:
	rm -f $(OUT_DIR)/*.png $(OUT_DIR)/*.json $(OUT_DIR)/*.tres

.PRECIOUS: $(OUT_DIR)/%.json
