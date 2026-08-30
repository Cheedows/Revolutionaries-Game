class_name ShopDef
extends Resource
## A shop, or one department within a shop. Mirrors the Shop class in
## src/sitemode/shop.cpp, which is recursive: a department is itself a shop.

@export var name: StringName = &""

## Menu text for entering this shop or department.
@export var entry: String = ""

## Menu text for leaving it.
@export var exit: String = "Leave"

## Hotkey for the department in its parent's menu.
@export var letter: String = ""

@export var only_sell_legal_items: bool = false
@export var allow_selling: bool = false
@export var increase_prices_with_illegality: bool = false
@export var sell_masks: bool = false

## Whether the department takes over the whole screen. Inherited by children in
## the original; the extractor resolves that inheritance.
@export var fullscreen: bool = false

@export var departments: Array[ShopDef] = []
@export var items: Array[ShopItem] = []
