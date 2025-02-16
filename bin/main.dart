import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: dart run <command>');
    print('Available commands: format, analyze, test');
    exit(1);
  }

  if (!isFlutterProjectRoot()) {
    print(
        'Error: No pubspec.yaml file found.\nThis command should be run from the root of your Flutter project.');
    exit(1);
  }

  final basePath = Directory.current.path;
  final repoRoot = getGitRepoRoot();
  final relativeBasePath = basePath.replaceFirst('$repoRoot/', '');

  print('Current directory: $basePath');
  print('Repository root: $repoRoot');
  print('Relative base path: $relativeBasePath');

  final command = arguments.first;

  final modifiedFiles = getModifiedFiles()
      .where(
        (file) => file.endsWith('.dart') && file.startsWith(relativeBasePath),
      )
      .toList();

  if (modifiedFiles.isEmpty) {
    print('No modified Dart files detected.');
    exit(0);
  }

  print('Modified Dart files:\n${modifiedFiles.join('\n')}');

  final List<String> files = [];
  final Set<String> testFiles = {};

  for (final file in modifiedFiles) {
    final relativePath = file.replaceFirst('$relativeBasePath/', '');
    if (File(relativePath).existsSync()) {
      files.add(relativePath);
      if (relativePath.endsWith('_test.dart')) {
        testFiles.add(relativePath);
      } else {
        final testFile = calculateTestFile(relativePath);
        if (File(testFile).existsSync()) {
          testFiles.add(testFile);
        } else {
          print('No test file found for $relativePath. Skipping...');
        }
      }
    } else {
      print(
          'File $relativePath does not exist in the current directory. Skipping...');
    }
  }

  switch (command) {
    case 'format':
      runCommand(['dart', 'format', ...files]);
      break;
    case 'analyze':
      runCommand(['dart', 'analyze', ...files]);
      break;
    case 'test':
      if (testFiles.isNotEmpty) {
        runCommand(['flutter', 'test', ...testFiles]);
      } else {
        print('No relevant test files found.');
      }
      break;
    default:
      print('Unknown command: $command');
      print('Available commands: format, analyze, test');
      exit(1);
  }
}

String runCommand(List<String> command, {bool output = true}) {
  print('Running: ${command.join(' ')}');
  final result = Process.runSync(command.first, command.sublist(1));
  if (result.exitCode != 0) {
    print('Error running ${command.sublist(0, 1).join(' ')} ${result.stderr}');
    exit(1);
  }
  if (output) {
    stdout.write(result.stdout);
  }
  return result.stdout.toString();
}

bool isFlutterProjectRoot() {
  return File('pubspec.yaml').existsSync();
}

String getGitRepoRoot() {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    print('Error getting git repo root: ${result.stderr}');
    exit(1);
  }
  return result.stdout.trim();
}

List<String> getModifiedFiles() {
  if (!_isGitInstalled()) {
    print('Error: Git is not installed or not found in PATH.');
    exit(1);
  }
  if (!_isGitRepository()) {
    print('Error: Not a git repository.');
    exit(1);
  }
  final result = runCommand(
    ['git', 'diff', '--name-only', 'origin/main...HEAD'],
    output: false,
  );
  return result.split('\n').map((e) => e.trim()).toList();
}

String calculateTestFile(String filePath) {
  if (filePath.startsWith('lib/')) {
    return filePath
        .replaceFirst('lib/', 'test/')
        .replaceAll('.dart', '_test.dart');
  }
  return filePath.replaceAll('.dart', '_test.dart');
}

List<String> getTestFiles(List<String> files) {
  return files
      .map((file) {
        if (file.contains('test/')) return file;
        return file
            .replaceFirst('lib/', 'test/')
            .replaceAll('.dart', '_test.dart');
      })
      .where((file) => File(file).existsSync())
      .toList();
}

bool _isGitInstalled() {
  try {
    final result = Process.runSync('git', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

bool _isGitRepository() {
  final result = Process.runSync('git', ['rev-parse', '--is-inside-work-tree']);
  return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
}
