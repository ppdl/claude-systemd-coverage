#!/usr/bin/env bash
# measure-coverage.sh — systemd gcov line coverage 측정 자동화
# Usage: ./scripts/measure-coverage.sh --src <SYSTEMD_SRC> --device <emulator|device> [options]

set -euo pipefail

# ── 색상 출력 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── 옵션 기본값 ────────────────────────────────────────────────────────────────
SYSTEMD_SRC=""
DEVICE_TYPE="emulator"
SKIP_PATCH=false
SKIP_BUILD=false
SKIP_DEPLOY=false
FROM_STEP=1

usage() {
    cat <<EOF
Usage: $0 --src <SYSTEMD_SRC> --device <emulator|device> [OPTIONS]

필수:
  --src <path>       systemd 소스코드 루트 경로

선택:
  --device <type>    연결 대상: emulator 또는 device (기본: emulator)
  --skip-patch       Step 1 소스 패치 건너뜀 (이미 패치된 경우)
  --skip-build       Step 2 GBS 빌드 건너뜀
  --skip-deploy      Step 3 디바이스 배포 건너뜀
  --from-step <N>    N번 Step부터 실행 (1~7, 기본: 1)
  -h, --help         이 도움말 출력

Steps:
  1. 소스 코드 패치 (manager.c, journald-server.c, udevd.c, logind.c, systemd.spec)
  2. GBS 빌드 (gbs build -A <arch> --define 'WITH_COVERAGE 1' --include-all)
  3. 디바이스 배포 (해시 검사 → RPM 설치 → 재부팅)
  4. gcov dump 트리거 및 gcda 수집 (부팅 후 1분 대기)
  5. lcov 도구 준비 (gcov 래퍼, lcov 설치)
  6. lcov 리포트 생성 (baseline, per-process, combined, HTML)
  7. 결과 확인
EOF
    exit 0
}

# ── 인자 파싱 ──────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)         SYSTEMD_SRC="$2"; shift 2 ;;
        --device)      DEVICE_TYPE="$2"; shift 2 ;;
        --skip-patch)  SKIP_PATCH=true; shift ;;
        --skip-build)  SKIP_BUILD=true; shift ;;
        --skip-deploy) SKIP_DEPLOY=true; shift ;;
        --from-step)   FROM_STEP="$2"; shift 2 ;;
        -h|--help)     usage ;;
        *) die "알 수 없는 옵션: $1" ;;
    esac
done

[[ -n "${SYSTEMD_SRC}" ]]             || die "--src 옵션이 필요합니다."
[[ -d "${SYSTEMD_SRC}" ]]             || die "소스 경로가 존재하지 않습니다: ${SYSTEMD_SRC}"
[[ "${DEVICE_TYPE}" =~ ^(emulator|device)$ ]] \
                                       || die "--device 값은 emulator 또는 device 이어야 합니다."

# ── Step 0: 변수 초기화 ────────────────────────────────────────────────────────
step0_init_vars() {
    info "변수 초기화 중..."

    # sdb 플래그
    if [[ "${DEVICE_TYPE}" = "emulator" ]]; then
        SDB="sdb -e"
    else
        SDB="sdb -d"
    fi

    # GBS buildroot base (~/.gbs.conf → [general] buildroot)
    local gbs_conf="${HOME}/.gbs.conf"
    GBS_BUILDROOT_BASE=""
    if [[ -f "${gbs_conf}" ]]; then
        GBS_BUILDROOT_BASE=$(awk '
            /^\[general\]/ { in_section=1; next }
            /^\[/          { in_section=0 }
            in_section && /^buildroot[[:space:]]*=/ {
                sub(/^buildroot[[:space:]]*=[[:space:]]*/, "")
                sub(/^~/, ENVIRON["HOME"])
                print; exit
            }
        ' "${gbs_conf}")
    fi
    GBS_BUILDROOT_BASE="${GBS_BUILDROOT_BASE:-${HOME}/GBS-ROOT}"

    # 타겟 아키텍처
    if [[ "${DEVICE_TYPE}" = "emulator" ]]; then
        ARCH="x86_64"
    else
        ARCH=$(${SDB} shell "rpm -qa | head -20" | \
            grep -oE '\.(aarch64|armv7l|armv7hl|i686|x86_64)$' | \
            sed 's/^\.//' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        [[ -n "${ARCH}" ]] || die "타겟 아키텍처를 자동으로 결정할 수 없습니다."
    fi

    # 경로 변수
    BUILDROOT="${GBS_BUILDROOT_BASE}/local/BUILD-ROOTS/scratch.${ARCH}.0"
    RPMS="${GBS_BUILDROOT_BASE}/local/repos/tizen/${ARCH}/RPMS"
    GCNO_BASE="${BUILDROOT}/home/abuild/rpmbuild/BUILD/systemd-244/_build"
    GCOV_HOST="${SYSTEMD_SRC}/../gcov-data-multi"
    OUT="${SYSTEMD_SRC}/../coverage-report"
    LCOV=/tmp/lcov-extracted/usr/bin/lcov
    GENHTML=/tmp/lcov-extracted/usr/bin/genhtml

    info "GBS_BUILDROOT_BASE : ${GBS_BUILDROOT_BASE}"
    info "ARCH               : ${ARCH}"
    info "SDB                : ${SDB}"
    info "BUILDROOT          : ${BUILDROOT}"
    info "RPMS               : ${RPMS}"
    info "GCOV_HOST          : ${GCOV_HOST}"
    info "OUT                : ${OUT}"
}

# ── Step 1: 소스 코드 패치 ────────────────────────────────────────────────────
step1_patch_sources() {
    info "=== Step 1: 소스 코드 패치 ==="
    _patch_manager_c
    _patch_journald_c
    _patch_udevd_c
    _patch_logind_c
    _patch_spec
    success "소스 패치 완료"
}

_patch_manager_c() {
    local file="${SYSTEMD_SRC}/src/core/manager.c"
    info "패치: src/core/manager.c"
    python3 - "${file}" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    text = f.read()

# --- Patch 1: SIGRTMIN+30 시그널 등록 ---
CHECK1 = 'RTSIG_IF_AVAILABLE(SIGRTMIN+30), /* systemd: dump gcov coverage data */'
OLD1   = '/* ... one free signal here SIGRTMIN+30 ... */\n-1);'
NEW1   = 'RTSIG_IF_AVAILABLE(SIGRTMIN+30), /* systemd: dump gcov coverage data */\n-1);'
if CHECK1 in text:
    print("  [SKIP] patch1 (signal registration) 이미 적용됨")
elif OLD1 in text:
    text = text.replace(OLD1, NEW1, 1)
    print("  [OK]   patch1 (signal registration) 적용")
else:
    print("  [WARN] patch1: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

# --- Patch 2: case 30 핸들러 ---
CHECK2 = 'case 30: {'
HANDLER = '''
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
        }'''
if CHECK2 in text:
    print("  [SKIP] patch2 (case 30 handler) 이미 적용됨")
else:
    # case 28: 블록의 끝 (break;\n        }) 이후에 삽입
    m = re.search(r'([ \t]+case 28:[^\}]+?break;\n[ \t]+\})', text, re.DOTALL)
    if m:
        pos = m.end()
        text = text[:pos] + HANDLER + text[pos:]
        print("  [OK]   patch2 (case 30 handler) 적용")
    else:
        print("  [WARN] patch2: case 28 블록을 찾을 수 없음 — 수동 적용 필요")

with open(path, 'w') as f:
    f.write(text)
PYEOF
}

_patch_journald_c() {
    local file="${SYSTEMD_SRC}/src/journal/journald-server.c"
    info "패치: src/journal/journald-server.c"
    python3 - "${file}" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    text = f.read()

NEW_FUNC = '''\
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

'''

# Patch 1: dispatch_sigrtmin30 함수 삽입
ANCHOR1 = 'static int dispatch_sigrtmin1('
if 'dispatch_sigrtmin30' in text:
    print("  [SKIP] patch1 (dispatch_sigrtmin30 함수) 이미 적용됨")
elif ANCHOR1 in text:
    text = text.replace(ANCHOR1, NEW_FUNC + ANCHOR1, 1)
    print("  [OK]   patch1 (dispatch_sigrtmin30 함수) 적용")
else:
    print("  [WARN] patch1: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

# Patch 2: sigprocmask_many에 SIGRTMIN+30 추가
OLD2 = 'sigprocmask_many(SIG_SETMASK, NULL, SIGINT, SIGTERM, SIGUSR1, SIGUSR2, SIGRTMIN+1, -1)'
NEW2 = 'sigprocmask_many(SIG_SETMASK, NULL, SIGINT, SIGTERM, SIGUSR1, SIGUSR2, SIGRTMIN+1, SIGRTMIN+30, -1)'
if NEW2 in text:
    print("  [SKIP] patch2 (sigprocmask) 이미 적용됨")
elif OLD2 in text:
    text = text.replace(OLD2, NEW2, 1)
    print("  [OK]   patch2 (sigprocmask) 적용")
else:
    print("  [WARN] patch2: 대상 문자열을 찾을 수 없음 — 수동 적용 필요")

# Patch 3: sd_event_add_signal 등록
CHECK3 = 'SIGRTMIN+30, dispatch_sigrtmin30'
REG3 = '''\
        r = sd_event_add_signal(s->event, NULL, SIGRTMIN+30, dispatch_sigrtmin30, s);
        if (r < 0)
                return r;
'''
if CHECK3 in text:
    print("  [SKIP] patch3 (sd_event_add_signal) 이미 적용됨")
else:
    # SIGRTMIN+1 등록 블록 이후에 삽입
    m = re.search(
        r'(r = sd_event_add_signal\(s->event, NULL, SIGRTMIN\+1,.*?\n[ \t]+if \(r < 0\)\n[ \t]+return r;\n)',
        text, re.DOTALL)
    if m:
        pos = m.end()
        text = text[:pos] + '\n' + REG3 + text[pos:]
        print("  [OK]   patch3 (sd_event_add_signal) 적용")
    else:
        print("  [WARN] patch3: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

with open(path, 'w') as f:
    f.write(text)
PYEOF
}

_patch_udevd_c() {
    local file="${SYSTEMD_SRC}/src/udev/udevd.c"
    info "패치: src/udev/udevd.c"
    python3 - "${file}" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    text = f.read()

NEW_FUNC = '''\
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

'''

# Patch 1: on_sigrtmin30 함수 삽입
ANCHOR1 = 'static int on_sigterm('
if 'on_sigrtmin30' in text:
    print("  [SKIP] patch1 (on_sigrtmin30 함수) 이미 적용됨")
elif ANCHOR1 in text:
    text = text.replace(ANCHOR1, NEW_FUNC + ANCHOR1, 1)
    print("  [OK]   patch1 (on_sigrtmin30 함수) 적용")
else:
    print("  [WARN] patch1: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

# Patch 2: sigprocmask_many SIG_BLOCK에 SIGRTMIN+30 추가
OLD2 = 'sigprocmask_many(SIG_BLOCK, NULL, SIGTERM, SIGINT, SIGHUP, SIGCHLD, -1)'
NEW2 = 'sigprocmask_many(SIG_BLOCK, NULL, SIGTERM, SIGINT, SIGHUP, SIGCHLD, SIGRTMIN+30, -1)'
if NEW2 in text:
    print("  [SKIP] patch2 (sigprocmask) 이미 적용됨")
elif OLD2 in text:
    text = text.replace(OLD2, NEW2, 1)
    print("  [OK]   patch2 (sigprocmask) 적용")
else:
    print("  [WARN] patch2: 대상 문자열을 찾을 수 없음 — 수동 적용 필요")

# Patch 3: sd_event_add_signal 등록
CHECK3 = 'SIGRTMIN+30, on_sigrtmin30'
REG3 = '''\
        r = sd_event_add_signal(manager->event, NULL, SIGRTMIN+30, on_sigrtmin30, manager);
        if (r < 0)
                return log_error_errno(r, "Failed to create SIGRTMIN+30 event source: %m");
'''
if CHECK3 in text:
    print("  [SKIP] patch3 (sd_event_add_signal) 이미 적용됨")
else:
    # SIGCHLD 등록 블록 이후에 삽입
    m = re.search(
        r'(r = sd_event_add_signal\(manager->event, NULL, SIGCHLD,.*?\n[ \t]+if \(r < 0\)\n[ \t]+return[^\n]+\n)',
        text, re.DOTALL)
    if m:
        pos = m.end()
        text = text[:pos] + '\n' + REG3 + text[pos:]
        print("  [OK]   patch3 (sd_event_add_signal) 적용")
    else:
        print("  [WARN] patch3: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

with open(path, 'w') as f:
    f.write(text)
PYEOF
}

_patch_logind_c() {
    local file="${SYSTEMD_SRC}/src/login/logind.c"
    info "패치: src/login/logind.c"
    python3 - "${file}" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    text = f.read()

# Patch 1: #include "mkdir.h" 추가
CHECK1 = '#include "mkdir.h"'
if CHECK1 in text:
    print("  [SKIP] patch1 (#include mkdir.h) 이미 적용됨")
else:
    # 마지막 #include "..." 줄 다음에 삽입
    m = list(re.finditer(r'#include "[^"]+"\n', text))
    if m:
        pos = m[-1].end()
        text = text[:pos] + '#include "mkdir.h"\n' + text[pos:]
        print("  [OK]   patch1 (#include mkdir.h) 적용")
    else:
        print("  [WARN] patch1: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

NEW_FUNC = '''\
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

'''

# Patch 2: manager_dispatch_gcov_signal 함수 삽입
ANCHOR2 = 'static int manager_dispatch_reload_signal('
if 'manager_dispatch_gcov_signal' in text:
    print("  [SKIP] patch2 (manager_dispatch_gcov_signal 함수) 이미 적용됨")
elif ANCHOR2 in text:
    text = text.replace(ANCHOR2, NEW_FUNC + ANCHOR2, 1)
    print("  [OK]   patch2 (manager_dispatch_gcov_signal 함수) 적용")
else:
    print("  [WARN] patch2: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

# Patch 3: sigprocmask_many에 SIGRTMIN+30 추가
OLD3 = 'sigprocmask_many(SIG_BLOCK, NULL, SIGHUP, SIGTERM, SIGINT, SIGCHLD, -1)'
NEW3 = 'sigprocmask_many(SIG_BLOCK, NULL, SIGHUP, SIGTERM, SIGINT, SIGCHLD, SIGRTMIN+30, -1)'
if NEW3 in text:
    print("  [SKIP] patch3 (sigprocmask) 이미 적용됨")
elif OLD3 in text:
    text = text.replace(OLD3, NEW3, 1)
    print("  [OK]   patch3 (sigprocmask) 적용")
else:
    print("  [WARN] patch3: 대상 문자열을 찾을 수 없음 — 수동 적용 필요")

# Patch 4: sd_event_add_signal 등록
CHECK4 = 'SIGRTMIN+30, manager_dispatch_gcov_signal'
REG4 = '''\
        r = sd_event_add_signal(m->event, NULL, SIGRTMIN+30, manager_dispatch_gcov_signal, m);
        if (r < 0)
                return log_error_errno(r, "Failed to register SIGRTMIN+30 handler: %m");
'''
if CHECK4 in text:
    print("  [SKIP] patch4 (sd_event_add_signal) 이미 적용됨")
else:
    # SIGHUP 등록 블록 이후에 삽입
    m = re.search(
        r'(r = sd_event_add_signal\(m->event, NULL, SIGHUP,.*?\n[ \t]+if \(r < 0\)\n[ \t]+return[^\n]+\n)',
        text, re.DOTALL)
    if m:
        pos = m.end()
        text = text[:pos] + '\n' + REG4 + text[pos:]
        print("  [OK]   patch4 (sd_event_add_signal) 적용")
    else:
        print("  [WARN] patch4: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

with open(path, 'w') as f:
    f.write(text)
PYEOF
}

_patch_spec() {
    local file="${SYSTEMD_SRC}/packaging/systemd.spec"
    info "패치: packaging/systemd.spec"
    python3 - "${file}" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    text = f.read()

CHECK = '%if 0%{?WITH_COVERAGE}'
OLD   = '-Db_pie=true\n%meson_build'
NEW   = '%if 0%{?WITH_COVERAGE}\n-Db_coverage=true \\\n%endif\n-Db_pie=true\n%meson_build'

if CHECK in text:
    print("  [SKIP] systemd.spec (WITH_COVERAGE 옵션) 이미 적용됨")
elif OLD in text:
    text = text.replace(OLD, NEW, 1)
    print("  [OK]   systemd.spec (WITH_COVERAGE 옵션) 적용")
else:
    print("  [WARN] systemd.spec: 삽입 위치를 찾을 수 없음 — 수동 적용 필요")

with open(path, 'w') as f:
    f.write(text)
PYEOF
}

# ── Step 2: GBS 빌드 ──────────────────────────────────────────────────────────
step2_build() {
    info "=== Step 2: GBS 빌드 ==="
    cd "${SYSTEMD_SRC}"
    info "gbs build -A ${ARCH} --define 'WITH_COVERAGE 1' --include-all"
    gbs build -A "${ARCH}" --define 'WITH_COVERAGE 1' --include-all

    local log="${GBS_BUILDROOT_BASE}/local/repos/tizen/${ARCH}/logs/success/systemd-244-0/log.txt"
    if grep -q "b_coverage : true" "${log}" 2>/dev/null; then
        success "빌드 성공: b_coverage=true 확인"
    else
        warn "빌드 로그에서 b_coverage=true를 확인하지 못했습니다. 로그: ${log}"
    fi
}

# ── Step 3: 디바이스 배포 ─────────────────────────────────────────────────────
step3_deploy() {
    info "=== Step 3: 디바이스 배포 ==="

    # 3-1 해시 검사
    info "바이너리 해시 검사..."
    mkdir -p /tmp/rpm-check
    rpm2cpio "${RPMS}/systemd-244-0.${ARCH}.rpm" | \
        cpio -id --quiet './usr/lib/systemd/systemd' -D /tmp/rpm-check/
    local rpm_hash dev_hash
    rpm_hash=$(md5sum /tmp/rpm-check/usr/lib/systemd/systemd | awk '{print $1}')
    rm -rf /tmp/rpm-check

    dev_hash=$(${SDB} shell "md5sum /usr/lib/systemd/systemd" | awk '{print $1}' | tr -d '\r')

    if [[ "${rpm_hash}" = "${dev_hash}" ]]; then
        success "해시 일치 — 재배포 불필요"
        return
    fi
    warn "해시 불일치 (rpm=${rpm_hash}, dev=${dev_hash}) — RPM 재설치 진행"

    # 3-2 RPM 설치 및 재부팅
    ${SDB} root on
    ${SDB} push "${RPMS}/libsystemd-244-0.${ARCH}.rpm" /tmp/
    ${SDB} push "${RPMS}/systemd-244-0.${ARCH}.rpm" /tmp/
    ${SDB} shell "rpm -Uvh --force /tmp/libsystemd-244-0.${ARCH}.rpm /tmp/systemd-244-0.${ARCH}.rpm"

    info "재부팅..."
    ${SDB} shell "reboot" || true
    sleep 20
    sdb wait-for-device
    ${SDB} root on
    success "재배포 완료"
}

# ── Step 4: gcov dump 트리거 및 gcda 수집 ────────────────────────────────────
step4_trigger_dump() {
    info "=== Step 4: gcov dump 트리거 및 gcda 수집 ==="

    # 4-1 부팅 후 1분 대기
    info "부팅 초기화 완료 대기 (60초)..."
    sdb wait-for-device
    ${SDB} root on
    echo "  시작: $(date)"
    sleep 60
    echo "  완료: $(date)"

    # 4-3 SIGRTMIN+30 (= kill -64) 전송
    info "SIGRTMIN+30 신호 전송..."
    ${SDB} shell "kill -64 1"                                                     # systemd (system)
    ${SDB} shell "kill -64 \$(pgrep systemd-journald)" || warn "journald PID 없음"
    ${SDB} shell "kill -64 \$(pgrep systemd-udevd)"   || warn "udevd PID 없음"
    ${SDB} shell "kill -64 \$(pgrep systemd-logind)"  || warn "logind PID 없음"
    ${SDB} shell "pgrep -f 'systemd --user' | xargs -r kill -64" || true          # systemd --user
    sleep 3  # dump 완료 대기

    # 4-4 gcda 생성 확인
    info "gcda 파일 수 확인..."
    ${SDB} shell "
for p in system user journald udevd; do
    echo \"  \$p: \$(find /tmp/gcov/\$p -name '*.gcda' 2>/dev/null | wc -l) gcda\"
done
echo \"  logind: \$(find /run/gcov/logind -name '*.gcda' 2>/dev/null | wc -l) gcda\"
"

    # 4-5 호스트로 수집
    info "gcda 파일 수집..."
    rm -rf "${GCOV_HOST}" && mkdir -p "${GCOV_HOST}"

    for proc in system user journald udevd; do
        mkdir -p "${GCOV_HOST}/${proc}"
        ${SDB} pull "/tmp/gcov/${proc}/_build" "${GCOV_HOST}/${proc}/" 2>/dev/null || true
    done
    mkdir -p "${GCOV_HOST}/logind"
    ${SDB} pull "/run/gcov/logind/_build" "${GCOV_HOST}/logind/" 2>/dev/null || true

    local total
    total=$(find "${GCOV_HOST}" -name '*.gcda' 2>/dev/null | wc -l)
    success "수집 완료: ${total}개 gcda 파일 → ${GCOV_HOST}"
}

# ── gcov 래퍼 생성 (아키텍처 자동 감지) ──────────────────────────────────────
_make_gcov_wrapper() {
    local gcov_bin="${BUILDROOT}/usr/bin/gcov"
    local gcov_arch
    gcov_arch=$(file "${gcov_bin}" 2>/dev/null | grep -oE 'ARM|x86-64' | head -1)
    info "gcov 바이너리 아키텍처: ${gcov_arch:-unknown}"

    if [[ "${gcov_arch}" = "x86-64" ]]; then
        # x86_64 gcov: buildroot에서 ld-linux-x86-64.so.2를 검색하여 실행
        local ldso
        ldso=$(find "${BUILDROOT}" -name "ld-linux-x86-64.so.2" 2>/dev/null | head -1)
        [[ -n "${ldso}" ]] || die "ld-linux-x86-64.so.2를 buildroot에서 찾을 수 없습니다: ${BUILDROOT}"

        local libpath=""
        for d in usr/lib64 lib64 usr/lib lib; do
            [[ -d "${BUILDROOT}/${d}" ]] && libpath="${libpath}${BUILDROOT}/${d}:"
        done
        cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec "${ldso}" --library-path "${libpath%:}" "${gcov_bin}" "\$@"
EOF

    elif [[ "${gcov_arch}" = "ARM" ]]; then
        # ARM gcov: qemu-arm으로 실행 (apt-get install qemu-user 필요)
        command -v qemu-arm &>/dev/null \
            || die "ARM gcov 실행을 위해 qemu-arm이 필요합니다: apt-get install qemu-user"
        cat > /tmp/gcov-wrapper.sh << EOF
#!/bin/bash
exec qemu-arm -L "${BUILDROOT}" "${gcov_bin}" "\$@"
EOF

    else
        die "gcov 바이너리 아키텍처를 판별할 수 없습니다: ${gcov_bin}\n       file 명령 결과: $(file "${gcov_bin}" 2>/dev/null)"
    fi

    chmod +x /tmp/gcov-wrapper.sh

    # 동작 확인: 버전 출력에 "4.2.0" 이 나오면 래퍼 실행 실패
    local ver
    ver=$(/tmp/gcov-wrapper.sh --version 2>/dev/null | head -1 || true)
    info "gcov 버전: ${ver}"
    if echo "${ver}" | grep -q "4\.2\.0"; then
        die "gcov 래퍼가 올바르게 동작하지 않습니다 (버전: 4.2.0 으로 감지됨). troubleshooting.md #11 참조"
    fi
}

# ── Step 5: lcov 도구 준비 ────────────────────────────────────────────────────
step5_setup_lcov() {
    info "=== Step 5: lcov 도구 준비 ==="

    [[ -f "${BUILDROOT}/usr/bin/gcov" ]] \
        || die "GBS 빌드루트에 gcov가 없습니다: ${BUILDROOT}/usr/bin/gcov\n       GBS 빌드를 먼저 한 번 실행하세요."

    # lcov 설치
    if [[ ! -x "${LCOV}" ]]; then
        info "lcov 설치 중 (apt-get download + dpkg-deb)..."
        (cd /tmp && apt-get download lcov -q 2>&1)
        dpkg-deb -x /tmp/lcov_*.deb /tmp/lcov-extracted/
    else
        info "lcov 이미 존재: ${LCOV}"
    fi

    # gcov 래퍼 생성 (BUILDROOT가 바뀐 경우도 재생성)
    if [[ ! -x /tmp/gcov-wrapper.sh ]] || ! grep -qF "${BUILDROOT}" /tmp/gcov-wrapper.sh 2>/dev/null; then
        _make_gcov_wrapper
    else
        info "gcov 래퍼 이미 존재: /tmp/gcov-wrapper.sh"
    fi

    success "lcov 도구 준비 완료"
}

# ── Step 6: lcov 리포트 생성 ──────────────────────────────────────────────────
step6_generate_report() {
    info "=== Step 6: lcov 리포트 생성 ==="
    mkdir -p "${OUT}"

    # 6-1 baseline (미실행 파일도 0%로 포함)
    info "baseline 생성..."
    perl "${LCOV}" \
        --gcov-tool /tmp/gcov-wrapper.sh \
        --capture --initial \
        --directory "${GCNO_BASE}" \
        --output-file "${OUT}/baseline.info" \
        --ignore-errors source,gcov

    # 6-2 프로세스별 coverage.info
    info "프로세스별 coverage.info 생성..."
    local procs=()
    for proc in system user journald udevd logind; do
        local gcda_count=0
        gcda_count=$(find "${GCOV_HOST}/${proc}" -name '*.gcda' 2>/dev/null | wc -l || true)
        if [[ "${gcda_count}" -eq 0 ]]; then
            warn "  ${proc}: gcda 파일 없음 — 건너뜀"
            continue
        fi
        info "  ${proc} 처리 중 (${gcda_count}개 gcda)..."
        find "${GCNO_BASE}" -name '*.gcda' -delete
        find "${GCOV_HOST}/${proc}" -name '*.gcda' | while read -r gcda; do
            local rel dest
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
        procs+=("${proc}")
    done
    find "${GCNO_BASE}" -name '*.gcda' -delete  # 정리

    # 6-3 경로 치환 (SF:/home/abuild/... → 실제 소스 경로)
    info "SF: 경로 치환..."
    for proc in baseline "${procs[@]}"; do
        [[ -f "${OUT}/${proc}.info" ]] || continue
        sed "s|SF:/home/abuild/rpmbuild/BUILD/systemd-244/|SF:${SYSTEMD_SRC}/|g" \
            "${OUT}/${proc}.info" > "${OUT}/${proc}-fixed.info"
    done

    # 6-4 전체 합산
    info "coverage.info 합산..."
    local add_args=()
    for proc in baseline "${procs[@]}"; do
        [[ -f "${OUT}/${proc}-fixed.info" ]] && add_args+=(--add-tracefile "${OUT}/${proc}-fixed.info")
    done
    perl "${LCOV}" \
        "${add_args[@]}" \
        --output-file "${OUT}/combined.info" \
        --ignore-errors source

    # 6-5 HTML 리포트
    info "HTML 리포트 생성..."
    rm -rf "${OUT}/html"
    perl "${GENHTML}" \
        "${OUT}/combined.info" \
        --output-directory "${OUT}/html" \
        --legend --show-details \
        --ignore-errors source \
        --prefix "${SYSTEMD_SRC}"

    success "리포트 생성 완료: ${OUT}/html/index.html"
}

# ── Step 7: 결과 확인 ─────────────────────────────────────────────────────────
step7_show_results() {
    info "=== Step 7: 결과 확인 ==="

    echo ""
    perl "${LCOV}" --list "${OUT}/combined.info" 2>/dev/null | tail -5
    echo ""
    info "0% 파일 (src/core):"
    perl "${LCOV}" --list "${OUT}/combined.info" 2>/dev/null \
        | grep "0\.0%" | grep "src/core" || echo "  (없음)"
    echo ""
    success "HTML 리포트: ${OUT}/html/index.html"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo "========================================================"
    echo " systemd Coverage Measurement"
    echo " SYSTEMD_SRC : ${SYSTEMD_SRC}"
    echo " DEVICE_TYPE : ${DEVICE_TYPE}"
    [[ "${SKIP_PATCH}"  = true ]] && echo " [SKIP] Step 1 (patch)"
    [[ "${SKIP_BUILD}"  = true ]] && echo " [SKIP] Step 2 (build)"
    [[ "${SKIP_DEPLOY}" = true ]] && echo " [SKIP] Step 3 (deploy)"
    [[ "${FROM_STEP}" -gt 1 ]]   && echo " FROM Step ${FROM_STEP}"
    echo "========================================================"

    step0_init_vars

    run_step() {
        local n="$1"; local skip="$2"; local fn="$3"
        [[ "${FROM_STEP}" -le "${n}" ]] || return 0
        [[ "${skip}" = false ]]         || { warn "Step ${n} 건너뜀 (--skip 옵션)"; return 0; }
        ${fn}
    }

    run_step 1 "${SKIP_PATCH}"  step1_patch_sources
    run_step 2 "${SKIP_BUILD}"  step2_build
    run_step 3 "${SKIP_DEPLOY}" step3_deploy
    run_step 4 false            step4_trigger_dump
    run_step 5 false            step5_setup_lcov
    run_step 6 false            step6_generate_report
    run_step 7 false            step7_show_results

    echo ""
    success "========================================================"
    success " 모든 단계 완료"
    success "========================================================"
}

main
