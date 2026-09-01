# The playtest signing key

`debug.keystore` is checked in on purpose, and it is not a secret.

Android will not install an unsigned APK, and it will not install a new
version of an app signed with a different key than the one already on the
device. The builds used to make a throwaway key on each run, which meant every
playtest build had to be installed over an uninstall — and an uninstall takes
the saves with it. A key that does not change fixes that: a new build installs
over the old one and the game carries on.

It is a debug key with the same well-known credentials the Android SDK uses for
its own — alias `androiddebugkey`, store and key password `android` — so
publishing it costs nothing that was not already public. What it can do is sign
a playtest build of this game. What it cannot do is publish anything: Google
Play refuses debug-signed uploads, and anybody installing one has to get past
Play Protect's unknown-developer warning by hand.

    SHA256 55:F6:7F:93:30:75:FC:84:7D:29:0B:67:23:3B:A3:54
           3B:58:2E:31:BB:E0:60:37:7D:A6:43:CB:23:2F:8B:A7

A real release wants a real key, kept out of the tree and passed in as a
repository secret. That is a separate decision and this is not it.

**Anything signed with this key should be treated as untrusted.** It says only
that a build came from this repository's CI, and anyone who has read this file
can produce a build that says the same.
