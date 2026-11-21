"""Google Play'e .aab yükler ve bir test/yayın kanalına sürüm oluşturur (Play Developer API).

Kullanım:
    python store/tools/play_upload.py --build                # derle, yükle, doğrula (gönderme)
    python store/tools/play_upload.py --build --commit       # ... ve Google incelemesine gönder
    python store/tools/play_upload.py --track internal       # başka kanal (internal/alpha/beta/production)

Varsayılan kanal 'alpha' = Play Console'daki "Closed testing - Alpha".
--commit olmadan hiçbir şey yayınlanmaz: yükleme yapılır, sürüm doğrulanır ve taslak düzenleme bırakılır.

Kimlik: servis hesabı JSON anahtarı. Yol sırasıyla:
    PLAY_SERVICE_ACCOUNT ortam değişkeni
    ~/stridefree-keys/play-service-account.json
Anahtar repoya girmez; Play Console → Kullanıcılar ve izinler'de bu hesaba uygulama için
"Sürüm oluşturma" yetkisi verilmiş olmalı.

Sürüm notları: store/release-notes/<sürüm>/<dil>.txt (ör. 1.0.1/tr-TR.txt, 1.0.1/en-US.txt), en fazla 500 karakter.
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.candykimy.stridefree"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"
AAB = ROOT / "build/app/outputs/bundle/release/app-release.aab"


def key_path() -> Path:
    env = os.environ.get("PLAY_SERVICE_ACCOUNT")
    return Path(env) if env else Path.home() / "stridefree-keys" / "play-service-account.json"


def session() -> AuthorizedSession:
    creds = service_account.Credentials.from_service_account_file(
        str(key_path()), scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    return AuthorizedSession(creds)


def check(r, what):
    if r.status_code >= 300:
        sys.exit(f"✗ {what}: HTTP {r.status_code}\n{r.text[:2000]}")
    return r.json() if r.content else {}


def _pubspec_version():
    m = re.search(r"^version:\s*([\d.]+)\+(\d+)", (ROOT / "pubspec.yaml").read_text(), re.M)
    if not m:
        sys.exit("✗ pubspec.yaml'da 'version: x.y.z+n' bulunamadı")
    return m.group(1), int(m.group(2))


def app_version() -> str:
    return _pubspec_version()[0]


def build_number() -> int:
    return _pubspec_version()[1]


def release_notes(version: str):
    d = ROOT / "store" / "release-notes" / version
    notes = []
    for f in sorted(d.glob("*.txt")) if d.exists() else []:
        text = f.read_text(encoding="utf-8").strip()
        if len(text) > 500:
            sys.exit(f"✗ {f.name} 500 karakteri aşıyor ({len(text)})")
        notes.append({"language": f.stem, "text": text})
    return notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--track", default="alpha")
    ap.add_argument("--aab", default=str(AAB))
    ap.add_argument("--build", action="store_true", help="önce flutter build appbundle çalıştır")
    ap.add_argument("--commit", action="store_true", help="düzenlemeyi kaydet = incelemeye gönder")
    a = ap.parse_args()

    version = app_version()
    if a.build:
        print("• flutter build appbundle --release")
        subprocess.run("flutter build appbundle --release", shell=True, cwd=ROOT, check=True)
    aab = Path(a.aab)
    if not aab.exists():
        sys.exit(f"✗ {aab} yok (--build ile derleyin)")
    if not key_path().exists():
        sys.exit(f"✗ Servis hesabı anahtarı yok: {key_path()}")

    s = session()
    edit = check(s.post(f"{API}/edits"), "düzenleme açılamadı")["id"]
    print(f"• düzenleme {edit}")

    print(f"• yükleniyor: {aab.name} ({aab.stat().st_size / 1e6:.1f} MB)")
    with open(aab, "rb") as f:
        r = s.post(
            f"{UPLOAD}/edits/{edit}/bundles?uploadType=media",
            data=f,
            headers={"Content-Type": "application/octet-stream"},
            timeout=900,
        )
    if r.status_code == 403 and "already been used" in r.text:
        # Bu derleme numarası Play'de zaten var (ör. Console'dan elle yüklendi): onu kullan.
        code = build_number()
        print(f"• versionCode {code} zaten yüklü, mevcut paket kullanılıyor")
    else:
        code = check(r, "paket yüklenemedi")["versionCode"]
        print(f"• yüklendi: versionCode {code}")

    notes = release_notes(version)
    release = {"name": f"{code} ({version})", "versionCodes": [str(code)], "status": "completed"}
    if notes:
        release["releaseNotes"] = notes
    check(
        s.put(f"{API}/edits/{edit}/tracks/{a.track}", json={"track": a.track, "releases": [release]}),
        "kanal güncellenemedi",
    )
    print(f"• kanal '{a.track}': {release['name']}, notlar: {[n['language'] for n in notes] or 'yok'}")

    check(s.post(f"{API}/edits/{edit}:validate"), "doğrulama başarısız")
    print("✓ doğrulandı")

    if a.commit:
        check(s.post(f"{API}/edits/{edit}:commit"), "gönderilemedi")
        print("✓ kaydedildi — Google incelemesine gönderildi")
    else:
        s.delete(f"{API}/edits/{edit}")
        print("• --commit verilmedi: düzenleme silindi, hiçbir şey yayınlanmadı (paket kütüphanede kalır)")


if __name__ == "__main__":
    main()
