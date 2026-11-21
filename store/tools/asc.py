"""Küçük App Store Connect API yardımcısı (JWT ile).
Kullanım: python asc.py GET /v1/apps

Kimlik (repoya girmez), sırasıyla:
    ASC_KEY_ID / ASC_ISSUER_ID ortam değişkenleri
    ~/stridefree-keys/appstore.json  →  {"key_id": "...", "issuer_id": "..."}
Anahtar dosyası ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 konumunda olmalı."""
import json, os, sys, time, urllib.request, urllib.error
import jwt

_CFG = os.path.expanduser("~/stridefree-keys/appstore.json")
_cfg = json.load(open(_CFG)) if os.path.exists(_CFG) else {}
KEY_ID = os.environ.get("ASC_KEY_ID") or _cfg.get("key_id")
ISSUER = os.environ.get("ASC_ISSUER_ID") or _cfg.get("issuer_id")
if not KEY_ID or not ISSUER:
    sys.exit(f"✗ App Store Connect kimliği yok: ASC_KEY_ID/ASC_ISSUER_ID ya da {_CFG}")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      open(KEY_PATH).read(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None):
    url = path if path.startswith("http") else "https://api.appstoreconnect.apple.com" + path
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else {})


if __name__ == "__main__":
    m, p = sys.argv[1], sys.argv[2]
    b = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    st, js = call(m, p, b)
    print(st)
    print(json.dumps(js, indent=1, ensure_ascii=False)[:6000])
