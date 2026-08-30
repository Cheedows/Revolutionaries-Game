class_name Ledger
extends RefCounted
## Money, and where it came from and went. Mirrors the Ledger class in
## src/includes.h.
##
## Income and expense are tracked per category twice over: a monthly figure the
## funding report shows and resets, and a daily figure the daily report uses.

## The original starts the squad with seven dollars.
const STARTING_FUNDS := 7

var funds: int = STARTING_FUNDS
var total_income: int = 0
var total_expense: int = 0

var income: Dictionary = {}
var expense: Dictionary = {}
var daily_income: Dictionary = {}
var daily_expense: Dictionary = {}


func add(amount: int, source: StringName) -> void:
	funds += amount
	total_income += amount
	income[source] = int(income.get(source, 0)) + amount
	daily_income[source] = int(daily_income.get(source, 0)) + amount


func subtract(amount: int, purpose: StringName) -> void:
	funds -= amount
	total_expense += amount
	expense[purpose] = int(expense.get(purpose, 0)) + amount
	daily_expense[purpose] = int(daily_expense.get(purpose, 0)) + amount


## Whether [param amount] can be spent without going into the red.
func can_afford(amount: int) -> bool:
	return funds >= amount


## Called at the start of each month, after the funding report.
func reset_monthly() -> void:
	income.clear()
	expense.clear()


## Called at the start of each day, after the daily report.
func reset_daily() -> void:
	daily_income.clear()
	daily_expense.clear()
