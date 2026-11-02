/// Where a tapped push notification should take the user, decided from the
/// `data` the Cloud Functions attach (see functions/index.js). Pure, so the
/// mapping can be tested without Firebase.
library;

sealed class NotificationRoute {
  const NotificationRoute();
}

/// A group's screen: payments, expenses, members, fund loans.
class GroupRoute extends NotificationRoute {
  final String groupId;
  const GroupRoute(this.groupId);
}

/// One debt or bill.
class DebtRoute extends NotificationRoute {
  final String debtId;
  const DebtRoute(this.debtId);
}

/// The matches screen, on the team with this TheSportsDB id.
class MatchRoute extends NotificationRoute {
  final String? teamId;
  const MatchRoute(this.teamId);
}

/// Null when there is nowhere better than Home — an unknown type, or a group
/// the user was just removed from and can no longer open.
NotificationRoute? notificationRoute(Map<String, dynamic> data) {
  String? field(String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  final type = field('type');
  if (type == 'jdt_match') return MatchRoute(field('teamId'));
  if (type == 'member_removed') return null;

  final debtId = field('debtId');
  if (debtId != null) return DebtRoute(debtId);
  final groupId = field('groupId');
  if (groupId != null) return GroupRoute(groupId);
  return null;
}
