// To parse this JSON data, do
//
//     final uploadFileDifyResponse = uploadFileDifyResponseFromJson(jsonString);

import 'dart:convert';

UploadFileDifyResponse uploadFileDifyResponseFromJson(String str) =>
    UploadFileDifyResponse.fromJson(json.decode(str));

String uploadFileDifyResponseToJson(UploadFileDifyResponse data) =>
    json.encode(data.toJson());

class UploadFileDifyResponse {
  String id;
  String name;
  int size;
  String extension;
  String mimeType;
  String createdBy;
  int createdAt;
  dynamic previewUrl;

  UploadFileDifyResponse({
    required this.id,
    required this.name,
    required this.size,
    required this.extension,
    required this.mimeType,
    required this.createdBy,
    required this.createdAt,
    required this.previewUrl,
  });

  factory UploadFileDifyResponse.fromJson(Map<String, dynamic> json) =>
      UploadFileDifyResponse(
        id: json["id"],
        name: json["name"],
        size: json["size"],
        extension: json["extension"],
        mimeType: json["mime_type"],
        createdBy: json["created_by"],
        createdAt: json["created_at"],
        previewUrl: json["preview_url"],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "size": size,
    "extension": extension,
    "mime_type": mimeType,
    "created_by": createdBy,
    "created_at": createdAt,
    "preview_url": previewUrl,
  };

  @override
  String toString() {
    return 'UploadFileDifyResponse{id: $id, name: $name, size: $size, extension: $extension}';
  }
}
