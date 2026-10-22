#!/bin/sh
# check.sh — one look at /health. state.json holds { misses, down, since } and nothing else. Prints only "ok",
# "miss N", "texted down" or "texted back": never a URL's body, never a secret.
set -u
STATE=state.json
[ -f "$STATE" ] || echo '{"misses":0,"down":false,"since":null}' > "$STATE"
misses=$(jq -r '.misses' "$STATE"); down=$(jq -r '.down' "$STATE"); since=$(jq -r '.since' "$STATE")
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

body=$(curl -s -m 20 -w '\n%{http_code}' "$URL" 2>/dev/null || true)
code=$(printf '%s' "$body" | tail -n1)
healthy=false
if [ "$code" = "200" ] && printf '%s' "$body" | sed '$d' | jq -e '.ok == true' >/dev/null 2>&1; then healthy=true; fi

# His time, the way he reads it (his 4:09 PM, Oct 22): Pacific, "4:05 PM". The state keeps UTC.
local_time() { TZ=America/Vancouver date -d "$1" +'%-I:%M %p' 2>/dev/null || echo "$1"; }

text() {   # one SMS through the existing Twilio account; the response is discarded, never printed
  curl -s -o /dev/null -w '%{http_code}' -X POST "https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json" \
    -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}" --data-urlencode "From=${WATCH_FROM}" --data-urlencode "To=${WATCH_TO}" \
    --data-urlencode "Body=$1"
}

if [ "$healthy" = true ]; then
  echo "ok at $(local_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
  if [ "$down" = true ]; then
    sent=$(text "Perri is back, $(local_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)").")
    echo "texted back (${sent})"
  fi
  echo '{"misses":0,"down":false,"since":null}' > "$STATE"
else
  misses=$((misses + 1)); [ "$since" = "null" ] && since="$now"
  echo "miss ${misses}"
  if [ "$misses" -ge 2 ] && [ "$down" != true ]; then
    sent=$(text "Perri is down since $(local_time "${since}"). Two checks failed.")
    echo "texted down (${sent})"
    down=true
  fi
  printf '{"misses":%s,"down":%s,"since":"%s"}\n' "$misses" "$down" "$since" > "$STATE"
fi

# GitHub disables a public repo's schedule after 60 days without a commit: one line a day keeps it alive.
today=$(date -u +%Y-%m-%d)
[ "$(cat heartbeat.txt 2>/dev/null)" = "$today" ] || echo "$today" > heartbeat.txt
