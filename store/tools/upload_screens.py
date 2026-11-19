"""store/screenshots/tr/*.png dosyalarını App Store sürüm yerelleştirmesine yükler."""
import hashlib, pathlib, sys, urllib.request
from asc import call

VER_LOC = "f3d6aa07-b0e0-44d3-8096-8f2fee1e7a85"
DISPLAY = sys.argv[1] if len(sys.argv) > 1 else "APP_IPHONE_67"
files = sorted(pathlib.Path(__file__).parents[1].joinpath("screenshots/tr").glob("*.png"))

st, js = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
    "attributes": {"screenshotDisplayType": DISPLAY},
    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": VER_LOC}}}}})
if st >= 300:
    print("set oluşturulamadı", st, js.get("errors")); sys.exit(1)
set_id = js["data"]["id"]

for f in files:
    data = f.read_bytes()
    st, js = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileName": f.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if st >= 300:
        print("HATA", f.name, js.get("errors")); continue
    sid = js["data"]["id"]
    for op in js["data"]["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req).read()
    st, js = call("PATCH", f"/v1/appScreenshots/{sid}", {"data": {"type": "appScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("OK" if st < 300 else f"HATA {st}", f.name)
