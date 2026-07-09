import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class BankAccountsPage extends ConsumerWidget {
  const BankAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(vendorBanksProvider);
    return VendorScaffold(
      title: 'Bank Accounts',
      actions: [
        IconButton(
            onPressed: () => _showBankForm(context, ref),
            icon: const Icon(Icons.add_rounded))
      ],
      child: banks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Manage your bank accounts for settlement payouts.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No bank accounts added')
            else
              ...items.map((acc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(
                        children: [
                          const CircleAvatar(
                              backgroundColor: AppColors.accent,
                              child: Icon(Icons.credit_card_rounded,
                                  color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                      child: Text(
                                          acc['bank_name']?.toString() ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  if (acc['is_primary'] == true)
                                    const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: StatusBadge('primary')),
                                ]),
                                Text(acc['account_holder']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                                Text(
                                    'A/C: ****${(acc['account_number'] ?? '').toString().padLeft(4).substring((acc['account_number'] ?? '').toString().padLeft(4).length - 4)} - IFSC: ${acc['ifsc_code'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              final repo = ref.read(vendorRepositoryProvider);
                              if (v == 'primary') {
                                await repo.setPrimaryBank(
                                    ref.read(vendorIdProvider)!,
                                    acc['id'].toString());
                              }
                              if (v == 'delete') {
                                await repo.deleteBank(acc['id'].toString());
                              }
                              ref.invalidate(vendorBanksProvider);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'primary', child: Text('Set Primary')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBankForm(BuildContext context, WidgetRef ref) async {
  final vendorId = ref.read(vendorIdProvider);
  if (vendorId == null) return;
  final bank = TextEditingController();
  final holder = TextEditingController();
  final account = TextEditingController();
  final confirm = TextEditingController();
  final ifsc = TextEditingController();
  var type = 'savings';
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text('Add Bank Account',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Bank Name')),
            const SizedBox(height: 10),
            TextField(
                controller: holder,
                decoration:
                    const InputDecoration(labelText: 'Account Holder Name')),
            const SizedBox(height: 10),
            TextField(
                controller: account,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Account Number')),
            const SizedBox(height: 10),
            TextField(
                controller: confirm,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Confirm Account Number')),
            const SizedBox(height: 10),
            TextField(
                controller: ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'IFSC Code')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Account Type'),
              items: const [
                DropdownMenuItem(value: 'savings', child: Text('Savings')),
                DropdownMenuItem(value: 'current', child: Text('Current'))
              ],
              onChanged: (v) => type = v ?? type,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (account.text != confirm.text) return;
                final existing = await ref.read(vendorBanksProvider.future);
                await ref.read(vendorRepositoryProvider).addBankAccount(
                    vendorId,
                    {
                      'bank_name': bank.text.trim(),
                      'account_holder': holder.text.trim(),
                      'account_number': account.text.trim(),
                      'ifsc_code': ifsc.text.trim().toUpperCase(),
                      'account_type': type,
                    },
                    existing.isEmpty);
                ref.invalidate(vendorBanksProvider);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('Add Bank Account'),
            ),
          ],
        ),
      ),
    ),
  );
}
