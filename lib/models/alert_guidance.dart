/// Editorial summaries of MOIS guidance; never a detected or received alert.
enum AlertKind {
  air('공습경보', '지금 즉시 대피하세요'),
  watch('경계경보', '대피를 준비하세요'),
  cbrn('화생방경보', '공격 종류를 확인하세요'),
  chemical('화학 공격', '오염된 공기를 피하세요'),
  biological('생물학 공격', '호흡기를 보호하세요'),
  nuclear('핵 경보', '즉시 몸을 보호하세요'),
  release('경보해제', '추가 안내를 확인하세요');

  const AlertKind(this.label, this.headline);
  final String label, headline;
  bool get hasSiren => this == air || this == nuclear;
  String get soundAsset => hasSiren ? 'drill_siren' : 'drill_${name}_voice';
  String get signal =>
      hasSiren ? '파상음 1분 + 음성·문자 안내' : '음성·문자 안내 · 별도 민방공 사이렌 없음';
  bool get offersShelters => this == air || this == watch || this == nuclear;
  static AlertKind? fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

enum UserSetting {
  unknown('모르겠어요'),
  indoors('실내'),
  outdoors('실외'),
  vehicle('차량');

  const UserSetting(this.label);
  final String label;
}

const guidanceSource =
    'https://www.mois.go.kr/frt/bbs/type002/commonSelectBoardArticle.do?bbsId=BBSMSTR_000000000530&nttId=119828';
const signalSource =
    'https://www.law.go.kr/LSW/flDownload.do?bylClsCd=200201&flSeq=160780623';

List<String> immediateActions(AlertKind kind, UserSetting setting) =>
    switch (kind) {
      AlertKind.air => [
        switch (setting) {
          UserSetting.indoors => '계단으로 지하나 아래층으로 이동하세요.',
          UserSetting.outdoors => '가까운 지하시설이나 콘크리트 건물 안으로 대피하세요.',
          UserSetting.vehicle => '운전 중이면 공터나 도로 오른쪽에 정차한 뒤 대피하세요.',
          UserSetting.unknown => '민방위 대피소나 가까운 지하시설로 즉시 대피하세요.',
        },
        '유리창을 피하세요. 침수 우려가 있는 지하는 피하세요.',
        '대피 후 정부 방송·재난문자를 확인하세요.',
      ],
      AlertKind.watch => [
        '정부 방송·재난문자로 발령 이유를 확인하세요.',
        setting == UserSetting.indoors
            ? '준비된 생존배낭과 보호장비를 챙겨 대피를 준비하세요.'
            : '주변 대피 장소를 확인하고 대피를 준비하세요.',
        '어린이·노약자의 이동을 돕고 정부 지시를 따르세요.',
      ],
      AlertKind.cbrn => [
        '음성·문자 안내에서 화학·생물학 등 공격 종류를 확인하세요.',
        '호흡기와 피부를 보호하고 오염지역 접근을 피하세요.',
        '공격 종류에 따라 대피 장소가 다릅니다. 아래 안내를 선택하세요.',
      ],
      AlertKind.chemical => [
        setting == UserSetting.indoors
            ? '문과 창문을 닫고 외부 공기 유입을 차단하세요.'
            : '외부 공기를 차단할 수 있는 높은 층 실내로 대피하세요.',
        '방독면 등으로 호흡기와 피부를 보호하세요.',
        '지하 대피를 일괄 적용하지 마세요. 정부의 오염지역·이동 안내를 따르세요.',
      ],
      AlertKind.biological => [
        '코와 입을 보호하고 오염물질과의 접촉을 피하세요.',
        setting == UserSetting.indoors
            ? '실내에서 정부의 지정 장소·이동 안내를 확인하세요.'
            : '정부가 안내한 지정 장소로 대피하거나 귀가하세요.',
        '보건당국의 검사·치료 안내를 따르세요.',
      ],
      AlertKind.nuclear => [
        '섬광·폭발을 이미 봤다면 이동보다 즉시 엎드려 몸을 보호하세요.',
        '폭발 전 경보 단계라면 가까운 지하시설로 즉시 대피하세요.',
        '폭발 후에는 콘크리트 건물 안·깊은 지하에서 낙진을 피하고 방송을 들으세요.',
      ],
      AlertKind.release => [
        '정부의 경보해제와 지역별 이동 지시를 확인하세요.',
        '추가 공격에 대비해 방송을 계속 들으세요.',
        '현장 안내에 따라 이동하고 도움이 필요한 사람을 살피세요.',
      ],
    };
