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
        print(f"  ERR {r.status_code}: {r.text[:2000]}")
    return r

def api_json(method, path, **kw):
    r = api(method, path, **kw)
    try:
        return r, r.json()
    except Exception:
        return r, {}

def require(r, action):
    if r.status_code >= 400:
        print(f"{action} failed")
        sys.exit(1)
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

def find_uploaded_build(expected_build_number=None, attempts=80):
    for i in range(attempts):
        r = require(api("GET", f"/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=20"), "Fetch builds")
        builds = r.json().get("data", [])
        if expected_build_number:
            builds = [
                build for build in builds
                if build.get("attributes", {}).get("version") == expected_build_number
            ]
        if builds:
            build = builds[0]
            state = build.get("attributes", {}).get("processingState")
            build_ver = build.get("attributes", {}).get("version")
            print(f"  Build {build_ver}: {state} ({i+1}/{attempts})")
            if state == "VALID":
                return build
            if state in ["INVALID", "FAILED"]:
                print(f"Build {build_ver} processing failed")
                sys.exit(1)
        else:
            label = expected_build_number or "latest"
            print(f"  Waiting for build {label} to appear ({i+1}/{attempts})")
        time.sleep(30)
    print("Timed out waiting for the uploaded build to become valid")
    sys.exit(1)

def main():
    print("=== SuujiNoHanashi submit ===")
    expected_build_number = os.environ.get("BUILD_NUMBER")
    build = find_uploaded_build(expected_build_number)
    build_id = build["id"]
    build_ver = build["attributes"]["version"]
    print(f"Build: {build_ver} ({build_id})")

    # Get or create version
    r = require(api("GET", f"/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=200"), "Fetch versions")
    versions = [
        version for version in r.json().get("data", [])
        if version.get("attributes", {}).get("versionString") == "1.0"
    ]
    if versions:
        version_id = versions[0]["id"]
        state = versions[0].get("attributes", {}).get("appStoreState")
        print(f"Existing version: {version_id} ({state})")
        if state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            print(f"Already submitted: {state}")
            return
    else:
        r = require(api("POST", "/appStoreVersions", json={"data": {"type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": "1.0"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}), "Create version")
        version_id = r.json()["data"]["id"]
        print(f"Created version: {version_id}")

    # Attach build
    require(api("PATCH", f"/appStoreVersions/{version_id}/relationships/build",
        json={"data": {"type": "builds", "id": build_id}}), "Attach build")

    # Localization
    r = require(api("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations"), "Fetch localization")
    locs = r.json().get("data", [])
    loc_id = locs[0]["id"] if locs else None
    if not loc_id:
        r = require(api("POST", "/appStoreVersionLocalizations", json={"data": {"type": "appStoreVersionLocalizations",
            "attributes": {"locale": "ja", "description": DESC_JA,
                "keywords": KEYWORDS, "marketingUrl": "https://snarfnet.github.io/",
                "supportUrl": "https://snarfnet.github.io/"},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}}), "Create localization")
        loc_id = r.json()["data"]["id"]
    else:
        require(api("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json={"data": {"type": "appStoreVersionLocalizations",
            "id": loc_id, "attributes": {"description": DESC_JA, "keywords": KEYWORDS,
                "marketingUrl": "https://snarfnet.github.io/", "supportUrl": "https://snarfnet.github.io/"}}}), "Update localization")

    ensure_review_detail(version_id)
    cancel_blocking_submissions()

    # Submit for review
    r = require(api("POST", "/reviewSubmissions", json={"data": {"type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}), "Create review submission")
    sub_id = r.json()["data"]["id"]
    require(api("POST", "/reviewSubmissionItems", json={"data": {"type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}}), "Add review item")
    require(api("PATCH", f"/reviewSubmissions/{sub_id}", json={"data": {"type": "reviewSubmissions",
        "id": sub_id, "attributes": {"submitted": True}}}), "Submit review")
    print("Submitted for review!")

def ensure_review_detail(version_id):
    attrs = {
        "contactFirstName": "Tokyo",
        "contactLastName": "Nasu",
        "contactEmail": "tokyonasu@yahoo.co.jp",
        "contactPhone": "+81 80-2368-9194",
        "demoAccountRequired": False,
        "demoAccountName": "",
        "demoAccountPassword": "",
        "notes": (
            "This build addresses the launch crash reported on iPad Air 11-inch running iPadOS 26.5. "
            "Ads remain enabled on iPhone, but the app now checks the hardware model before touching Google Mobile Ads. "
            "On iPad hardware, including iPhone compatibility mode, the app does not start Mobile Ads, create banner views, or request ads. "
            "Ad startup is also delayed until after the first screen is active. "
            "The app now launches directly to the number search screen with no login required."
        ),
    }
    r, body = api_json("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if r.status_code == 200 and body.get("data"):
        detail_id = body["data"]["id"]
        require(api("PATCH", f"/appStoreReviewDetails/{detail_id}", json={
            "data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}
        }), "Update review detail")
        return
    require(api("POST", "/appStoreReviewDetails", json={
        "data": {
            "type": "appStoreReviewDetails",
            "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
        }
    }), "Create review detail")

def cancel_blocking_submissions():
    for state in ("UNRESOLVED_ISSUES", "READY_FOR_REVIEW"):
        r = api("GET", f"/apps/{APP_ID}/reviewSubmissions?filter[state]={state}&limit=200")
        for submission in r.json().get("data", []):
            submission_id = submission["id"]
            r = api("PATCH", f"/reviewSubmissions/{submission_id}", json={
                "data": {
                    "type": "reviewSubmissions",
                    "id": submission_id,
                    "attributes": {"canceled": True},
                }
            })
            if r.status_code < 400:
                print(f"Canceled review submission: {submission_id}")
                time.sleep(10)
            else:
                print(f"Could not cancel review submission: {submission_id}")

DESC_JA = """数字には、知られざる物語が眠っています。

好きな数字を入力して「調べる」をタップするだけ。その数字にまつわるトリビア、数学的な性質、歴史上の出来事を、英語と日本語で表示します。

・トリビア：その数字にまつわる雑学
・数学：数学的な特徴や豆知識
・歴史：その年に起きた出来事

何気なく目にする数字も、調べてみると面白い話が隠れているかもしれません。"""

KEYWORDS = "数字,トリビア,雑学,数学,歴史,豆知識,ナンバー,facts,numbers,trivia"

if __name__ == "__main__":
    main()
