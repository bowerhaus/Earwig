#!/usr/bin/env bash
# Archive Earwig and upload it to TestFlight (plan 012, decisions 8 and 9).
#
# Run from anywhere in the repo, on a clean tree:
#   scripts/release/testflight.sh             bump the build, archive, upload, commit, tag
#   scripts/release/testflight.sh --dry-run   the same checks, bump and archive, with no upload;
#                                             project.yml is put back afterwards
#
# The App Store Connect key is read from the macOS Keychain, service bowerhaus.appstoreconnect,
# accounts key-id, issuer-id and key-p8 (the .p8 in base64). If an item is missing the script
# prints the commands that store them, to run once in your own terminal. The key is a team key
# with the Admin role, which cloud-managed distribution signing needs. Never print a value.
#
# Steps:
#   1. Refuse a dirty working tree, a missing Keychain item or a build number already tagged.
#   2. Bump CURRENT_PROJECT_VERSION in project.yml and run xcodegen generate (the project is
#      git-ignored, so it is made fresh and cannot be stale).
#   3. Archive the Release build. -allowProvisioningUpdates with the key lets Xcode use
#      cloud-managed distribution signing, so the Mac needs no distribution certificate.
#   4. Export with ExportOptions.plist, which uploads to App Store Connect.
#   5. Commit project.yml and tag the commit testflight/<version>-<build>. Pushing is separate.
#
# A failure anywhere puts project.yml back, so it leaves no commit and no bumped number.
# Fallback: Product › Archive in Xcode, then Distribute App › TestFlight in the Organizer.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

dry_run=false
case "${1:-}" in
    "") ;;
    --dry-run) dry_run=true ;;
    *) echo "Usage: scripts/release/testflight.sh [--dry-run]" >&2; exit 2 ;;
esac

service=bowerhaus.appstoreconnect

if [[ -n "$(git status --porcelain)" ]]; then
    echo "The working tree has uncommitted changes. Commit or stash them first." >&2
    exit 1
fi

# The value of one Keychain item, or nothing if it is missing.
keychain_item() {
    security find-generic-password -s "$service" -a "$1" -w 2>/dev/null || true
}

key_id=""
issuer_id=""
key_p8=""
if ! $dry_run; then
    key_id=$(keychain_item key-id)
    issuer_id=$(keychain_item issuer-id)
    key_p8=$(keychain_item key-p8)
    if [[ -z "$key_id" || -z "$issuer_id" || -z "$key_p8" ]]; then
        cat >&2 <<HELP
The App Store Connect key is not in the Keychain (service $service).
Store it once, in your own terminal, with your key's values:

  security add-generic-password -U -s $service -a key-id -w '<KEY_ID>'
  security add-generic-password -U -s $service -a issuer-id -w '<ISSUER_ID>'
  security add-generic-password -U -s $service -a key-p8 -w "\$(base64 -i <path to AuthKey_KEY_ID.p8>)"

Then run this script again.
HELP
        exit 1
    fi
fi

version=$(sed -nE 's/^ *MARKETING_VERSION: *"?([^"]+)"?$/\1/p' project.yml)
current=$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: *"?([0-9]+)"?$/\1/p' project.yml)
[[ -n "$version" && -n "$current" ]] || { echo "Could not read the version and build from project.yml" >&2; exit 1; }
build=$((current + 1))

tag="testflight/$version-$build"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "$tag is already tagged. Set CURRENT_PROJECT_VERSION in project.yml past it." >&2
    exit 1
fi

branch=$(git branch --show-current)
echo "Earwig $version ($build) from ${branch:-a detached HEAD}$($dry_run && echo ", dry run: no upload")"

succeeded=false
keydir=""
cleanup() {
    [[ -n "$keydir" ]] && rm -rf "$keydir"
    if ! $succeeded; then
        git checkout -- project.yml
        xcodegen generate --quiet >/dev/null 2>&1 || true
        $dry_run || echo "Not uploaded. project.yml is as it was." >&2
    fi
}
trap cleanup EXIT

sed -i '' -E "s/^( *CURRENT_PROJECT_VERSION: *)\"?[0-9]+\"?$/\1\"$build\"/" project.yml
grep -q "CURRENT_PROJECT_VERSION: \"$build\"" project.yml || { echo "Could not bump the build in project.yml" >&2; exit 1; }
xcodegen generate --quiet

auth=(-allowProvisioningUpdates)
if ! $dry_run; then
    umask 077
    keydir=$(mktemp -d)
    keypath="$keydir/AuthKey_$key_id.p8"
    printf '%s' "$key_p8" | base64 -D > "$keypath"
    unset key_p8
    auth+=(-authenticationKeyPath "$keypath" -authenticationKeyID "$key_id" -authenticationKeyIssuerID "$issuer_id")
fi

archive=build/Earwig.xcarchive
rm -rf "$archive" build/export

echo "Archiving Earwig $version ($build)"
xcodebuild archive \
    -scheme Earwig \
    -destination 'generic/platform=iOS' \
    -configuration Release \
    -archivePath "$archive" \
    -quiet \
    "${auth[@]}"

if $dry_run; then
    echo "Dry run: archived $archive. Nothing uploaded; project.yml goes back to build $current."
    exit 0
fi

echo "Uploading Earwig $version ($build) to App Store Connect"
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist scripts/release/ExportOptions.plist \
    -exportPath build/export \
    "${auth[@]}"

git commit -q -m "TestFlight $version ($build)" -- project.yml
git tag "$tag"
succeeded=true
echo "Uploaded, committed and tagged $tag. Push with: git push origin HEAD $tag"
echo "The build appears in TestFlight once App Store Connect has processed it."
