import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const ink = Color(0xFF142D34);
const teal = Color(0xFF006B60);

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.urgent = false});
  final String text;
  final bool urgent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: urgent ? const Color(0xFFFFE9DB) : const Color(0xFFE3F0EC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: urgent ? const Color(0xFF763010) : ink,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Show a recoverable error; never imply an external action succeeded.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('연결할 앱을 열 수 없습니다. 주소나 번호를 직접 확인해 주세요.')),
    );
  }
}
