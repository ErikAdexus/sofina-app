import 'package:flutter/material.dart';

class LogoSofina extends StatelessWidget {
  final double size;

  const LogoSofina({
    super.key,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/SofinaNailSalon.jpeg',
        fit: BoxFit.contain,
      ),
    );
  }
}
