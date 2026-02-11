class Item {
  final String id;
  final String capId; // Unique CAP identifier for tracking
  final String userId;
  final String title;
  final String? description;
  final String? assignee;
  final DateTime? dueDate;
  final String status; // pending, in-progress, completed, approved
  final String? completionDetails;
  final String? completionUploadUrl;
  final DateTime? completedAt;
  final List<String>? tags;
  // CAP management fields
  final String? correctiveAction;
  final String? remarks;
  final DateTime? expectedClosureDate;
  final List<String>? teamMembers;
  final String capexRevexType; // CAPEX, REVEX, or NONE
  final double capexRevexAmount; // Amount in currency
  final String approvalStatus; // pending, approved, rejected
  final String? approvalNotes;
  final DateTime? submittedForApprovalAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? attachments; // URLs to uploaded files

  Item({
    required this.id,
    required this.capId,
    required this.userId,
    required this.title,
    this.description,
    this.assignee,
    this.dueDate,
    this.status = 'pending',
    this.completionDetails,
    this.completionUploadUrl,
    this.completedAt,
    this.tags,
    this.correctiveAction,
    this.remarks,
    this.expectedClosureDate,
    this.teamMembers,
    this.capexRevexType = 'NONE',
    this.capexRevexAmount = 0.0,
    this.approvalStatus = 'pending',
    this.approvalNotes,
    this.submittedForApprovalAt,
    this.createdAt,
    this.updatedAt,
    this.attachments,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['_id'] ?? '',
      capId: json['capId'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      assignee: json['assignee'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      status: json['status'] ?? 'pending',
      completionDetails: json['completionDetails'],
      completionUploadUrl: json['completionUploadUrl'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      tags: List<String>.from(json['tags'] ?? []),
      correctiveAction: json['correctiveAction'],
      remarks: json['remarks'],
      expectedClosureDate: json['expectedClosureDate'] != null ? DateTime.parse(json['expectedClosureDate']) : null,
      teamMembers: List<String>.from(json['teamMembers'] ?? []),
      capexRevexType: json['capexRevexType'] ?? 'NONE',
      capexRevexAmount: (json['capexRevexAmount'] ?? 0).toDouble(),
      approvalStatus: json['approvalStatus'] ?? 'pending',
      approvalNotes: json['approvalNotes'],
      submittedForApprovalAt: json['submittedForApprovalAt'] != null ? DateTime.parse(json['submittedForApprovalAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      attachments: List<String>.from(json['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'assignee': assignee,
    'dueDate': dueDate?.toIso8601String(),
    'status': status,
    'completionDetails': completionDetails,
    'completionUploadUrl': completionUploadUrl,
    'tags': tags,
    'correctiveAction': correctiveAction,
    'remarks': remarks,
    'expectedClosureDate': expectedClosureDate?.toIso8601String(),
    'teamMembers': teamMembers,
    'capexRevexType': capexRevexType,
    'capexRevexAmount': capexRevexAmount,
    'approvalNotes': approvalNotes,
  };

  // Helper to check if CAP is overdue
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && status != 'completed';

  // Helper for status badge color
  String get statusColor {
    switch (status) {
      case 'pending':
        return 'grey';
      case 'in-progress':
        return 'orange';
      case 'completed':
        return 'green';
      default:
        return 'grey';
    }
  }
}
