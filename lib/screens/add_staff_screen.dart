import 'package:flutter/material.dart';
import '../models/hotel_models.dart';
import '../providers/hotel_provider.dart';
import '../services/app_env.dart';
import '../services/stayfix_email_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class AddStaffScreen extends StatefulWidget {
  final String currentUserRole;
  final bool isAddingSupervisorMode;
  final String? initialRole;

  const AddStaffScreen({
    super.key,
    required this.currentUserRole,
    this.isAddingSupervisorMode = false,
    this.initialRole,
  });

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final String googleScriptUrl =
      "https://script.google.com/macros/s/AKfycbzYxUgzZBT9GlVdrAZX-Idz3uybDM_3XiOTe331CtaUibmPT8QK-FPZHkjPG9wPcABAeA/exec";

  String? _selectedRole;
  String? _selectedManagerId;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAddingSupervisorMode) {
      _selectedRole = UserRoles.supervisor;
    } else if (widget.initialRole != null) {
      _selectedRole = widget.initialRole;
    } else if (_roles.isNotEmpty) {
      _selectedRole = _roles.first['id'];
    }
  }

  String get _screenTitle {
    if (_selectedRole == UserRoles.maintenanceManager) {
      return "AJOUTER DIR. MAINTENANCE";
    } else if (_selectedRole == UserRoles.housekeepingManager) {
      return "AJOUTER DIR. PROPRETÉ";
    } else if (_selectedRole == UserRoles.receptionManager) {
      return "AJOUTER DIR. RÉCEPTION";
    } else if (widget.isAddingSupervisorMode || _selectedRole == UserRoles.supervisor) {
      return "AJOUTER UN SUPERVISEUR";
    } else if (widget.currentUserRole == UserRoles.director) {
      return "AJOUTER UN DIRECTEUR";
    } else {
      return "AJOUTER UN OUVRIER";
    }
  }

  bool get _isWorkerRole {
    final isDirectorCreatingSubManager =
        widget.currentUserRole == UserRoles.director &&
            !widget.isAddingSupervisorMode &&
            (_selectedRole == UserRoles.maintenanceManager ||
                _selectedRole == UserRoles.housekeepingManager ||
                _selectedRole == UserRoles.receptionManager);
    return !isDirectorCreatingSubManager;
  }

  String get _targetAppName => _isWorkerRole ? "Stayfix Job" : "Stayfix";

  List<Map<String, dynamic>> get _roles {
    if (widget.currentUserRole == UserRoles.director) {
      if (widget.isAddingSupervisorMode) {
        return [
          {
            'id': UserRoles.supervisor,
            'label': 'Superviseur',
            'icon': LucideIcons.eye
          }
        ];
      } else {
        return [
          {
            'id': UserRoles.maintenanceManager,
            'label': 'Dir. Maintenance',
            'icon': LucideIcons.hammer
          },
          {
            'id': UserRoles.housekeepingManager,
            'label': 'Dir. Propreté',
            'icon': LucideIcons.sparkles
          },
          {
            'id': UserRoles.receptionManager,
            'label': 'Dir. Réception',
            'icon': LucideIcons.conciergeBell
          },
        ];
      }
    } else {
      return [
        {
          'id': UserRoles.supervisor,
          'label': 'Superviseur',
          'icon': LucideIcons.eye
        },
        {
          'id': UserRoles.houseman,
          'label': 'Houseman',
          'icon': LucideIcons.shirt
        },
        {
          'id': UserRoles.housekeeping,
          'label': 'Valet/Femme',
          'icon': LucideIcons.sprayCan
        },
        {
          'id': UserRoles.staff,
          'label': 'Staff Standard',
          'icon': LucideIcons.user
        },
      ];
    }
  }



  void _submit() async {
    final bool requiresUsername = _isWorkerRole && 
                                  _selectedRole != UserRoles.supervisor && 
                                  !widget.isAddingSupervisorMode;

    if (_selectedRole == null ||
        _firstNameController.text.trim().isEmpty ||
        (requiresUsername && _usernameController.text.trim().isEmpty) ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veuillez remplir tous les champs obligatoires"),
          backgroundColor: Colors.redAccent));
      return;
    }

    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veuillez saisir une adresse email valide"),
          backgroundColor: Colors.redAccent));
      return;
    }

    if (widget.currentUserRole == UserRoles.director &&
        widget.isAddingSupervisorMode &&
        _selectedManagerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Veuillez sélectionner un directeur pour ce superviseur"),
          backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    String finalRole = _selectedRole!;
    final provider = Provider.of<HotelProvider>(context, listen: false);

    if (widget.isAddingSupervisorMode && _selectedManagerId != null) {
      final manager =
          provider.hotelStaff.firstWhere((u) => u.id == _selectedManagerId);
      String cleanManagerRole = manager.role.replaceAll('Dir. ', '');
      finalRole = "Superviseur ($cleanManagerRole)";
    }

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    final String fullName = "$firstName $lastName".trim();
    final String hotelName = provider.currentHotelName;

    // Determine target app and download link
    final bool isWorker = _isWorkerRole;

    await provider.addStaffMember(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      username: username,
      password: password,
      role: finalRole,
      appAccess: isWorker ? 'stayfix_job' : null,
    );

    final String appName = isWorker ? "Stayfix Job" : "Stayfix";
    final String appLinkAndroid = isWorker
        ? await AppEnv.get(
            'STAYFIX_JOB_APP_URL',
            fallback: 'https://play.google.com/store/apps/details?id=com.rezzaky.stayfix_job',
          )
        : await AppEnv.get(
            'STAYFIX_APP_DOWNLOAD_URL',
            fallback: 'https://play.google.com/store/apps/details?id=com.rezzaky.stayfix',
          );
    final String appLinkIos = isWorker
        ? await AppEnv.get(
            'STAYFIX_JOB_APP_URL_IOS',
            fallback: 'https://apps.apple.com/pk/app/stayfix-job/id6771841746',
          )
        : await AppEnv.get(
            'STAYFIX_APP_DOWNLOAD_URL_IOS',
            fallback: 'https://apps.apple.com/us/app/stayfix/id6771962711',
          );

    // Send via central StayfixEmailService using the new layout
    await StayfixEmailService.sendHotelStaffCreatedEmail(
      to: email,
      recipientName: fullName.isNotEmpty ? fullName : email,
      hotelName: hotelName,
      role: finalRole,
      temporaryPassword: password,
      appName: appName,
      appLinkAndroid: appLinkAndroid,
      appLinkIos: appLinkIos,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "Membre ajouté avec succès. Email envoyé avec le lien $appName.",
          ),
          backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text(
          _screenTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mail, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Le membre recevra son mot de passe et le lien de l'application $_targetAppName par email.",
                      style: TextStyle(color: Colors.grey[300], fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
            const Text("SÉLECTIONNER LE RÔLE",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildRoleCard(_roles[index]),
              ),
            ),
            const SizedBox(height: 30),

            if (widget.currentUserRole == UserRoles.director &&
                widget.isAddingSupervisorMode) ...[
              const Text("RATTACHER AU DIRECTEUR",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildManagerDropdown(),
              const SizedBox(height: 30),
            ],

            const Text("INFORMATIONS",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInput("Prénom", _firstNameController, LucideIcons.user),
            _buildInput("Nom", _lastNameController, LucideIcons.user),
            _buildInput("Email", _emailController, LucideIcons.mail),
            _buildInput("Téléphone", _phoneController, LucideIcons.phone),

            const SizedBox(height: 30),
            const Text("ACCÈS",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_isWorkerRole && 
                _selectedRole != UserRoles.supervisor && 
                !widget.isAddingSupervisorMode)
              _buildInput(
                  "Nom d'utilisateur", _usernameController, LucideIcons.atSign),
            _buildInput("Mot de passe", _passwordController, LucideIcons.lock,
                isPassword: true),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Text("ENREGISTRER",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(Map<String, dynamic> role) {
    final isSelected = _selectedRole == role['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 105,
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? Colors.amber : Colors.transparent,
              width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(role['icon'],
                color: isSelected ? Colors.amber : Colors.white, size: 30),
            const SizedBox(height: 12),
            Text(
              role['label'],
              style: TextStyle(
                  color: isSelected ? Colors.amber : Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
      String label, TextEditingController controller, IconData icon,
      {bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildManagerDropdown() {
    return Consumer<HotelProvider>(builder: (context, provider, child) {
      final managers = provider.hotelStaff.where((u) {
        return u.role == UserRoles.receptionManager ||
            u.role == UserRoles.housekeepingManager ||
            u.role == UserRoles.maintenanceManager ||
            u.role.contains('Dir.');
      }).toList();

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            dropdownColor: const Color(0xFF27272A),
            value: _selectedManagerId,
            hint: Text("Choisir un directeur...",
                style: TextStyle(color: Colors.grey[600])),
            isExpanded: true,
            icon: const Icon(LucideIcons.chevronDown, color: Colors.grey),
            items: managers.isEmpty
                ? []
                : managers.map((manager) {
                    return DropdownMenuItem<String>(
                      value: manager.id,
                      child: Text("${manager.fullName} (${manager.role})",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    );
                  }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedManagerId = val;
              });
            },
          ),
        ),
      );
    });
  }
}
