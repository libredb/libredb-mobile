import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

/// One place the community section sends the user, with the icon and label that name it.
///
/// It carries **no colour**. The two layouts that render these disagree about colour — the wide card grid tints each
/// icon with a brand hue on a dark panel, the phone row draws all six in `cs.onSurfaceVariant` because two of those
/// hues fall under the 3:1 contrast floor on a light surface (#357). A colour here would have to be one of the two,
/// and the other would override it.
class CommunityAction {
  const CommunityAction({required this.key, required this.icon, required this.label, required this.url});

  final Key key;
  final IconData icon;
  final String Function(S l10n) label;
  final String url;
}

/// The six places, in the order both layouts show them.
List<CommunityAction> communityActions(CommunityUrls urls) => [
  CommunityAction(
    key: communityStarKey,
    icon: Icons.star_border_rounded,
    label: (l10n) => l10n.community_star,
    url: urls.repo,
  ),
  CommunityAction(
    key: communityIssueKey,
    icon: Icons.bug_report_outlined,
    label: (l10n) => l10n.community_issue,
    url: urls.issues,
  ),
  CommunityAction(
    key: communityContributeKey,
    icon: Icons.code_rounded,
    label: (l10n) => l10n.community_contribute,
    url: urls.contributing,
  ),
  CommunityAction(
    key: communityTranslateKey,
    icon: Icons.translate_rounded,
    label: (l10n) => l10n.community_translate,
    url: urls.translate,
  ),
  CommunityAction(
    key: communitySponsorKey,
    icon: Icons.favorite_border_rounded,
    label: (l10n) => l10n.community_sponsor,
    url: urls.sponsor,
  ),
  CommunityAction(
    key: communityDocsKey,
    icon: Icons.menu_book_rounded,
    label: (l10n) => l10n.community_docs,
    url: urls.docs,
  ),
];
