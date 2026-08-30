class_name OrganCare
extends RefCounted
## What it takes to put each organ back, and what it costs when it cannot be.
##
## The original writes this as a switch with no breaks in it (the special-wound
## cases in advanceday(), src/daily/daily.cpp), so a heart falls through the
## lungs into the abdomen and collects all three sets of consequences. Written
## out here as the table the fall-through actually describes.
##
## Each row is [difficulty, whole, bleed, permanent]:
## [code]whole[/code] is what the field reads as once it is repaired, and
## [code]permanent[/code] marks the injuries that can cost health for good.

const RULES := {
	# The heart falls through everything below it: the lungs' permanent damage,
	# and the abdomen's extra point of bleeding on top of its own eight.
	&"heart": [16, 1, 9, true],
	&"rightlung": [14, 1, 1, true],
	&"leftlung": [14, 1, 1, true],
	&"liver": [14, 1, 1, false],
	&"stomach": [14, 1, 1, false],
	&"rightkidney": [14, 1, 1, false],
	&"leftkidney": [14, 1, 1, false],
	&"spleen": [14, 1, 1, false],
	# Ribs are counted rather than flagged, and knitting them costs nothing.
	&"ribs": [14, 10, 0, false],
	&"neck": [14, 2, 0, false],
	&"upperspine": [14, 2, 0, false],
	&"lowerspine": [14, 2, 0, false],
}
