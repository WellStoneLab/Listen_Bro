// Copies master JSON from data/master/ to assets/data/.
// Usage: dart run tools/export_notion_data.dart
import 'dart:io';

Future<void> main() async {
  final root = Directory.current;
  final master = Directory('${root.path}/data/master');
  final assets = Directory('${root.path}/assets/data');
  if (!await master.exists()) {
    stderr.writeln('data/master not found');
    exit(1);
  }
  await assets.create(recursive: true);
  await for (final entity in master.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final name = entity.uri.pathSegments.last;
      await entity.copy('${assets.path}/$name');
      stdout.writeln('Copied $name');
    }
  }
}
