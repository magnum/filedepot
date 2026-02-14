# Filedepot

[![Gem Version](https://badge.fury.io/rb/filedepot.svg)](https://badge.fury.io/rb/filedepot)

Command-line tool to sync files on remote storage via SSH.

## Installation

```bash
gem install filedepot
```

Or add to your Gemfile:

```ruby
gem "filedepot"
```

## Configuration

Config file: `$HOME/.filedepot/config.yml`

Run `filedepot setup` to create the config. On first run of any command, setup is automatically invoked if no config exists.

```yaml
stores:
  - name: test
    ssh: true
    host: 127.0.0.1
    username: user
    base_path: /Users/user/filedepot
default_store: test
```

Optional `public_base_path` for public URLs (shown in info and after push):

```yaml
stores:
  - name: test
    ssh: true
    host: 127.0.0.1
    base_path: /data/filedepot
    public_base_path: https://example.com/files
default_store: test
```

When `default_store` does not match any store name, the first store is used.

## Commands

| Command | Description |
|---------|-------------|
| `filedepot` | Show current store and available commands |
| `filedepot setup` | Create or reconfigure config (interactive) |
| `filedepot config` | Open config file with $EDITOR |
| `filedepot push HANDLE FILE` | Send file to current storage |
| `filedepot pull HANDLE [--path PATH] [--version N]` | Get file from storage |
| `filedepot handles` | List all handles in storage |
| `filedepot versions HANDLE` | List all versions of a handle |
| `filedepot info HANDLE` | Show info for a handle |
| `filedepot delete HANDLE [VERSION]` | Delete file(s) after confirmation |

### Push

```bash
filedepot push test test.txt
```

Sends `test.txt` to storage with handle `test`. Each push creates a new version. When `public_base_path` is configured, the URL is shown after upload.

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

Shows handle, remote base path, current version, updated-at datetime, and latest version URL (when `public_base_path` is set).

## Testing

```bash
bundle install
bundle exec rake test
```

## License

MIT
