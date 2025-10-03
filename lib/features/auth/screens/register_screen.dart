import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/auth/bloc/auth_bloc.dart';
import 'package:marmooq/features/auth/bloc/auth_state.dart';
import 'package:marmooq/core/utils/validation_utils.dart';
import 'package:marmooq/core/constants/app_colors.dart';

/// Registration screen for Shopify authentication
class RegisterScreen extends StatefulWidget {
  /// Route name for navigation
  static const String routeName = '/register';

  /// Constructor
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _acceptsMarketing = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthInitialize());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  void _register() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الموافقة على الشروط والأحكام للمتابعة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    () async {
      // Request App Tracking Transparency on iOS
      if (Platform.isIOS) {
        try {
          await AppTrackingTransparency.requestTrackingAuthorization();
        } catch (_) {}
      }

      final normalizedPhone = ValidationUtils.normalizeKuwaitPhone(
        _phoneController.text,
      );
      context.read<AuthBloc>().add(
        AuthRegister(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: normalizedPhone.isEmpty ? null : normalizedPhone,
          acceptsMarketing: _acceptsMarketing,
        ),
      );
    }();
  }

  void _navigateToLogin() {
    context.go('/login');
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'خطأ في التسجيل',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(errorMessage, style: const TextStyle(fontSize: 16)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'موافق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;
    final isSmallScreen = screenSize.width < 400;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('إنشاء حساب'),
          centerTitle: true,
          backgroundColor: Colors.white,
        ),
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.isAuthenticated) {
              // Navigate to products view after successful registration
              context.go('/products');
            } else if (state.hasError) {
              _showErrorDialog(
                context,
                state.errorMessage ?? 'Registration failed',
              );
            }
          },
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32.0 : 16.0,
                  vertical: 16.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop
                        ? 600
                        : isTablet
                        ? 500
                        : double.infinity,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isTablet ? 24 : 16),
                        Text(
                          'إنشاء حسابك',
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'املأ تفاصيلك للبدء',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 32 : 24),
                        // Name fields - responsive layout
                        isSmallScreen
                            ? Column(
                                children: [
                                  TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الأول',
                                      border: const OutlineInputBorder(),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.brand,
                                          width: 2,
                                        ),
                                      ),
                                      floatingLabelStyle: const TextStyle(
                                        color: AppColors.brand,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: isTablet ? 20 : 16,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال اسمك الأول';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: isTablet ? 20 : 16),
                                  TextFormField(
                                    controller: _lastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الأخير',
                                      border: const OutlineInputBorder(),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.brand,
                                          width: 2,
                                        ),
                                      ),
                                      floatingLabelStyle: const TextStyle(
                                        color: AppColors.brand,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: isTablet ? 20 : 16,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال اسمك الأخير';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      decoration: InputDecoration(
                                        labelText: 'الاسم الأول',
                                        border: const OutlineInputBorder(),
                                        focusedBorder: const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: AppColors.brand,
                                            width: 2,
                                          ),
                                        ),
                                        floatingLabelStyle: const TextStyle(
                                          color: AppColors.brand,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: isTablet ? 20 : 16,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال اسمك الأول';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 20 : 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      decoration: InputDecoration(
                                        labelText: 'الاسم الأخير',
                                        border: const OutlineInputBorder(),
                                        focusedBorder: const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: AppColors.brand,
                                            width: 2,
                                          ),
                                        ),
                                        floatingLabelStyle: const TextStyle(
                                          color: AppColors.brand,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: isTablet ? 20 : 16,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال اسمك الأخير';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                        SizedBox(height: isTablet ? 20 : 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: const Icon(FeatherIcons.mail),
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTablet ? 20 : 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال بريدك الإلكتروني';
                            }
                            if (!ValidationUtils.isValidEmail(value)) {
                              return 'يرجى إدخال بريد إلكتروني صالح';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'الهاتف (اختياري)',
                            hintText: 'يجب أن يبدأ الرقم بـ 5 أو 6',
                            prefixIcon: const Icon(FeatherIcons.phone),
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTablet ? 20 : 16,
                            ),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final normalized =
                                  ValidationUtils.normalizeKuwaitPhone(value);
                              if (!ValidationUtils.isValidKuwaitPhone(
                                normalized,
                              )) {
                                return 'يرجى إدخال رقم هاتف صالح (يجب أن يبدأ بـ 5 أو 6 أو 9)';
                              }
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(FeatherIcons.lock),
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTablet ? 20 : 16,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? FeatherIcons.eye
                                    : FeatherIcons.eyeOff,
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال كلمة مرور';
                            }
                            if (!ValidationUtils.isStrongPassword(value)) {
                              return ValidationUtils.getPasswordValidationMessage(
                                value,
                              );
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور',
                            prefixIcon: const Icon(FeatherIcons.lock),
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTablet ? 20 : 16,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? FeatherIcons.eye
                                    : FeatherIcons.eyeOff,
                              ),
                              onPressed: _toggleConfirmPasswordVisibility,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى تأكيد كلمة المرور';
                            }
                            if (value != _passwordController.text) {
                              return 'كلمات المرور غير متطابقة';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptsMarketing,
                              onChanged: (value) {
                                setState(() {
                                  _acceptsMarketing = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                'أوافق على تلقي الاتصالات التسويقية من المتجر',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: isTablet ? 16 : 14),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 12 : 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontSize: isTablet ? 16 : 14),
                                  children: [
                                    const TextSpan(text: 'أوافق على '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: InkWell(
                                        onTap: () async {
                                          final uri = Uri.parse(
                                            'https://offeraatkw.com/78080082156/policies/38744293612.html?locale=ar',
                                          );
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        },
                                        child: Text(
                                          'الشروط والأحكام وسياسة الخصوصية',
                                          style: TextStyle(
                                            color: AppColors.brand,
                                            decoration:
                                                TextDecoration.underline,
                                            fontSize: isTablet ? 16 : 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 32 : 24),
                        ElevatedButton(
                          onPressed: state.isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,

                            padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 20 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: state.isLoading
                              ? const CircularProgressIndicator.adaptive()
                              : Text(
                                  'إنشاء حساب',
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    color: AppColors.brand,
                                  ),
                                ),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'لديك حساب بالفعل؟',
                              style: TextStyle(fontSize: isTablet ? 16 : 14),
                            ),
                            TextButton(
                              onPressed: _navigateToLogin,
                              child: Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
