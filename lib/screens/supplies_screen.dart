import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Preparation only. No invented products, paid rankings or checkout.
class SuppliesScreen extends StatelessWidget {
  const SuppliesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('비상용품 준비')),
    body: PageBody(
      children: [
        const IconTextBlock(
          icon: Icons.backpack_outlined,
          title: '집에 있는 물품부터',
          body: Text('체크리스트를 보고 부족한 물품만 준비하세요.'),
        ),
        const SizedBox(height: 24),
        const Text(
          '구매 전 확인',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final item in const [
          (Icons.water_drop_outlined, '물·간편식', '유효기간 · 보관 방법 · 휴대 무게'),
          (Icons.flashlight_on_outlined, '손전등·건전지', '작동 여부 · 사용하는 건전지 규격'),
          (Icons.radio_outlined, '휴대용 라디오', 'FM 수신 지원 · 전원 방식'),
          (Icons.battery_charging_full, '보조배터리', '내 휴대폰과 케이블 호환 여부'),
        ]) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconTextBlock(
                icon: item.$1,
                title: item.$2,
                body: Text(item.$3),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: IconTextBlock(
              icon: Icons.storefront_outlined,
              title: '제휴 판매처',
              body: Text('현재 연결된 판매처가 없습니다.\n구매·결제 기능은 아직 제공하지 않습니다.'),
            ),
          ),
        ),
      ],
    ),
  );
}
