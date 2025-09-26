import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/auth/bloc/auth_bloc.dart';
import 'package:marmooq/features/auth/bloc/auth_state.dart';
import 'package:marmooq/core/utils/validation_utils.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthInitialize());
    _firstNameController.text = 'Demo';
    _lastNameController.text = 'User';
    _emailController.text = 'demo@marmooq.com';
    _phoneController.text = '55555555';
    _passwordController.text = 'Demo@12345';
    _confirmPasswordController.text = 'Demo@12345';
    _acceptsMarketing = true;
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
    if (_formKey.currentState?.validate() ?? false) {
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
    }
  }

  void _navigateToLogin() {
    context.go('/login');
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
        appBar: AppBar(title: const Text('إنشاء حساب'), centerTitle: true),
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.isAuthenticated) {
              // Navigate to products view after successful registration
              context.go('/products');
            } else if (state.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Registration failed'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'إغلاق',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
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
                            prefixIcon: const Icon(FeatherIcons.phone),
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTablet ? 20 : 16,
                            ),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!ValidationUtils.isValidKuwaitPhone(value)) {
                                return 'يرجى إدخال رقم هاتف صالح';
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
                        SizedBox(height: isTablet ? 32 : 24),
                        ElevatedButton(
                          onPressed: state.isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
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
                                style: TextStyle(fontSize: isTablet ? 16 : 14),
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
