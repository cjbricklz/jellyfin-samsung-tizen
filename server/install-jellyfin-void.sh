#!/bin/sh
# Install Jellyfin Server 10.11.11 natively on Void Linux (runit). Run as root.
# Port 8097 (8096 was used by Emby, since removed; change PORT below to 8096 if you want the default).
set -e
VER=10.11.11
FFMPEG=7.1.4-3
PORT=${PORT:-8097}
cd /root 2>/dev/null || cd /tmp
mkdir -p jf-dl && cd jf-dl
curl -fsSLO https://repo.jellyfin.org/files/server/linux/stable/v$VER/amd64/jellyfin_$VER-amd64.tar.xz
curl -fsSLO https://repo.jellyfin.org/files/ffmpeg/linux/latest-7.x/amd64/jellyfin-ffmpeg_${FFMPEG}_portable_linux64-gpl.tar.xz

mkdir -p /opt/jellyfin /opt/jellyfin-ffmpeg
tar -xJf jellyfin_$VER-amd64.tar.xz -C /opt/jellyfin --strip-components=1
tar -xJf jellyfin-ffmpeg_${FFMPEG}_portable_linux64-gpl.tar.xz -C /opt/jellyfin-ffmpeg
id jellyfin >/dev/null 2>&1 || useradd -r -M -s /sbin/nologin -G media,video jellyfin
mkdir -p /var/lib/jellyfin/config /var/cache/jellyfin /var/log/jellyfin
cat > /var/lib/jellyfin/config/network.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <InternalHttpPort>$PORT</InternalHttpPort>
  <PublicHttpPort>$PORT</PublicHttpPort>
  <AutoDiscovery>false</AutoDiscovery>
  <EnableUPnP>false</EnableUPnP>
</NetworkConfiguration>
XML
chown -R jellyfin:jellyfin /var/lib/jellyfin /var/cache/jellyfin /var/log/jellyfin

mkdir -p /etc/sv/jellyfin
cp "$(dirname "$0")/runit-run" /etc/sv/jellyfin/run 2>/dev/null || cat > /etc/sv/jellyfin/run <<'RUN'
#!/bin/sh
exec 2>&1
exec chpst -u jellyfin:jellyfin /opt/jellyfin/jellyfin \
    --datadir /var/lib/jellyfin \
    --cachedir /var/cache/jellyfin \
    --ffmpeg /opt/jellyfin-ffmpeg/ffmpeg
RUN
chmod 755 /etc/sv/jellyfin/run
ln -sfn /etc/sv/jellyfin /var/service/jellyfin
/opt/jellyfin-ffmpeg/ffmpeg -version | head -1
echo "Started; check: curl http://localhost:$PORT/System/Info/Public"
