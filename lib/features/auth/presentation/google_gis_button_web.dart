import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Official Google Identity Services button (required on web).
Widget googleGisSignInButton() {
  return Center(
    child: gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.rectangular,
        logoAlignment: gsi.GSIButtonLogoAlignment.left,
        minimumWidth: 320,
      ),
    ),
  );
}
