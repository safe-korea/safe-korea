import 'package:flutter/material.dart';

import 'common.dart';

class ShelterClusterPin extends StatelessWidget {
  const ShelterClusterPin({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: teal,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x35000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: FittedBox(
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 19,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
