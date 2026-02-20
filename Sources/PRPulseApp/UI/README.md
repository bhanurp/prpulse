# PR Pulse — User Guide

## Overview

PR Pulse is a macOS app designed to help you stay on top of GitHub pull requests that matter to you. Whether it's your own PRs, those where you have review requests, or PRs in repositories you watch, PR Pulse offers a clean, focused dashboard to track and manage them efficiently.

## Install & Launch

- Requires macOS 14 or later.
- Download from the repository and open the Xcode project.
- Build and run the app on your Mac.
- The app will launch and show the main dashboard.

## First-time Setup

1. **Configure Authentication**

   PR Pulse needs a GitHub Personal Access Token (PAT) for access to your PRs and repositories.

   - Create a PAT on GitHub with either the `repo` and `read:org` scopes for classic tokens or equivalent scopes for fine-grained tokens.
   - In the app, open the Settings screen.
   - Under the Account section, paste your token into the "GitHub Token" field.
   - Click "Save Token" to securely store it in your system Keychain.

2. **Add Watched Repositories**

   In Settings, add any repositories you want to track under the Watched tab. Use the format `owner/repo` (e.g., `apple/swift`).

## Using the App

PR Pulse organizes pull requests into three main tabs:

- **My PRs:** Lists pull requests you have authored.
- **Review Requested:** Shows PRs where you are requested as a reviewer.
- **Watched:** Displays open PRs in your watched repositories.

### Filtering and Search

- Use the search bar to filter PRs by title or repository name.
- Toggle filters to hide reviewed PRs, snoozed PRs, or PRs marked Not Applicable.
- Customize the view based on your workflow.

## Managing Settings

Settings allow you to tailor PR Pulse to your preferences:

- **Refresh on Launch:** Automatically refresh PR data when the app starts.
- **Refresh Interval:** Set how often PRs sync with GitHub (e.g., every 10 minutes).
- **Notifications:** Enable notifications for:
  - PRs needing re-review.
  - Review requests.
  - Digest summaries.
- **Snooze Defaults:** Configure the default time when snoozed PRs resume visibility.
- **Watched Repositories:** Add or remove repositories and enable notifications per repo.

## Actions on PRs

You can manage your PRs directly from the app with these actions:

- **Mark TODO:** Flag a PR for follow-up.
- **Mark Not Applicable:** Indicate a PR does not require your attention.
- **Clear Override:** Remove any manual status overrides.
- **Snooze:** Temporarily hide PRs until tomorrow or a specific date/time.

## Notifications

PR Pulse sends notifications to keep you informed:

- When a PR you reviewed now needs re-review.
- When you receive a new review request.
- Digest notifications summarizing activity, based on your configured cadence (Off, Weekly, Bi-Weekly).

## Digest

The digest provides a summary snapshot of your PR landscape over a selected time window. It highlights important changes and pending reviews to help you catch up efficiently.

## Debug Tools

If you encounter issues:

- Check the token validity and permissions.
- Use the logs in the app for detailed error information.
- Reset the token or clear app data via Settings.
- Confirm your repositories are correctly added to the Watched list.

## Troubleshooting

- **Token Not Accepted:** Ensure your GitHub token has the correct scopes and is correctly entered.
- **No PRs Showing:** Verify your token’s access and that the correct repositories and tabs are selected.
- **Ambiguous UI Behavior:** Restart the app or reset settings if UI elements behave unexpectedly.
- **Duplicate Keychain Entries:** Remove any duplicate token entries from your system Keychain.

## FAQ

- **Where is my token stored?**
  Your GitHub token is securely stored in the system Keychain with accessibility set to After First Unlock. It is never saved in plaintext on disk.

- **Can I track PRs from private repositories?**

  Yes, as long as your token has the necessary permissions to access those repositories.

- **How do I update or remove my token?**

  Use the Settings screen to update or clear your token. Updating replaces the stored token securely.

- **What refresh intervals are supported?**

  You can set the refresh interval in minutes. The app schedules automatic refreshes accordingly.

- **Can I customize notifications per watched repository?**

  Yes, you can enable or disable notifications for each watched repository individually in Settings.

---

Thank you for using PR Pulse! For more information or to report issues, please visit the project repository or contact support.

