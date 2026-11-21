"""iOS derlemesini App Store Connect'e yükler ve App Store sürümünü hazırlar (play_upload.py'nin iOS karşılığı).

Kullanım (yalnızca macOS + Xcode):
    python3 store/tools/appstore_upload.py --build            # derle, yükle, sürümü hazırla (gönderme)
    python3 store/tools/appstore_upload.py --build --commit   # ... ve Apple incelemesine gönder
    python3 store/tools/appstore_upload.py --commit           # zaten yüklü derlemeyi kullan, sadece gönder

Ne yapar:
  1. --build: flutter build ios + xcodebuild archive + App Store Connect'e yükleme
     (imzalama otomatik, API anahtarıyla; Xcode'da oturum açmak gerekmez)
  2. pubspec.yaml'daki sürüm/derleme numarasının Apple'da işlenmesini bekler (TestFlight'a da düşer)
  3. App Store sürümünü bulur ya da oluşturur, "Bu sürümdeki yenilikler" metnini
     store/release-notes/<sürüm>/<dil>.txt dosyalarından doldurur ve derlemeyi bağlar
  4. --commit: incelemeye gönderir (onaylanınca otomatik yayınlanır)
--commit olmadan hiçbir şey incelemeye gitmez.

Kimlik: asc.py ile aynı (ASC_KEY_ID/ASC_ISSUER_ID ya da ~/stridefree-keys/appstore.json,
anahtar ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8).
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
APP_ID = "6836717829"
TEAM_ID = "TALS74XL8C"
ARCHIVE = ROOT / "build/StrideFree.xcarchive"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
IN_FLIGHT = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE",
             "PROCESSING_FOR_APP_STORE"}


def die(msg):
    sys.exit(f"✗ {msg}")


def call(method, path, body=None, what=""):
    st, js = asc.call(method, path, body)
    if st >= 300:
        errs = js.get("errors", [{}])
        detail = "; ".join(e.get("detail") or e.get("title", "") for e in errs)
        die(f"{what or path}: HTTP {st} {detail}")
    return js


def pubspec_version():
    m = re.search(r"^version:\s*([\d.]+)\+(\d+)", (ROOT / "pubspec.yaml").read_text(), re.M)
    if not m:
        die("pubspec.yaml'da 'version: x.y.z+n' bulunamadı")
    return m.group(1), m.group(2)


def release_notes(version):
    """{'tr': ..., 'en': ...} — dosya adı tr-TR.txt / en-US.txt, dil önekiyle eşleşir."""
    d = ROOT / "store" / "release-notes" / version
    out = {}
    for f in sorted(d.glob("*.txt")) if d.exists() else []:
        text = f.read_text(encoding="utf-8").strip()
        if len(text) > 4000:
            die(f"{f.name} 4000 karakteri aşıyor")
        out[f.stem.split("-")[0].lower()] = text
    return out


def run(cmd):
    print(f"• {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    subprocess.run(cmd, cwd=ROOT, check=True)


def build_and_upload():
    auth = [
        "-allowProvisioningUpdates",
        "-authenticationKeyPath", asc.KEY_PATH,
        "-authenticationKeyID", asc.KEY_ID,
        "-authenticationKeyIssuerID", asc.ISSUER,
    ]
    run(["flutter", "build", "ios", "--release", "--no-codesign"])
    subprocess.run(["rm", "-rf", str(ARCHIVE)], check=True)
    run(["xcodebuild", "archive", "-quiet", "-workspace", "ios/Runner.xcworkspace", "-scheme", "Runner",
         "-configuration", "Release", "-destination", "generic/platform=iOS",
         "-archivePath", str(ARCHIVE), *auth])
    with tempfile.TemporaryDirectory() as tmp:
        opts = Path(tmp) / "ExportOptions.plist"
        opts.write_text(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>{TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
""")
        run(["xcodebuild", "-exportArchive", "-archivePath", str(ARCHIVE), "-exportOptionsPlist", str(opts),
             "-exportPath", str(Path(tmp) / "export"), *auth])
    print("✓ yüklendi")


def find_build(version, number, wait):
    q = (f"/v1/builds?filter[app]={APP_ID}&filter[version]={number}"
         f"&filter[preReleaseVersion.version]={version}&fields[builds]=processingState,version")
    deadline = time.time() + (45 * 60 if wait else 0)
    while True:
        data = call("GET", q, what="derleme sorgusu")["data"]
        state = data[0]["attributes"]["processingState"] if data else None
        if state == "VALID":
            print(f"✓ derleme {version} ({number}) işlendi")
            return data[0]["id"]
        if state in ("FAILED", "INVALID"):
            die(f"derleme {version} ({number}) Apple'da reddedildi: {state} (e-postanıza bakın)")
        if time.time() > deadline:
            die(f"derleme {version} ({number}) bulunamadı/işlenmedi (durum: {state or 'yok'}). "
                "--build ile yükleyin ya da biraz sonra tekrar deneyin")
        print(f"  … Apple derlemeyi işliyor ({state or 'henüz görünmüyor'}), 30 sn sonra tekrar")
        time.sleep(30)


def prepare_version(version):
    versions = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS"
                           "&fields[appStoreVersions]=versionString,appStoreState&limit=20")["data"]
    for v in versions:
        a = v["attributes"]
        if a["versionString"] == version:
            if a["appStoreState"] in IN_FLIGHT | {"READY_FOR_SALE"}:
                die(f"{version} zaten '{a['appStoreState']}' durumunda; pubspec.yaml'da sürümü yükseltin")
            print(f"• App Store sürümü {version} mevcut ({a['appStoreState']})")
            return v["id"]
    busy = [v["attributes"] for v in versions if v["attributes"]["appStoreState"] in IN_FLIGHT]
    if busy:
        b = busy[0]
        die(f"{b['versionString']} hâlâ '{b['appStoreState']}' durumunda; Apple aynı anda tek sürüm alır. "
            "Derleme TestFlight'ta hazır; o sürüm yayınlanınca bu komutu tekrar çalıştırın")
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
    if editable:
        vid = editable[0]["id"]
        call("PATCH", f"/v1/appStoreVersions/{vid}",
             {"data": {"type": "appStoreVersions", "id": vid, "attributes": {"versionString": version}}},
             "sürüm numarası güncellenemedi")
        print(f"• hazırlıktaki sürüm {version} olarak yeniden adlandırıldı")
        return vid
    js = call("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version, "releaseType": "AFTER_APPROVAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}, "sürüm oluşturulamadı")
    print(f"• App Store sürümü {version} oluşturuldu")
    return js["data"]["id"]


def set_whats_new(version_id, notes):
    locs = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations"
                       "?fields[appStoreVersionLocalizations]=locale")["data"]
    done = []
    for loc in locs:
        text = notes.get(loc["attributes"]["locale"].split("-")[0].lower())
        if not text:
            continue
        st, js = asc.call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": text}}})
        if st < 300:
            done.append(loc["attributes"]["locale"])
        elif "whatsNew" in str(js):
            print("• ilk sürümde 'yenilikler' metni girilemez, atlandı")
        else:
            die(f"yenilikler metni yazılamadı: {js}")
    print(f"• yenilikler: {done or 'yok'}")


def attach_build(version_id, build_id):
    call("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
         {"data": {"type": "builds", "id": build_id}}, "derleme sürüme bağlanamadı")
    print("✓ derleme sürüme bağlandı")


def submit(version_id):
    subs = call("GET", f"/v1/reviewSubmissions?filter[app]={APP_ID}&filter[platform]=IOS"
                       "&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES")["data"]
    if subs:
        sub = subs[0]["id"]
    else:
        sub = call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}, "inceleme oluşturulamadı")["data"]["id"]
    items = call("GET", f"/v1/reviewSubmissions/{sub}/items?include=appStoreVersion")["data"]
    has = any((i["relationships"].get("appStoreVersion", {}).get("data") or {}).get("id") == version_id
              for i in items)
    if not has:
        call("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}},
             "sürüm incelemeye eklenemedi")
    # Derleme yeni bağlandıysa Apple birkaç dakika "hazır değil" diyebilir.
    for attempt in range(20):
        st, js = asc.call("PATCH", f"/v1/reviewSubmissions/{sub}", {"data": {
            "type": "reviewSubmissions", "id": sub, "attributes": {"submitted": True}}})
        if st < 300:
            print(f"✓ Apple incelemesine gönderildi ({js['data']['attributes']['state']}); "
                  "onaylanınca otomatik yayınlanır")
            return
        text = str(js)
        if "not ready to be submitted yet" not in text:
            die(f"gönderilemedi: HTTP {st} {text[:1500]}")
        print("  … sürüm henüz gönderilmeye hazır değil, 30 sn sonra tekrar")
        time.sleep(30)
    die("sürüm 10 dk içinde gönderilmeye hazır olmadı; App Store Connect'te eksik bilgi olabilir")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build", action="store_true", help="derle ve App Store Connect'e yükle")
    ap.add_argument("--commit", action="store_true", help="Apple incelemesine gönder")
    a = ap.parse_args()

    if not os.path.exists(asc.KEY_PATH):
        die(f"API anahtarı yok: {asc.KEY_PATH}")
    version, number = pubspec_version()
    print(f"• StrideFree {version} ({number})")
    if a.build:
        build_and_upload()
    build_id = find_build(version, number, wait=True)
    version_id = prepare_version(version)
    set_whats_new(version_id, release_notes(version))
    attach_build(version_id, build_id)
    if a.commit:
        submit(version_id)
    else:
        print("• --commit verilmedi: sürüm hazır ama incelemeye gönderilmedi")


if __name__ == "__main__":
    main()
