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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hospital / PQC Logo Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 40,
                        color: Color(0xFF00796B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SecureMed IoT',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00796B),
                      ),
                    ),
                    Text(
                      'Post-Quantum Healthcare Device Security',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error Banner
                    if (authProvider.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 20, color: colorScheme.error),
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
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => context.read<AuthProvider>().clearError(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                    // Tab Selector: Sign In vs Register
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF00796B),
                      labelColor: const Color(0xFF00796B),
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Register Account'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tab Views
                    SizedBox(
                      height: 380,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLoginForm(authProvider),
                          _buildRegisterForm(authProvider),
                        ],
                      ),
                    ),

                    const Divider(height: 28),

                    // Quick Demo Accounts Fill Bar
                    Text(
                      'Quick Demo Credentials (Tap to fill):',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.medical_services_outlined, size: 14),
                          label: const Text('Doctor', style: TextStyle(fontSize: 11)),
                          onPressed: () => _fillDemo('doctor@hospital.local', 'Password123!'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.shield, size: 14),
                          label: const Text('SecOps Analyst', style: TextStyle(fontSize: 11)),
                          onPressed: () => _fillDemo('analyst@hospital.local', 'Password123!'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.admin_panel_settings, size: 14),
                          label: const Text('Admin', style: TextStyle(fontSize: 11)),
                          onPressed: () => _fillDemo('admin@hospital.local', 'Password123!'),
                        ),
                      ],
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

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          TextFormField(
            key: const ValueKey('login_email_field'),
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Hospital Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!val.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('login_password_field'),
            controller: _loginPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              if (val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: authProvider.isLoading ? null : _submitLogin,
            child: authProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Secure Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRegisterForm(AuthProvider authProvider) {
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('register_name_field'),
              controller: _registerNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name / Title',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register_email_field'),
              controller: _registerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Hospital Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email is required';
                if (!val.contains('@')) return 'Valid email required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register_password_field'),
              controller: _registerPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (val) {
                if (val == null || val.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              key: const ValueKey('register_role_dropdown'),
              isExpanded: true,
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role Designation',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: UserRole.doctor,
                  child: Text('Doctor / Clinician (Default)'),
                ),
                DropdownMenuItem(
                  value: UserRole.securityAnalyst,
                  child: Text('Security Analyst (SecOps)'),
                ),
                DropdownMenuItem(
                  value: UserRole.admin,
                  child: Text('Admin (Restricted - Requires Approval)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRole = val);
                }
              },
            ),
            if (_selectedRole == UserRole.admin)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'SECURITY RULE: Admin role cannot be self-assigned. Default unprivileged clinician profile will be provisioned until elevated.',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: authProvider.isLoading ? null : _submitRegister,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Protected Account', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
