/**
 * content.js — runs in ALL frames on ALL Salesforce domains.
 * Injects a "Truly Delete All" button next to the native "Delete All"
 * button on the Setup → Debug Logs page and deletes all Apex logs
 * via the Salesforce REST API through the background service worker.
 */

(function () {
    'use strict';

    const BUTTON_ID = 'sf-truly-delete-btn';

    // ── Styles ────────────────────────────────────────────────────
    function injectStyles() {
        if (document.getElementById('sf-cleaner-styles')) return;
        const s = document.createElement('style');
        s.id = 'sf-cleaner-styles';
        s.textContent = `
            #${BUTTON_ID} {
                background-color: #ba0517;
                color: #fff;
                border: 1px solid #8e030f;
                border-radius: 3px;
                padding: 3px 10px;
                font-size: 12px;
                font-weight: bold;
                cursor: pointer;
                margin-left: 6px;
                vertical-align: middle;
                font-family: Arial, sans-serif;
            }
            #${BUTTON_ID}:hover    { background-color: #8e030f; }
            #${BUTTON_ID}:disabled { background-color: #aaa; cursor: not-allowed; }

            #sf-toast {
                position: fixed; top: 16px; right: 16px; z-index: 99999;
                padding: 11px 18px; border-radius: 5px; min-width: 220px;
                font-size: 13px; font-weight: bold; font-family: Arial, sans-serif;
                box-shadow: 0 4px 14px rgba(0,0,0,0.3);
            }
            #sf-toast.success { background:#2e844a; color:#fff; }
            #sf-toast.error   { background:#ba0517; color:#fff; }
            #sf-toast.info    { background:#0070d2; color:#fff; }

            #sf-overlay {
                position: fixed; inset:0; background:rgba(0,0,0,0.45);
                z-index: 99998; display:flex; align-items:center; justify-content:center;
            }
            #sf-modal {
                background:#fff; border-radius:7px; width:340px;
                box-shadow:0 8px 28px rgba(0,0,0,0.28); overflow:hidden;
                font-family:Arial,sans-serif;
            }
            #sf-modal .mh { background:#ba0517;color:#fff;padding:13px 16px;font-size:14px;font-weight:bold; }
            #sf-modal .mb { padding:16px;font-size:13px;color:#333;line-height:1.6; }
            #sf-modal .mf { padding:10px 16px;display:flex;justify-content:flex-end;gap:8px;border-top:1px solid #e5e5e5; }
            #sf-modal button { padding:5px 15px;border-radius:4px;border:none;font-size:13px;font-weight:bold;cursor:pointer; }
            #sf-btn-cancel  { background:#f0f0f0;color:#333;border:1px solid #ccc!important; }
            #sf-btn-confirm { background:#ba0517;color:#fff; }
        `;
        document.head.appendChild(s);
    }

    // ── Toast ─────────────────────────────────────────────────────
    function toast(msg, type = 'success', ms = 4000) {
        document.getElementById('sf-toast')?.remove();
        const el = document.createElement('div');
        el.id = 'sf-toast'; el.className = type; el.textContent = msg;
        document.body.appendChild(el);
        setTimeout(() => el.remove(), ms);
    }

    // ── Confirm modal ─────────────────────────────────────────────
    function showConfirm(onYes) {
        const ov = document.createElement('div');
        ov.id = 'sf-overlay';
        ov.innerHTML = `
            <div id="sf-modal">
                <div class="mh">⚠️ Delete All Debug Logs?</div>
                <div class="mb">
                    Permanently delete <b>all Apex Debug Logs</b> in this org.<br>
                    <small style="color:#888">This cannot be undone.</small>
                </div>
                <div class="mf">
                    <button id="sf-btn-cancel">Cancel</button>
                    <button id="sf-btn-confirm">Yes, Delete All</button>
                </div>
            </div>`;
        document.body.appendChild(ov);
        document.getElementById('sf-btn-cancel').onclick  = () => ov.remove();
        document.getElementById('sf-btn-confirm').onclick = () => { ov.remove(); onYes(); };
        ov.onclick = e => { if (e.target === ov) ov.remove(); };
    }

    // ── Resolve the core Salesforce REST API base URL ─────────────
    // The button may be injected into various Salesforce shell domains.
    // REST API only works on *.my.salesforce.com (the core instance).
    //
    // Domain mapping:
    //   *.my.salesforce-setup.com  → *.my.salesforce.com  (Lightning setup shell)
    //   *.lightning.force.com      → *.my.salesforce.com  (Lightning Experience)
    //   *.visual.force.com         → *.my.salesforce.com  (VF pages)
    //   *.my.salesforce.com        → unchanged             (already correct)
    function getApiBase() {
        const { hostname, protocol } = window.location;

        // Extract the org subdomain prefix (e.g. "myorg" from "myorg.my.salesforce-setup.com")
        // All SF domains follow: <orgSlug>.my.<domain> or <orgSlug>.<domain>
        let corrected = hostname;

        if (hostname.endsWith('.salesforce-setup.com')) {
            // e.g. myorg.my.salesforce-setup.com → myorg.my.salesforce.com
            corrected = hostname.replace(/\.salesforce-setup\.com$/, '.salesforce.com');
        } else if (hostname.endsWith('.lightning.force.com')) {
            // e.g. myorg.lightning.force.com → myorg.my.salesforce.com
            corrected = hostname.replace(/\.lightning\.force\.com$/, '.my.salesforce.com');
        } else if (hostname.endsWith('.visual.force.com')) {
            // e.g. myorg.visual.force.com → myorg.my.salesforce.com
            corrected = hostname.replace(/\.visual\.force\.com$/, '.my.salesforce.com');
        }
        // *.my.salesforce.com is already correct — no change needed

        return `${protocol}//${corrected}`;
    }

    // ── Delete all ApexLogs — delegated to background service worker ──
    // Direct fetch from content script hits CORS when the page is on
    // salesforce-setup.com. The background worker has no CORS restrictions
    // and can read the session cookie to authenticate the REST API call.
    async function deleteAll(btn) {
        btn.disabled = true;
        btn.value    = 'Deleting…';

        const apiBase = getApiBase();

        try {
            const resp = await chrome.runtime.sendMessage({
                action:  'deleteApexLogs',
                apiBase
            });

            if (!resp || !resp.ok) {
                throw new Error(resp?.error || 'Unknown error from background');
            }

            if (resp.none) {
                toast('ℹ️ No debug logs to delete.', 'info');
            } else {
                const msg = resp.deleted === resp.total
                    ? `✅ ${resp.deleted} log(s) deleted!`
                    : `✅ ${resp.deleted} of ${resp.total} log(s) deleted.`;
                toast(msg, 'success');
                setTimeout(() => window.location.reload(), 1500);
            }

        } catch (e) {
            toast('❌ ' + e.message, 'error', 7000);
        } finally {
            btn.disabled = false;
            btn.value    = '🗑️ Truly Delete All';
        }
    }

    // ── Find "Delete All" buttons ─────────────────────────────────
    function findDeleteAllButtons() {
        // Primary: VF Visualforce id ending in "deleteAll"
        const byId = Array.from(document.querySelectorAll('input[id$="deleteAll"]'));
        if (byId.length) return byId;

        // Fallback: any input button with value "Delete All"
        return Array.from(document.querySelectorAll('input[type="button"],input[type="submit"]'))
            .filter(el => el.value?.trim() === 'Delete All');
    }

    // ── Inject button ─────────────────────────────────────────────
    function injectButton() {
        if (document.getElementById(BUTTON_ID)) return;

        const candidates = findDeleteAllButtons();
        if (!candidates.length) return; // not the right frame/page

        const target = candidates[0]; // first "Delete All" button

        const btn      = document.createElement('input');
        btn.type       = 'button';
        btn.id         = BUTTON_ID;
        btn.value      = '🗑️ Truly Delete All';
        btn.title      = 'Delete ALL Apex debug logs via REST API';
        btn.className  = target.className; // match native Salesforce button style
        btn.style.cssText = 'margin-left:6px;background:#ba0517;color:#fff;border-color:#8e030f;font-weight:bold;cursor:pointer;';
        btn.onclick    = () => showConfirm(() => deleteAll(btn));

        target.parentNode.insertBefore(btn, target.nextSibling);
    }

    // ── Retry loop + MutationObserver ─────────────────────────────
    function startWatching() {
        injectButton();

        new MutationObserver(() => {
            if (!document.getElementById(BUTTON_ID)) injectButton();
        }).observe(document.documentElement, { childList: true, subtree: true });

        let n = 0;
        const t = setInterval(() => {
            if (document.getElementById(BUTTON_ID) || ++n > 30) clearInterval(t);
            else injectButton();
        }, 1000);
    }

    // ── Init ──────────────────────────────────────────────────────
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => { injectStyles(); startWatching(); });
    } else {
        injectStyles();
        startWatching();
    }

})();
