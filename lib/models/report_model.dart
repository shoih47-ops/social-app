class ReportModel {
  final String postId;
  final String reportedBy;
  final String reason;

  ReportModel({
    required this.postId,
    required this.reportedBy,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {'postId': postId, 'reportedBy': reportedBy, 'reason': reason};
  }
}
