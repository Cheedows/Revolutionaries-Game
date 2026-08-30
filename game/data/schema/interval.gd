class_name Interval
extends Resource
## An inclusive integer range, as written "6" or "6-10" in art/*.xml.
## Mirrors the Interval class in src/includes.h. Rolling one is a core concern
## (it consumes the RNG), so it lives in core/, not here.

@export var min: int = 0
@export var max: int = 0
