class_name FundingReport
extends RefCounted
## Snapshot the original fundreport() before monthly amounts are reset.

static func snapshot(state: GameState, catalog: Catalog) -> Dictionary:
	var assets := {&"weapon": 0, &"armor": 0, &"clip": 0, &"loot": 0}
	for place: Location in state.locations.values():
		for item: Item in place.ground_loot:
			var kind := item.item_class()
			if assets.has(kind):
				assets[kind] += Shopping.fence_value(item, catalog) * item.count
	return {"funds": state.ledger.funds,
		"income": state.ledger.income.duplicate(), "expense": state.ledger.expense.duplicate(),
		"daily_income": state.ledger.daily_income.duplicate(),
		"daily_expense": state.ledger.daily_expense.duplicate(), "assets": assets}
