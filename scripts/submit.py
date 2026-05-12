#!/usr/bin/env python3
"""ASC submission script for SuujiNoHanashi."""
import os, sys, time, json, hashlib, base64, hmac, struct
from pathlib import Path

try:
    import jwt
    import requests
except ImportError:
    os.system("pip install PyJWT cryptography requests")
    import jwt, requests

KEY_ID     = os.environ["ASC_KEY_ID"]
ISSUER_ID  = os.environ["ASC_ISSUER_ID"]
PRIVATE_KEY= os.environ["ASC_PRIVATE_KEY"]
APP_ID     = "6768641431"

BASE = "https://api.appstoreconnect.apple.com"

def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER_ID, "iat": now, "exp": now+1200,
                        "aud": "appstoreconnect-v1"},
                       PRIVATE_KEY, algorithm="ES256",
                       headers={"kid": KEY_ID, "typ": "JWT"})

def api(method, path, **kw):
    r = requests.request(method, BASE+"/v1"+path,
                          headers={"Authorization": f"Bearer {token()}",
                                   "Content-Type": "application/json"}, **kw)
    if r.status_code >= 400:
        print(f"  ERR {r.status_code}: {r.text[:300]}")
    return r

def wait_build(build_id, attempts=80):
    for i in range(attempts):
        r = api("GET", f"/builds/{build_id}")
        state = r.json()["data"]["attributes"]["processingState"]
        print(f"  Build state: {state} ({i+1}/{attempts})")
        if state == "VALID": return True
        if state in ["INVALID","FAILED"]: return False
        time.sleep(30)
    return False

def main():
    print("=== SuujiNoHanashi submit ===")
    # Get latest build
    r = api("GET", f"/apps/{APP_ID}/builds?limit=1&sort=-uploadedDate&filter[processingState]=VALID,PROCESSING")
    builds = r.json().get("data", [])
    if not builds:
        print("No builds found"); sys.exit(1)
    build_id = builds[0]["id"]
    build_ver = builds[0]["attributes"]["version"]
    print(f"Build: {build_ver} ({build_id})")

    if builds[0]["attributes"]["processingState"] != "VALID":
        if not wait_build(build_id):
            print("Build not valid"); sys.exit(1)

    # Get or create version
    r = api("GET", f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&filter[appStoreState]=PREPARE_FOR_SUBMISSION,READY_FOR_REVIEW,DEVELOPER_REJECTED")
    versions = r.json().get("data", [])
    if versions:
        version_id = versions[0]["id"]
        print(f"Existing version: {version_id}")
    else:
        r = api("POST", "/appStoreVersions", json={"data": {"type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": "1.0"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
        version_id = r.json()["data"]["id"]
        print(f"Created version: {version_id}")

    # Attach build
    api("PATCH", f"/appStoreVersions/{version_id}/relationships/build",
        json={"data": {"type": "builds", "id": build_id}})

    # Localization
    r = api("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    locs = r.json().get("data", [])
    loc_id = locs[0]["id"] if locs else None
    if not loc_id:
        r = api("POST", "/appStoreVersionLocalizations", json={"data": {"type": "appStoreVersionLocalizations",
            "attributes": {"locale": "ja", "description": DESC_JA,
                "keywords": KEYWORDS, "marketingUrl": "https://snarfnet.github.io/",
                "supportUrl": "https://snarfnet.github.io/"},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        loc_id = r.json()["data"]["id"]
    else:
        api("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json={"data": {"type": "appStoreVersionLocalizations",
            "id": loc_id, "attributes": {"description": DESC_JA, "keywords": KEYWORDS,
                "marketingUrl": "https://snarfnet.github.io/", "supportUrl": "https://snarfnet.github.io/"}}})

    # Submit for review
    r = api("POST", "/reviewSubmissions", json={"data": {"type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    sub_id = r.json()["data"]["id"]
    api("POST", "/reviewSubmissionItems", json={"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    api("PATCH", f"/reviewSubmissions/{sub_id}", json={"data": {"type": "reviewSubmissions",
        "id": sub_id, "attributes": {"submitted": True}}})
    print("Submitted for review!")

DESC_JA = """数字には、知られざる物語が眠っている。

好きな数字を入力して「調べる」をタップするだけ。その数字にまつわるトリビア、数学的な秘密、歴史上の出来事が、英語と日本語で表示されます。

• トリビア：その数字にまつわる雑学
• 数学：数学的な特性や法則
• 歴史：その年に起きた出来事

何気なく目にする数字も、調べてみると面白い話が隠れているかもしれません。"""

KEYWORDS = "数字,トリビア,雑学,数学,歴史,豆知識,ナンバー,facts,numbers,trivia"

if __name__ == "__main__":
    main()
