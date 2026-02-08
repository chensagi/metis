---
name: python
version: 0.1.0
description: Python project conventions, virtual environments, and tooling
requires: []
provides:
  - python-runtime
  - virtual-environments
  - pip-packages
commands:
  verify: "python -m py_compile {file}"
  test: "python -m pytest"
  lint: "python -m ruff check"
  format: "python -m ruff format"
  typecheck: "python -m mypy ."
---

# Python Capability

## Agent Instructions

This is a Python project. Follow these conventions:

### Virtual Environments

- Check for `venv/`, `.venv/`, or `env/` directories
- If using `pyproject.toml`, the project may use `uv`, `poetry`, or `hatch`
- Always run commands through the virtual environment: `python -m pytest` (not bare `pytest`)

### Project Detection

| File | Tool |
|------|------|
| `pyproject.toml` with `[tool.poetry]` | Poetry |
| `pyproject.toml` with `[build-system]` | pip/setuptools or uv |
| `setup.py` | setuptools |
| `requirements.txt` | pip |
| `Pipfile` | pipenv |

### Code Conventions

- Use type hints for function signatures
- Follow PEP 8 (ruff handles this)
- Use `pathlib.Path` instead of `os.path`
- Use f-strings for string formatting
- Use `dataclasses` or `pydantic` for structured data

### Testing

- Tests in `tests/` directory (or `test_*.py` files)
- Use `pytest` (not unittest)
- Run: `python -m pytest` or `python -m pytest tests/test_specific.py`
- Use `pytest-cov` for coverage: `python -m pytest --cov`

### Import Conventions

- Standard library first, then third-party, then local
- Use absolute imports from the package root
- Avoid circular imports — restructure if needed
