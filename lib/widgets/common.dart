import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const ink = AppPalette.ink;
const teal = AppPalette.green;

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.urgent = false,
    this.warning = false,
  });
  final String text;
  final bool urgent;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: urgent || warning
          ? AppPalette.cautionBackground
          : AppPalette.informationBackground,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            urgent || warning
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: urgent || warning ? AppPalette.caution : teal,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: urgent || warning ? AppPalette.caution : ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

/// Shared geometry for icon-led content: 44px icon + 12px gutter.
/// The caller supplies the same 16px card inset on each screen.
class IconTextBlock extends StatelessWidget {
  const IconTextBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = AppPalette.ink,
    this.iconColor = AppPalette.green,
    this.iconBackground = AppPalette.background,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget body;
  final Color color, iconColor, iconBackground;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            body,
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        ExcludeSemantics(child: trailing!),
      ],
    ],
  );
}

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

/// Structured metadata instead of newline-joined paragraphs.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppPalette.muted,
          ),
        );
        final valueWidget = Text(
          value,
          style: const TextStyle(fontSize: 16, height: 1.4),
        );
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(16) > 24) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: labelWidget),
            const SizedBox(width: 12),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}
