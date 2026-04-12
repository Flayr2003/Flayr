import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flayr/common/widget/custom_shimmer_fill_text.dart';
import 'package:flayr/screen/splash_screen/splash_screen_controller.dart';
import 'package:flayr/utilities/app_res.dart';
import 'package:flayr/utilities/text_style_custom.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashScreenController());
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Pure black background
          Container(
            height: double.infinity,
            width: double.infinity,
            color: const Color(0xFF000000),
          ),
          // App name centered with shimmer
          Align(
            alignment: Alignment.center,
            child: CustomShimmerFillText(
              text: AppRes.appName.toUpperCase(),
              baseColor: Colors.white,
              textStyle: TextStyleCustom.unboundedBlack900(
                  color: Colors.white, fontSize: 30),
              finalColor: Colors.white,
              shimmerColor: const Color(0xFF3E8BFF),
            ),
          ),
          // Developer credit at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Developed by',
                    style: TextStyleCustom.outFitLight300(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF3E8BFF), Color(0xFF7B5CFF)],
                    ).createShader(bounds),
                    child: Text(
                      'Abdullah Mabruok',
                      style: TextStyleCustom.unboundedSemiBold600(
                        color: Colors.white,
                        fontSize: 14,
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
  }
}
