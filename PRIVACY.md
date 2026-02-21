# Privacy Policy — Salesforce Debug Log Cleaner

**Last updated: February 21, 2026**

## Overview

Salesforce Debug Log Cleaner is a Chrome extension that adds a "Truly Delete All" button to the Salesforce Setup → Debug Logs page, allowing users to delete all Apex debug logs from their Salesforce org via the Salesforce REST API.

## Data Collection

This extension **does not collect, store, transmit, or share any personal data** with the extension developer or any third party.

## Data Access

To authenticate with the Salesforce REST API, the extension reads your browser's session cookie (`sid`) for your Salesforce org domain (e.g. `https://yourorg.my.salesforce.com`). This cookie value is:

- Used **only** to make authenticated API requests back to your own Salesforce org
- **Never** sent to any server other than your own Salesforce org
- **Never** stored, logged, or retained by the extension

## Permissions Explained

| Permission | Why it's needed |
|-----------|----------------|
| `activeTab` | Detect if the current tab is the Salesforce Debug Logs page (to show the badge) |
| `scripting` | Inject the "Truly Delete All" button into the Debug Logs page |
| `cookies` | Read the Salesforce session cookie to authenticate REST API calls to your org |
| Host permissions (`*.salesforce.com`, etc.) | Required to run the content script on Salesforce pages |

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/MouryA6/DeleteSalesforceDebugsExtention/issues
