import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/localization/app_strings.dart';
import '../providers/explore_provider.dart';

class RequestInboxScreen extends ConsumerWidget {
  const RequestInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final requestsAsync = ref.watch(incomingPendingRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(s.t('request_inbox'), style: IsleText.subtitle()),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: IsleText.caption(color: IsleColors.muted))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Text(s.t('requests_empty'), style: IsleText.body(color: IsleColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final req = requests[i];
              final label = req.requesterDisplay.isNotEmpty ? req.requesterDisplay : req.requesterUsername;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: IsleText.subtitle()),
                    const SizedBox(height: 6),
                    Text(req.purpose, style: IsleText.body()),
                    if (req.introMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(req.introMessage, style: IsleText.caption(color: IsleColors.muted)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(exploreRepoProvider).updatePendingRequestStatus(
                                  requestId: req.id,
                                  status: 'rejected',
                                );
                            ref.invalidate(incomingPendingRequestsProvider);
                          },
                          child: Text(s.t('reject')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            await ref.read(exploreRepoProvider).updatePendingRequestStatus(
                                  requestId: req.id,
                                  status: 'accepted',
                                );
                            ref.invalidate(incomingPendingRequestsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s.t('accept_done'))),
                              );
                              context.push(
                                '/explore/chat/${req.requesterId}?name=${Uri.encodeComponent(label)}',
                              );
                            }
                          },
                          child: Text(s.t('accept')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
