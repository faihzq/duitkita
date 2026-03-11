import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String homeTeam;
  final String? homeTeamLogo;
  final String awayTeam;
  final String? awayTeamLogo;
  final DateTime matchDate;
  final String? venue;
  final String league;
  final String
  status; // e.g. 'NS' (not started), 'FT' (full time), 'LIVE', etc.
  final int? homeScore;
  final int? awayScore;
  final bool isManual; // true if added manually via Firestore

  MatchModel({
    required this.id,
    required this.homeTeam,
    this.homeTeamLogo,
    required this.awayTeam,
    this.awayTeamLogo,
    required this.matchDate,
    this.venue,
    required this.league,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.isManual = false,
  });

  /// Parse from Firestore document
  factory MatchModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
    return MatchModel(
      id: id,
      homeTeam: data['homeTeam'] ?? '',
      homeTeamLogo: data['homeTeamLogo'],
      awayTeam: data['awayTeam'] ?? '',
      awayTeamLogo: data['awayTeamLogo'],
      matchDate:
          data['matchDate'] != null
              ? (data['matchDate'] as Timestamp).toDate()
              : DateTime.now(),
      venue: data['venue'],
      league: data['league'] ?? 'Malaysia Super League',
      status: data['status'] ?? 'NS',
      homeScore: data['homeScore'],
      awayScore: data['awayScore'],
      isManual: true,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'homeTeam': homeTeam,
      'homeTeamLogo': homeTeamLogo,
      'awayTeam': awayTeam,
      'awayTeamLogo': awayTeamLogo,
      'matchDate': matchDate,
      'venue': venue,
      'league': league,
      'status': status,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'createdAt': DateTime.now(),
    };
  }

  bool get isUpcoming => matchDate.isAfter(DateTime.now()) && status == 'NS';
  bool get isFinished => status == 'FT';
}
