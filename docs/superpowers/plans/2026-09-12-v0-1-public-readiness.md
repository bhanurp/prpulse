# PR Pulse v0.1.0 Public Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PR Pulse publicly installable, verifiable, and trustworthy as a stable v0.1.0 open-source macOS release.

**Architecture:** Keep the SwiftUI application unchanged for this release. Add an independent macOS test workflow, repair the documented release installer path, and provide the project-policy and community files that establish a clear support contract. The release workflow continues to build the DMG and ZIP from semantic tags; a stable tag turns those assets into GitHub’s actual latest release.

**Tech Stack:** Swift Package Manager 6.2, XCTest, GitHub Actions on macOS 15, GitHub Releases, Bash, Markdown.

---

## File structure

- Create: `.github/workflows/test.yml` — runs the Swift test suite on supported macOS/Xcode CI for every pull request and `master` push.
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml` — collects reproducible defect reports.
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml` — collects user problems and measurable success criteria.
- Create: `LICENSE` — MIT license with the repository owner as copyright holder.
- Create: `SECURITY.md` — private security-reporting path and supported-version policy.
- Create: `CONTRIBUTING.md` — local setup, branch/PR expectations, and verification commands.
- Create: `CHANGELOG.md` — release history beginning with v0.1.0.
- Modify: `README.md:32-69` — use the correct branch in the installer command, explain stable-release requirements and the current ad-hoc-signing limitation, and add contribution/security links.
- Modify: `.github/workflows/publish-binary.yml:20-135` — run tests before packaging and publish a stable release only from `v*` tags.

### Task 1: Add a macOS test workflow

**Files:**
- Create: `.github/workflows/test.yml`
- Test: GitHub Actions run for a pull request or `master` push

- [ ] **Step 1: Create the workflow file**

```yaml
name: Test macOS App

on:
  pull_request:
  push:
    branches:
      - master

permissions:
  contents: read

jobs:
  test:
    name: Swift tests
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Run test suite
        run: swift test
```

- [ ] **Step 2: Validate the workflow YAML locally**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/test.yml")'`

Expected: command exits with status 0 and prints no output.

- [ ] **Step 3: Push the branch and inspect the GitHub Actions run**

Run: `gh run list --workflow 'Test macOS App' --limit 1`

Expected: the newest run is `completed` with conclusion `success` and contains a successful `Run test suite` step.

- [ ] **Step 4: Commit the workflow**

```bash
git add .github/workflows/test.yml
git commit -m "ci: run Swift tests on macOS"
```

### Task 2: Make release builds test before packaging

**Files:**
- Modify: `.github/workflows/publish-binary.yml:20-28`
- Test: `swift test` on a macOS runner before `Build app bundle`

- [ ] **Step 1: Insert the test step after the existing Xcode selection step**

```yaml
      - name: Run test suite
        run: swift test

      - name: Build app bundle
```

The resulting section must appear exactly after the `Select Xcode` step and before the existing `Build app bundle` step.

- [ ] **Step 2: Validate the release workflow YAML locally**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/publish-binary.yml")'`

Expected: command exits with status 0 and prints no output.

- [ ] **Step 3: Validate that the existing tag-release guard is unchanged**

Run: `rg -n 'if: startsWith\(github\.ref, .refs/tags/.\)' .github/workflows/publish-binary.yml`

Expected: one matching line, proving manual workflow dispatch cannot masquerade as a stable release.

- [ ] **Step 4: Commit the release gate**

```bash
git add .github/workflows/publish-binary.yml
git commit -m "ci: test before packaging releases"
```

### Task 3: Add open-source and support policy files

**Files:**
- Create: `LICENSE`
- Create: `SECURITY.md`
- Create: `CONTRIBUTING.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Add the MIT license**

Create `LICENSE` with this complete text:

```text
MIT License

Copyright (c) 2026 bhanu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Add the security policy**

Create `SECURITY.md` with this complete text:

```markdown
# Security Policy

## Supported versions

Only the latest stable GitHub Release is supported with security fixes.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability, especially one involving GitHub tokens or Keychain storage. Email bhanuputtareddy@gmail.com with a description, reproduction steps, impact, and any proof of concept. You will receive an acknowledgement within 72 hours and a status update after the issue is assessed.
```

- [ ] **Step 3: Add the contribution guide**

Create `CONTRIBUTING.md` with this complete text:

```markdown
# Contributing to PR Pulse

Thanks for helping improve PR Pulse.

## Local setup

1. Install Xcode 15 or newer and select it with `xcode-select`.
2. Clone the repository and change into it.
3. Run `swift test`.
4. Run `swift build -c release --product PRPulseApp`.

## Pull requests

- Keep each pull request focused on one user problem.
- Add or update XCTest coverage for behavior changes.
- Update the README or changelog when a user-visible behavior changes.
- Before requesting review, run `swift test` and include the result in the pull-request description.

## Reporting bugs and proposing features

Use the repository issue forms. Describe the workflow you were trying to complete, not only the implementation you expect.
```

- [ ] **Step 4: Add the initial changelog**

Create `CHANGELOG.md` with this complete text:

```markdown
# Changelog

All notable changes to PR Pulse are documented in this file.

## [0.1.0] - 2026-09-12

### Added

- Native macOS menu-bar dashboard for authored PRs, review requests, and watched repositories.
- Local triage actions, snooze reminders, notifications, digest snapshots, and Keychain-backed GitHub token storage.
- Stable DMG and ZIP release artifacts for macOS 13 and newer.

### Known limitations

- PR Pulse supports GitHub and macOS only.
- The app is ad-hoc signed until Developer ID signing and notarization are available.
```

- [ ] **Step 5: Check all public-policy files**

Run: `rg -n 'Copyright \(c\) 2026 bhanu|Reporting a vulnerability|swift test|\[0\.1\.0\]' LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md`

Expected: one or more meaningful matches in every listed file.

- [ ] **Step 6: Commit the policy files**

```bash
git add LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md
git commit -m "docs: add project policies"
```

### Task 4: Add structured public issue forms

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Test: YAML parsing of both forms

- [ ] **Step 1: Add the bug-report form**

```yaml
name: Bug report
description: Report a reproducible problem in PR Pulse
title: "[Bug]: "
labels:
  - bug
body:
  - type: markdown
    attributes:
      value: "Please remove all GitHub tokens and private repository names before submitting."
  - type: input
    id: version
    attributes:
      label: PR Pulse version
      placeholder: "0.1.0"
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
      placeholder: "1. Open PR Pulse\n2. ..."
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: Actual behavior
    validations:
      required: true
  - type: input
    id: macos
    attributes:
      label: macOS version
      placeholder: "macOS 15.0"
    validations:
      required: true
```

- [ ] **Step 2: Add the feature-request form**

```yaml
name: Feature request
description: Propose a workflow improvement for PR Pulse
title: "[Feature]: "
labels:
  - feature
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem to solve
      description: "Describe the repeated PR workflow that is currently difficult."
    validations:
      required: true
  - type: textarea
    id: outcome
    attributes:
      label: Desired outcome
      description: "Describe what a successful experience would let you do."
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives considered
      description: "Describe any current workaround or similar tool."
    validations:
      required: true
```

- [ ] **Step 3: Validate the issue-form YAML files**

Run: `ruby -e 'require "yaml"; Dir[".github/ISSUE_TEMPLATE/*.yml"].each { |path| YAML.load_file(path); puts path }'`

Expected: both issue-form paths print and the command exits with status 0.

- [ ] **Step 4: Commit the issue forms**

```bash
git add .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/feature_request.yml
git commit -m "chore: add issue forms"
```

### Task 5: Repair and clarify public release documentation

**Files:**
- Modify: `README.md:32-69`
- Modify: `README.md:341-349`
- Test: public installer script URL returns HTTP 200 after push; GitHub latest-release API returns HTTP 200 after v0.1.0 publishing

- [ ] **Step 1: Replace the README installer command with the default-branch URL**

Replace the existing command block with:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bhanurp/prpulse/master/scripts/install_latest_release.sh)" -- bhanurp/prpulse
```

- [ ] **Step 2: Add a stable-release and signing note directly after the command**

```markdown
This command requires a stable GitHub Release. Pre-releases are intentionally excluded so it always installs the latest tested public version.

PR Pulse is currently ad-hoc signed, not notarized. If macOS blocks the first launch, follow the Gatekeeper command below. Do not bypass Gatekeeper for builds downloaded from any source other than this repository’s Releases page.
```

- [ ] **Step 3: Replace the source-build placeholder and add community links**

Replace `git clone <your-repo-url>` with:

```bash
git clone https://github.com/bhanurp/prpulse.git
```

Append this section at the end of `README.md`:

```markdown
## Community and support

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
- Report reproducible defects and feature requests through [Issues](https://github.com/bhanurp/prpulse/issues).
- Read [SECURITY.md](SECURITY.md) for private vulnerability reporting.
- See [CHANGELOG.md](CHANGELOG.md) for release history and known limitations.
```

- [ ] **Step 4: Verify the documentation references**

Run: `rg -n 'raw\.githubusercontent\.com/bhanurp/prpulse/master|stable GitHub Release|https://github\.com/bhanurp/prpulse\.git|CONTRIBUTING\.md|SECURITY\.md' README.md`

Expected: five or more matches, including the corrected raw installer URL.

- [ ] **Step 5: Commit the documentation update**

```bash
git add README.md
git commit -m "docs: fix release installation instructions"
```

### Task 6: Publish and verify the stable v0.1.0 release

**Files:**
- No repository file changes; this task creates the externally visible Git tag and GitHub Release only after Tasks 1–5 are merged to `master`.
- Test: generated release assets and documented installer command

- [ ] **Step 1: Run the local verification set in an Xcode-enabled environment**

Run: `swift test && swift build -c release --product PRPulseApp`

Expected: both commands exit with status 0. The test command must run with full Xcode selected rather than Command Line Tools because XCTest is unavailable in the current local CLT setup.

- [ ] **Step 2: Push the completed v0.1.0 work to the public default branch**

Run: `git push origin master`

Expected: the `Test macOS App` workflow completes successfully for the push.

- [ ] **Step 3: Create and push the stable version tag**

Run: `git tag -a v0.1.0 -m 'PR Pulse v0.1.0' && git push origin v0.1.0`

Expected: the `Build and Publish macOS App` workflow runs and publishes a non-prerelease GitHub Release.

- [ ] **Step 4: Verify stable release metadata and assets**

Run: `gh release view v0.1.0 --repo bhanurp/prpulse --json isPrerelease,isLatest,assets --jq '{isPrerelease, isLatest, assets: [.assets[].name]}'`

Expected: `isPrerelease` is `false`, `isLatest` is `true`, and assets include `PRPulseApp.dmg` and `PRPulseApp.zip`.

- [ ] **Step 5: Verify the installer’s two remote dependencies**

Run: `curl -fsS -o /dev/null -w '%{http_code}\n' https://raw.githubusercontent.com/bhanurp/prpulse/master/scripts/install_latest_release.sh && curl -fsS -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/bhanurp/prpulse/releases/latest`

Expected: two lines, each containing `200`.

- [ ] **Step 6: Perform a clean-machine installation test**

Run on a macOS test account: `bash -c "$(curl -fsSL https://raw.githubusercontent.com/bhanurp/prpulse/master/scripts/install_latest_release.sh)" -- bhanurp/prpulse`

Expected: the script downloads `PRPulseApp.dmg`, installs `PRPulseApp.app` into `/Applications` or `$HOME/Applications`, opens the app, and leaves the GitHub token setup screen available.

- [ ] **Step 7: Commit no additional files for the release tag**

The tag is the release record. Confirm the working tree is clean with `git status --short`.

## Plan self-review

Spec coverage: Tasks 1–6 implement every v0.1.0 requirement from the approved roadmap: a stable install path, CI test gate, project-policy files, issue intake, security posture, clear onboarding documentation, and a clean installation verification. v0.2.0 saved views and later product work are intentionally excluded because they are independent release scopes.

Type consistency: no Swift API changes are made in this plan. Workflow names, repository owner, default branch, product name, and release asset names match the current repository.

Verification: every file change has a syntax or content validation command, and the final release has remote-metadata and clean-install checks.
