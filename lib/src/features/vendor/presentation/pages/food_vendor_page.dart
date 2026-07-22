import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/widgets/vendor_scaffold.dart';

const _base = '/api/v1/commerce/food';
String _foodSlug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

class FoodVendorPage extends StatefulWidget {
  const FoodVendorPage({super.key});
  @override
  State<FoodVendorPage> createState() => _FoodVendorPageState();
}

class _FoodVendorPageState extends State<FoodVendorPage>
    with SingleTickerProviderStateMixin {
  final api = ApiClient();
  late TabController tabs;
  Map<String, dynamic>? restaurant, menu;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> combos = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      restaurant = await api.getJson('$_base/vendor/restaurant', auth: true);
      if (restaurant?.isNotEmpty == true) {
        menu = await api.getJson('$_base/vendor/menu', auth: true);
        combos = await api.getList('$_base/vendor/combos', auth: true);
      }
      final response = await api.getJson('$_base/vendor/orders', auth: true);
      orders = apiItems(response['items'] ?? response);
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => VendorScaffold(
      title: 'Food & kitchen',
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      child: Column(children: [
        TabBar(controller: tabs, tabs: const [
          Tab(text: 'Restaurant'),
          Tab(text: 'Menu'),
          Tab(text: 'Kitchen')
        ]),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : TabBarView(
                        controller: tabs,
                        children: [_profile(), _menu(), _kitchen()]))
      ]));
  Widget _profile() {
    final r = restaurant ?? {};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${r['name'] ?? 'Create restaurant profile'}',
          style: Theme.of(context).textTheme.headlineSmall),
      ListTile(
          leading: const Icon(Icons.location_on),
          title: Text('${r['address'] ?? 'Address required'}')),
      ListTile(
          leading: const Icon(Icons.schedule),
          title: Text(
              '${r['openingTime'] ?? '--'} – ${r['closingTime'] ?? '--'}')),
      ListTile(
          leading: const Icon(Icons.storefront),
          title: Text('Status ${r['status'] ?? 'offline'}'),
          subtitle: Text(r['isActive'] == true
              ? 'Visible to customers'
              : 'Not customer-visible')),
      FilledButton.icon(
          onPressed: () => _profileDialog(r),
          icon: const Icon(Icons.edit),
          label: Text(r.isEmpty ? 'Create profile' : 'Edit profile'))
    ]);
  }

  Future<void> _profileDialog(Map<String, dynamic> r) async {
    final name = TextEditingController(text: '${r['name'] ?? ''}'),
        address = TextEditingController(text: '${r['address'] ?? ''}'),
        lat = TextEditingController(text: '${r['latitude'] ?? ''}'),
        lng = TextEditingController(text: '${r['longitude'] ?? ''}');
    var status = '${r['status'] ?? 'open'}';
    var active = r['isActive'] ?? true;
    await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('Restaurant profile'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: 'Name')),
                      TextField(
                          controller: address,
                          decoration:
                              const InputDecoration(labelText: 'Address')),
                      TextField(
                          controller: lat,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Latitude')),
                      TextField(
                          controller: lng,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Longitude')),
                      DropdownButtonFormField(
                          initialValue: status,
                          items: ['open', 'busy', 'closed', 'offline']
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setLocal(() => status = v!)),
                      SwitchListTile(
                          value: active,
                          title: const Text('Customer-visible'),
                          onChanged: (v) => setLocal(() => active = v))
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            await api.putJson('$_base/vendor/restaurant',
                                auth: true,
                                body: {
                                  'name': name.text,
                                  'address': address.text,
                                  'latitude': double.tryParse(lat.text),
                                  'longitude': double.tryParse(lng.text),
                                  'status': status,
                                  'isActive': active
                                });
                            if (context.mounted) Navigator.pop(context);
                            await load();
                          },
                          child: const Text('Save'))
                    ])));
  }

  Widget _menu() {
    if (restaurant?.isEmpty != false) {
      return const Center(child: Text('Create restaurant profile first'));
    }
    final categories = apiItems(menu?['categories']),
        items = apiItems(menu?['items']);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(
            child: Text('Categories',
                style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
            onPressed: _categoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('Category'))
      ]),
      for (final c in categories)
        ListTile(
            title: Text('${c['name']}'),
            trailing: Switch(
                value: c['isActive'] ?? true,
                onChanged: (v) async {
                  await api.patchJson(
                      '$_base/vendor/menu/categories/${c['id']}',
                      auth: true,
                      body: {'isActive': v});
                  await load();
                })),
      Row(children: [
        Expanded(
            child:
                Text('Combos', style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
            onPressed: items.isEmpty ? null : () => _comboDialog(items),
            icon: const Icon(Icons.add),
            label: const Text('Combo'))
      ]),
      for (final combo in combos)
        Card(
            child: ListTile(
                title: Text('${combo['name']}'),
                subtitle: Text(
                    '₹${combo['price']} · ${(apiItems(combo['item_ids'])).length} items'),
                trailing: Switch(
                    value: combo['in_stock'] ?? true,
                    onChanged: (value) async {
                      await api.putJson('$_base/vendor/combos/${combo['id']}',
                          auth: true,
                          body: {
                            ...combo,
                            'itemIds': combo['item_ids'],
                            'inStock': value
                          });
                      await load();
                    }))),
      Row(children: [
        Expanded(
            child:
                Text('Items', style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
            onPressed:
                categories.isEmpty ? null : () => _itemDialog(categories),
            icon: const Icon(Icons.add),
            label: const Text('Item'))
      ]),
      for (final i in items)
        Card(
            child: ListTile(
                title: Text('${i['name']}'),
                subtitle: Text(
                    '₹${i['discountedPrice'] ?? i['price']} • ${i['categoryId'] ?? 'Uncategorised'}'),
                trailing: Switch(
                    value: i['inStock'] ?? true,
                    onChanged: (v) async {
                      await api.patchJson('$_base/vendor/menu/items/${i['id']}',
                          auth: true, body: {'inStock': v});
                      if (v) {
                        await api.postJson(
                            '$_base/vendor/menu/items/${i['id']}/notify-stock',
                            auth: true);
                      }
                      await load();
                    })))
    ]);
  }

  Future<void> _categoryDialog() async {
    final value = TextEditingController();
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('New category'),
                content: TextField(
                    controller: value,
                    decoration: const InputDecoration(labelText: 'Name')),
                actions: [
                  FilledButton(
                      onPressed: () async {
                        await api.postJson('$_base/vendor/menu/categories',
                            auth: true, body: {'name': value.text});
                        if (context.mounted) Navigator.pop(context);
                        await load();
                      },
                      child: const Text('Create'))
                ]));
  }

  Future<void> _itemDialog(List<Map<String, dynamic>> categories) async {
    final name = TextEditingController(), price = TextEditingController();
    final addons = <Map<String, dynamic>>[];
    final customizations = <Map<String, dynamic>>[];
    var category = '${categories.first['id']}';
    await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('New menu item'),
                    content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                  controller: name,
                                  decoration:
                                      const InputDecoration(labelText: 'Name')),
                              TextField(
                                  controller: price,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Price')),
                              DropdownButtonFormField(
                                  initialValue: category,
                                  decoration: const InputDecoration(
                                      labelText: 'Category'),
                                  items: categories
                                      .map((c) => DropdownMenuItem(
                                          value: '${c['id']}',
                                          child: Text('${c['name']}')))
                                      .toList(),
                                  onChanged: (v) =>
                                      setLocal(() => category = v!)),
                              const SizedBox(height: 16),
                              Row(children: [
                                const Expanded(
                                    child: Text('Add-ons',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                TextButton.icon(
                                    onPressed: () => setLocal(() =>
                                        addons.add({'name': '', 'price': 0.0})),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add'))
                              ]),
                              if (addons.isEmpty)
                                const Text('Optional extras such as toppings.',
                                    style: TextStyle(color: Colors.grey)),
                              for (var index = 0;
                                  index < addons.length;
                                  index++)
                                Row(key: ValueKey('addon-$index'), children: [
                                  Expanded(
                                      child: TextFormField(
                                          initialValue:
                                              '${addons[index]['name']}',
                                          decoration: const InputDecoration(
                                              labelText: 'Add-on name'),
                                          onChanged: (value) =>
                                              addons[index]['name'] = value)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                          initialValue:
                                              '${addons[index]['price']}',
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText: 'Extra ₹'),
                                          onChanged: (value) => addons[index]
                                                  ['price'] =
                                              double.tryParse(value) ?? 0)),
                                  IconButton(
                                      onPressed: () => setLocal(
                                          () => addons.removeAt(index)),
                                      icon: const Icon(Icons.delete_outline))
                                ]),
                              const SizedBox(height: 16),
                              Row(children: [
                                const Expanded(
                                    child: Text('Customisations',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                TextButton.icon(
                                    onPressed: () => setLocal(() =>
                                        customizations.add({
                                          'name': '',
                                          'required': false,
                                          'options': <Map<String, dynamic>>[]
                                        })),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Group'))
                              ]),
                              if (customizations.isEmpty)
                                const Text(
                                    'Choice groups such as size or spice level.',
                                    style: TextStyle(color: Colors.grey)),
                              for (var groupIndex = 0;
                                  groupIndex < customizations.length;
                                  groupIndex++)
                                Card(
                                    key: ValueKey('group-$groupIndex'),
                                    child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(children: [
                                          Row(children: [
                                            Expanded(
                                                child: TextFormField(
                                                    initialValue:
                                                        '${customizations[groupIndex]['name']}',
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Group name'),
                                                    onChanged: (value) =>
                                                        customizations[
                                                                groupIndex]
                                                            ['name'] = value)),
                                            IconButton(
                                                onPressed: () => setLocal(() =>
                                                    customizations
                                                        .removeAt(groupIndex)),
                                                icon: const Icon(
                                                    Icons.delete_outline))
                                          ]),
                                          SwitchListTile(
                                              contentPadding: EdgeInsets.zero,
                                              value: customizations[groupIndex]
                                                      ['required'] ==
                                                  true,
                                              title:
                                                  const Text('Required choice'),
                                              onChanged: (value) => setLocal(
                                                  () =>
                                                      customizations[groupIndex]
                                                              ['required'] =
                                                          value)),
                                          for (var optionIndex = 0;
                                              optionIndex <
                                                  (customizations[groupIndex]
                                                              ['options']
                                                          as List<
                                                              Map<String,
                                                                  dynamic>>)
                                                      .length;
                                              optionIndex++)
                                            Row(children: [
                                              Expanded(
                                                  child: TextFormField(
                                                      initialValue:
                                                          '${(customizations[groupIndex]['options'] as List)[optionIndex]['name']}',
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Option'),
                                                      onChanged: (value) =>
                                                          (customizations[groupIndex]
                                                                          [
                                                                          'options']
                                                                      as List)[
                                                                  optionIndex][
                                                              'name'] = value)),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                  width: 100,
                                                  child: TextFormField(
                                                      initialValue:
                                                          '${(customizations[groupIndex]['options'] as List)[optionIndex]['price']}',
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Extra ₹'),
                                                      onChanged: (value) =>
                                                          (customizations[groupIndex]
                                                                      ['options']
                                                                  as List)[optionIndex]
                                                              ['price'] = double
                                                                  .tryParse(
                                                                      value) ??
                                                              0)),
                                              IconButton(
                                                  onPressed: () => setLocal(
                                                      () => (customizations[
                                                                      groupIndex]
                                                                  ['options']
                                                              as List)
                                                          .removeAt(
                                                              optionIndex)),
                                                  icon: const Icon(Icons
                                                      .remove_circle_outline))
                                            ]),
                                          Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton(
                                                  onPressed: () => setLocal(() =>
                                                      (customizations[groupIndex]
                                                                  ['options']
                                                              as List<
                                                                  Map<String,
                                                                      dynamic>>)
                                                          .add({
                                                        'name': '',
                                                        'price': 0.0
                                                      })),
                                                  child: const Text(
                                                      '+ Add option')))
                                        ])))
                            ]),
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            final cleanAddons = addons
                                .where(
                                    (row) => '${row['name']}'.trim().isNotEmpty)
                                .map((row) =>
                                    {...row, 'id': _foodSlug('${row['name']}')})
                                .toList();
                            final cleanGroups = customizations
                                .where(
                                    (row) => '${row['name']}'.trim().isNotEmpty)
                                .map((row) => {
                                      ...row,
                                      'id': _foodSlug('${row['name']}'),
                                      'options': (row['options']
                                              as List<Map<String, dynamic>>)
                                          .where((option) => '${option['name']}'
                                              .trim()
                                              .isNotEmpty)
                                          .map((option) => {
                                                ...option,
                                                'id': _foodSlug(
                                                    '${option['name']}')
                                              })
                                          .toList()
                                    })
                                .toList();
                            await api.postJson('$_base/vendor/menu/items',
                                auth: true,
                                body: {
                                  'name': name.text,
                                  'price': double.tryParse(price.text),
                                  'categoryId': category,
                                  'inStock': true,
                                  'addons': cleanAddons,
                                  'customizations': cleanGroups
                                });
                            if (context.mounted) Navigator.pop(context);
                            await load();
                          },
                          child: const Text('Create'))
                    ])));
  }

  Future<void> _comboDialog(List<Map<String, dynamic>> items) async {
    final name = TextEditingController(), price = TextEditingController();
    final selected = <String>{};
    await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('New combo'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'Combo name')),
                      TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Combo price')),
                      for (final item in items)
                        CheckboxListTile(
                            value: selected.contains('${item['id']}'),
                            title: Text('${item['name']}'),
                            onChanged: (value) => setLocal(() {
                                  value == true
                                      ? selected.add('${item['id']}')
                                      : selected.remove('${item['id']}');
                                }))
                    ])),
                    actions: [
                      FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                                  await api.postJson('$_base/vendor/combos',
                                      auth: true,
                                      body: {
                                        'name': name.text,
                                        'price': double.tryParse(price.text),
                                        'itemIds': selected.toList(),
                                        'inStock': true,
                                        'isActive': true
                                      });
                                  if (context.mounted) Navigator.pop(context);
                                  await load();
                                },
                          child: const Text('Create'))
                    ])));
  }

  Widget _kitchen() {
    if (orders.isEmpty) return const Center(child: Text('No food orders'));
    return ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final o = orders[index], status = '${o['status']}';
          return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                  title: Text('${o['orderRef']}'),
                  subtitle: Text(
                      '${o['customerName'] ?? 'Customer'} • $status • ₹${o['total']}'),
                  children: [
                    for (final item in apiItems(o['items']))
                      ListTile(
                          dense: true,
                          title: Text('${item['name']} × ${item['quantity']}')),
                    Wrap(spacing: 8, children: [
                      for (final next in _next(status))
                        FilledButton.tonal(
                            onPressed: () => _status('${o['id']}', next),
                            child: Text(next.replaceAll('_', ' '))),
                      if (status == 'ready')
                        OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await api.postJson(
                                    '$_base/vendor/orders/${o['id']}/assign-rider',
                                    auth: true);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Nearest rider offered')));
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')));
                              }
                            },
                            icon: const Icon(Icons.delivery_dining),
                            label: const Text('Assign rider'))
                    ]),
                    const SizedBox(height: 8)
                  ]));
        });
  }

  List<String> _next(String s) =>
      {
        'placed': ['accepted', 'rejected'],
        'accepted': ['preparing', 'cancelled'],
        'preparing': ['ready']
      }[s] ??
      [];
  Future<void> _status(String id, String status) async {
    await api.patchJson('$_base/vendor/orders/$id/status',
        auth: true, body: {'status': status});
    await load();
  }
}
