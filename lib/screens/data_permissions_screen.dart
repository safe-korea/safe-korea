import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/public_support_links.dart';

/// In-app disclosure plus the operator's public policy and contact links.
class DataPermissionsScreen extends StatelessWidget {
  const DataPermissionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('데이터와 권한')),
    body: const PageBody(
      children: [
        IconTextBlock(
          icon: Icons.phone_android_outlined,
          title: '기기에 보관하는 정보',
          body: Text(
            '가족 만남 장소·약속, 저장한 대피소·사진·메모, 준비물 체크와 마지막 조회 시설을 이 기기에 저장합니다.',
          ),
        ),
        SizedBox(height: 24),
        ExpansionTile(
          title: Text('현재 위치는 어떻게 쓰나요?'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'GPS 버튼을 누를 때 한 번 확인하며 위치 기록을 저장하거나 백그라운드에서 추적하지 않습니다. 거리 계산은 기기에서 처리합니다. 지도에 현재 위치를 표시하면 해당 위치 주변의 지도 범위를 지도 제공자에게 요청할 수 있습니다.\n\n조회 지역 제안은 별도 동작입니다. 요청하면 좌표가 Apple·Google 등 기기의 주소 변환 서비스에 전달될 수 있습니다. 권한을 거부해도 지역 직접 선택과 행동요령을 사용할 수 있습니다.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('사진·알림 권한은 왜 필요한가요?'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '사진은 사용자가 선택한 대피소·출입구 사진을 기기에 복사할 때 사용합니다. 앱에서 복사본을 삭제해도 사진 보관함 원본은 유지됩니다.\n\n알림은 직접 요청한 훈련용 테스트 알림에 사용합니다. 실제 정부 경보를 수신하지 않습니다.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('외부로 전달되는 정보'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '시설 조회 시 선택한 지역 코드와 IP가 설정된 데이터 서버(Cloudflare) 또는 정부 사이트에 전달됩니다. 데이터 서버는 지역 코드로 정부 자료를 조회하며 GPS·가족 정보를 받지 않습니다. 카카오·OpenStreetMap 지도와 로드뷰는 조회 범위·좌표·IP 등을 제공자에게 전달할 수 있습니다.\n\n가족 공유는 미리보기 후 선택한 외부 앱에 전달됩니다. 상대방에게 자동 전송하지 않습니다. 라디오·출처 링크를 열면 외부 서비스가 인터넷 연결을 처리합니다.\n\n앱 자체 계정·광고·분석 서버는 운영하지 않습니다. 외부 서비스의 정보 처리는 해당 제공자의 정책이 적용됩니다.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('저장한 정보를 지우려면'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '가족 화면의 저장된 계획 삭제, 대피소 저장 해제, 사진·메모 수정을 이용하세요. 준비물 체크는 해제할 수 있습니다.\n\n이전 버전의 연락처 등 앱 내부 저장 정보를 모두 지우려면 앱을 삭제하거나 Android 설정에서 앱 저장공간을 지우세요. iOS의 앱 정리하기는 데이터 삭제와 다릅니다. 외부로 공유한 메시지와 사진 보관함 원본은 해당 앱에서 별도로 관리해야 합니다.',
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        PublicSupportLinks(),
        SizedBox(height: 20),
        Text('현재 앱 동작 안내 · 2026-11-01', style: TextStyle(fontSize: 14)),
      ],
    ),
  );
}
