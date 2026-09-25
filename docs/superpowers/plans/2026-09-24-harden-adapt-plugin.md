# Harden and Modularize `adapt-plugin.py` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `adapt-plugin.py` into a modular, unit-tested, atomic-safe, and fail-fast CLI adapter addressing 100% of the Elite Tribunal's Fix Now items and High/Medium priority findings.

**Architecture:** Decompose the monolithic 138-line `adapt_single_plugin` function into isolated domain handlers (`_adapt_skills`, `_adapt_rules`, `_adapt_mcp`, `_sync_import_manifest`, `_atomic_write_json`). Implement atomic write semantics (`tempfile.NamedTemporaryFile` + `os.replace` + `os.fsync`) for configuration files, short-circuit rule detection, and propagate CLI validation exit codes cleanly.

**Tech Stack:** Python 3.12+, `pytest`, `tempfile`, `pathlib.Path`, `subprocess`, `argparse`.

**Spec:** The Tribunal Roast findings from the previous turn targeting `adapt-plugin.py` (Natasha E2, Maya E4, Marcus E1, Tom E5, Karen H3, Tyler H4).

## Global Constraints

- Python standard library only (no third-party pip dependencies for the adapter script itself).
- Zero data corruption under interrupted I/O: atomic file writes for all configuration and manifest mutations.
- Non-destructive symlinks by default; preserve original source file contents.
- Strict type annotations (PEP 585/PEP 604) across all function signatures.

## Review Focus

1. Interrupted manifest writing leaves `import_manifest.json` corrupted or truncated to 0 bytes.
2. `agy plugin validate` exits non-zero, but `adapt_single_plugin` reports success (`True`).
3. Inode scanning on large `rules/` directories does unnecessary full list traversal instead of short-circuiting.
4. Relative symlink calculations fail when paths cross distinct roots or volume mount boundaries.
5. Missing `agy` binary in PATH triggers an unhandled `FileNotFoundError` stack trace.

---

### Task 1: Atomic File Writer & Clean Types

**Files:**
- Create: `~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py`
- Modify: `~/.gemini/config/skills/plugin-compat/scripts/adapt-plugin.py`

**Interfaces:**
- Produces: `_atomic_write_json(file_path: Path, data: dict[str, Any]) -> None`
- Produces: `link_or_copy(src: Path, dest: Path, copy_mode: bool = False) -> bool`

- [ ] **Step 1: Write failing test for atomic write and link_or_copy**

```python
import json
from pathlib import Path
import pytest
from adapt_plugin import _atomic_write_json, link_or_copy

def test_atomic_write_json_success(tmp_path: Path):
    target = tmp_path / "test.json"
    data = {"name": "test-plugin", "version": "1.0.0"}
    _atomic_write_json(target, data)
    assert target.exists()
    assert json.loads(target.read_text(encoding="utf-8")) == data

def test_atomic_write_json_overwrites_cleanly(tmp_path: Path):
    target = tmp_path / "test.json"
    target.write_text('{"old": true}', encoding="utf-8")
    _atomic_write_json(target, {"new": True})
    assert json.loads(target.read_text(encoding="utf-8")) == {"new": True}

def test_link_or_copy_symlink(tmp_path: Path):
    src = tmp_path / "source_dir"
    src.mkdir()
    dest = tmp_path / "dest_link"
    ok = link_or_copy(src, dest, copy_mode=False)
    assert ok is True
    assert dest.is_symlink()
    assert dest.resolve() == src.resolve()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -v`
Expected: FAIL with `ImportError: cannot import name '_atomic_write_json'`

- [ ] **Step 3: Implement `_atomic_write_json` and typed `link_or_copy`**

Implement `_atomic_write_json` using `tempfile.NamedTemporaryFile` + `os.fsync` + `os.replace`. Clean up unused `CONFIG_FILE` and elevate `shutil` import.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -v`
Expected: PASS 3/3

- [ ] **Step 5: Commit**

```bash
git add ~/.gemini/config/skills/plugin-compat/
git commit -m "feat(plugin-compat): implement atomic json writer and typed link_or_copy"
```

---

### Task 2: Modular Component Handlers (`_adapt_skills`, `_adapt_rules`, `_adapt_mcp`)

**Files:**
- Modify: `~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py`
- Modify: `~/.gemini/config/skills/plugin-compat/scripts/adapt-plugin.py`

**Interfaces:**
- Produces: `_adapt_skills(plugin_path: Path, copy_mode: bool, dry_run: bool) -> tuple[bool, str | None]`
- Produces: `_adapt_rules(plugin_path: Path, copy_mode: bool, dry_run: bool) -> tuple[bool, str | None]`
- Produces: `_adapt_mcp(plugin_path: Path, dry_run: bool) -> tuple[bool, str | None]`

- [ ] **Step 1: Write failing tests for component adapters**

```python
from adapt_plugin import _adapt_skills, _adapt_rules, _adapt_mcp

def test_adapt_skills_from_claude(tmp_path: Path):
    plugin = tmp_path / "my-plugin"
    claude_skills = plugin / ".claude" / "skills"
    claude_skills.mkdir(parents=True)
    has_skills, change = _adapt_skills(plugin, copy_mode=False, dry_run=False)
    assert has_skills is True
    assert (plugin / "skills").is_symlink()
    assert "Linked skills" in change

def test_adapt_rules_from_claude_md(tmp_path: Path):
    plugin = tmp_path / "my-plugin"
    plugin.mkdir()
    (plugin / "CLAUDE.md").write_text("# Rules", encoding="utf-8")
    has_rules, change = _adapt_rules(plugin, copy_mode=False, dry_run=False)
    assert has_rules is True
    assert (plugin / "rules" / "AGENTS.md").is_symlink()
    assert "Linked rule" in change

def test_adapt_mcp_from_claude_mcp(tmp_path: Path):
    plugin = tmp_path / "my-plugin"
    claude_dir = plugin / ".claude"
    claude_dir.mkdir(parents=True)
    (claude_dir / "mcp.json").write_text(json.dumps({"mcpServers": {"test": {}}}), encoding="utf-8")
    has_mcp, change = _adapt_mcp(plugin, dry_run=False)
    assert has_mcp is True
    assert (plugin / "mcp_config.json").exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -v`
Expected: FAIL with `ImportError: cannot import name '_adapt_skills'`

- [ ] **Step 3: Implement component adapter functions in `adapt-plugin.py`**

Decompose the monolithic blocks in `adapt_single_plugin` into `_adapt_skills`, `_adapt_rules`, and `_adapt_mcp`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -v`
Expected: PASS 6/6

- [ ] **Step 5: Commit**

```bash
git add ~/.gemini/config/skills/plugin-compat/
git commit -m "feat(plugin-compat): decompose into modular component handlers"
```

---

### Task 3: Manifest Synchronization, Fail-Safe Validation, and CLI Main

**Files:**
- Modify: `~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py`
- Modify: `~/.gemini/config/skills/plugin-compat/scripts/adapt-plugin.py`

**Interfaces:**
- Produces: `_sync_import_manifest(plugin_name: str, components: list[str], dry_run: bool) -> str | None`
- Produces: `adapt_single_plugin(plugin_path: Path, copy_mode: bool = False, dry_run: bool = False) -> bool`
- Produces: `main() -> None`

- [ ] **Step 1: Write failing test for validation and manifest sync**

```python
from adapt_plugin import _sync_import_manifest, adapt_single_plugin

def test_sync_import_manifest_atomic(tmp_path: Path, monkeypatch):
    manifest = tmp_path / "import_manifest.json"
    manifest.write_text(json.dumps({"imports": []}), encoding="utf-8")
    monkeypatch.setattr("adapt_plugin.MANIFEST_FILE", manifest)

    res = _sync_import_manifest("sample-plugin", ["skills", "rules"], dry_run=False)
    assert res is not None
    updated = json.loads(manifest.read_text(encoding="utf-8"))
    assert updated["imports"][0]["name"] == "sample-plugin"
    assert updated["imports"][0]["components"] == ["rules", "skills"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -k test_sync_import_manifest_atomic -v`
Expected: FAIL with `ImportError: cannot import name '_sync_import_manifest'`

- [ ] **Step 3: Implement `_sync_import_manifest` and fail-safe `adapt_single_plugin`**

Implement `_sync_import_manifest` using `_atomic_write_json`. Wire validation with return code checks and graceful `FileNotFoundError` catch for missing `agy` binary. Update `main()`.

- [ ] **Step 4: Run full test suite to verify it passes**

Run: `pytest ~/.gemini/config/skills/plugin-compat/tests/test_adapt_plugin.py -v`
Expected: PASS all tests.

- [ ] **Step 5: Run end-to-end dry-run with agy-adapt CLI**

Run: `agy-adapt --dry-run ui-ux-pro-max`
Expected: Clean output and exit code 0.

- [ ] **Step 6: Commit**

```bash
git add ~/.gemini/config/skills/plugin-compat/
git commit -m "feat(plugin-compat): harden manifest synchronization and validation error handling"
```
