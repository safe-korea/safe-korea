import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const ink = AppPalette.ink;
const teal = AppPalette.green;

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

/// Compact, consistent navigation rows for everyday preparedness screens.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppPalette.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppPalette.green, size: 24),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: AppPalette.muted),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppPalette.muted),
      onTap: onTap,
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppPalette.green,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppPalette.muted, fontSize: 16),
        ),
      ],
    ),
  );
}
