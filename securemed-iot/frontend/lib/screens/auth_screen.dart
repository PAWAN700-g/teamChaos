import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.doctor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_loginFormKey.currentState?.validate() ?? false) {
      context.read<AuthProvider>().signIn(
            email: _loginEmailController.text.trim(),
            password: _loginPasswordController.text,
          );
    }
  }

  void _submitRegister() {
    if (_registerFormKey.currentState?.validate() ?? false) {
      context.read<AuthProvider>().register(
            email: _registerEmailController.text.trim(),
            password: _registerPasswordController.text,
            displayName: _registerNameController.text.trim(),
            role: _selectedRole,
          );
    }
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _loginEmailController.text = email;
      _loginPasswordController.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hospital / PQC Logo Header
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 38,
                        color: Color(0xFF00796B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SecureMed IoT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A192F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIST Post-Quantum Cryptographic Healthcare Access',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),

                    // Tab Bar: Sign In vs Register
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: const Color(0xFF0A192F),
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Sign In'),
                          Tab(text: 'Register Account'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Error Message Banner (if any)
                    if (authProvider.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authProvider.errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tab Contents
                    SizedBox(
                      height: 380,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLoginForm(context, authProvider),
                          _buildRegisterForm(context, authProvider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('login_email_field'),
            controller: _loginEmailController,
            decoration: InputDecoration(
              labelText: 'Hospital Staff Email',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter your email address';
              if (!val.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('login_password_field'),
            controller: _loginPasswordController,
            decoration: InputDecoration(
              labelText: 'Staff Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            obscureText: true,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Enter your password';
              if (val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: authProvider.status == AuthStatus.loading ? null : _submitLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: authProvider.status == AuthStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Secure Login',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
          const SizedBox(height: 16),
          // Quick Demo Credentials Selector
          const Text(
            'Quick-Fill Demo Credentials:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.local_hospital, size: 14, color: Color(0xFF00796B)),
                label: const Text('Doctor', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillDemo('doctor@hospital.local', 'Password123!'),
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.security, size: 14, color: Colors.indigo),
                label: const Text('Sec Analyst', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillDemo('analyst@hospital.local', 'Password123!'),
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.admin_panel_settings, size: 14, color: Colors.purple),
                label: const Text('Admin', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillDemo('admin@hospital.local', 'Password123!'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context, AuthProvider authProvider) {
    return Form(
      key: _registerFormKey,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          TextFormField(
            key: const ValueKey('register_name_field'),
            controller: _registerNameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter full name';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('register_email_field'),
            controller: _registerEmailController,
            decoration: InputDecoration(
              labelText: 'Staff Email',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter staff email';
              if (!val.contains('@')) return 'Enter valid email address';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('register_password_field'),
            controller: _registerPasswordController,
            decoration: InputDecoration(
              labelText: 'Password (min 6 chars)',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            obscureText: true,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Enter password';
              if (val.length < 6) return 'Minimum 6 characters required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserRole>(
            isExpanded: true,
            initialValue: _selectedRole,
            decoration: InputDecoration(
              labelText: 'Requested Role',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: UserRole.doctor, child: Text('Clinician / Doctor', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: UserRole.securityAnalyst, child: Text('Security Analyst', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: authProvider.status == AuthStatus.loading ? null : _submitRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: authProvider.status == AuthStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Create Protected Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ],
      ),
    );
  }
}
