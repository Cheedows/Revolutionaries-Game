class_name Money
extends Item
## Cash lying on the floor or in a pocket. [member Item.count] is the amount.


func item_class() -> StringName:
	return &"money"
