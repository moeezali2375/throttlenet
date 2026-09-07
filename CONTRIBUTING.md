# Contributing to ThrottleNet

First off, thank you for considering contributing to ThrottleNet! 🎉 Projects like this thrive because of people like you.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Running Tests](#running-tests)
5. [Building the Release App Bundle](#building-the-release-app-bundle)
6. [Submitting Pull Requests](#submitting-pull-requests)
7. [Reporting Bugs & Requesting Features](#reporting-bugs--requesting-features)

---

## Code of Conduct
By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please treat everyone with respect and empathy.

---

## Getting Started

ThrottleNet is built with **Swift** and **SwiftUI** for macOS. It interfaces directly with macOS network diagnostic tools (`nettop`, `lsof`) and packet filtering utilities (`dnctl`, `pfctl`).

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0+ or Swift 5.9+ command-line tools installed (`xcode-select --install`)
- Administrator privileges on your Mac (required for applying network shaping rules with `dnctl` and `pfctl`)

---

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/moeezali2375/throttlenet.git
   cd throttlenet
   ```

2. **Build the project**:
   ```bash
   swift build
   ```

3. **Run in development mode**:
   ```bash
   swift run ThrottleNet
   # or
   ./Scripts/run.sh
   ```

---

## Running Tests

ThrottleNet includes an automated test runner that verifies unit models, speed formatting, socket inspection, rule matching, and live `nettop` sampling:

```bash
swift run ThrottleNetTestsRunner
```

Ensure all tests pass before submitting your pull request.

---

## Building the Release App Bundle

To package a standalone `ThrottleNet.app` with icons and metadata:

```bash
./Scripts/build_app.sh
```

The compiled application will be generated in `build/ThrottleNet.app`.

To build and package a distribution `.zip` for releases:
```bash
./Scripts/package_release.sh 1.0.0
```

---

## Submitting Pull Requests

1. **Fork the repo** and create your branch from `main`:
   ```bash
   git checkout -b feature/my-cool-feature
   ```
2. **Follow Swift conventions**:
   - Write clear, idiomatic Swift code.
   - Maintain SwiftUI architecture and separation of concerns (Models, Services, ViewModels, Views).
   - Keep comments and docstrings up to date.
3. **Commit Messages**:
   We encourage [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat: add new feature`
   - `fix: resolve a bug`
   - `perf: optimize polling or memory usage`
   - `docs: update documentation`
   - `refactor: clean up code structure`
4. **Push your branch and open a Pull Request**:
   - Describe your changes clearly in the PR description.
   - Reference any related issues (e.g. `Closes #12`).

---

## Reporting Bugs & Requesting Features

- **Bug Reports**: Please open an issue using the Bug Report template. Include your macOS version, target process name/PID, and terminal output if applicable.
- **Feature Requests**: We welcome ideas! Feel free to start a discussion or open a Feature Request issue.
