# VeryBattery

[English README](./README.md)

VeryBattery는 macOS 메뉴바에서 동작하는 배터리 관리 앱입니다.

장시간 전원 연결 상태에서 배터리 수명을 보호할 수 있도록 충전 제한, 열 보호, 앱 기반 자동화 기능을 제공합니다.

## 주요 기능

- `80% / 100%` 충전 한도 전환
- `80% -> 75%` 히스테리시스 기반 세일링 모드
- 강제 방전 모드
- 온도 기반 열 보호 모드
- 특정 앱 실행 시 자동 풀충전
- 외출 준비용 2시간 임시 풀충전
- 배터리 잔량, 전원 상태, 온도 실시간 표시
- 베이지 배경과 딥그린 포인트의 메뉴바 UI

## 동작 방식

VeryBattery는 `battery` CLI를 사용해 macOS 배터리 충전 동작을 제어합니다.

배포용 빌드에서는 다음 구성이 포함됩니다.

- `battery` CLI를 앱 번들 내부에 포함
- 관리자 권한이 필요한 동작을 위한 privileged helper 포함
- 앱이 XPC를 통해 helper와 통신

일반적인 실행 흐름은 다음과 같습니다.

1. `VeryBattery.app` 실행
2. 메뉴바 팝업 열기
3. 충전 제한이나 강제 방전 같은 privileged 기능 실행
4. macOS가 요구하는 helper 승인 또는 관리자 인증 진행
5. 승인 후 일반 메뉴바 앱처럼 계속 사용

## 설치 방법

1. `VeryBattery.app`를 `/Applications`에 복사
2. 앱 실행
3. macOS가 실행을 막으면 `시스템 설정 > 개인정보 보호 및 보안`에서 허용
4. helper 승인 요청이 뜨면 승인 후 다시 시도

## 배포 관련 주의사항

이 프로젝트는 Mac App Store 배포용이 아니라 일반 배포용입니다.

이유:

- privileged helper 등록이 필요함
- App Sandbox를 비활성화해야 함
- 배터리 제어 기능에 관리자 권한이 필요함

## 개발

Xcode 빌드 명령:

```bash
xcodebuild -project VeryBattery.xcodeproj -scheme VeryBattery -destination 'platform=macOS' build
```

## 배포 및 QA

클린 Mac 테스트 절차, helper 승인 흐름, 서명/노타리제이션 체크는 [DEPLOYMENT.md](./DEPLOYMENT.md)에 정리되어 있습니다.

릴리즈 본문 템플릿은 [RELEASE.md](./RELEASE.md), [RELEASE.ko.md](./RELEASE.ko.md)에 정리되어 있습니다.

## 작성자

John (`nam9295-cmyk`)
