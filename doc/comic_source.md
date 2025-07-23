# Comic Source

## Introduction

Venera is a comic reader that can read comics from various sources. 

All comic sources are written in javascript. 
Venera uses [flutter_qjs](https://github.com/wgh136/flutter_qjs) as js engine which is forked from [ekibun](https://github.com/ekibun/flutter_qjs).

This document will describe how to write a comic source for Venera.

## Comic Source List

Venera can display a list of comic sources in the app.

You can use the following repo url:
```
https://git.nyne.dev/nyne/venera-configs/raw/branch/main/index.json
```
The repo is maintained by the Venera team.

> The link is a mirror of the original repo. To contribute your comic source, please visit the [original repo](https://github.com/venera-app/venera-configs)

You should provide a repository url to let the app load the comic source list.
The url should point to a JSON file that contains the list of comic sources.

The JSON file should have the following format:

```json
[
  {
    "name": "Source Name",
    "url": "https://example.com/source.js",
    "filename": "Relative path to the source file",
    "version": "1.0.0",
    "description": "A brief description of the source"
  }
]
```

Only one of `url` and `filename` should be provided.
The description field is optional.

## Create a Comic Source

### Preparation

- Install Venera. Using flutter to run the project is recommended since it's easier to debug.
- An editor that supports javascript.
- Download template and venera javascript api from [here](https://github.com/venera-app/venera-configs).

### Start Writing

The template contains detailed comments and examples. You can refer to it when writing your own comic source.

Here is a brief introduction to the template:

> Note: Javascript api document is [here](js_api.md).

#### Write basic information

```javascript
class NewComicSource extends ComicSource {
    // Note: The fields which are marked as [Optional] should be removed if not used

    // name of the source
    name = ""

    // unique id of the source
    key = ""

    version = "1.0.0"

    minAppVersion = "1.0.0"

    // update url
    url = ""
// ...
}
```

In this part, you need to do the following:
- Change the class name to your source name.
- Fill in the name, key, version, minAppVersion, and url fields.

#### init function

```javascript
    /**
     * [Optional] init function
     */
    init() {

    }
```

The function will be called when the source is initialized. You can do some initialization work here.

Remove this function if not used.

#### Account

```javascript
// [Optional] account related
    account = {
        /**
         * [Optional] login with account and password, return any value to indicate success
         * @param account {string}
         * @param pwd {string}
         * @returns {Promise<any>}
         */
        login: async (account, pwd) => {

        },

        /**
         * [Optional] login with webview
         */
        loginWithWebview: {
            url: "",
            /**
             * check login status
             * @param url {string} - current url
             * @param title {string} - current title
             * @returns {boolean} - return true if login success
             */
            checkStatus: (url, title) => {

            },
            /**
             * [Optional] Callback when login success
             */
            onLoginSuccess: () => {

            },
        },

        /**
         * [Optional] login with cookies
         * Note: If `this.account.login` is implemented, this will be ignored
         */
        loginWithCookies: {
            fields: [
                "ipb_member_id",
                "ipb_pass_hash",
                "igneous",
                "star",
            ],
            /**
             * Validate cookies, return false if cookies are invalid.
             *
             * Use `Network.setCookies` to set cookies before validate.
             * @param values {string[]} - same order as `fields`
             * @returns {Promise<boolean>}
             */
            validate: async (values) => {

            },
        },

        /**
         * logout function, clear account related data
         */
        logout: () => {

        },

        // {string?} - register url
        registerWebsite: null
    }
```

In this part, you can implement login, logout, and register functions.

Remove this part if not used.

#### Explore page

```javascript
    // explore page list
    explore = [
        {
            // title of the page.
            // title is used to identify the page, it should be unique
            title: "",

            /// multiPartPage or multiPageComicList or mixed
            type: "multiPartPage",

            /**
             * load function
             * @param page {number | null} - page number, null for `singlePageWithMultiPart` type
             * @returns {{}}
             * - for `multiPartPage` type, return {title: string, comics: Comic[], viewMore: string?}[]
             * - for `multiPageComicList` type, for each page(1-based), return {comics: Comic[], maxPage: number}
             * - for `mixed` type, use param `page` as index. for each index(0-based), return {data: [], maxPage: number?}, data is an array contains Comic[] or {title: string, comics: Comic[], viewMore: string?}
             */
            load: async (page) => {

            },

            /**
             * Only use for `multiPageComicList` type.
             * `loadNext` would be ignored if `load` function is implemented.
             * @param next {string | null} - next page token, null if first page
             * @returns {Promise<{comics: Comic[], next: string?}>} - next is null if no next page.
             */
            loadNext(next) {},
        }
    ]
```

In this part, you can implement the explore page.

A comic source can have multiple explore pages.

There are three types of explore pages:
- multiPartPage: An explore page contains multiple parts, each part contains multiple comics.
- multiPageComicList: An explore page contains multiple comics, the comics are loaded page by page.
- mixed: An explore page contains multiple parts, each part can be a list of comics or a block of comics which have a title and a view more button.

#### Category Page

```javascript
    // categories
    category = {
        /// title of the category page, used to identify the page, it should be unique
        title: "",
        parts: [
            {
                // title of the part
                name: "Theme",

                // fixed or random
                // if random, need to provide `randomNumber` field, which indicates the number of comics to display at the same time
                type: "fixed",

                // number of comics to display at the same time
                // randomNumber: 5,

                categories: ["All", "Adventure", "School"],

                // category or search
                // if `category`, use categoryComics.load to load comics
                // if `search`, use search.load to load comics
                itemType: "category",

                // [Optional] {string[]?} must have same length as categories, used to provide loading param for each category
                categoryParams: ["all", "adventure", "school"],

                // [Optional] {string} cannot be used with `categoryParams`, set all category params to this value
                groupParam: null,
            }
        ],
        // enable ranking page
        enableRankingPage: false,
    }
```

Category page is a static page that contains multiple parts, each part contains multiple categories.

A comic source can only have one category page.

#### Category Comics Page

```javascript
    /// category comic loading related
    categoryComics = {
        /**
         * load comics of a category
         * @param category {string} - category name
         * @param param {string?} - category param
         * @param options {string[]} - options from optionList
         * @param page {number} - page number
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        load: async (category, param, options, page) => {

        },
        // provide options for category comic loading
        optionList: [
            {
                // For a single option, use `-` to separate the value and text, left for value, right for text
                options: [
                    "newToOld-New to Old",
                    "oldToNew-Old to New"
                ],
                // [Optional] {string[]} - show this option only when the value not in the list
                notShowWhen: null,
                // [Optional] {string[]} - show this option only when the value in the list
                showWhen: null
            }
        ],
        ranking: {
            // For a single option, use `-` to separate the value and text, left for value, right for text
            options: [
                "day-Day",
                "week-Week"
            ],
            /**
             * load ranking comics
             * @param option {string} - option from optionList
             * @param page {number} - page number
             * @returns {Promise<{comics: Comic[], maxPage: number}>}
             */
            load: async (option, page) => {

            }
        }
    }
```

When user clicks on a category, the category comics page will be displayed.

This part is used to load comics of a category.

#### Search

```javascript
    /// search related
    search = {
        /**
         * load search result
         * @param keyword {string}
         * @param options {(string | null)[]} - options from optionList
         * @param page {number}
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        load: async (keyword, options, page) => {

        },

        /**
         * load search result with next page token.
         * The field will be ignored if `load` function is implemented.
         * @param keyword {string}
         * @param options {(string)[]} - options from optionList
         * @param next {string | null}
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        loadNext: async (keyword, options, next) => {

        },

        // provide options for search
        optionList: [
            {
                // [Optional] default is `select`
                // type: select, multi-select, dropdown
                // For select, there is only one selected value
                // For multi-select, there are multiple selected values or none. The `load` function will receive a json string which is an array of selected values
                // For dropdown, there is one selected value at most. If no selected value, the `load` function will receive a null
                type: "select",
                // For a single option, use `-` to separate the value and text, left for value, right for text
                options: [
                    "0-time",
                    "1-popular"
                ],
                // option label
                label: "sort",
                // default selected options
                default: null,
            }
        ],

        // enable tags suggestions
        enableTagsSuggestions: false,
        // [Optional] handle tag suggestion click
        onTagSuggestionSelected: (namespace, tag) => {
            // return the text to insert into search box
            return `${namespace}:${tag}`
        },
    }
```

This part is used to load search results.

`load` and `loadNext` functions are used to load search results. 
If `load` function is implemented, `loadNext` function will be ignored.

#### Favorites

```javascript
    // favorite related
    favorites = {
        // whether support multi folders
        multiFolder: false,
        /**
         * add or delete favorite.
         * throw `Login expired` to indicate login expired, App will automatically re-login and re-add/delete favorite
         * @param comicId {string}
         * @param folderId {string}
         * @param isAdding {boolean} - true for add, false for delete
         * @param favoriteId {string?} - [Comic.favoriteId]
         * @returns {Promise<any>} - return any value to indicate success
         */
        addOrDelFavorite: async (comicId, folderId, isAdding, favoriteId) => {
            
        },
        /**
         * load favorite folders.
         * throw `Login expired` to indicate login expired, App will automatically re-login retry.
         * if comicId is not null, return favorite folders which contains the comic.
         * @param comicId {string?}
         * @returns {Promise<{folders: {[p: string]: string}, favorited: string[]}>} - `folders` is a map of folder id to folder name, `favorited` is a list of folder id which contains the comic
         */
        loadFolders: async (comicId) => {

        },
        /**
         * add a folder
         * @param name {string}
         * @returns {Promise<any>} - return any value to indicate success
         */
        addFolder: async (name) => {

        },
        /**
         * delete a folder
         * @param folderId {string}
         * @returns {Promise<void>} - return any value to indicate success
         */
        deleteFolder: async (folderId) => {

        },
        /**
         * load comics in a folder
         * throw `Login expired` to indicate login expired, App will automatically re-login retry.
         * @param page {number}
         * @param folder {string?} - folder id, null for non-multi-folder
         * @returns {Promise<{comics: Comic[], maxPage: number}>}
         */
        loadComics: async (page, folder) => {

        },
        /**
         * load comics with next page token
         * @param next {string | null} - next page token, null for first page
         * @param folder {string}
         * @returns {Promise<{comics: Comic[], next: string?}>}
         */
        loadNext: async (next, folder) => {

        },
    }
```

This part is used to manage network favorites of the source.

`load` and `loadNext` functions are used to load search results.
If `load` function is implemented, `loadNext` function will be ignored.

#### Comic Details

```javascript
    /// single comic related
    comic = {
        /**
         * load comic info
         * @param id {string}
         * @returns {Promise<ComicDetails>}
         */
        loadInfo: async (id) => {

        },
        /**
         * [Optional] load thumbnails of a comic
         *
         * To render a part of an image as thumbnail, return `${url}@x=${start}-${end}&y=${start}-${end}`
         * - If width is not provided, use full width
         * - If height is not provided, use full height
         * @param id {string}
         * @param next {string?} - next page token, null for first page
         * @returns {Promise<{thumbnails: string[], next: string?}>} - `next` is next page token, null for no more
         */
        loadThumbnails: async (id, next) => {

        },

        /**
         * rate a comic
         * @param id
         * @param rating {number} - [0-10] app use 5 stars, 1 rating = 0.5 stars,
         * @returns {Promise<any>} - return any value to indicate success
         */
        starRating: async (id, rating) => {

        },

        /**
         * load images of a chapter
         * @param comicId {string}
         * @param epId {string?}
         * @returns {Promise<{images: string[]}>}
         */
        loadEp: async (comicId, epId) => {

        },
        /**
         * [Optional] provide configs for an image loading
         * @param url
         * @param comicId
         * @param epId
         * @returns {ImageLoadingConfig | Promise<ImageLoadingConfig>}
         */
        onImageLoad: (url, comicId, epId) => {
            return {}
        },
        /**
         * [Optional] provide configs for a thumbnail loading
         * @param url {string}
         * @returns {ImageLoadingConfig | Promise<ImageLoadingConfig>}
         *
         * `ImageLoadingConfig.modifyImage` and `ImageLoadingConfig.onLoadFailed` will be ignored.
         * They are not supported for thumbnails.
         */
        onThumbnailLoad: (url) => {
            return {}
        },
        /**
         * [Optional] like or unlike a comic
         * @param id {string}
         * @param isLike {boolean} - true for like, false for unlike
         * @returns {Promise<void>}
         */
        likeComic: async (id, isLike) =>  {

        },
        /**
         * [Optional] load comments
         *
         * Since app version 1.0.6, rich text is supported in comments.
         * Following html tags are supported: ['a', 'b', 'i', 'u', 's', 'br', 'span', 'img'].
         * span tag supports style attribute, but only support font-weight, font-style, text-decoration.
         * All images will be placed at the end of the comment.
         * Auto link detection is enabled, but only http/https links are supported.
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param page {number}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<{comments: Comment[], maxPage: number?}>}
         */
        loadComments: async (comicId, subId, page, replyTo) => {

        },
        /**
         * [Optional] send a comment, return any value to indicate success
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param content {string}
         * @param replyTo {string?} - commentId to reply, not null when reply to a comment
         * @returns {Promise<any>}
         */
        sendComment: async (comicId, subId, content, replyTo) => {

        },
        /**
         * [Optional] like or unlike a comment
         * @param comicId {string}
         * @param subId {string?} - ComicDetails.subId
         * @param commentId {string}
         * @param isLike {boolean} - true for like, false for unlike
         * @returns {Promise<void>}
         */
        likeComment: async (comicId, subId, commentId, isLike) => {

        },
        /**
         * [Optional] vote a comment
         * @param id {string} - comicId
         * @param subId {string?} - ComicDetails.subId
         * @param commentId {string} - commentId
         * @param isUp {boolean} - true for up, false for down
         * @param isCancel {boolean} - true for cancel, false for vote
         * @returns {Promise<number>} - new score
         */
        voteComment: async (id, subId, commentId, isUp, isCancel) => {

        },
        // {string?} - regex string, used to identify comic id from user input
        idMatch: null,
        /**
         * [Optional] Handle tag click event
         * @param namespace {string}
         * @param tag {string}
         * @returns {{action: string, keyword: string, param: string?}}
         */
        onClickTag: (namespace, tag) => {

        },
        /**
         * [Optional] Handle links
         */
        link: {
            /**
             * set accepted domains
             */
            domains: [
                'example.com'
            ],
            /**
             * parse url to comic id
             * @param url {string}
             * @returns {string | null}
             */
            linkToId: (url) => {

            }
        },
        // enable tags translate
        enableTagsTranslate: false,
    }

```

This part is used to load comic details.

#### Settings

```javascript
    /*
    [Optional] settings related
    Use this.loadSetting to load setting
    ```
    let setting1Value = this.loadSetting('setting1')
    console.log(setting1Value)
    ```
     */
    settings = {
        setting1: {
            // title
            title: "Setting1",
            // type: input, select, switch
            type: "select",
            // options
            options: [
                {
                    // value
                    value: 'o1',
                    // [Optional] text, if not set, use value as text
                    text: 'Option 1',
                },
            ],
            default: 'o1',
        },
        setting2: {
            title: "Setting2",
            type: "switch",
            default: true,
        },
        setting3: {
            title: "Setting3",
            type: "input",
            validator: null, // string | null, regex string
            default: '',
        },
        setting4: {
            title: "Setting4",
            type: "callback",
            buttonText: "Click me",
            /**
             * callback function
             *
             * If the callback function returns a Promise, the button will show a loading indicator until the promise is resolved.
             * @returns {void | Promise<any>}
             */
            callback: () => {
                // do something
            }
        }
    }
```

This part is used to provide settings for the source.


#### Translations

```javascript
    // [Optional] translations for the strings in this config
    translation = {
        'zh_CN': {
            'Setting1': '设置1',
            'Setting2': '设置2',
            'Setting3': '设置3',
        },
        'zh_TW': {},
        'en': {}
    }
```

This part is used to provide translations for the source.

> Note: strings in the UI api will not be translated automatically. You need to translate them manually.