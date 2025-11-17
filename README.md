# brewmeister

Homebrew package manager running as a service account for RMM systems.

## Overview

brewmeister allows Homebrew to run under a dedicated service account (`_brewmeister`) with proper privilege separation, making it ideal for remote management and automation scenarios.

## Building from Source

brewmeister requires the `--disable-sandbox` flag when building due to Info.plist embedding:

```bash
# Update build timestamp (format: YY.MM.DD.HHmm UTC)
./Scripts/update-build-version.sh

# Build
swift build --disable-sandbox
```

For release builds:

```bash
./Scripts/update-build-version.sh
swift build --disable-sandbox -c release
```

**Why `--disable-sandbox`?**
brewmeister embeds an Info.plist file into the binary using linker flags (`-sectcreate`). This makes version information visible in Finder's "Get Info" dialog but requires disabling Swift Package Manager's build sandbox.

**Build Versioning:**
The `update-build-version.sh` script automatically updates `CFBundleVersion` in Info.plist with a UTC timestamp in format `YY.MM.DD.HHmm` (e.g., `25.11.17.1549`). This ensures each build has a unique, automatically-incrementing version number that's visible in Finder.

## Installation

```bash
sudo .build/release/brewmeister setupmeister
```

This will:
- Create the `_brewmeister` service account
- Install Homebrew to `/opt/brewmeister`
- Configure PATH and zsh integration
- Install brewmeister to `/usr/local/bin`
- Install man page to `/usr/local/share/man/man1`

## Commands

### Management Commands

- `brewmeister setupmeister` - Install brewmeister service account and Homebrew
- `brewmeister healthmeister` - Validate brewmeister installation and repair issues
- `brewmeister removemeister` - Remove brewmeister (and optionally Homebrew)
- `brewmeister usermeister [username]` - Enable a user to access brewmeister's Homebrew installation

### Brew Passthrough

All Homebrew commands can be used with either explicit or implicit syntax:

```bash
# Explicit (recommended for clarity)
brewmeister brew install jq
brewmeister brew upgrade
brewmeister brew list

# Implicit (shorter)
brewmeister install jq
brewmeister upgrade
brewmeister list
```

### User Access

The `usermeister` command enables regular users to use brewmeister's Homebrew installation:

```bash
# Enable current user (run with sudo)
sudo brewmeister usermeister

# Enable specific user
sudo brewmeister usermeister username
```

This configures the user's shell to:
- Use brewmeister's Homebrew installation at `/opt/brewmeister`
- Create a `brew` alias that runs `sudo brewmeister brew`
- Override any existing Homebrew installation (e.g., `/opt/homebrew`)

After running usermeister, the user should reload their shell:
```bash
source ~/.zshrc
```

**Note:** Users will be prompted for their sudo password when running `brew` commands.

## Documentation

- Run `man brewmeister` for full documentation
- Run `brewmeister --help` for command list
- Run `brewmeister [command] --help` for command-specific help

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later (for building)
- Xcode Command Line Tools
- sudo privileges (for installation)

## License

Copyright © 2025 Peet Inc. All rights reserved.
