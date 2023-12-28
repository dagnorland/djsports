const kBuildStage =
    String.fromEnvironment('BUILD_STAGE', defaultValue: 'DEVELOPER');

enum BuildStageENUM {
  developer('DEVELOPER'),
  beta('BETA'),
  production('PRODUCTION');

  final String value;
  const BuildStageENUM(this.value);

  factory BuildStageENUM.fromString(String buildStageString) {
    return BuildStageENUM.values.firstWhere((e) => e.value == buildStageString);
  }
}
