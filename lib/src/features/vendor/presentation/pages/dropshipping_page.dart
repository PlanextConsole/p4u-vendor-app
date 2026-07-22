import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class DropshippingPage extends ConsumerStatefulWidget {
  const DropshippingPage({super.key});
  @override
  ConsumerState<DropshippingPage> createState() => _DropshippingPageState();
}

class _DropshippingPageState extends ConsumerState<DropshippingPage> {
  late Future<List<Object>> _load;
  bool _enabled = false,
      _autoForward = false,
      _notify = true,
      _initialized = false,
      _busy = false;
  String? _supplierId;
  final _margin = TextEditingController(text: '20');
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future.wait<Object>([
      ref.read(vendorRepositoryProvider).dropshippingSettings(),
      ref.read(vendorRepositoryProvider).dropshippingSuppliers(),
      ref.read(vendorRepositoryProvider).dropshippingOrders(),
    ]);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(vendorRepositoryProvider).saveDropshippingSettings({
        'enabled': _enabled,
        'defaultSupplierId': _supplierId,
        'autoForwardOrders': _autoForward,
        'defaultMarginPercent': double.tryParse(_margin.text) ?? 20,
        'notifyOnStatusChange': _notify,
      });
      _toast('Dropshipping settings saved');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _orderAction(String id, bool forward) async {
    setState(() => _busy = true);
    try {
      if (forward) {
        await ref.read(vendorRepositoryProvider).forwardDropshippingOrder(id);
      } else {
        await ref.read(vendorRepositoryProvider).cancelDropshippingOrder(id);
      }
      setState(() {
        _initialized = false;
        _reload();
      });
      _toast(forward ? 'Order forwarded' : 'Order cancelled');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  void dispose() {
    _margin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VendorScaffold(
        title: 'Dropshipping',
        child: FutureBuilder<List<Object>>(
            future: _load,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                return const Center(child: CircularProgressIndicator());
              }
              final bundle = snapshot.data![0] as Map<String, dynamic>;
              final suppliers = snapshot.data![1] as List<Map<String, dynamic>>;
              final orders = snapshot.data![2] as List<Map<String, dynamic>>;
              final settings = bundle['settings'] is Map
                  ? Map<String, dynamic>.from(bundle['settings'] as Map)
                  : <String, dynamic>{};
              if (!_initialized) {
                _enabled = settings['enabled'] == true;
                _autoForward = settings['autoForwardOrders'] == true;
                _notify = settings['notifyOnStatusChange'] != false;
                _supplierId = settings['defaultSupplierId']?.toString();
                _margin.text = '${settings['defaultMarginPercent'] ?? 20}';
                _initialized = true;
              }
              final platformEnabled = bundle['platformEnabled'] != false;
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (!platformEnabled)
                  const AppCard(
                      child: Text(
                          'Dropshipping is disabled by the platform administrator.')),
                AppCard(
                    child: Column(children: [
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable dropshipping'),
                      value: _enabled,
                      onChanged: platformEnabled
                          ? (v) => setState(() => _enabled = v)
                          : null),
                  DropdownButtonFormField<String>(
                      initialValue: suppliers
                              .any((s) => s['id']?.toString() == _supplierId)
                          ? _supplierId
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'Default supplier'),
                      items: suppliers
                          .map((s) => DropdownMenuItem(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? 'Supplier')))
                          .toList(),
                      onChanged: (v) => setState(() => _supplierId = v)),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _margin,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Margin percent')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-forward new orders'),
                      value: _autoForward,
                      onChanged: (v) => setState(() => _autoForward = v)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Status notifications'),
                      value: _notify,
                      onChanged: (v) => setState(() => _notify = v)),
                  FilledButton(
                      onPressed: _busy ? null : _save,
                      child: const Text('Save settings')),
                ])),
                const SizedBox(height: 16),
                const Text('Supplier orders',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const AppCard(child: Text('No dropshipping orders yet.')),
                ...orders.map((order) {
                  final status = order['status']?.toString() ?? 'pending';
                  final id = order['id']?.toString() ?? '';
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text('Order ${order['orderId'] ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              StatusBadge(status)
                            ]),
                            Text(
                                'Cost Rs. ${order['costTotal'] ?? 0} · Margin Rs. ${order['marginAmount'] ?? 0}'),
                            if (status == 'pending')
                              Wrap(spacing: 8, children: [
                                FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _orderAction(id, true),
                                    child: const Text('Forward')),
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _orderAction(id, false),
                                    child: const Text('Cancel')),
                              ]),
                          ])));
                }),
                if (_busy) const LinearProgressIndicator(),
              ]);
            }));
  }
}
