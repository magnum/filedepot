# Filedepot

[![Gem Version](https://badge.fury.io/rb/filedepot.svg)](https://badge.fury.io/rb/filedepot)

Filedepot is a command-line tool that lets you efficiently synchronize different files between people using a remote server over SSH. Each file is identified by a **handle** — a stable name you choose. The system automatically keeps versions of every upload. Use `filedepot push HANDLE FILE` to upload; use `filedepot pull HANDLE` to download the latest version by default.

## Installation

```bash
gem install filedepot
```

Or add to your Gemfile:

```ruby
gem "filedepot"
```

## Configuration

Config file: `~/.filedepot/config.yml`

Run `filedepot setup` to create the config. On first run of any command, if the config file is not found, you will see "~/.filedepot/config.yml not found, let's config it" and setup is invoked automatically.

Config structure (keys in order):

```yaml
default_store: test
stores:
  - name: test
    type: ssh
    host: 127.0.0.1
    username: user
    base_path: /Users/user/filedepot
```

Optional `public_base_url` for public URLs (shown in info and after push):

```yaml
default_store: test
stores:
  - name: test
    type: ssh
    host: 127.0.0.1
    username: user
    base_path: /data/filedepot
    public_base_url: https://example.com/files
```

When `default_store` does not match any store name, the first store is used.

You can specify a store other than default by passing `--store [name]` for every command except `setup` and `config`.

## Permissions

On the server, use these commands to set up the folder for filedepot:

```bash
# set group
groupadd filedepot
usermod -aG filedepot user # for evey user you want allow filedepot

# set folder
mkdir -p /data/filedepot
chown -R :filedepot /data/filedepot/
chmod 2775 /data/filedepot
setfacl -d -m g:filedepot:rwx /data/filedepot
```

For existing folders:

```bash
setfacl -m g:filedepot:rwx /data/filedepot
```

## Commands

| Command | Description |
|---------|-------------|
| `filedepot` | Show current store and available commands |
| `filedepot setup` | Create or reconfigure config (interactive, prompts for name, type, host, username, base path, public base URL) |
| `filedepot config` | Open config file with $EDITOR; asks to run a test after closing |
| `filedepot push HANDLE FILE` | Send file to current storage |
| `filedepot pull HANDLE [--path PATH] [--version N]` | Get file from storage |
| `filedepot handles` | List all handles in storage |
| `filedepot versions HANDLE` | List all versions of a handle |
| `filedepot info HANDLE` | Show info for a handle |
| `filedepot delete HANDLE [--version N] [--yes]` | Delete file(s) after confirmation; use `--version N` for a specific version, `--yes` to skip confirmation |
| `filedepot test` | Run end-to-end test (push, pull, delete a temporary file) |

### Setup

Prompts for store name, type, host, username, base path, and optional public base URL. After writing the config.

### Config

Opens the config file in your editor. After you close the editor.

### Push

```bash
filedepot push test test.txt
```

Sends `test.txt` to storage with handle `test`. Each push creates a new version. When `public_base_url` is configured, the URL is shown after upload.

### Pull

```bash
filedepot pull test
filedepot pull test --path ./output/file.txt
filedepot pull test --version 2
filedepot pull test --version 2 --path ./output/file.txt
```

Gets the latest version by default, or a specific version with `--version`. Use `--path` to specify the local destination. Prompts before creating directories or overwriting files.

### Versions

Lists versions in descending order with creation datetime. Shows at most 10, with a summary if more exist.

### Info

Shows handle, remote base path, current version, updated-at datetime, and latest version URL (when `public_base_url` is set).

### Delete

Deletes all versions of a handle, or a specific version with `--version N`. Requires typing the handle name to confirm. Use `--yes` or `-y` to skip confirmation (for scripts).

### Test

Runs an end-to-end test: creates a temporary file, pushes it, deletes locally, pulls it back, deletes the handle. Prints "Test is OK" or "Test is KO, see the outputs for errors".

## Testing

```bash
bundle install
bundle exec rake test
```

## License

MIT
