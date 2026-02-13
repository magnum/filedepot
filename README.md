# Filedepot

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

On first run, a default config is created:

```yaml
default_source: test
sources:
  - name: test
    ssh: ssh
    host: 127.0.0.1
    username:
    base_path: /Users/user/filedepot
```

## Commands

| Command | Description |
|---------|-------------|
| `filedepot` | Show current source and available commands |
| `filedepot config` | Open config file with $EDITOR |
| `filedepot push HANDLE` | Send file to current storage |
| `filedepot pull HANDLE [VERSION]` | Get file from storage |
| `filedepot versions HANDLE` | List all versions of a handle |
| `filedepot delete HANDLE [VERSION]` | Delete file(s) after confirmation |

## License

MIT
