class ExternalLinks {
  ExternalLinks._();

  static final privacyPolicy = Uri.parse('https://exom.app/privacy');
  static final supportPage = Uri.parse('https://exom.app/contact');
  static final developerGithub = Uri.parse('https://github.com/carsan-dev');
  static final supportEmail = Uri(
    scheme: 'mailto',
    path: 'soporte@exom.app',
    queryParameters: {'subject': 'Soporte EXOM'},
  );
}
