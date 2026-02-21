// background.js — service worker
// Listens for tab updates and sets the extension badge
// to indicate when the user is on the Debug Logs Setup page.
//
// Also handles 'deleteApexLogs' messages from content.js.
// Fetches are made here (service worker) to bypass CORS restrictions
// that block cross-origin credentialed requests from content scripts.

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status === 'complete' && tab.url) {
        const isDebugLogPage = /ApexDebugLog/i.test(tab.url);

        if (isDebugLogPage) {
            chrome.action.setBadgeText({ text: 'ON', tabId });
            chrome.action.setBadgeBackgroundColor({ color: '#2e844a', tabId });
        } else {
            chrome.action.setBadgeText({ text: '', tabId });
        }
    }
});

// ── Message handler: deleteApexLogs ──────────────────────────────────────────
// content.js sends: { action: 'deleteApexLogs', apiBase: 'https://org.my.salesforce.com' }
// We fetch the session cookie for that domain, then hit the REST API.
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg.action !== 'deleteApexLogs') return false;

    deleteApexLogs(msg.apiBase)
        .then(result => sendResponse({ ok: true, ...result }))
        .catch(err  => sendResponse({ ok: false, error: err.message }));

    return true; // keep channel open for async response
});

// ── Resolve session token from cookies ───────────────────────────────────────
// Salesforce uses "sid" as the session cookie on most orgs.
// Some SSO setups may use a different name — we try common ones.
async function getSessionToken(apiBase) {
    const allCookies = await chrome.cookies.getAll({ url: apiBase });

    // Try known Salesforce session cookie names in priority order
    const names = ['sid', 'salesforce_sid', 'oid'];
    for (const name of names) {
        const c = allCookies.find(x => x.name === name);
        if (c) return c.value;
    }

    // Last resort: pick any httpOnly cookie (likely to be the session)
    const httpOnly = allCookies.find(c => c.httpOnly);
    if (httpOnly) return httpOnly.value;

    throw new Error(
        `No session cookie found for ${apiBase}. ` +
        `Make sure you are logged into Salesforce in this browser.`
    );
}

// ── Auto-detect latest available REST API version ────────────────────────────
async function resolveApiVersion(apiBase, headers) {
    try {
        const r = await fetch(`${apiBase}/services/data/`, { headers });
        if (!r.ok) return 'v59.0'; // safe minimum fallback
        const versions = await r.json(); // [{version:"62.0",...}, ...]
        if (!Array.isArray(versions) || !versions.length) return 'v59.0';
        const latest = versions[versions.length - 1].version;
        return `v${latest}`;
    } catch {
        return 'v59.0';
    }
}

// ── Collect ALL ApexLog IDs via paginated SOQL ───────────────────────────────
// Salesforce caps a single query at 2,000 records.
// nextRecordsUrl handles pagination for orgs with >2,000 logs.
async function collectAllLogIds(apiBase, ver, headers) {
    const ids = [];
    let url = `${apiBase}/services/data/${ver}/query?q=${encodeURIComponent('SELECT Id FROM ApexLog')}`;

    while (url) {
        const r = await fetch(url, { headers });
        if (!r.ok) {
            const body = await r.text();
            throw new Error(`[${r.status}] ${body}`);
        }
        const data = await r.json();
        for (const rec of (data.records || [])) ids.push(rec.Id);

        // If there are more pages, nextRecordsUrl is a relative path
        url = data.nextRecordsUrl
            ? `${apiBase}${data.nextRecordsUrl}`
            : null;
    }
    return ids;
}

// ── Batch-delete up to 200 IDs per request ───────────────────────────────────
// REST composite endpoint: DELETE /services/data/vXX/composite/sobjects?ids=...
// Much faster than one-by-one — 200 deletions per HTTP round-trip.
async function batchDelete(apiBase, ver, headers, ids) {
    const BATCH = 200;
    let deleted = 0;

    for (let i = 0; i < ids.length; i += BATCH) {
        const chunk = ids.slice(i, i + BATCH);
        const r = await fetch(
            `${apiBase}/services/data/${ver}/composite/sobjects?ids=${chunk.join(',')}&allOrNone=false`,
            { method: 'DELETE', headers }
        );
        // Response is an array of {id, success, errors}
        if (r.status === 200) {
            const results = await r.json();
            deleted += results.filter(x => x.success).length;
        }
    }
    return deleted;
}

// ── Main orchestrator ─────────────────────────────────────────────────────────
async function deleteApexLogs(apiBase) {
    const token = await getSessionToken(apiBase);
    const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type':  'application/json'
    };

    const ver  = await resolveApiVersion(apiBase, headers);
    const ids  = await collectAllLogIds(apiBase, ver, headers);

    if (!ids.length) return { deleted: 0, none: true };

    const deleted = await batchDelete(apiBase, ver, headers, ids);
    return { deleted, total: ids.length };
}
