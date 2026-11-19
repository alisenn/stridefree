"""App Store bilgilerini store/app-store-tr.md içeriğine göre doldurur."""
import re, pathlib
from asc import call

APP = "6836717829"
INFO = "82330bc7-292d-49d1-844a-4060650277c0"
INFO_LOC = "0f65c29e-a5d6-4d1a-a98a-adae0304e545"
VER = "d0b86658-2c14-4863-9800-5a7ffad2a200"
VER_LOC = "f3d6aa07-b0e0-44d3-8096-8f2fee1e7a85"

md = pathlib.Path(__file__).parents[1].joinpath("app-store-tr.md").read_text()
def section(title):
    m = re.search(rf"## {re.escape(title)}[^\n]*\n(.*?)(?=\n## |\Z)", md, re.S)
    return m.group(1).strip()

def ok(label, r):
    st, js = r
    print(("OK " if st < 300 else f"HATA {st} ") + label, "" if st < 300 else js.get("errors", js))

ok("kategori", call("PATCH", f"/v1/appInfos/{INFO}", {"data": {"type": "appInfos", "id": INFO, "relationships": {
    "primaryCategory": {"data": {"type": "appCategories", "id": "HEALTH_AND_FITNESS"}},
    "secondaryCategory": {"data": {"type": "appCategories", "id": "SPORTS"}}}}}))

ok("ad/alt başlık/gizlilik", call("PATCH", f"/v1/appInfoLocalizations/{INFO_LOC}", {"data": {
    "type": "appInfoLocalizations", "id": INFO_LOC, "attributes": {
        "name": "StrideFree: Koşu Bandı Kontrol",
        "subtitle": "Ücretsiz bant ve antrenman",
        "privacyPolicyUrl": "https://github.com/alisenn/stridefree/blob/main/PRIVACY.md"}}}))

ok("açıklama/anahtar kelime", call("PATCH", f"/v1/appStoreVersionLocalizations/{VER_LOC}", {"data": {
    "type": "appStoreVersionLocalizations", "id": VER_LOC, "attributes": {
        "description": section("Açıklama"),
        "keywords": section("Anahtar kelimeler"),
        "promotionalText": section("Tanıtım metni"),
        "supportUrl": "https://github.com/alisenn/stridefree/issues",
        "marketingUrl": "https://github.com/alisenn/stridefree"}}}))

ok("telif", call("PATCH", f"/v1/appStoreVersions/{VER}", {"data": {"type": "appStoreVersions", "id": VER,
    "attributes": {"copyright": "2026 StrideFree contributors", "releaseType": "AFTER_APPROVAL"}}}))

ok("içerik hakları", call("PATCH", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP,
    "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}}))

# Yaş sınırı: hiçbir hassas içerik yok → 4+
st, js = call("GET", f"/v1/appInfos/{INFO}/ageRatingDeclaration")
if st == 200:
    aid = js["data"]["id"]
    attrs = {k: ("NONE" if isinstance(v, str) or v is None else False)
             for k, v in js["data"]["attributes"].items()}
    # Bilinen alanlar dışında kalanları temizle (API tipine göre)
    for k, v in list(js["data"]["attributes"].items()):
        if isinstance(v, bool): attrs[k] = False
    attrs.pop("kidsAgeBand", None); attrs.pop("ageRatingOverride", None); attrs.pop("koreaAgeRatingOverride", None)
    attrs.pop("koreaAgeRatingOverrideV2", None); attrs.pop("ageRatingOverrideV2", None); attrs.pop("developerAgeRatingInfoUrl", None)
    ok("yaş sınırı", call("PATCH", f"/v1/ageRatingDeclarations/{aid}", {"data": {"type": "ageRatingDeclarations", "id": aid, "attributes": attrs}}))
else:
    print("yaş sınırı okunamadı", st, js)
