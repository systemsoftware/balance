# Bookmark API for custom homepages (v1.7.0+)

Balance can expose the current profile's bookmarks to a third-party webpage configured as the browser homepage. The API is available as `window.balance.bookmarks` in the page's main frame.

## Enable access

1. In Balance settings, set **Homepage** to a full `https://` URL for the page that will use the API. The API is unavailable on HTTP homepages.
2. Turn on **Expose Bookmarks to Homepage**. This setting is off by default. If you change the homepage later, Balance turns the permission off; review the new URL before enabling it again.
3. Open the homepage in a new tab after enabling the setting. The API script is installed when the web view is created, so an already-open tab may need to be reopened.

If you enabled bookmark exposure in an older version of Balance, turn it off and on once to approve the current homepage URL.

There is no separate prompt for each API call. Balance checks the setting and the calling page's origin on every request. The page must be the main frame of a non-private tab and have the same scheme, hostname, and port as the configured homepage. A different subdomain, protocol, or port cannot read or open bookmarks, and embedded frames cannot use the API. If access is turned off while a page is open, later requests are denied even if `window.balance` is still present in that page.

Grant this permission only to a homepage you trust: `get()` gives that origin the names and URLs of all bookmarks in the active profile, including local file paths in file bookmarks. Any script running on that origin, including third-party scripts included by the page, can call the API. The API does not provide methods to create, edit, or delete bookmarks.

## Use the API

Check for the API before calling it, since it is absent when permission is off or the page is outside the allowed origin:

```js
(async () => {
  if (!window.balance?.bookmarks) {
    console.log('Balance bookmarks are unavailable on this page');
    return;
  }

  const bookmarks = await window.balance.bookmarks.get();
  for (const bookmark of bookmarks) {
    console.log(bookmark.id, bookmark.name, bookmark.url);
  }
})();
```

### `await balance.bookmarks.get()`

Returns an array of bookmark objects from the active Balance profile. Each object has:

| Property | Meaning |
| --- | --- |
| `id` | Bookmark UUID as a string. Pass this to `open()`. |
| `name` | Bookmark title. |
| `url` | Saved URL string. |

Each object also has a `raw()` method that returns a plain object with these properties. On a bridge error or denied request, `get()` logs the error and returns `[]`, so an empty array does not necessarily mean there are no bookmarks.

### `await balance.bookmarks.open(id)`

Opens the bookmark with the given UUID in the current tab and returns `true` when Balance accepts the request. It returns `false` and logs an error if access is denied, the ID is missing, or the saved URL is invalid. Balance accepts saved `http`, `https`, and `file` URLs. A successful call starts navigation, so the current page may unload shortly afterward.

```js
document.querySelector('#open-first-bookmark').addEventListener('click', async () => {
  if (!window.balance?.bookmarks) return;
  const bookmarks = await window.balance.bookmarks.get();
  const first = bookmarks[0];

  if (first) {
    await window.balance.bookmarks.open(first.id);
  }
});
```

## Native reply format

The page wrapper uses a WebKit message handler. Pages should normally use `window.balance.bookmarks`, but the underlying replies are:

| Request body | Successful reply | Error reply |
| --- | --- | --- |
| `{ action: 'get' }` | `{ bookmarks: [{ id, name, url }, ...] }` | `{ error: '...' }` |
| `{ action: 'open', id: 'bookmark-uuid' }` | `{ success: true }` | `{ error: '...' }` |
