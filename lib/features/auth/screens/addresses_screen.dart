import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shopify_flutter/models/src/shopify_user/address/address.dart';
import 'package:traincode/core/services/shopify_auth_service.dart';
import 'package:traincode/features/auth/bloc/auth_bloc.dart';
import 'package:traincode/features/auth/bloc/auth_state.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _service = ShopifyAuthService.instance;
  late Future<List<Address>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.listAddresses();
  }

  void _refresh() {
    setState(() {
      _future = _service.listAddresses();
    });
  }

  void _openAddressDialog({Address? address}) {
    final first = TextEditingController(text: address?.firstName ?? '');
    final last = TextEditingController(text: address?.lastName ?? '');
    final phone = TextEditingController(text: address?.phone ?? '');
    final address1 = TextEditingController(text: address?.address1 ?? '');
    final address2 = TextEditingController(text: address?.address2 ?? '');
    final city = TextEditingController(text: address?.city ?? '');
    final province = TextEditingController(text: address?.province ?? '');
    final zip = TextEditingController(text: address?.zip ?? '');
    final country = TextEditingController(text: address?.country ?? 'Kuwait');

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog.adaptive(
            title: Text(address == null ? 'إضافة عنوان' : 'تعديل العنوان'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: first,
                    decoration: const InputDecoration(labelText: 'الاسم الأول'),
                  ),
                  TextField(
                    controller: last,
                    decoration: const InputDecoration(labelText: 'اسم العائلة'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  TextField(
                    controller: address1,
                    decoration: const InputDecoration(labelText: 'عنوان 1'),
                  ),
                  TextField(
                    controller: address2,
                    decoration: const InputDecoration(labelText: 'عنوان 2'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'المدينة'),
                  ),
                  TextField(
                    controller: province,
                    decoration: const InputDecoration(labelText: 'المحافظة'),
                  ),
                  TextField(
                    controller: zip,
                    decoration: const InputDecoration(
                      labelText: 'الرمز البريدي',
                    ),
                  ),
                  TextField(
                    controller: country,
                    decoration: const InputDecoration(labelText: 'الدولة'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    if (address == null) {
                      await _service.createAddress(
                        firstName: first.text.trim().isEmpty
                            ? null
                            : first.text.trim(),
                        lastName: last.text.trim().isEmpty
                            ? null
                            : last.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        address1: address1.text.trim(),
                        address2: address2.text.trim().isEmpty
                            ? null
                            : address2.text.trim(),
                        city: city.text.trim(),
                        province: province.text.trim().isEmpty
                            ? null
                            : province.text.trim(),
                        zip: zip.text.trim().isEmpty ? null : zip.text.trim(),
                        country: country.text.trim(),
                      );
                    } else {
                      await _service.updateAddress(
                        id: address.id!,
                        firstName: first.text.trim().isEmpty
                            ? null
                            : first.text.trim(),
                        lastName: last.text.trim().isEmpty
                            ? null
                            : last.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                        address1: address1.text.trim(),
                        address2: address2.text.trim().isEmpty
                            ? null
                            : address2.text.trim(),
                        city: city.text.trim(),
                        province: province.text.trim().isEmpty
                            ? null
                            : province.text.trim(),
                        zip: zip.text.trim().isEmpty ? null : zip.text.trim(),
                        country: country.text.trim(),
                      );
                    }
                    if (context.mounted) Navigator.of(ctx).pop();
                    _refresh();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عناويني'),
          centerTitle: true,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          actions: [_buildCartIcon(), const SizedBox(width: 16)],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openAddressDialog(),
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return FutureBuilder<List<Address>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }
                final addresses = snapshot.data ?? [];
                if (addresses.isEmpty) {
                  return const Center(child: Text('لا توجد عناوين بعد'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final a = addresses[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.firstName ?? ''} ${a.lastName ?? ''}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              a.address1,
                              a.address2,
                              a.city,
                              a.province,
                              a.zip,
                              a.country,
                            ].where((e) => (e ?? '').isNotEmpty).join(', '),
                          ),
                          if ((a.phone ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(a.phone!),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _openAddressDialog(address: a),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('تعديل'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await _service.deleteAddress(
                                      addressId: a.id!,
                                    );
                                    _refresh();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('فشل الحذف: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'حذف',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: addresses.length,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartIcon() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        int itemCount = 0;
        if (cartState is CartSuccess) {
          itemCount = cartState.cart.lines.length;
        } else if (cartState is CartInitialized) {
          itemCount = cartState.cart.lines.length;
        }

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/cart'),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      FeatherIcons.shoppingBag,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            itemCount > 99 ? '99+' : itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
