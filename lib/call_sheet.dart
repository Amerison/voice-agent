import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

void showCallSheet(BuildContext context, CallRecord call) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      maxChildSize: .96,
      minChildSize: .5,
      builder: (context, scrollController) => Column(
        children: [
          HubSheetHeader(
            title: 'Call',
            showCancel: false,
            onDone: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                _CallSummary(call: call),
                const SizedBox(height: 16),
                HubCard(
                  icon: call.resolved
                      ? CupertinoIcons.checkmark_circle
                      : CupertinoIcons.exclamationmark_circle,
                  title: 'Resolution',
                  trailing: HubPill(
                    label: call.resolved ? 'Resolved' : 'Unresolved',
                    tone: call.resolved ? PillTone.success : PillTone.danger,
                  ),
                  child: Text(
                    call.resolutionReason,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (call.actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  HubCard(
                    icon: CupertinoIcons.bolt,
                    title: 'Actions',
                    detail: 'completed',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in call.actions)
                          HubPill(label: action, tone: PillTone.accent),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                HubCard(
                  icon: CupertinoIcons.chat_bubble_2,
                  title: 'Transcript',
                  detail: '${call.transcript.length} messages',
                  child: Column(
                    children: [
                      for (final message in call.transcript)
                        _TranscriptBubble(message: message),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CallSummary extends StatelessWidget {
  const _CallSummary({required this.call});

  final CallRecord call;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const IconBadge(
          icon: CupertinoIcons.phone,
          size: 52,
          color: HubColors.surface,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                call.callerNumber,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  DateChip(date: call.startedAt),
                  const SizedBox(width: 8),
                  Text(
                    formatDuration(call.durationSeconds),
                    style: const TextStyle(color: HubColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.message});

  final TranscriptMessage message;

  @override
  Widget build(BuildContext context) {
    final isAgent = message.role == 'assistant';
    return Align(
      alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAgent
              ? HubColors.surfaceRaised
              : HubColors.orange.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAgent
                ? HubColors.border
                : HubColors.orange.withValues(alpha: .4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAgent ? 'Agent' : 'Caller',
              style: const TextStyle(
                fontFamily: HubFonts.mono,
                fontSize: 11,
                color: HubColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(message.text),
          ],
        ),
      ),
    );
  }
}
