# Contributing to PR Pulse

Thanks for helping improve PR Pulse.

## Local setup

1. Install Xcode or a Swift toolchain compatible with Swift 6.2, then select Xcode with `xcode-select`.
2. Clone the repository and change into it.
3. Run `swift test`.
4. Run `swift build -c release --product PRPulseApp`.

## Pull requests

- Keep each pull request focused on one user problem.
- Add or update XCTest coverage for behavior changes.
- Update the README or changelog when a user-visible behavior changes.
- Before requesting review, run `swift test` and include the result in the pull-request description.

## Reporting bugs and proposing features

Open a GitHub issue. Describe the workflow you were trying to complete, not only the implementation you expect.
