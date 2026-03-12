import 'package:flutter/material.dart';

class Styles {
  static const Color primaryColor = Color(0xFF0E225D);
  static const Color primaryBackgroundColor = Color(0xffeeebf6);
  static const Color darkBackgroundColor = Color.fromARGB(255, 48, 1, 87);
  static const Color primaryAccentColor = Color(0xffbf37a7);
  static const Color primaryAccentColorDark = Color(0xffba24c7);
  static const Color purpleColor = Color(0xffa93185);
  static const Color purpleColorLight = Color(0xffae27a5);
  static const Color secondaryAccentColor = Color(0xff5531a9);
  static const Color secondaryAccentColorDark = Color(0xff742cb2);
  static const Color yellowColor = Color(0xFFDFE94B);
  static const Color greenColor = Color(0xff26b686);
  static const Color greyColor = Color(0xFFE6E8E8);
  static const Color whiteColor = Colors.white;
  static const Color buttonColor = Color(0xFF4C66EE);
  static const Color blueColor = Color(0xff0d6efd);
  static const Color textColor = Color(0xff313a52);
  static const Color navColor = Color(0xffe5e1f0);
  static const Color boxBackgroundColor = Color(0xfff8f7fc);
  static const Color splashBackgroundColor = Color(0xfffef9f6);
  static const Color textLightColor = Color(0xff8890ab);
  static const Color errorColor = Color(0xFFCC0B0B);
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [purpleColorLight, secondaryAccentColorDark],
  );

  // Typography scale
  static const double fsDisplay = 32;
  static const double fsPageTitle = 32;
  static const double fsSectionTitle = 22;
  static const double fsCardTitle = 18;
  static const double fsBody = 16;
  static const double fsBodyStrong = 16;
  static const double fsCaption = 14;
  static const double fsSmall = 12;
}
