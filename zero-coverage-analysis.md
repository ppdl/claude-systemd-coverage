# 라인 커버리지 0% 소스 파일 분석

> 기준: `result/coverage-report-3/combined.info`
> 총 **.c 파일 498개** — 런타임 코드 **258개** / 테스트·퍼징 코드 **240개**

## 범례

| 기호 | 의미 |
|------|------|
| ✅ 가능 | Tizen 빌드에서 제외해도 런타임 영향 없음 |
| ⚠️ 조건부 가능 | 특정 기능 미사용 시 제외 가능 |
| ❌ 불가 | 런타임 의존성 있음, 제외 불가 |
| — | 테스트·퍼징 코드 (해당없음) |

## 요약

| 카테고리 | 파일 수 | ✅ 가능 | ⚠️ 조건부 | ❌ 불가 |
|---------|--------|---------|----------|--------|
| systemd PID 1 (core) | 12 | 2 | 0 | 10 |
| journald (journal) | 22 | 0 | 0 | 6 |
| udevd + udevadm (udev) | 32 | 0 | 0 | 29 |
| logind (login) | 14 | 0 | 0 | 11 |
| 공유 라이브러리 (basic/shared/libsystemd*) | 150 | 0 | 2 | 108 |
| 컨테이너/옵션 데몬 (nspawn/machine 등) | 37 | 24 | 9 | 0 |
| CLI 도구 및 서비스 | 57 | 14 | 7 | 36 |
| 테스트·퍼징 (분석 제외) | 240 | — | — | — |

---

## 상세 분석

### core — systemd PID 1 핵심

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `audit-fd.c` | 4 | 커널 audit 서브시스템 FD 관리 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `bus-policy.c` | 84 | dbus-1 커널 버스 정책 변환 처리 | ✅ 가능 | kdbus/dbus-1 커널 버스 미사용 코드 |
| `chown-recursive.c` | 63 | 유닛 디렉토리 재귀적 chown 처리 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-automount.c` | 20 | automount 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-busname.c` | 1 | busname 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-mount.c` | 57 | mount 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-slice.c` | 10 | slice 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-swap.c` | 22 | swap 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `dbus-timer.c` | 168 | timer 유닛 dbus 인터페이스 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `killall.c` | 127 | 시스템 종료 시 프로세스 전체 종료 | ❌ 불가 | systemd PID 1 핵심 구성요소 |
| `selinux-access.c` | 2 | SELinux 접근 제어 통합 | ✅ 가능 | Tizen은 SELinux 대신 SMACK 사용, 이 파일 미실행 |
| `timer.c` | 451 | timer 유닛 구현 (OnCalendar 등) | ❌ 불가 | systemd PID 1 핵심 구성요소 |

### journal — journald 핵심

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `cat.c` | 71 | journalctl --output=cat 포맷 출력 구현 | ❌ 불가 | journald 핵심 구성요소 |
| `catalog.c` | 415 | MESSAGE_ID 기반 메시지 카탈로그 조회 | ❌ 불가 | journald 핵심 구성요소 |
| `journal-send.c` | 283 | sd_journal_send() API 구현 | ❌ 불가 | journald 핵심 구성요소 |
| `journal-verify.c` | 647 | FSS journal 서명 무결성 검증 | ❌ 불가 | journald 핵심 구성요소 |
| `journalctl.c` | 1220 | journalctl CLI 도구 메인 구현 | ❌ 불가 | journald 핵심 구성요소 |
| `journald-console.c` | 45 | journal 메시지 /dev/console 출력 | ❌ 불가 | journald 핵심 구성요소 |

> **테스트 코드** (16개): `test-audit-type.c`, `test-catalog.c`, `test-compress-benchmark.c`, `test-compress.c`, `test-journal-config.c`, `test-journal-enum.c`, `test-journal-flush.c`, `test-journal-init.c`, `test-journal-interleaving.c`, `test-journal-match.c`, `test-journal-send.c`, `test-journal-stream.c`, `test-journal-syslog.c`, `test-journal-verify.c`, `test-journal.c`, `test-mmap-cache.c`

### udev — udevd 핵심 및 udevadm

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `ata_id.c` | 276 | ATA 디스크 ID/시리얼 추출 udev 헬퍼 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `cdrom_id.c` | 666 | CD-ROM 미디어 타입 및 기능 감지 헬퍼 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `fido_id.c` | 46 | FIDO2/U2F 보안 키 디바이스 감지 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `fido_id_desc.c` | 26 | FIDO 디바이스 설명자 파싱 라이브러리 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `mtd_probe.c` | 14 | MTD 플래시 디바이스 타입 감지 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `probe_smartmedia.c` | 34 | SmartMedia 플래시 카드 감지 헬퍼 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `naming-scheme.c` | 28 | 예측 가능 네트워크 인터페이스 이름 스킴 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `scsi_id.c` | 294 | SCSI 디스크 고유 ID 추출 도구 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `scsi_serial.c` | 372 | SCSI INQUIRY 명령으로 시리얼 번호 추출 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-blkid.c` | 167 | blkid 기반 블록 디바이스 ID 추출 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-btrfs.c` | 14 | Btrfs 장치 정보 udev 속성 설정 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-input_id.c` | 189 | 입력 디바이스 타입 분류 (마우스/키보드 등) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-keyboard.c` | 144 | 키보드 키코드 재매핑 처리 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-net_id.c` | 473 | 네트워크 인터페이스 예측 가능 이름 생성 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-path_id.c` | 373 | 디바이스 경로 기반 ID 생성 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-uaccess.c` | 31 | 로그인 세션별 디바이스 uaccess ACL 설정 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-builtin-usb_id.c` | 269 | USB 디바이스 ID/속성 추출 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udev-node.c` | 266 | 디바이스 노드 생성/심볼릭 링크 관리 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-control.c` | 89 | udevadm control 명령 구현 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-hwdb.c` | 39 | udevadm hwdb 명령 (HW DB 갱신) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-info.c` | 249 | udevadm info 명령 (디바이스 속성 출력) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-monitor.c` | 130 | udevadm monitor 명령 (이벤트 실시간 출력) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-settle.c` | 83 | udevadm settle 명령 (이벤트 처리 대기) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-test-builtin.c` | 43 | udevadm test-builtin 명령 (빌트인 테스트) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-test.c` | 68 | udevadm test 명령 (규칙 시뮬레이션) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-trigger.c` | 209 | udevadm trigger 명령 (이벤트 재전송) | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm-util.c` | 23 | udevadm 공통 유틸리티 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |
| `udevadm.c` | 45 | udevadm 메인 진입점 (다중 명령 라우팅) | ❌ 불가 | udevadm 진입점, 디바이스 관리 필수 |
| `v4l_id.c` | 39 | V4L2 비디오 디바이스 타입 및 속성 감지 | ❌ 불가 | udevd 핵심 구성요소 또는 udevadm 관리 도구 |

> **테스트 코드** (3개): `fuzz-fido-id-desc.c`, `test-fido-id-desc.c`, `fuzz-link-parser.c`

### login — logind 핵심

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `inhibit.c` | 146 | inhibit 잠금 생성/관리 CLI (systemd-inhibit) | ❌ 불가 | logind 핵심 구성요소 |
| `loginctl.c` | 714 | loginctl CLI 도구 (로그인 세션/사용자 조회) | ❌ 불가 | logind 핵심 구성요소 |
| `logind-acl.c` | 134 | 로그인 세션별 디바이스 ACL 관리 | ❌ 불가 | logind 핵심 구성요소 |
| `logind-brightness.c` | 115 | logind-brightness 구현 | ❌ 불가 | logind 핵심 구성요소 |
| `logind-button.c` | 185 | 전원/슬립 버튼 입력 처리 | ❌ 불가 | logind 핵심 구성요소 |
| `logind-inhibit.c` | 268 | 시스템 슬립/종료 억제(inhibit) 관리 | ❌ 불가 | logind 핵심 구성요소 |
| `logind-session-device.c` | 249 | 세션별 디바이스 할당/해제 | ❌ 불가 | logind 핵심 구성요소 |
| `logind-utmp.c` | 77 | utmp/wtmp 로그인 기록 업데이트 | ❌ 불가 | logind 핵심 구성요소 |
| `pam_systemd.c` | 377 | PAM systemd 모듈 (로그인 세션 등록) | ❌ 불가 | PAM 로그인 모듈, session 생성에 필요 |
| `sysfs-show.c` | 81 | sysfs-show 구현 | ❌ 불가 | logind 핵심 구성요소 |
| `user-runtime-dir.c` | 120 | user-runtime-dir 구현 | ❌ 불가 | logind 핵심 구성요소 |

> **테스트 코드** (3개): `test-inhibit.c`, `test-login-shared.c`, `test-login-tables.c`

### basic — 공유 기본 유틸리티 라이브러리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `af-list.c` | 12 | 주소 패밀리(AF_*) 이름 목록 정의 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `arphrd-list.c` | 6 | ARP 하드웨어 타입(ARPHRD_*) 목록 정의 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `blockdev-util.c` | 90 | 블록 디바이스 경로/번호 조회 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `copy.c` | 421 | 파일/디렉토리 복사 유틸리티 (sendfile 활용) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `device-nodes.c` | 28 | 디바이스 노드 이름 검증 함수 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `errno-list.c` | 10 | errno 이름 목록 정의 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `ether-addr-util.c` | 39 | 이더넷 MAC 주소 파싱/포맷 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `kbd-util.c` | 47 | 키보드 레이아웃 목록 열거 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `khash.c` | 157 | 커널 AF_ALG 기반 해시 계산 래퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `memfd-util.c` | 74 | memfd_create() 기반 메모리 파일 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `namespace-util.c` | 89 | Linux 네임스페이스 타입 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `ordered-set.c` | 41 | 삽입 순서 보장 Set 자료구조 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `replace-var.c` | 50 | 문자열 내 ${VAR} 치환 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `sort-util.c` | 12 | 타입 안전 정렬 매크로 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |
| `strbuf.c` | 85 | 중복 제거 문자열 버퍼 (Trie 기반) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 기본 라이브러리 |

### shared — 공유 유틸리티 라이브러리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `acl-util.c` | 251 | POSIX ACL 조회/설정 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `apparmor-util.c` | 8 | AppArmor 프로필 로드/상태 확인 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `ask-password-api.c` | 556 | 패스워드 요청/수신 API (소켓 기반) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `barrier.c` | 110 | fork 경계 동기화 추상화 레이어 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `base-filesystem.c` | 43 | 최소 파일시스템 구조 생성 (/usr 심볼릭 링크 등) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `bootspec.c` | 824 | Boot Loader Spec 부트 항목 파싱 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `bus-unit-procs.c` | 213 | bus-unit-procs 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `bus-unit-util.c` | 1060 | 유닛 프로퍼티 설정 dbus 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `bus-wait-for-jobs.c` | 156 | 유닛 작업 완료 대기 dbus 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `bus-wait-for-units.c` | 189 | 유닛 상태 변경 대기 dbus 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `calendarspec.c` | 756 | OnCalendar 타이머 표현식 파싱/생성 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `cgroup-show.c` | 179 | cgroup 트리 출력 (cgls 등에서 사용) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `clean-ipc.c` | 231 | 프로세스 종료 시 IPC 자원(세마포어 등) 정리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `dissect-image.c` | 632 | 디스크 이미지 파티션 분석/마운트 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `dm-util.c` | 12 | dm 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `dns-domain.c` | 587 | DNS 도메인 이름 파싱/검증 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `env-file-label.c` | 7 | env-file-label 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `ethtool-util.c` | 455 | ethtool 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `fileio-label.c` | 12 | fileio-label 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `format-table.c` | 1039 | 표 형식 터미널 출력 라이브러리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `generator.c` | 206 | generator 유닛 파일 쓰기 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `id128-print.c` | 32 | 128-bit ID 포맷 출력 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `ima-util.c` | 4 | IMA 무결성 측정 서브시스템 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `import-util.c` | 85 | 이미지 임포트 공통 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `install-printf.c` | 60 | 유닛 설치 시 specifier 치환 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `install.c` | 1637 | 유닛 enable/disable (systemctl enable) 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `ip-protocol-list.c` | 24 | IP 프로토콜 번호↔이름 변환 목록 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `journal-importer.c` | 256 | 외부 저널 항목 파싱 임포터 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `local-addresses.c` | 157 | local-addresses 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `lockfile-util.c` | 58 | lockfile 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `logs-show.c` | 783 | logs-show 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `loop-util.c` | 81 | loop 블록 디바이스 생성/관리 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `machine-image.c` | 603 | 컨테이너 이미지 탐색/관리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `machine-pool.c` | 21 | 컨테이너 이미지 풀 크기 관리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `module-util.c` | 32 | module 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `mount-util.c` | 241 | 마운트/언마운트 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `nscd-flush.c` | 63 | nscd-flush 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `nsflags.c` | 33 | 네임스페이스 플래그 이름 변환 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `output-mode.c` | 3 | 출력 모드 이름 파싱 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `pager.c` | 151 | less/more 페이저 실행 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `pretty-print.c` | 167 | 표/목록 포맷 터미널 출력 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `ptyfwd.c` | 297 | PTY 포워딩 (nspawn 터미널 등) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `reboot-util.c` | 43 | reboot 파라미터 설정/조회 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `resolve-util.c` | 12 | DNS 조회 모드 파싱 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `serialize.c` | 115 | 데몬 직렬화/역직렬화 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `sleep-config.c` | 352 | 슬립/하이버네이트 설정 파싱 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `spawn-ask-password-agent.c` | 17 | spawn-ask-password-agent 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `spawn-polkit-agent.c` | 8 | spawn-polkit-agent 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `switch-root.c` | 55 | initrd에서 실제 루트로 전환(switch_root) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `tests.c` | 99 | 공유 테스트 인프라 헬퍼 함수 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `tmpfile-util-label.c` | 7 | tmpfile-util-label 구현 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `tomoyo-util.c` | 6 | tomoyo 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `uid-range.c` | 100 | UID/GID 범위 파싱 유틸리티 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `utmp-wtmp.c` | 206 | utmp/wtmp 로그인 기록 처리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `verbs.c` | 57 | CLI 동사(verb) 라우팅 헬퍼 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `vlan-util.c` | 44 | vlan 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `volatile-util.c` | 16 | volatile 루트 파일시스템 모드 감지 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `watchdog.c` | 75 | 하드웨어 워치독 타이머 관리 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `wifi-util.c` | 64 | wifi 관련 유틸리티 함수 모음 | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |
| `xml.c` | 114 | 경량 XML 파서 (DBUS 인트로스펙션용) | ❌ 불가 | 다수 컴포넌트에 링크되는 공유 유틸리티 라이브러리 |

### libsystemd — libsystemd 공개 API

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `bus-bloom.c` | 65 | bus-bloom 구현 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `bus-container.c` | 122 | 컨테이너 내부 dbus 소켓 연결 처리 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `bus-dump.c` | 386 | dbus 메시지 사람이 읽을 수 있는 덤프 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `bus-gvariant.c` | 133 | GLib GVariant 직렬화 형식 지원 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `bus-introspect.c` | 108 | dbus 인트로스펙션 XML 생성 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `hwdb-util.c` | 344 | hwdb 관련 유틸리티 함수 모음 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `sd-login.c` | 557 | sd_login_* 공개 API 구현 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `generic-netlink.c` | 90 | generic-netlink 구현 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `netlink-util.c` | 54 | netlink 관련 유틸리티 함수 모음 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `network-util.c` | 15 | network 관련 유틸리티 함수 모음 | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `sd-network.c` | 236 | 네트워크 인터페이스 상태 조회 API | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `sd-resolve.c` | 617 | 비동기 DNS 조회 API (getaddrinfo 래퍼) | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |
| `sd-utf8.c` | 6 | UTF-8 인코딩 검증 및 변환 API | ❌ 불가 | libsystemd 공개 API - 외부 앱 의존 |

> **테스트 코드** (29개): `test-bus-address.c`, `test-bus-async-match.c`, `test-bus-benchmark.c`, `test-bus-chat.c`, `test-bus-cleanup.c`, `test-bus-creds.c`, `test-bus-error.c`, `test-bus-gvariant.c`, `test-bus-introspect.c`, `test-bus-kernel-bloom.c`, `test-bus-kernel.c`, `test-bus-marshal.c`, `test-bus-match.c`, `test-bus-objects.c`, `test-bus-queue-ref-cycle.c`, `test-bus-server.c`, `test-bus-signature.c`, `test-bus-track.c`, `test-bus-vtable.c`, `test-bus-watch-bind.c`, `test-bus-zero-copy.c`, `test-sd-device-monitor.c`, `test-sd-device-thread.c`, `test-sd-device.c`, `test-udev-device-thread.c`, `test-event.c`, `test-login.c`, `test-netlink.c`, `test-resolve.c`

### libsystemd-network — 네트워크 라이브러리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `arp-util.c` | 43 | arp 관련 유틸리티 함수 모음 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp-identifier.c` | 102 | DHCP 클라이언트 ID(DUID/IAID) 생성 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp-network.c` | 83 | DHCP 소켓 생성 및 바인드 헬퍼 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp-option.c` | 162 | DHCPv4 옵션 인코딩/디코딩 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp-packet.c` | 77 | DHCPv4 패킷 생성 및 파싱 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp6-network.c` | 29 | DHCPv6 소켓 생성 및 관리 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `dhcp6-option.c` | 284 | DHCPv6 옵션 파싱 및 인코딩 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `icmp6-util.c` | 85 | ICMPv6 소켓 생성 및 수신 처리 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `lldp-neighbor.c` | 424 | lldp-neighbor 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `lldp-network.c` | 29 | LLDP 이더넷 프레임 수신 소켓 설정 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `ndisc-router.c` | 418 | NDP Router Advertisement 메시지 파싱 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `network-internal.c` | 429 | network-internal 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-dhcp-client.c` | 928 | DHCPv4 클라이언트 상태 머신 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-dhcp-lease.c` | 749 | DHCPv4 임대 정보 파싱 및 관리 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-dhcp-server.c` | 594 | DHCPv4 서버 기능 구현 | ⚠️ 조건부 가능 | DHCP 서버 기능 미사용 시 제외 가능 |
| `sd-dhcp6-client.c` | 722 | DHCPv6 클라이언트 상태 머신 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-dhcp6-lease.c` | 206 | sd_dhcp6_lease_* 공개 API 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-ipv4acd.c` | 225 | IPv4 주소 충돌 감지(ACD/DAD) 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-ipv4ll.c` | 143 | IPv4 링크로컬 주소 자동 설정(Zeroconf) | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-lldp.c` | 254 | sd_lldp_* 공개 API 구현 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-ndisc.c` | 198 | NDP Router Discovery 클라이언트 | ❌ 불가 | 네트워크 관련 공유 라이브러리 |
| `sd-radv.c` | 453 | NDP Router Advertisement 전송 구현 | ⚠️ 조건부 가능 | RA 전송 기능 미사용 시 제외 가능 |

> **테스트 코드** (11개): `test-acd.c`, `test-dhcp-client.c`, `test-dhcp-option.c`, `test-dhcp-server.c`, `test-dhcp6-client.c`, `test-ipv4ll-manual.c`, `test-ipv4ll.c`, `test-lldp.c`, `test-ndisc-ra.c`, `test-ndisc-rs.c`, `test-sd-dhcp-lease.c`

### nspawn — systemd-nspawn 컨테이너 도구

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `nspawn-cgroup.c` | 302 | nspawn cgroup 격리 설정 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-expose-ports.c` | 119 | nspawn 포트 포워딩 설정 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-mount.c` | 655 | nspawn 마운트 포인트 설정 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-network.c` | 393 | nspawn 네트워크 인터페이스 설정 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-oci.c` | 914 | OCI(컨테이너 표준) 번들 파싱 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-patch-uid.c` | 264 | nspawn UID 매핑 패치 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-register.c` | 157 | machined에 컨테이너 등록 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-seccomp.c` | 2 | nspawn seccomp 필터 설정 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-settings.c` | 390 | nspawn .nspawn 설정 파일 처리 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-setuid.c` | 141 | nspawn 내부 setuid 실행 헬퍼 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn-stub-pid1.c` | 89 | 컨테이너 내 스텁 PID1 구현 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |
| `nspawn.c` | 2603 | systemd-nspawn 컨테이너 실행 메인 | ✅ 가능 | Tizen에서 컨테이너 기능 미사용 시 제외 가능 |

> **테스트 코드** (2개): `test-nspawn-tables.c`, `test-patch-uid.c`

### machine — systemd-machined 컨테이너 관리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `image-dbus.c` | 231 | 컨테이너 이미지 dbus 인터페이스 | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |
| `machine-dbus.c` | 795 | machined 컨테이너 dbus API | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |
| `machine.c` | 368 | 컨테이너 인스턴스 관리 객체 | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |
| `machined-core.c` | 15 | machined 코어 기능 (컨테이너 추적) | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |
| `machined-dbus.c` | 822 | machined 메인 dbus 서비스 | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |
| `operation.c` | 75 | 비동기 machined 작업 관리 | ⚠️ 조건부 가능 | 컨테이너 관리(machined) 미사용 시 제외 가능 |

### resolve — systemd-resolved DNS 리졸버

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `dns-type.c` | 86 | DNS 레코드 타입 이름 변환 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |
| `resolved-dns-answer.c` | 390 | resolved-dns-answer 구현 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |
| `resolved-dns-dnssec.c` | 58 | resolved-dns-dnssec 구현 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |
| `resolved-dns-packet.c` | 1237 | DNS 패킷 생성/파싱 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |
| `resolved-dns-question.c` | 215 | resolved-dns-question 구현 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |
| `resolved-dns-rr.c` | 972 | resolved-dns-rr 구현 | ✅ 가능 | systemd-resolved Tizen에서 비활성화 |

### locale — systemd-localed 로케일 설정

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `keymap-util.c` | 438 | keymap 관련 유틸리티 함수 모음 | ⚠️ 조건부 가능 | systemd-localed Tizen에서 미사용 시 제외 가능 |
| `localectl.c` | 229 | localectl CLI 도구 | ⚠️ 조건부 가능 | systemd-localed Tizen에서 미사용 시 제외 가능 |
| `localed.c` | 320 | systemd-localed 로케일 설정 데몬 | ⚠️ 조건부 가능 | systemd-localed Tizen에서 미사용 시 제외 가능 |

> **테스트 코드** (1개): `test-keymap-util.c`

### journal-remote — 원격 저널 수집

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `journal-remote-parse.c` | 38 | journal-remote-parse 구현 | ✅ 가능 | 원격 저널 수집 기능 임베디드에서 불필요 |
| `journal-remote-write.c` | 56 | journal-remote-write 구현 | ✅ 가능 | 원격 저널 수집 기능 임베디드에서 불필요 |
| `journal-remote.c` | 251 | journal-remote 구현 | ✅ 가능 | 원격 저널 수집 기능 임베디드에서 불필요 |

### import — systemd-importd 이미지 임포트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `qcow2-util.c` | 143 | qcow2 관련 유틸리티 함수 모음 | ✅ 가능 | 컨테이너 이미지 임포트 기능 불필요 |

> **테스트 코드** (1개): `test-qcow2.c`

### partition — systemd-repart 파티셔닝

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `growfs.c` | 123 | 파일시스템 온라인 확장 서비스 (growfs) | ✅ 가능 | 디스크 파티셔닝 도구 런타임 불필요 |
| `makefs.c` | 37 | 파일시스템 생성 서비스 (systemd-makefs) | ✅ 가능 | 디스크 파티셔닝 도구 런타임 불필요 |

### analyze — systemd-analyze 분석 도구

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `analyze-condition.c` | 54 | 유닛 Condition 평가 분석 | ✅ 가능 | 개발/디버깅용 CLI, 프로덕션 빌드 제외 가능 |
| `analyze-security.c` | 614 | 유닛 보안 설정 점수 분석 | ✅ 가능 | 개발/디버깅용 CLI, 프로덕션 빌드 제외 가능 |
| `analyze-verify.c` | 160 | 유닛 파일 유효성 검증 | ✅ 가능 | 개발/디버깅용 CLI, 프로덕션 빌드 제외 가능 |
| `analyze.c` | 1106 | systemd-analyze 분석 도구 메인 | ✅ 가능 | 개발/디버깅용 CLI, 프로덕션 빌드 제외 가능 |

### systemctl — systemctl CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `systemctl.c` | 4595 | systemctl 메인 CLI 진입점 | ❌ 불가 | systemd 관리 CLI, 운영에 필수 |
| `sysv-compat.c` | 32 | SysV init 호환 systemctl 처리 | ❌ 불가 | systemd 관리 CLI, 운영에 필수 |

### busctl — busctl CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `busctl-introspect.c` | 329 | dbus 인트로스펙션 XML 출력 | ✅ 가능 | dbus 디버깅 CLI, 프로덕션 빌드 제외 가능 |
| `busctl.c` | 1538 | dbus 메시지 버스 조회 CLI 도구 | ✅ 가능 | dbus 디버깅 CLI, 프로덕션 빌드 제외 가능 |

### cgls — systemd-cgls CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `cgls.c` | 139 | cgroup 트리 계층 출력 도구 | ✅ 가능 | cgroup 조회 CLI, 프로덕션 빌드 제외 가능 |

### cgtop — systemd-cgtop CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `cgtop.c` | 559 | cgroup별 리소스 사용량 실시간 표시 | ✅ 가능 | cgroup 모니터링 CLI, 프로덕션 빌드 제외 가능 |

### delta — systemd-delta CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `delta.c` | 328 | 유닛 파일 오버라이드 변경사항 비교 | ✅ 가능 | 설정 비교 CLI, 프로덕션 빌드 제외 가능 |

### dissect — systemd-dissect CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `dissect.c` | 134 | 디스크/OS 이미지 분석 및 마운트 CLI | ✅ 가능 | 이미지 분석 CLI, 런타임 불필요 |

### detect-virt — systemd-detect-virt CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `detect-virt.c` | 75 | 가상화/컨테이너 환경 감지 CLI | ❌ 불가 | 가상화 환경 감지로 조건부 서비스에 사용 |

### escape — systemd-escape CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `escape.c` | 121 | 유닛 이름 문자 이스케이프/언이스케이프 | ❌ 불가 | 유닛 이름 처리 시 필요한 도구 |

### mount — systemd-mount CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `mount-tool.c` | 838 | mount-tool 구현 | ❌ 불가 | 마운트 유닛 생성 CLI |

### run — systemd-run CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `run.c` | 891 | systemd-run 임시 유닛 실행 CLI | ❌ 불가 | 임시 유닛 실행 CLI |

### notify — systemd-notify CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `notify.c` | 95 | sd_notify() 전송 CLI (서비스 상태 알림) | ❌ 불가 | 서비스 상태 알림 CLI |

### id128 — systemd-id128 CLI

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `id128.c` | 74 | machine-id/app-id 128비트 값 출력 CLI | ❌ 불가 | machine-id 조회 CLI |

### boot — EFI 부팅 관련 도구

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `bless-boot-generator.c` | 28 | 부팅 성공 확인 generator | ⚠️ 조건부 가능 | UEFI 부트 도구 - Tizen x86 에뮬레이터 불필요 |
| `bless-boot.c` | 269 | EFI 부팅 성공 표시 유틸리티 | ⚠️ 조건부 가능 | UEFI 부트 도구 - Tizen x86 에뮬레이터 불필요 |
| `boot-check-no-failures.c` | 43 | 부팅 실패 유닛 존재 여부 확인 | ⚠️ 조건부 가능 | UEFI 부트 도구 - Tizen x86 에뮬레이터 불필요 |
| `bootctl.c` | 952 | EFI 부트 엔트리 관리 CLI | ⚠️ 조건부 가능 | UEFI 부트 도구 - Tizen x86 에뮬레이터 불필요 |

### binfmt — systemd-binfmt 서비스

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `binfmt.c` | 105 | 바이너리 포맷 등록 서비스 | ❌ 불가 | 실행 파일 포맷 등록 서비스 |

### cgroups-agent — cgroup 알림 에이전트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `cgroups-agent.c` | 21 | cgroup.events 변경 알림 에이전트 | ❌ 불가 | cgroup v1 알림 에이전트 |

### dbus1-generator — dbus1 서비스 generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `dbus1-generator.c` | 167 | dbus1 서비스 파일→유닛 자동 변환 | ❌ 불가 | dbus1 서비스 자동 활성화에 필요 |

### debug-generator — 디버그 generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `debug-generator.c` | 96 | 커널 cmdline 기반 디버그 유닛 생성 | ✅ 가능 | 디버깅 전용 generator |

### fstab-generator — fstab generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `fstab-generator.c` | 443 | fstab 기반 마운트 유닛 자동 생성 | ❌ 불가 | fstab 기반 마운트에 필수 |

### getty-generator — getty generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `getty-generator.c` | 95 | getty 서비스 자동 생성 generator | ❌ 불가 | 터미널 로그인 세션 생성에 필요 |

### gpt-auto-generator — GPT 자동 마운트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `gpt-auto-generator.c` | 398 | GPT 파티션 자동 마운트 generator | ⚠️ 조건부 가능 | GPT 자동 마운트 - 에뮬레이터 불필요 |

### fsck — 파일시스템 검사

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `fsck.c` | 203 | 부팅 시 파일시스템 검사 서비스 | ❌ 불가 | 부팅 시 파일시스템 검사에 필요 |

### modules-load — 커널 모듈 로드

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `modules-load.c` | 112 | modules-load.d/ 기반 커널 모듈 로드 | ❌ 불가 | 커널 모듈 자동 로드 필수 |

### quotacheck — 디스크 쿼터 검사

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `quotacheck.c` | 30 | 파일시스템 디스크 쿼터 검사 | ⚠️ 조건부 가능 | 디스크 쿼터 미사용 Tizen 환경에서 제외 가능 |

### remount-fs — 파일시스템 재마운트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `remount-fs.c` | 71 | 루트 파일시스템 읽기전용→읽기쓰기 재마운트 | ❌ 불가 | 루트 파일시스템 재마운트 필수 |

### shutdown — 시스템 종료 처리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `shutdown.c` | 274 | 시스템 종료 마지막 단계 처리 | ❌ 불가 | 시스템 종료 최종 처리 필수 |
| `umount.c` | 354 | 종료 시 파일시스템 언마운트 처리 | ❌ 불가 | 시스템 종료 최종 처리 필수 |

### sleep — 슬립/하이버네이트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `sleep.c` | 155 | 슬립/하이버네이트 모드 전환 서비스 | ❌ 불가 | 슬립/하이버네이트 처리 |

### sysctl — sysctl 파라미터 설정

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `sysctl.c` | 171 | sysctl.d/ 기반 커널 파라미터 설정 | ❌ 불가 | 커널 파라미터 설정 필수 |

### system-update-generator — 시스템 업데이트 generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `system-update-generator.c` | 25 | 시스템 업데이트 target 전환 generator | ❌ 불가 | 업데이트 모드 전환 generator |

### tmpfiles — 임시 파일 관리

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `tmpfiles.c` | 1594 | tmpfiles.d/ 규칙 기반 파일 생성/삭제 | ❌ 불가 | 임시 파일 디렉토리 관리 필수 |

### user-sessions — 사용자 세션

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `user-sessions.c` | 16 | 사용자 세션 활성화/비활성화 서비스 | ❌ 불가 | 사용자 세션 활성화 필수 |

### vconsole — 가상 콘솔 설정

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `vconsole-setup.c` | 249 | 가상 콘솔 키맵/폰트 초기화 | ❌ 불가 | 콘솔 키맵/폰트 설정 |

### volatile-root — volatile 루트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `volatile-root.c` | 114 | volatile 루트 파일시스템 초기화 | ❌ 불가 | volatile 루트 파일시스템 지원 |

### update-done — 업데이트 완료 기록

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `update-done.c` | 24 | 패키지 업데이트 완료 타임스탬프 기록 | ⚠️ 조건부 가능 | 패키지 관리 미사용 시 제외 가능 |

### update-utmp — utmp/wtmp 업데이트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `update-utmp.c` | 81 | runlevel/부팅완료 시 utmp 기록 | ❌ 불가 | 로그인 기록 유지 |

### ac-power — AC 전원 감지

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `ac-power.c` | 36 | AC 전원 연결 여부 확인 도구 | ❌ 불가 | AC 전원 감지, upower 대체로 사용됨 |

### activate — 소켓 활성화

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `activate.c` | 267 | 소켓 기반 서비스 on-demand 활성화 | ❌ 불가 | 소켓 활성화 헬퍼 |

### ask-password — 패스워드 요청

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `ask-password.c` | 74 | 터미널/Plymouth 패스워드 요청 | ❌ 불가 | 암호화 디스크 잠금 해제 등에 필요 |

### initctl — SysV initctl 호환

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `initctl.c` | 188 | SysV /dev/initctl 호환 인터페이스 | ✅ 가능 | SysV 호환 인터페이스, Tizen 불필요 |

### machine-id-setup — machine-id 초기화

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `machine-id-setup-main.c` | 56 | machine-id-setup-main 구현 | ❌ 불가 | machine-id 초기화 필수 |

### nss-myhostname — 호스트명 NSS

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `nss-myhostname.c` | 268 | 호스트명 NSS 플러그인 구현 | ❌ 불가 | 호스트명 조회 NSS 플러그인 |

### path — path 유닛

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `path.c` | 64 | path 유닛 파일 변경 감시 구현 | ❌ 불가 | path 유닛 구현 |

### reply-password — 패스워드 응답

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `reply-password.c` | 40 | 패스워드 에이전트 응답 전송 | ❌ 불가 | 패스워드 에이전트 응답 필수 |

### run-generator — 임시 유닛 generator

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `run-generator.c` | 59 | 커널 cmdline 기반 임시 유닛 생성 | ❌ 불가 | 커널 cmdline 유닛 생성 |

### socket-proxy — 소켓 프록시

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `socket-proxyd.c` | 357 | socket-proxyd 구현 | ✅ 가능 | 특수 목적 소켓 프록시 |

### stdio-bridge — stdio dbus 브릿지

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `stdio-bridge.c` | 132 | stdin/stdout ↔ dbus 소켓 브릿지 | ✅ 가능 | 특수 환경 dbus 브릿지 |

### sulogin-shell — 비상 복구 쉘

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `sulogin-shell.c` | 48 | 비상 복구 쉘 실행 래퍼 | ❌ 불가 | 비상 복구 쉘 필수 |

### tty-ask-password-agent — TTY 패스워드 에이전트

| 파일 | 라인 수 | 역할 요약 | 빌드 제외 | 의견 |
|------|---------|----------|-----------|------|
| `tty-ask-password-agent.c` | 324 | TTY 패스워드 요청 수신 에이전트 | ❌ 불가 | TTY 패스워드 요청 처리 |

### 테스트·퍼징 코드 전체 목록

> 총 240개. 런타임 미배포, 분석 제외.

| 파일 경로 | 라인 수 |
|-----------|---------|
| `fuzz/fuzz-bus-label.c` | 7 |
| `fuzz/fuzz-bus-message.c` | 23 |
| `fuzz/fuzz-calendarspec.c` | 11 |
| `fuzz/fuzz-catalog.c` | 12 |
| `fuzz/fuzz-compress.c` | 31 |
| `fuzz/fuzz-dhcp-server.c` | 31 |
| `fuzz/fuzz-dhcp6-client.c` | 28 |
| `fuzz/fuzz-dns-packet.c` | 12 |
| `fuzz/fuzz-env-file.c` | 12 |
| `fuzz/fuzz-hostname-util.c` | 10 |
| `fuzz/fuzz-journal-remote.c` | 40 |
| `fuzz/fuzz-journald-audit.c` | 6 |
| `fuzz/fuzz-journald-kmsg.c` | 7 |
| `fuzz/fuzz-journald-native-fd.c` | 28 |
| `fuzz/fuzz-journald-native.c` | 3 |
| `fuzz/fuzz-journald-stream.c` | 19 |
| `fuzz/fuzz-journald-syslog.c` | 3 |
| `fuzz/fuzz-journald.c` | 19 |
| `fuzz/fuzz-json.c` | 14 |
| `fuzz/fuzz-lldp.c` | 20 |
| `fuzz/fuzz-main.c` | 17 |
| `fuzz/fuzz-ndisc-rs.c` | 28 |
| `fuzz/fuzz-nspawn-oci.c` | 10 |
| `fuzz/fuzz-nspawn-settings.c` | 10 |
| `fuzz/fuzz-time-util.c` | 14 |
| `fuzz/fuzz-udev-database.c` | 13 |
| `fuzz/fuzz-udev-rules.c` | 44 |
| `fuzz/fuzz-unit-file.c` | 39 |
| `fuzz/fuzz-varlink.c` | 70 |
| `import/test-qcow2.c` | 18 |
| `journal/test-audit-type.c` | 12 |
| `journal/test-catalog.c` | 109 |
| `journal/test-compress-benchmark.c` | 86 |
| `journal/test-compress.c` | 124 |
| `journal/test-journal-config.c` | 24 |
| `journal/test-journal-enum.c` | 15 |
| `journal/test-journal-flush.c` | 34 |
| `journal/test-journal-init.c` | 25 |
| `journal/test-journal-interleaving.c` | 177 |
| `journal/test-journal-match.c` | 35 |
| `journal/test-journal-send.c` | 29 |
| `journal/test-journal-stream.c` | 108 |
| `journal/test-journal-syslog.c` | 26 |
| `journal/test-journal-verify.c` | 68 |
| `journal/test-journal.c` | 143 |
| `journal/test-mmap-cache.c` | 36 |
| `libsystemd-network/test-acd.c` | 49 |
| `libsystemd-network/test-dhcp-client.c` | 258 |
| `libsystemd-network/test-dhcp-option.c` | 196 |
| `libsystemd-network/test-dhcp-server.c` | 145 |
| `libsystemd-network/test-dhcp6-client.c` | 493 |
| `libsystemd-network/test-ipv4ll-manual.c` | 56 |
| `libsystemd-network/test-ipv4ll.c` | 112 |
| `libsystemd-network/test-lldp.c` | 168 |
| `libsystemd-network/test-ndisc-ra.c` | 175 |
| `libsystemd-network/test-ndisc-rs.c` | 210 |
| `libsystemd-network/test-sd-dhcp-lease.c` | 50 |
| `libsystemd/sd-bus/test-bus-address.c` | 34 |
| `libsystemd/sd-bus/test-bus-async-match.c` | 170 |
| `libsystemd/sd-bus/test-bus-benchmark.c` | 207 |
| `libsystemd/sd-bus/test-bus-chat.c` | 284 |
| `libsystemd/sd-bus/test-bus-cleanup.c` | 44 |
| `libsystemd/sd-bus/test-bus-creds.c` | 16 |
| `libsystemd/sd-bus/test-bus-error.c` | 134 |
| `libsystemd/sd-bus/test-bus-gvariant.c` | 153 |
| `libsystemd/sd-bus/test-bus-introspect.c` | 19 |
| `libsystemd/sd-bus/test-bus-kernel-bloom.c` | 78 |
| `libsystemd/sd-bus/test-bus-kernel.c` | 108 |
| `libsystemd/sd-bus/test-bus-marshal.c` | 277 |
| `libsystemd/sd-bus/test-bus-match.c` | 90 |
| `libsystemd/sd-bus/test-bus-objects.c` | 307 |
| `libsystemd/sd-bus/test-bus-queue-ref-cycle.c` | 24 |
| `libsystemd/sd-bus/test-bus-server.c` | 103 |
| `libsystemd/sd-bus/test-bus-signature.c` | 119 |
| `libsystemd/sd-bus/test-bus-track.c` | 62 |
| `libsystemd/sd-bus/test-bus-vtable.c` | 29 |
| `libsystemd/sd-bus/test-bus-watch-bind.c` | 124 |
| `libsystemd/sd-bus/test-bus-zero-copy.c` | 122 |
| `libsystemd/sd-device/test-sd-device-monitor.c` | 138 |
| `libsystemd/sd-device/test-sd-device-thread.c` | 16 |
| `libsystemd/sd-device/test-sd-device.c` | 101 |
| `libsystemd/sd-device/test-udev-device-thread.c` | 14 |
| `libsystemd/sd-event/test-event.c` | 301 |
| `libsystemd/sd-login/test-login.c` | 189 |
| `libsystemd/sd-netlink/test-netlink.c` | 412 |
| `libsystemd/sd-resolve/test-resolve.c` | 47 |
| `locale/test-keymap-util.c` | 134 |
| `login/test-inhibit.c` | 49 |
| `login/test-login-shared.c` | 12 |
| `login/test-login-tables.c` | 9 |
| `nspawn/test-nspawn-tables.c` | 4 |
| `nspawn/test-patch-uid.c` | 20 |
| `test/test-acl-util.c` | 36 |
| `test/test-af-list.c` | 11 |
| `test/test-alloc-util.c` | 108 |
| `test/test-architecture.c` | 28 |
| `test/test-arphrd-list.c` | 12 |
| `test/test-ask-password-api.c` | 12 |
| `test/test-async.c` | 16 |
| `test/test-barrier.c` | 51 |
| `test/test-bitmap.c` | 84 |
| `test/test-boot-timestamps.c` | 46 |
| `test/test-bpf-devices.c` | 185 |
| `test/test-bpf-firewall.c` | 116 |
| `test/test-btrfs.c` | 121 |
| `test/test-bus-util.c` | 31 |
| `test/test-calendarspec.c` | 203 |
| `test/test-cap-list.c` | 65 |
| `test/test-capability.c` | 155 |
| `test/test-cgroup-cpu.c` | 18 |
| `test/test-cgroup-mask.c` | 104 |
| `test/test-cgroup-setup.c` | 33 |
| `test/test-cgroup-unit-default.c` | 56 |
| `test/test-cgroup-util.c` | 317 |
| `test/test-cgroup.c` | 56 |
| `test/test-chase-symlinks.c` | 45 |
| `test/test-chown-rec.c` | 105 |
| `test/test-clock.c` | 27 |
| `test/test-condition.c` | 632 |
| `test/test-conf-files.c` | 84 |
| `test/test-conf-parser.c` | 205 |
| `test/test-copy.c` | 187 |
| `test/test-cpu-set-util.c` | 225 |
| `test/test-daemon.c` | 24 |
| `test/test-date.c` | 79 |
| `test/test-dev-setup.c` | 36 |
| `test/test-device-nodes.c` | 21 |
| `test/test-dissect-image.c` | 23 |
| `test/test-dlopen.c` | 5 |
| `test/test-dns-domain.c` | 605 |
| `test/test-ellipsize.c` | 82 |
| `test/test-emergency-action.c` | 39 |
| `test/test-engine.c` | 106 |
| `test/test-env-file.c` | 79 |
| `test/test-env-util.c` | 205 |
| `test/test-escape.c` | 118 |
| `test/test-exec-util.c` | 259 |
| `test/test-execute.c` | 439 |
| `test/test-exit-status.c` | 32 |
| `test/test-extract-word.c` | 454 |
| `test/test-fd-util.c` | 222 |
| `test/test-fdset.c` | 149 |
| `test/test-fileio.c` | 539 |
| `test/test-format-table.c` | 76 |
| `test/test-format-util.c` | 27 |
| `test/test-fs-util.c` | 560 |
| `test/test-fstab-util.c` | 103 |
| `test/test-glob-util.c` | 59 |
| `test/test-hash.c` | 46 |
| `test/test-hashmap-ordered.c` | 780 |
| `test/test-hashmap-plain.c` | 775 |
| `test/test-hashmap.c` | 78 |
| `test/test-hexdecoct.c` | 280 |
| `test/test-hostname-util.c` | 119 |
| `test/test-hostname.c` | 6 |
| `test/test-id128.c` | 97 |
| `test/test-in-addr-util.c` | 129 |
| `test/test-install-root.c` | 756 |
| `test/test-install.c` | 188 |
| `test/test-io-util.c` | 31 |
| `test/test-ip-protocol-list.c` | 42 |
| `test/test-ipcrm.c` | 13 |
| `test/test-job-type.c` | 37 |
| `test/test-journal-importer.c` | 45 |
| `test/test-json.c` | 261 |
| `test/test-libmount.c` | 46 |
| `test/test-libsystemd-sym.c` | 5 |
| `test/test-libudev-sym.c` | 5 |
| `test/test-libudev.c` | 407 |
| `test/test-list.c` | 145 |
| `test/test-load-fragment.c` | 440 |
| `test/test-local-addresses.c` | 23 |
| `test/test-locale-util.c` | 74 |
| `test/test-log.c` | 31 |
| `test/test-loopback.c` | 7 |
| `test/test-mount-util.c` | 46 |
| `test/test-mountpoint-util.c` | 172 |
| `test/test-namespace.c` | 109 |
| `test/test-netlink-manual.c` | 66 |
| `test/test-ns.c` | 30 |
| `test/test-nscd-flush.c` | 7 |
| `test/test-nss.c` | 307 |
| `test/test-ordered-set.c` | 81 |
| `test/test-os-util.c` | 9 |
| `test/test-parse-util.c` | 630 |
| `test/test-path-lookup.c` | 58 |
| `test/test-path-util.c` | 494 |
| `test/test-path.c` | 153 |
| `test/test-pretty-print.c` | 20 |
| `test/test-prioq.c` | 70 |
| `test/test-proc-cmdline.c` | 186 |
| `test/test-process-util.c` | 391 |
| `test/test-procfs-util.c` | 27 |
| `test/test-random-util.c` | 38 |
| `test/test-ratelimit.c` | 16 |
| `test/test-replace-var.c` | 13 |
| `test/test-rlimit-util.c` | 88 |
| `test/test-sched-prio.c` | 37 |
| `test/test-sd-hwdb.c` | 42 |
| `test/test-selinux.c` | 62 |
| `test/test-serialize.c` | 130 |
| `test/test-set-disable-mempool.c` | 28 |
| `test/test-set.c` | 68 |
| `test/test-sigbus.c` | 27 |
| `test/test-signal-util.c` | 101 |
| `test/test-siphash24.c` | 67 |
| `test/test-sizeof.c` | 34 |
| `test/test-sleep.c` | 88 |
| `test/test-socket-util.c` | 598 |
| `test/test-specifier.c` | 31 |
| `test/test-stat-util.c` | 108 |
| `test/test-static-destruct.c` | 16 |
| `test/test-strbuf.c` | 50 |
| `test/test-string-util.c` | 409 |
| `test/test-strip-tab-ansi.c` | 48 |
| `test/test-strv.c` | 691 |
| `test/test-strxcpyx.c` | 77 |
| `test/test-tables.c` | 86 |
| `test/test-terminal-util.c` | 82 |
| `test/test-time-util.c` | 402 |
| `test/test-tmpfiles.c` | 35 |
| `test/test-udev.c` | 56 |
| `test/test-uid-range.c` | 54 |
| `test/test-umask-util.c` | 23 |
| `test/test-umount.c` | 32 |
| `test/test-unaligned.c` | 135 |
| `test/test-unit-name.c` | 740 |
| `test/test-user-util.c` | 257 |
| `test/test-utf8.c` | 167 |
| `test/test-util.c` | 271 |
| `test/test-varlink.c` | 131 |
| `test/test-verbs.c` | 19 |
| `test/test-watch-pid.c` | 56 |
| `test/test-watchdog.c` | 22 |
| `test/test-web-util.c` | 15 |
| `test/test-xattr-util.c` | 51 |
| `test/test-xml.c` | 24 |
| `udev/fido_id/fuzz-fido-id-desc.c` | 6 |
| `udev/fido_id/test-fido-id-desc.c` | 31 |
| `udev/net/fuzz-link-parser.c` | 14 |
