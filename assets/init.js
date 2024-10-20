/*
Venera JavaScript Library

This library provides a set of APIs for interacting with the Venera app.
*/

/// encode, decode, hash, decrypt
let Convert = {
    /**
     * @param str {string}
     * @returns {ArrayBuffer}
     */
    encodeUtf8: (str) => {
        return sendMessage({
            method: "convert",
            type: "utf8",
            value: str,
            isEncode: true
        });
    },

    /**
     * @param value {ArrayBuffer}
     * @returns {string}
     */
    decodeUtf8: (value) => {
        return sendMessage({
            method: "convert",
            type: "utf8",
            value: value,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {string}
     */
    encodeBase64: (value) => {
        return sendMessage({
            method: "convert",
            type: "base64",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {string} value
     * @returns {ArrayBuffer}
     */
    decodeBase64: (value) => {
        return sendMessage({
            method: "convert",
            type: "base64",
            value: value,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    md5: (value) => {
        return sendMessage({
            method: "convert",
            type: "md5",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha1: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha1",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha256: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha256",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @returns {ArrayBuffer}
     */
    sha512: (value) => {
        return sendMessage({
            method: "convert",
            type: "sha512",
            value: value,
            isEncode: true
        });
    },

    /**
     * @param key {ArrayBuffer}
     * @param value {ArrayBuffer}
     * @param hash {string} - md5, sha1, sha256, sha512
     * @returns {ArrayBuffer}
     */
    hmac: (key, value, hash) => {
        return sendMessage({
            method: "convert",
            type: "hmac",
            value: value,
            key: key,
            hash: hash,
            isEncode: true
        });
    },

    /**
     * @param key {ArrayBuffer}
     * @param value {ArrayBuffer}
     * @param hash {string} - md5, sha1, sha256, sha512
     * @returns {string} - hex string
     */
    hmacString: (key, value, hash) => {
        return sendMessage({
            method: "convert",
            type: "hmac",
            value: value,
            key: key,
            hash: hash,
            isEncode: true,
            isString: true
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @returns {ArrayBuffer}
     */
    decryptAesEcb: (value, key) => {
        return sendMessage({
            method: "convert",
            type: "aes-ecb",
            value: value,
            key: key,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {ArrayBuffer} iv
     * @returns {ArrayBuffer}
     */
    decryptAesCbc: (value, key, iv) => {
        return sendMessage({
            method: "convert",
            type: "aes-ecb",
            value: value,
            key: key,
            iv: iv,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    decryptAesCfb: (value, key, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-cfb",
            value: value,
            key: key,
            blockSize: blockSize,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @param {number} blockSize
     * @returns {ArrayBuffer}
     */
    decryptAesOfb: (value, key, blockSize) => {
        return sendMessage({
            method: "convert",
            type: "aes-ofb",
            value: value,
            key: key,
            blockSize: blockSize,
            isEncode: false
        });
    },

    /**
     * @param {ArrayBuffer} value
     * @param {ArrayBuffer} key
     * @returns {ArrayBuffer}
     */
    decryptRsa: (value, key) => {
        return sendMessage({
            method: "convert",
            type: "rsa",
            value: value,
            key: key,
            isEncode: false
        });
    }
}

/**
 * create a time-based uuid
 *
 * Note: the engine will generate a new uuid every time it is called
 *
 * To get the same uuid, please save it to the local storage
 *
 * @returns {string}
 */
function createUuid() {
    return sendMessage({
        method: "uuid"
    });
}

/**
 * Generate a random integer between min and max
 * @param min {number}
 * @param max {number}
 * @returns {number}
 */
function randomInt(min, max) {
    return sendMessage({
        method: 'random',
        type: 'int',
        min: min,
        max: max
    });
}

/**
 * Generate a random double between min and max
 * @param min {number}
 * @param max {number}
 * @returns {number}
 */
function randomDouble(min, max) {
    return sendMessage({
        method: 'random',
        type: 'double',
        min: min,
        max: max
    });
}

class _Timer {
    delay = 0;

    callback = () => { };

    status = false;

    constructor(delay, callback) {
        this.delay = delay;
        this.callback = callback;
    }

    run() {
        this.status = true;
        this._interval();
    }

    _interval() {
        if (!this.status) {
            return;
        }
        this.callback();
        setTimeout(this._interval.bind(this), this.delay);
    }

    cancel() {
        this.status = false;
    }
}

function setInterval(callback, delay) {
    let timer = new _Timer(delay, callback);
    timer.run();
    return timer;
}

function Cookie(name, value, domain = null) {
    let obj = {};
    obj.name = name;
    obj.value = value;
    if (domain) {
        obj.domain = domain;
    }
    return obj;
}

/**
 * Network object for sending HTTP requests and managing cookies.
 * @namespace Network
 */
let Network = {
    /**
     * Sends an HTTP request.
     * @param {string} method - The HTTP method (e.g., GET, POST, PUT, PATCH, DELETE).
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<{status: number, headers: {}, body: ArrayBuffer}>} The response from the request.
     */
    async fetchBytes(method, url, headers, data) {
        let result = await sendMessage({
            method: 'http',
            http_method: method,
            bytes: true,
            url: url,
            headers: headers,
            data: data,
        });

        if (result.error) {
            throw result.error;
        }

        return result;
    },

    /**
     * Sends an HTTP request.
     * @param {string} method - The HTTP method (e.g., GET, POST, PUT, PATCH, DELETE).
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async sendRequest(method, url, headers, data) {
        let result = await sendMessage({
            method: 'http',
            http_method: method,
            url: url,
            headers: headers,
            data: data,
        });

        if (result.error) {
            throw result.error;
        }

        return result;
    },

    /**
     * Sends an HTTP GET request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async get(url, headers) {
        return this.sendRequest('GET', url, headers);
    },

    /**
     * Sends an HTTP POST request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async post(url, headers, data) {
        return this.sendRequest('POST', url, headers, data);
    },

    /**
     * Sends an HTTP PUT request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async put(url, headers, data) {
        return this.sendRequest('PUT', url, headers, data);
    },

    /**
     * Sends an HTTP PATCH request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async patch(url, headers, data) {
        return this.sendRequest('PATCH', url, headers, data);
    },

    /**
     * Sends an HTTP DELETE request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @returns {Promise<{status: number, headers: {}, body: string}>} The response from the request.
     */
    async delete(url, headers) {
        return this.sendRequest('DELETE', url, headers);
    },

    /**
     * Sets cookies for a specific URL.
     * @param {string} url - The URL to set the cookies for.
     * @param {Cookie[]} cookies - The cookies to set.
     */
    setCookies(url, cookies) {
        sendMessage({
            method: 'cookie',
            function: 'set',
            url: url,
            cookies: cookies,
        });
    },

    /**
     * Retrieves cookies for a specific URL.
     * @param {string} url - The URL to get the cookies from.
     * @returns {Promise<Cookie[]>} The cookies for the given URL.
     */
    getCookies(url) {
        return sendMessage({
            method: 'cookie',
            function: 'get',
            url: url,
        });
    },

    /**
     * Deletes cookies for a specific URL.
     * @param {string} url - The URL to delete the cookies from.
     */
    deleteCookies(url) {
        sendMessage({
            method: 'cookie',
            function: 'delete',
            url: url,
        });
    },
};

/**
 * HtmlDocument class for parsing HTML and querying elements.
 */
class HtmlDocument {
    static _key = 0;

    key = 0;

    /**
     * Constructor for HtmlDocument.
     * @param {string} html - The HTML string to parse.
     */
    constructor(html) {
        this.key = HtmlDocument._key;
        HtmlDocument._key++;
        sendMessage({
            method: "html",
            function: "parse",
            key: this.key,
            data: html
        })
    }

    /**
     * Query a single element from the HTML document.
     * @param {string} query - The query string.
     * @returns {HtmlElement} The first matching element.
     */
    querySelector(query) {
        let k = sendMessage({
            method: "html",
            function: "querySelector",
            key: this.key,
            query: query
        })
        if(k == null) return null;
        return new HtmlElement(k, this.key);
    }

    /**
     * Query all matching elements from the HTML document.
     * @param {string} query - The query string.
     * @returns {HtmlElement[]} An array of matching elements.
     */
    querySelectorAll(query) {
        let ks = sendMessage({
            method: "html",
            function: "querySelectorAll",
            key: this.key,
            query: query
        })
        return ks.map(k => new HtmlElement(k, this.key));
    }

    /**
     * Dispose the HTML document.
     * This should be called when the document is no longer needed.
     */
    dispose() {
        sendMessage({
            method: "html",
            function: "dispose",
            key: this.key
        })
    }
}

/**
 * HtmlDom class for interacting with HTML elements.
 */
class HtmlElement {
    key = 0;

    doc = 0;

    /**
     * Constructor for HtmlDom.
     * @param {number} k - The key of the element.
     * @param {number} doc - The key of the document.
     */
    constructor(k, doc) {
        this.key = k;
        this.doc = doc;
    }

    /**
     * Get the text content of the element.
     * @returns {string} The text content.
     */
    get text() {
        return sendMessage({
            method: "html",
            function: "getText",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get the attributes of the element.
     * @returns {Object} The attributes.
     */
    get attributes() {
        return sendMessage({
            method: "html",
            function: "getAttributes",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Query a single element from the current element.
     * @param {string} query - The query string.
     * @returns {HtmlElement} The first matching element.
     */
    querySelector(query) {
        let k = sendMessage({
            method: "html",
            function: "dom_querySelector",
            key: this.key,
            query: query,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }

    /**
     * Query all matching elements from the current element.
     * @param {string} query - The query string.
     * @returns {HtmlElement[]} An array of matching elements.
     */
    querySelectorAll(query) {
        let ks = sendMessage({
            method: "html",
            function: "dom_querySelectorAll",
            key: this.key,
            query: query,
            doc: this.doc,
        })
        return ks.map(k => new HtmlElement(k, this.doc));
    }

    /**
     * Get the children of the current element.
     * @returns {HtmlElement[]} An array of child elements.
     */
    get children() {
        let ks = sendMessage({
            method: "html",
            function: "getChildren",
            key: this.key,
            doc: this.doc,
        })
        return ks.map(k => new HtmlElement(k, this.doc));
    }

    /**
     * Get the nodes of the current element.
     * @returns {HtmlNode[]} An array of nodes.
     */
    get nodes() {
        let ks = sendMessage({
            method: "html",
            function: "getNodes",
            key: this.key,
            doc: this.doc,
        })
        return ks.map(k => new HtmlNode(k, this.doc));
    }

    /**
     * Get inner HTML of the element.
     * @returns {string} The inner HTML.
     */
    get innerHTML() {
        return sendMessage({
            method: "html",
            function: "getInnerHTML",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get parent element of the element. If the element has no parent, return null.
     * @returns {HtmlElement|null}
     */
    get parent() {
        let k = sendMessage({
            method: "html",
            function: "getParent",
            key: this.key,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k);
    }

    /**
     * Get class names of the element.
     * @returns {string[]} An array of class names.
     */
    get classNames() {
        return sendMessage({
            method: "html",
            function: "getClassNames",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get id of the element.
     * @returns {string | null} The id of the element.
     */
    get id() {
        return sendMessage({
            method: "html",
            function: "getId",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get local name of the element.
     * @returns {string} The tag name of the element.
     */
    get localName() {
        return sendMessage({
            method: "html",
            function: "getLocalName",
            key: this.key,
            doc: this.doc,
        })
    }
}

class HtmlNode {
    key = 0;

    doc = 0;

    constructor(k, doc) {
        this.key = k;
        this.doc = doc;
    }

    /**
     * Get the text content of the node.
     * @returns {string} The text content.
     */
    get text() {
        return sendMessage({
            method: "html",
            function: "node_text",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Get the type of the node.
     * @returns {string} The type of the node. ("text", "element", "comment", "document", "unknown")
     */
    get type() {
        return sendMessage({
            method: "html",
            function: "node_type",
            key: this.key,
            doc: this.doc,
        })
    }

    /**
     * Convert the node to an HtmlElement. If the node is not an element, return null.
     * @returns {HtmlElement|null}
     */
    toElement() {
        let k = sendMessage({
            method: "html",
            function: "node_toElement",
            key: this.key,
            doc: this.doc,
        })
        if(k == null) return null;
        return new HtmlElement(k, this.doc);
    }
}

function log(level, title, content) {
    sendMessage({
        method: 'log',
        level: level,
        title: title,
        content: content,
    })
}

let console = {
    log: (content) => {
        log('info', 'JS Console', content)
    },
    warn: (content) => {
        log('warning', 'JS Console', content)
    },
    error: (content) => {
        log('error', 'JS Console', content)
    },
};

/**
 * Create a comic object
 * @param id {string}
 * @param title {string}
 * @param subtitle {string}
 * @param cover {string}
 * @param tags {string[]}
 * @param description {string}
 * @param maxPage {number?}
 * @param language {string?}
 * @param favoriteId {string?} - Only set this field if the comic is from favorites page
 * @constructor
 */
function Comic({id, title, subtitle, cover, tags, description, maxPage, language, favoriteId}) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.cover = cover;
    this.tags = tags;
    this.description = description;
    this.maxPage = maxPage;
    this.language = language;
    this.favoriteId = favoriteId;
}

/**
 * Create a comic details object
 * @param title {string}
 * @param cover {string}
 * @param description {string?}
 * @param tags {Map<string, string[]> | {} | null | undefined}
 * @param chapters {Map<string, string> | {} | null | undefined}} - key: chapter id, value: chapter title
 * @param isFavorite {boolean | null | undefined}} - favorite status. If the comic source supports multiple folders, this field should be null
 * @param subId {string?} - a param which is passed to comments api
 * @param thumbnails {string[]?} - for multiple page thumbnails, set this to null, and use `loadThumbnails` api to load thumbnails
 * @param recommend {Comic[]?} - related comics
 * @param commentCount {number?}
 * @param likesCount {number?}
 * @param isLiked {boolean?}
 * @param uploader {string?}
 * @param updateTime {string?}
 * @param uploadTime {string?}
 * @param url {string?}
 * @constructor
 */
function ComicDetails({title, cover, description, tags, chapters, isFavorite, subId, thumbnails, recommend, commentCount, likesCount, isLiked, uploader, updateTime, uploadTime, url}) {
    this.title = title;
    this.cover = cover;
    this.description = description;
    this.tags = tags;
    this.chapters = chapters;
    this.isFavorite = isFavorite;
    this.subId = subId;
    this.thumbnails = thumbnails;
    this.recommend = recommend;
    this.commentCount = commentCount;
    this.likesCount = likesCount;
    this.isLiked = isLiked;
    this.uploader = uploader;
    this.updateTime = updateTime;
    this.uploadTime = uploadTime;
    this.url = url;
}

/**
 * Create a comment object
 * @param userName {string}
 * @param avatar {string?}
 * @param content {string}
 * @param time {string?}
 * @param replyCount {number?}
 * @param id {string?}
 * @param isLiked {boolean?}
 * @param score {number?}
 * @param voteStatus {number?} - 1: upvote, -1: downvote, 0: none
 * @constructor
 */
function Comment({userName, avatar, content, time, replyCount, id, isLiked, score, voteStatus}) {
    this.userName = userName;
    this.avatar = avatar;
    this.content = content;
    this.time = time;
    this.replyCount = replyCount;
    this.id = id;
    this.isLiked = isLiked;
    this.score = score;
    this.voteStatus = voteStatus;
}

class ComicSource {
    name = ""

    key = ""

    version = ""

    minAppVersion = ""

    url = ""

    /**
     * load data with its key
     * @param {string} dataKey
     * @returns {any}
     */
    loadData(dataKey) {
        return sendMessage({
            method: 'load_data',
            key: this.key,
            data_key: dataKey
        })
    }

    /**
     * load a setting with its key
     * @param key {string}
     * @returns {any}
     */
    loadSetting(key) {
        return sendMessage({
            method: 'load_setting',
            key: this.key,
            setting_key: key
        })
    }

    /**
     * save data
     * @param {string} dataKey
     * @param data
     */
    saveData(dataKey, data) {
        return sendMessage({
            method: 'save_data',
            key: this.key,
            data_key: dataKey,
            data: data
        })
    }

    /**
     * delete data
     * @param {string} dataKey
     */
    deleteData(dataKey) {
        return sendMessage({
            method: 'delete_data',
            key: this.key,
            data_key: dataKey,
        })
    }

    /**
     *
     * @returns {boolean}
     */
    get isLogged() {
        return sendMessage({
            method: 'isLogged',
            key: this.key,
        });
    }

    init() { }

    static sources = {}
}