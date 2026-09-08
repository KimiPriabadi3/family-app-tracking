import 'package:flutter/material.dart';

import '../models/errand_item.dart';
import '../models/profile.dart';
import '../services/firestore_service.dart';
import '../services/profile_session.dart';
import '../theme/register_theme.dart';
import '../widgets/register.dart';

/// The shopping list, kept as a register rather than a checklist: nothing is
/// removed when it is bought, it is struck and filed below with the name of
/// whoever bought it, so a request never quietly disappears.
class ErrandListScreen extends StatelessWidget {
  final String profileId;

  const ErrandListScreen({super.key, required this.profileId});

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TITIP BELI'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Barang',
            hintText: 'misal: susu UHT',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('TITIPKAN'),
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
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ProfileSession.isAdmin(profileId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_shopping_cart_outlined),
        label: const Text('TITIP'),
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
                return const RegisterEmpty(
                  'Belum ada titipan.\nTulis apa yang perlu dibeli, siapa pun yang '
                  'keluar bisa mencentangnya.',
                );
              }
              final pending = items.where((e) => !e.done).toList();
              final bought = items.where((e) => e.done).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                    child: FieldLabel(
                      pending.isEmpty
                          ? 'Semua titipan sudah dibeli'
                          : '${pending.length} barang belum dibeli',
                    ),
                  ),
                  if (pending.isNotEmpty)
                    RegisterSheet(
                      child: Column(
                        children: [
                          const RegisterHeaderStrip(
                            columns: ['Barang · dititip oleh'],
                            flex: [1],
                          ),
                          for (var i = 0; i < pending.length; i++)
                            _ErrandRow(
                              item: pending[i],
                              names: names,
                              profileId: profileId,
                              canRemove: isAdmin ||
                                  pending[i].requestedByProfileId == profileId,
                              last: i == pending.length - 1,
                            ),
                        ],
                      ),
                    ),
                  if (bought.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                      child: FieldLabel('Sudah dibeli',
                          color: scheme.onSurfaceVariant),
                    ),
                    RegisterSheet(
                      child: Column(
                        children: [
                          for (var i = 0; i < bought.length; i++)
                            _ErrandRow(
                              item: bought[i],
                              names: names,
                              profileId: profileId,
                              canRemove: isAdmin ||
                                  bought[i].requestedByProfileId == profileId,
                              last: i == bought.length - 1,
                            ),
                        ],
                      ),
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

class _ErrandRow extends StatelessWidget {
  final ErrandItem item;
  final Map<String, String> names;
  final String profileId;
  final bool canRemove;
  final bool last;

  const _ErrandRow({
    required this.item,
    required this.names,
    required this.profileId,
    required this.canRemove,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final requesterInk = RegisterInk.forMember(context, item.requestedByProfileId);
    final requester =
        names[item.requestedByProfileId] ?? item.requestedByProfileId;
    final buyer = item.doneByProfileId == null
        ? null
        : names[item.doneByProfileId] ?? item.doneByProfileId;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => FirestoreService.instance
                .setErrandDone(item.id, !item.done, profileId),
            child: Container(
              width: 52,
              height: 60,
              alignment: Alignment.center,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: item.done ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                  color: item.done ? scheme.primary : null,
                ),
                child: item.done
                    ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: RegisterType.value.copyWith(
                      color: item.done
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      decoration:
                          item.done ? TextDecoration.lineThrough : null,
                      decorationThickness: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      FieldLabel(requester, color: requesterInk),
                      if (buyer != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'dibeli $buyer',
                          style: RegisterType.annotation
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (canRemove)
            InkWell(
              onTap: () =>
                  FirestoreService.instance.deleteErrandItem(item.id),
              child: Container(
                width: 72,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: scheme.outline)),
                ),
                child: FieldLabel('Hapus', color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
