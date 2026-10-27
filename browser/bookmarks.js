class BalanceBookmark {

    id = ""
    name = ""
    url = ""

    constructor(id, name, url) {
        this.id = id;
        this.name = name;
        this.url = url;
    }

    raw() {
        return {
            id: this.id,
            name: this.name,
            url: this.url,
        };
    }
}

const balance = {
    bookmarks: {

        async get() {
            try {

                const response = await window.webkit.messageHandlers.bookmarks.postMessage({ action: 'get' });

                if (response.error) {
                    console.error('Error getting bookmarks:', response.error);
                    return [];
                }

                return response.bookmarks.map(bookmarkData => new BalanceBookmark(
                    bookmarkData.id,
                    bookmarkData.name,
                    bookmarkData.url,
                ));
            } catch (error) {
                console.error('IPC Bridge Error:', error);
                return [];
            }
        },

        async open(id) {
            try {
                const response = await window.webkit.messageHandlers.bookmarks.postMessage({ action: 'open', id: id });

                if (response.error) {
                    console.error('Error opening bookmark:', response.error);
                    return false;
                }

                return response.success;
            } catch (error) {
                console.error('IPC Bridge Error:', error);
                return false;
            }
        }
    }
};

window.balance = balance;
