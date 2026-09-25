import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_provider.dart';
import '../services/ai_sound_service.dart';
import 'auth_screen.dart';
import 'condo_dashboard_screen.dart';
import 'immeuble_dashboard.dart';
import 'manager_profile_config.dart';
import 'orders/order_hub_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants – Midnight Sapphire × Radiant Gold palette
// ─────────────────────────────────────────────────────────────────────────────
const Color _bg        = Color(0xFF040814); // deep obsidian-navy
const Color _gold      = Color(0xFFD6A85A);
const Color _goldDark  = Color(0xFFB8863B);
const Color _goldLight = Color(0xFFF0CB87);
// midnight blue surface / border / glow
const Color _navySurface  = Color(0xFF0B1322);
const Color _navyBorder   = Color(0xFF182A42);
const Color _sapphireGlow = Color(0xFF133E6E);

// ─────────────────────────────────────────────────────────────────────────────
// Entry-point widget
// ─────────────────────────────────────────────────────────────────────────────
class DirectorTypeScreen extends StatefulWidget {
  const DirectorTypeScreen({super.key, this.showIntroAnimation = true});

  final bool showIntroAnimation;

  @override
  State<DirectorTypeScreen> createState() => _DirectorTypeScreenState();
}

class _DirectorTypeScreenState extends State<DirectorTypeScreen> {
  // Intro animation phase
  bool _introVisible = false;
  bool _introAnimationDone = false;
  Timer? _introTimer;

  // Step 1 / Step 2 state
  UniverseDomain? _selectedDomain;
  String? _selectedRoleValue;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(AiSoundService.init());
    if (widget.showIntroAnimation) {
      _introVisible = true;
      unawaited(AiSoundService.playActivate());
      // Show intro for 2.2 s then auto-advance to step 1
      _introTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _introAnimationDone = true);
          unawaited(AiSoundService.playReady());
        }
      });
    } else {
      _introAnimationDone = true;
      unawaited(AiSoundService.playReady());
    }
  }

  void _skipIntro() {
    if (!_introAnimationDone) {
      _introTimer?.cancel();
      _introTimer = null;
      HapticFeedback.lightImpact();
      setState(() => _introAnimationDone = true);
      unawaited(AiSoundService.playReady());
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    AiSoundService.stopAll();
    super.dispose();
  }

  // ── Submission ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedRoleValue == null || _isLoading) return;

    // Normalise alias used in domain catalogue
    final String resolvedValue = _selectedRoleValue == 'rental_building_locatif'
        ? 'rental_building'
        : _selectedRoleValue!;

    final option = managerProfileOptionByValue(resolvedValue);
    if (option == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showAuthError(context, 'Session introuvable. Veuillez vous reconnecter.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'directorType': option.label,
        'propertyProfileType': resolvedValue,
        'propertyProfileLabel': option.label,
        'profileCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      final Widget nextScreen;
      if (resolvedValue == 'hotel_manager') {
        nextScreen = const OrderHubScreen();
      } else if (resolvedValue == 'building_manager' ||
          resolvedValue == 'rental_building') {
        nextScreen = ImmeubleDashboardScreen(propertyType: resolvedValue);
      } else {
        nextScreen = CondoDashboardScreen(propertyType: resolvedValue);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (e) {
      if (mounted) {
        showAuthError(context, "Erreur lors de l'enregistrement du profil.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    await Provider.of<HotelProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Widget _buildCurrentStep() {
    if (_introVisible && !_introAnimationDone) {
      return _IntroLayer(
        key: const ValueKey('intro'),
        onTap: _skipIntro,
      );
    }
    if (_selectedDomain == null) {
      return _StepOne(
        key: const ValueKey('step1'),
        onDomainSelected: (d) {
          unawaited(AiSoundService.playSelect());
          setState(() {
            _selectedDomain = d;
            _selectedRoleValue = null;
          });
        },
        onLogout: _logout,
      );
    }
    return _StepTwo(
      key: ValueKey('step2_${_selectedDomain!.id}'),
      domain: _selectedDomain!,
      selectedValue: _selectedRoleValue,
      isLoading: _isLoading,
      onBack: () {
        unawaited(AiSoundService.playBack());
        setState(() {
          _selectedDomain = null;
          _selectedRoleValue = null;
        });
      },
      onRoleSelected: (v) {
        unawaited(AiSoundService.playToggle());
        setState(() => _selectedRoleValue = v);
      },
      onSubmit: () {
        unawaited(AiSoundService.playConfirm());
        _submit();
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedDomain == null && (_introAnimationDone || !_introVisible),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_introAnimationDone) {
          _skipIntro();
        } else if (_selectedDomain != null) {
          unawaited(AiSoundService.playBack());
          setState(() {
            _selectedDomain = null;
            _selectedRoleValue = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // ── Ambient background ─────────────────────────────────────────────
            const _AmbientBackground(),

            // ── Main flow with fluid Apple-like slide & fade transition ────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient midnight sapphire background
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient – deep obsidian navy
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF070E1E),
                Color(0xFF040814),
                Color(0xFF030610),
              ],
            ),
          ),
        ),
        // Celestial sapphire halo – centered, behind the orb
        Positioned(
          top: size.height * 0.05,
          left: size.width * 0.5 - 180,
          child: _Blob(
            size: 360,
            color: const Color(0xFF144272).withValues(alpha: 0.50),
          ),
        ),
        // Top-right azure accent
        Positioned(
          top: -60,
          right: -40,
          child: _Blob(
            size: 220,
            color: const Color(0xFF1B4979).withValues(alpha: 0.22),
          ),
        ),
        // Bottom-left cobalt depth
        Positioned(
          bottom: 80,
          left: -60,
          child: _Blob(
            size: 240,
            color: const Color(0xFF0D2138).withValues(alpha: 0.35),
          ),
        ),
        // Bottom-right secondary sapphire
        Positioned(
          bottom: -40,
          right: -50,
          child: _Blob(
            size: 200,
            color: const Color(0xFF0C2747).withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
  });
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.45),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intro layer (first 2 s after sign-in, tap anywhere to continue)
// ─────────────────────────────────────────────────────────────────────────────
class _IntroLayer extends StatelessWidget {
  const _IntroLayer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Central cosmic orbital emblem
                const _CosmicOrbitalEmblem(
                  coreSize: 72,
                  outerOrbitA: 100,
                  outerOrbitB: 54,
                  innerOrbitA: 72,
                  innerOrbitB: 39,
                  introMode: true,
                ).animate().scaleXY(begin: 0.70, duration: 650.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 36),

                // Chip badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF133E6E).withValues(alpha: 0.35),
                    border: Border.all(
                      color: const Color(0xFF2563B0).withValues(alpha: 0.48),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF133E6E).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.sparkles, color: Color(0xFF7CA6F8), size: 13),
                      const SizedBox(width: 8),
                      Text(
                        'ASSISTANT IA STAYFIX',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFB0CDFF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.15, end: 0),

                const SizedBox(height: 18),

                // BIENVENUE
                Text(
                  'B I E N V E N U E',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: _gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.5,
                  ),
                ).animate().fadeIn(delay: 180.ms, duration: 400.ms).slideY(begin: 0.15, end: 0),

                const SizedBox(height: 12),

                // Headline
                Text(
                  'Choisissez votre univers',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: 0.3,
                  ),
                ).animate().fadeIn(delay: 260.ms, duration: 450.ms).slideY(begin: 0.15, end: 0),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Votre espace de gestion haut de gamme vous attend.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 450.ms),

                const SizedBox(height: 32),

                // Interactive tap hint
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Appuyez pour continuer',
                      style: GoogleFonts.manrope(
                        color: _gold.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.chevronRight,
                      color: _gold.withValues(alpha: 0.70),
                      size: 14,
                    ),
                  ],
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(delay: 450.ms, duration: 350.ms)
                    .shimmer(duration: 1600.ms, color: _goldLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 – Universe Domain Selection
// ─────────────────────────────────────────────────────────────────────────────
class _StepOne extends StatelessWidget {
  const _StepOne({
    super.key,
    required this.onDomainSelected,
    required this.onLogout,
  });

  final ValueChanged<UniverseDomain> onDomainSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isCompact = size.height < 750;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(22, 0, 22, bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status bar ──────────────────────────────────────────────────
            const SizedBox(height: 18),
            Row(
              children: [
                // Online dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF22C55E),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x5522C55E),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '• STAYFIX DIRECTOR',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onLogout();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.logOut,
                            color: Colors.white.withValues(alpha: 0.60), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Déconnexion',
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 350.ms),

            // ── Cosmic orbital emblem ────────────────────────────────────────
            SizedBox(height: isCompact ? 20 : 32),
            Center(
              child: const _CosmicOrbitalEmblem(
                coreSize: 58,
                outerOrbitA: 82,
                outerOrbitB: 44,
                innerOrbitA: 60,
                innerOrbitB: 32,
                introMode: false,
              ).animate().fadeIn(delay: 50.ms, duration: 400.ms).scaleXY(
                    begin: 0.85,
                    curve: Curves.easeOutCubic,
                    duration: 500.ms,
                  ),
            ),

            // ── Header text ─────────────────────────────────────────────────
            SizedBox(height: isCompact ? 20 : 28),
            Center(
              child: Column(
                children: [
                  Text(
                    'Bienvenue',
                    style: GoogleFonts.manrope(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez votre univers',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      color: Colors.white,
                      fontSize: isCompact ? 28 : 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez un domaine ci-dessous pour ouvrir vos options',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _gold.withValues(alpha: 0.10),
                      border: Border.all(color: _gold.withValues(alpha: 0.28), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.sparkles, color: _gold, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'ÉTAPE 1 SUR 2 : SÉLECTIONNEZ UN DOMAINE',
                          style: GoogleFonts.manrope(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

            // ── Domain cards ────────────────────────────────────────────────
            SizedBox(height: isCompact ? 22 : 30),
            ...kUniverseDomains.asMap().entries.map((e) {
              final idx = e.key;
              final domain = e.value;
              return Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 12 : 14),
                child: _DomainCard(
                  domain: domain,
                  onTap: () => onDomainSelected(domain),
                ).animate()
                    .fadeIn(delay: Duration(milliseconds: 140 + idx * 55), duration: 320.ms)
                    .slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DomainCard extends StatefulWidget {
  const _DomainCard({required this.domain, required this.onTap});
  final UniverseDomain domain;
  final VoidCallback onTap;

  @override
  State<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<_DomainCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [const Color(0xFF0F1D30), const Color(0xFF0C1628)]
                  : [_navySurface, const Color(0xFF080F1C)],
            ),
            border: Border.all(
              color: _pressed
                  ? _gold.withValues(alpha: 0.65)
                  : _navyBorder.withValues(alpha: 0.80),
              width: _pressed ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              if (_pressed)
                BoxShadow(
                  color: _sapphireGlow.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF101B2E),
                  border: Border.all(color: _gold.withValues(alpha: 0.35), width: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: _sapphireGlow.withValues(alpha: 0.20),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(widget.domain.icon, color: _gold, size: 22),
              ),
              const SizedBox(width: 16),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.domain.title,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.domain.subtitle,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Arrow bubble
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: _pressed ? 0.25 : 0.08),
                  border: Border.all(
                    color: _gold.withValues(alpha: _pressed ? 0.70 : 0.45),
                    width: 0.9,
                  ),
                ),
                child: const Icon(LucideIcons.chevronRight, color: _gold, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 – Role Selection
// ─────────────────────────────────────────────────────────────────────────────
class _StepTwo extends StatelessWidget {
  const _StepTwo({
    super.key,
    required this.domain,
    required this.selectedValue,
    required this.isLoading,
    required this.onBack,
    required this.onRoleSelected,
    required this.onSubmit,
  });

  final UniverseDomain domain;
  final String? selectedValue;
  final bool isLoading;
  final VoidCallback onBack;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onSubmit;

  bool get _canSubmit => selectedValue != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isCompact = size.height < 750;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(22, 0, 22, bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button ─────────────────────────────────────────────────
            const SizedBox(height: 18),
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onBack();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _gold.withValues(alpha: 0.08),
                      border: Border.all(color: _gold.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.arrowLeft, color: _gold, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          'Changer de domaine',
                          style: GoogleFonts.manrope(
                            color: _gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),

            // ── Header ──────────────────────────────────────────────────────
            SizedBox(height: isCompact ? 20 : 28),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_goldLight, _goldDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(domain.icon, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain.title,
                        style: GoogleFonts.cormorantGaramond(
                          color: Colors.white,
                          fontSize: isCompact ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Sélectionnez votre rôle principal de direction',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 50.ms, duration: 320.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

            // Step tag
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _gold.withValues(alpha: 0.10),
                border: Border.all(color: _gold.withValues(alpha: 0.28), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.sparkles, color: _gold, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'ÉTAPE 2 SUR 2 : SÉLECTIONNEZ VOTRE RÔLE PRÉCIS',
                    style: GoogleFonts.manrope(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 90.ms, duration: 280.ms),

            // ── Divider ──────────────────────────────────────────────────────
            const SizedBox(height: 20),
            Divider(color: _gold.withValues(alpha: 0.14), height: 1),
            const SizedBox(height: 18),

            // ── Role cards ───────────────────────────────────────────────────
            ...domain.roles.asMap().entries.map((e) {
              final idx = e.key;
              final role = e.value;
              final isSelected = selectedValue == role.value;
              return Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 12 : 14),
                child: _RoleCard(
                  option: role,
                  isSelected: isSelected,
                  onTap: () => onRoleSelected(role.value),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 70 + idx * 45), duration: 280.ms)
                    .slideX(begin: 0.04, end: 0, duration: 280.ms, curve: Curves.easeOutCubic),
              );
            }),

            // ── Submit button ────────────────────────────────────────────────
            const SizedBox(height: 10),
            _SubmitButton(
              enabled: _canSubmit,
              isLoading: isLoading,
              onTap: _canSubmit ? onSubmit : null,
            ).animate().fadeIn(delay: 160.ms, duration: 280.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });
  final ManagerProfileOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: sel
                  ? [const Color(0xFF0F1D30), const Color(0xFF0C1628)]
                  : [_navySurface, const Color(0xFF070D18)],
            ),
            border: Border.all(
              color: sel ? _gold : _navyBorder.withValues(alpha: 0.70),
              width: sel ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              if (sel)
                BoxShadow(
                  color: _gold.withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              // Role icon badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? _gold.withValues(alpha: 0.18) : _gold.withValues(alpha: 0.08),
                  border: Border.all(
                    color: sel ? _gold.withValues(alpha: 0.55) : _gold.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Icon(widget.option.icon, color: _gold, size: 20),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.label,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.option.subtitle,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Radio / checkmark with spring pop
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? _gold : Colors.transparent,
                  border: Border.all(
                    color: sel ? _gold : Colors.white.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.40),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: AnimatedScale(
                  scale: sel ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: const Icon(LucideIcons.check, color: Colors.black, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit / CTA button
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_goldLight, _gold, _goldDark],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
            border: Border.all(
              color: active ? _gold.withValues(alpha: 0.70) : Colors.white.withValues(alpha: 0.12),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: _pressed ? 0.50 : 0.30),
                      blurRadius: _pressed ? 28 : 20,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Valider et continuer',
                        style: GoogleFonts.manrope(
                          color: active ? Colors.black : Colors.white.withValues(alpha: 0.30),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        LucideIcons.arrowRight,
                        color: active ? Colors.black : Colors.white.withValues(alpha: 0.25),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Cosmic Orbital Emblem – animated spinning satellite dots on tilted ellipses
// ─────────────────────────────────────────────────────────────────────────────
class _CosmicOrbitalEmblem extends StatefulWidget {
  const _CosmicOrbitalEmblem({
    required this.coreSize,
    required this.outerOrbitA,
    required this.outerOrbitB,
    required this.innerOrbitA,
    required this.innerOrbitB,
    this.introMode = false,
  });

  final double coreSize;
  final double outerOrbitA; // semi-major axis
  final double outerOrbitB; // semi-minor axis
  final double innerOrbitA;
  final double innerOrbitB;
  final bool introMode;

  @override
  State<_CosmicOrbitalEmblem> createState() => _CosmicOrbitalEmblemState();
}

class _CosmicOrbitalEmblemState extends State<_CosmicOrbitalEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasW = (widget.outerOrbitA + 22) * 2;
    final canvasH = (widget.outerOrbitA + 22) * 2;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: canvasW,
          height: canvasH,
          child: CustomPaint(
            painter: _OrbitPainter(
              t: _ctrl.value,
              coreSize: widget.coreSize,
              outerA: widget.outerOrbitA,
              outerB: widget.outerOrbitB,
              innerA: widget.innerOrbitA,
              innerB: widget.innerOrbitB,
            ),
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.t,
    required this.coreSize,
    required this.outerA,
    required this.outerB,
    required this.innerA,
    required this.innerB,
  });

  final double t;
  final double coreSize;
  final double outerA, outerB;
  final double innerA, innerB;

  static const double _tilt = -0.48; // ~−27.5°

  Offset _ellipsePoint(Offset center, double a, double b, double theta) {
    final x = a * math.cos(theta);
    final y = b * math.sin(theta);
    final rx = x * math.cos(_tilt) - y * math.sin(_tilt);
    final ry = x * math.sin(_tilt) + y * math.cos(_tilt);
    return center + Offset(rx, ry);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Sapphire ambient halo behind the sphere (GPU radial gradient) ──
    final haloRect = Rect.fromCircle(center: center, radius: coreSize * 0.95);
    final haloShader = const RadialGradient(
      colors: [
        Color(0x751A4F8A),
        Color(0x321A4F8A),
        Color(0x001A4F8A),
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(haloRect);
    canvas.drawCircle(center, coreSize * 0.95, Paint()..shader = haloShader);

    // ── Orbit ellipse paths (hardware-accelerated GPU drawOval) ──
    void drawOrbit(double a, double b, Color color) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_tilt);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: a * 2, height: b * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.85
          ..color = color,
      );
      canvas.restore();
    }

    drawOrbit(outerA, outerB, const Color(0xFFD6A85A).withValues(alpha: 0.22));
    drawOrbit(innerA, innerB, const Color(0xFFB0CDFF).withValues(alpha: 0.18));

    // ── Satellite angles ──
    final outerTheta = t * 2 * math.pi;
    final innerTheta = -(t * 2 * math.pi * 1.45) + math.pi;

    void drawSatellite({
      required double a,
      required double b,
      required double theta,
      required Color color,
      required Color glowColor,
      required double radius,
      required double glowRadius,
    }) {
      final pt = _ellipsePoint(center, a, b, theta);
      final depth = (math.sin(theta) + 1) / 2;
      final opacity = 0.55 + 0.45 * depth;
      final scale = 0.72 + 0.28 * depth;

      // Motion trail
      for (int trail = 3; trail >= 1; trail--) {
        final trailTheta = theta - trail * 0.14;
        final trailPt = _ellipsePoint(center, a, b, trailTheta);
        final trailDepth = (math.sin(trailTheta) + 1) / 2;
        final trailOpacity = opacity * (1 - trail * 0.28) * trailDepth;
        final trailScale = scale * (1 - trail * 0.18);
        if (trailOpacity < 0.04) continue;
        canvas.drawCircle(
          trailPt,
          radius * trailScale * 0.65,
          Paint()..color = color.withValues(alpha: trailOpacity * 0.40),
        );
      }

      // Bloom glow
      final satGlowRect = Rect.fromCircle(center: pt, radius: glowRadius * scale);
      final satGlowShader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: opacity * 0.45),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(satGlowRect);
      canvas.drawCircle(pt, glowRadius * scale, Paint()..shader = satGlowShader);

      // Crisp dot
      canvas.drawCircle(pt, radius * scale, Paint()..color = color.withValues(alpha: opacity));

      // Specular highlight
      canvas.drawCircle(
        pt + Offset(-radius * scale * 0.3, -radius * scale * 0.3),
        radius * scale * 0.28,
        Paint()..color = Colors.white.withValues(alpha: opacity * 0.55),
      );
    }

    // Depth ordering: draw the "behind" satellite first
    final outerFront = math.sin(outerTheta) >= 0;
    if (!outerFront) {
      drawSatellite(
        a: outerA, b: outerB, theta: outerTheta,
        color: const Color(0xFFF0CB87), glowColor: const Color(0xFFD6A85A),
        radius: 5.0, glowRadius: 10.0,
      );
      drawSatellite(
        a: innerA, b: innerB, theta: innerTheta,
        color: const Color(0xFFE0EEFF), glowColor: const Color(0xFF7AB8FF),
        radius: 3.8, glowRadius: 7.5,
      );
    } else {
      drawSatellite(
        a: innerA, b: innerB, theta: innerTheta,
        color: const Color(0xFFE0EEFF), glowColor: const Color(0xFF7AB8FF),
        radius: 3.8, glowRadius: 7.5,
      );
      drawSatellite(
        a: outerA, b: outerB, theta: outerTheta,
        color: const Color(0xFFF0CB87), glowColor: const Color(0xFFD6A85A),
        radius: 5.0, glowRadius: 10.0,
      );
    }

    // ── Core sphere (3-D gold radial gradient) ──
    final sphereRect = Rect.fromCircle(center: center, radius: coreSize / 2);
    canvas.drawCircle(
      center,
      coreSize / 2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.40),
          radius: 0.85,
          colors: [
            Color(0xFFFFF4DC),
            Color(0xFFF0CB87),
            Color(0xFFD6A85A),
            Color(0xFF9E712B),
          ],
          stops: [0.0, 0.30, 0.65, 1.0],
        ).createShader(sphereRect),
    );

    // Sphere outer glow
    canvas.drawCircle(
      center,
      coreSize / 2 + 2,
      Paint()
        ..color = const Color(0xFFD6A85A).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // ── Building icon drawn with canvas geometry ──
    final ic = coreSize * 0.44;
    final il = center - Offset(ic / 2, ic / 2);
    final iconFill = Paint()
      ..color = Colors.black.withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;
    final glowFill = Paint()
      ..color = const Color(0xFFF0CB87).withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(il.dx, il.dy + ic * 0.18, ic, ic * 0.82),
        const Radius.circular(2),
      ),
      iconFill,
    );
    // Roof
    canvas.drawPath(
      Path()
        ..moveTo(il.dx - ic * 0.06, il.dy + ic * 0.20)
        ..lineTo(il.dx + ic / 2, il.dy)
        ..lineTo(il.dx + ic + ic * 0.06, il.dy + ic * 0.20)
        ..close(),
      iconFill,
    );
    // Door
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(il.dx + ic * 0.36, il.dy + ic * 0.60, ic * 0.28, ic * 0.40),
        const Radius.circular(1.5),
      ),
      glowFill,
    );
    // Windows
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              il.dx + ic * (0.12 + col * 0.46),
              il.dy + ic * (0.30 + row * 0.20),
              ic * 0.20,
              ic * 0.14,
            ),
            const Radius.circular(1),
          ),
          glowFill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}
