class_name SaveMigrations
extends RefCounted
## Brings an older save document up to the current shape.
##
## Every save names its version, so a change to GameState means a migration
## here rather than a silently misread file. Returns {} when the document is
## from a version this build cannot read.

## Migrations are applied in order, each taking a document at version N and
## returning it at N + 1. Add one whenever GameState.SAVE_VERSION is bumped.
const STEPS := {}


static func migrate(document: Dictionary) -> Dictionary:
	var version := int(document.get("version", 0))
	if version > GameState.SAVE_VERSION:
		return {}  # written by a newer build
	while version < GameState.SAVE_VERSION:
		if not STEPS.has(version):
			return {}
		document = STEPS[version].call(document)
		version += 1
		document["version"] = version
	return document
