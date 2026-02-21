// popup.js — checks the active tab and updates the status indicator

chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab        = tabs[0];
    const url        = tab?.url || '';
    const dot        = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');

    const isDebugLogPage = /ApexDebugLog/i.test(url);

    if (isDebugLogPage) {
        dot.classList.add('on-page');
        statusText.textContent = '✅ Active on this page';
    } else {
        dot.classList.add('off-page');
        statusText.textContent = 'Not on Debug Logs page';
    }
});
