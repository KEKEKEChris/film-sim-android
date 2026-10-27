// The workspace's dialogs: the card they share. Export and the keyboard shortcuts have their own
// files (export_dialog.dart, shortcuts_dialog.dart).
import 'package:flutter/widgets.dart';

import '../../model/l10n.dart';
import '../theme/theme.dart';

/// A dialog's card: its title, its body and its buttons on the right.
class DialogCard extends StatelessWidget {
  const DialogCard({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.width = 440,
  });

  final String title;
  final List<Widget> children, actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final room = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      width: width.clamp(0, room.width - 32).toDouble(),
      constraints: BoxConstraints(
        maxHeight: (room.height - 32 - keyboard).clamp(180.0, room.height - 32),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: room.width < 500 ? 16 : 24,
        vertical: room.height < 700 || keyboard > 0 ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: palette.dark ? const Color(0xFF222222) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 10))],
      ),
      child: DefaultTextStyle(
        style: editorText(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t(title),
                style: editorText(context, size: TextSizes.dialog, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboard > 0 ? 12 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
