/// encode, decode, hash, decrypt
let Convert = {
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

function randomInt(min, max) {
    return sendMessage({
        method: 'random',
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
     * @returns {Promise<ArrayBuffer>} The response from the request.
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
     * @returns {Promise<Object>} The response from the request.
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
     * @returns {Promise<Object>} The response from the request.
     */
    async get(url, headers) {
        return this.sendRequest('GET', url, headers);
    },

    /**
     * Sends an HTTP POST request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<Object>} The response from the request.
     */
    async post(url, headers, data) {
        return this.sendRequest('POST', url, headers, data);
    },

    /**
     * Sends an HTTP PUT request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<Object>} The response from the request.
     */
    async put(url, headers, data) {
        return this.sendRequest('PUT', url, headers, data);
    },

    /**
     * Sends an HTTP PATCH request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @param data - The data to send with the request.
     * @returns {Promise<Object>} The response from the request.
     */
    async patch(url, headers, data) {
        return this.sendRequest('PATCH', url, headers, data);
    },

    /**
     * Sends an HTTP DELETE request.
     * @param {string} url - The URL to send the request to.
     * @param {Object} headers - The headers to include in the request.
     * @returns {Promise<Object>} The response from the request.
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
        if(!k) return null;
        return new HtmlElement(k);
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
        return ks.map(k => new HtmlElement(k));
    }
}

/**
 * HtmlDom class for interacting with HTML elements.
 */
class HtmlElement {
    key = 0;

    /**
     * Constructor for HtmlDom.
     * @param {number} k - The key of the element.
     */
    constructor(k) {
        this.key = k;
    }

    /**
     * Get the text content of the element.
     * @returns {string} The text content.
     */
    get text() {
        return sendMessage({
            method: "html",
            function: "getText",
            key: this.key
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
            key: this.key
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
            query: query
        })
        if(!k) return null;
        return new HtmlElement(k);
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
            query: query
        })
        return ks.map(k => new HtmlElement(k));
    }

    /**
     * Get the children of the current element.
     * @returns {HtmlElement[]} An array of child elements.
     */
    get children() {
        let ks = sendMessage({
            method: "html",
            function: "getChildren",
            key: this.key
        })
        return ks.map(k => new HtmlElement(k));
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

    init() { }

    static sources = {}
}