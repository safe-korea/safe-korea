import 'package:flutter/material.dart';

import 'common.dart';

const publicPrivacyUrl =
    'https://safe-korea-shelter-api.trovapp.workers.dev/privacy';
const publicSupportUrl =
    'https://safe-korea-shelter-api.trovapp.workers.dev/support';
const publicSupportEmail = 'taetaeg@gmail.com';

/// User-initiated links only. No automatic mail, telemetry or device data.
class PublicSupportLinks extends StatelessWidget {
  const PublicSupportLinks({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '개인정보 및 문의',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => openExternal(context, Uri.parse(publicPrivacyUrl)),
        icon: const Icon(Icons.privacy_tip_outlined),
        label: const Text('개인정보처리방침'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => openExternal(context, Uri.parse(publicSupportUrl)),
        icon: const Icon(Icons.help_outline),
        label: const Text('문의·데이터 삭제 안내'),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => openExternal(
          context,
          Uri(
            scheme: 'mailto',
            path: publicSupportEmail,
            query: 'subject=${Uri.encodeComponent('safeKor 문의')}',
          ),
        ),
        icon: const Icon(Icons.mail_outline),
        label: const Text('문의 이메일 앱 열기'),
      ),
      const SelectableText(publicSupportEmail, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text(
        '운영자 safeKor · 이메일을 자동으로 보내지 않습니다. 인터넷 연결이 필요하며 긴급 구조 접수 창구는 아닙니다.',
        style: TextStyle(fontSize: 14),
      ),
    ],
  );
}
