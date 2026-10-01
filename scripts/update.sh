#!/usr/bin/env bash
# Updates stars.jsonl with the GitHub stars of a user and renders README.md from it.
# Incremental: only fetches stars newer than the cache, so descriptions and languages of
# older entries stay as cached. Refetches everything when there is no cache or when stars
# were removed (delete stars.jsonl to force it).
# Usage: scripts/update.sh [username]   (needs gh and jq)
# Re-render from the cached stars.jsonl only: jq -rsf scripts/readme.jq --arg user <username> stars.jsonl > README.md
set -euo pipefail
cd "$(dirname "$0")/.."

full=false
user="${1:-${GITHUB_REPOSITORY_OWNER:?pass a username}}"
cache=stars.jsonl
[[ -s $cache ]] || full=true

new=$(mktemp)
merged=$(mktemp)
trap 'rm -f "$new" "$merged"' EXIT

query='
  query($user: String!, $after: String) {
    user(login: $user) {
      starredRepositories(first: 100, after: $after, orderBy: {field: STARRED_AT, direction: DESC}) {
        totalCount
        pageInfo { hasNextPage endCursor }
        edges { starredAt node { id name url description owner { login } primaryLanguage { name } } }
      }
    }
  }'

# Writes to $new the stars newer than the first one also found in $1 (newest first), sets $total
fetch() {
  local known=$1 after=null page
  : > "$new"
  while :; do
    page=$(gh api graphql -f user="$user" -f query="$query" -F after="$after" --jq '.data.user.starredRepositories' |
      jq -c --slurpfile known "$known" '
        ($known | map({key: "\(.id) \(.starredAt)", value: true}) | from_entries) as $seen
        | [.edges[] | {id: .node.id, starredAt, name: .node.name, owner: .node.owner.login, url: .node.url,
            description: .node.description, language: .node.primaryLanguage.name}] as $rows
        | ($rows | map($seen["\(.id) \(.starredAt)"] // false) | index(true)) as $stop
        | {rows: $rows[:$stop // ($rows | length)], done: ($stop != null or (.pageInfo.hasNextPage | not)),
           after: .pageInfo.endCursor, total: .totalCount}')
    jq -c '.rows[]' <<< "$page" >> "$new"
    total=$(jq '.total' <<< "$page")
    [[ $(jq '.done' <<< "$page") == true ]] && break
    after=$(jq -r '.after' <<< "$page")
  done
}

if ! $full; then
  fetch "$cache"
  { cat "$new"; jq -c --slurpfile new "$new" '($new | map(.id)) as $ids | select(.id | IN($ids[]) | not)' "$cache"; } > "$merged"
  if (( $(wc -l < "$merged") != total )); then
    echo "Cache is out of sync with GitHub, refetching all stars"
    full=true
  fi
fi
if $full; then
  fetch /dev/null
  cp "$new" "$merged"
fi

if [[ -f README.md ]] && cmp -s "$merged" "$cache"; then
  echo "No changes for $user"
  exit 0
fi

cp "$merged" "$cache"
jq -rsf scripts/readme.jq --arg user "$user" "$cache" > README.md
echo "Wrote README.md with $total stars for $user"
