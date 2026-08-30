class_name ShopItem
extends Resource
## One purchasable line in a shop menu. Mirrors Shop::ShopItem in
## src/sitemode/shop.cpp.

## &"weapon", &"clip", &"armor" or &"loot".
@export var item_class: StringName = &""

## Idname of the type sold.
@export var type: StringName = &""

## Menu text; when empty the original falls back to the item's own name.
@export var description: String = ""

@export var price: int = 0
@export var sleeperprice: int = 0

## Hotkey. The original lowercases letters and also accepts "!".
@export var letter: String = ""
