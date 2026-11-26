#!/usr/bin/env bash
set -euo pipefail

checker="$(cd -- "$(dirname -- "$0")" && pwd)/check.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/radish-asset-fixture.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
cd "$fixture"
git -c init.defaultBranch=main init --quiet
git config --local user.name 'Repository asset fixture'
git config --local user.email 'asset-fixture@example.invalid'
git config --local core.hooksPath /dev/null
printf 'base\n' > README.md
mkdir -p output/playwright .radish-assets
printf 'grandfathered\n' > output/playwright/old.log
git add README.md output/playwright/old.log
git commit --quiet -m 'fixture baseline'
base=$(git rev-parse HEAD)
printf 'version\t1.0.0\nbaseline\t%s\n' "$base" > .radish-assets/policy.tsv

fail_with() {
  local expected=$1 rc=0
  shift
  bash "$checker" "$@" > result.txt 2>&1 || rc=$?
  [[ "$rc" == 1 ]] || { cat result.txt; return 1; }
  grep -F -- "$expected" result.txt >/dev/null
}

unstage() {
  git rm --cached --force --quiet -- "$@"
}

printf 'new log\n' > output/playwright/new.log
git add output/playwright/new.log
fail_with 'Blocked path or artifact type' --staged
unstage output/playwright/new.log

dd if=/dev/zero of='large content' bs=1048576 count=5 2>/dev/null
git add 'large content'
bash "$checker" --staged
printf '\0' >> 'large content'
git add 'large content'
printf 'small working copy\n' > 'large content'
fail_with 'Binary needs an exception' --staged
unstage 'large content'

printf 'small archive\n' > source.zip
git add source.zip
fail_with 'Blocked path or artifact type' --staged
if command -v sha256sum >/dev/null 2>&1; then
  hash=$(sha256sum source.zip | cut -d ' ' -f1)
else
  hash=$(shasum -a 256 source.zip | cut -d ' ' -f1)
fi
printf 'allow\tsource.zip\t100\t%s\tarchive needed for fixture\tfixture source\n' "$hash" >> .radish-assets/policy.tsv
bash "$checker" --staged
printf 'different bytes\n' >> source.zip
git add source.zip
fail_with 'Blocked path or artifact type' --staged
unstage source.zip

dd if=/dev/zero of=first.png bs=1048576 count=4 2>/dev/null
cp first.png copied.png
printf 'different\n' > second.png
cat first.png >> second.png
git add first.png copied.png second.png
bash "$checker" --staged > result.txt 2>&1
! grep -F '10 MiB review threshold' result.txt
printf 'third\n' > third.png
cat first.png >> third.png
git add third.png
bash "$checker" --staged > result.txt 2>&1
grep -F '10 MiB review threshold' result.txt >/dev/null
unstage first.png copied.png second.png third.png

dd if=/dev/zero of=transient.otf bs=1048576 count=6 2>/dev/null
git add transient.otf
git commit --quiet -m 'add transient binary'
git rm --quiet transient.otf
git commit --quiet -m 'remove transient binary'
fail_with 'transient.otf' --range "$base" HEAD
head=$(git rev-parse HEAD)
fail_with 'transient.otf' --range "$(printf '%040d' 0)" "$head"
printf 'refs/heads/main %s refs/heads/main %s\n' "$head" "$base" |
  fail_with 'transient.otf' --pre-push
printf 'refs/heads/main %s refs/heads/main %040d\n' "$head" 0 |
  fail_with 'transient.otf' --pre-push
bash "$checker" --range "$base" "$base"
printf '%s\n' 'Repository asset checker regression cases passed.'
