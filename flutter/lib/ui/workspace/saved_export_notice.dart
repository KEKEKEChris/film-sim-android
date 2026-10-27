// What an export just saved: a dark card at the window's foot with Open (the system's viewer for
// it), Show in Finder and Dismiss. Export All saved many files, so only Show in Finder is offered
// for it. In a browser the export is a download, so only Dismiss is.
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter/widgets.dart';

import '../../app/host_window.dart';
import '../../model/editor.dart';
import '../../model/export.dart' show SavedExport;
import '../../model/l10n.dart';
import '../kit/kit.dart';
import '../theme/theme.dart';

class SavedExportNotice extends StatelessWidget {
  const SavedExportNotice({super.key, required this.editor});
  final EditorModel editor;
  static const _share = MethodChannel('fotufilm/exports');

  Future<void> _shareFile(SavedExport saved) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _share.invokeMethod('share', {'path': saved.path, 'name': saved.filename});
    } on PlatformException {
      // The export itself is complete; a device without a share target can still open it.
    } on MissingPluginException {
      // Desktop and older source builds do not provide the Android share channel.
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = editor.exporter.saved;
    if (saved == null) return const SizedBox.shrink();
    return Positioned(
        bottom: 24,
        left: 0,
        right: 0,
        child: Appear(key: ValueKey(saved), rise: 8, child: _saved(context, saved)));
  }

  static Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          border: Border.all(color: const Color(0xFF666666)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  Widget _saved(BuildContext context, SavedExport saved) {
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final savedText =
        '${t('Saved')} ${saved.filename}${saved.directory == null && saved.location == null ? '' : '\n${saved.location ?? saved.directory}'}';
    final buttons = [
      if (HostWindow.showsFiles) ...[
        if (saved.count == null)
          _NoticeButton('Open', () => HostWindow.openFile(saved.path)),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && saved.count == null)
          _NoticeButton('Share', () => _shareFile(saved)),
        _NoticeButton(HostWindow.revealLabel, () => HostWindow.reveal([saved.path])),
      ],
      _NoticeButton('Dismiss', editor.exporter.dismissSaved),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _card(
          narrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      savedText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: editorText(context, color: const Color(0xFFFFFFFF)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: buttons,
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        savedText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: editorText(context, color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      buttons[i],
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Spectrum's ActionButton at size S, on the notice's dark card in either appearance.
class _NoticeButton extends StatefulWidget {
  const _NoticeButton(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  State<_NoticeButton> createState() => _NoticeButtonState();
}

class _NoticeButtonState extends State<_NoticeButton> with PointerTint {
  @override
  Widget build(BuildContext context) => tinted(
        onTap: widget.onPressed,
        child: Container(
          height: Metrics.control,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? const Color(0xFF444444) : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(Metrics.radius),
          ),
          child: Text(t(widget.label),
              style: editorText(context, weight: FontWeight.w500, color: const Color(0xFFFFFFFF))),
        ),
      );
}
