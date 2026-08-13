# 한국 SNI 차단 우회 (ByeDPI) - Linux 설정 가이드

한국 ISP(KT/SKB/LGU+)의 HTTPS SNI 차단을 우회하는 로컬 SOCKS5 프록시 설정법입니다.
외부 VPN 서버 없이 내 컴퓨터에서 패킷만 변조하므로 속도 저하가 없습니다.

## 원리

- ISP는 TLS ClientHello의 SNI(접속 도메인)를 보고 차단 대상이면 TCP RST를 보냄
- ByeDPI가 ClientHello를 조각내어(TLS record 분할 등) DPI가 SNI를 읽지 못하게 함
- DNS 차단까지 고려하면 브라우저 DoH 설정을 병행 권장

## 설치

1. [hufrea/byedpi](https://github.com/hufrea/byedpi/releases) 최신 릴리즈에서 플랫폼용 바이너리 다운로드
   - Linux x86_64: `byedpi-<ver>-x86_64.tar.gz`
2. 압축 풀고 실행 파일을 원하는 위치에 배치 (예: `~/byedpi/ciadpi`)
3. 아래의 systemd 유저 서비스로 등록하면 부팅 시 자동 시작

## 설정

### systemd 유저 서비스

`~/.config/systemd/user/byedpi.service`:

```ini
[Unit]
Description=ByeDPI - SNI filtering bypass (SOCKS5 proxy on 127.0.0.1:1080)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/byedpi/ciadpi -i 127.0.0.1 -p 1080 --disorder 1 --auto=torst --tlsrec 1+s
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now byedpi.service
```

### 수동 실행

```bash
~/byedpi/ciadpi -i 127.0.0.1 -p 1080 --disorder 1 --auto=torst --tlsrec 1+s
```

### 시스템 프록시 (GNOME/GSettings)

```bash
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
gsettings set org.gnome.system.proxy.socks port 1080
```

### CLI 환경변수

`~/.config/environment.d/byedpi.conf`:

```sh
http_proxy=socks5://127.0.0.1:1080
https_proxy=socks5://127.0.0.1:1080
all_proxy=socks5://127.0.0.1:1080
no_proxy=localhost,127.0.0.1,::1
```

### Chromium 계열 브라우저 (Brave/Chrome)

**플래그를 하드코딩하지 말 것.** Brave는 GSettings 시스템 프록시를 실시간 반영하므로,
아래 "원클릭 토글" 스크립트가 `org.gnome.system.proxy`를 켜고 끌 뿐 브라우저 재시작이 불필요하다.
(과거 방식: `~/.config/brave-flags.conf`에 `--proxy-server=socks5://127.0.0.1:1080` 추가 —
따옴표를 붙이면 `ERR_NO_SUPPORTED_PROXIES` 발생, 변경 후 완전 재시작 필요. 플래그를 고정하면
byedpi를 껐을 때 브라우저가 죽은 프록시를 바라봐서 인터넷 전체가 끊기므로 권장하지 않음)

## 원클릭 토글

`byedpi.sh`를 PATH에 설치 (`ln -s ~/byedpi/byedpi.sh ~/.local/bin/byedpi`):

```bash
byedpi start   # 우회 켜기
byedpi stop    # 우회 끄기
byedpi status  # 상태 확인 (차단 사이트로 실측)
byedpi heat    # CPU 온도/부하 확인
```

`start`: byedpi 서비스 실행 + GSettings 프록시를 manual(socks 127.0.0.1:1080)로
`stop`: 서비스 중지 + GSettings 프록시를 none으로 (일반 인터넷은 그대로, 차단 사이트만 막힘)

## 검증

```bash
curl -sI --max-time 10 --socks5-hostname 127.0.0.1:1080 https://www.pornhub.com \
  -o /dev/null -w "HTTP %{http_code}\n"
```

- 직접 연결: 차단됨 (HTTP 000 / ERR_CONNECTION_RESET)
- 프록시 경유: HTTP 200

브라우저는 `brave://version`의 Command Line에 `--proxy-server=socks5://127.0.0.1:1080`이 보이면 성공.

## 제한 사항

- 이 방법은 **ISP SNI 차단 우회** 전용. 2026년 5월부터 Cloudflare가 한국 IP 전체에 HTTP 451로 차단하는 사이트는 **외국 IP(VPS 터널)가 필요**함
- 정부가 DPI 탐지 방식을 바꾸면 우회가 막힐 수 있음. 그때 `--tlsrec 1+s` 등을 조정
- 패킷 변조 도구라 브라우징 데이터 자체는 암호화되지 않음 (VPN이 아님)
