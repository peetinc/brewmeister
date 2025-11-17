# macOS Build Tools Directory

This directory contains macOS build, signing, notarization, and deployment scripts for rmmagent.

## Purpose

The `bin/macos_build/` directory provides:
- Complete build and deployment automation
- Code signing and notarization workflows
- Tactical RMM agent installation integration
- Development and testing scripts
- Production-ready build pipelines

## Quick Start

The main build script is **`macos-build_with_test.sh`** - a comprehensive build, sign, notarize, and deploy tool.

```bash
# Build, sign, notarize, and deploy (requires environment setup)
sudo -E ./bin/macos_build/macos-build_with_test.sh --arch universal

# Build only (no signing/notarization)
sudo ./bin/macos_build/macos-build_with_test.sh --arch universal --skip-sign --skip-notary

# View all options
./bin/macos_build/macos-build_with_test.sh --help
```

## Setup Instructions

### 1. Configure Code Signing Certificate (Optional)

Set the `MACOS_SIGN_CERT` environment variable to your Developer ID Application certificate:

```bash
export MACOS_SIGN_CERT="Developer ID Application: Your Name (TEAMID)"
```

To find your certificate name:

```bash
security find-identity -v -p codesigning
```

Look for the "Developer ID Application" certificate. **Note:** Use `sudo -E` to preserve environment variables when running the build script.

### 2. Setup Notarization Credentials (Optional, One-Time)

Store your Apple notarization credentials in the macOS keychain:

```bash
xcrun notarytool store-credentials "rmmagent-notary" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

**Where to find these values:**

- **Apple ID**: Your Apple Developer account email
- **Team ID**: Found at [developer.apple.com/account](https://developer.apple.com/account) → Membership section
- **Password**: App-specific password from [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords

**Note:** This stores credentials securely in your keychain. You only need to do this once per machine.

## Available Scripts

### macos-build_with_test.sh (Main Build Script)

**Comprehensive build, sign, notarize, and deploy script with Tactical RMM integration.**

This is the primary script that mirrors the MeshAgent build system architecture. It handles the complete build-to-deployment pipeline.

**Features:**
- Builds rmmagent for Intel (amd64), ARM (arm64), or Universal binary
- Optional code signing with certificate validation
- Optional notarization with Apple's notary service
- Automatic deployment to system paths
- LaunchDaemon management (start/stop/enable/disable)
- **Tactical RMM agent installation** with full parameter support
- Git pull integration for updates
- Step-by-step progress tracking with timestamps
- Comprehensive validation and error handling

**Build Options:**

```bash
--arch <amd64|arm64|universal>  # Architecture to build (default: universal)
--skip-build                    # Skip build step, use existing binary
--skip-sign                     # Skip signing step
--skip-notary                   # Skip notarization step
--git-pull                      # Pull latest changes before building
```

**Deployment Options:**

```bash
--deploy <yes|no>               # Deploy binary to system (default: yes)
--deploy-path <path>            # Deployment path (default: /opt/tacticalagent/tacticalagent)
--service <enable|disable>      # LaunchDaemon state (default: enable)
```

**Tactical RMM Installation Options:**

```bash
--trmm-exec                     # Execute tacticalagent installation after build
--trmm-mode <mode>              # TRMM mode (auto-enables --trmm-exec):
                                #   install - Install and configure agent
                                #   svc     - Run as service
--trmm-api <url>                # TRMM server API URL
                                #   Example: https://api.artichoke.tech
--trmm-client-id <id>           # TRMM Client ID (numeric)
--trmm-site-id <id>             # TRMM Site ID (numeric)
--trmm-agent-type <type>        # TRMM Agent Type (workstation or server)
--trmm-auth <token>             # TRMM Authentication token
```

**Example TRMM Installation Command:**

To execute this Tactical RMM command:
```bash
/tacticalagent -m install --api https://api.example.com --client-id 1 --site-id 1 --agent-type workstation --auth <your-auth-token>
```

Use this build script command:
```bash
sudo -E ./bin/macos_build/macos-build_with_test.sh \
  --arch universal \
  --trmm-mode install \
  --trmm-api https://api.example.com \
  --trmm-client-id 1 \
  --trmm-site-id 1 \
  --trmm-agent-type workstation \
  --trmm-auth <your-auth-token>
```

This will build, sign, notarize, deploy, and execute the tacticalagent with the specified TRMM parameters.

### macos-sign.sh

Code signing script that signs a macOS binary with your Developer ID certificate.

**Usage:**

```bash
# Sign a specific binary
./bin/macos_build/macos-sign.sh build/Output/macos/universal/rmmagent
```

**Requirements:**
- `MACOS_SIGN_CERT` environment variable must be set
- Certificate must be installed in keychain

### macos-notarize.sh

Notarization script that submits a binary to Apple's notary service and staples the notarization ticket.

**Usage:**

```bash
# Notarize a specific binary
./bin/macos_build/macos-notarize.sh build/Output/macos/universal/rmmagent
```

**Requirements:**
- Keychain profile `rmmagent-notary` must be configured
- Binary must already be signed

### test-macos-rmmagent.sh (Legacy)

Legacy development testing script. **Recommended to use `macos-build_with_test.sh` instead.**

## Common Workflows

### 1. Development & Testing (Build Only)

Build and test locally without signing or deploying to production:

```bash
# Build universal binary without signing/notarization
sudo ./bin/macos_build/macos-build_with_test.sh --arch universal --skip-sign --skip-notary

# View logs
sudo log stream --predicate 'process == "tacticalagent"' --level debug
```

### 2. Full Build with Signing & Notarization

Complete production build with code signing and notarization:

```bash
# Set up environment
export MACOS_SIGN_CERT="Developer ID Application: Your Name (TEAMID)"

# Build, sign, notarize, and deploy
sudo -E ./bin/macos_build/macos-build_with_test.sh --arch universal

# The -E flag preserves the MACOS_SIGN_CERT environment variable
```

### 3. Build and Install with Tactical RMM

Build and execute full Tactical RMM agent installation:

```bash
# Set up environment
export MACOS_SIGN_CERT="Developer ID Application: Your Name (TEAMID)"

# Build and install with TRMM configuration
sudo -E ./bin/macos_build/macos-build_with_test.sh \
  --arch universal \
  --trmm-mode install \
  --trmm-api https://api.example.com \
  --trmm-client-id 1 \
  --trmm-site-id 1 \
  --trmm-agent-type workstation \
  --trmm-auth <your-auth-token>
```

This will:
1. Build the universal binary
2. Sign the binary
3. Notarize with Apple
4. Deploy to `/opt/tacticalagent/tacticalagent`
5. Execute the installation command:
   ```bash
   /opt/tacticalagent/tacticalagent -m install --api https://api.example.com \
     --client-id 1 --site-id 1 --agent-type workstation --auth <your-auth-token>
   ```

### 4. Quick Redeploy (Skip Build)

Redeploy an existing binary without rebuilding:

```bash
# Deploy existing binary and restart service
sudo ./bin/macos_build/macos-build_with_test.sh --skip-build --skip-sign --skip-notary --service enable
```

### 5. Build Without Deployment

Build binaries for distribution without deploying to local system:

```bash
# Build and sign but don't deploy
sudo -E ./bin/macos_build/macos-build_with_test.sh --arch universal --deploy no

# Binaries are ready at:
# - build/Output/macos/universal/rmmagent
```

### 6. Testing TRMM in Service Mode

Run the agent in service mode without full installation:

```bash
# Build and run in service mode (no installation)
sudo ./bin/macos_build/macos-build_with_test.sh \
  --arch universal \
  --skip-sign --skip-notary \
  --trmm-mode svc \
  --service disable

# Or manually test the binary
/opt/tacticalagent/tacticalagent -m svc
```

### 7. Update and Rebuild

Pull latest changes and rebuild:

```bash
sudo -E ./bin/macos_build/macos-build_with_test.sh --arch universal --git-pull
```

## Troubleshooting

### "Certificate not found" error

Check your certificate is installed:

```bash
security find-identity -v -p codesigning
```

### "Keychain profile not found" error

Setup the notarization profile:

```bash
xcrun notarytool store-credentials "rmmagent-notary" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### LaunchDaemon won't start

Check the plist file exists:

```bash
ls -la /Library/LaunchDaemons/tacticalagent.plist
```

View recent errors:

```bash
sudo log show --predicate 'process == "launchd"' --last 10m | grep tacticalagent
```

### Service keeps crashing

View crash logs:

```bash
sudo log stream --predicate 'process == "tacticalagent"' --level debug
```

Or check Console.app → Crash Reports

## Security Notes

- **Never commit files in `bin/` to git** - they may contain credentials
- The `bin/` directory is gitignored by default
- Certificates are stored in your macOS keychain, not in scripts
- Notarization credentials are stored in keychain via `notarytool`
- Always verify `.gitignore` includes `bin/` before adding any sensitive data

## Additional Resources

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [launchd Documentation](https://www.launchd.info/)
