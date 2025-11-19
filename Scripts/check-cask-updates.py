#!/usr/bin/env python3
"""
Check for Homebrew cask updates for installed macOS applications.

Uses osquery to discover installed apps and matches them against Homebrew casks
to identify which apps have updates available.

Strategy:
1. Build cask database: app_name -> cask_token mapping from Homebrew
2. Query osquery for installed apps
3. Look up each app in cask database
4. Compare versions
"""

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Tuple


# Configuration
OSQUERY_BIN = '/opt/tacticalosquery/bin/osqueryi'
MAX_WORKERS = 10


def get_all_cask_tokens() -> List[str]:
    """Get list of all available Homebrew cask tokens."""
    try:
        result = subprocess.run(
            ['brew', 'search', '--cask', '/./'],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            print(f"Error getting cask list: {result.stderr}", file=sys.stderr)
            return []

        # Each line is a cask token
        tokens = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
        return tokens

    except subprocess.TimeoutExpired:
        print("Error: brew search timed out", file=sys.stderr)
        return []
    except Exception as e:
        print(f"Error getting cask tokens: {e}", file=sys.stderr)
        return []


def get_cask_info(token: str) -> Optional[Dict]:
    """Get full cask info as JSON."""
    try:
        result = subprocess.run(
            ['brew', 'info', '--cask', token, '--json=v2'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            data = json.loads(result.stdout)
            if data.get('casks'):
                return data['casks'][0]

    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
        pass

    return None


def extract_app_names_from_cask(cask_data: Dict) -> List[str]:
    """
    Extract app names from cask artifacts.

    Example artifacts:
    [{"app": ["1Password.app"]}, {"zap": [...]}]
    """
    app_names = []

    for artifact in cask_data.get('artifacts', []):
        if isinstance(artifact, dict) and 'app' in artifact:
            # artifact['app'] is a list of app names
            app_names.extend(artifact['app'])

    return app_names


def build_cask_database() -> Dict[str, Dict]:
    """
    Build a mapping of app_name -> cask_data.

    Returns:
        Dictionary mapping app names to their cask data
    """
    print("Getting list of all Homebrew casks...", file=sys.stderr)
    tokens = get_all_cask_tokens()

    if not tokens:
        print("Failed to get cask list", file=sys.stderr)
        return {}

    print(f"Found {len(tokens)} casks", file=sys.stderr)
    print("Building cask database...", file=sys.stderr)

    app_to_cask = {}
    processed = 0

    # Process casks in parallel
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(get_cask_info, token): token for token in tokens}

        for i, future in enumerate(as_completed(futures), 1):
            token = futures[future]
            try:
                cask_data = future.result()
                if cask_data:
                    # Extract app names from artifacts
                    app_names = extract_app_names_from_cask(cask_data)

                    # Map each app name to this cask
                    for app_name in app_names:
                        if app_name not in app_to_cask:
                            # Store full cask data for later use
                            app_to_cask[app_name] = cask_data
                        processed += 1

            except Exception as e:
                print(f"Error processing cask {token}: {e}", file=sys.stderr)

            # Progress indicator every 500 casks
            if i % 500 == 0:
                print(f"  Processed {i}/{len(tokens)} casks...", file=sys.stderr)

    print(f"Built database with {len(app_to_cask)} app mappings", file=sys.stderr)
    return app_to_cask


def get_installed_apps() -> List[Dict]:
    """Query osquery for installed apps in /Applications."""
    query = """
    SELECT name, path, bundle_identifier, bundle_short_version
    FROM apps
    WHERE path LIKE '/Applications/%'
    AND path NOT LIKE '/Applications/%/%'
    ORDER BY name;
    """

    try:
        result = subprocess.run(
            [OSQUERY_BIN, query, '--json'],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            print(f"Error querying osquery: {result.stderr}", file=sys.stderr)
            return []

        return json.loads(result.stdout)

    except subprocess.TimeoutExpired:
        print("Error: osquery query timed out", file=sys.stderr)
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing osquery JSON: {e}", file=sys.stderr)
        return []
    except FileNotFoundError:
        print(f"Error: osquery not found at {OSQUERY_BIN}", file=sys.stderr)
        return []


def compare_versions(installed: str, available: str) -> Optional[bool]:
    """
    Compare version strings.

    Returns:
        True if update available (installed < available)
        False if up-to-date or installed > available
        None if comparison failed
    """
    if not installed or not available:
        return None

    # Clean version strings (remove build info like "2.5.1 release (770)")
    installed_clean = installed.split()[0] if ' ' in installed else installed
    available_clean = available.split()[0] if ' ' in available else available

    def parse_version(v: str) -> List:
        """Parse version string into comparable components."""
        parts = []
        for part in v.split('.'):
            try:
                parts.append(int(part))
            except ValueError:
                # Keep non-numeric parts as strings
                parts.append(part)
        return parts

    try:
        v1 = parse_version(installed_clean)
        v2 = parse_version(available_clean)

        # Pad shorter version with zeros
        max_len = max(len(v1), len(v2))
        v1 += [0] * (max_len - len(v1))
        v2 += [0] * (max_len - len(v2))

        return v1 < v2

    except Exception:
        return None


def match_apps_to_casks(apps: List[Dict], cask_db: Dict[str, Dict]) -> List[Dict]:
    """
    Match installed apps to casks using the cask database.

    Returns:
        List of matched app/cask records
    """
    results = []

    for app in apps:
        app_name = app['name']

        # Look up in cask database
        cask_data = cask_db.get(app_name)

        if not cask_data:
            continue

        installed_version = app.get('bundle_short_version', '')
        available_version = cask_data.get('version', '')
        update_available = compare_versions(installed_version, available_version)

        results.append({
            'app_name': app_name,
            'bundle_id': app.get('bundle_identifier', ''),
            'installed_version': installed_version,
            'cask_token': cask_data.get('token', ''),
            'cask_version': available_version,
            'update_available': update_available,
            'cask_installed': bool(cask_data.get('installed')),
            'outdated': cask_data.get('outdated', False)
        })

    return results


def main():
    """Main execution."""
    # Step 1: Build cask database
    cask_db = build_cask_database()

    if not cask_db:
        print("Failed to build cask database", file=sys.stderr)
        return 1

    # Step 2: Query osquery for installed apps
    print("\nQuerying osquery for installed apps...", file=sys.stderr)
    apps = get_installed_apps()

    if not apps:
        print("No apps found or query failed", file=sys.stderr)
        return 1

    print(f"Found {len(apps)} apps in /Applications", file=sys.stderr)

    # Step 3: Match apps to casks
    print("Matching apps to casks...", file=sys.stderr)
    results = match_apps_to_casks(apps, cask_db)

    print(f"\nMatched {len(results)} apps to Homebrew casks", file=sys.stderr)

    # Count updates available
    updates_available = sum(1 for r in results if r.get('update_available') is True)
    if updates_available:
        print(f"Found {updates_available} apps with updates available", file=sys.stderr)

    print("\n---\n", file=sys.stderr)

    # Output JSON results
    print(json.dumps(results, indent=2))

    return 0


if __name__ == '__main__':
    sys.exit(main())
