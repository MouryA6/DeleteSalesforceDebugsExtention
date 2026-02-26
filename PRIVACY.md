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
| `cookies` | Read the Salesforce session cookie (`sid`) by name to authenticate REST API calls to your own Salesforce org via the background service worker. `document.cookie` cannot be used as an alternative because the API call is made from the background service worker context, not from a page context. The cookie value is never stored, shared, or sent anywhere other than back to your own Salesforce org. |
| Host permissions (`*.salesforce.com`, `*.salesforce-setup.com`, `*.lightning.force.com`, `*.visual.force.com`) | Required to inject the button content script into Salesforce pages and to make authenticated REST API calls to the user's Salesforce org. Different orgs use different domain patterns and all are necessary. |

## Google API Limited Use

The use of information received from Google APIs will adhere to the Chrome Web Store User Data Policy, including the Limited Use requirements.

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/MouryA6/DeleteSalesforceDebugsExtention/issues
