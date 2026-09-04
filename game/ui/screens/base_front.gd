class_name BaseFront
extends RefCounted
## What is in front of the page, and how it gets there.
##
## A panel is not part of the safehouse screen any more. It comes to the front
## in a [Sheet], over a darkened copy of the page, and the page is still there
## to go back to — which is what let the screen stop giving nine panels a share
## of a phone that has room for one.
##
## Split out of base_screen.gd because it is one subject: everything here is
## about what is on top and how it is put away. The screen decides *when*.

## Brings one of the panels to the front.
static func panel(parts: Dictionary, session: Session, which: StringName,
		subject: Variant, narrow: bool) -> void:
	(parts["panels"] as PanelStack).open(which, session, subject)
	settle(parts, narrow)


## Brings the list of everything that can be looked at to the front.
##
## Only reached on a phone: on a desk the buttons are along the bottom of the
## screen already and the list is never built into anything.
static func menu(parts: Dictionary, narrow: bool) -> void:
	var sheet: Sheet = parts["sheet"]
	sheet.show_it(parts["menu"])
	sheet.compact(narrow)
	_hold_the_page(parts, true)


## Puts whatever should be in front in front, and the page back when nothing
## should be.
##
## The panels are handed back to the column they came from rather than left in
## the sheet, so the screen that built them still owns them.
static func settle(parts: Dictionary, narrow: bool) -> void:
	var sheet: Sheet = parts["sheet"]
	if (parts["panels"] as PanelStack).is_open():
		sheet.show_it(parts["panels"])
		sheet.compact(narrow)
		_hold_the_page(parts, true)
	else:
		sheet.dismiss()
		_hold_the_page(parts, false)


## Takes one step back out of whatever is in front, and says whether it did.
static func step_back(parts: Dictionary) -> bool:
	var sheet: Sheet = parts["sheet"]
	if not sheet.showing():
		return false
	sheet.dismiss()
	(parts["panels"] as PanelStack).open(PanelStack.NONE, null)
	_hold_the_page(parts, false)
	return true


## Stops the page scrolling while something is in front of it, and lets it go
## again afterwards.
##
## A modal that leaves the page scrolling behind it is a drag that does the
## wrong thing: the finger is on the sheet, the page moves, and the thing the
## player was reading goes somewhere else. It is also the rule a phone gets one
## scroller — while a sheet is up, the sheet is the one.
static func _hold_the_page(parts: Dictionary, held: bool) -> void:
	var scroll: ScrollContainer = parts["scroll"]
	# Held means "no bar and nothing to drag", not "disabled". A disabled
	# [ScrollContainer] reports its content's height as its own, so the page
	# behind the sheet grows to whatever it holds and its bottom ends up past
	# the window — where it stays until something scrolls, which it now cannot.
	# Show-never keeps it the size of the window, and the sheet is what eats
	# the drag, being a full-screen control that stops input.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER \
			if held else ScrollContainer.SCROLL_MODE_AUTO
