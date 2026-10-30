# OMP + PinkCollab na Unraidzie

Nieoficjalny obraz integracyjny z **oryginalnym Oh My Pi** (binarne wydanie) oraz **oryginalnym PinkCollab Gateway** (npm). Nie jest to fork żadnego z projektów.

## Jak działa aktualizacja

GitHub Actions codziennie sprawdza nowe wersje OMP i PinkCollab. Przy zmianie wersji lub kodu repozytorium buduje obraz i publikuje go w GitHub Container Registry:

`ghcr.io/elmakus/pinkcollab-omp:latest`

Po pierwszym udanym buildzie ustaw widoczność pakietu GHCR na **Public**. W Unraidzie używaj **Docker → Check for Updates → Update**. Aplikacja PinkCollab na Androidzie wymaga osobnej aktualizacji APK **do wersji zgodnej z Gatewayem**.

## Co jest w środku

Node.js 22, **Bun**, oficjalny binarny OMP i PinkCollab Gateway. Python 3 + pip/venv, kompilatory GCC/make, `fd`, `ripgrep`, `git`, `gh`, SSH, `sqlite3`, `jq`, `rsync`, `curl`, `wget`, `zip/unzip`, `tmux`, `socat`, `nano` oraz narzędzia sieciowe `ping`, `ip`, `dig`, `nc`. Dodatkowo gotowe serwery LSP: **TypeScript/JavaScript, Python (Pyright), YAML, Bash, Dockerfile**. Procesy działają pod UID/GID 1000. Kontener ma HEALTHCHECK. Nie ma dostępu do socketu Dockera, pełnej macierzy ani automatycznie skonfigurowanych MCP.

**Nie instalujemy** `ipykernel` (współczesne OMP ma własny kernel Python bez zależności od Jupytera), Rust (nie jest potrzebny do uruchomienia binarnego OMP) ani `iptables` z uprawnieniem NET_ADMIN (nie jest konieczne dla funkcji gatewaya). Przeglądarka Chromium, serwery DAP dla konkretnych języków, pamięć Mnemopi oraz dostęp do SSH/MCP można skonfigurować w zależności od zastosowania. Samo obecne narzędzie `debug`/`lsp` OMP nie gwarantuje działającego adaptera dla każdej technologii.

## Pierwsze uruchomienie na Unraidzie

1. Sprawdź [pierwszy build w Actions](https://github.com/elmakus/pinkcollab-omp-unraid/actions).
2. W GitHub Packages przełącz pakiet `pinkcollab-omp` na **Public**.
3. Uruchom w terminalu Unraida:

```sh
mkdir -p /mnt/user/appdata/pinkcollab-omp/{.omp,.pinkcollab,.local,.config,.ssh}
mkdir -p /mnt/cachedl/omp-workspace
chown -R 1000:1000 /mnt/user/appdata/pinkcollab-omp /mnt/cachedl/omp-workspace
chmod 700 /mnt/user/appdata/pinkcollab-omp/.ssh
```

4. Skopiuj `templates/my-pinkcollab-omp.xml` do `/boot/config/plugins/dockerMan/templates-user/my-pinkcollab-omp.xml`.
5. W Docker → Add Container wybierz szablon `pinkcollab-omp`. Obraz: `ghcr.io/elmakus/pinkcollab-omp:latest`.
6. W istniejącym Cloudflare Tunnel na Unraidzie dodaj trasę **Published application** (Cloudflare Dashboard → Networking → Tunnels → wybierz tunnel → Routes). Skonfigurowany hostname: `pinkcollab.makowski.li`. Service URL: **`http://pinkcollab-omp:8788`**. Kontener jest w sieci Docker `ibraproxy`, w której pracuje także `CloudflaredTunnel`, i **nie publikuje portów na hoście**. Nie potrzeba Nginx Proxy Manager ani przekierowania portów na UniFi.
7. Sprawdź z telefonu przez Internet `https://pinkcollab.makowski.li/health` (oczekiwane `pinkcollab:ok`), a następnie sparuj aplikację (użyj faktycznego hostname):

```sh
docker exec -it pinkcollab-omp pinkcollab pair --url https://pinkcollab.makowski.li
```

PinkCollab Gateway uruchamia OMP lokalnie na żądanie; w pojedynczym kontenerze nie potrzebujesz drugiego demona OMP.

## Dane, logowanie i diagnostyka

- **`/mnt/user/appdata/pinkcollab-omp` → `/home/agent`** (cały katalog domowy agenta, w tym `.omp`, `.pinkcollab`, `.local`, `.config`, `.ssh`, `.cache` i przyszłe konfiguracje/narzędzia). W Unraidzie to jeden mount, wszystkie pliki użytkownika są trwałe.
- **`/mnt/cachedl/omp-workspace` → `/workspace`** (osobny trwały katalog projektów bezpośrednio na NVMe cachedl, niezależnie od `appdata`).

Wcześniejszą instalację z pięcioma osobnymi katalogami przeniesiono do ukrytych katalogów (`omp` → `.omp`, `gateway` → `.pinkcollab`, `local` → `.local`, `user-config` → `.config`, `ssh` → `.ssh`) i ponownie uruchomiono kontener z dwoma mapowaniami.

### Instalowanie narzędzi przez agenta i trwałość

OMP działa jako nieuprzywilejowany użytkownik UID 1000. **Cały katalog domowy** jest trwały, włącznie z cache i przyszłymi konfiguracjami innych programów. Pakiety `npm install -g` lądują dzięki `NPM_CONFIG_PREFIX` w `~/.local/npm`; własne programy w `~/.local/bin` również pozostają po odtworzeniu kontenera. Programy `gh` zapisują ustawienia w `~/.config`, a klucze SSH w `~/.ssh`. Biblioteki Pythona instaluj w wirtualnym środowisku, np. `python3 -m venv /workspace/.venv` i potem `/workspace/.venv/bin/python -m pip install <package>`. Dane takiego venv leżą na cachedl, więc również przetrwają update. Nie instaluj bibliotek pip do systemowego Pythona.

**Uwaga:** `apt install`, pliki w `/usr/local` i inne zmiany warstwy kontenera **nie są trwałe**. Jeżeli nowy program potrzebuje uprawnień roota, dodaj go do Dockerfile w tym repozytorium, aby GitHub Actions zbudował i przetestował nowy obraz. Kontener celowo nie ma uprawnień administracyjnych do hosta. Uruchomiony jest jako `agent` (UID 1000), z `--cap-drop=ALL`, `--security-opt=no-new-privileges`, bez `--privileged` i bez montowania `/var/run/docker.sock`. Zewnętrzne SSH/API mogą nadać uprawnienia wynikające z podanych tam danych logowania, więc należy je ograniczać niezależnie. Ponieważ cały HOME jest trwały, `~/.cache` i `~/.npm` mogą z czasem rosnąć; można je selektywnie czyścić lub wykluczyć z kopii zapasowych.

```sh
docker exec -it pinkcollab-omp omp
docker exec pinkcollab-omp omp --version
docker exec pinkcollab-omp pinkcollab --version
docker exec pinkcollab-omp pinkcollab doctor
docker inspect --format '{{.State.Health.Status}}' pinkcollab-omp
```

Po aktualizacji sesje na dysku pozostają, ale działające zadania zostaną przerwane. Plik z prywatną wiedzą o Twoim środowisku (`AGENTS.md`) trzymaj wyłącznie w wolumenie Unraida, **nigdy w tym publicznym repozytorium**.

## Ograniczenia

- To własny obraz łączący oryginalne wydania; nie jest oficjalnym obrazem OMP ani PinkCollab.
- APK Android aktualizujesz osobno, gdy zmienia się PinkCollab Gateway.
- Pierwszy build i pełne działanie przez Androida wymagają testu. Status działania widać w Actions.
- Domyślna konfiguracja nie instaluje Mnemopi ani nie udziela dostępu do Unraida/UniFi/Home Assistanta.
- Cloudflare Tunnel publikuje wybrany hostname przez HTTPS bez otwierania portów przychodzących. Sam tunel nie ogranicza dostępu do sparowanych urządzeń: PinkCollab odpowiada za parowanie i autoryzację. Nie włączaj interaktywnej strony logowania Cloudflare Access przed testem obsługi Androida: może blokować aplikację mobilną. Po przyznaniu OMP dostępu SSH jako root traktuj publiczną ekspozycję gatewaya jako element wysokiego ryzyka i włącz ochronę WAF/rate limiting oraz monitoruj połączenia.

## Upstream

- [OMP](https://github.com/can1357/oh-my-pi)
- [PinkCollab](https://github.com/3xian/PinkCollab)
- [PinkCollab deployment](https://github.com/3xian/PinkCollab/blob/main/docs/deployment.md)
