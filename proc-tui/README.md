# proc-tui

A terminal UI for running and monitoring Procfile processes, built with the Charm Ruby libraries (bubbletea-ruby, bubbles-ruby, lipgloss-ruby).

Similar to [Overmind](https://github.com/DarthSim/overmind) and [Foreman](https://github.com/ddollar/foreman), but with an interactive TUI.

## Features

- **Combined Log View**: See all process output in one view with color-coded prefixes
- **Per-Process Tabs**: Switch between processes to see individual logs
- **Process Colors**: Each process gets a unique color for easy identification
- **Auto-Scroll**: Automatically follows new log output (toggleable)
- **Search/Filter**: Filter logs by text in real-time
- **Process Control**: Start, stop, and restart individual processes
- **Status Indicators**: See which processes are running/stopped

## Installation

```bash
bundle install
```

## Usage

```bash
./proc-tui [Procfile]
```

If no Procfile is specified, it looks for `Procfile` in the current directory.

### Example Procfile

```procfile
web: bundle exec rails server -p 3000
worker: bundle exec sidekiq
webpack: bin/webpack-dev-server
```

## Keyboard Controls

### Navigation
| Key | Action |
|-----|--------|
| `←` / `h` | Previous tab |
| `→` / `l` | Next tab |
| `1-9` | Jump to tab N |
| `0` | Jump to "All" tab |
| `↑` / `k` | Scroll up |
| `↓` / `j` | Scroll down |
| `PgUp` / `Ctrl+u` | Page up |
| `PgDown` / `Ctrl+d` | Page down |
| `Home` / `g` | Scroll to top |
| `End` / `G` | Scroll to bottom |

### Process Control
| Key | Action |
|-----|--------|
| `r` | Restart current process |
| `s` | Stop current process |
| `S` | Start current process |

### Search/Filter
| Key | Action |
|-----|--------|
| `/` | Enter filter mode |
| `Enter` / `Esc` | Exit filter mode |
| `Ctrl+u` | Clear filter |

### Other
| Key | Action |
|-----|--------|
| `a` | Toggle auto-scroll |
| `q` / `Ctrl+c` | Quit (stops all processes) |


## Dependencies

- [bubbletea-ruby](https://github.com/marcoroth/bubbletea-ruby) - Terminal UI framework
- [bubbles-ruby](https://github.com/marcoroth/bubbles-ruby) - UI components  
- [lipgloss-ruby](https://github.com/marcoroth/lipgloss-ruby) - Styling
