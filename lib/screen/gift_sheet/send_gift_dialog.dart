import 'dart:math';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flayr/common/extensions/string_extension.dart';
import 'package:flayr/common/widget/custom_image.dart';
import 'package:flayr/common/widget/gradient_text.dart';
import 'package:flayr/languages/languages_keys.dart';
import 'package:flayr/model/general/settings_model.dart';
import 'package:flayr/utilities/app_res.dart';
import 'package:flayr/utilities/style_res.dart';
import 'package:flayr/utilities/text_style_custom.dart';
import 'package:flayr/utilities/theme_res.dart';

class SendGiftDialog extends StatefulWidget {
  final Gift gift;

  const SendGiftDialog({super.key, required this.gift});

  @override
  State<SendGiftDialog> createState() => _SendGiftDialogState();
}

class _SendGiftDialogState extends State<SendGiftDialog>
    with TickerProviderStateMixin {
  // Main gift animation controller
  late AnimationController _mainController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Sparkle/particle animation controller
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  // Glow pulse animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Generate particles
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(
        angle: (2 * pi / 12) * i + _random.nextDouble() * 0.5,
        distance: 80 + _random.nextDouble() * 60,
        size: 4 + _random.nextDouble() * 6,
        color: [
          const Color(0xFF3E8BFF),
          const Color(0xFF7B5CFF),
          const Color(0xFFFF6B6B),
          const Color(0xFFFFD93D),
          const Color(0xFF6BCB77),
          Colors.white,
        ][_random.nextInt(6)],
      ));
    }

    // Main animation - slide up + scale + bounce
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Sparkle animation
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeOut),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _sparkleController.forward();
    });

    // Auto dismiss
    Future.delayed(const Duration(seconds: AppRes.giftDialogDismissTime), () {
      if (mounted) {
        _mainController.reverse().then((_) {
          if (mounted) Get.back();
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _sparkleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _sparkleController, _glowController]),
        builder: (context, child) {
          return Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow effect behind gift
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3E8BFF)
                                        .withValues(alpha: _glowAnimation.value * 0.4),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF7B5CFF)
                                        .withValues(alpha: _glowAnimation.value * 0.3),
                                    blurRadius: 60,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Sparkle particles
                        ..._particles.map((particle) {
                          double progress = _sparkleAnimation.value;
                          double opacity = progress < 0.5
                              ? progress * 2
                              : (1 - progress) * 2;
                          double dx = cos(particle.angle) *
                              particle.distance *
                              progress;
                          double dy = sin(particle.angle) *
                              particle.distance *
                              progress;
                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Container(
                                width: particle.size * (1 - progress * 0.5),
                                height: particle.size * (1 - progress * 0.5),
                                decoration: BoxDecoration(
                                  color: particle.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: particle.color
                                          .withValues(alpha: 0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        // Gift image (main element)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomImage(
                              image: widget.gift.image?.addBaseURL(),
                              size: const Size(100, 100),
                              radius: 0,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              LKey.yourGiftHasBeenSent.tr,
                              style: TextStyleCustom.outFitRegular400(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            GradientText(
                              LKey.successfully.tr,
                              gradient: StyleRes.themeGradient,
                              style: TextStyleCustom.unboundedSemiBold600(
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}
