#!/usr/bin/env bash
# Fetches the GitHub stars of a user into stars.jsonl and renders README.md from it.
# Usage: scripts/update.sh [username]   (needs gh and jq)
# Re-render from the cached stars.jsonl only: jq -rsf scripts/readme.jq --arg user <username> stars.jsonl > README.md
set -euo pipefail
cd "$(dirname "$0")/.."

user="${1:-${GITHUB_REPOSITORY_OWNER:?pass a username}}"

gh api graphql --paginate -f user="$user" -f query='
  query($user: String!, $endCursor: String) {
    user(login: $user) {
      starredRepositories(first: 100, after: $endCursor, orderBy: {field: STARRED_AT, direction: DESC}) {
        pageInfo { hasNextPage endCursor }
        nodes { name url description stargazerCount owner { login } primaryLanguage { name } }
      }
    }
  }' --jq '.data.user.starredRepositories.nodes[]' |
  jq -c '{name, owner: .owner.login, url, description, language: .primaryLanguage.name, stars: .stargazerCount}' > stars.jsonl

jq -rsf scripts/readme.jq --arg user "$user" stars.jsonl > README.md
echo "Wrote README.md with $(wc -l < stars.jsonl | tr -d ' ') stars for $user"
