import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/radio_link_card.dart';

class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('라디오 연결')),
    body: const PageBody(
      children: [
        Text('평소에 연결 방법을 확인해 두세요.'),
        SizedBox(height: 16),
        RadioLinkCard(),
      ],
    ),
  );
}
