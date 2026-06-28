import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../models/callsign_profile.dart';
import 'radio_theme.dart';

class CallsignBiographyPage extends StatelessWidget {
  final CallsignProfile profile;

  const CallsignBiographyPage({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: Text(profile.callsign),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(profile: profile),
          const SizedBox(height: 16),
          _BiographyRenderer(html: profile.biographyHtml ?? ''),
          const SizedBox(height: 20),
          _QrzDetailPrompt(callsign: profile.callsign),
        ],
      ),
    );
  }
}

class _QrzDetailPrompt extends StatelessWidget {
  final String callsign;

  const _QrzDetailPrompt({required this.callsign});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = 'https://www.qrz.com/db/$callsign';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '出于安全考虑，当前信息展示可能不全，请点击按钮查看详情。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('查看 QRZ 详情'),
            ),
            const SizedBox(height: 4),
            Text(
              url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CallsignProfile profile;

  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.callsign,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (profile.displayName?.isNotEmpty == true)
              Text(profile.displayName!),
            if (profile.dxcc?.name?.isNotEmpty == true)
              Text(
                'DXCC ${profile.dxcc?.dxcc ?? ''} · ${profile.dxcc!.name}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _BiographyRenderer extends StatelessWidget {
  final String html;

  const _BiographyRenderer({required this.html});

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('暂无 Biography Data'),
        ),
      );
    }

    final document = html_parser.parse(html);
    final nodes = document.body?.nodes ?? document.nodes;
    final widgets = _nodesToWidgets(context, nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.isEmpty ? const [Text('暂无可渲染内容')] : widgets,
    );
  }

  List<Widget> _nodesToWidgets(BuildContext context, List<dom.Node> nodes) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      final widget = _nodeToWidget(context, node);
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  Widget? _nodeToWidget(BuildContext context, dom.Node node) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text),
      );
    }
    if (node is! dom.Element) return null;

    final tag = node.localName?.toLowerCase();
    switch (tag) {
      case 'script':
      case 'style':
      case 'iframe':
        return null;
      case 'br':
        return const SizedBox(height: 8);
      case 'img':
        return _image(node);
      case 'a':
        return _link(context, node);
      case 'table':
        return _table(context, node);
      case 'tbody':
      case 'thead':
      case 'tfoot':
      case 'tr':
      case 'td':
      case 'th':
        return _container(context, node);
      case 'h1':
      case 'h2':
      case 'h3':
        return _textBlock(
          context,
          node.text,
          Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        );
      case 'p':
      case 'div':
      case 'span':
      case 'center':
      case 'font':
      case 'b':
      case 'strong':
      case 'i':
      case 'em':
      case 'u':
        return _container(context, node);
      case 'ul':
      case 'ol':
        return _list(context, node);
      default:
        return _container(context, node);
    }
  }

  Widget _container(BuildContext context, dom.Element element) {
    final background = _backgroundImage(element);
    final children = _nodesToWidgets(context, element.nodes);
    if (children.isEmpty) {
      final text = element.text.trim();
      if (text.isEmpty && background == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (background != null) _imageUrl(background),
          if (text.isNotEmpty) _textBlock(context, text),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (background != null) _imageUrl(background),
          ...children,
        ],
      ),
    );
  }

  Widget _table(BuildContext context, dom.Element table) {
    final rows = table
        .getElementsByTagName('tr')
        .map((row) => row.children.where((cell) {
              final tag = cell.localName?.toLowerCase();
              return tag == 'td' || tag == 'th';
            }).toList())
        .where((cells) => cells.isNotEmpty)
        .toList();
    if (rows.isEmpty) return _container(context, table);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cells in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  for (final cell in cells)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _container(context, cell),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, dom.Element element) {
    final items = element.children
        .where((child) => child.localName?.toLowerCase() == 'li')
        .map((child) => child.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }

  Widget _textBlock(
    BuildContext context,
    String text, [
    TextStyle? style,
  ]) {
    final normalized = text.trim();
    if (normalized.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(normalized, style: style),
    );
  }

  Widget _link(BuildContext context, dom.Element element) {
    final href = element.attributes['href']?.trim();
    final label =
        element.text.trim().isEmpty ? href ?? '链接' : element.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: href == null || href.isEmpty
            ? null
            : () => launchUrl(Uri.parse(href),
                mode: LaunchMode.externalApplication),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _image(dom.Element element) {
    final src = element.attributes['src']?.trim();
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    return _imageUrl(src);
  }

  Widget _imageUrl(String src) {
    final resolved = _resolveUrl(src);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          resolved,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  String? _backgroundImage(dom.Element element) {
    final background = element.attributes['background']?.trim();
    if (background != null && background.isNotEmpty) return background;

    final style = element.attributes['style'];
    if (style == null) return null;
    final start = style.indexOf('url(');
    if (start < 0) return null;
    final end = style.indexOf(')', start + 4);
    if (end < 0) return null;
    final value = style
        .substring(start + 4, end)
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '');
    return value.isEmpty ? null : value;
  }

  String _resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return 'https://www.qrz.com$trimmed';
    return 'https://www.qrz.com/$trimmed';
  }
}
