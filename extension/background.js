/* Clicking the toolbar icon opens powertoy in a full tab.
   The app is a bundled extension page, so it loads instantly and works offline. */
chrome.action.onClicked.addListener(() => {
  chrome.tabs.create({ url: chrome.runtime.getURL('index.html') });
});
