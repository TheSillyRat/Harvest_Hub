import 'package:flutter/material.dart';
import 'theme.dart';
import 'ui_components.dart';

class OnboardingItemData {
  final String tag;
  final String title;
  final String subtitle;
  final String imagePath;

  const OnboardingItemData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

class RetroOnboardingScreen extends StatefulWidget {
  final Widget loginScreen;
  final Widget signUpScreen;

  const RetroOnboardingScreen({
    super.key,
    required this.loginScreen,
    required this.signUpScreen,
  });

  @override
  State<RetroOnboardingScreen> createState() => _RetroOnboardingScreenState();
}

class _RetroOnboardingScreenState extends State<RetroOnboardingScreen> {
  final PageController _pageController = PageController();
  double _pageOffset = 0.0;
  int _currentPage = 0;

  final List<OnboardingItemData> _pages = const [
    OnboardingItemData(
      tag: 'DIRECT HARVEST',
      title: 'Fresh From Farm\nTo Fair Trade',
      subtitle: 'Connect directly with certified local farmers. Transparent pricing without unnecessary middlemen.',
      imagePath: 'packages/harvesthub_core/assets/images/FSlide-Cus1.jpeg',
    ),
    OnboardingItemData(
      tag: 'SMART CONTRACTS',
      title: 'Real-Time Grain\n& Crop Auctions',
      subtitle: 'Lock in forward contracts with verified buyers. Automated escrows for reliable, stress-free harvest settlements.',
      imagePath: 'packages/harvesthub_core/assets/images/FSlide-Cus2.jpeg',
    ),
    OnboardingItemData(
      tag: 'ECO LOGISTICS',
      title: 'Sustainably Stored,\nPromptly Shipped',
      subtitle: 'From silo storage to climate-controlled freight, monitor your bulk produce condition at every mile.',
      imagePath: 'packages/harvesthub_core/assets/images/FSlide-Cus3.jpeg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
        _currentPage = _pageOffset.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToAuth({bool isSignUp = false}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isSignUp ? widget.signUpScreen : widget.loginScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curve),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToAuth(isSignUp: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (Logo & Skip button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const HarvestHubLogo(fontSize: 18),
                  TextButton(
                    onPressed: () => _navigateToAuth(),
                    style: TextButton.styleFrom(
                      foregroundColor: HhColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // 2. Middle Content: PageView (Text Header + Parallax Character Image)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final delta = _pageOffset - index;
                  final titleOffset = delta * 60.0;
                  final subtitleOffset = delta * 30.0;
                  final scale = (1.0 - (delta.abs() * 0.08)).clamp(0.92, 1.0);
                  final page = _pages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        BadgeChip(
                          label: page.tag,
                          icon: Icons.spa_outlined,
                        ),
                        const SizedBox(height: 10),
                        Transform.translate(
                          offset: Offset(titleOffset, 0),
                          child: Text(
                            page.title,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: HhColors.text,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Transform.translate(
                          offset: Offset(subtitleOffset, 0),
                          child: Text(
                            page.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: HhColors.text.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Character illustration scaled down & centered
                        Expanded(
                          child: Center(
                            child: Transform.scale(
                              scale: scale,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 4.0,
                                ),
                                child: Image.asset(
                                  page.imagePath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.agriculture_rounded,
                                        size: 80,
                                        color: HhColors.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. Persistent Bottom Controls (Indicator + Buttons)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElasticLiquidIndicator(
                    count: _pages.length,
                    pageOffset: _pageOffset,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Left Button: White Rounded Pill
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _navigateToAuth(isSignUp: false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: HhColors.primary,
                            side: BorderSide(
                              color: HhColors.text.withValues(alpha: 0.15),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right Button: Solid Dark Green Pill
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HhColors.primary,
                            foregroundColor: HhColors.bg,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                            shadowColor: HhColors.primary.withValues(alpha: 0.35),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1 ? 'Sign up' : 'Next',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
