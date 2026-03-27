pass.bat
========

pass.cmd - the standard unix password manager, now on windows!

Written in pure batch script for compatibility with Windows and ReactOS without
any external dependency other than gpg.

GOALS
-----
- Provide UNIX pass interface to the user.
- Don't depend on anything except cmd and gpg.
- Be extensible like the original pass while providing common extensions out
of the box (pass-otp).

FEATURES
--------
- Supports / as well as \ for paths
- Less dependency and auditable
- Optional OTP support via totp.exe tool instead of the oauthtool
- Easy deployment (Single .bat file)

NOTES
-----
It is suggested to use this program with passmenu.bat, wlines.exe and 
totp.exe.

BUGS
----
- pass -c does not expire after %PASSWORD_STORE_CLIP_TIME%
- The tree obtained after running only `pass` has a little quark. Directories
without any .gpg files in them may show up.
- Setting PASSWORD_STORE_SIGNING_KEY can be finicky.
- Little care has been taken for files having weird names. Files with @ works
though.
- No sanitization is done when reading .gpg-id files for keys yet.
- Inline comments are not supported for .gpg-id files yet.
- Groups feature not tested yet.
- Let me know!

TODO
----
- Signed releases
- Add extension support
- Add completions based on availability (clink, powershell)
- Distribution mechanism?

RELATED
-------
- [password-store](https://www.passwordstore.org/)
- [totp](https://codeberg.org/sjmulder/totp)
- [wlines](https://github.com/jerwuqu/wlines)
- [tpm](https://git.8pit.net/tpm/)
- [tpm-utils](https://codeberg.org/haiksgit/tpm-utils)
- [pass-winmenu](https://github.com/geluk/pass-winmenu)
