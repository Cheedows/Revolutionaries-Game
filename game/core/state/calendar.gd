class_name Calendar
extends RefCounted
## The game date. Mirrors the day/month/year globals and datest in the original.
##
## The original starts on 1 January 2009 and advances one day at a time; months
## have their real lengths and February is 28 days in every year (the original
## does not model leap years, and neither does this).

const MONTH_LENGTHS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES := ["Jan.", "Feb.", "Mar.", "Apr.", "May", "June",
		"July", "Aug.", "Sept.", "Oct.", "Nov.", "Dec."]

var day: int = 1
var month: int = 1
var year: int = 2009


## Advances one day. Returns true when the month rolled over, which is what
## triggers the monthly turn.
func advance() -> bool:
	day += 1
	if day <= MONTH_LENGTHS[month - 1]:
		return false
	day = 1
	month += 1
	if month > 12:
		month = 1
		year += 1
	return true


## Days elapsed since 1 January of [member year], counting the first as 0.
func day_of_year() -> int:
	var elapsed := day - 1
	for index in month - 1:
		elapsed += MONTH_LENGTHS[index]
	return elapsed


func to_display() -> String:
	return "%s %d, %d" % [MONTH_NAMES[month - 1], day, year]
