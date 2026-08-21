import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/family_member_providers.dart';
import '../widgets/family_member_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final membersAsync = ref.watch(
      familyMembersStreamProvider,
    );

    final statisticsAsync = ref.watch(
      dashboardStatisticsProvider,
    );

    final viewMode = ref.watch(
      viewModeProvider,
    );

    return Scaffold(
      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Family Vault',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(
              Icons.search,
            ),
            onPressed: () {
              context.push(
                '/search',
              );
            },
          ),
          IconButton(
            tooltip: viewMode == ViewMode.grid ? 'List View' : 'Grid View',
            icon: Icon(
              viewMode == ViewMode.grid ? Icons.list : Icons.grid_view,
            ),
            onPressed: () {
              ref
                      .read(
                        viewModeProvider.notifier,
                      )
                      .state =
                  viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(
              Icons.settings_outlined,
            ),
            onPressed: () {
              context.push(
                '/settings',
              );
            },
          ),
          const SizedBox(
            width: 4,
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            familyMembersStreamProvider,
          );

          ref.invalidate(
            dashboardStatisticsProvider,
          );

          await ref.read(
            familyMembersStreamProvider.future,
          );
        },
        child: membersAsync.when(
          // ======================================================
          // DATA
          // ======================================================

          data: (
            membersWithCounts,
          ) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ==================================================
                // DASHBOARD
                // ==================================================

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        _buildStatistics(
                          context,
                          ref,
                          statisticsAsync,
                        ),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // FAMILY MEMBERS HEADER
                // ==================================================

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      8,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Family Members',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${membersWithCounts.length}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // NO MEMBERS
                // ==================================================

                if (membersWithCounts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyMembers(
                      context,
                    ),
                  ),

                // ==================================================
                // MEMBERS GRID
                // ==================================================

                if (membersWithCounts.isNotEmpty && viewMode == ViewMode.grid)
                  SliverPadding(
                    padding: const EdgeInsets.all(
                      12,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (
                          context,
                          index,
                        ) {
                          final item = membersWithCounts[index];

                          return FamilyMemberCard(
                            member: item.member,
                            folderCount: item.folderCount,
                            documentCount: item.documentCount,
                            viewMode: viewMode,
                            onTap: () {
                              context.push(
                                '/member/${item.member.id}',
                              );
                            },
                          );
                        },
                        childCount: membersWithCounts.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                    ),
                  ),

                // ==================================================
                // MEMBERS LIST
                // ==================================================

                if (membersWithCounts.isNotEmpty && viewMode == ViewMode.list)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (
                        context,
                        index,
                      ) {
                        final item = membersWithCounts[index];

                        return FamilyMemberCard(
                          member: item.member,
                          folderCount: item.folderCount,
                          documentCount: item.documentCount,
                          viewMode: viewMode,
                          onTap: () {
                            context.push(
                              '/member/${item.member.id}',
                            );
                          },
                        );
                      },
                      childCount: membersWithCounts.length,
                    ),
                  ),

                // ==================================================
                // BOTTOM SPACE
                // ==================================================

                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90,
                  ),
                ),
              ],
            );
          },

          // ======================================================
          // LOADING
          // ======================================================

          loading: () {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },

          // ======================================================
          // ERROR
          // ======================================================

          error: (
            err,
            stack,
          ) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          const Text(
                            'Unable to load family members.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            '$err',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(
                                familyMembersStreamProvider,
                              );

                              ref.invalidate(
                                dashboardStatisticsProvider,
                              );
                            },
                            icon: const Icon(
                              Icons.refresh,
                            ),
                            label: const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ==========================================================
      // ADD MEMBER
      // ==========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(
            '/add-member',
          );
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Add Member',
        ),
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<DashboardStatistics> statisticsAsync,
  ) {
    return statisticsAsync.when(
      data: (stats) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.people,
                label: 'Members',
                value: stats.memberCount.toString(),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.folder,
                label: 'Folders',
                value: stats.folderCount.toString(),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.insert_drive_file,
                label: 'Documents',
                value: stats.documentCount.toString(),
              ),
            ),
          ],
        );
      },
      loading: () {
        return const SizedBox(
          height: 92,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (
        error,
        stack,
      ) {
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(
              16,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                ),
                const SizedBox(
                  width: 12,
                ),
                const Expanded(
                  child: Text(
                    'Unable to load statistics.',
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.invalidate(
                      dashboardStatisticsProvider,
                    );
                  },
                  icon: const Icon(
                    Icons.refresh,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 27,
              color: Theme.of(
                context,
              ).colorScheme.primary,
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY MEMBERS
  // ============================================================

  Widget _buildEmptyMembers(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'No family members yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/add-member',
                );
              },
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Add Family Member',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextButton.icon(
              onPressed: () {
                context.push(
                  '/settings',
                );
              },
              icon: const Icon(
                Icons.settings_outlined,
              ),
              label: const Text(
                'Settings',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
