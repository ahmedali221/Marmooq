import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/features/auth/bloc/auth_bloc.dart';
import 'package:traincode/features/auth/bloc/auth_state.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    _firstNameController = TextEditingController(
      text: state.user?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: state.user?.lastName ?? '',
    );
    _emailController = TextEditingController(text: state.user?.email ?? '');
    _phoneController = TextEditingController(text: state.user?.phone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'البريد مطلوب';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'صيغة بريد غير صحيحة';
    return null;
  }

  String? _validateKuwaitPhone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null; // optional
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      if (!RegExp(r'^[2569]').hasMatch(digits)) {
        return 'ابدأ برقم صحيح (2 أو 5 أو 6 أو 9)';
      }
      return null; // will be normalized to +965
    }
    if ((digits.length == 11 && digits.startsWith('965')) ||
        (digits.length == 12 && digits.startsWith('9650'))) {
      final local = digits.length == 11
          ? digits.substring(3)
          : digits.substring(4);
      if (!RegExp(r'^[2569]').hasMatch(local)) {
        return 'ابدأ برقم صحيح (2 أو 5 أو 6 أو 9)';
      }
      return null;
    }
    return 'يرجى إدخال رقم كويتي صحيح: 8 أرقام أو +965 متبوعاً بـ 8 أرقام';
  }

  String? _normalizeKuwaitPhone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 8) return '+965$digits';
    if (digits.length == 11 && digits.startsWith('965')) return '+$digits';
    if (digits.length == 12 && digits.startsWith('9650')) {
      return '+${digits.substring(0, 3)}${digits.substring(4)}';
    }
    return null; // invalid
  }

  void _submit() {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final currentPhone = context.read<AuthBloc>().state.user?.phone;
    final normalizedPhone = _normalizeKuwaitPhone(_phoneController.text);
    if (_phoneController.text.trim().isNotEmpty && normalizedPhone == null) {
      setState(() {
        _inlineError =
            'يرجى إدخال رقم كويتي صحيح: 8 أرقام أو +965 متبوعاً بـ 8 أرقام';
      });
      return;
    }

    context.read<AuthBloc>().add(
      AuthUpdateProfile(
        firstName: _firstNameController.text.trim().isEmpty
            ? null
            : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: normalizedPhone == currentPhone ? null : normalizedPhone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعديل الحساب'),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            },
          ),
        ),
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.isAuthenticated) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث البيانات بنجاح')),
              );
            } else if (state.status == AuthStatus.error) {
              final msg = state.errorMessage ?? 'حدث خطأ أثناء التحديث';
              String friendly = msg;
              if (msg.contains('محجوز') ||
                  msg.toLowerCase().contains('already')) {
                friendly =
                    'رقم الهاتف مستخدم مسبقاً. استخدم رقماً آخر أو اتركه فارغاً.';
              } else if (msg.contains('غير صالح') ||
                  msg.toLowerCase().contains('invalid')) {
                friendly = 'رقم الهاتف غير صالح. استخدم صيغة كويتية صحيحة.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(friendly), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state.isLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الأول',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم العائلة',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            validator: _validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          IntlPhoneField(
                            controller: _phoneController,
                            initialCountryCode: 'KW',
                            disableLengthCheck: true,
                            flagsButtonPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (phone) =>
                                _validateKuwaitPhone(phone?.completeNumber),
                            onChanged: (phone) {
                              // no-op, we normalize on submit
                            },
                          ),
                          if (_inlineError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _inlineError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : _submit,
                              icon: isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('حفظ التغييرات'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.teal[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
