# Venera Headless Mode Update

This update introduces a powerful new headless mode to Venera, allowing for automation and integration with other systems. All core functionalities such as WebDAV sync, script updates, and subscription updates are now accessible via the command line.

## New Features

### 1. Headless Mode (`--headless`)

Venera can now be run from the command line without a graphical user interface. This is the foundation for all new automation capabilities.

### 2. Command-Line Interface (CLI)

A new set of commands has been added to control Venera's features:

-   **`webdav up`**: Uploads your local configuration to the configured WebDAV server.
-   **`webdav down`**: Downloads the remote configuration from your WebDAV server, overwriting the local one.
-   **`updatescript all`**: Checks for and applies all available updates for comic source scripts.
-   **`updatesubscribe`**: Checks for updates for all comics in your designated "Follow Updates" folder.

### 3. Structured JSON Output

All output from the headless mode is in a machine-readable JSON format, prefixed with `[CLI PRINT]`. This makes it easy to integrate Venera with scripts and other tools. The output includes status updates (`running`, `success`, `error`), progress reports, and detailed data for updated comics.

### 4. Log Suppression (`--ignore-disheadless-log`)

A new flag has been added to suppress regular application logs, ensuring that only the structured JSON output is printed to the console.

## How to Use Headless Mode

To use the new headless mode, you will need to run the Venera executable from your terminal. The basic syntax is:

```bash
venera --headless <command> <subcommand>
```

### Examples

**Sync with WebDAV:**

```bash
# Upload local settings
venera --headless webdav up

# Download remote settings
venera --headless webdav down
```

**Update Comic Source Scripts:**

```bash
venera --headless updatescript all
```

**Update Subscriptions:**

```bash
venera --headless updatesubscribe
```

### `updatesubscribe` Output Format

The `updatesubscribe` command provides detailed progress and a final list of updated comics.

**Progress Update:**

For each comic being checked, a progress object is printed:

```json
{
  "status": "running",
  "message": "Progress",
  "data": {
    "current": 5,
    "total": 25,
    "comic": {
      "id": "comic_id",
      "name": "Comic Name",
      "coverUrl": "https://example.com/cover.jpg",
      "author": "Author Name",
      "type": "source_key",
      "updateTime": "2023-10-27 10:00:00",
      "tags": ["tag1", "tag2"]
    }
  }
}
```

**Final Success Output:**

Once the update check is complete, a final object is printed containing all comics that had an update:

```json
{
  "status": "success",
  "message": "Updated comics list.",
  "data": [
    {
      "id": "updated_comic_id",
      "name": "Updated Comic Name",
      "coverUrl": "https://example.com/new_cover.jpg",
      "author": "Author Name",
      "type": "source_key",
      "updateTime": "2023-10-28 12:00:00",
      "tags": ["tag1", "tag2", "new_tag"]
    }
  ]
}
```

This update significantly enhances Venera's utility for power users and developers who wish to build automated workflows around their comic collections.
