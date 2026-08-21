import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../models/search_result.dart';
import '../providers/search_providers.dart';

enum SearchFilter {
  all,
  members,
  folders,
  documents,
}

enum SearchSort {
  nameAZ,
  recentlyAdded,
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  SearchFilter _selectedFilter = SearchFilter.all;

  SearchSort _selectedSort = SearchSort.nameAZ;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    _searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(
    String value,
  ) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchController.clear();

    ref.read(searchQueryProvider.notifier).state = '';

    _searchFocusNode.requestFocus();
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<SearchResult> _applyFilter(
    List<SearchResult> results,
  ) {
    switch (_selectedFilter) {
      case SearchFilter.all:
        return results;

      case SearchFilter.members:
        return results
            .where(
              (result) => result.type == SearchResultType.member,
            )
            .toList();

      case SearchFilter.folders:
        return results
            .where(
              (result) => result.type == SearchResultType.folder,
            )
            .toList();

      case SearchFilter.documents:
        return results
            .where(
              (result) => result.type == SearchResultType.document,
            )
            .toList();
    }
  }

  // ============================================================
  // SORT
  // ============================================================

  List<SearchResult> _applySort(
    List<SearchResult> results,
  ) {
    final sorted = List<SearchResult>.from(
      results,
    );

    switch (_selectedSort) {
      case SearchSort.nameAZ:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(
                b.title.toLowerCase(),
              ),
        );

        break;

      case SearchSort.recentlyAdded:
        sorted.sort(
          (a, b) {
            final dateA = _getResultDate(a);

            final dateB = _getResultDate(b);

            return dateB.compareTo(
              dateA,
            );
          },
        );

        break;
    }

    return sorted;
  }

  // ============================================================
  // RESULT DATE
  // ============================================================

  DateTime _getResultDate(
    SearchResult result,
  ) {
    switch (result.type) {
      case SearchResultType.member:
        return result.member?.dateOfBirth ??
            DateTime.fromMillisecondsSinceEpoch(
              0,
            );

      case SearchResultType.folder:
        return result.folder?.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(
              0,
            );

      case SearchResultType.document:
        return result.document?.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(
              0,
            );
    }
  }

  // ============================================================
  // FILTER LABEL
  // ============================================================

  String _filterLabel(
    SearchFilter filter,
  ) {
    switch (filter) {
      case SearchFilter.all:
        return 'All';

      case SearchFilter.members:
        return 'Members';

      case SearchFilter.folders:
        return 'Folders';

      case SearchFilter.documents:
        return 'Documents';
    }
  }

  // ============================================================
  // SORT LABEL
  // ============================================================

  String _sortLabel(
    SearchSort sort,
  ) {
    switch (sort) {
      case SearchSort.nameAZ:
        return 'Name A–Z';

      case SearchSort.recentlyAdded:
        return 'Recently Added';
    }
  }

  // ============================================================
  // RESULT ICON
  // ============================================================

  IconData _getResultIcon(
    SearchResultType type,
  ) {
    switch (type) {
      case SearchResultType.member:
        return Icons.person;

      case SearchResultType.folder:
        return Icons.folder;

      case SearchResultType.document:
        return Icons.insert_drive_file;
    }
  }

  // ============================================================
  // RESULT COLOR
  // ============================================================

  Color _getResultColor(
    BuildContext context,
    SearchResultType type,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (type) {
      case SearchResultType.member:
        return colorScheme.primary;

      case SearchResultType.folder:
        return Colors.orange;

      case SearchResultType.document:
        return Colors.blue;
    }
  }

  // ============================================================
  // OPEN RESULT
  // ============================================================

  Future<void> _openResult(
    SearchResult result,
  ) async {
    switch (result.type) {
      case SearchResultType.member:
        if (result.memberId == null) {
          return;
        }

        if (!mounted) return;

        context.push(
          '/member/${result.memberId}',
        );

        return;

      case SearchResultType.folder:
        if (result.memberId == null || result.folderId == null) {
          return;
        }

        if (!mounted) return;

        context.push(
          '/member/${result.memberId}/folder/${result.folderId}',
        );

        return;

      case SearchResultType.document:
        await _openDocument(result);

        return;
    }
  }

  // ============================================================
  // OPEN DOCUMENT
  // ============================================================

  Future<void> _openDocument(
    SearchResult result,
  ) async {
    final document = result.document;

    if (document == null) {
      _showMessage(
        'Document information is unavailable.',
      );

      return;
    }

    final filePath = document.filePath;

    try {
      final file = File(filePath);

      final exists = await file.exists();

      if (!mounted) return;

      if (!exists) {
        _showMessage(
          'File not found on this device.',
        );

        return;
      }

      final openResult = await OpenFilex.open(
        filePath,
      );

      if (!mounted) return;

      if (openResult.type != ResultType.done) {
        _showMessage(
          openResult.message.isNotEmpty
              ? openResult.message
              : 'Unable to open this document.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to open document: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // FILTER BUTTON
  // ============================================================

  Widget _buildFilterButton() {
    return PopupMenuButton<SearchFilter>(
      tooltip: 'Filter',
      initialValue: _selectedFilter,
      onSelected: (filter) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      itemBuilder: (_) {
        return SearchFilter.values
            .map(
              (filter) => PopupMenuItem<SearchFilter>(
                value: filter,
                child: Row(
                  children: [
                    if (_selectedFilter == filter)
                      const Icon(
                        Icons.check,
                        size: 20,
                      )
                    else
                      const SizedBox(
                        width: 20,
                      ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      _filterLabel(
                        filter,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      icon: const Icon(
        Icons.filter_list,
      ),
    );
  }

  // ============================================================
  // SORT BUTTON
  // ============================================================

  Widget _buildSortButton() {
    return PopupMenuButton<SearchSort>(
      tooltip: 'Sort',
      initialValue: _selectedSort,
      onSelected: (sort) {
        setState(() {
          _selectedSort = sort;
        });
      },
      itemBuilder: (_) {
        return SearchSort.values
            .map(
              (sort) => PopupMenuItem<SearchSort>(
                value: sort,
                child: Row(
                  children: [
                    if (_selectedSort == sort)
                      const Icon(
                        Icons.check,
                        size: 20,
                      )
                    else
                      const SizedBox(
                        width: 20,
                      ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      _sortLabel(sort),
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      icon: const Icon(
        Icons.sort,
      ),
    );
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: SearchFilter.values.length,
        separatorBuilder: (_, __) {
          return const SizedBox(
            width: 8,
          );
        },
        itemBuilder: (context, index) {
          final filter = SearchFilter.values[index];

          final selected = _selectedFilter == filter;

          return FilterChip(
            selected: selected,
            label: Text(
              _filterLabel(filter),
            ),
            avatar: selected
                ? const Icon(
                    Icons.check,
                    size: 18,
                  )
                : null,
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
    String query, {
    bool filteredOut = false,
  }) {
    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.25,
                    ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Search Family Vault',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              const Text(
                'Search for family members, '
                'folders, and documents.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filteredOut ? Icons.filter_alt_off : Icons.search_off,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.3,
                  ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              filteredOut ? 'No results in this category' : 'No results found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              filteredOut
                  ? 'Try selecting "All" or another filter.'
                  : 'Nothing matches "$query".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RESULTS
  // ============================================================

  Widget _buildResults(
    List<SearchResult> rawResults,
  ) {
    final query = ref.watch(searchQueryProvider).trim();

    final filteredResults = _applyFilter(
      rawResults,
    );

    final results = _applySort(
      filteredResults,
    );

    if (results.isEmpty) {
      return _buildEmptyState(
        query,
        filteredOut: rawResults.isNotEmpty && query.isNotEmpty,
      );
    }

    return Column(
      children: [
        // ------------------------------------------------------
        // RESULT SUMMARY
        // ------------------------------------------------------

        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} '
                  '${results.length == 1 ? 'result' : 'results'}'
                  ' • ${_filterLabel(_selectedFilter)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _sortLabel(
                  _selectedSort,
                ),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // ------------------------------------------------------
        // LIST
        // ------------------------------------------------------

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 8,
              );
            },
            itemBuilder: (context, index) {
              final result = results[index];

              final iconColor = _getResultColor(
                context,
                result.type,
              );

              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      _getResultIcon(
                        result.type,
                      ),
                      color: iconColor,
                    ),
                  ),
                  title: Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    result.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    _openResult(
                      result,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final resultsAsync = ref.watch(
      searchResultsProvider,
    );

    final query = ref.watch(
      searchQueryProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
        ),
        actions: [
          _buildFilterButton(),
          _buildSortButton(),
        ],
      ),
      body: Column(
        children: [
          // ======================================================
          // SEARCH FIELD
          // ======================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search family, folders, documents...',
                prefixIcon: const Icon(
                  Icons.search,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.clear,
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                ),
                filled: true,
              ),
            ),
          ),

          // ======================================================
          // FILTER CHIPS
          // ======================================================

          _buildFilterChips(),

          const SizedBox(
            height: 4,
          ),

          // ======================================================
          // RESULTS
          // ======================================================

          Expanded(
            child: resultsAsync.when(
              data: _buildResults,
              loading: () {
                if (query.isEmpty) {
                  return _buildEmptyState(
                    '',
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              error: (
                error,
                stack,
              ) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        const Text(
                          'Unable to search',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          '$error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        FilledButton(
                          onPressed: () {
                            ref.invalidate(
                              searchResultsProvider,
                            );
                          },
                          child: const Text(
                            'Try Again',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
