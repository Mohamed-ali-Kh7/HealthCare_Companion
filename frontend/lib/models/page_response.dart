/// Enveloppe de pagination renvoyée par l'API (PageResponse côté Spring).
class PageResponse<T> {
  const PageResponse({
    required this.content,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });

  final List<T> content;
  final int page;
  final int totalPages;
  final int totalElements;

  bool get hasNext => page + 1 < totalPages;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) =>
      PageResponse(
        content: (json['content'] as List)
            .map((e) => itemFromJson(e as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        totalPages: json['totalPages'] as int,
        totalElements: json['totalElements'] as int,
      );
}
