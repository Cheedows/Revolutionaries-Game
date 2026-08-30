#!/usr/bin/env python3
"""Minimal Godot .tres writer for generated content resources.

Only what the extractor needs: a root resource, nested sub-resources, and the
scalar/array/dictionary types the schema classes in game/data/schema use.
"""
from pathlib import Path


class Res:
    """A resource instance: a schema script plus its exported properties."""

    def __init__(self, script: str, props: dict):
        self.script = script          # e.g. "weapon_type.gd"
        self.props = props


def _fmt(value, subs, order):
    if isinstance(value, Res):
        return f'SubResource("{_register(value, subs, order)}")'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, StringName):
        return f'&"{_escape(str(value))}"'
    if isinstance(value, str):
        return f'"{_escape(value)}"'
    if isinstance(value, list):
        inner = ", ".join(_fmt(v, subs, order) for v in value)
        if value and isinstance(value[0], Res):
            return f"Array[Resource]([{inner}])"
        if value and isinstance(value[0], StringName):
            return f"Array[StringName]([{inner}])"
        return f"[{inner}]"
    if isinstance(value, PackedInt32Array):
        return "PackedInt32Array(" + ", ".join(str(int(v)) for v in value) + ")"
    if isinstance(value, dict):
        inner = ", ".join(
            f"{_fmt(k, subs, order)}: {_fmt(v, subs, order)}" for k, v in value.items()
        )
        return "{" + inner + "}"
    if value is None:
        return "null"
    raise TypeError(f"cannot serialize {type(value).__name__}: {value!r}")


class PackedInt32Array(list):
    """Marks a list of ints that must serialize as a Godot PackedInt32Array."""


class StringName(str):
    """Marks a string that must serialize as a Godot StringName."""


def _escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _register(res, subs, order):
    key = id(res)
    if key not in subs:
        subs[key] = f"Sub_{len(subs) + 1}"
        order.append(res)
    return subs[key]


def write(path: Path, root: Res, schema_dir: str = "res://data/schema") -> None:
    """Writes [param root] and everything it references to [param path]."""
    subs: dict = {}
    order: list = []

    # Post-order: a sub-resource must be declared before anything referencing
    # it, or Godot's text loader rejects the file.
    def visit(res: Res):
        for value in res.props.values():
            for item in _walk(value):
                visit(item)
        if id(res) not in subs:
            subs[id(res)] = f"Sub_{len(subs) + 1}"
            order.append(res)

    for value in root.props.values():
        for item in _walk(value):
            visit(item)

    rendered = [(subs[id(sub)], sub, {k: _fmt(v, subs, order) for k, v in sub.props.items()})
                for sub in order]
    root_props = {k: _fmt(v, subs, order) for k, v in root.props.items()}

    scripts: dict = {}
    for _, sub, _props in rendered:
        scripts.setdefault(sub.script, f"Script_{len(scripts) + 1}")
    scripts.setdefault(root.script, f"Script_{len(scripts) + 1}")

    lines = [
        f'[gd_resource type="Resource" script_class="{_class_name(root.script)}" '
        f"load_steps={len(scripts) + len(rendered) + 1} format=3]",
        "",
    ]
    for script, ident in scripts.items():
        lines.append(f'[ext_resource type="Script" path="{schema_dir}/{script}" id="{ident}"]')
    lines.append("")

    for ident, sub, props in rendered:
        lines.append(f'[sub_resource type="Resource" id="{ident}"]')
        lines.append(f'script = ExtResource("{scripts[sub.script]}")')
        for key, formatted in props.items():
            lines.append(f"{key} = {formatted}")
        lines.append("")

    lines.append("[resource]")
    lines.append(f'script = ExtResource("{scripts[root.script]}")')
    for key, formatted in root_props.items():
        lines.append(f"{key} = {formatted}")
    lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines))


def _walk(value):
    """Yields every Res reachable from a property value."""
    if isinstance(value, Res):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from _walk(item)
    elif isinstance(value, dict):
        for key, item in value.items():
            yield from _walk(key)
            yield from _walk(item)


def _class_name(script: str) -> str:
    return "".join(part.capitalize() for part in script.removesuffix(".gd").split("_"))
