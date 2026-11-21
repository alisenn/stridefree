# Security Policy

## Supported versions

Only the latest release (and `main`) receives security fixes.

## What's in scope

StrideFree has no server, no accounts and no analytics, so the attack surface is small. Things we'd still like to hear about:

- Bluetooth handling that could be abused by a nearby malicious device (crashes, unexpected treadmill commands, unsafe speeds)
- Data leaving the device in any way
- Problems in import / backup parsing (TCX, GPX, CSV, JSON) such as crashes or code execution from a crafted file
- Vulnerable dependencies

**Treadmill safety matters.** Anything that could make a treadmill speed up or start unexpectedly is treated as high priority.

## Reporting a vulnerability

Please **don't open a public issue** for security problems.

Use GitHub's private reporting: **[Report a vulnerability](https://github.com/alisenn/stridefree/security/advisories/new)**, or email **canykimy@gmail.com**.

Please include steps to reproduce, the affected version and platform, and (for Bluetooth issues) the treadmill model. You'll get a reply within a week. Once a fix is released you'll be credited in the release notes unless you'd rather stay anonymous.

---

**Türkçe:** Güvenlik açıklarını herkese açık issue olarak değil, [gizli raporla](https://github.com/alisenn/stridefree/security/advisories/new) ya da **canykimy@gmail.com** adresine bildirin. Bandı beklenmedik şekilde hızlandırabilecek her durum öncelikli ele alınır.
