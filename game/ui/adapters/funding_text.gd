class_name FundingText
extends RefCounted
## Original fundreport() category names and ordering.
const INCOME := {
	&"brownies": "Brownies", &"cars": "Car Sales", &"ccfraud": "Credit Card Fraud",
	&"donations": "Donations", &"sketches": "Drawing Sales", &"embezzlement": "Embezzlement",
	&"extortion": "Extortion", &"hustling": "Hustling", &"pawn": "Pawning Goods",
	&"prostitution": "Prostitution", &"busking": "Street Music", &"thievery": "Thievery",
	&"tshirts": "T-Shirt Sales",
}
const EXPENSE := {
	&"troublemaking": "Activism", &"confiscated": "Confiscated", &"dating": "Dating",
	&"sketches": "Drawing Materials", &"food": "Groceries", &"hostage": "Hostage Tending",
	&"legal": "Legal Fees", &"manufacture": "Manufacturing", &"cars": "New Cars",
	&"shopping": "Purchasing Goods", &"recruitment": "Recruitment", &"rent": "Rent",
	&"compound": "Safehouse Investments", &"training": "Training", &"travel": "Travel",
	&"tshirts": "T-Shirt Materials",
}
const ASSETS := {&"weapon": "Tools and Weapons", &"armor": "Clothing and Armor",
	&"clip": "Ammunition", &"loot": "Miscellaneous Loot"}

static func rows(data: Dictionary, side: String) -> Array[Dictionary]:
	var names: Dictionary = INCOME if side == "income" else EXPENSE
	var book: Dictionary = data.get(side, {})
	var daily: Dictionary = data.get("daily_" + side, {})
	var rows: Array[Dictionary] = []
	for key in names:
		if int(book.get(key, 0)) != 0:
			rows.append({"label": names[key], "month": int(book[key]), "day": int(daily.get(key, 0))})
	var other := 0
	var other_day := 0
	for key in book:
		if not names.has(key):
			other += int(book[key])
			other_day += int(daily.get(key, 0))
	if other != 0:
		rows.append({"label": "Other Income" if side == "income" else "Other Expenses",
			"month": other, "day": other_day})
	return rows

static func total(book: Dictionary) -> int:
	var amount := 0
	for value in book.values(): amount += int(value)
	return amount

static func money(amount: int, signed: bool = true) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else ("+" if signed and amount > 0 else "")) + "$" + digits + grouped
