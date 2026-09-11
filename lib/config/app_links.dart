/// Outward-facing links, kept in one place because they are shared in messages
/// people forward to each other — a stale one strands whoever receives it.
library;

/// Where someone who does not have DuitKita yet should go to install it.
///
/// Distribution moved from Firebase App Distribution to Google Play; the old
/// `appdistribution.firebase.dev` link was pasted into every group invite and
/// now leads nowhere.
///
/// While the app is in closed testing this listing only resolves for accounts
/// on the tester list — everyone else sees "item not found". Swap it for the
/// opt-in link (`https://play.google.com/apps/testing/my.duitkita.app`) if you
/// want recipients to be able to join the test themselves.
const String kAppDownloadUrl =
    'https://play.google.com/store/apps/details?id=my.duitkita.app';
