# Tizen systemd Coverage Measurement Guide

## 목적

타이젠 에뮬레이터에서 systemd의 gcov code coverage를 측정하여 실행되지 않는 코드를 파악하고,
해당 코드를 제거/비활성화하여 메모리 사용량을 최적화한다.

---

## 환경

| 항목 | 값 |
|------|-----|
| 빌드 시스템 | GBS 2.0.6 |
| 타이젠 버전 | Tizen 10.0 |
| 에뮬레이터 | T-10.0-x86_64 (sdb serial: emulator-26101) |
| 연결 방법 | sdb (Smart Development Bridge) |
| Coverage 도구 | gcov / lcov |
| systemd 버전 | 244 |
| 소스 경로 | `/home/choyj/workspace/systemd-optimization/systemd/` |

---

## Step 1: 소스 코드 패치

### 1-1. SIGRTMIN+30 시그널 등록

파일: `src/core/manager.c` (line ~548)

`SIGRTMIN+25 ~ SIGRTMIN+29` 뒤에 아래를 추가:

```c
RTSIG_IF_AVAILABLE(SIGRTMIN+30), /* systemd: dump gcov coverage data */
```

**변경 전:**
```c
RTSIG_IF_AVAILABLE(SIGRTMIN+29), /* systemd: set log target to syslog-or-kmsg (obsolete) */

/* ... one free signal here SIGRTMIN+30 ... */
-1);
```

**변경 후:**
```c
RTSIG_IF_AVAILABLE(SIGRTMIN+29), /* systemd: set log target to syslog-or-kmsg (obsolete) */

RTSIG_IF_AVAILABLE(SIGRTMIN+30), /* systemd: dump gcov coverage data */
-1);
```

### 1-2. SIGRTMIN+30 핸들러 추가

파일: `src/core/manager.c` (line ~2843, `switch (sfsi.ssi_signo - SIGRTMIN)` 블록 내부)

`case 28:` 다음에 추가:

```c
case 30: {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                __gcov_dump();
                log_info("gcov coverage data dumped to .gcda files.");
        }
        break;
}
```

> **왜 weak symbol인가:** GCC는 `-fprofile-arcs` 플래그를 주더라도 `__GCOV__` 매크로를 자동 정의하지 않는다.
> `__attribute__((weak))`로 선언하면 coverage 빌드일 때는 libgcov의 실제 구현이 링크되고,
> 일반 빌드일 때는 NULL이 되어 조건 분기로 안전하게 처리된다.

> **왜 SIGUSR2가 아닌 SIGRTMIN+30인가:** systemd에서 SIGUSR1(D-Bus 재연결), SIGUSR2(상태 덤프)는 이미 사용 중이다.
> SIGRTMIN+30은 주석("one free signal")으로 명시된 빈 슬롯이다.
> (SIGRTMIN=34, SIGRTMAX=64, SIGRTMIN+30=64=SIGRTMAX)

### 1-3. spec 파일에 coverage 빌드 옵션 추가

파일: `packaging/systemd.spec` (line ~284, `%meson` 섹션 내부)

```spec
-Dinstall-tests=true \
-Ddefault-hierarchy=legacy \
%if 0%{?WITH_COVERAGE}
-Db_coverage=true \
%endif
-Db_pie=true
%meson_build
```

> **주의:** `-Db_coverage=true \` 뒤에 trailing backslash가 있으면 안 된다.
> `%meson_build`가 같은 줄로 연결되어 meson setup 명령에 `compile` 서브커맨드가 붙어버린다.
> coverage 옵션을 마지막(-Db_pie=true)보다 앞에 배치하여 해결한다.

---

## Step 2: GBS 빌드

```bash
cd /home/choyj/workspace/systemd-optimization/systemd

# --include-all: 미커밋 변경사항 포함
# --define 'WITH_COVERAGE 1': spec 파일의 %if 0%{?WITH_COVERAGE} 조건 활성화
gbs build -A x86_64 --define 'WITH_COVERAGE 1' --include-all
```

빌드 결과 RPM 위치:
```
/home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS/
├── systemd-244-0.x86_64.rpm          # 메인 패키지 (systemd 바이너리)
├── libsystemd-244-0.x86_64.rpm       # 공유 라이브러리
├── systemd-debuginfo-244-0.x86_64.rpm
└── ...
```

빌드 성공 확인:
```bash
grep "b_coverage" /home/choyj/GBS-ROOT/local/repos/tizen/x86_64/logs/success/systemd-244-0/log.txt
# 출력: ... -Db_coverage=true -Db_pie=true
#        b_coverage : true
```

---

## Step 3: 에뮬레이터 배포

### 3-1. 바이너리 해시 검사 (재배포 필요 여부 판단)

coverage 측정 전에 반드시 에뮬레이터의 systemd 바이너리가 빌드된 RPM과 동일한지 확인한다.
에뮬레이터가 스냅샷에서 복원되거나 재설치된 경우 이전 coverage 빌드가 사라질 수 있다.

```bash
RPMS=/home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS

# 빌드 RPM에서 systemd 바이너리 추출하여 해시 계산
mkdir -p /tmp/rpm-check
rpm2cpio "${RPMS}/systemd-244-0.x86_64.rpm" | \
    cpio -id --quiet './usr/lib/systemd/systemd' -D /tmp/rpm-check/
RPM_HASH=$(md5sum /tmp/rpm-check/usr/lib/systemd/systemd | awk '{print $1}')

# 에뮬레이터 바이너리 해시 계산
EMU_HASH=$(sdb -e shell "md5sum /usr/lib/systemd/systemd" | awk '{print $1}')

echo "RPM 해시: ${RPM_HASH}"
echo "에뮬: ${EMU_HASH}"

if [ "${RPM_HASH}" = "${EMU_HASH}" ]; then
    echo "OK: 해시 일치 → 재배포 불필요"
else
    echo "MISMATCH: 해시 불일치 → Step 3-2 진행"
fi
```

### 3-2. RPM 설치 (해시 불일치 시에만)

```bash
RPMS=/home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS

# 1. 에뮬레이터 연결 확인
sdb devices
# 출력: emulator-26101    device    T-10.0-x86_64

# 2. root 모드 활성화
sdb -e root on

# 3. RPM push
sdb -e push "${RPMS}/systemd-244-0.x86_64.rpm" /tmp/
sdb -e push "${RPMS}/libsystemd-244-0.x86_64.rpm" /tmp/

# 4. 설치
sdb -e shell "rpm -Uvh --force /tmp/libsystemd-244-0.x86_64.rpm /tmp/systemd-244-0.x86_64.rpm"

# 5. 재부팅
sdb -e shell "reboot"
sdb wait-for-device && sdb -e root on
```

---

## Step 4: gcov 데이터 경로 설정

### 문제 및 해결 과정

gcov 계측은 정상 적용됨. 바이너리 내부에 gcda 경로 문자열이 존재:
```
/home/abuild/rpmbuild/BUILD/systemd-244/_build/systemd.p/src_core_main.c.gcda
```

에뮬레이터에 `/home/abuild/...` 경로가 없어 PID 1이 gcda를 기록하지 못함.

**시도 1 (실패):** `DefaultEnvironment`는 자식 프로세스에만 적용되고 PID 1 자신에게는 미적용:
```bash
sdb -e shell "printf '[Manager]\nDefaultEnvironment=GCOV_PREFIX=/tmp GCOV_PREFIX_STRIP=5\n' \
    > /etc/systemd/system.conf.d/gcov.conf"
```

**해결책:** 시그널 핸들러 내부에서 직접 `setenv()` 호출 (`src/core/manager.c`):
```c
case 30: {
        extern void __gcov_dump(void) __attribute__((weak));
        if (__gcov_dump) {
                (void) setenv("GCOV_PREFIX", "/tmp", 1);
                (void) setenv("GCOV_PREFIX_STRIP", "5", 1);
                __gcov_dump();
                log_info("gcov coverage data dumped to .gcda files.");
        }
        break;
}
```

`__gcov_dump()` 호출 직전에 `GCOV_PREFIX=/tmp`를 설정하면 gcda 파일이 `/tmp/_build/...`에 기록됨.
(`GCOV_PREFIX_STRIP=5`는 `/home/abuild/rpmbuild/BUILD/systemd-244` 5개 경로 컴포넌트를 제거)

---

## Step 5: gcov dump 트리거 및 수집

> **중요:** 부팅 완료 후 1분 대기 후 dump를 트리거한다.
> 이유: systemd가 부팅 초기화(target 활성화, 서비스 시작 등)를 모두 완료한 뒤의
> coverage를 측정해야 부팅 시 실행되는 코드 경로를 빠짐없이 수집할 수 있다.

### 측정 대상 프로세스

| 프로세스 | 핸들러 위치 | gcda 출력 경로 |
|---------|------------|--------------|
| `systemd` (PID 1, system) | `src/core/manager.c` case 30 | `/tmp/gcov/system/` |
| `systemd --user` (user session) | `src/core/manager.c` case 30 | `/tmp/gcov/user/` |
| `systemd-journald` | `src/journal/journald-server.c` | `/tmp/gcov/journald/` |
| `systemd-udevd` | `src/udev/udevd.c` | `/tmp/gcov/udevd/` |
| `systemd-logind` | `src/login/logind.c` | `/run/gcov/logind/` (PrivateTmp=yes 우회) |

> **logind 주의:** `systemd-logind.service`는 `PrivateTmp=yes`로 실행되어 자신의 `/tmp`가
> 시스템 `/tmp`와 격리된다. 따라서 logind의 gcda 경로는 `/run/gcov/logind`를 사용한다.

```bash
# 부팅 완료 확인 후 1분 대기
sdb wait-for-device && sdb -e root on
echo "부팅 완료: $(date), 1분 대기 시작"
sleep 60
echo "1분 경과: $(date)"

# 각 프로세스 PID 확인
sdb -e shell "pgrep -la 'systemd$|systemd-journald|systemd-udevd|systemd-logind'"

# SIGRTMIN+30 = 64 → 각 프로세스에 전송
sdb -e shell "kill -64 1"                          # systemd (system)
sdb -e shell "kill -64 \$(pgrep systemd-journald)" # journald
sdb -e shell "kill -64 \$(pgrep systemd-udevd)"    # udevd
sdb -e shell "kill -64 \$(pgrep systemd-logind)"   # logind
# systemd --user: 실행 중일 경우
sdb -e shell "pgrep -f 'systemd --user' | xargs -r kill -64"

# gcda 파일 생성 확인
sdb -e shell "for p in system user journald udevd; do
    echo \"\$p: \$(find /tmp/gcov/\$p -name '*.gcda' 2>/dev/null | wc -l) gcda\"
done"
sdb -e shell "echo \"logind: \$(find /run/gcov/logind -name '*.gcda' 2>/dev/null | wc -l) gcda\""

# 호스트로 수집
GCOV_HOST=/home/choyj/workspace/systemd-optimization/gcov-data-multi
rm -rf "${GCOV_HOST}" && mkdir -p "${GCOV_HOST}"

for proc in system user journald udevd; do
    mkdir -p "${GCOV_HOST}/${proc}"
    sdb -e pull "/tmp/gcov/${proc}/_build" "${GCOV_HOST}/${proc}/" 2>/dev/null
done

# logind: /run/gcov/logind 에서 수집
mkdir -p "${GCOV_HOST}/logind"
sdb -e pull "/run/gcov/logind/_build" "${GCOV_HOST}/logind/" 2>/dev/null
```

---

## Step 6: lcov 리포트 생성

### 사전 준비: gcov 버전 문제 해결

gcno 파일은 GCC 14 (Tizen)로 생성됐으나 호스트 gcov는 GCC 11 → 버전 불일치.
GBS 빌드 루트의 gcov를 ld 직접 실행으로 사용:

```bash
# gcov 래퍼 스크립트 생성
cat > /tmp/gcov-wrapper.sh << 'EOF'
#!/bin/bash
BUILDROOT=/home/choyj/GBS-ROOT/local/BUILD-ROOTS/scratch.x86_64.0
exec "${BUILDROOT}/lib64/ld-linux-x86-64.so.2" \
    --library-path "${BUILDROOT}/usr/lib64:${BUILDROOT}/lib64" \
    "${BUILDROOT}/usr/bin/gcov" "$@"
EOF
chmod +x /tmp/gcov-wrapper.sh

# lcov 설치 (sudo 없이 deb 추출)
cd /tmp && apt-get download lcov
dpkg-deb -x /tmp/lcov_1.15-1_all.deb /tmp/lcov-extracted/
```

### lcov 실행 (전체 재현 가이드)

> **주의:** `/home/abuild/rpmbuild/BUILD/systemd-244/` 경로가 호스트에 없으므로, 아래 순서대로 경로 치환을 포함한 방식으로 실행해야 한다.

```bash
LCOV=/tmp/lcov-extracted/usr/bin/lcov
GENHTML=/tmp/lcov-extracted/usr/bin/genhtml
GCNO_BASE=/home/choyj/GBS-ROOT/local/BUILD-ROOTS/scratch.x86_64.0/home/abuild/rpmbuild/BUILD/systemd-244/_build
SRC=/home/choyj/workspace/systemd-optimization/systemd
OUT=/home/choyj/workspace/systemd-optimization/coverage-report
GCOV_HOST=/home/choyj/workspace/systemd-optimization/gcov-data-multi
mkdir -p "${OUT}"

# 1. baseline 생성 (미실행 파일도 0%로 포함, 한 번만 실행)
perl "${LCOV}" \
    --gcov-tool /tmp/gcov-wrapper.sh \
    --capture --initial \
    --directory "${GCNO_BASE}" \
    --output-file "${OUT}/baseline.info" \
    --ignore-errors source,gcov

# 2. 프로세스별 coverage.info 생성
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

# 3. 경로 치환 (/home/abuild/... → 실제 소스 경로)
for proc in baseline system journald udevd logind; do
    sed "s|SF:/home/abuild/rpmbuild/BUILD/systemd-244/|SF:${SRC}/|g" \
        "${OUT}/${proc}.info" > "${OUT}/${proc}-fixed.info"
done

# 4. baseline + 전체 프로세스 합산
perl "${LCOV}" \
    --add-tracefile "${OUT}/baseline-fixed.info" \
    --add-tracefile "${OUT}/system-fixed.info" \
    --add-tracefile "${OUT}/journald-fixed.info" \
    --add-tracefile "${OUT}/udevd-fixed.info" \
    --add-tracefile "${OUT}/logind-fixed.info" \
    --output-file "${OUT}/combined.info" \
    --ignore-errors source

# 5. HTML 리포트 생성
rm -rf "${OUT}/html"
perl "${GENHTML}" \
    "${OUT}/combined.info" \
    --output-directory "${OUT}/html" \
    --legend --show-details \
    --ignore-errors source \
    --prefix "${SRC}"
```

### 왜 /home/abuild/... 경로인가

gcno 파일은 GBS 빌드 컨테이너 내부 경로(`/home/abuild/rpmbuild/BUILD/systemd-244/`)를 절대경로로 저장한다.
호스트에는 이 경로가 존재하지 않으므로 (`sudo mkdir /home/abuild`가 필요하고 불편), 
coverage.info의 `SF:` 라인을 `sed`로 일괄 치환하는 방식을 사용한다.

### 0% 파일 목록 추출

```bash
# core 디렉토리 0% 파일
perl "${LCOV}" --list "${OUT}/combined.info" 2>/dev/null | grep "0\.0%" | grep "src/core"
```

**측정 결과 (2026-04-24 기준, 멀티 프로세스 측정):**
- 소스 파일 수: **921개** (SF 기준, 중복 제거)
- 전체 라인 커버리지: **20.2%** (38,675 / 191,220 lines)
- 전체 함수 커버리지: **27.8%** (2,970 / 10,685 functions)
- 프로세스별 gcda 파일 수: system 304개, journald 254개, udevd 267개, logind 260개

| 측정 방식 | 라인 커버리지 | 함수 커버리지 |
|----------|-------------|-------------|
| PID 1만 (단일) | 14.5% | 21.0% |
| **멀티 프로세스** | **20.2%** | **27.8%** |

**참고: 컴파일되지 않은 201개 파일 (gcno 없음)**
- `src/boot/efi/` (11개): UEFI 전용 툴체인, 일반 Linux 바이너리 아님
- `src/test/`, `src/*/test-*.c` (~30개): RPM에 미포함 테스트 바이너리
- `src/resolve/`, `src/network/netdev/`, `src/coredump/`, `src/import/` 등 (~160개): Tizen meson 설정에서 비활성화된 데몬/기능

---

## Step 7: 미사용 코드 제거

| 상황 | 처리 방법 |
|------|-----------|
| meson 옵션이 이미 있는 기능 | `systemd.spec`에 `-Dfeature=false` 추가 |
| 옵션 없는 타이젠 불필요 기능 | `meson_options.txt`에 옵션 추가 후 `#if` 처리 |
| 소수의 독립 함수 | `#ifndef TIZEN_NO_<FEATURE>` 구문 |

```bash
# 최적화 전/후 메모리 비교
sdb -e shell "cat /proc/1/status | grep -E 'VmRSS|VmSize|VmPeak'"
```

---

## 현재 진행 상태 (2026-04-24 기준)

- [x] 계획 수립
- [x] `src/core/manager.c` 패치 (SIGRTMIN+30 등록 + __gcov_dump 핸들러 + setenv)
- [x] `packaging/systemd.spec` coverage 빌드 옵션 추가
- [x] `.claude/commands/sdb.md` 커스텀 슬래시 커맨드 생성
- [x] GBS 빌드 성공 (`-Db_coverage=true` 적용 확인)
- [x] 에뮬레이터 배포 및 재부팅
- [x] gcov dump 트리거 및 gcda 수집 (345개 파일)
- [x] lcov 리포트 생성 (HTML + coverage.info)
- [x] coverage 리포트 수정 (경로 치환 + baseline 추가 → `/* EOF */` 해결, 누락 파일 추가)
- [x] 부팅 후 1분 대기 후 재측정 (라인 14.5%, 함수 21.0%)
- [x] 멀티 프로세스 coverage 측정 구현 (journald, udevd, logind 핸들러 추가)
- [x] 멀티 프로세스 측정 결과: 라인 20.2%, 함수 27.8%
- [ ] 미사용 코드 분석 및 제거 ← 다음 단계

---

## 관련 파일 경로

| 파일 | 설명 |
|------|------|
| `src/core/manager.c` | SIGRTMIN+30 핸들러 (line 548, 2843) |
| `packaging/systemd.spec` | coverage 빌드 조건 (line 284) |
| `.claude/commands/sdb.md` | sdb 슬래시 커맨드 |
| `.claude/plans/systemd-purring-fairy.md` | 전체 계획 파일 |
| `/home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS/` | 빌드 결과 RPM |
