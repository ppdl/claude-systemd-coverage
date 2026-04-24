# systemd Line Coverage 측정 Runbook

AI 에이전트가 처음부터 끝까지 단독으로 실행할 수 있도록 작성된 가이드입니다.

---

## 사용자 입력값

작업 시작 전 아래 두 값을 사용자에게 확인한다.

| 변수 | 설명 | 예시 |
|------|------|------|
| `SYSTEMD_SRC` | systemd 소스코드 루트 경로 | `/home/user/workspace/systemd` |
| `DEVICE_TYPE` | 연결 대상 타입 | `emulator` 또는 `device` |

`DEVICE_TYPE`에 따라 sdb 플래그가 달라진다.
- `emulator` → `sdb -e`
- `device` → `sdb -d`

이하 가이드에서는 `SDB="sdb -e"` (emulator 기준)로 표기한다. `device`라면 `-e`를 `-d`로 바꾼다.

---

## 환경 전제조건

| 항목 | 값 |
|------|-----|
| 빌드 시스템 | GBS (Tizen GBS) |
| Coverage 도구 | gcov (GCC 14, GBS 빌드루트) / lcov 1.15 |
| 연결 도구 | sdb (Smart Development Bridge) |
| systemd 버전 | 244 |

### 변수 자동 결정

아래 셸 스크립트를 실행하여 `BUILDROOT`, `ARCH`, `RPMS`, `GCNO_BASE`를 결정한다.
이후 모든 Step에서 이 변수들을 사용한다.

**① GBS 빌드루트 기본 경로 결정**

`~/.gbs.conf`의 `[general]` 섹션에 `buildroot` 키가 있으면 그 값을 사용하고,
없으면 GBS 기본값(`~/GBS-ROOT`)을 사용한다.

```bash
GBS_CONF="${HOME}/.gbs.conf"
GBS_BUILDROOT_BASE=""

if [ -f "${GBS_CONF}" ]; then
    # [general] 섹션의 buildroot 값 추출
    GBS_BUILDROOT_BASE=$(awk '
        /^\[general\]/ { in_section=1; next }
        /^\[/          { in_section=0 }
        in_section && /^buildroot[[:space:]]*=/ {
            sub(/^buildroot[[:space:]]*=[[:space:]]*/, "")
            # ~ 를 실제 HOME 경로로 치환
            sub(/^~/, ENVIRON["HOME"])
            print; exit
        }
    ' "${GBS_CONF}")
fi

# 값이 없으면 기본 경로 사용
GBS_BUILDROOT_BASE="${GBS_BUILDROOT_BASE:-${HOME}/GBS-ROOT}"
echo "GBS buildroot base: ${GBS_BUILDROOT_BASE}"
```

**② 타겟 아키텍처 결정**

```bash
if [ "${DEVICE_TYPE}" = "emulator" ]; then
    ARCH="x86_64"
else
    # 디바이스에서 설치된 RPM의 아키텍처를 확인
    # noarch는 제외하고 aarch64, armv7l 등 실제 arch만 추출
    ARCH=$(${SDB} shell "rpm -qa | head -20" | \
        grep -oE '\.(aarch64|armv7l|armv7hl|i686|x86_64)$' | \
        sed 's/^\.//' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

    if [ -z "${ARCH}" ]; then
        echo "ERROR: 타겟 아키텍처를 자동으로 결정할 수 없습니다."
        echo "디바이스에서 'rpm -qa | head -20' 출력을 확인하고 ARCH를 수동으로 설정하세요."
        exit 1
    fi
fi
echo "Target architecture: ${ARCH}"
```

**③ 최종 경로 변수 설정**

```bash
BUILDROOT="${GBS_BUILDROOT_BASE}/local/BUILD-ROOTS/scratch.${ARCH}.0"
RPMS="${GBS_BUILDROOT_BASE}/local/repos/tizen/${ARCH}/RPMS"
GCNO_BASE="${BUILDROOT}/home/abuild/rpmbuild/BUILD/systemd-244/_build"

echo "BUILDROOT : ${BUILDROOT}"
echo "RPMS      : ${RPMS}"
echo "GCNO_BASE : ${GCNO_BASE}"
```

> **확인:** `ls "${BUILDROOT}/usr/bin/gcov"` 가 성공해야 다음 Step으로 진행 가능하다.
> 실패하면 GBS 빌드를 먼저 한 번 수행해야 빌드루트가 생성된다.

---

## Step 1: 소스 코드 패치

아래 5개 파일을 수정한다. 각 파일의 수정은 정확한 위치에 코드를 삽입하는 것이며,
기존 코드를 삭제하지 않는다.

### 1-1. `src/core/manager.c` — SIGRTMIN+30 시그널 등록

`RTSIG_IF_AVAILABLE(SIGRTMIN+29)` 바로 뒤, `-1);` 바로 앞에 아래 한 줄을 추가한다.

```c
/* 변경 전 */
RTSIG_IF_AVAILABLE(SIGRTMIN+29), /* systemd: set log target to syslog-or-kmsg (obsolete) */

/* ... one free signal here SIGRTMIN+30 ... */
-1);

/* 변경 후 */
RTSIG_IF_AVAILABLE(SIGRTMIN+29), /* systemd: set log target to syslog-or-kmsg (obsolete) */

RTSIG_IF_AVAILABLE(SIGRTMIN+30), /* systemd: dump gcov coverage data */
-1);
```

### 1-2. `src/core/manager.c` — SIGRTMIN+30 핸들러 추가

`switch (sfsi.ssi_signo - SIGRTMIN)` 블록 안의 `case 28:` 다음에 추가한다.
`Manager *m`이 스코프에 있으며, `MANAGER_IS_SYSTEM(m)` 매크로로 system/user 인스턴스를 구분한다.

```c
case 30: {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                const char *prefix = MANAGER_IS_SYSTEM(m)
                        ? "/tmp/gcov/system"
                        : "/tmp/gcov/user";
                (void) mkdir_p(prefix, 0755);
                (void) setenv("GCOV_PREFIX", prefix, 1);
                (void) setenv("GCOV_PREFIX_STRIP", "5", 1);
                __gcov_dump();
                log_info("gcov coverage data dumped to %s", prefix);
        }
        break;
}
```

> `mkdir_p`는 이미 `#include "mkdir.h"`로 포함돼 있다.
> `GCOV_PREFIX_STRIP=5`는 빌드 컨테이너 경로 `/home/abuild/rpmbuild/BUILD/systemd-244`의
> 5개 컴포넌트를 제거하여 gcda가 `<prefix>/_build/...`에 기록되게 한다.

### 1-3. `src/journal/journald-server.c` — journald 핸들러 추가

`static int dispatch_sigrtmin1(...)` 함수 정의 바로 앞에 새 함수를 추가한다.

```c
static int dispatch_sigrtmin30(sd_event_source *es, const struct signalfd_siginfo *si, void *userdata) {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                (void) mkdir_p("/tmp/gcov/journald", 0755);
                (void) setenv("GCOV_PREFIX", "/tmp/gcov/journald", 1);
                (void) setenv("GCOV_PREFIX_STRIP", "5", 1);
                __gcov_dump();
                log_info("gcov coverage data dumped to /tmp/gcov/journald");
        }
        return 0;
}
```

같은 파일의 `sigprocmask_many` 호출에 `SIGRTMIN+30`을 추가한다.

```c
/* 변경 전 */
assert_se(sigprocmask_many(SIG_SETMASK, NULL, SIGINT, SIGTERM, SIGUSR1, SIGUSR2, SIGRTMIN+1, -1) >= 0);

/* 변경 후 */
assert_se(sigprocmask_many(SIG_SETMASK, NULL, SIGINT, SIGTERM, SIGUSR1, SIGUSR2, SIGRTMIN+1, SIGRTMIN+30, -1) >= 0);
```

`sd_event_add_signal(... SIGRTMIN+1 ...)` 등록 코드 바로 뒤에 아래를 추가한다.

```c
r = sd_event_add_signal(s->event, NULL, SIGRTMIN+30, dispatch_sigrtmin30, s);
if (r < 0)
        return r;
```

### 1-4. `src/udev/udevd.c` — udevd 핸들러 추가

`static int on_sigterm(...)` 함수 정의 바로 앞에 새 함수를 추가한다.

```c
static int on_sigrtmin30(sd_event_source *s, const struct signalfd_siginfo *si, void *userdata) {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                (void) mkdir_p("/tmp/gcov/udevd", 0755);
                (void) setenv("GCOV_PREFIX", "/tmp/gcov/udevd", 1);
                (void) setenv("GCOV_PREFIX_STRIP", "5", 1);
                __gcov_dump();
                log_info("gcov coverage data dumped to /tmp/gcov/udevd");
        }
        return 1;
}
```

`sigprocmask_many(SIG_BLOCK, ...)` 호출에 `SIGRTMIN+30`을 추가한다.

```c
/* 변경 전 */
assert_se(sigprocmask_many(SIG_BLOCK, NULL, SIGTERM, SIGINT, SIGHUP, SIGCHLD, -1) >= 0);

/* 변경 후 */
assert_se(sigprocmask_many(SIG_BLOCK, NULL, SIGTERM, SIGINT, SIGHUP, SIGCHLD, SIGRTMIN+30, -1) >= 0);
```

`sd_event_add_signal(... SIGCHLD ...)` 등록 코드 바로 뒤에 추가한다.

```c
r = sd_event_add_signal(manager->event, NULL, SIGRTMIN+30, on_sigrtmin30, manager);
if (r < 0)
        return log_error_errno(r, "Failed to create SIGRTMIN+30 event source: %m");
```

### 1-5. `src/login/logind.c` — logind 핸들러 추가

> **주의:** `systemd-logind.service`는 `PrivateTmp=yes`로 실행되므로 자신의 `/tmp`가
> 시스템 `/tmp`와 격리된다. gcda 출력 경로를 `/run/gcov/logind`로 설정해야
> 호스트에서 수집 가능하다.

파일 상단 include 블록에 `mkdir.h`를 추가한다.

```c
#include "mkdir.h"
```

`static int manager_dispatch_reload_signal(...)` 함수 정의 바로 앞에 추가한다.

```c
static int manager_dispatch_gcov_signal(sd_event_source *s, const struct signalfd_siginfo *si, void *userdata) {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                (void) mkdir_p("/run/gcov/logind", 0755);
                (void) setenv("GCOV_PREFIX", "/run/gcov/logind", 1);
                (void) setenv("GCOV_PREFIX_STRIP", "5", 1);
                __gcov_dump();
                log_info("gcov coverage data dumped to /run/gcov/logind");
        }
        return 0;
}
```

`sigprocmask_many(SIG_BLOCK, ...)` 호출에 `SIGRTMIN+30`을 추가한다.

```c
/* 변경 전 */
assert_se(sigprocmask_many(SIG_BLOCK, NULL, SIGHUP, SIGTERM, SIGINT, SIGCHLD, -1) >= 0);

/* 변경 후 */
assert_se(sigprocmask_many(SIG_BLOCK, NULL, SIGHUP, SIGTERM, SIGINT, SIGCHLD, SIGRTMIN+30, -1) >= 0);
```

`manager_startup()` 함수 안의 `sd_event_add_signal(... SIGHUP ...)` 바로 뒤에 추가한다.

```c
r = sd_event_add_signal(m->event, NULL, SIGRTMIN+30, manager_dispatch_gcov_signal, m);
if (r < 0)
        return log_error_errno(r, "Failed to register SIGRTMIN+30 handler: %m");
```

### 1-6. `packaging/systemd.spec` — coverage 빌드 옵션 추가

`%meson` 섹션에서 `-Db_pie=true` 바로 앞에 아래 블록을 추가한다.

```spec
%if 0%{?WITH_COVERAGE}
-Db_coverage=true \
%endif
```

최종 형태:
```spec
-Dinstall-tests=true \
-Ddefault-hierarchy=legacy \
%if 0%{?WITH_COVERAGE}
-Db_coverage=true \
%endif
-Db_pie=true
%meson_build
```

> `-Db_coverage=true \` 끝에 역슬래시(`\`)가 있으면 안 된다. `%meson_build`가 같은 줄에 이어져
> 빌드가 실패한다. 반드시 `%endif` 다음 줄에 `-Db_pie=true`가 오도록 배치한다.

---

## Step 2: GBS 빌드

```bash
cd "${SYSTEMD_SRC}"
gbs build -A "${ARCH}" --define 'WITH_COVERAGE 1' --include-all
```

- `-A "${ARCH}"`: 환경 전제조건에서 결정된 타겟 아키텍처 사용
- `--include-all`: 미커밋 변경사항을 빌드에 포함
- `--define 'WITH_COVERAGE 1'`: spec 파일의 `%if 0%{?WITH_COVERAGE}` 조건 활성화

빌드 성공 확인:
```bash
grep "b_coverage" "${GBS_BUILDROOT_BASE}/local/repos/tizen/${ARCH}/logs/success/systemd-244-0/log.txt"
# 출력에 "b_coverage : true" 가 있어야 한다
```

---

## Step 3: 디바이스 배포

### 3-1. 바이너리 해시 검사

디바이스에 설치된 systemd가 현재 빌드한 coverage 버전인지 확인한다.
스냅샷 복원 등으로 인해 이전 버전이 남아 있을 수 있다.

```bash
# 빌드 RPM에서 바이너리 추출
mkdir -p /tmp/rpm-check
rpm2cpio "${RPMS}/systemd-244-0.${ARCH}.rpm" | \
    cpio -id --quiet './usr/lib/systemd/systemd' -D /tmp/rpm-check/
RPM_HASH=$(md5sum /tmp/rpm-check/usr/lib/systemd/systemd | awk '{print $1}')
rm -rf /tmp/rpm-check

# 디바이스 바이너리 해시
DEV_HASH=$(${SDB} shell "md5sum /usr/lib/systemd/systemd" | awk '{print $1}')

if [ "${RPM_HASH}" = "${DEV_HASH}" ]; then
    echo "해시 일치 → 재배포 불필요, Step 4로 이동"
else
    echo "해시 불일치 → Step 3-2 진행"
fi
```

### 3-2. RPM 설치 및 재부팅 (해시 불일치 시)

```bash
# root 활성화
${SDB} root on

# RPM 전송
${SDB} push "${RPMS}/libsystemd-244-0.${ARCH}.rpm" /tmp/
${SDB} push "${RPMS}/systemd-244-0.${ARCH}.rpm" /tmp/

# 설치
${SDB} shell "rpm -Uvh --force /tmp/libsystemd-244-0.${ARCH}.rpm /tmp/systemd-244-0.${ARCH}.rpm"

# 재부팅
${SDB} shell "reboot"
sdb wait-for-device && ${SDB} root on
```

---

## Step 4: gcov dump 트리거 및 gcda 수집

### 4-1. 부팅 후 1분 대기

systemd 부팅 초기화(target 활성화, 서비스 시작)가 완전히 끝난 후 측정해야
부팅 시 실행되는 코드 경로가 gcda에 반영된다.

```bash
sdb wait-for-device && ${SDB} root on
echo "부팅 완료: $(date)"
sleep 60
echo "1분 경과: $(date)"
```

### 4-2. 측정 대상 프로세스 및 gcda 출력 경로

| 프로세스 | 신호 대상 | gcda 수집 경로 |
|---------|----------|--------------|
| `systemd` (PID 1, system 인스턴스) | `kill -64 1` | `/tmp/gcov/system/_build/` |
| `systemd --user` (user 세션) | `kill -64 <pid>` | `/tmp/gcov/user/_build/` |
| `systemd-journald` | `kill -64 <pid>` | `/tmp/gcov/journald/_build/` |
| `systemd-udevd` | `kill -64 <pid>` | `/tmp/gcov/udevd/_build/` |
| `systemd-logind` | `kill -64 <pid>` | `/run/gcov/logind/_build/` |

> **신호 번호:** SIGRTMIN=34이므로 SIGRTMIN+30=64. `kill -64 <pid>`로 전송한다.
>
> **systemd --user:** 같은 바이너리가 `--user` 플래그로 실행된 별도 프로세스다.
> `pgrep -f 'systemd --user'`로 PID를 찾는다. 사용자 세션이 없으면 프로세스가 없을 수 있다.
>
> **logind PrivateTmp:** `systemd-logind`는 `PrivateTmp=yes`로 실행되어 `/tmp`가 격리된다.
> gcda는 `/run/gcov/logind/`에 기록된다(`/run`은 격리되지 않음).

### 4-3. 신호 전송

```bash
# system (PID 1)
${SDB} shell "kill -64 1"

# journald
${SDB} shell "kill -64 \$(pgrep systemd-journald)"

# udevd
${SDB} shell "kill -64 \$(pgrep systemd-udevd)"

# logind
${SDB} shell "kill -64 \$(pgrep systemd-logind)"

# systemd --user (실행 중일 경우만)
${SDB} shell "pgrep -f 'systemd --user' | xargs -r kill -64"
```

### 4-4. gcda 생성 확인

```bash
${SDB} shell "
for p in system user journald udevd; do
    echo \"\$p: \$(find /tmp/gcov/\$p -name '*.gcda' 2>/dev/null | wc -l) gcda\"
done
echo \"logind: \$(find /run/gcov/logind -name '*.gcda' 2>/dev/null | wc -l) gcda\"
"
```

각 프로세스가 정상 동작했다면 아래와 비슷한 수의 gcda 파일이 생성된다.

| 프로세스 | 예상 gcda 수 |
|---------|------------|
| system | ~300 |
| journald | ~250 |
| udevd | ~260 |
| logind | ~260 |

### 4-5. 호스트로 수집

```bash
GCOV_HOST="${SYSTEMD_SRC}/../gcov-data-multi"
rm -rf "${GCOV_HOST}" && mkdir -p "${GCOV_HOST}"

for proc in system user journald udevd; do
    mkdir -p "${GCOV_HOST}/${proc}"
    ${SDB} pull "/tmp/gcov/${proc}/_build" "${GCOV_HOST}/${proc}/" 2>/dev/null
done

# logind: /run/gcov/logind 에서 수집
mkdir -p "${GCOV_HOST}/logind"
${SDB} pull "/run/gcov/logind/_build" "${GCOV_HOST}/logind/" 2>/dev/null
```

---

## Step 5: lcov 도구 준비

GBS 빌드루트의 GCC 14 gcov를 사용해야 한다. 호스트 gcov와 버전이 달라서
직접 실행할 수 없으므로 dynamic linker를 통해 실행하는 래퍼 스크립트를 만든다.

```bash
# gcov 래퍼 (환경 전제조건에서 결정된 BUILDROOT 변수 사용)
cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec "${BUILDROOT}/lib64/ld-linux-x86-64.so.2" \\
    --library-path "${BUILDROOT}/usr/lib64:${BUILDROOT}/lib64" \\
    "${BUILDROOT}/usr/bin/gcov" "\$@"
EOF
chmod +x /tmp/gcov-wrapper.sh

# lcov 설치 (sudo 없이 deb 직접 추출)
cd /tmp && apt-get download lcov
dpkg-deb -x /tmp/lcov_1.15-1_all.deb /tmp/lcov-extracted/
```

---

## Step 6: lcov 리포트 생성

```bash
LCOV=/tmp/lcov-extracted/usr/bin/lcov
GENHTML=/tmp/lcov-extracted/usr/bin/genhtml
GCNO_BASE=${BUILDROOT}/home/abuild/rpmbuild/BUILD/systemd-244/_build
GCOV_HOST="${SYSTEMD_SRC}/../gcov-data-multi"
OUT="${SYSTEMD_SRC}/../coverage-report"
mkdir -p "${OUT}"
```

### 6-1. baseline 생성

컴파일됐으나 한 번도 실행되지 않은 파일도 0%로 리포트에 포함시킨다.

```bash
perl "${LCOV}" \
    --gcov-tool /tmp/gcov-wrapper.sh \
    --capture --initial \
    --directory "${GCNO_BASE}" \
    --output-file "${OUT}/baseline.info" \
    --ignore-errors source,gcov
```

### 6-2. 프로세스별 coverage.info 생성

```bash
for proc in system journald udevd logind; do
    # 해당 프로세스의 gcda를 gcno 위치에 복사
    find "${GCNO_BASE}" -name '*.gcda' -delete
    find "${GCOV_HOST}/${proc}" -name '*.gcda' | while read gcda; do
        rel="${gcda#${GCOV_HOST}/${proc}/}"
        dest="${GCNO_BASE}/${rel}"
        mkdir -p "$(dirname "${dest}")"
        cp "${gcda}" "${dest}"
    done

    perl "${LCOV}" \
        --gcov-tool /tmp/gcov-wrapper.sh \
        --capture \
        --directory "${GCNO_BASE}" \
        --output-file "${OUT}/${proc}.info" \
        --ignore-errors source,gcov
done
```

> `systemd --user` gcda가 수집됐다면 `for` 루프에 `user`도 추가한다.

### 6-3. 경로 치환

GBS 빌드 컨테이너 내부 경로(`/home/abuild/rpmbuild/BUILD/systemd-244/`)가
coverage.info의 `SF:` 라인에 기록돼 있다. 호스트에 이 경로가 없으므로
실제 소스 경로로 치환해야 HTML에서 소스 코드가 표시된다.

```bash
for proc in baseline system journald udevd logind; do
    sed "s|SF:/home/abuild/rpmbuild/BUILD/systemd-244/|SF:${SYSTEMD_SRC}/|g" \
        "${OUT}/${proc}.info" > "${OUT}/${proc}-fixed.info"
done
```

### 6-4. 전체 합산

```bash
perl "${LCOV}" \
    --add-tracefile "${OUT}/baseline-fixed.info" \
    --add-tracefile "${OUT}/system-fixed.info" \
    --add-tracefile "${OUT}/journald-fixed.info" \
    --add-tracefile "${OUT}/udevd-fixed.info" \
    --add-tracefile "${OUT}/logind-fixed.info" \
    --output-file "${OUT}/combined.info" \
    --ignore-errors source
```

### 6-5. HTML 리포트 생성

```bash
rm -rf "${OUT}/html"
perl "${GENHTML}" \
    "${OUT}/combined.info" \
    --output-directory "${OUT}/html" \
    --legend --show-details \
    --ignore-errors source \
    --prefix "${SYSTEMD_SRC}"
```

---

## Step 7: 결과 확인

```bash
# 전체 커버리지 요약
perl "${LCOV}" --list "${OUT}/combined.info" 2>/dev/null | tail -3

# 0% 파일 목록 (src/core 기준)
perl "${LCOV}" --list "${OUT}/combined.info" 2>/dev/null \
    | grep "0\.0%" | grep "src/core"

# HTML 리포트 경로
echo "HTML report: ${OUT}/html/index.html"
```

정상 측정 시 예상 결과 (Tizen 10.0, 멀티 프로세스 기준):

| 항목 | 값 |
|------|-----|
| 소스 파일 수 | ~921개 |
| 라인 커버리지 | ~20% |
| 함수 커버리지 | ~28% |

---

## 참고: 컴파일되지 않는 파일

아래 파일들은 Tizen 빌드 설정상 gcno 파일 자체가 생성되지 않아 coverage 측정이 불가하다.
이는 정상이며, 해당 기능들이 Tizen에서 비활성화된 것을 의미한다.

| 분류 | 예시 | 이유 |
|------|------|------|
| EFI 부트로더 | `src/boot/efi/` | UEFI 전용 툴체인으로 별도 빌드 |
| 테스트 바이너리 | `src/test/`, `src/*/test-*.c` | RPM 배포 대상 아님 |
| 비활성화된 기능 | `src/resolve/`, `src/network/netdev/`, `src/coredump/` 등 | Tizen meson 옵션으로 비활성화 |
