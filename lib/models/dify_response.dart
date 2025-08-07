// To parse this JSON data, do
//
//     final welcome = welcomeFromJson(jsonString);

import 'dart:convert';

Welcome welcomeFromJson(String str) => Welcome.fromJson(json.decode(str));

String welcomeToJson(Welcome data) => json.encode(data.toJson());

class Welcome {
  String event;
  String taskId;
  String id;
  String messageId;
  String conversationId;
  String mode;
  String answer;
  Metadata metadata;
  int createdAt;

  Welcome({
    required this.event,
    required this.taskId,
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.mode,
    required this.answer,
    required this.metadata,
    required this.createdAt,
  });

  factory Welcome.fromJson(Map<String, dynamic> json) => Welcome(
    event: json["event"],
    taskId: json["task_id"],
    id: json["id"],
    messageId: json["message_id"],
    conversationId: json["conversation_id"],
    mode: json["mode"],
    answer: json["answer"],
    metadata: Metadata.fromJson(json["metadata"]),
    createdAt: json["created_at"],
  );

  Map<String, dynamic> toJson() => {
    "event": event,
    "task_id": taskId,
    "id": id,
    "message_id": messageId,
    "conversation_id": conversationId,
    "mode": mode,
    "answer": answer,
    "metadata": metadata.toJson(),
    "created_at": createdAt,
  };
}

class Metadata {
  dynamic annotationReply;
  List<dynamic> retrieverResources;
  Usage usage;

  Metadata({
    required this.annotationReply,
    required this.retrieverResources,
    required this.usage,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) => Metadata(
    annotationReply: json["annotation_reply"],
    retrieverResources: List<dynamic>.from(
      json["retriever_resources"].map((x) => x),
    ),
    usage: Usage.fromJson(json["usage"]),
  );

  Map<String, dynamic> toJson() => {
    "annotation_reply": annotationReply,
    "retriever_resources": List<dynamic>.from(retrieverResources.map((x) => x)),
    "usage": usage.toJson(),
  };
}

class Usage {
  int promptTokens;
  String promptUnitPrice;
  String promptPriceUnit;
  String promptPrice;
  int completionTokens;
  String completionUnitPrice;
  String completionPriceUnit;
  String completionPrice;
  int totalTokens;
  String totalPrice;
  String currency;
  double latency;

  Usage({
    required this.promptTokens,
    required this.promptUnitPrice,
    required this.promptPriceUnit,
    required this.promptPrice,
    required this.completionTokens,
    required this.completionUnitPrice,
    required this.completionPriceUnit,
    required this.completionPrice,
    required this.totalTokens,
    required this.totalPrice,
    required this.currency,
    required this.latency,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
    promptTokens: json["prompt_tokens"],
    promptUnitPrice: json["prompt_unit_price"],
    promptPriceUnit: json["prompt_price_unit"],
    promptPrice: json["prompt_price"],
    completionTokens: json["completion_tokens"],
    completionUnitPrice: json["completion_unit_price"],
    completionPriceUnit: json["completion_price_unit"],
    completionPrice: json["completion_price"],
    totalTokens: json["total_tokens"],
    totalPrice: json["total_price"],
    currency: json["currency"],
    latency: json["latency"]?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    "prompt_tokens": promptTokens,
    "prompt_unit_price": promptUnitPrice,
    "prompt_price_unit": promptPriceUnit,
    "prompt_price": promptPrice,
    "completion_tokens": completionTokens,
    "completion_unit_price": completionUnitPrice,
    "completion_price_unit": completionPriceUnit,
    "completion_price": completionPrice,
    "total_tokens": totalTokens,
    "total_price": totalPrice,
    "currency": currency,
    "latency": latency,
  };
}
