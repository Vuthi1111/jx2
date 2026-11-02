# Client setup (JX2 2021 "Shiina")

Source: `https://drive.google.com/file/d/19lcRG8r4fS_-1MO5KMi5PqiU4SAEaBBk/view` (from EoPi's book,
`book.loliteam.net/tong-hop-vo-lam-2/server-jx2-2021-phien-ban-offline`).

## Archive facts

- RAR5, ~2.97 GB, **password: `thuong`** (confirmed from EoPi's mirror-forum thread; the book page does not state it).
- Extraction: `unar` (EPEL) is buggy on this encrypted RAR5 and EPEL's `7z` lacks the RAR codec —
  use rarlab's static `unrar` (`https://www.rarlab.com/rar/rarlinux-x64-*.tar.gz`) or WinRAR on Windows.
- Contents: Windows client (~3.3 GB), `jxq.exe` (game), `autovl2.exe` (launcher),
  `cfeapplt.exe` (EoPi's IP-change helper), `settings/connectings.ini` (server list).

## Pointing it at our server

`settings/connectings.ini`:

```ini
[Region_0]
Count=2
0_Title=Shiina Eopi
0_Address=130.94.6.220     ; <- the only IP you must change
0_GroupName=1
```

That's it — EoPi's client talks only to the gateway (Bishop :55795). The old offline default was `192.168.70.100`.

## First login

1. Download + extract the client (password above).
2. Edit `settings/connectings.ini` as above.
3. Run `autovl2.exe` (or `jxq.exe` directly).
4. Log in with the test account created server-side: **`test` / `test123`**.
   (`paysys.account.password` = MD5(plaintext); insert more rows in `paysys` when needed.)

## Notes

- Client displays GBK/Vietnamese text; `settings/connectings.ini` titles can be renamed freely
  (`0_Title=...`) — that's the realm name shown in the launcher.
- `config.ini` already has `single_byte_char_set=1` and `english_message=1` hints; text assets are in
  `settings/*.txt` inside `data/*.pak` — that is where translation/customization work happens.