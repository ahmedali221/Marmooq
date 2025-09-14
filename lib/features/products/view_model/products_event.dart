import 'package:equatable/equatable.dart';

abstract class ProductsEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchProductsEvent extends ProductsEvent {
  final int page;
  final int limit;
  final bool forceRefresh;

  FetchProductsEvent({
    this.page = 1,
    this.limit = 20,
    this.forceRefresh = false,
  });

  @override
  List<Object> get props => [page, limit, forceRefresh];
}

class LoadMoreProductsEvent extends ProductsEvent {
  final int page;
  final int limit;

  LoadMoreProductsEvent({required this.page, this.limit = 20});

  @override
  List<Object> get props => [page, limit];
}
