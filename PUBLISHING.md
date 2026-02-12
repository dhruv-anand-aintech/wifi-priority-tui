# Publishing to PyPI

This guide explains how to publish `wifi-priority-tui` to PyPI.

## Prerequisites

```bash
# Install build tools
uv pip install build twine

# Set up PyPI account at https://pypi.org/account/register/
# Create API token at https://pypi.org/manage/account/token/
```

## Publishing Steps

### 1. Update Version

Edit `pyproject.toml` and bump the version number:
```toml
version = "0.1.1"  # Increment appropriately
```

### 2. Build Distribution

```bash
# Clean old builds
rm -rf dist/ build/ *.egg-info/

# Build wheel and source distribution
python -m build
```

This creates:
- `dist/wifi_priority_tui-<version>-py3-none-any.whl` (wheel)
- `dist/wifi-priority-tui-<version>.tar.gz` (source)

### 3. Test on TestPyPI (Recommended)

```bash
# Upload to TestPyPI
python -m twine upload --repository testpypi dist/*

# Test installation
uv pip install --index-url https://test.pypi.org/simple/ wifi-priority-tui
```

### 4. Upload to PyPI

```bash
# Upload to production PyPI
python -m twine upload dist/*

# Enter your PyPI username and API token when prompted
# Username: __token__
# Password: pypi-...
```

### 5. Verify Installation

```bash
# Create fresh environment to test
uv venv test-env
source test-env/bin/activate

# Install from PyPI
uv pip install wifi-priority-tui

# Test the command
wifi-priority

# Clean up
deactivate
rm -rf test-env
```

## Automating with GitHub Actions (Optional)

Create `.github/workflows/publish.yml` to automatically publish on release:

```yaml
name: Publish to PyPI

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install build twine
      - name: Build package
        run: python -m build
      - name: Publish to PyPI
        env:
          TWINE_USERNAME: __token__
          TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
        run: python -m twine upload dist/*
```

Then add your PyPI API token as a GitHub secret named `PYPI_API_TOKEN`.

## Version Numbering

Follow semantic versioning:
- `0.1.0` → `0.1.1` - Bug fixes
- `0.1.0` → `0.2.0` - New features (backwards compatible)
- `0.1.0` → `1.0.0` - Breaking changes

## Checklist Before Publishing

- [ ] Version bumped in `pyproject.toml`
- [ ] README.md is up to date
- [ ] CHANGELOG or git history documents changes
- [ ] Tested locally with `uv pip install -e .`
- [ ] Code is committed and pushed to GitHub
- [ ] Git tag created: `git tag v0.1.0 && git push --tags`
- [ ] Clean build: `rm -rf dist/ build/`
- [ ] Build successful: `python -m build`
- [ ] Tested on TestPyPI (recommended for first release)
