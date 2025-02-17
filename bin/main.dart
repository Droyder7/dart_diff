import 'dart:io';
import 'package:args/args.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'branch',
      abbr: 'b',
      defaultsTo: 'main',
      help: 'Specify the base branch to use for git diff',
    )
    ..addOption(
      'remote',
      abbr: 'r',
      defaultsTo: 'origin',
      help: 'Specify the remote repository to use for git diff',
    )
    ..addFlag(
      'flutter',
      abbr: 'f',
      help: 'Run flutter test instead of dart test',
    );

  final argResults = parser.parse(arguments);
  final branch = argResults['branch'] as String;
  final remote = argResults['remote'] as String;
  final useFlutter = argResults['flutter'] as bool;
  final command = argResults.rest.isNotEmpty ? argResults.rest.first : null;

  if (command == null) {
    print('Usage: dart-diff <command> [-b <branch>]');
    print('Available commands: format, analyze, test');
    exit(1);
  }

  if (!isFlutterProjectRoot()) {
    print(
      'Error: No pubspec.yaml file found. '
      'This command should be run from the root of your Flutter project.',
    );
    exit(1);
  }

  final basePath = Directory.current.path;
  final repoRoot = getGitRepoRoot();
  final relativeBasePath = basePath.replaceFirst('$repoRoot/', '');

  print('Current directory: $basePath');
  print('Repository root: $repoRoot');
  print('Relative base path: $relativeBasePath');
  print('Using branch: $remote/$branch');

  final modifiedFiles = getModifiedFiles(remote, branch)
      .where(
        (file) => file.endsWith('.dart') && file.startsWith(relativeBasePath),
      )
      .toList();

  if (modifiedFiles.isEmpty) {
    print('No modified Dart files detected.');
    exit(0);
  }

  print('Modified Dart files:\n${modifiedFiles.join('\n')}');

  final files = <String>[];
  final testFiles = <String>{};

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
        'File $relativePath does not exist in the current directory. '
        'Skipping...',
      );
    }
  }

  switch (command) {
    case 'format':
      runCommand(['dart', 'format', ...files]);
      break;
    case 'analyze':
      runCommand([useFlutter ? 'flutter' : 'dart', 'analyze', ...files]);
      break;
    case 'test':
      if (testFiles.isNotEmpty) {
        runCommand([useFlutter ? 'flutter' : 'dart', 'test', ...testFiles]);
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
  if (output) {
    print('Running: ${command.join(' ')}');
  }
  final result = Process.runSync(command.first, command.sublist(1));
  if (result.exitCode != 0) {
    print('Error running ${command.sublist(0, 2).join(' ')} ${result.stderr}');
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

List<String> getModifiedFiles(String remote, String branch) {
  if (!_isGitInstalled()) {
    print('Error: Git is not installed or not found in PATH.');
    exit(1);
  }
  if (!_isGitRepository()) {
    print('Error: Not a git repository.');
    exit(1);
  }
  runCommand(['git', 'fetch', remote, branch], output: false);
  final result = runCommand(
    [
      'git',
      'diff',
      '--name-only',
      '--diff-filter=A',
      '$remote/$branch',
    ],
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
