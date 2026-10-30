# OMP + PinkCollab na Unraidzie

Nieoficjalny obraz integracyjny z **oryginalnym Oh My Pi** (binarne wydanie) oraz **oryginalnym PinkCollab Gateway** (npm). Nie jest to fork żadnego z projektów.

## Jak działa aktualizacja

GitHub Actions codziennie sprawdza nowe wersje OMP i PinkCollab. Przy zmianie wersji lub kodu repozytorium buduje obraz i publikuje go w GitHub Container Registry:

`ghcr.io/elmakus/pinkcollab-omp:latest`

Po pierwszym udanym buildzie ustaw widoczność pakietu GHCR na **Public**. W Unraidzie używaj **Docker → Check for Updates → Update**. Aplikacja PinkCollab na Androidzie wymaga osobnej aktualizacji APK **do wersji zgodnej z Gatewayem**.

## Co jest w środku

Node.js 22, OMP, PinkCollab Gateway, git, openssh-client, curl, bash, python3, ripgrep, jq, zip/unzip, procps, tmux, socat i dumb-init. Procesy działają pod UID/GID 1000. Kontener ma HEALTHCHECK. Nie ma dostępu do socketu Dockera, pełnej macierzy ani automatycznie skonfigurowanych MCP.

## Pierwsze uruchomienie na Unraidzie

1. Sprawdź [pierwszy build w Actions](https://github.com/elmakus/pinkcollab-omp-unraid/actions).
2. W GitHub Packages przełącz pakiet `pinkcollab-omp` na **Public**.
3. Uruchom w terminalu Unraida:

```sh
mkdir -p /mnt/user/appdata/pinkcollab-omp/{omp,gateway,workspace}
chown -R 1000:1000 /mnt/user/appdata/pinkcollab-omp
```

4. Skopiuj `templates/my-pinkcollab-omp.xml` do `/boot/config/plugins/dockerMan/templates-user/my-pinkcollab-omp.xml`.
5. W Docker → Add Container wybierz szablon `pinkcollab-omp`. Obraz: `ghcr.io/elmakus/pinkcollab-omp:latest`.
6. Skonfiguruj **HTTPS reverse proxy** do `http://IP_UNRAID:18788`. Proxy musi wspierać WebSocket i przekazywać nagłówek Authorization. Nie przekierowuj portu 18788 z Internetu.
7. Sparuj telefon (podstaw własny HTTPS URL):

```sh
docker exec -it pinkcollab-omp pinkcollab pair --url https://pink.example.com
```

PinkCollab Gateway uruchamia OMP lokalnie na żądanie; w pojedynczym kontenerze nie potrzebujesz drugiego demona OMP.

## Dane, logowanie i diagnostyka

- `/mnt/user/appdata/pinkcollab-omp/omp` → `/home/agent/.omp` (sesje, modele, klucze)
- `/mnt/user/appdata/pinkcollab-omp/gateway` → `/home/agent/.pinkcollab` (sparowania)
- `/mnt/user/appdata/pinkcollab-omp/workspace` → `/workspace` (pliki robocze)

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
- Do HTTPS wystarczy lokalny reverse proxy i dostęp przez LAN/UniFi Teleport; nie trzeba wystawiać gatewaya publicznie.

## Upstream

- [OMP](https://github.com/can1357/oh-my-pi)
- [PinkCollab](https://github.com/3xian/PinkCollab)
- [PinkCollab deployment](https://github.com/3xian/PinkCollab/blob/main/docs/deployment.md)
