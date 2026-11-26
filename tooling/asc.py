#!/usr/bin/env python3
"""Minimal App Store Connect API client for publishing Slide.

Credentials come from 1Password (never stored in the repo):
    op run --env-file=.env.1password -- python3 tooling/asc.py get "/v1/apps?filter[bundleId]=ch.geneve.slide.ski"
    op run --env-file=.env.1password -- python3 tooling/asc.py patch /v1/appInfoLocalizations/ID < body.json

Needs PyJWT and cryptography (ES256 token, valid 20 minutes, as Apple requires).
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    now = int(time.time())
    key = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"].replace("\\n", "\n")
    return jwt.encode(
        {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["APP_STORE_CONNECT_KEY_ID"], "typ": "JWT"},
    )


def call(method: str, path: str, body: dict | None = None, raw: bytes | None = None, headers: dict | None = None) -> dict:
    url = path if path.startswith("http") else API + path
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(url, data=data, method=method)
    if not url.startswith(API):  # pre-signed upload URLs (screenshots) take no token
        for name, value in (headers or {}).items():
            request.add_header(name, value)
    else:
        request.add_header("Authorization", f"Bearer {token()}")
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            text = response.read().decode() or "{}"
            return json.loads(text) if text.strip().startswith(("{", "[")) else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit(f"{method} {path} → {error.code}\n{detail}") from None


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    method, path = sys.argv[1].upper(), sys.argv[2]
    body = json.load(sys.stdin) if method in ("POST", "PATCH") else None
    print(json.dumps(call(method, path, body), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
