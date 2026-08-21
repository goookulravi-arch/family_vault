import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_vault/data/database/app_database.dart';
import 'package:family_vault/data/repositories/family_member_repository.dart';

import '../models/family_member_with_counts.dart';

enum ViewMode {
  grid,
  list,
}

// ============================================================
// DATABASE
// ============================================================

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  ref.onDispose(() {
    db.close();
  });

  return db;
});

// ============================================================
// REPOSITORY
// ============================================================

final familyMemberRepositoryProvider = Provider<FamilyMemberRepository>((ref) {
  final db = ref.watch(
    databaseProvider,
  );

  return FamilyMemberRepository(db);
});

// ============================================================
// FAMILY MEMBERS
// ============================================================

final familyMembersStreamProvider =
    StreamProvider<List<FamilyMemberWithCounts>>(
  (ref) {
    final repo = ref.watch(
      familyMemberRepositoryProvider,
    );

    return repo.watchAllMembersWithCounts();
  },
);

// ============================================================
// VIEW MODE
// ============================================================

final viewModeProvider = StateProvider<ViewMode>(
  (ref) => ViewMode.grid,
);

// ============================================================
// DASHBOARD STATISTICS
// ============================================================

class DashboardStatistics {
  final int memberCount;
  final int folderCount;
  final int documentCount;

  const DashboardStatistics({
    required this.memberCount,
    required this.folderCount,
    required this.documentCount,
  });
}

final dashboardStatisticsProvider = FutureProvider<DashboardStatistics>(
  (ref) async {
    final db = ref.watch(
      databaseProvider,
    );

    final members = await db
        .select(
          db.familyMembers,
        )
        .get();

    final folders = await db
        .select(
          db.folders,
        )
        .get();

    final documents = await db
        .select(
          db.documents,
        )
        .get();

    return DashboardStatistics(
      memberCount: members.length,
      folderCount: folders.length,
      documentCount: documents.length,
    );
  },
);

// ============================================================
// RECENT DOCUMENTS
// ============================================================

final recentDocumentsProvider = FutureProvider<List<Document>>(
  (ref) async {
    final db = ref.watch(
      databaseProvider,
    );

    final documents = await db
        .select(
          db.documents,
        )
        .get();

    documents.sort(
      (a, b) => b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    // Show the latest 5 documents.
    if (documents.length > 5) {
      return documents.take(5).toList();
    }

    return documents;
  },
);
