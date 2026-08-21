import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

class StorageDirectoryManager {
  static late Directory _appDocDir;

  static Future<void> initialize() async {
    _appDocDir = await getApplicationDocumentsDirectory();
    await _ensureDirectoryExists(_appDocDir.path);
  }

  static String get rootPath => _appDocDir.path;

  static Future<String> getMemberDirectory(String memberId) async {
    final path = p.join(_appDocDir.path, AppConstants.membersDir, 'member_$memberId');
    await _ensureDirectoryExists(path);
    return path;
  }

  static Future<String> getMemberProfileDirectory(String memberId) async {
    final memberPath = await getMemberDirectory(memberId);
    final path = p.join(memberPath, AppConstants.profilesDir);
    await _ensureDirectoryExists(path);
    return path;
  }

  static Future<String> getFolderDirectory(String memberId, String folderId) async {
    final memberPath = await getMemberDirectory(memberId);
    final path = p.join(memberPath, AppConstants.foldersDir, 'folder_$folderId', AppConstants.documentsDir);
    await _ensureDirectoryExists(path);
    return path;
  }

  static Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}