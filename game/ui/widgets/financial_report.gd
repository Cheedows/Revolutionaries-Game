class_name FinancialReport
extends VBoxContainer
## A scrolling ledger with a fixed acknowledgement, sized for a phone or desk.
signal acknowledged
var _body: VBoxContainer
var _inset: MarginContainer
var _number_rows: Array[BoxContainer] = []

func show_report(data: Dictionary) -> void:
	_number_rows.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", Metrics.ROOM)
	add_child(Atoms.wrapped(Atoms.title("Liberal Crime Squad: Funding Report")))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Metrics.page_scroller(scroll)
	add_child(scroll)
	_body = Atoms.column(Metrics.ROOM)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inset = MarginContainer.new()
	_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inset)
	_inset.add_child(_body)
	for side in ["income", "expense"]:
		var section := Atoms.column(Metrics.SNUG)
		_body.add_child(section)
		section.add_child(Atoms.heading("Income" if side == "income" else "Expenses"))
		var grid := _table(section)
		var sign := 1 if side == "income" else -1
		for row in FundingText.rows(data, side):
			_row(grid, row.label, sign * int(row.month), sign * int(row.day))
		_row(grid, "Total Income" if side == "income" else "Total Expenses",
			sign * FundingText.total(data.get(side, {})), sign * FundingText.total(data.get("daily_" + side, {})), true)
	var net := FundingText.total(data.get("income", {})) - FundingText.total(data.get("expense", {}))
	var today := FundingText.total(data.get("daily_income", {})) - FundingText.total(data.get("daily_expense", {}))
	var summary := _table(_body)
	_row(summary, "Net Change This Month (Day):", net, today, true)
	_body.add_child(Atoms.heading("Liquid Assets"))
	var assets := _table(_body)
	var cash := int(data.get("funds", 0))
	_row(assets, "Cash", cash, null, true, false)
	var values: Dictionary = data.get("assets", {})
	for kind in FundingText.ASSETS:
		_row(assets, FundingText.ASSETS[kind], int(values.get(kind, 0)), null, false, false)
	_row(assets, "Total Liquid Assets:", cash + FundingText.total(values), null, true, false)
	var carry := Atoms.primary("Carry on")
	carry.pressed.connect(func() -> void: acknowledged.emit())
	add_child(carry)
	_reflow()
	PressFeel.teach(self)

func _table(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", Metrics.ROOM)
	grid.add_theme_constant_override(&"v_separation", Metrics.SNUG)
	parent.add_child(grid)
	return grid

func _row(grid: GridContainer, title: String, amount: int, daily: Variant,
		strong: bool = false, signed: bool = true) -> void:
	var label := Atoms.wrapped(Atoms.heading(title) if strong else Atoms.body(title))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var numbers := Atoms.split(Metrics.SNUG)
	_number_rows.append(numbers)
	numbers.size_flags_horizontal = Control.SIZE_FILL
	grid.add_child(numbers)
	var value := Atoms.tinted(FundingText.money(amount, signed), _ink(amount))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numbers.add_child(value)
	if daily != null:
		var day := Atoms.tinted("(%s today)" % FundingText.money(int(daily)), _ink(int(daily)))
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		numbers.add_child(day)

static func _ink(amount: int) -> Color:
	return Palette.INCOME if amount > 0 else (Palette.EXPENSE if amount < 0 else Palette.TEXT_DIM)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _inset != null:
		_reflow.call_deferred()

func _reflow() -> void:
	if not is_instance_valid(_inset): return
	# Keep a readable line length on a desktop and clear the scrollbar on phones.
	var side := maxi(Metrics.ROOM, int((size.x - Metrics.PHONE_WIDTH) / 2))
	_inset.add_theme_constant_override(&"margin_left", side)
	_inset.add_theme_constant_override(&"margin_right", side)
	for row in _number_rows:
		Atoms.stack(row, Metrics.narrow(self))
