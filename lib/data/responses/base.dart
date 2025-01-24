import 'package:djsports/data/parser.dart';

class BaseResponse {
  int code = 200;
  String error = '';

  bool get successful => code == 200;

  void from({required dynamic json, required int code}) {
    this.code = code;
    error = json['error'] as String? ?? '';
  }

  Map<String, dynamic> toJson() {
    var data = <String, dynamic>{};
    data['code'] = code;
    data['error'] = error;
    return data;
  }
}

class BaseResponseWithMessages extends BaseResponse {
  List<ResponseMessage> messages = [];

  @override
  void from({required dynamic json, required int code}) {
    super.from(json: json, code: code);

    if (json['messages'] != null) {
      json['messages'].forEach((v) {
        messages.add(ResponseMessage.from(json: v as Map<String, dynamic>));
      });
    }
  }

  @override
  Map<String, dynamic> toJson() {
    var data = <String, dynamic>{};
    data.addAll(super.toJson());
    if (messages.isNotEmpty) {
      data['messages'] = messages.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ResponseMessage {
  String message = '';
  String status = '';
  String reason = '';

  ResponseMessage(
      {required this.message, required this.status, required this.reason});

  ResponseMessage.from({required Map<String, dynamic> json}) {
    final data =
        json['message'] is Map ? json['message'] as Map<String, dynamic> : json;
    message = Parser.getString(data, 'message');
    status = Parser.getString(data, 'status');
    reason = Parser.getString(data, 'reason');
  }

  String get error {
    if (message.isNotEmpty) return message;
    if (reason.isNotEmpty) return reason;
    return message;
  }

  Map<String, dynamic> toJson() {
    var data = <String, dynamic>{};
    data['message'] = message;
    data['status'] = status;
    data['reason'] = reason;
    return data;
  }
}
