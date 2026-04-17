class ExternalLinks {
  ExternalLinks._();

  static final privacyPolicy = Uri.parse('https://exommethod.com/privacy');
  static final supportPage = Uri.parse('https://exommethod.com/support');
  static final developerGithub = Uri.parse('https://github.com/carsan-dev');
  static final serviceSupportEmail = Uri(
    scheme: 'mailto',
    path: 'exom.method@gmail.com',
    queryParameters: {'subject': 'Soporte EXOM - Servicio'},
  );
  static final technicalSupportEmail = Uri(
    scheme: 'mailto',
    path: 'csroman.dev@gmail.com',
    queryParameters: {'subject': 'Soporte EXOM - Tecnico'},
  );
}
