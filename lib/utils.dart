enum Status {
  all,
  pending,
  completed,
}

extension StatusExtension on Status {
  String get status {
    String status;
    switch (this) {
      case Status.pending:
        status = 'pending';
        break;
      case Status.completed:
        status = "completed";
        break;
      case Status.all:
        status = "all";
        break;
    }
    return status;
  }
}

enum Type {
  all,
  score,
  event,
  penalty,
  tracks,
}

extension TypeExtension on Type {
  String get type {
    String type;
    switch (this) {
      case Type.event:
        type = 'event';
        break;
      case Type.score:
        type = "score";
        break;
      case Type.penalty:
        type = 'penalty';
        break;
      case Type.tracks:
        type = 'tracks';
        break;
      case Type.all:
        type = "all";
        break;
    }
    return type;
  }
}
