import 'package:flutter/material.dart';

import '../models/errand_item.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/app_theme.dart';
import '../widgets/soft.dart';

/// The shopping list. Bought things stay on the list, struck through and
/// credited, so a request never quietly disappears.
class ErrandListScreen extends StatelessWidget {
  final String profileId;

  const ErrandListScreen({super.key, required this.profileId});

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Titip beli'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'misal: susu UHT'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Titipkan'),
          ),
        ],
      ),
    );

    if (saved != true || controller.text.trim().isEmpty) return;

    await FirestoreService.instance.addErrandItem(ErrandItem(
      id: '',
      name: controller.text.trim(),
      requestedByProfileId: profileId,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ProfileSession.isAdmin(profileId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Titip'),
      ),
      body: StreamBuilder<List<Profile>>(
        stream: FirestoreService.instance.watchProfiles(),
        builder: (context, profileSnap) {
          final names = {
            for (final p in profileSnap.data ?? const <Profile>[]) p.id: p.name,
          };
          return StreamBuilder<List<ErrandItem>>(
            stream: FirestoreService.instance.watchErrandItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <ErrandItem>[];
              if (items.isEmpty) {
                return const SoftEmpty(
                  icon: Icons.shopping_basket_rounded,
                  message:
                      'Belum ada titipan.\nTulis apa yang perlu dibeli, siapa pun yang keluar bisa mencentangnya.',
                );
              }
              final pending = items.where((e) => !e.done).toList();
              final bought = items.where((e) => e.done).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  SectionHeading(
                    icon: Icons.shopping_basket_rounded,
                    title: pending.isEmpty
                        ? 'Semua sudah dibeli'
                        : '${pending.length} barang belum dibeli',
                  ),
                  for (final item in pending)
                    _ErrandCard(
                      item: item,
                      names: names,
                      profileId: profileId,
                      canRemove:
                          isAdmin || item.requestedByProfileId == profileId,
                    ),
                  if (bought.isNotEmpty) ...[
                    const SectionHeading(
                      icon: Icons.check_circle_rounded,
                      title: 'Sudah dibeli',
                    ),
                    for (final item in bought)
                      _ErrandCard(
                        item: item,
                        names: names,
                        profileId: profileId,
                        canRemove:
                            isAdmin || item.requestedByProfileId == profileId,
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrandCard extends StatelessWidget {
  final ErrandItem item;
  final Map<String, String> names;
  final String profileId;
  final bool canRemove;

  const _ErrandCard({
    required this.item,
    required this.names,
    required this.profileId,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final requester =
        names[item.requestedByProfileId] ?? item.requestedByProfileId;
    final buyer = item.doneByProfileId == null
        ? null
        : names[item.doneByProfileId] ?? item.doneByProfileId;

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => FirestoreService.instance
            .setErrandDone(item.id, !item.done, profileId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.done ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: item.done ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: item.done
                    ? Icon(Icons.check_rounded,
                        size: 18, color: scheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item.done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        MemberAvatar(
                          profileId: item.requestedByProfileId,
                          name: requester,
                          size: 22,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          buyer == null
                              ? 'dititip $requester'
                              : 'dititip $requester · dibeli $buyer',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Hapus',
                  onPressed: () =>
                      FirestoreService.instance.deleteErrandItem(item.id),
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
