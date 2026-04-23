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

```bash
# 1. 에뮬레이터 연결 확인
sdb devices
# 출력: emulator-26101    device    T-10.0-x86_64

# 2. root 모드 활성화
sdb -e root on

# 3. RPM push
sdb -e push /home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS/systemd-244-0.x86_64.rpm /tmp/
sdb -e push /home/choyj/GBS-ROOT/local/repos/tizen/x86_64/RPMS/libsystemd-244-0.x86_64.rpm /tmp/

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

```bash
# SIGRTMIN 값 확인 (에뮬레이터에서 34 → SIGRTMIN+30=64)
sdb -e shell "python3 -c 'import signal; print(signal.SIGRTMIN)'"

# SIGRTMIN+30 = 64 → systemd PID 1에 전송 (gcda 파일 기록)
sdb -e shell "kill -64 1"

# gcda 파일 생성 확인
sdb -e shell "find /tmp/_build -name '*.gcda' -path '*/core/*' | head -5"
# 기대 출력:
# /tmp/_build/src/core/libcore.a.p/automount.c.gcda
# ...

# 전체 gcda 수량 확인 (345개 예상)
sdb -e shell "find /tmp/_build -name '*.gcda' | wc -l"

# 호스트로 수집
mkdir -p /home/choyj/workspace/systemd-optimization/gcov-data
sdb -e pull /tmp/_build /home/choyj/workspace/systemd-optimization/gcov-data/
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

### gcda 파일을 gcno 경로에 복사

```bash
GCNO_BASE=/home/choyj/GBS-ROOT/local/BUILD-ROOTS/scratch.x86_64.0/home/abuild/rpmbuild/BUILD/systemd-244/_build
GCDA_BASE=/home/choyj/workspace/systemd-optimization/gcov-data

find "${GCDA_BASE}" -name '*.gcda' | while read gcda; do
    rel="${gcda#${GCDA_BASE}/}"
    dest="${GCNO_BASE}/${rel}"
    mkdir -p "$(dirname "${dest}")"
    cp "${gcda}" "${dest}"
done
```

### lcov 실행

```bash
LCOV=/tmp/lcov-extracted/usr/bin/lcov
GENHTML=/tmp/lcov-extracted/usr/bin/genhtml
GCNO_BASE=/home/choyj/GBS-ROOT/local/BUILD-ROOTS/scratch.x86_64.0/home/abuild/rpmbuild/BUILD/systemd-244/_build
OUT=/home/choyj/workspace/systemd-optimization/coverage-report
mkdir -p "${OUT}"

# coverage.info 생성
perl "${LCOV}" \
    --gcov-tool /tmp/gcov-wrapper.sh \
    --capture \
    --directory "${GCNO_BASE}" \
    --output-file "${OUT}/coverage.info" \
    --ignore-errors source,gcov

# HTML 리포트 생성
perl "${GENHTML}" \
    "${OUT}/coverage.info" \
    --output-directory "${OUT}/html" \
    --legend --show-details \
    --ignore-errors source \
    --prefix /home/abuild/rpmbuild/BUILD/systemd-244

# 결과: Overall coverage rate: lines 20.9%, functions 28.4%
```

### 0% 파일 목록 추출

```bash
# 전체 0% 파일
perl "${LCOV}" --list "${OUT}/coverage.info" 2>/dev/null | grep "0\.0%" \
    > "${OUT}/uncovered-all.txt"

# core 디렉토리 0% 파일 (25개)
perl "${LCOV}" --list "${OUT}/coverage.info" 2>/dev/null | grep "0\.0%" | grep "src/core" \
    > "${OUT}/uncovered-core.txt"
```

**측정 결과 (2026-04-23 기준):**
- 전체 라인 커버리지: **20.9%** (24,564 / 117,674 lines)
- 전체 함수 커버리지: **28.4%** (1,930 / 6,800 functions)
- core 디렉토리 0% 파일: **25개**

주요 미실행 core 파일:
```
src/core/bus-policy.c       (84 lines, 5 functions)
src/core/busname.c          
src/core/chown-recursive.c  (63 lines, 3 functions)
src/core/dbus-automount.c   (20 lines, 3 functions)
src/core/dbus-mount.c       (57 lines, 10 functions)
src/core/dbus-timer.c       (168 lines, 8 functions)
src/core/dynamic-user.c     (5% 커버리지, 400 lines, 25 functions)
```

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

## 현재 진행 상태 (2026-04-23 기준)

- [x] 계획 수립
- [x] `src/core/manager.c` 패치 (SIGRTMIN+30 등록 + __gcov_dump 핸들러 + setenv)
- [x] `packaging/systemd.spec` coverage 빌드 옵션 추가
- [x] `.claude/commands/sdb.md` 커스텀 슬래시 커맨드 생성
- [x] GBS 빌드 성공 (`-Db_coverage=true` 적용 확인)
- [x] 에뮬레이터 배포 및 재부팅
- [x] gcov dump 트리거 및 gcda 수집 (345개 파일)
- [x] lcov 리포트 생성 (HTML + coverage.info)
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
