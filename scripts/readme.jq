# Renders README.md from the slurped stars.jsonl (newest star first).
# Usage: jq -rsf scripts/readme.jq --arg user <username> stars.jsonl > README.md

# Make text safe for a single Markdown table cell
def cell:
  (. // "")
  | gsub("^\\s+|\\s+$"; "")
  | gsub("\\s*[\\r\\n]+\\s*"; " ")
  | gsub("<"; "&lt;")
  | gsub(">"; "&gt;")
  | gsub("\\|"; "\\|");

# GitHub heading anchors: lowercase, strip punctuation, spaces to hyphens, dedupe with -1, -2...
def slugs:
  reduce .[] as $heading ({seen: {}, out: []};
    ($heading | ascii_downcase | gsub("[^\\p{L}\\p{N} _-]"; "") | gsub(" "; "-")) as $slug
    | .out += [if .seen[$slug] then "\($slug)-\(.seen[$slug])" else $slug end]
    | .seen[$slug] += 1)
  | .out;

def repo: "[\(.owner)/\(.name)](\(.url))";

map(.language //= "Other") as $repos
| ($repos | group_by(.language) | sort_by(.[0].language | [. == "Other", ascii_downcase])) as $groups
| ($groups | map(.[0].language)) as $languages
| ([$languages, ($languages | slugs)] | transpose | map({key: .[0], value: .[1]}) | from_entries) as $anchor
| def language: "[\(.language)](#\($anchor[.language]))";
  [
    "# Awesome Stars [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)",
    "",
    "> My GitHub stars, grouped by language. Updated daily by [a GitHub Actions workflow](.github/workflows/workflow.yml).",
    "",
    "![Total](https://img.shields.io/badge/Total-\($repos | length)-green.svg)",
    "![Updated](https://img.shields.io/badge/Updated-\(now | strftime("%Y--%m--%d"))-blue.svg)",
    "",
    "## Contents",
    "",
    "- [Recently starred](#recently-starred)",
    "- Languages: \($groups | map("\(.[0] | language) (\(length))") | join(" · "))",
    "",
    "## Recently starred",
    "",
    "| Repository | Description | Language |",
    "| --- | --- | --- |",
    ($repos[:10][] | "| \(repo) | \(.description | cell) | \(language) |"),
    ($groups[] |
      "",
      "## \(.[0].language)",
      "",
      "| Repository | Description |",
      "| --- | --- |",
      (.[] | "| \(repo) | \(.description | cell) |"),
      "",
      "[⬆ Back to contents](#contents)"
    ),
    "",
    "## License",
    "",
    "To the extent possible under law, [\($user)](https://github.com/\($user)) has waived all copyright and related or neighboring rights to this work."
  ]
| join("\n")
