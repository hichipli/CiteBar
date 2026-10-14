<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · **한국어** · [Español](README.es.md) · [Português](README.pt-BR.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar 로고" width="112" height="112">

# CiteBar

**이제 Google Scholar 새로고침은 그만.**<br>
인용 수를 조금 자주 확인하는 모든 분들을 위해.

[다운로드](https://github.com/hichipli/CiteBar/releases/latest) · [웹사이트](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="메뉴 막대 패널에서 Citation Record 스튜디오로: 타임머신을 인용 1,000회를 달성한 날로 되돌린 뒤 Gazette, Certificate, Night 테마를 차례로 적용해 보는 모습" width="420">

</div>

---

## 왜 CiteBar인가요?

20분마다 Google Scholar 프로필을 새로고침한다고 연구가 진척되지는 않으니까요. CiteBar는 자꾸만 들여다보게 되는 브라우저 탭을 메뉴 막대 속 조용한 동반자로 바꿔 줍니다. 하루에 한 번 확인하고, 방금 어떤 논문이 인용되었는지 알려 주고, 나머지 시간에는 방해하지 않습니다.

논문의 영향력을 추적하는 연구자, 첫 인용을 자축하는 박사과정생, 연구실 전체를 챙기는 연구 책임자, 그리고 "혹시 내 h-index가 방금 올랐나?" 하고 궁금해 본 적 있는 모든 분께 딱 맞습니다.

## 빠른 시작

**바로 쓰고 싶으신가요?** 기술적인 내용은 건너뛰고 1분이면 시작할 수 있습니다.

1. **최신 버전 다운로드**
   - [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest)로 이동합니다.
   - `CiteBar-x.x.x-universal-[date].dmg` 파일을 다운로드합니다.
   - 유니버설 DMG는 Apple Silicon Mac과 Intel Mac 모두에서 작동합니다.
   - Homebrew가 편하다면 `brew install --cask hichipli/tap/citebar` 한 줄로 1, 2단계를 대신할 수 있습니다.

2. **CiteBar 설치**
   - DMG를 엽니다.
   - `CiteBar.app`을 `Applications`(응용 프로그램) 폴더로 드래그합니다.
   - `Applications`에서 CiteBar를 실행합니다.

3. **프로필 추가**
   - 처음 실행하면 CiteBar가 Add Profiles 창을 엽니다. Google Scholar 프로필 링크를 붙여 넣으세요.
   - 연구실이나 공동 저자를 함께 보고 싶다면 모든 링크를 한 줄에 하나씩 한꺼번에 붙여 넣고 그룹으로 묶으면 됩니다.
   - 기본값은 하루 한 번 새로고침입니다. Google Scholar 자체가 하루나 이틀에 한 번 갱신되므로 이 정도면 충분히 최신 상태를 유지할 수 있습니다.

전체 프로필 링크를 붙여 넣어도 되고, URL의 `user` 값인 ID만 붙여 넣어도 됩니다.

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

현재 배포 버전은 Apple Developer ID로 서명되고 Apple의 공증(notarization)을 거쳤습니다. 다만 인터넷에서 다운로드한 앱이므로 처음 실행할 때 macOS가 일반적인 확인 창을 띄울 수 있습니다.

`1.3.x` 또는 `1.4.1`에서 업그레이드하는 경우에는 최신 DMG를 한 번만 직접 설치해 주세요. 그 이후로는 앱 내 자동 업데이트가 정상적으로 작동합니다.

설치에 문제가 있나요? [설치 가이드](../DISTRIBUTION.md)(영어)를 참고하세요.

## 주요 기능

<img src="../website/assets/panel.png" alt="CiteBar 패널: 인용 1,284회인 프로필, 연도별 인용 수, 새로 인용된 논문, h-index를 14로 끌어올릴 두 편의 논문, 관심 논문 두 편, 합산 인용 수가 표시된 연구실 그룹" width="360">

**숫자에 맥락을 더하다**
- 인용 수가 메뉴 막대에 표시되고, 클릭하면 패널이 열립니다
- 연도별 인용 수, 올해 인용 수, 최근 30일 증가량, h-index, i10-index
- 방금 어떤 논문이 인용되었는지 확인하고, 클릭 한 번으로 누가 인용했는지 볼 수 있습니다
- 다음 h-index가 가까워지면 어떤 논문에 인용이 몇 번씩 더 필요한지 정확히 보여 줍니다
- 특정 논문 지켜보기: Papers window에서 별표를 달면 패널에 계속 표시되고, 새 인용 알림에서도 가장 먼저 보입니다
- 열 제목과 마우스를 올리면 나오는 설명으로 모든 숫자의 의미를 알 수 있습니다

**연구실과 공동 연구자를 위한 그룹**
- 연구실, 공동 저자, 동기 등으로 프로필을 묶고 합산 인용 수와 최근 30일 증가량을 확인합니다
- Scholar 링크 목록을 한 번에 붙여 넣을 수 있습니다
- 그룹의 링크를 복사해 연구실 동료에게 공유하면, 동료가 자기 CiteBar에 붙여 넣기만 하면 됩니다

**열어 볼 가치가 있는 알림**
- 알림에 인용이 늘어난 논문 제목이 표시됩니다
- 인용 100회, 1,000회 같은 이정표나 h-index 상승은 따로 알려 줍니다
- "변화 없음" 같은 쓸데없는 알림은 보내지 않습니다

**자랑하고 싶은 인용 기록**
- 네 가지 카드 스타일: Record, Night, Gazette(내 숫자로 헤드라인을 뽑은 신문 1면), Certificate
- 연도별 인용 수, h-index, 가장 많이 인용된 논문 또는 특정 논문 하나, 7일에서 365일까지의 증가량, 한마디 메모 등 표시할 내용을 고를 수 있습니다
- 패널이나 Settings의 각 프로필 ⋯ 메뉴에서 클릭 한 번으로 공유(AirDrop, 메시지, 메일), 복사, 저장할 수 있습니다

<img src="../website/assets/card-record.png" alt="Record 카드" width="180"> <img src="../website/assets/card-night.png" alt="Night 카드" width="180"> <img src="../website/assets/card-gazette.png" alt="Gazette 카드" width="180"> <img src="../website/assets/card-certificate.png" alt="Certificate 카드" width="180">

**내 기록을 위한 타임머신**
- 타임라인을 원하는 날짜로 드래그해 그날의 카드를 만들 수 있습니다
- 인용 이정표와 h-index 상승 시점이 표시되어 있어, 놓친 순간도 나중에 공유할 수 있습니다
- 설치 첫날부터 바로 쓸 수 있습니다: CiteBar를 설치하기 전의 이정표는 Google Scholar의 연도별 인용 수로 날짜를 추정해 ~로 표시하고, 설치한 날부터는 하루하루 정확하게 기록합니다

**예의 바르고 믿음직하게**
- 프로필당 요청은 한 번, 요청 간격은 2초
- 네트워크 오류는 자동으로 재시도하고, Google Scholar의 요청 제한에 걸리면 간격을 점차 늘렸다가(15분에서 최대 4시간) 알아서 재개합니다
- Refresh Now로 언제든 바로 새로고침할 수 있습니다
- Sparkle을 통한 자동 업데이트

**기본부터 개인정보 우선**
- 모든 데이터는 내 Mac에만 저장됩니다
- 사용 데이터 수집(텔레메트리) 없음
- CiteBar 서버도, 계정도 없습니다

**가져갈 수 있는 내 데이터**
- Settings › Data에서 데이터 저장 위치(`~/Library/Application Support/CiteBar/`)와 인용 기록, 논문 목록, 논문 기록이 각각 차지하는 용량을 확인할 수 있습니다
- 인용 기록은 영구 보관(기본값)하거나 5년, 2년, 1년만 보관하도록 설정할 수 있습니다
- 논문 기록을 켜면 논문별 인용 수가 바뀔 때마다 저장되어, 타임머신에서 지난 날짜를 볼 때 논문 정보도 함께 표시됩니다
- 프로필, 그룹, 설정, 전체 기록까지 모든 것을 파일 하나로 내보내고 새 Mac에서 가져올 수 있습니다. 가져오기는 추가만 할 뿐 아무것도 삭제하지 않습니다
- 새로고침할 때마다 iCloud Drive나 Google Drive, Dropbox 같은 원하는 폴더에 자동으로 백업하도록 설정할 수도 있습니다

**macOS다운 사용감**
- 메뉴 막대에 가볍게 자리 잡고, 라이트 모드와 다크 모드를 지원합니다
- Profiles, General, Data, About 탭으로 구성된 네이티브 Settings
- 로그인 시 자동 실행 지원
- Apple Silicon과 Intel 모두 지원

**켜 두어도 부담 없는 가벼움**
- 대기 중 CPU 사용량은 거의 0
- 사용자가 정한 간격에 맞춘 최소한의 네트워크 사용
- 자세한 구현 내용은 [기술 노트](../TECHNICAL.md)(영어)를 참고하세요

## 개인정보 보호

CiteBar는 공개된 Google Scholar 프로필 페이지만 읽습니다. 설정과 인용 기록은 `~/Library/Application Support/CiteBar/` 아래, 내 Mac에만 저장됩니다.

앱은 넉넉한 새로고침 간격, 요청 사이의 지연, 오류 발생 시 백오프를 적용해 인용 수를 책임감 있게 확인합니다.

## 도움말 및 프로젝트 문서

- 설치 또는 macOS 보안 경고 관련: [설치 가이드](../DISTRIBUTION.md)
- 소스에서 빌드하기: [설정 가이드](../SETUP.md)
- 버그 신고 및 기능 제안: [GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- 변경 사항: [변경 기록](../CHANGELOG.md)

위 문서는 모두 영어로 작성되어 있습니다. 이슈는 한국어로 작성하셔도 괜찮습니다.

아이디어가 있거나, 아직 다듬어지지 않은 기능 제안이 있거나, CiteBar가 아직 잘 지원하지 못하는 작업 방식이 있나요? 편하게 이슈를 열어 주세요. 완성된 제안서나 pull request를 준비할 필요는 없습니다. 실제 연구 현장에서 나온 피드백만으로도 큰 도움이 됩니다.

## 개발자 및 기여자

소스에서 직접 빌드하거나, 코드에 기여하거나, CiteBar가 내부적으로 어떻게 동작하는지 궁금하신가요?

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

참고할 만한 프로젝트 문서(영어):

- [기여 가이드](../CONTRIBUTING.md)
- [기술 노트](../TECHNICAL.md)
- [릴리스 가이드](../RELEASING.md)
- [버전 관리](../VERSION_MANAGEMENT.md)

## 라이선스

CiteBar는 [MIT License](../LICENSE)에 따라 배포됩니다.

## 커뮤니티

CiteBar를 더 좋게 만들어 주신 모든 분께 감사드립니다.

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**학계를 위해 정성껏 만들었습니다**

[최신 버전 다운로드](https://github.com/hichipli/CiteBar/releases/latest) | [이슈 신고](https://github.com/hichipli/CiteBar/issues) | [기여하기](../CONTRIBUTING.md)

</div>
