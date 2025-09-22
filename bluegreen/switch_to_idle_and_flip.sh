DOMAIN="hello.d1ko4.com"       # <-- set your domain here
NPM_API_BASE="http://127.0.0.1:81/api"

# Load credentials from env or ~/.npm_creds
if [[ -z "${NPM_USER:-}" || -z "${NPM_PASS:-}" ]]; then
  CRED_FILE="${HOME}/.npm_creds"
  if [[ -f "$CRED_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CRED_FILE"
  fi
fi
if [[ -z "${NPM_USER:-}" || -z "${NPM_PASS:-}" ]]; then
  echo "ERROR: set NPM_USER/NPM_PASS env or create ~/.npm_creds with them."
  exit 2
fi

ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "blue")
if [[ "$ACTIVE" == "blue" ]]; then
  NEW_ACTIVE="green"
else
  NEW_ACTIVE="blue"
fi
echo "Switching ${DOMAIN} to hello-${NEW_ACTIVE}:80 ..."

# token
TOKEN_JSON=$(curl -sS -X POST -H 'Content-Type: application/json' \
  -d "{\"identity\":\"${NPM_USER}\",\"secret\":\"${NPM_PASS}\"}" \
  "${NPM_API_BASE}/tokens")
TOKEN=$(echo "$TOKEN_JSON" | jq -r .token)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "ERROR getting token:"
  echo "$TOKEN_JSON"
  exit 3
fi

# find proxy host id by domain
PH_JSON=$(curl -sS -H "Authorization: Bearer $TOKEN" "${NPM_API_BASE}/nginx/proxy-hosts")
PHID=$(echo "$PH_JSON" | jq -r --arg domain "$DOMAIN" '.[] | select(.domain_names[] == $domain) | .id')
if [[ -z "$PHID" || "$PHID" == "null" ]]; then
  echo "ERROR: Proxy Host for ${DOMAIN} not found."
  exit 4
fi

# update upstream
PAYLOAD=$(jq -n --arg fh "hello-${NEW_ACTIVE}" --argjson fp 80 '{forward_host:$fh, forward_port:$fp}')
curl -sS -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${NPM_API_BASE}/nginx/proxy-hosts/${PHID}" >/dev/null

# flip ACTIVE
echo "$NEW_ACTIVE" > "$ACTIVE_FILE"
echo "✅ Switched to hello-${NEW_ACTIVE} and flipped ACTIVE."
