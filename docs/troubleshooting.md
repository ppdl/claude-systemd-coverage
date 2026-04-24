# Coverage Measurement Troubleshooting

이 파일은 coverage 측정 작업 중 발생한 에러와 해결 방법을 기록한다.
작업 중 에러가 발생하면 먼저 이 파일에서 동일하거나 유사한 케이스를 검색한다.

---

## 목차

1. [gcda 파일이 생성되지 않음 — PID 1 DefaultEnvironment 미적용](#1-gcda-파일이-생성되지-않음--pid-1-defaultenvironment-미적용)
2. [genhtml 소스 코드가 `/* EOF */`로 표시됨](#2-genhtml-소스-코드가-eof로-표시됨)
3. [일부 소스 파일이 HTML 리포트에 누락됨](#3-일부-소스-파일이-html-리포트에-누락됨)
4. [gcov 버전 불일치 오류](#4-gcov-버전-불일치-오류)
5. [에뮬레이터 바이너리가 coverage 빌드가 아님 (해시 불일치)](#5-에뮬레이터-바이너리가-coverage-빌드가-아님-해시-불일치)
6. [logind gcda 파일이 /tmp/gcov/logind에 생성되지 않음](#6-logind-gcda-파일이-tmpgcovlogind에-생성되지-않음)
7. [sdb wait-for-device 재부팅 후 타임아웃](#7-sdb-wait-for-device-재부팅-후-타임아웃)
8. [/tmp 도구 세션 간 초기화 (lcov, gcov 래퍼 사라짐)](#8-tmp-도구-세션-간-초기화-lcov-gcov-래퍼-사라짐)
9. [spec 파일 trailing backslash로 meson build 실패](#9-spec-파일-trailing-backslash로-meson-build-실패)
10. [멀티 프로세스 gcda 파일 충돌 (덮어쓰기)](#10-멀티-프로세스-gcda-파일-충돌-덮어쓰기)
11. [gcov 버전 감지 실패 및 "Overlong record" — armv7l 실제 디바이스 빌드](#11-gcov-버전-감지-실패-및-overlong-record--armv7l-실제-디바이스-빌드)

---

## 1. gcda 파일이 생성되지 않음 — PID 1 DefaultEnvironment 미적용

**증상:**
- SIGRTMIN+30 시그널을 보낸 후 `/tmp/_build/` 아래 gcda 파일이 생성되지 않음
- systemd journal에도 gcov dump 로그가 없음

**시도한 방법 (실패):**
`/etc/systemd/system.conf.d/gcov.conf`에 `DefaultEnvironment` 설정:
```bash
sdb -e shell "printf '[Manager]\nDefaultEnvironment=GCOV_PREFIX=/tmp GCOV_PREFIX_STRIP=5\n' \
    > /etc/systemd/system.conf.d/gcov.conf"
```
→ `DefaultEnvironment`는 systemd가 생성하는 **자식 프로세스**에만 적용되고, PID 1 자신의 환경에는 적용되지 않음.

**해결책:**
시그널 핸들러 내부에서 `setenv()`를 직접 호출하여 `__gcov_dump()` 실행 직전에 환경변수를 설정:
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
`GCOV_PREFIX_STRIP=5`는 `/home/abuild/rpmbuild/BUILD/systemd-244` (5개 컴포넌트)를 제거하여
gcda가 `${GCOV_PREFIX}/_build/...` 에 기록되게 한다.

---

## 2. genhtml 소스 코드가 `/* EOF */`로 표시됨

**증상:**
- HTML 리포트에서 모든 소스 파일의 내용이 `/* EOF */` 한 줄만 표시됨
- coverage 수치는 정상적으로 계산됨

**원인:**
gcno/gcda 파일 내부에 기록된 소스 경로가 GBS 빌드 컨테이너 내부 절대경로:
```
/home/abuild/rpmbuild/BUILD/systemd-244/src/core/manager.c
```
호스트에는 이 경로가 존재하지 않으므로 genhtml이 소스를 읽지 못함.

**시도한 방법 (실패):**
```bash
sudo mkdir -p /home/abuild/rpmbuild/BUILD/systemd-244
sudo ln -s /home/choyj/workspace/.../systemd /home/abuild/rpmbuild/BUILD/systemd-244
```
→ `/home/abuild` 생성에 root 권한 필요하고 불편함.

**해결책:**
lcov가 생성한 `coverage.info`의 `SF:` 라인을 `sed`로 치환:
```bash
sed "s|SF:/home/abuild/rpmbuild/BUILD/systemd-244/|SF:${SRC}/|g" \
    coverage.info > coverage-fixed.info
```
이후 `coverage-fixed.info`로 genhtml 실행.

---

## 3. 일부 소스 파일이 HTML 리포트에 누락됨

**증상:**
- gcno 파일은 존재하지만 gcda 파일이 없는 파일들이 HTML에 포함되지 않음
- `audit-fd.c`, `dbus-device.c`, `dbus-target.c`, `selinux-access.c` 등

**원인:**
lcov `--capture`는 gcda 파일이 있는 소스만 포함함. 실행되지 않은 파일은 gcda가 없어 리포트에서 제외됨.

**참고 — dbus-device.c, dbus-target.c:**
gcno 파일 크기가 71바이트로 계측된 코드가 없는 파일. 빌드는 됐지만 실행 가능한 브랜치가 없으므로 리포트 누락은 정상.

**해결책:**
`--capture --initial` 옵션으로 baseline을 먼저 생성하면 gcda 없는 파일도 0%로 포함됨:
```bash
perl "${LCOV}" \
    --gcov-tool /tmp/gcov-wrapper.sh \
    --capture --initial \
    --directory "${GCNO_BASE}" \
    --output-file baseline.info \
    --ignore-errors source,gcov

# 이후 실제 coverage.info와 --add-tracefile로 합산
perl "${LCOV}" \
    --add-tracefile baseline-fixed.info \
    --add-tracefile coverage-fixed.info \
    --output-file combined.info
```

---

## 4. gcov 버전 불일치 오류

**증상:**
```
gcov: version 'A85*', prefer 'A82*'
```
또는 lcov 실행 시 gcov 처리 결과가 비정상적으로 나옴.

**원인:**
- 호스트 gcov: GCC 11 (`/usr/bin/gcov`)
- gcno 파일 생성: GBS 빌드루트의 GCC 14
- gcov는 자신을 생성한 GCC 버전과 일치해야 정상 동작

**해결책:**
GBS 빌드루트의 gcov를 dynamic linker를 통해 직접 실행하는 래퍼 스크립트 사용:
```bash
cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec "${BUILDROOT}/lib64/ld-linux-x86-64.so.2" \
    --library-path "${BUILDROOT}/usr/lib64:${BUILDROOT}/lib64" \
    "${BUILDROOT}/usr/bin/gcov" "\$@"
EOF
chmod +x /tmp/gcov-wrapper.sh
```
lcov 실행 시 `--gcov-tool /tmp/gcov-wrapper.sh` 옵션으로 래퍼를 지정.

> **주의:** `/tmp/gcov-wrapper.sh`는 세션 재시작 시 삭제된다. → [항목 8 참조](#8-tmp-도구-세션-간-초기화-lcov-gcov-래퍼-사라짐)

---

## 5. 에뮬레이터 바이너리가 coverage 빌드가 아님 (해시 불일치)

**증상:**
- SIGRTMIN+30 시그널을 보내도 gcda 파일이 생성되지 않음
- `journalctl`에 "gcov coverage data dumped" 로그 없음
- 에뮬레이터를 스냅샷에서 복원하거나 재설치한 후 발생

**원인:**
에뮬레이터가 스냅샷 복원 등으로 coverage 빌드 전 상태로 되돌아가 non-coverage 바이너리가 실행 중.

**진단:**
```bash
# 빌드 RPM의 바이너리 해시
mkdir -p /tmp/rpm-check
rpm2cpio "${RPMS}/systemd-244-0.${ARCH}.rpm" | \
    cpio -id --quiet './usr/lib/systemd/systemd' -D /tmp/rpm-check/
RPM_HASH=$(md5sum /tmp/rpm-check/usr/lib/systemd/systemd | awk '{print $1}')
rm -rf /tmp/rpm-check

# 에뮬레이터 바이너리 해시
DEV_HASH=$(${SDB} shell "md5sum /usr/lib/systemd/systemd" | awk '{print $1}')

[ "${RPM_HASH}" = "${DEV_HASH}" ] && echo "일치" || echo "불일치 → RPM 재설치 필요"
```

**해결책:**
해시 불일치 시 RPM 재설치 및 재부팅:
```bash
${SDB} root on
${SDB} push "${RPMS}/libsystemd-244-0.${ARCH}.rpm" /tmp/
${SDB} push "${RPMS}/systemd-244-0.${ARCH}.rpm" /tmp/
${SDB} shell "rpm -Uvh --force /tmp/libsystemd-244-0.${ARCH}.rpm /tmp/systemd-244-0.${ARCH}.rpm"
${SDB} shell "reboot"
sdb wait-for-device && ${SDB} root on
```

---

## 6. logind gcda 파일이 /tmp/gcov/logind에 생성되지 않음

**증상:**
- SIGRTMIN+30 전송 후 journal에 "gcov coverage data dumped to /tmp/gcov/logind" 로그가 찍힘
- 하지만 에뮬레이터 `/tmp/gcov/logind/`에 파일이 없거나 호스트로 pull해도 빈 디렉토리

**원인:**
`systemd-logind.service`의 `PrivateTmp=yes` 설정으로 인해 logind는 격리된 자체 `/tmp`를 사용함.
logind가 쓰는 `/tmp/gcov/logind`는 시스템 `/tmp`가 아닌 logind의 private namespace 내부.

**진단:**
```bash
sdb -e shell "systemctl cat systemd-logind | grep PrivateTmp"
# → PrivateTmp=yes
```

**해결책:**
logind의 gcda 경로를 `/tmp` 대신 `/run/gcov/logind`로 변경:
- `/run`은 PrivateTmp 격리 없이 시스템 전체가 공유하는 경로
- `src/login/logind.c`의 `manager_dispatch_gcov_signal` 함수에서 경로를 `/run/gcov/logind`로 설정
- 호스트에서 pull: `sdb -e pull "/run/gcov/logind/_build" ...`

---

## 7. sdb wait-for-device 재부팅 후 타임아웃

**증상:**
```
error: no devices/emulators found
```
또는 `sdb wait-for-device`가 응답 없이 멈춤.

**원인:**
에뮬레이터 재부팅 직후 sdb 서버와의 연결이 끊긴 상태에서 명령을 너무 빨리 보냄.

**해결책:**
재부팅 후 충분히 대기한 뒤 재연결 확인:
```bash
# 재부팅 명령 후
sleep 30
sdb devices   # 연결 확인
sdb wait-for-device
${SDB} root on
```
여전히 안 되면 sdb 서버 재시작:
```bash
sdb kill-server && sdb start-server
sleep 5
sdb devices
```

---

## 8. /tmp 도구 세션 간 초기화 (lcov, gcov 래퍼 사라짐)

**증상:**
이전 세션에서 설치한 lcov (`/tmp/lcov-extracted/`) 또는 gcov 래퍼 (`/tmp/gcov-wrapper.sh`)가 없음:
```
/tmp/gcov-wrapper.sh: No such file or directory
/tmp/lcov-extracted/usr/bin/lcov: No such file or directory
```

**원인:**
`/tmp`는 재부팅 또는 세션 재시작 시 초기화될 수 있음.

**해결책:**
매 작업 세션 시작 시 아래를 재실행:
```bash
# lcov 재설치
cd /tmp && apt-get download lcov 2>/dev/null
dpkg-deb -x /tmp/lcov_*.deb /tmp/lcov-extracted/

# gcov 래퍼 재생성 (BUILDROOT 변수가 설정되어 있어야 함)
cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec "${BUILDROOT}/lib64/ld-linux-x86-64.so.2" \\
    --library-path "${BUILDROOT}/usr/lib64:${BUILDROOT}/lib64" \\
    "${BUILDROOT}/usr/bin/gcov" "\$@"
EOF
chmod +x /tmp/gcov-wrapper.sh
```

---

## 9. spec 파일 trailing backslash로 meson build 실패

**증상:**
GBS 빌드 실패 또는 빌드 로그에서 `b_coverage : false`로 확인됨.
meson setup 명령에 `compile` 서브커맨드가 붙어버리는 형태로 파싱됨.

**원인:**
`packaging/systemd.spec`의 `%meson` 섹션에서 `-Db_coverage=true \` 뒤에 trailing backslash가 있으면
`%meson_build` 매크로가 직전 meson setup 옵션의 연속으로 처리됨:
```spec
# 잘못된 예 (backslash로 줄 이음)
-Db_coverage=true \
%meson_build     ← 이 줄이 meson setup 명령의 인수로 붙음
```

**해결책:**
`-Db_coverage=true` 라인의 trailing backslash 제거, 그리고 마지막 옵션(-Db_pie=true) **앞**에 배치:
```spec
%if 0%{?WITH_COVERAGE}
-Db_coverage=true \
%endif
-Db_pie=true
%meson_build
```
`%if/%endif` 블록 안에서는 backslash를 유지해도 되며, 마지막 줄(`-Db_pie=true`)이 backslash 없이 끝나야 한다.

---

## 10. 멀티 프로세스 gcda 파일 충돌 (덮어쓰기)

**증상:**
여러 프로세스(systemd, journald, udevd 등)의 coverage를 합산했을 때 결과가 단일 프로세스와 크게 다르지 않음.
또는 한 프로세스의 gcda가 다른 프로세스의 결과를 덮어씀.

**원인:**
여러 데몬이 공유 static library 코드를 함께 사용하는 경우, 같은 gcno에 대한 gcda 경로가 동일하여
나중에 dump된 프로세스의 데이터가 이전 것을 덮어씀.

**해결책:**
각 프로세스에 고유한 `GCOV_PREFIX` 서브디렉토리를 설정:
- `systemd (system)` → `/tmp/gcov/system`
- `systemd --user` → `/tmp/gcov/user`
- `systemd-journald` → `/tmp/gcov/journald`
- `systemd-udevd` → `/tmp/gcov/udevd`
- `systemd-logind` → `/run/gcov/logind` (PrivateTmp 우회)

이후 lcov에서 프로세스별로 별도 `coverage.info`를 생성하고 `--add-tracefile`로 합산:
```bash
for proc in system journald udevd logind; do
    perl "${LCOV}" --capture --directory "${GCNO_BASE}" \
        --output-file "${OUT}/${proc}.info" ...
done
perl "${LCOV}" \
    --add-tracefile "${OUT}/system-fixed.info" \
    --add-tracefile "${OUT}/journald-fixed.info" \
    ...
    --output-file "${OUT}/combined.info"
```

---

## 11. gcov 버전 감지 실패 및 "Overlong record" — armv7l 실제 디바이스 빌드

**증상:**
```
geninfo: WARNING: cannot determine gcov version - assuming 4.2.0
Found gcov version: 4.2.0
...
geninfo: WARNING: <path>.gcno: Overlong record at end of file!
```

**원인:**
gcov 래퍼 스크립트가 x86_64 에뮬레이터 기준으로 하드코딩되어 있어 armv7l 빌드루트에서
gcov를 실행하지 못한다.

```bash
# 기존 래퍼 — x86_64 전용
exec "${BUILDROOT}/lib64/ld-linux-x86-64.so.2" \
    --library-path "${BUILDROOT}/usr/lib64:${BUILDROOT}/lib64" \
    "${BUILDROOT}/usr/bin/gcov" "$@"
```

`armv7l` 빌드루트의 경우:
- gcov 바이너리가 ARM 바이너리일 수 있어 x86_64 ld-linux로 실행 불가
- 라이브러리 경로가 `lib64` 가 아닌 `lib`일 수 있음

래퍼 실행 실패 → geninfo가 gcov 버전을 판별 못함 → 4.2.0으로 가정 → GCC 14가 생성한
gcno 파일을 4.2.0 포맷으로 파싱 시도 → "Overlong record" 오류

**해결책:**
gcov 바이너리의 아키텍처를 `file` 명령으로 자동 감지하여 실행 방식을 분기한다.

```bash
GCOV_BIN="${BUILDROOT}/usr/bin/gcov"
GCOV_ARCH=$(file "${GCOV_BIN}" 2>/dev/null | grep -oE 'ARM|x86-64' | head -1)

if [ "${GCOV_ARCH}" = "x86-64" ]; then
    # x86_64 gcov (에뮬레이터 빌드): buildroot에서 ld-linux를 검색하여 실행
    LDSO=$(find "${BUILDROOT}" -name "ld-linux-x86-64.so.2" 2>/dev/null | head -1)
    LIBPATH=""
    for d in usr/lib64 lib64 usr/lib lib; do
        [ -d "${BUILDROOT}/${d}" ] && LIBPATH="${LIBPATH}${BUILDROOT}/${d}:"
    done
    cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec "${LDSO}" --library-path "${LIBPATH%:}" "${GCOV_BIN}" "\$@"
EOF
elif [ "${GCOV_ARCH}" = "ARM" ]; then
    # ARM gcov (실제 디바이스 빌드): qemu-arm으로 실행
    # apt-get install qemu-user 로 설치 필요
    cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec qemu-arm -L "${BUILDROOT}" "${GCOV_BIN}" "\$@"
EOF
fi
chmod +x /tmp/gcov-wrapper.sh
```

ARM gcov의 경우 `qemu-arm`이 설치되어 있어야 한다:
```bash
apt-get install qemu-user
```

**검증:**
```bash
/tmp/gcov-wrapper.sh --version
# 출력에 "gcov (GCC) 14.x.x" 가 포함되어야 한다 (4.2.0 이면 실패)
```
