# Javascript API

## Overview

The Javascript API is a set of functions that used to interact application.

There are following parts in the API:
- [Convert](#Convert)
- [Network](#Network)
- [Html](#Html)
- [UI](#UI)
- [Utils](#Utils)
- [Types](#Types)


## Convert

Convert is a set of functions that used to convert data between different types.

### `Convert.encodeUtf8(str: string): ArrayBuffer`

Convert a string to an ArrayBuffer.

### `Convert.decodeUtf8(value: ArrayBuffer): string`

Convert an ArrayBuffer to a string.

### `Convert.encodeBase64(value: ArrayBuffer): string`

Convert an ArrayBuffer to a base64 string.

### `Convert.decodeBase64(value: string): ArrayBuffer`

Convert a base64 string to an ArrayBuffer.

### `Convert.md5(value: ArrayBuffer): ArrayBuffer`

Calculate the md5 hash of an ArrayBuffer.

### `Convert.sha1(value: ArrayBuffer): ArrayBuffer`

Calculate the sha1 hash of an ArrayBuffer.

### `Convert.sha256(value: ArrayBuffer): ArrayBuffer`

Calculate the sha256 hash of an ArrayBuffer.

### `Convert.sha512(value: ArrayBuffer): ArrayBuffer`

Calculate the sha512 hash of an ArrayBuffer.

### `Convert.hmac(key: ArrayBuffer, value: ArrayBuffer, hash: string): ArrayBuffer`

Calculate the hmac hash of an ArrayBuffer.

### `Convert.hmacString(key: ArrayBuffer, value: ArrayBuffer, hash: string): string`

Calculate the hmac hash of an ArrayBuffer and return a string.

### `Convert.decryptAesEcb(value: ArrayBuffer, key: ArrayBuffer): ArrayBuffer`

Decrypt an ArrayBuffer with AES ECB mode.

### `Convert.decryptAesCbc(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

Decrypt an ArrayBuffer with AES CBC mode.

### `Convert.decryptAesCfb(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

Decrypt an ArrayBuffer with AES CFB mode.

### `Convert.decryptAesOfb(value: ArrayBuffer, key: ArrayBuffer, iv: ArrayBuffer): ArrayBuffer`

Decrypt an ArrayBuffer with AES OFB mode.

### `Convert.decryptRsa(value: ArrayBuffer, key: ArrayBuffer): ArrayBuffer`

Decrypt an ArrayBuffer with RSA.

### `Convert.hexEncode(value: ArrayBuffer): string`

Convert an ArrayBuffer to a hex string.

## Network

Network is a set of functions that used to send network requests and manage network resources.

### `Network.fetchBytes(method: string, url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: ArrayBuffer}>`

Send a network request and return the response as an ArrayBuffer.

### `Network.sendRequest(method: string, url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

Send a network request and return the response as a string.

### `Network.get(url: string, headers: object): Promise<{status: number, headers: object, body: string}>`

Send a GET request and return the response as a string.

### `Network.post(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

Send a POST request and return the response as a string.

### `Network.put(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

Send a PUT request and return the response as a string.

### `Network.delete(url: string, headers: object): Promise<{status: number, headers: object, body: string}>`

Send a DELETE request and return the response as a string.

### `Network.patch(url: string, headers: object, data: ArrayBuffer): Promise<{status: number, headers: object, body: string}>`

Send a PATCH request and return the response as a string.

### `Network.setCookies(url: string, cookies: Cookie[]): void`

Set cookies for a specific url.

### `Network.getCookies(url: string): Cookie[]`

Get cookies for a specific url.

### `Network.deleteCookies(url: string): void`

Delete cookies for a specific url.

### `fetch`

The fetch function is a wrapper of the `Network.fetchBytes` function. Same as the `fetch` function in the browser.

## Html

Api for parsing HTML.

### `new HtmlDocument(html: string): HtmlDocument`

Create a HtmlDocument object from a html string.

### `HtmlDocument.querySelector(selector: string): HtmlElement`

Find the first element that matches the selector.

### `HtmlDocument.querySelectorAll(selector: string): HtmlElement[]`

Find all elements that match the selector.

### `HtmlDocument.getElementById(id: string): HtmlElement`

Find the element with the id.

### `HtmlDocument.dispose(): void`

Dispose the HtmlDocument object.

### `HtmlElement.querySelector(selector: string): HtmlElement`

Find the first element that matches the selector.

### `HtmlElement.querySelectorAll(selector: string): HtmlElement[]`

Find all elements that match the selector.

### `HtmlElement.getElementById(id: string): HtmlElement`

Find the element with the id.

### `get HtmlElement.text(): string`

Get the text content of the element.

### `get HtmlElement.attributes(): object`

Get the attributes of the element.

### `get HtmlElement.children(): HtmlElement[]`

Get the children

### `get HtmlElement.nodes(): HtmlNode[]`

Get the child nodes

### `get HtmlElement.parent(): HtmlElement | null`

Get the parent element

### `get HtmlElement.innerHtml(): string`

Get the inner html

### `get HtmlElement.classNames(): string[]`

Get the class names

### `get HtmlElement.id(): string | null`

Get the id

### `get HtmlElement.localName(): string`

Get the local name

### `get HtmlElement.previousSibling(): HtmlElement | null`

Get the previous sibling

### `get HtmlElement.nextSibling(): HtmlElement | null`

Get the next sibling

### `get HtmlNode.type(): string`

Get the node type ("text", "element", "comment", "document", "unknown")

### `HtmlNode.toElement(): HtmlElement | null`

Convert the node to an element

### `get HtmlNode.text(): string`

Get the text content of the node

## UI

### `UI.showMessage(message: string): void`

Show a message.

### `UI.showDialog(title: string, content: string, actions: {text: string, callback: () => void | Promise<void>, style: "text"|"filled"|"danger"}[]): void`

Show a dialog. Any action will close the dialog.

### `UI.launchUrl(url: string): void`

Open a url in external browser.

### `UI.showLoading(onCancel: () => void | null | undefined): number`

Show a loading dialog.

### `UI.cancelLoading(id: number): void`

Cancel a loading dialog.

### `UI.showInputDialog(title: string, validator: (string) => string | null | undefined): string | null`

Show an input dialog.

### `UI.showSelectDialog(title: string, options: string[], initialIndex?: number): number | null`

Show a select dialog.

## Utils

### `createUuid(): string`

create a time-based uuid.

### `randomInt(min: number, max: number): number`

Generate a random integer between min and max.

### `randomDouble(min: number, max: number): number`

Generate a random double between min and max.

### console

Send log to application console. Same api as the browser console.

## Types

### `Cookie`

```javascript
/**
 * Create a cookie object.
 * @param name {string}
 * @param value {string}
 * @param domain {string}
 * @constructor
 */
function Cookie({name, value, domain}) {
    this.name = name;
    this.value = value;
    this.domain = domain;
}
```

### `Comic`

```javascript
/**
 * Create a comic object
 * @param id {string}
 * @param title {string}
 * @param subtitle {string}
 * @param subTitle {string} - equal to subtitle
 * @param cover {string}
 * @param tags {string[]}
 * @param description {string}
 * @param maxPage {number?}
 * @param language {string?}
 * @param favoriteId {string?} - Only set this field if the comic is from favorites page
 * @param stars {number?} - 0-5, double
 * @constructor
 */
function Comic({id, title, subtitle, subTitle, cover, tags, description, maxPage, language, favoriteId, stars}) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.subTitle = subTitle;
    this.cover = cover;
    this.tags = tags;
    this.description = description;
    this.maxPage = maxPage;
    this.language = language;
    this.favoriteId = favoriteId;
    this.stars = stars;
}
```

### `ComicDetails`
```javascript
/**
 * Create a comic details object
 * @param title {string}
 * @param subtitle {string}
 * @param subTitle {string} - equal to subtitle
 * @param cover {string}
 * @param description {string?}
 * @param tags {Map<string, string[]> | {} | null | undefined}
 * @param chapters {Map<string, string> | {} | null | undefined} - key: chapter id, value: chapter title
 * @param isFavorite {boolean | null | undefined} - favorite status. If the comic source supports multiple folders, this field should be null
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
 * @param stars {number?} - 0-5, double
 * @param maxPage {number?}
 * @param comments {Comment[]?}- `since 1.0.7` App will display comments in the details page.
 * @constructor
 */
function ComicDetails({title, subtitle, subTitle, cover, description, tags, chapters, isFavorite, subId, thumbnails, recommend, commentCount, likesCount, isLiked, uploader, updateTime, uploadTime, url, stars, maxPage, comments}) {
    this.title = title;
    this.subtitle = subtitle ?? subTitle;
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
    this.stars = stars;
    this.maxPage = maxPage;
    this.comments = comments;
}
```

### `Comment`
```javascript
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
```

### `ImageLoadingConfig`
```javascript
/**
 * Create image loading config
 * @param url {string?}
 * @param method {string?} - http method, uppercase
 * @param data {any} - request data, may be null
 * @param headers {Object?} - request headers
 * @param onResponse {((ArrayBuffer) => ArrayBuffer)?} - modify response data
 * @param modifyImage {string?}
 *  A js script string.
 *  The script will be executed in a new Isolate.
 *  A function named `modifyImage` should be defined in the script, which receives an [Image] as the only argument, and returns an [Image]..
 * @param onLoadFailed {(() => ImageLoadingConfig)?} - called when the image loading failed
 * @constructor
 * @since 1.0.5
 *
 * To keep the compatibility with the old version, do not use the constructor. Consider creating a new object with the properties directly.
 */
function ImageLoadingConfig({url, method, data, headers, onResponse, modifyImage, onLoadFailed}) {
    this.url = url;
    this.method = method;
    this.data = data;
    this.headers = headers;
    this.onResponse = onResponse;
    this.modifyImage = modifyImage;
    this.onLoadFailed = onLoadFailed;
}
```

### `ComicSource`
```javascript
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
```