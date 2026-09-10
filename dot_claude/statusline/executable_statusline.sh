#!/usr/bin/env bash
# Claude Code statusline: context window + 5h/7d rate limits + cost.
# Reads the session JSON on stdin (see https://code.claude.com/docs/en/statusline).
# One jq call, no network, no subshell loops -- runs in a few ms.

IFS=$'\x1f' read -r MODEL CWD CTX FIVE_P FIVE_R WEEK_P WEEK_R COST < <(
  jq -r '
    # Two ways to lose column alignment, both of which shift every later field
    # left: "// empty" DROPS the slot, so absent values become empty strings;
    # and tab is an IFS whitespace char that bash read would collapse in runs,
    # so the fields are joined with US (\x1f) instead of @tsv.
    def int: if type == "number" then floor | tostring else "" end;
    def str: if . == null then "" else tostring end;
    [ (.model.display_name // "?"),
      (.workspace.current_dir // .cwd // ""),
      (.context_window.used_percentage        | int),
      (.rate_limits.five_hour.used_percentage | int),
      (.rate_limits.five_hour.resets_at       | str),
      (.rate_limits.seven_day.used_percentage | int),
      (.rate_limits.seven_day.resets_at       | str),
      (.cost.total_cost_usd                   | str)
    ] | join("\u001f")'
)

R=$'\e[0m'; DIM=$'\e[2m'; SEP="${DIM} · ${R}"

# Green under 50%, yellow under 80%, red at or above.
hue() { if   (( $1 < 50 )); then printf '\e[32m'
        elif (( $1 < 80 )); then printf '\e[33m'
        else                     printf '\e[31m'; fi; }

# 5-cell bar, filled proportionally to the percentage.
bar() {
  local f=$(( ($1 * 5 + 99) / 100 )); (( f > 5 )) && f=5
  printf '%s' "$(hue "$1")"
  local i; for ((i=0;i<5;i++)); do (( i < f )) && printf '▓' || printf "${DIM}░$(hue "$1")"; done
  printf "%s" "$R"
}

# Unix epoch -> compact countdown ("2d3h", "1h20m", "45m", "<1m").
until_ts() {
  local s=$(( $1 - $(printf '%(%s)T' -1) ))
  (( s <= 0 )) && { printf '<1m'; return; }
  if   (( s >= 86400 )); then printf '%dd%dh' $((s/86400)) $((s%86400/3600))
  elif (( s >= 3600  )); then printf '%dh%dm' $((s/3600))  $((s%3600/60))
  else                        printf '%dm'    $((s/60)); fi
}

# Reset countdown, only for a well-formed epoch.
fmt_reset() { [[ $1 =~ ^[0-9]+$ ]] && printf " ${DIM}↻%s${R}" "$(until_ts "$1")"; }

# A metric renders only when Claude Code actually sent it: rate_limits is
# Pro/Max only, arrives after the first API response, and each window is
# dropped once it resets.
out="\e[1m${MODEL}${R}"

[[ -n $CWD ]] && out+="${SEP}${DIM}${CWD/#$HOME/\~}${R}"

# Branch straight from .git/HEAD -- no `git` subprocess.
d=$CWD; while [[ -n $d && $d != / ]]; do
  if [[ -r $d/.git/HEAD ]]; then
    h=$(<"$d/.git/HEAD"); out+="${SEP}\e[35m${h#ref: refs/heads/}${R}"; break
  fi
  d=${d%/*}
done

[[ $CTX =~ ^[0-9]+$ ]] && out+="${SEP}ctx $(bar "$CTX") $(hue "$CTX")${CTX}%${R}"
[[ $FIVE_P =~ ^[0-9]+$ ]] && out+="${SEP}5h $(bar "$FIVE_P") $(hue "$FIVE_P")${FIVE_P}%${R}$(fmt_reset "$FIVE_R")"
[[ $WEEK_P =~ ^[0-9]+$ ]] && out+="${SEP}7d $(bar "$WEEK_P") $(hue "$WEEK_P")${WEEK_P}%${R}$(fmt_reset "$WEEK_R")"
[[ $COST =~ ^[0-9.]+$ ]] && out+="${SEP}${DIM}\$$(printf '%.2f' "$COST")${R}"

printf '%b' "$out"
