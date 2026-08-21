import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/database/app_database.dart';
import '../providers/family_member_providers.dart';

class FamilyMemberCard extends StatelessWidget {
  final FamilyMember member;
  final int folderCount;
  final int documentCount;
  final ViewMode viewMode;
  final VoidCallback onTap;

  const FamilyMemberCard({
    super.key,
    required this.member,
    required this.folderCount,
    required this.documentCount,
    required this.viewMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (viewMode == ViewMode.list) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          onTap: onTap,
          leading: _buildAvatar(radius: 26),
          title: Text(
            member.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            member.relationship ?? 'Family Member',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          trailing: Text(
            '$folderCount folders • $documentCount files',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatar(radius: 42),
              const SizedBox(height: 12),
              Text(
                member.fullName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (member.relationship != null &&
                  member.relationship!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Chip(
                  label: Text(
                    member.relationship!,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
              const Spacer(),
              Text(
                '$folderCount folders • $documentCount files',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({required double radius}) {
    if (member.profileImagePath != null &&
        File(member.profileImagePath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(member.profileImagePath!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      child: Text(
        member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
