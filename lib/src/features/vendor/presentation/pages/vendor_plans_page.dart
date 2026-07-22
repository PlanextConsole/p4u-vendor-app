import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/vendor_scaffold.dart';
import '../../data/vendor_providers.dart';

class VendorPlansPage extends ConsumerStatefulWidget {
  const VendorPlansPage({super.key});
  @override
  ConsumerState<VendorPlansPage> createState() => _VendorPlansPageState();
}

class _VendorPlansPageState extends ConsumerState<VendorPlansPage> {
  late final Razorpay _razorpay;
  String? _planId;
  bool _busy = false;
  late Future<List<Object>> _load;
  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _paymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _paymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _externalWallet);
    _refresh();
  }

  void _refresh() {
    final vendorId = ref.read(vendorIdProvider) ?? '';
    _load = Future.wait<Object>([
      ref.read(vendorRepositoryProvider).planInfo(vendorId),
      ref.read(vendorRepositoryProvider).plans(vendorId),
    ]);
  }

  Future<void> _select(Map<String, dynamic> plan) async {
    final id = plan['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _busy = true;
      _planId = id;
    });
    try {
      final checkout =
          await ref.read(vendorRepositoryProvider).startPlanCheckout(id);
      if (checkout['free'] == true) {
        _done('Plan activated');
        return;
      }
      _razorpay.open({
        'key': checkout['keyId'],
        'order_id': checkout['orderId'],
        'amount': checkout['amount'],
        'currency': checkout['currency'] ?? 'INR',
        'name': 'Planext4U',
        'description': plan['name'] ?? plan['title'] ?? 'Vendor plan',
        'theme': {'color': '#0C831F'},
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _paymentSuccess(PaymentSuccessResponse response) async {
    final planId = _planId;
    if (planId == null ||
        response.orderId == null ||
        response.paymentId == null ||
        response.signature == null) {
      _fail('Payment response was incomplete');
      return;
    }
    try {
      await ref.read(vendorRepositoryProvider).verifyPlanPayment(
          planId: planId,
          orderId: response.orderId!,
          paymentId: response.paymentId!,
          signature: response.signature!);
      _done('Payment verified and plan activated');
    } catch (e) {
      _fail(e);
    }
  }

  void _paymentError(PaymentFailureResponse response) =>
      _fail(response.message ?? 'Payment failed');
  void _externalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('External wallet: ${response.walletName}')));
    }
  }

  void _done(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _refresh();
    });
    ref.invalidate(vendorProfileProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VendorScaffold(
        title: 'Plans & Payments',
        child: FutureBuilder<List<Object>>(
            future: _load,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                return const Center(child: CircularProgressIndicator());
              }
              final info = snapshot.data![0] as Map<String, dynamic>;
              final plans = snapshot.data![1] as List<Map<String, dynamic>>;
              final active = info['plan'] is Map
                  ? Map<String, dynamic>.from(info['plan'] as Map)
                  : <String, dynamic>{};
              final effective = info['effective'] is Map
                  ? Map<String, dynamic>.from(info['effective'] as Map)
                  : <String, dynamic>{};
              return ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.workspace_premium_rounded),
                        title: Text(
                            active['name']?.toString() ?? 'No active plan',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            'Effective commission: ${effective['commissionPercent'] ?? 0}%'))),
                const SizedBox(height: 12),
                ...plans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              plan['name']?.toString() ??
                                  plan['title']?.toString() ??
                                  'Plan',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('Rs. ${plan['price'] ?? 0}'),
                          Text('Commission ${plan['commissionPercent'] ?? 0}%'),
                          const SizedBox(height: 10),
                          FilledButton(
                              onPressed: _busy ||
                                      active['id']?.toString() ==
                                          plan['id']?.toString()
                                  ? null
                                  : () => _select(plan),
                              child: Text(active['id']?.toString() ==
                                      plan['id']?.toString()
                                  ? 'Current plan'
                                  : 'Choose plan')),
                        ])))),
                if (_busy) const LinearProgressIndicator(),
              ]);
            }));
  }
}
