# Jellyfin on a Samsung Tizen TV + a native Jellyfin server (Void Linux)

Two pieces, both pinned to **Jellyfin 10.11.11**:

| Piece | What | Where it runs |
|---|---|---|
| `tv/` | Build `jellyfin-web` + `jellyfin-tizen`, sign it, install it on the TV | Samsung 6 Series UHD (2017 6 Series, Tizen 3.0, armv7) |
| `server/` | Native Jellyfin Server + jellyfin-ffmpeg as a runit service | Void Linux server (`<SERVER_IP>`), port **8097** |

Versions used: jellyfin-web `release-10.11.z` @ `35c0793` (10.11.11), jellyfin-tizen @ `31408c1`,
Jellyfin Server 10.11.11, jellyfin-ffmpeg 7.1.4-3, Tizen Studio CLI 5.6, Node 22 (npm 10).
The widget was built unmodified from upstream. There are no local patches.

## Placeholders you must fill in

Personal details were removed from this repo. Wherever you see these tokens, substitute your own values
(a person or an LLM agent can do this by search-and-replace; none of them are committed anywhere):

| Token | Meaning | How to find it |
|---|---|---|
| `<SERVER_IP>` | LAN address of the server running Jellyfin | `ip -4 addr` on the server |
| `<SERVER_USER>` | SSH/sudo user on the server | the account you log in with (needs sudo/root for the install script) |
| `<TV_IP>` | TV address on the Wi-Fi/LAN | TV: Apps → Developer mode screen, or router client list |
| `<HOST_PC_IP>` | IP of the PC running the Tizen tools, entered in the TV's Developer mode dialog | `ip -4 addr` on the PC |
| `<TV_DUID>` | TV device ID, needed only if you build a TV-specific distributor certificate | `sdb connect <TV_IP>; sdb shell 0 getduid` |
| `<MEDIA_PATH>` | Mount point of your media drive on the server | `df -h` on the server (library path given to the Jellyfin wizard) |
| `<CERT_NAME>` | Name placed in your Tizen author certificate (`setup-cert.sh "<CERT_NAME>"`), any string | your choice |
| `<SERVER_PASSWORD>` | Never stored. Use SSH keys (`ssh-copy-id <SERVER_USER>@<SERVER_IP>`) or type it when prompted | n/a |

Secrets that are generated locally and must stay out of git: the Tizen author keystore and its password
(`~/tizen-studio-data/keystore/`), and any `.p12` files. The `.gitignore` already excludes `*.p12` and `password.txt`.

## 1. Server (Void Linux, runit)

On the server, as root (or with sudo):

```sh
sudo sh server/install-jellyfin-void.sh        # PORT=8096 sudo -E sh ... to use the default port
```

It downloads the official portable tarballs into `/opt/jellyfin` and `/opt/jellyfin-ffmpeg`, creates a
`jellyfin` user (groups `media`, `video`), writes `/var/lib/jellyfin/config/network.xml`
(port 8097, auto-discovery and UPnP off), installs `/etc/sv/jellyfin/run` and links it into `/var/service`.

Check: `curl http://localhost:8097/System/Info/Public`. Then open `http://<SERVER_IP>:8097` and run the
setup wizard. Add the library with path `<MEDIA_PATH>/...` (the `jellyfin` user reads it via the `media` group).

Notes
- Data lives in `/var/lib/jellyfin`, cache in `/var/cache/jellyfin`. Back up the data directory.
- Update: change `VER`/`FFMPEG` in the script, rerun, then `sv restart jellyfin`.
- If you are replacing another media server on port 8096 (this setup replaced Emby), stop it first or keep 8097.

## 2. TV app (Samsung Tizen)

Note: the TV's Tizen 3.0 browser is old, so the web client version matters. 10.11.x worked here.

### One-time prep
1. On the TV: Apps → press `12345` on the remote → **Developer mode ON**, set *Host PC IP* to `<HOST_PC_IP>`.
   Reboot the TV.
2. Install the Tizen Studio CLI (no root needed):
   ```sh
   curl -fLO https://download.tizen.org/sdk/Installer/tizen-studio_5.6/web-cli_Tizen_Studio_5.6_ubuntu-64.bin
   chmod +x web-cli_*.bin && ./web-cli_*.bin --accept-license ~/tizen-studio
   export PATH=$HOME/tizen-studio/tools:$HOME/tizen-studio/tools/ide/bin:$HOME/tizen-studio/package-manager:$PATH
   ```
3. Connect and note the TV's DUID, `<TV_DUID>` (`sdb connect <TV_IP>; sdb shell 0 getduid`).
4. Install the extensions for TV packaging/certificates:
   `package-manager-cli.bin install --accept-license Certificate-Manager cert-add-on TV-SAMSUNG-Public-WebAppDevelopment TV-SAMSUNG-Extension-Tools`.
   It reports errors for a few Ubuntu/KDE GUI libraries (the GUI Certificate Manager). Ignore them: the CLI
   packaging and certificate tools still work.
5. Create the signing certificate and profile: `./tv/setup-cert.sh "Your Name"`.
6. Node: jellyfin-web needs npm 10, so use Node 22 (`mise use node@22`). Node 26 / npm 11 is rejected.

### Build + install
```sh
TV_IP=<TV_IP> ./tv/build-and-install.sh
```
This clones upstream at the pinned versions into `build/`, builds the web client
(`USE_SYSTEM_FONTS=1 npm run build:production`), wraps it with jellyfin-tizen, packages `Jellyfin.wgt`
signed with your `JellyfinTV` profile, installs and launches it (`AprZAARz4r.Jellyfin`).

A prebuilt widget is at `wgt/Jellyfin-10.11.11.wgt`. It is signed with a throwaway author certificate (`CN=Jellyfin`)
and the public Tizen distributor certificate, with no personal data. TVs generally need to be in developer mode
with your PC's IP set; if the install is rejected, rebuild and re-sign with your own profile (above).
`sdb connect <TV_IP>` then `tizen install -n wgt/Jellyfin-10.11.11.wgt -t <sdb device name>`.
Note: this re-signed package was built but not test-installed on the TV; the originally installed one used a different author cert.

### Connect the app to the server
In the app enter the server address **with the port**: `http://<SERVER_IP>:8097`. Without the port the TV
hits 8096 and gets "server needs updating" if some other server answers there.

## Troubleshooting
- `sdb` shows nothing: the TV's Host PC IP must be this PC and the TV rebooted. Port 26101 must be open.
- Install fails with a certificate error: the distributor certificate must include the TV's DUID. Redo step 5 with the TV connected.
- Remote SSH login shell on the server is fish; wrap commands with `bash -s`.
